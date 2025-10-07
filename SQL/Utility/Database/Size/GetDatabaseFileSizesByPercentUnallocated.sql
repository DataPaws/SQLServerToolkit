IF OBJECT_ID('tempdb..#DatabaseUnallocatedSpace', 'U') IS NOT NULL
    DROP TABLE #DatabaseUnallocatedSpace;

CREATE TABLE #DatabaseUnallocatedSpace (
    [DatabaseName] NVARCHAR(128),
    [FileName] NVARCHAR(128),
    [FileType] NVARCHAR(50),
    [SizeMB] INT,
    [SizeGB] DECIMAL(10,2),
    [UnallocatedSpaceMB] INT,
    [UnallocatedSpaceGB] DECIMAL(10,2),
    [UnallocatedSpacePercentage] NVARCHAR(6),
    [DriveLetter] NVARCHAR(3)
);

DECLARE @DatabaseName NVARCHAR(128),
        @SQL NVARCHAR(MAX);

DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT [name]
FROM sys.databases
WHERE state_desc = 'ONLINE' AND database_id > 4;

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @DatabaseName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = N'
    USE [' + @DatabaseName + '];

    INSERT INTO #DatabaseUnallocatedSpace
    SELECT
        DB_NAME() AS DatabaseName,
        [name] AS FileName,
        [type_desc] AS FileType,
        [size] * 8 / 1024 AS SizeMB,
        CAST(([size] * 8.0 / 1024 / 1024) AS DECIMAL(10,2)) AS SizeGB,
        ([size] * 8 / 1024) - (FILEPROPERTY([name], ''SpaceUsed'') / 128) AS UnallocatedSpaceMB,
        CAST((([size] * 8.0 / 1024) - (FILEPROPERTY([name], ''SpaceUsed'') / 128)) / 1024 AS DECIMAL(10,2)) AS UnallocatedSpaceGB,
        CONCAT(
            CAST(
                ROUND(
                    CASE 
                        WHEN [size] = 0 THEN 0
                        ELSE 
                            CASE 
                                WHEN (([size]*8.0/1024 - FILEPROPERTY([name], ''SpaceUsed'')/128) / ([size]*8.0/1024) * 100) < 0 THEN 0
                                ELSE (([size]*8.0/1024 - FILEPROPERTY([name], ''SpaceUsed'')/128) / ([size]*8.0/1024) * 100)
                            END
                    END, 1
                ) AS DECIMAL(5,1)
            ),
            ''%''
        ) AS UnallocatedSpacePercentage,
        LEFT([physical_name], 3) AS DriveLetter
    FROM sys.database_files
    WHERE [type_desc] IN (''ROWS'', ''LOG'');
    ';

    EXEC sp_executesql @SQL;

    FETCH NEXT FROM db_cursor INTO @DatabaseName;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

SELECT *
FROM #DatabaseUnallocatedSpace
ORDER BY SizeMB DESC, UnallocatedSpacePercentage DESC

DROP TABLE #DatabaseUnallocatedSpace;
