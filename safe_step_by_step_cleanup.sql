-- SAFE STEP-BY-STEP DATABASE CLEANUP
-- Run these queries one by one to safely clean your database

-- ==========================================================================================================
-- STEP 1: ANALYZE CORRUPTION (READ-ONLY - SAFE TO RUN)
-- ==========================================================================================================

-- 1.1 Check for orphaned submissions
SELECT 
    'ORPHANED_SUBMISSIONS' as issue_type,
    COUNT(*) as count,
    'Submissions without any claims' as description
FROM claims.submission s
LEFT JOIN claims.claim c ON s.id = c.submission_id
WHERE c.id IS NULL;

-- 1.2 Check for duplicate submissions per ingestion_file
SELECT 
    ingestion_file_id,
    COUNT(*) as submission_count,
    MIN(created_at) as first_created,
    MAX(created_at) as last_created
FROM claims.submission
GROUP BY ingestion_file_id
HAVING COUNT(*) > 1
ORDER BY submission_count DESC;

-- 1.3 Check for orphaned claims
SELECT 
    'ORPHANED_CLAIMS' as issue_type,
    COUNT(*) as count,
    'Claims without claim_keys' as description
FROM claims.claim c
LEFT JOIN claims.claim_key ck ON c.claim_key_id = ck.id
WHERE ck.id IS NULL;

-- 1.4 Check for orphaned claim_events
SELECT 
    'ORPHANED_EVENTS' as issue_type,
    COUNT(*) as count,
    'Claim events without claims' as description
FROM claims.claim_event ce
LEFT JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id
WHERE c.id IS NULL;

-- ==========================================================================================================
-- STEP 2: BACKUP CRITICAL DATA (OPTIONAL BUT RECOMMENDED)
-- ==========================================================================================================

-- Uncomment these lines to create backup tables
/*
CREATE TABLE IF NOT EXISTS claims.backup_submission_$(date +%Y%m%d_%H%M%S) AS 
SELECT * FROM claims.submission;

CREATE TABLE IF NOT EXISTS claims.backup_claim_$(date +%Y%m%d_%H%M%S) AS 
SELECT * FROM claims.claim;

CREATE TABLE IF NOT EXISTS claims.backup_claim_event_$(date +%Y%m%d_%H%M%S) AS 
SELECT * FROM claims.claim_event;
*/

-- ==========================================================================================================
-- STEP 3: CLEANUP ORPHANED DATA (RUN ONE BY ONE)
-- ==========================================================================================================

-- 3.1 Delete orphaned observations (safest first)
-- Run this first and check the result count
DELETE FROM claims.observation 
WHERE activity_id IN (
    SELECT a.id FROM claims.activity a
    LEFT JOIN claims.claim c ON a.claim_id = c.id
    WHERE c.id IS NULL
);

-- Check how many were deleted
SELECT 'OBSERVATIONS_DELETED' as action, ROW_COUNT() as count;

-- 3.2 Delete orphaned activities
DELETE FROM claims.activity 
WHERE claim_id IN (
    SELECT c.id FROM claims.claim c
    LEFT JOIN claims.claim_key ck ON c.claim_key_id = ck.id
    WHERE ck.id IS NULL
);

SELECT 'ACTIVITIES_DELETED' as action, ROW_COUNT() as count;

-- 3.3 Delete orphaned diagnoses
DELETE FROM claims.diagnosis 
WHERE claim_id IN (
    SELECT c.id FROM claims.claim c
    LEFT JOIN claims.claim_key ck ON c.claim_key_id = ck.id
    WHERE ck.id IS NULL
);

SELECT 'DIAGNOSES_DELETED' as action, ROW_COUNT() as count;

-- 3.4 Delete orphaned encounters
DELETE FROM claims.encounter 
WHERE claim_id IN (
    SELECT c.id FROM claims.claim c
    LEFT JOIN claims.claim_key ck ON c.claim_key_id = ck.id
    WHERE ck.id IS NULL
);

SELECT 'ENCOUNTERS_DELETED' as action, ROW_COUNT() as count;

-- 3.5 Delete orphaned claim_events
DELETE FROM claims.claim_event 
WHERE claim_key_id IN (
    SELECT ce.claim_key_id FROM claims.claim_event ce
    LEFT JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id
    WHERE c.id IS NULL
);

SELECT 'CLAIM_EVENTS_DELETED' as action, ROW_COUNT() as count;

