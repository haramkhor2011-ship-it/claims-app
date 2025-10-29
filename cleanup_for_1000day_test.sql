-- COMPREHENSIVE CLEANUP SCRIPT FOR 1000-DAY INGESTION TEST
-- This script will clean all core tables and prepare for fresh ingestion
-- Run this before starting the 1000-day ingestion test

-- ==========================================================================================================
-- SECTION 1: BACKUP CRITICAL DATA (OPTIONAL - FOR SAFETY)
-- ==========================================================================================================

-- Create backup tables with timestamp
CREATE TABLE IF NOT EXISTS claims.backup_ingestion_file_audit_20251025 AS
SELECT * FROM claims.ingestion_file_audit WHERE created_at > NOW() - INTERVAL '7 days';

CREATE TABLE IF NOT EXISTS claims.backup_ingestion_run_20251025 AS
SELECT * FROM claims.ingestion_run WHERE started_at > NOW() - INTERVAL '7 days';

SELECT 'BACKUP_CREATED' as action, NOW() as timestamp;

-- ==========================================================================================================
-- SECTION 2: CLEAN UP INGESTION TRACKING TABLES
-- ==========================================================================================================

-- Count records to be cleaned
SELECT 'INGESTION_AUDIT_RECORDS_TO_CLEAN' as action, COUNT(*) as count
FROM claims.ingestion_file_audit;

SELECT 'INGESTION_RUN_RECORDS_TO_CLEAN' as action, COUNT(*) as count
FROM claims.ingestion_run;

-- Clean ingestion tracking tables
DELETE FROM claims.ingestion_file_audit;
DELETE FROM claims.ingestion_run;

SELECT 'INGESTION_TRACKING_CLEANED' as action, 'All tracking records removed' as note;

-- ==========================================================================================================
-- SECTION 3: CLEAN UP CORE CLAIMS DATA
-- ==========================================================================================================

-- Count core data to be cleaned
SELECT 'SUBMISSIONS_TO_CLEAN' as action, COUNT(*) as count FROM claims.submission;
SELECT 'CLAIMS_TO_CLEAN' as action, COUNT(*) as count FROM claims.claim;
SELECT 'CLAIM_EVENTS_TO_CLEAN' as action, COUNT(*) as count FROM claims.claim_event;
SELECT 'CLAIM_KEYS_TO_CLEAN' as action, COUNT(*) as count FROM claims.claim_key;
SELECT 'REMITTANCES_TO_CLEAN' as action, COUNT(*) as count FROM claims.remittance;
SELECT 'REMITTANCE_CLAIMS_TO_CLEAN' as action, COUNT(*) as count FROM claims.remittance_claim;

-- Clean core claims data in proper order (respecting foreign keys)
DELETE FROM claims.claim_event_activity;
DELETE FROM claims.claim_event;
DELETE FROM claims.remittance_claim;
DELETE FROM claims.remittance;
DELETE FROM claims.claim;
DELETE FROM claims.submission;
DELETE FROM claims.claim_key;
DELETE FROM claims.ingestion_file;

SELECT 'CORE_DATA_CLEANED' as action, 'All core claims data removed' as note;

-- ==========================================================================================================
-- SECTION 4: CLEAN UP REFERENCE DATA (OPTIONAL - UNCOMMENT IF NEEDED)
-- ==========================================================================================================

-- Uncomment these lines if you want to clean reference data too
-- DELETE FROM claims_ref.facility;
-- DELETE FROM claims_ref.payer;
-- DELETE FROM claims_ref.provider;
-- DELETE FROM claims_ref.diagnosis_code;
-- DELETE FROM claims_ref.activity_code;
-- DELETE FROM claims_ref.denial_code;

-- SELECT 'REFERENCE_DATA_CLEANED' as action, 'All reference data removed' as note;

-- ==========================================================================================================
-- SECTION 5: RESET SEQUENCES (OPTIONAL - FOR CLEAN IDS)
-- ==========================================================================================================

-- Reset sequences to start from 1 (optional - uncomment if needed)
-- ALTER SEQUENCE claims.ingestion_file_id_seq RESTART WITH 1;
-- ALTER SEQUENCE claims.submission_id_seq RESTART WITH 1;
-- ALTER SEQUENCE claims.claim_id_seq RESTART WITH 1;
-- ALTER SEQUENCE claims.claim_key_id_seq RESTART WITH 1;
-- ALTER SEQUENCE claims.claim_event_id_seq RESTART WITH 1;
-- ALTER SEQUENCE claims.remittance_id_seq RESTART WITH 1;

-- SELECT 'SEQUENCES_RESET' as action, 'All sequences reset to 1' as note;

-- ==========================================================================================================
-- SECTION 6: VERIFY CLEANUP RESULTS
-- ==========================================================================================================

-- Verify all tables are empty
SELECT
    'VERIFICATION_SUBMISSIONS' as table_name,
    COUNT(*) as count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM claims.submission
UNION ALL
SELECT
    'VERIFICATION_CLAIMS' as table_name,
    COUNT(*) as count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM claims.claim
UNION ALL
SELECT
    'VERIFICATION_CLAIM_EVENTS' as table_name,
    COUNT(*) as count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM claims.claim_event
UNION ALL
SELECT
    'VERIFICATION_CLAIM_KEYS' as table_name,
    COUNT(*) as count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM claims.claim_key
UNION ALL
SELECT
    'VERIFICATION_REMITTANCES' as table_name,
    COUNT(*) as count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM claims.remittance
UNION ALL
SELECT
    'VERIFICATION_REMITTANCE_CLAIMS' as table_name,
    COUNT(*) as count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM claims.remittance_claim
UNION ALL
SELECT
    'VERIFICATION_INGESTION_FILES' as table_name,
    COUNT(*) as count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM claims.ingestion_file
UNION ALL
SELECT
    'VERIFICATION_INGESTION_AUDIT' as table_name,
    COUNT(*) as count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM claims.ingestion_file_audit
UNION ALL
SELECT
    'VERIFICATION_INGESTION_RUNS' as table_name,
    COUNT(*) as count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM claims.ingestion_run;

-- ==========================================================================================================
-- SECTION 7: DATABASE STATISTICS UPDATE
-- ==========================================================================================================

-- Update database statistics for better performance
ANALYZE claims.submission;
ANALYZE claims.claim;
ANALYZE claims.claim_key;
ANALYZE claims.claim_event;
ANALYZE claims.remittance;
ANALYZE claims.remittance_claim;
ANALYZE claims.ingestion_file;
ANALYZE claims.ingestion_file_audit;
ANALYZE claims.ingestion_run;

SELECT 'STATISTICS_UPDATED' as action, 'Database statistics refreshed' as note;

-- ==========================================================================================================
-- COMPLETION MESSAGE
-- ==========================================================================================================

SELECT
    'CLEANUP_COMPLETE' as status,
    'Database is now clean and ready for 1000-day ingestion test' as message,
    NOW() as completion_time,
    'Next step: Start ingestion with 1000-day configuration' as next_action;
