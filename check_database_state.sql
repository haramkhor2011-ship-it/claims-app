-- Quick Database State Check
-- Run this to see the current state of your database before cleanup

SELECT '=== DATABASE STATE ANALYSIS ===' as section;

-- Check total counts
SELECT 
    'TOTAL_COUNTS' as category,
    'ingestion_file' as table_name,
    COUNT(*) as count
FROM claims.ingestion_file
UNION ALL
SELECT 
    'TOTAL_COUNTS' as category,
    'submission' as table_name,
    COUNT(*) as count
FROM claims.submission
UNION ALL
SELECT 
    'TOTAL_COUNTS' as category,
    'claim' as table_name,
    COUNT(*) as count
FROM claims.claim
UNION ALL
SELECT 
    'TOTAL_COUNTS' as category,
    'claim_event' as table_name,
    COUNT(*) as count
FROM claims.claim_event
UNION ALL
SELECT 
    'TOTAL_COUNTS' as category,
    'claim_key' as table_name,
    COUNT(*) as count
FROM claims.claim_key;

-- Check for corruption issues
SELECT '=== CORRUPTION ANALYSIS ===' as section;

-- Orphaned submissions
SELECT 
    'ORPHANED_SUBMISSIONS' as issue_type,
    COUNT(*) as count
FROM claims.submission s
LEFT JOIN claims.claim c ON s.id = c.submission_id
WHERE c.id IS NULL;

-- Duplicate submissions
SELECT 
    'DUPLICATE_SUBMISSIONS' as issue_type,
    COUNT(*) as count
FROM (
    SELECT ingestion_file_id, COUNT(*) as submission_count
    FROM claims.submission
    GROUP BY ingestion_file_id
    HAVING COUNT(*) > 1
) duplicates;

-- Orphaned claims
SELECT 
    'ORPHANED_CLAIMS' as issue_type,
    COUNT(*) as count
FROM claims.claim c
LEFT JOIN claims.claim_key ck ON c.claim_key_id = ck.id
WHERE ck.id IS NULL;

-- Orphaned events
SELECT 
    'ORPHANED_EVENTS' as issue_type,
    COUNT(*) as count
FROM claims.claim_event ce
LEFT JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id
WHERE c.id IS NULL;

-- Check recent ingestion activity
SELECT '=== RECENT INGESTION ACTIVITY ===' as section;

SELECT 
    'RECENT_INGESTION_FILES' as category,
    COUNT(*) as count,
    MAX(created_at) as latest_file
FROM claims.ingestion_file
WHERE created_at > NOW() - INTERVAL '24 hours';

SELECT 
    'RECENT_SUBMISSIONS' as category,
    COUNT(*) as count,
    MAX(created_at) as latest_submission
FROM claims.submission
WHERE created_at > NOW() - INTERVAL '24 hours';

SELECT 
    'RECENT_CLAIMS' as category,
    COUNT(*) as count,
    MAX(created_at) as latest_claim
FROM claims.claim
WHERE created_at > NOW() - INTERVAL '24 hours';

-- Check ingestion run status
SELECT '=== INGESTION RUN STATUS ===' as section;

SELECT 
    id,
    started_at,
    ended_at,
    profile,
    files_discovered,
    files_processed_ok,
    files_failed,
    CASE 
        WHEN ended_at IS NULL THEN 'RUNNING'
        ELSE 'COMPLETED'
    END as status
FROM claims.ingestion_run
ORDER BY started_at DESC
LIMIT 5;
