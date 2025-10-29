-- SIMPLE AND FAST DATABASE CLEANUP
-- Only removes truly orphaned data, preserves remittance relationships

-- ==========================================================================================================
-- STEP 1: BACKUP CRITICAL DATA (OPTIONAL)
-- ==========================================================================================================

-- Create backup tables
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

SELECT 'BACKUP_CREATED' as action, 
       (SELECT COUNT(*) FROM claims.backup_submission_20251025) as orphaned_submissions_backed_up,
       (SELECT COUNT(*) FROM claims.backup_claim_event_20251025) as orphaned_events_backed_up;

-- ==========================================================================================================
-- STEP 2: DELETE ORPHANED EVENTS (FAST - NO JOINS)
-- ==========================================================================================================

-- Delete claim_events that reference non-existent claim_keys
DELETE FROM claims.claim_event 
WHERE claim_key_id NOT IN (
    SELECT DISTINCT id FROM claims.claim_key
);

SELECT 'ORPHANED_EVENTS_DELETED' as action, 'Check logs for count' as note;

-- ==========================================================================================================
-- STEP 3: DELETE ORPHANED SUBMISSIONS (FAST - NO JOINS)
-- ==========================================================================================================

-- Delete submissions that have no claims
DELETE FROM claims.submission 
WHERE id NOT IN (
    SELECT DISTINCT submission_id FROM claims.claim WHERE submission_id IS NOT NULL
);

SELECT 'ORPHANED_SUBMISSIONS_DELETED' as action, 'Check logs for count' as note;

-- ==========================================================================================================
-- STEP 4: HANDLE DUPLICATE SUBMISSIONS (FAST)
-- ==========================================================================================================

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

SELECT 'DUPLICATE_SUBMISSIONS_DELETED' as action, 'Check logs for count' as note;

-- ==========================================================================================================
-- STEP 5: DELETE ORPHANED REMITTANCE_CLAIMS (FAST)
-- ==========================================================================================================

-- Delete remittance_claims that reference non-existent claim_keys
DELETE FROM claims.remittance_claim 
WHERE claim_key_id NOT IN (
    SELECT DISTINCT id FROM claims.claim_key
);

SELECT 'ORPHANED_REMITTANCE_CLAIMS_DELETED' as action, 'Check logs for count' as note;

-- ==========================================================================================================
-- STEP 6: DELETE ORPHANED REMITTANCES (FAST)
-- ==========================================================================================================

-- Delete remittances that have no claims
DELETE FROM claims.remittance 
WHERE id NOT IN (
    SELECT DISTINCT remittance_id FROM claims.remittance_claim WHERE remittance_id IS NOT NULL
);

SELECT 'ORPHANED_REMITTANCES_DELETED' as action, 'Check logs for count' as note;

-- ==========================================================================================================
-- STEP 7: DELETE ORPHANED CLAIM_KEYS (NOW SAFE AND FAST)
-- ==========================================================================================================

-- Delete claim_keys that are not referenced by ANY claims or remittance_claims
DELETE FROM claims.claim_key 
WHERE id NOT IN (
    SELECT DISTINCT claim_key_id FROM claims.claim WHERE claim_key_id IS NOT NULL
    UNION
    SELECT DISTINCT claim_key_id FROM claims.remittance_claim WHERE claim_key_id IS NOT NULL
);

SELECT 'ORPHANED_CLAIM_KEYS_DELETED' as action, 'Check logs for count' as note;

-- ==========================================================================================================
-- STEP 8: RESET INGESTION TRACKING TABLES
-- ==========================================================================================================

-- Mark all ingestion_file_audit records as failed
UPDATE claims.ingestion_file_audit 
SET status = 3,
    reason = 'Database cleanup - corrupted data removed',
    verification_failed_count = 1
WHERE status != 3;

SELECT 'INGESTION_AUDIT_RESET' as action, 'Check logs for count' as note;

-- End any running ingestion runs
UPDATE claims.ingestion_run 
SET ended_at = NOW(),
    poll_reason = 'Database cleanup - corrupted data removed'
WHERE ended_at IS NULL;

SELECT 'INGESTION_RUNS_ENDED' as action, 'Check logs for count' as note;

-- ==========================================================================================================
-- STEP 9: VERIFY CLEANUP RESULTS (FAST)
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

-- Quick integrity checks
SELECT 
    'INTEGRITY_CHECK_SUBMISSIONS' as check_type,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL - ' || COUNT(*) || ' orphaned submissions'
    END as result
FROM claims.submission s
WHERE NOT EXISTS (SELECT 1 FROM claims.claim c WHERE c.submission_id = s.id);

SELECT 
    'INTEGRITY_CHECK_EVENTS' as check_type,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL - ' || COUNT(*) || ' orphaned events'
    END as result
FROM claims.claim_event ce
WHERE NOT EXISTS (SELECT 1 FROM claims.claim_key ck WHERE ck.id = ce.claim_key_id);

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
    'FAST_CLEANUP_COMPLETE' as status,
    'Database corruption has been cleaned. Ready for fresh ingestion.' as message,
    NOW() as completion_time;
