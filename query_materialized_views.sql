-- List all materialized views with sizes and row counts
SELECT 
    mv.schemaname AS schema_name,
    mv.matviewname AS materialized_view_name,
    COALESCE(st.n_live_tup, 0) AS row_count,
    pg_size_pretty(pg_total_relation_size(mv.schemaname||'.'||mv.matviewname)) AS total_size,
    mv.matviewowner AS owner
FROM pg_matviews mv
LEFT JOIN pg_stat_user_tables st ON st.schemaname = mv.schemaname AND st.relname = mv.matviewname
ORDER BY mv.schemaname, mv.matviewname;












