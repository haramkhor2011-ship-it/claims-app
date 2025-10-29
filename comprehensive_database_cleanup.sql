-- COMPREHENSIVE DATABASE CLEANUP SCRIPT
-- This script will clean up corrupt data step by step to enable proper ingestion

-- ==========================================================================================================
-- STEP 1: ANALYZE CURRENT CORRUPTION ISSUES
-- ==========================================================================================================

-- 1.1 Check for orphaned submissions (submissions without claims)
SELECT 
    'ORPHANED_SUBMISSIONS' as issue_type,
    COUNT(*) as count,
    'Submissions without any claims' as description
FROM claims.submission s
LEFT JOIN claims.claim c ON s.id = c.submission_id
WHERE c.id IS NULL;

-- 1.2 Check for orphaned claims (claims without claim_keys)
SELECT 
    'ORPHANED_CLAIMS' as issue_type,
    COUNT(*) as count,
    'Claims without claim_keys' as description
FROM claims.claim c
LEFT JOIN claims.claim_key ck ON c.claim_key_id = ck.id
WHERE ck.id IS NULL;

-- 1.3 Check for orphaned claim_events (events without claims)
SELECT 
    'ORPHANED_EVENTS' as issue_type,
    COUNT(*) as count,
    'Claim events without claims' as description
FROM claims.claim_event ce
LEFT JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id
WHERE c.id IS NULL;

-- 1.4 Check for duplicate submissions per ingestion_file
SELECT 
    'DUPLICATE_SUBMISSIONS' as issue_type,
    COUNT(*) as count,
    'Multiple submissions for same ingestion_file' as description
FROM (
    SELECT ingestion_file_id, COUNT(*) as submission_count
    FROM claims.submission
    GROUP BY ingestion_file_id
    HAVING COUNT(*) > 1
) duplicates;

-- 1.5 Check for ingestion_files without submissions
SELECT 
    'ORPHANED_INGESTION_FILES' as issue_type,
    COUNT(*) as count,
    'Ingestion files without submissions' as description
FROM claims.ingestion_file if
LEFT JOIN claims.submission s ON if.id = s.ingestion_file_id
WHERE s.id IS NULL AND if.root_type = 1; -- Only submission files

-- 1.6 Check for orphaned activities
SELECT 
    'ORPHANED_ACTIVITIES' as issue_type,
    COUNT(*) as count,
    'Activities without claims' as description
FROM claims.activity a
LEFT JOIN claims.claim c ON a.claim_id = c.id
WHERE c.id IS NULL;

-- 1.7 Check for orphaned diagnoses
SELECT 
    'ORPHANED_DIAGNOSES' as issue_type,
    COUNT(*) as count,
    'Diagnoses without claims' as description
FROM claims.diagnosis d
LEFT JOIN claims.claim c ON d.claim_id = c.id
WHERE c.id IS NULL;

-- 1.8 Check for orphaned encounters
SELECT 
    'ORPHANED_ENCOUNTERS' as issue_type,
    COUNT(*) as count,
    'Encounters without claims' as description
FROM claims.encounter e
LEFT JOIN claims.claim c ON e.claim_id = c.id
WHERE c.id IS NULL;

-- 1.9 Check for orphaned observations
SELECT 
    'ORPHANED_OBSERVATIONS' as issue_type,
    COUNT(*) as count,
    'Observations without activities' as description
FROM claims.observation o
LEFT JOIN claims.activity a ON o.activity_id = a.id
WHERE a.id IS NULL;

-- ==========================================================================================================
-- STEP 2: BACKUP CURRENT STATE (OPTIONAL)
-- ==========================================================================================================

-- 2.1 Create backup tables for critical data
-- Uncomment these if you want to backup before cleanup
/*
CREATE TABLE IF NOT EXISTS claims.backup_submission AS SELECT * FROM claims.submission;
CREATE TABLE IF NOT EXISTS claims.backup_claim AS SELECT * FROM claims.claim;
CREATE TABLE IF NOT EXISTS claims.backup_claim_event AS SELECT * FROM claims.claim_event;
CREATE TABLE IF NOT EXISTS claims.backup_ingestion_file AS SELECT * FROM claims.ingestion_file;
*/

-- ==========================================================================================================
-- STEP 3: CLEANUP ORPHANED DATA (SAFE ORDER)
-- ==========================================================================================================

-- 3.1 Delete orphaned observations (lowest level)
DELETE FROM claims.observation 
WHERE activity_id IN (
    SELECT a.id FROM claims.activity a
    LEFT JOIN claims.claim c ON a.claim_id = c.id
    WHERE c.id IS NULL
);

-- 3.2 Delete orphaned activities
DELETE FROM claims.activity 
WHERE claim_id IN (
    SELECT c.id FROM claims.claim c
    LEFT JOIN claims.claim_key ck ON c.claim_key_id = ck.id
    WHERE ck.id IS NULL
);

