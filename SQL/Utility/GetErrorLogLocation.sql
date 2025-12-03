DECLARE @ErrorLogFilePath NVARCHAR(256);
DECLARE @UNCErrorLogFilePath NVARCHAR(256);
DECLARE @ServerName NVARCHAR(128) = CONVERT(NVARCHAR(128), SERVERPROPERTY('MachineName'));
DECLARE @DriveLetter NVARCHAR(1); 

SET @DriveLetter = SUBSTRING(CONVERT(NVARCHAR(256), SERVERPROPERTY('ErrorLogFileName')), 1, 1);

SET @ErrorLogFilePath = REPLACE(CONVERT(NVARCHAR(256), SERVERPROPERTY('ErrorLogFileName')), '\ERRORLOG', '');
SET @UNCErrorLogFilePath = '\\' + @ServerName + '\' + @DriveLetter + '$\' + 
    REPLACE(RIGHT(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(256)), 
    LEN(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(256))) - CHARINDEX('\', CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(256)))),
    '\ERRORLOG', '');

SELECT @ErrorLogFilePath AS ErrorLogFilePath;
SELECT @UNCErrorLogFilePath AS UNCErrorLogFilePath;