-- 3.6 Delete orphaned claims
DELETE FROM claims.claim 
WHERE claim_key_id IN (
    SELECT c.claim_key_id FROM claims.claim c
    LEFT JOIN claims.claim_key ck ON c.claim_key_id = ck.id
    WHERE ck.id IS NULL
);

SELECT 'CLAIMS_DELETED' as action, ROW_COUNT() as count;

-- ==========================================================================================================
-- STEP 4: HANDLE DUPLICATE SUBMISSIONS (CAREFUL!)
-- ==========================================================================================================

-- 4.1 First, see which submissions will be deleted
SELECT 
    s.id,
    s.ingestion_file_id,
    s.created_at,
    ROW_NUMBER() OVER (PARTITION BY s.ingestion_file_id ORDER BY s.created_at) as rn
FROM claims.submission s
WHERE s.ingestion_file_id IN (
    SELECT ingestion_file_id
    FROM claims.submission
    GROUP BY ingestion_file_id
    HAVING COUNT(*) > 1
)
ORDER BY s.ingestion_file_id, s.created_at;

-- 4.2 Delete duplicate submissions (keep the first one)
WITH duplicate_submissions AS (
    SELECT id, ingestion_file_id,
           ROW_NUMBER() OVER (PARTITION BY ingestion_file_id ORDER BY created_at) as rn
    FROM claims.submission
)
DELETE FROM claims.submission 
WHERE id IN (
    SELECT id FROM duplicate_submissions WHERE rn > 1
);

SELECT 'DUPLICATE_SUBMISSIONS_DELETED' as action, ROW_COUNT() as count;

-- ==========================================================================================================
-- STEP 5: CLEAN UP ORPHANED CLAIM_KEYS
-- ==========================================================================================================

-- 5.1 Check which claim_keys will be deleted
SELECT 
    'ORPHANED_CLAIM_KEYS' as issue_type,
    COUNT(*) as count
FROM claims.claim_key ck
LEFT JOIN claims.claim c ON ck.id = c.claim_key_id
WHERE c.id IS NULL;

-- 5.2 Delete orphaned claim_keys
DELETE FROM claims.claim_key 
WHERE id NOT IN (
    SELECT DISTINCT claim_key_id FROM claims.claim WHERE claim_key_id IS NOT NULL
);

SELECT 'ORPHANED_CLAIM_KEYS_DELETED' as action, ROW_COUNT() as count;

-- ==========================================================================================================
-- STEP 6: RESET INGESTION TRACKING (OPTIONAL)
-- ==========================================================================================================

-- 6.1 Mark all ingestion_file_audit records as failed
UPDATE claims.ingestion_file_audit 
SET status = 3, -- Mark as failed
    reason = 'Database cleanup - marked as failed',
    verification_failed_count = 1
WHERE status != 3;

SELECT 'INGESTION_AUDIT_RESET' as action, ROW_COUNT() as count;

-- 6.2 End any running ingestion runs
UPDATE claims.ingestion_run 
SET ended_at = NOW(),
    poll_reason = 'Database cleanup completed'
WHERE ended_at IS NULL;

SELECT 'INGESTION_RUNS_ENDED' as action, ROW_COUNT() as count;

-- ==========================================================================================================
-- STEP 7: VERIFY CLEANUP RESULTS
-- ==========================================================================================================

-- 7.1 Check remaining data counts
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
    'REMAINING_INGESTION_FILES' as table_name,
    COUNT(*) as count
FROM claims.ingestion_file;

-- 7.2 Verify no orphaned data remains
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
    'INTEGRITY_CHECK_CLAIMS' as check_type,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL - ' || COUNT(*) || ' orphaned claims'
    END as result
FROM claims.claim c
LEFT JOIN claims.claim_key ck ON c.claim_key_id = ck.id
WHERE ck.id IS NULL;

SELECT 
    'INTEGRITY_CHECK_EVENTS' as check_type,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL - ' || COUNT(*) || ' orphaned events'
    END as result
FROM claims.claim_event ce
LEFT JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id
WHERE c.id IS NULL;

-- ==========================================================================================================
-- COMPLETION MESSAGE
-- ==========================================================================================================

SELECT 
    'DATABASE_CLEANUP_COMPLETE' as status,
    'Database has been cleaned and is ready for fresh ingestion' as message,
    NOW() as completion_time;
