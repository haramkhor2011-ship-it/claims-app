-- Counts for all tables in claims_ref schema using psql \gexec
\timing off
SELECT 'SELECT '''|| schemaname ||'.'|| tablename ||''' AS table_name, COUNT(*) AS row_count FROM '|| schemaname ||'.'|| tablename ||';'
FROM pg_tables
WHERE schemaname = 'claims_ref'
ORDER BY tablename
\gexec
