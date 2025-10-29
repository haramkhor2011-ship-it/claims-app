-- Comprehensive query to check constraints and indexes for claim_event table
-- This script provides multiple ways to examine the table structure

-- ==========================================================================================================
-- METHOD 1: ALL CONSTRAINTS AND INDEXES (COMPREHENSIVE VIEW)
-- ==========================================================================================================

SELECT 
    'CONSTRAINT' as object_type,
    conname as name,
    contype as type,
    pg_get_constraintdef(oid) as definition,
    confrelid::regclass as referenced_table,
    confkey as referenced_columns
FROM pg_constraint 
WHERE conrelid = 'claims.claim_event'::regclass

UNION ALL

SELECT 
    'INDEX' as object_type,
    indexname as name,
    'i' as type,
    indexdef as definition,
    NULL as referenced_table,
    NULL as referenced_columns
FROM pg_indexes 
WHERE tablename = 'claim_event' AND schemaname = 'claims'

ORDER BY object_type, name;

-- ==========================================================================================================
-- METHOD 2: DETAILED CONSTRAINT INFORMATION
-- ==========================================================================================================

SELECT 
    tc.constraint_name,
    tc.constraint_type,
    tc.table_name,
    tc.table_schema,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    pg_get_constraintdef(tc.constraint_name::regclass) as constraint_definition
FROM information_schema.table_constraints AS tc 
LEFT JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
LEFT JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.table_name = 'claim_event' 
    AND tc.table_schema = 'claims'
ORDER BY tc.constraint_type, tc.constraint_name;

-- ==========================================================================================================
-- METHOD 3: DETAILED INDEX INFORMATION
-- ==========================================================================================================

SELECT 
    i.relname as index_name,
    i.relkind as index_type,
    pg_size_pretty(pg_relation_size(i.oid)) as index_size,
    pg_get_indexdef(i.oid) as index_definition,
    a.attname as column_name,
    am.amname as access_method,
    idx.indisunique as is_unique,
    idx.indisprimary as is_primary,
    idx.indisclustered as is_clustered
FROM pg_class i
JOIN pg_index idx ON i.oid = idx.indexrelid
JOIN pg_class t ON idx.indrelid = t.oid
JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(idx.indkey)
JOIN pg_am am ON i.relam = am.oid
WHERE t.relname = 'claim_event' 
    AND t.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'claims')
ORDER BY i.relname, a.attnum;

-- ==========================================================================================================
-- METHOD 4: QUICK OVERVIEW (SUMMARY)
-- ==========================================================================================================

-- Quick constraint summary
SELECT 
    'CONSTRAINTS' as category,
    COUNT(*) as count,
    STRING_AGG(constraint_type, ', ' ORDER BY constraint_type) as types
FROM information_schema.table_constraints 
WHERE table_name = 'claim_event' AND table_schema = 'claims'

UNION ALL

-- Quick index summary
SELECT 
    'INDEXES' as category,
    COUNT(*) as count,
    STRING_AGG(
        CASE 
            WHEN indisunique THEN 'UNIQUE ' 
            WHEN indisprimary THEN 'PRIMARY ' 
            ELSE '' 
        END || relname, 
        ', ' 
        ORDER BY relname
    ) as types
FROM pg_class i
JOIN pg_index idx ON i.oid = idx.indexrelid
JOIN pg_class t ON idx.indrelid = t.oid
WHERE t.relname = 'claim_event' 
    AND t.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'claims');

-- ==========================================================================================================
-- METHOD 5: SPECIFIC CONSTRAINT TYPES
-- ==========================================================================================================

-- Primary Key
SELECT 
    'PRIMARY KEY' as constraint_type,
    kcu.column_name,
    tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'claim_event' 
    AND tc.table_schema = 'claims'
    AND tc.constraint_type = 'PRIMARY KEY';

-- Foreign Keys
SELECT 
    'FOREIGN KEY' as constraint_type,
    kcu.column_name,
    ccu.table_name AS referenced_table,
    ccu.column_name AS referenced_column,
    tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu 
    ON tc.constraint_name = ccu.constraint_name
