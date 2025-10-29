-- Quick checks for claim_event table constraints and indexes
-- Run these queries one by one for specific information

-- ==========================================================================================================
-- QUICK CHECK 1: All constraints on claim_event table
-- ==========================================================================================================
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as definition
FROM pg_constraint 
WHERE conrelid = 'claims.claim_event'::regclass
ORDER BY contype, conname;

-- ==========================================================================================================
-- QUICK CHECK 2: All indexes on claim_event table
-- ==========================================================================================================
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'claim_event' AND schemaname = 'claims'
ORDER BY indexname;

-- ==========================================================================================================
-- QUICK CHECK 3: Specific indexes we care about
-- ==========================================================================================================
-- Check for the unique indexes we've been working with
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conrelid = 'claims.claim_event'::regclass 
                AND conname = 'uq_claim_event_dedup'
        ) THEN '✓ EXISTS'
        ELSE '✗ MISSING'
    END as uq_claim_event_dedup_constraint,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE tablename = 'claim_event' 
                AND schemaname = 'claims'
                AND indexname = 'uq_claim_event_one_submission'
        ) THEN '✓ EXISTS'
        ELSE '✗ MISSING'
    END as uq_claim_event_one_submission_index;

-- ==========================================================================================================
-- QUICK CHECK 4: Table structure overview
-- ==========================================================================================================
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'claim_event' 
    AND table_schema = 'claims'
ORDER BY ordinal_position;

-- ==========================================================================================================
-- QUICK CHECK 5: Foreign key relationships
-- ==========================================================================================================
SELECT 
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    tc.constraint_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_name = 'claim_event' 
    AND tc.table_schema = 'claims'
    AND tc.constraint_type = 'FOREIGN KEY';

-- ==========================================================================================================
-- QUICK CHECK 6: Index usage statistics (if available)
-- ==========================================================================================================
SELECT 
    indexname,
    idx_scan as times_used,
    idx_tup_read as tuples_read
FROM pg_stat_user_indexes 
WHERE tablename = 'claim_event' AND schemaname = 'claims'
ORDER BY idx_scan DESC;