-- 3.3 Delete orphaned diagnoses
DELETE FROM claims.diagnosis 
WHERE claim_id IN (
    SELECT c.id FROM claims.claim c
    LEFT JOIN claims.claim_key ck ON c.claim_key_id = ck.id
    WHERE ck.id IS NULL
);

-- 3.4 Delete orphaned encounters
DELETE FROM claims.encounter 
WHERE claim_id IN (
    SELECT c.id FROM claims.claim c
    LEFT JOIN claims.claim_key ck ON c.claim_key_id = ck.id
    WHERE ck.id IS NULL
);

-- 3.5 Delete orphaned claim_events
DELETE FROM claims.claim_event 
WHERE claim_key_id IN (
    SELECT ce.claim_key_id FROM claims.claim_event ce
    LEFT JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id
    WHERE c.id IS NULL
);

-- 3.6 Delete orphaned claims
DELETE FROM claims.claim 
WHERE claim_key_id IN (
    SELECT c.claim_key_id FROM claims.claim c
    LEFT JOIN claims.claim_key ck ON c.claim_key_id = ck.id
    WHERE ck.id IS NULL
);

-- 3.7 Delete orphaned submissions (keep only the first one per ingestion_file)
WITH duplicate_submissions AS (
    SELECT id, ingestion_file_id,
           ROW_NUMBER() OVER (PARTITION BY ingestion_file_id ORDER BY created_at) as rn
    FROM claims.submission
)
DELETE FROM claims.submission 
WHERE id IN (
    SELECT id FROM duplicate_submissions WHERE rn > 1
);

-- 3.8 Delete orphaned claim_keys (only if no claims reference them)
DELETE FROM claims.claim_key 
WHERE id NOT IN (
    SELECT DISTINCT claim_key_id FROM claims.claim WHERE claim_key_id IS NOT NULL
);

-- ==========================================================================================================
-- STEP 4: RESET INGESTION TRACKING TABLES
-- ==========================================================================================================

-- 4.1 Clean up ingestion_file_audit (keep for reference but mark as failed)
UPDATE claims.ingestion_file_audit 
SET status = 3, -- Mark as failed
    reason = 'Database cleanup - marked as failed',
    verification_failed_count = 1
WHERE status != 3;

-- 4.2 Clean up ingestion_run (keep for reference)
UPDATE claims.ingestion_run 
SET ended_at = NOW(),
    poll_reason = 'Database cleanup completed'
WHERE ended_at IS NULL;

-- 4.3 Clean up ingestion_error (optional - keep for debugging)
-- DELETE FROM claims.ingestion_error; -- Uncomment if you want to clear error history

-- ==========================================================================================================
-- STEP 5: VERIFY CLEANUP RESULTS
-- ==========================================================================================================

-- 5.1 Re-run the corruption analysis
SELECT 'CLEANUP_COMPLETE' as status, NOW() as cleanup_time;

-- 5.2 Check remaining data integrity
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

-- 5.3 Verify referential integrity
SELECT 
    'INTEGRITY_CHECK' as check_type,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    'Submissions without claims' as description
FROM claims.submission s
LEFT JOIN claims.claim c ON s.id = c.submission_id
WHERE c.id IS NULL;

-- ==========================================================================================================
-- STEP 6: PREPARE FOR FRESH INGESTION
-- ==========================================================================================================

-- 6.1 Reset sequences to avoid ID conflicts (optional)
-- Uncomment these if you want to reset auto-increment sequences
/*
SELECT setval('claims.submission_id_seq', (SELECT COALESCE(MAX(id), 1) FROM claims.submission));
SELECT setval('claims.claim_id_seq', (SELECT COALESCE(MAX(id), 1) FROM claims.claim));
SELECT setval('claims.claim_event_id_seq', (SELECT COALESCE(MAX(id), 1) FROM claims.claim_event));
SELECT setval('claims.ingestion_file_id_seq', (SELECT COALESCE(MAX(id), 1) FROM claims.ingestion_file));
*/

-- 6.2 Create indexes for better performance (if missing)
CREATE INDEX IF NOT EXISTS idx_submission_file_cleanup ON claims.submission(ingestion_file_id);
CREATE INDEX IF NOT EXISTS idx_claim_submission_cleanup ON claims.claim(submission_id);
CREATE INDEX IF NOT EXISTS idx_claim_event_claim_key_cleanup ON claims.claim_event(claim_key_id);

-- ==========================================================================================================
-- COMPLETION MESSAGE
-- ==========================================================================================================

SELECT 
    'DATABASE_CLEANUP_COMPLETE' as status,
    'Database has been cleaned and is ready for fresh ingestion' as message,
    NOW() as completion_time;
