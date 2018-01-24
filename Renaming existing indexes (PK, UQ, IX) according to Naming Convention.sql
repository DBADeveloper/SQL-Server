--Renaming existing indexes (PK, UQ, IX) according to Naming Convention

SET NOCOUNT ON

--FYI: 128 - Max length of name of column => EXEC sp_server_info @attribute_id = 15 => COLUMN_LENGTH=128

IF OBJECT_ID(N'tempdb..#t') IS NOT NULL DROP TABLE #t
CREATE TABLE #t ([Id] int IDENTITY(1,1) NOT NULL, [cmd] varchar(MAX) NOT NULL)

--rename PK - Primary Key
INSERT INTO #t ([cmd])
SELECT 'EXEC sp_rename ''[' + SCHEMA_NAME(t.schema_id) + '].[' + OBJECT_NAME(i.object_id) + '].[' + i.name + ']'', ''PK__' + LEFT(OBJECT_NAME(i.object_id), 128 - LEN(N'PK__')) + '''; ' AS [cmd]
FROM sys.tables t
	INNER JOIN sys.indexes i ON t.object_id = i.object_id
	INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
	INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.is_primary_key = 1
	AND i.name <> 'PK__' + OBJECT_NAME(i.object_id) + ''
GROUP BY t.schema_id, i.object_id, i.name
ORDER BY SCHEMA_NAME(t.schema_id), OBJECT_NAME(i.object_id)--, i.index_id, ic.index_column_id

--rename UQ - Unique index
;WITH t AS (
	SELECT t.schema_id, i.object_id, i.index_id, ic.index_column_id, i.name AS indexName, c.name AS columnName
	FROM sys.tables t
		INNER JOIN sys.indexes i ON t.object_id = i.object_id
		INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
		INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
	WHERE is_unique = 1 AND is_primary_key = 0
)
, t0 AS (
	SELECT t.schema_id
		, t.object_id
		, t.index_id
		, t.indexName
	FROM t
	GROUP BY t.schema_id
		, t.object_id
		, t.index_id
		, t.indexName
)
INSERT INTO #t ([cmd])
SELECT 'BEGIN TRY EXEC sp_rename ''[' + SCHEMA_NAME(t0.schema_id) + '].[' + OBJECT_NAME(t0.object_id) + '].' + t0.indexName + ''', ''UQ__' + LEFT(OBJECT_NAME(t0.object_id), 128 - LEN(N'UQ__' + N'__')) + '__' + (LEFT(LEFT(y.columnNames, 128 - LEN(N'UQ__' + N'__')), LEN(y.columnNames) - 1)) + ''' END TRY BEGIN CATCH ALTER TABLE [' + SCHEMA_NAME(t0.schema_id) + '].[' + OBJECT_NAME(t0.object_id) + '] DROP CONSTRAINT ' + t0.indexName + ' END CATCH; ' AS [cmd]
FROM t0
	CROSS APPLY (SELECT t.columnName + '_'
				FROM t
				WHERE t0.schema_id = t.schema_id
					AND t0.object_id = t.object_id
					AND t0.index_id = t.index_id
				ORDER BY t.index_column_id
				FOR XML PATH(''), TYPE) x (columnNames)
	CROSS APPLY (SELECT x.columnNames.value('.', 'NVARCHAR(MAX)')) y (columnNames)
WHERE t0.indexName <> 'UQ__' + LEFT(OBJECT_NAME(t0.object_id), 128 - LEN(N'UQ__' + N'__')) + '__' + (LEFT(LEFT(y.columnNames, 128 - LEN(N'UQ__' + N'__')), LEN(y.columnNames) - 1)) + ''
ORDER BY SCHEMA_NAME(t0.schema_id), OBJECT_NAME(t0.object_id)

--rename IX - regular index
;WITH t AS (
	SELECT t.schema_id, i.object_id, i.index_id, ic.index_column_id, i.name AS indexName, c.name AS columnName
	FROM sys.tables t
		INNER JOIN sys.indexes i ON t.object_id = i.object_id
		INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
		INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
	WHERE is_unique = 0 AND is_primary_key = 0
)
, t0 AS (
	SELECT t.schema_id
		, t.object_id
		, t.index_id
		, t.indexName
	FROM t
	GROUP BY t.schema_id
		, t.object_id
		, t.index_id
		, t.indexName
)
INSERT INTO #t ([cmd])
SELECT 'BEGIN TRY EXEC sp_rename ''[' + SCHEMA_NAME(t0.schema_id) + '].[' + OBJECT_NAME(t0.object_id) + '].' + t0.indexName + ''', ''IX__' + LEFT(OBJECT_NAME(t0.object_id), 128 - LEN(N'IX__' + N'__')) + '__' + (LEFT(LEFT(y.columnNames, 128 - LEN(N'IX__' + N'__')), LEN(y.columnNames) - 1)) + ''' END TRY BEGIN CATCH DROP INDEX ' + t0.indexName + ' ON [' + SCHEMA_NAME(t0.schema_id) + '].[' + OBJECT_NAME(t0.object_id) + '] WITH (ONLINE = OFF) END CATCH; ' AS [cmd]
FROM t0
	CROSS APPLY (SELECT t.columnName + '_'
				FROM t
				WHERE t0.schema_id = t.schema_id
					AND t0.object_id = t.object_id
					AND t0.index_id = t.index_id
				ORDER BY t.index_column_id
				FOR XML PATH(''), TYPE) x (columnNames)
	CROSS APPLY (SELECT x.columnNames.value('.', 'NVARCHAR(MAX)')) y (columnNames)
WHERE t0.indexName <> 'IX__' + LEFT(OBJECT_NAME(t0.object_id), 128 - LEN(N'IX__' + N'__')) + '__' + (LEFT(LEFT(y.columnNames, 128 - LEN(N'IX__' + N'__')), LEN(y.columnNames) - 1)) + ''
ORDER BY SCHEMA_NAME(t0.schema_id), OBJECT_NAME(t0.object_id)


DECLARE @RowCount int = 1
	, @Id int = 1
	, @cmd nvarchar(MAX) = ''

WHILE @RowCount > 0
BEGIN
	SELECT @cmd = [cmd]
	FROM #t
	WHERE [Id] = @Id
	SET @RowCount = @@ROWCOUNT

	IF @RowCount > 0
	BEGIN
		EXEC(@cmd)
		PRINT(@cmd)
		SET @Id += 1
	END

END

PRINT('Processed ' + CONVERT(varchar(11), @Id-1) + ' objects')

SET NOCOUNT OFF
