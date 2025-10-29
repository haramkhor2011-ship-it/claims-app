-- FIXED TARGETED CLEANUP FOR YOUR SPECIFIC CORRUPTION ISSUES
-- Based on your database state analysis - PostgreSQL compatible

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

-- Show backup counts
SELECT 'BACKUP_CREATED' as action, 
       (SELECT COUNT(*) FROM claims.backup_submission_20251025) as orphaned_submissions_backed_up,
       (SELECT COUNT(*) FROM claims.backup_claim_event_20251025) as orphaned_events_backed_up;

-- ==========================================================================================================
-- STEP 2: CLEAN UP ORPHANED EVENTS (7,367 events)
-- ==========================================================================================================

-- Count orphaned events before deletion
SELECT 'ORPHANED_EVENTS_TO_DELETE' as action, COUNT(*) as count
FROM claims.claim_event ce
LEFT JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id
WHERE c.id IS NULL;

-- Delete orphaned claim_events first (safest)
DELETE FROM claims.claim_event 
WHERE claim_key_id IN (
    SELECT ce.claim_key_id FROM claims.claim_event ce
    LEFT JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id
    WHERE c.id IS NULL
);

SELECT 'ORPHANED_EVENTS_DELETED' as action, 'Check PostgreSQL logs for actual count' as note;

-- ==========================================================================================================
-- STEP 3: CLEAN UP ORPHANED SUBMISSIONS (1,417 submissions)
-- ==========================================================================================================

-- Count orphaned submissions before deletion
SELECT 'ORPHANED_SUBMISSIONS_TO_DELETE' as action, COUNT(*) as count
FROM claims.submission s
LEFT JOIN claims.claim c ON s.id = c.submission_id
WHERE c.id IS NULL;

-- Delete orphaned submissions (submissions without claims)
DELETE FROM claims.submission 
WHERE id IN (
    SELECT s.id FROM claims.submission s
    LEFT JOIN claims.claim c ON s.id = c.submission_id
    WHERE c.id IS NULL
);

SELECT 'ORPHANED_SUBMISSIONS_DELETED' as action, 'Check PostgreSQL logs for actual count' as note;

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

SELECT 'DUPLICATE_SUBMISSIONS_DELETED' as action, 'Check PostgreSQL logs for actual count' as note;

-- ==========================================================================================================
-- STEP 5: CLEAN UP REMITTANCE DATA FIRST
-- ==========================================================================================================

-- Count orphaned remittance_claims before deletion
SELECT 'ORPHANED_REMITTANCE_CLAIMS_TO_DELETE' as action, COUNT(*) as count
FROM claims.remittance_claim rc
LEFT JOIN claims.claim c ON rc.claim_key_id = c.claim_key_id
WHERE c.id IS NULL;

-- Delete orphaned remittance_claims (claims without corresponding submission claims)
DELETE FROM claims.remittance_claim 
WHERE claim_key_id IN (
    SELECT rc.claim_key_id FROM claims.remittance_claim rc
    LEFT JOIN claims.claim c ON rc.claim_key_id = c.claim_key_id
    WHERE c.id IS NULL
);

SELECT 'ORPHANED_REMITTANCE_CLAIMS_DELETED' as action, 'Check PostgreSQL logs for actual count' as note;

-- Count orphaned remittances before deletion
SELECT 'ORPHANED_REMITTANCES_TO_DELETE' as action, COUNT(*) as count
FROM claims.remittance r
LEFT JOIN claims.remittance_claim rc ON r.id = rc.remittance_id
WHERE rc.id IS NULL;

-- Delete orphaned remittances (remittances without claims)
DELETE FROM claims.remittance 
WHERE id IN (
    SELECT r.id FROM claims.remittance r
    LEFT JOIN claims.remittance_claim rc ON r.id = rc.remittance_id
    WHERE rc.id IS NULL
);

SELECT 'ORPHANED_REMITTANCES_DELETED' as action, 'Check PostgreSQL logs for actual count' as note;

-- ==========================================================================================================
-- STEP 6: CLEAN UP ORPHANED CLAIM_KEYS (NOW SAFE)
-- ==========================================================================================================

-- Count orphaned claim_keys before deletion
SELECT 'ORPHANED_CLAIM_KEYS_TO_DELETE' as action, COUNT(*) as count
FROM claims.claim_key ck
LEFT JOIN claims.claim c ON ck.id = c.claim_key_id
LEFT JOIN claims.remittance_claim rc ON ck.id = rc.claim_key_id
WHERE c.id IS NULL AND rc.id IS NULL;

-- Delete orphaned claim_keys (only if no claims or remittance_claims reference them)
DELETE FROM claims.claim_key 
WHERE id NOT IN (
    SELECT DISTINCT claim_key_id FROM claims.claim WHERE claim_key_id IS NOT NULL
    UNION
    SELECT DISTINCT claim_key_id FROM claims.remittance_claim WHERE claim_key_id IS NOT NULL
);

SELECT 'ORPHANED_CLAIM_KEYS_DELETED' as action, 'Check PostgreSQL logs for actual count' as note;

-- ==========================================================================================================
-- STEP 7: RESET INGESTION TRACKING TABLES
-- ==========================================================================================================

-- Count records to be updated
SELECT 'INGESTION_AUDIT_RECORDS_TO_RESET' as action, COUNT(*) as count
FROM claims.ingestion_file_audit 
WHERE status != 3;

-- Mark all ingestion_file_audit records as failed (they're corrupted)
UPDATE claims.ingestion_file_audit 
SET status = 3, -- Mark as failed
    reason = 'Database cleanup - corrupted data removed',
    verification_failed_count = 1
WHERE status != 3;

SELECT 'INGESTION_AUDIT_RESET' as action, 'Check PostgreSQL logs for actual count' as note;

-- Count running ingestion runs
SELECT 'RUNNING_INGESTION_RUNS_TO_END' as action, COUNT(*) as count
FROM claims.ingestion_run 
WHERE ended_at IS NULL;

-- End any running ingestion runs
UPDATE claims.ingestion_run 
SET ended_at = NOW(),
    poll_reason = 'Database cleanup - corrupted data removed'
WHERE ended_at IS NULL;

SELECT 'INGESTION_RUNS_ENDED' as action, 'Check PostgreSQL logs for actual count' as note;

-- ==========================================================================================================
-- STEP 8: VERIFY CLEANUP RESULTS
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
FROM claims.claim_key
UNION ALL
SELECT 
    'REMAINING_REMITTANCES' as table_name,
    COUNT(*) as count
FROM claims.remittance
UNION ALL
SELECT 
    'REMAINING_REMITTANCE_CLAIMS' as table_name,
    COUNT(*) as count
FROM claims.remittance_claim;

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
