SELECT
    registry_key,
    value_name,
    value_data
FROM sys.dm_server_registry
WHERE 
    registry_key LIKE N'%MSSQLServer\Parameters';
