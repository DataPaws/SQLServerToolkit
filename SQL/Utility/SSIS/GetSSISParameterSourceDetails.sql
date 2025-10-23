-- Returns information on where SSIS packages are getting their parameter values from (SSIS Environments, SQL Agent Job Parameter Overrides, Package Defaults, etc.)
WITH EnvironmentValues AS (
    SELECT 
        er.project_id,
        ev.name AS variable_name,
        CAST(ev.value AS NVARCHAR(MAX)) AS environment_value,
        e.name AS environment_name,
        e.environment_id,
        er.reference_id,
        er.environment_folder_name
    FROM SSISDB.catalog.environment_variables ev 
    LEFT JOIN SSISDB.catalog.environments e ON ev.environment_id = e.environment_id
    LEFT JOIN SSISDB.catalog.environment_references er ON er.environment_name = e.name
    LEFT JOIN SSISDB.catalog.projects pr ON er.project_id = pr.project_id
    LEFT JOIN SSISDB.catalog.folders f1 ON e.folder_id = f1.folder_id
    LEFT JOIN SSISDB.catalog.folders f2 ON pr.folder_id = f2.folder_id
    WHERE f1.name = f2.name
),
DesignAndDefaultValues AS (
    SELECT DISTINCT 
        op.project_id, 
        p.name COLLATE SQL_Latin1_General_CP1_CI_AS AS SSIS_project_name,
        op.parameter_name COLLATE SQL_Latin1_General_CP1_CI_AS AS parameter_name,
        CAST(op.design_default_value AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS AS design_default_value,
        CAST(op.default_value AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS AS default_value
    FROM SSISDB.catalog.object_parameters op
    LEFT JOIN SSISDB.catalog.projects p ON op.project_id = p.project_id
    WHERE op.parameter_name COLLATE SQL_Latin1_General_CP1_CI_AS NOT LIKE 'CM.%' 
      AND op.object_type = 20
),
JobStepParameters AS (
    SELECT 
        js.job_id,
        js.step_id,
        d.parameter_name AS parameter_name,
        LTRIM(RTRIM(
            CASE 
                WHEN CHARINDEX('";', s.value) > 0 
                THEN SUBSTRING(
                        s.value,
                        CHARINDEX('";', s.value) + 2,
                        CASE 
                            WHEN CHARINDEX(' /', s.value, CHARINDEX('";', s.value)) > 0 
                            THEN CHARINDEX(' /', s.value, CHARINDEX('";', s.value)) - (CHARINDEX('";', s.value) + 2)
                            ELSE LEN(s.value) - (CHARINDEX('";', s.value) + 1)
                        END
                     )
                ELSE NULL
            END
        )) AS manually_set_value
    FROM msdb.dbo.sysjobsteps js
    CROSS APPLY STRING_SPLIT(REPLACE(js.command, '/Par ', '|'), '|') AS s
    CROSS JOIN DesignAndDefaultValues d
    WHERE js.subsystem = 'SSIS'
      AND s.value LIKE '%$Project::' + d.parameter_name + '%'
)
SELECT DISTINCT 
    f.name AS Folder,
    p.name AS Project,
    COALESCE(js_pkg.PackageName, dep_pkg.name) AS PackageName,
    d.parameter_name AS ParameterName,
    COALESCE(
        CASE 
            WHEN EXISTS (
                SELECT 1
                FROM JobStepParameters jp
                WHERE jp.job_id = j.job_id
                  AND jp.step_id = js.step_id
                  AND jp.parameter_name = d.parameter_name
            )
            THEN 
                LTRIM(RTRIM(
                    REPLACE(
                        REPLACE(
                            (SELECT TOP 1 manually_set_value
                             FROM JobStepParameters jp
                             WHERE jp.job_id = j.job_id
                               AND jp.step_id = js.step_id
                               AND jp.parameter_name = d.parameter_name),
                            '\"', ''),
                        '"', ''
                    )
                ))
            ELSE NULL
        END,
        d.default_value,
        env_val.environment_value,
        d.design_default_value
    ) AS ParameterValue,
    CASE
        WHEN EXISTS (
            SELECT 1 
            FROM JobStepParameters jp
            WHERE jp.job_id = j.job_id
              AND jp.step_id = js.step_id
              AND jp.parameter_name = d.parameter_name
        ) THEN 'Value manually set in SQL Agent Job'
        WHEN d.default_value IS NOT NULL THEN 'Value manually set in project configuration'
        WHEN env_val.environment_value IS NOT NULL THEN 'Takes value from environment'
        WHEN d.design_default_value IS NOT NULL THEN 'Parameter not configured so value set in package'
        ELSE 'Unknown'
    END AS ParameterValueSource,
    j.name AS SQLAgentJobName,
    j.enabled AS SQLAgentJobEnabled,
    ISNULL(env_val.environment_folder_name,f.name) + '\' + env_val.environment_name AS EnvironmentPath,
    js.command AS JobStepCommand
FROM SSISDB.catalog.folders f
LEFT JOIN SSISDB.catalog.projects p ON f.folder_id = p.folder_id
LEFT JOIN DesignAndDefaultValues d ON p.project_id = d.project_id
LEFT JOIN EnvironmentValues env_val ON p.project_id = env_val.project_id 
    AND d.parameter_name = env_val.variable_name
LEFT JOIN msdb.dbo.sysjobsteps js 
    ON js.command COLLATE SQL_Latin1_General_CP1_CI_AS LIKE '%' + p.name + '%' COLLATE SQL_Latin1_General_CP1_CI_AS
LEFT JOIN msdb.dbo.sysjobs j ON j.job_id = js.job_id
OUTER APPLY (
    SELECT TOP 1 
        REVERSE(LEFT(
            REVERSE(
                SUBSTRING(
                    js.command,
                    CHARINDEX('/ISSERVER', js.command) + 10,
                    CHARINDEX('.dtsx', js.command) + 5 - (CHARINDEX('/ISSERVER', js.command) + 10)
                )
            ),
            CHARINDEX('\', REVERSE(
                SUBSTRING(
                    js.command,
                    CHARINDEX('/ISSERVER', js.command) + 10,
                    CHARINDEX('.dtsx', js.command) + 5 - (CHARINDEX('/ISSERVER', js.command) + 10)
                )
            )) - 1
        )) AS PackageName
) js_pkg
OUTER APPLY (
    SELECT TOP 1 name
    FROM SSISDB.catalog.packages
    WHERE project_id = p.project_id
    ORDER BY name
) dep_pkg
ORDER BY f.name, p.name, PackageName, d.parameter_name, j.name;
