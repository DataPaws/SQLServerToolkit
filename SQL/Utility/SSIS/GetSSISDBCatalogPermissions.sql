USE SSISDB;
GO
SELECT
	COALESCE(sp.name, dp.name) AS login_name,
	CASE
    	WHEN op.object_type = 1 THEN 'FOLDER'
    	WHEN op.object_type = 2 THEN 'PROJECT'
    	WHEN op.object_type = 3 THEN 'ENVIRONMENT'
    	WHEN op.object_type = 4 THEN 'OPERATION'
    	ELSE 'UNKNOWN'
	END AS object_type,
	COALESCE(f.name, f2.name) AS folder_name,
	p.name AS project_name,
	e.environment_name,
	o.operation_id,
	CASE o.operation_type
    	WHEN 1 THEN 'INITIALIZE'
    	WHEN 2 THEN 'VALIDATE'
    	WHEN 3 THEN 'EXECUTE'
    	WHEN 4 THEN 'STOP'
    	WHEN 200 THEN 'DEPLOY_PROJECT'
    	WHEN 201 THEN 'DELETE_OBJECT'
    	WHEN 300 THEN 'CONFIGURE'
    	ELSE 'UNKNOWN'
	END AS operation_type_desc,
	o.status,
	o.created_time,
	CASE op.permission_type
    	WHEN 1 THEN 'READ'
    	WHEN 2 THEN 'MODIFY'
    	WHEN 3 THEN 'EXECUTE'
    	WHEN 4 THEN 'MANAGE_PERMISSIONS'
    	ELSE 'UNKNOWN'
	END AS permission_desc,
	op.is_deny,
	op.is_role
FROM SSISDB.internal.object_permissions op
LEFT JOIN sys.database_principals dp
	ON op.sid = dp.sid
LEFT JOIN sys.server_principals sp
	ON dp.sid = sp.sid
LEFT JOIN SSISDB.internal.folders f
	ON op.object_type = 1
   AND op.object_id = f.folder_id
LEFT JOIN SSISDB.internal.projects p
	ON op.object_type = 2
   AND op.object_id = p.project_id
LEFT JOIN SSISDB.internal.folders f2
	ON p.folder_id = f2.folder_id
LEFT JOIN SSISDB.internal.environments e
	ON op.object_type = 3
   AND op.object_id = e.environment_id
LEFT JOIN SSISDB.internal.operations o
	ON op.object_type = 4
   AND op.object_id = o.operation_id
ORDER BY login_name, object_type, folder_name, project_name;
