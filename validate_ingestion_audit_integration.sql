-- =====================================================================================
-- INGESTION AUDIT INTEGRATION VALIDATION QUERIES
-- =====================================================================================
-- Use these queries to validate that the ingestion audit integration is working correctly
-- Run these after deployment to verify the implementation

-- =====================================================================================
-- 1. VERIFY INGESTION RUN TRACKING
-- =====================================================================================

-- Check if ingestion runs are being created
SELECT 
    COUNT(*) as total_runs,
    COUNT(CASE WHEN ended_at IS NOT NULL THEN 1 END) as completed_runs,
    COUNT(CASE WHEN ended_at IS NULL THEN 1 END) as active_runs,
    MIN(started_at) as earliest_run,
    MAX(started_at) as latest_run
FROM claims.ingestion_run 
WHERE started_at > NOW() - INTERVAL '24 hours';

-- Check recent ingestion runs with details
SELECT 
    id,
    profile,
    fetcher_name,
    acker_name,
    poll_reason,
    started_at,
    ended_at,
    files_discovered,
    files_pulled,
    files_processed_ok,
    files_failed,
    files_already,
    acks_sent,
    CASE 
        WHEN ended_at IS NULL THEN 'ACTIVE'
        WHEN ended_at IS NOT NULL THEN 'COMPLETED'
    END as status
FROM claims.ingestion_run 
WHERE started_at > NOW() - INTERVAL '2 hours'
ORDER BY started_at DESC
LIMIT 10;

-- =====================================================================================
-- 2. VERIFY FILE AUDIT TRACKING
-- =====================================================================================

-- Check if file audit records are being created
SELECT 
    COUNT(*) as total_file_audits,
    COUNT(CASE WHEN status = 1 THEN 1 END) as files_ok,
    COUNT(CASE WHEN status = 2 THEN 1 END) as files_failed,
    COUNT(CASE WHEN status = 0 THEN 1 END) as files_already,
    MIN(created_at) as earliest_audit,
    MAX(created_at) as latest_audit
FROM claims.ingestion_file_audit 
WHERE created_at > NOW() - INTERVAL '24 hours';

-- Check recent file audit records with details
SELECT 
    ifa.id,
    ifa.ingestion_run_id,
    ifa.ingestion_file_id,
    ifa.status,
    ifa.reason,
    ifa.error_class,
    ifa.error_message,
    ifa.validation_ok,
    ifa.parsed_claims,
    ifa.persisted_claims,
    ifa.parsed_activities,
    ifa.persisted_activities,
    ifa.verification_passed,
    ifa.created_at,
    ir.profile,
    ir.fetcher_name
FROM claims.ingestion_file_audit ifa
JOIN claims.ingestion_run ir ON ifa.ingestion_run_id = ir.id
WHERE ifa.created_at > NOW() - INTERVAL '2 hours'
ORDER BY ifa.created_at DESC
LIMIT 10;

-- =====================================================================================
-- 3. VERIFY KPI VIEW FUNCTIONALITY
-- =====================================================================================

-- Check if KPI view returns data
SELECT 
    hour_bucket,
    files_total,
    files_ok,
    files_fail,
    files_already,
    parsed_claims,
    persisted_claims,
    parsed_activities,
    persisted_activities,
    parsed_remit_claims,
    persisted_remit_claims,
    parsed_remit_activities,
    persisted_remit_activities,
    files_verified
FROM claims.v_ingestion_kpis 
WHERE hour_bucket > NOW() - INTERVAL '24 hours'
ORDER BY hour_bucket DESC
LIMIT 10;

-- Check KPI view data quality
SELECT 
    COUNT(*) as kpi_records,
    SUM(files_total) as total_files_processed,
    SUM(files_ok) as total_files_successful,
    SUM(files_fail) as total_files_failed,
    SUM(parsed_claims) as total_claims_parsed,
    SUM(persisted_claims) as total_claims_persisted,
    AVG(CASE WHEN files_total > 0 THEN (files_ok::float / files_total) * 100 ELSE 0 END) as avg_success_rate_percent
FROM claims.v_ingestion_kpis 
WHERE hour_bucket > NOW() - INTERVAL '24 hours';

-- =====================================================================================
-- 4. VERIFY ERROR LOGGING (EXISTING FUNCTIONALITY)
-- =====================================================================================

-- Check if error logging continues to work
SELECT 
    COUNT(*) as total_errors,
    COUNT(CASE WHEN retryable = true THEN 1 END) as retryable_errors,
    COUNT(CASE WHEN retryable = false THEN 1 END) as non_retryable_errors,
    MIN(occurred_at) as earliest_error,
    MAX(occurred_at) as latest_error
FROM claims.ingestion_error 
WHERE occurred_at > NOW() - INTERVAL '24 hours';

-- Check recent errors by stage
SELECT 
    stage,
    object_type,
    error_code,
    COUNT(*) as error_count,
    MAX(occurred_at) as latest_occurrence
FROM claims.ingestion_error 
WHERE occurred_at > NOW() - INTERVAL '24 hours'
GROUP BY stage, object_type, error_code
ORDER BY error_count DESC, latest_occurrence DESC
LIMIT 10;

-- =====================================================================================
-- 5. VERIFY DATA CONSISTENCY
-- =====================================================================================

