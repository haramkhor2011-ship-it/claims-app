-- ==========================================================================================================
-- DATABASE INSPECTION QUERIES
-- Claims Backend Database Schema Inspection
-- ==========================================================================================================

-- ==========================================================================================================
-- 1. TABLES - List all tables with schema, size, and row counts
-- ==========================================================================================================
SELECT 
    schemaname AS schema_name,
    tablename AS table_name,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS indexes_size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename;

-- Get row counts for all tables
SELECT 
    schemaname AS schema_name,
    tablename AS table_name,
    n_live_tup AS row_count,
    n_dead_tup AS dead_rows,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY schemaname, tablename;

-- ==========================================================================================================
-- 2. VIEWS - List all views with their definitions
-- ==========================================================================================================
SELECT 
    schemaname AS schema_name,
    viewname AS view_name,
    pg_size_pretty(pg_relation_size(schemaname||'.'||viewname)) AS size,
    viewowner AS owner
FROM pg_views
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, viewname;

-- Get view definitions (first 10 for brevity)
SELECT 
    schemaname AS schema_name,
    viewname AS view_name,
    SUBSTRING(definition, 1, 200) AS definition_preview
FROM pg_views
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, viewname
LIMIT 10;

-- ==========================================================================================================
-- 3. MATERIALIZED VIEWS - List all materialized views with refresh status
-- ==========================================================================================================
SELECT 
    schemaname AS schema_name,
    matviewname AS materialized_view_name,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||matviewname)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||matviewname)) AS mv_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||matviewname) - pg_relation_size(schemaname||'.'||matviewname)) AS indexes_size,
    matviewowner AS owner
FROM pg_matviews
ORDER BY schemaname, matviewname;

-- Get MV row counts
SELECT 
    schemaname AS schema_name,
    matviewname AS materialized_view_name,
    n_live_tup AS row_count,
    n_dead_tup AS dead_rows,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE schemaname || '.' || relname IN (
    SELECT schemaname || '.' || matviewname 
    FROM pg_matviews
)
ORDER BY schemaname, matviewname;

-- ==========================================================================================================
-- 4. FUNCTIONS & PROCEDURES - List all functions and procedures
-- ==========================================================================================================
SELECT 
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_result(p.oid) AS return_type,
    pg_get_function_arguments(p.oid) AS arguments,
    CASE p.prokind
        WHEN 'f' THEN 'function'
        WHEN 'p' THEN 'procedure'
        WHEN 'a' THEN 'aggregate'
        WHEN 'w' THEN 'window'
        ELSE 'unknown'
    END AS kind,
    l.lanname AS language,
    CASE p.provolatile
        WHEN 'i' THEN 'IMMUTABLE'
        WHEN 's' THEN 'STABLE'
        WHEN 'v' THEN 'VOLATILE'
    END AS volatility
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
LEFT JOIN pg_language l ON p.prolang = l.oid
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
ORDER BY n.nspname, p.proname;

-- ==========================================================================================================
-- 5. SUMMARY STATISTICS
-- ==========================================================================================================
SELECT 
    'Tables' AS object_type,
    COUNT(*) AS count
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
UNION ALL
SELECT 
    'Views' AS object_type,
    COUNT(*) AS count
FROM pg_views
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
UNION ALL
SELECT 
    'Materialized Views' AS object_type,
    COUNT(*) AS count
FROM pg_matviews
UNION ALL
SELECT 
    'Functions' AS object_type,
    COUNT(*) AS count
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast');

-- ==========================================================================================================
-- 6. SCHEMA SIZES
-- ==========================================================================================================
SELECT 
    schemaname AS schema_name,
    pg_size_pretty(SUM(pg_total_relation_size(schemaname||'.'||tablename))) AS total_size,
    pg_size_pretty(SUM(pg_relation_size(schemaname||'.'||tablename))) AS table_size,
    pg_size_pretty(SUM(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename))) AS indexes_size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
GROUP BY schemaname
ORDER BY SUM(pg_total_relation_size(schemaname||'.'||tablename)) DESC;

-- ==========================================================================================================
-- 7. INDEXES - List indexes for major tables
-- ==========================================================================================================
SELECT 
    schemaname AS schema_name,
    tablename AS table_name,
    indexname AS index_name,
    indexdef AS index_definition
FROM pg_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename, indexname
LIMIT 50;