WHERE tc.table_name = 'claim_event' 
    AND tc.table_schema = 'claims'
    AND tc.constraint_type = 'FOREIGN KEY';

-- Unique Constraints
SELECT 
    'UNIQUE' as constraint_type,
    kcu.column_name,
    tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'claim_event' 
    AND tc.table_schema = 'claims'
    AND tc.constraint_type = 'UNIQUE';

-- Check Constraints
SELECT 
    'CHECK' as constraint_type,
    tc.constraint_name,
    pg_get_constraintdef(tc.constraint_name::regclass) as constraint_definition
FROM information_schema.table_constraints tc
WHERE tc.table_name = 'claim_event' 
    AND tc.table_schema = 'claims'
    AND tc.constraint_type = 'CHECK';

-- ==========================================================================================================
-- METHOD 6: INDEX USAGE STATISTICS (if pg_stat_statements is enabled)
-- ==========================================================================================================

-- Index usage statistics
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as times_used,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes 
WHERE tablename = 'claim_event' AND schemaname = 'claims'
ORDER BY idx_scan DESC;

-- ==========================================================================================================
-- METHOD 7: TABLE SIZE AND INDEX SIZE
-- ==========================================================================================================

SELECT 
    'claim_event' as table_name,
    pg_size_pretty(pg_total_relation_size('claims.claim_event')) as total_size,
    pg_size_pretty(pg_relation_size('claims.claim_event')) as table_size,
    pg_size_pretty(pg_total_relation_size('claims.claim_event') - pg_relation_size('claims.claim_event')) as index_size;

-- ==========================================================================================================
-- METHOD 8: SPECIFIC INDEXES WE'RE INTERESTED IN
-- ==========================================================================================================

-- Check for the specific indexes we've been working with
SELECT 
    indexname,
    indexdef,
    CASE 
        WHEN indexdef LIKE '%uq_claim_event_one_submission%' THEN 'SUBMISSION UNIQUE INDEX'
        WHEN indexdef LIKE '%uq_claim_event_dedup%' THEN 'DEDUP UNIQUE CONSTRAINT'
        WHEN indexdef LIKE '%ingestion_file_id%' THEN 'INGESTION FILE INDEX'
        WHEN indexdef LIKE '%claim_key_id%' THEN 'CLAIM KEY INDEX'
        ELSE 'OTHER INDEX'
    END as index_purpose
FROM pg_indexes 
WHERE tablename = 'claim_event' 
    AND schemaname = 'claims'
ORDER BY index_purpose, indexname;

-- ==========================================================================================================
-- METHOD 9: VALIDATION QUERIES
-- ==========================================================================================================

-- Validate that our specific constraints exist
DO $$
DECLARE
    constraint_count INTEGER;
    index_count INTEGER;
BEGIN
    RAISE NOTICE '=== CONSTRAINT VALIDATION ===';
    
    -- Check for uq_claim_event_dedup constraint
    SELECT COUNT(*) INTO constraint_count
    FROM pg_constraint 
    WHERE conrelid = 'claims.claim_event'::regclass 
        AND conname = 'uq_claim_event_dedup';
    
    IF constraint_count > 0 THEN
        RAISE NOTICE '✓ uq_claim_event_dedup constraint exists';
    ELSE
        RAISE NOTICE '✗ uq_claim_event_dedup constraint missing';
    END IF;
    
    -- Check for uq_claim_event_one_submission index
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes 
    WHERE tablename = 'claim_event' 
        AND schemaname = 'claims'
        AND indexname = 'uq_claim_event_one_submission';
    
    IF index_count > 0 THEN
        RAISE NOTICE '✓ uq_claim_event_one_submission index exists';
    ELSE
        RAISE NOTICE '✗ uq_claim_event_one_submission index missing';
    END IF;
    
    RAISE NOTICE '=== VALIDATION COMPLETE ===';
END $$;




