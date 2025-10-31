-- List all views
SELECT 
    schemaname AS schema_name,
    viewname AS view_name,
    viewowner AS owner
FROM pg_views
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, viewname;