-- Check for orphaned file audit records (should be 0)
SELECT COUNT(*) as orphaned_file_audits
FROM claims.ingestion_file_audit ifa
LEFT JOIN claims.ingestion_run ir ON ifa.ingestion_run_id = ir.id
WHERE ir.id IS NULL;

-- Check for orphaned file audit records without ingestion files (should be 0)
SELECT COUNT(*) as orphaned_file_audits_no_file
FROM claims.ingestion_file_audit ifa
LEFT JOIN claims.ingestion_file if ON ifa.ingestion_file_id = if.id
WHERE if.id IS NULL;

-- Check run statistics consistency
SELECT 
    ir.id,
    ir.files_processed_ok,
    ir.files_failed,
    ir.files_already,
    COUNT(CASE WHEN ifa.status = 1 THEN 1 END) as actual_files_ok,
    COUNT(CASE WHEN ifa.status = 2 THEN 1 END) as actual_files_failed,
    COUNT(CASE WHEN ifa.status = 0 THEN 1 END) as actual_files_already
FROM claims.ingestion_run ir
LEFT JOIN claims.ingestion_file_audit ifa ON ir.id = ifa.ingestion_run_id
WHERE ir.started_at > NOW() - INTERVAL '2 hours'
GROUP BY ir.id, ir.files_processed_ok, ir.files_failed, ir.files_already
HAVING 
    ir.files_processed_ok != COUNT(CASE WHEN ifa.status = 1 THEN 1 END) OR
    ir.files_failed != COUNT(CASE WHEN ifa.status = 2 THEN 1 END) OR
    ir.files_already != COUNT(CASE WHEN ifa.status = 0 THEN 1 END)
ORDER BY ir.started_at DESC;

-- =====================================================================================
-- 6. PERFORMANCE MONITORING QUERIES
-- =====================================================================================

-- Check average run duration
SELECT 
    AVG(EXTRACT(EPOCH FROM (ended_at - started_at))) as avg_run_duration_seconds,
    MIN(EXTRACT(EPOCH FROM (ended_at - started_at))) as min_run_duration_seconds,
    MAX(EXTRACT(EPOCH FROM (ended_at - started_at))) as max_run_duration_seconds,
    COUNT(*) as completed_runs
FROM claims.ingestion_run 
WHERE ended_at IS NOT NULL 
  AND started_at > NOW() - INTERVAL '24 hours';

-- Check files processed per run
SELECT 
    AVG(files_processed_ok + files_failed + files_already) as avg_files_per_run,
    MIN(files_processed_ok + files_failed + files_already) as min_files_per_run,
    MAX(files_processed_ok + files_failed + files_already) as max_files_per_run,
    COUNT(*) as total_runs
FROM claims.ingestion_run 
WHERE started_at > NOW() - INTERVAL '24 hours';

-- =====================================================================================
-- 7. TROUBLESHOOTING QUERIES
-- =====================================================================================

-- Find runs that are stuck (started but not ended for more than 1 hour)
SELECT 
    id,
    profile,
    fetcher_name,
    started_at,
    NOW() - started_at as duration_since_start,
    files_discovered,
    files_pulled,
    files_processed_ok,
    files_failed,
    files_already
FROM claims.ingestion_run 
WHERE ended_at IS NULL 
  AND started_at < NOW() - INTERVAL '1 hour'
ORDER BY started_at DESC;

-- Find runs with high failure rates
SELECT 
    ir.id,
    ir.started_at,
    ir.files_processed_ok,
    ir.files_failed,
    ir.files_already,
    CASE 
        WHEN (ir.files_processed_ok + ir.files_failed + ir.files_already) > 0 
        THEN (ir.files_failed::float / (ir.files_processed_ok + ir.files_failed + ir.files_already)) * 100 
        ELSE 0 
    END as failure_rate_percent
FROM claims.ingestion_run ir
WHERE ir.started_at > NOW() - INTERVAL '24 hours'
  AND ir.files_failed > 0
ORDER BY failure_rate_percent DESC, ir.started_at DESC
LIMIT 10;

-- =====================================================================================
-- EXPECTED RESULTS AFTER SUCCESSFUL IMPLEMENTATION
-- =====================================================================================

/*
After successful implementation, you should see:

1. INGESTION RUN TRACKING:
   - total_runs > 0 (runs are being created)
   - completed_runs > 0 (runs are being closed)
   - active_runs should be 0 or very low (most runs complete quickly)

2. FILE AUDIT TRACKING:
   - total_file_audits > 0 (file processing is being audited)
   - files_ok > 0 (successful files are being recorded)
   - files_failed >= 0 (failed files are being recorded if any)

3. KPI VIEW FUNCTIONALITY:
   - kpi_records > 0 (KPI view returns data)
   - total_files_processed > 0 (files are being processed)
   - avg_success_rate_percent > 0 (success rate is calculated)

4. ERROR LOGGING:
   - total_errors >= 0 (error logging continues to work)
   - No new error patterns related to audit operations

5. DATA CONSISTENCY:
   - orphaned_file_audits = 0 (no orphaned records)
   - orphaned_file_audits_no_file = 0 (all audits have valid file references)
   - No inconsistencies in run statistics

6. PERFORMANCE:
   - avg_run_duration_seconds < 60 (runs complete quickly)
   - avg_files_per_run > 0 (files are being processed per run)

If any of these expectations are not met, investigate the corresponding area.
*/
