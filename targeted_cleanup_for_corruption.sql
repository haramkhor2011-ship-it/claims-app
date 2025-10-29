-- TARGETED CLEANUP FOR YOUR SPECIFIC CORRUPTION ISSUES
-- Based on your database state analysis

-- ==========================================================================================================
-- STEP 1: BACKUP CRITICAL DATA (RECOMMENDED)
-- ==========================================================================================================

-- Create backup tables with timestamp
CREATE TABLE IF NOT EXISTS claims.backup_submission_20251025 AS 
SELECT * FROM claims.submission WHERE id IN (
    SELECT s.id FROM claims.submission s
    LEFT JOIN claims.claim c ON s.id = c.submission_id
    WHERE c.id IS NULL
);

CREATE TABLE IF NOT EXISTS claims.backup_claim_event_20251025 AS 
SELECT * FROM claims.claim_event WHERE id IN (
    SELECT ce.id FROM claims.claim_event ce
    LEFT JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id
    WHERE c.id IS NULL
);

-- ==========================================================================================================
-- STEP 2: CLEAN UP ORPHANED EVENTS (7,367 events)
-- ==========================================================================================================

-- Delete orphaned claim_events first (safest)
DELETE FROM claims.claim_event 
WHERE claim_key_id IN (
    SELECT ce.claim_key_id FROM claims.claim_event ce
    LEFT JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id
    WHERE c.id IS NULL
);

SELECT 'ORPHANED_EVENTS_DELETED' as action, 'Check logs for count' as count;

-- ==========================================================================================================
-- STEP 3: CLEAN UP ORPHANED SUBMISSIONS (1,417 submissions)
-- ==========================================================================================================

-- Delete orphaned submissions (submissions without claims)
DELETE FROM claims.submission 
WHERE id IN (
    SELECT s.id FROM claims.submission s
    LEFT JOIN claims.claim c ON s.id = c.submission_id
    WHERE c.id IS NULL
);

SELECT 'ORPHANED_SUBMISSIONS_DELETED' as action, 'Check logs for count' as count;

-- ==========================================================================================================
-- STEP 4: HANDLE DUPLICATE SUBMISSIONS (385 duplicates)
-- ==========================================================================================================

-- First, see which submissions will be deleted
SELECT 
    'DUPLICATE_SUBMISSIONS_TO_DELETE' as action,
    COUNT(*) as count
FROM (
    SELECT id, ingestion_file_id,
           ROW_NUMBER() OVER (PARTITION BY ingestion_file_id ORDER BY created_at) as rn
    FROM claims.submission
) ranked
WHERE rn > 1;

-- Delete duplicate submissions (keep the first one per ingestion_file)
WITH duplicate_submissions AS (
    SELECT id, ingestion_file_id,
           ROW_NUMBER() OVER (PARTITION BY ingestion_file_id ORDER BY created_at) as rn
    FROM claims.submission
)
DELETE FROM claims.submission 
WHERE id IN (
    SELECT id FROM duplicate_submissions WHERE rn > 1
);

SELECT 'DUPLICATE_SUBMISSIONS_DELETED' as action, 'Check logs for count' as count;

-- ==========================================================================================================
-- STEP 5: CLEAN UP ORPHANED CLAIM_KEYS
-- ==========================================================================================================

-- Delete orphaned claim_keys (only if no claims reference them)
DELETE FROM claims.claim_key 
WHERE id NOT IN (
    SELECT DISTINCT claim_key_id FROM claims.claim WHERE claim_key_id IS NOT NULL
);

SELECT 'ORPHANED_CLAIM_KEYS_DELETED' as action, 'Check logs for count' as count;

-- ==========================================================================================================
-- STEP 6: RESET INGESTION TRACKING TABLES
-- ==========================================================================================================

-- Mark all ingestion_file_audit records as failed (they're corrupted)
UPDATE claims.ingestion_file_audit 
SET status = 3, -- Mark as failed
    reason = 'Database cleanup - corrupted data removed',
    verification_failed_count = 1
WHERE status != 3;

SELECT 'INGESTION_AUDIT_RESET' as action, 'Check logs for count' as count;

-- End any running ingestion runs
UPDATE claims.ingestion_run 
SET ended_at = NOW(),
    poll_reason = 'Database cleanup - corrupted data removed'
WHERE ended_at IS NULL;

SELECT 'INGESTION_RUNS_ENDED' as action, 'Check logs for count' as count;

-- ==========================================================================================================
-- STEP 7: VERIFY CLEANUP RESULTS
-- ==========================================================================================================

-- Check remaining data counts
SELECT 
    'REMAINING_SUBMISSIONS' as table_name,
    COUNT(*) as count
FROM claims.submission
UNION ALL
SELECT 
    'REMAINING_CLAIMS' as table_name,
    COUNT(*) as count
FROM claims.claim
UNION ALL
SELECT 
    'REMAINING_CLAIM_EVENTS' as table_name,
    COUNT(*) as count
FROM claims.claim_event
UNION ALL
SELECT 
    'REMAINING_CLAIM_KEYS' as table_name,
    COUNT(*) as count
FROM claims.claim_key;

-- Verify no orphaned data remains
SELECT 
    'INTEGRITY_CHECK_SUBMISSIONS' as check_type,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL - ' || COUNT(*) || ' orphaned submissions'
    END as result
FROM claims.submission s
LEFT JOIN claims.claim c ON s.id = c.submission_id
WHERE c.id IS NULL;

SELECT 
    'INTEGRITY_CHECK_EVENTS' as check_type,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL - ' || COUNT(*) || ' orphaned events'
    END as result
FROM claims.claim_event ce
LEFT JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id
WHERE c.id IS NULL;

-- Check for remaining duplicates
SELECT 
    'INTEGRITY_CHECK_DUPLICATES' as check_type,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL - ' || COUNT(*) || ' duplicate submissions'
    END as result
FROM (
    SELECT ingestion_file_id, COUNT(*) as submission_count
    FROM claims.submission
    GROUP BY ingestion_file_id
    HAVING COUNT(*) > 1
) duplicates;

-- ==========================================================================================================
-- COMPLETION MESSAGE
-- ==========================================================================================================

SELECT 
    'TARGETED_CLEANUP_COMPLETE' as status,
    'Database corruption has been cleaned. Ready for fresh ingestion.' as message,
    NOW() as completion_time;
