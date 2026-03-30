IF OBJECT_ID('tempdb..#IntegrityCheckResults') IS NOT NULL
    DROP TABLE #IntegrityCheckResults;

IF OBJECT_ID('tempdb..#DBInfo') IS NOT NULL
    DROP TABLE #DBInfo;

CREATE TABLE #IntegrityCheckResults
(
    DatabaseName NVARCHAR(128),
    LastIntegrityCheckDate DATETIME
);

CREATE TABLE #DBInfo (
	ParentObject VARCHAR(255), 
	[Object] VARCHAR(255), 
	Field VARCHAR(255), 
	[Value] VARCHAR(255)
);

DECLARE @DatabaseName NVARCHAR(128);
DECLARE db_cursor CURSOR FOR
SELECT name
FROM sys.databases
WHERE database_id <> 2
AND state_desc = 'ONLINE';

DECLARE @SqlCommand NVARCHAR(MAX);

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @DatabaseName;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SqlCommand = '
        INSERT INTO #DBInfo EXECUTE (''DBCC DBINFO ([' + @DatabaseName + ']) WITH TABLERESULTS'');
        INSERT INTO #IntegrityCheckResults (DatabaseName, LastIntegrityCheckDate)
        SELECT ''' + @DatabaseName + ''', [Value]
        FROM #DBInfo
        WHERE Field = ''dbi_dbccLastKnownGood'';
		TRUNCATE TABLE #DBInfo
		'
    EXEC sp_executesql @SqlCommand;

    FETCH NEXT FROM db_cursor INTO @DatabaseName;
END;

CLOSE db_cursor;
DEALLOCATE db_cursor;

SELECT
    *
FROM #IntegrityCheckResults
ORDER BY LastIntegrityCheckDate DESC;

DROP TABLE #IntegrityCheckResults;
DROP TABLE #DBInfo;
