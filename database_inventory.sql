-- DATABASE INVENTORY SCRIPT
-- Shows what will be included in a pg_dump backup

-- ==========================================================================================================
-- SECTION 1: DATABASE OVERVIEW
-- ==========================================================================================================

SELECT 
    'DATABASE_INFO' as info_type,
    current_database() as database_name,
    current_user as current_user,
    version() as postgresql_version,
    pg_database_size(current_database()) as database_size_bytes,
    ROUND(pg_database_size(current_database()) / 1024.0 / 1024.0, 2) as database_size_mb;

-- ==========================================================================================================
-- SECTION 2: SCHEMAS
-- ==========================================================================================================

SELECT 
    'SCHEMAS' as info_type,
    schema_name,
    schema_owner
FROM information_schema.schemata
WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pg_temp_1', 'pg_toast_temp_1')
ORDER BY schema_name;

-- ==========================================================================================================
-- SECTION 3: TABLES
-- ==========================================================================================================

SELECT 
    'TABLES' as info_type,
    table_schema,
    table_name,
    table_type,
    CASE 
        WHEN table_type = 'BASE TABLE' THEN 'Regular Table'
        WHEN table_type = 'VIEW' THEN 'View'
        WHEN table_type = 'FOREIGN TABLE' THEN 'Foreign Table'
        ELSE table_type
    END as table_description
FROM information_schema.tables
WHERE table_schema NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pg_temp_1', 'pg_toast_temp_1')
ORDER BY table_schema, table_name;

-- ==========================================================================================================
-- SECTION 4: MATERIALIZED VIEWS
-- ==========================================================================================================

SELECT 
    'MATERIALIZED_VIEWS' as info_type,
    schemaname,
    matviewname,
    definition
FROM pg_matviews
WHERE schemaname NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pg_temp_1', 'pg_toast_temp_1')
ORDER BY schemaname, matviewname;

-- ==========================================================================================================
-- SECTION 5: FUNCTIONS AND PROCEDURES
-- ==========================================================================================================

SELECT 
    'FUNCTIONS' as info_type,
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_function_result(p.oid) as return_type,
    pg_get_function_arguments(p.oid) as arguments,
    CASE 
        WHEN p.prokind = 'f' THEN 'Function'
        WHEN p.prokind = 'p' THEN 'Procedure'
        WHEN p.prokind = 'a' THEN 'Aggregate'
        WHEN p.prokind = 'w' THEN 'Window'
        ELSE 'Other'
    END as function_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pg_temp_1', 'pg_toast_temp_1')
ORDER BY n.nspname, p.proname;

-- ==========================================================================================================
-- SECTION 6: SEQUENCES
-- ==========================================================================================================

SELECT 
    'SEQUENCES' as info_type,
    sequence_schema,
    sequence_name,
    data_type,
    start_value,
    minimum_value,
    maximum_value,
    increment
FROM information_schema.sequences
WHERE sequence_schema NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pg_temp_1', 'pg_toast_temp_1')
ORDER BY sequence_schema, sequence_name;

-- ==========================================================================================================
-- SECTION 7: INDEXES
-- ==========================================================================================================

SELECT 
    'INDEXES' as info_type,
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pg_temp_1', 'pg_toast_temp_1')
ORDER BY schemaname, tablename, indexname;

-- ==========================================================================================================
-- SECTION 8: CONSTRAINTS
-- ==========================================================================================================

SELECT 
    'CONSTRAINTS' as info_type,
    tc.table_schema,
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name 
    AND tc.table_schema = kcu.table_schema
WHERE tc.table_schema NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pg_temp_1', 'pg_toast_temp_1')
ORDER BY tc.table_schema, tc.table_name, tc.constraint_name;

-- ==========================================================================================================
-- SECTION 9: TRIGGERS
-- ==========================================================================================================

SELECT 
    'TRIGGERS' as info_type,
    trigger_schema,
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pg_temp_1', 'pg_toast_temp_1')
ORDER BY trigger_schema, event_object_table, trigger_name;

-- ==========================================================================================================
-- SECTION 10: EXTENSIONS
-- ==========================================================================================================

SELECT 
    'EXTENSIONS' as info_type,
    extname as extension_name,
    extversion as version,
    n.nspname as schema_name
FROM pg_extension e
JOIN pg_namespace n ON e.extnamespace = n.oid
ORDER BY extname;

-- ==========================================================================================================
-- SECTION 11: CUSTOM TYPES
-- ==========================================================================================================

SELECT 
    'CUSTOM_TYPES' as info_type,
    n.nspname as schema_name,
    t.typname as type_name,
    CASE 
        WHEN t.typtype = 'c' THEN 'Composite'
        WHEN t.typtype = 'd' THEN 'Domain'
        WHEN t.typtype = 'e' THEN 'Enum'
        WHEN t.typtype = 'r' THEN 'Range'
        ELSE 'Other'
    END as type_type
FROM pg_type t
JOIN pg_namespace n ON t.typnamespace = n.oid
WHERE n.nspname NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pg_temp_1', 'pg_toast_temp_1')
AND t.typtype IN ('c', 'd', 'e', 'r')
ORDER BY n.nspname, t.typname;

-- ==========================================================================================================
-- SECTION 12: TABLE SIZES
-- ==========================================================================================================

SELECT 
    'TABLE_SIZES' as info_type,
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) as indexes_size
FROM pg_tables
WHERE schemaname NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pg_temp_1', 'pg_toast_temp_1')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- ==========================================================================================================
-- SECTION 13: ROW COUNTS
-- ==========================================================================================================

-- This will show row counts for all tables
-- Note: This might take a while for large tables
SELECT 
    'ROW_COUNTS' as info_type,
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;







