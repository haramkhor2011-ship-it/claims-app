-- ==========================================================================================================
-- CLAIM_EVENT TABLE CONSTRAINTS AND INDEXES COMPARISON
-- ==========================================================================================================
-- 
-- Purpose: Compare constraints and indexes between DDL file and actual database
--
-- ==========================================================================================================

-- 1. Get constraints from actual database
SELECT 'CONSTRAINTS IN ACTUAL DATABASE:' as info;
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'claims.claim_event'::regclass 
ORDER BY conname;

-- 2. Get indexes from actual database
SELECT 'INDEXES IN ACTUAL DATABASE:' as info;
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'claim_event' 
AND schemaname = 'claims' 
ORDER BY indexname;

-- 3. Get table structure from actual database
SELECT 'TABLE STRUCTURE IN ACTUAL DATABASE:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'claims' 
AND table_name = 'claim_event' 
ORDER BY ordinal_position;

-- 4. Check for specific unique constraints mentioned in DDL
SELECT 'CHECKING FOR SPECIFIC UNIQUE CONSTRAINTS:' as info;

-- Check for uq_claim_event_dedup
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conrelid = 'claims.claim_event'::regclass 
            AND conname = 'uq_claim_event_dedup'
        ) THEN 'EXISTS' 
        ELSE 'MISSING' 
    END as uq_claim_event_dedup_status;

-- Check for uq_claim_event_one_submission
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conrelid = 'claims.claim_event'::regclass 
            AND conname = 'uq_claim_event_one_submission'
        ) THEN 'EXISTS' 
        ELSE 'MISSING' 
    END as uq_claim_event_one_submission_status;

-- Check for uq_claim_event_dedup index
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE tablename = 'claim_event' 
            AND schemaname = 'claims' 
            AND indexname = 'uq_claim_event_dedup'
        ) THEN 'EXISTS' 
        ELSE 'MISSING' 
    END as uq_claim_event_dedup_index_status;

-- Check for uq_claim_event_one_submission index
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE tablename = 'claim_event' 
            AND schemaname = 'claims' 
            AND indexname = 'uq_claim_event_one_submission'
        ) THEN 'EXISTS' 
        ELSE 'MISSING' 
    END as uq_claim_event_one_submission_index_status;

-- 5. Summary comparison
SELECT 'SUMMARY COMPARISON:' as info;
SELECT 
    'DDL File' as source,
    'uq_claim_event_dedup UNIQUE (claim_key_id, type, event_time)' as constraint_or_index,
    'UNIQUE INDEX' as type
UNION ALL
SELECT 
    'DDL File' as source,
    'uq_claim_event_one_submission UNIQUE (claim_key_id) WHERE type = 1' as constraint_or_index,
    'UNIQUE INDEX' as type
UNION ALL
SELECT 
    'DDL File' as source,
    'idx_claim_event_key ON (claim_key_id)' as constraint_or_index,
    'INDEX' as type
UNION ALL
SELECT 
    'DDL File' as source,
    'idx_claim_event_type ON (type)' as constraint_or_index,
    'INDEX' as type
UNION ALL
SELECT 
    'DDL File' as source,
    'idx_claim_event_time ON (event_time)' as constraint_or_index,
    'INDEX' as type
UNION ALL
SELECT 
    'DDL File' as source,
    'idx_claim_event_file ON (ingestion_file_id)' as constraint_or_index,
    'INDEX' as type;

SELECT 'Comparison complete!' as completion_message;
