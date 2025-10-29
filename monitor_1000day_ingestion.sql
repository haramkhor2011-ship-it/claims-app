-- MONITORING SCRIPT FOR 1000-DAY INGESTION TEST
-- Run this script periodically to monitor ingestion progress

-- ==========================================================================================================
-- SECTION 1: OVERALL INGESTION STATUS
-- ==========================================================================================================

SELECT 
    'OVERALL_STATUS' as metric_type,
    COUNT(*) as total_files,
    COUNT(CASE WHEN status = 1 THEN 1 END) as processed_successfully,
    COUNT(CASE WHEN status = 2 THEN 1 END) as processing_in_progress,
    COUNT(CASE WHEN status = 3 THEN 1 END) as failed,
    COUNT(CASE WHEN status = 4 THEN 1 END) as skipped,
    ROUND(COUNT(CASE WHEN status = 1 THEN 1 END) * 100.0 / COUNT(*), 2) as success_rate_percent
FROM claims.ingestion_file_audit;

-- ==========================================================================================================
-- SECTION 2: RECENT INGESTION ACTIVITY (LAST 10 MINUTES)
-- ==========================================================================================================

SELECT 
    'RECENT_ACTIVITY' as metric_type,
    COUNT(*) as files_processed_last_10min,
    COUNT(CASE WHEN status = 1 THEN 1 END) as successful_last_10min,
    COUNT(CASE WHEN status = 3 THEN 1 END) as failed_last_10min,
    MIN(created_at) as earliest_processing,
    MAX(created_at) as latest_processing
FROM claims.ingestion_file_audit
WHERE created_at > NOW() - INTERVAL '10 minutes';

-- ==========================================================================================================
-- SECTION 3: PROCESSING SPEED METRICS
-- ==========================================================================================================

SELECT 
    'PROCESSING_SPEED' as metric_type,
    COUNT(*) as total_files,
    AVG(duration_ms) as avg_duration_ms,
    MIN(duration_ms) as min_duration_ms,
    MAX(duration_ms) as max_duration_ms,
    AVG(file_size_bytes) as avg_file_size_bytes,
    AVG(parsed_claims) as avg_claims_per_file,
    AVG(parsed_activities) as avg_activities_per_file
FROM claims.ingestion_file_audit
WHERE status = 1 AND duration_ms IS NOT NULL;

-- ==========================================================================================================
-- SECTION 4: DATA VOLUME METRICS
-- ==========================================================================================================

SELECT 
    'DATA_VOLUME' as metric_type,
    COUNT(DISTINCT s.id) as total_submissions,
    COUNT(DISTINCT c.id) as total_claims,
    COUNT(DISTINCT ce.id) as total_claim_events,
    COUNT(DISTINCT r.id) as total_remittances,
    COUNT(DISTINCT rc.id) as total_remittance_claims
FROM claims.submission s
LEFT JOIN claims.claim c ON s.id = c.submission_id
LEFT JOIN claims.claim_event ce ON c.claim_key_id = ce.claim_key_id
LEFT JOIN claims.remittance r ON s.ingestion_file_id = r.ingestion_file_id
LEFT JOIN claims.remittance_claim rc ON r.id = rc.remittance_id;

-- ==========================================================================================================
-- SECTION 5: ERROR ANALYSIS
-- ==========================================================================================================

SELECT 
    'ERROR_ANALYSIS' as metric_type,
    reason,
    COUNT(*) as error_count,
    MAX(created_at) as latest_error
FROM claims.ingestion_file_audit
WHERE status = 3
GROUP BY reason
ORDER BY error_count DESC
LIMIT 10;

-- ==========================================================================================================
-- SECTION 6: INGESTION RUN STATUS
-- ==========================================================================================================

SELECT 
    'INGESTION_RUNS' as metric_type,
    id,
    profile,
    started_at,
    ended_at,
    files_discovered,
    files_pulled,
    files_processed_ok,
    files_processed_fail,
    poll_reason,
    CASE 
        WHEN ended_at IS NULL THEN 'RUNNING'
        ELSE 'COMPLETED'
    END as status
FROM claims.ingestion_run
ORDER BY started_at DESC
LIMIT 5;

-- ==========================================================================================================
-- SECTION 7: PERFORMANCE BY PAYER
-- ==========================================================================================================

SELECT 
    'PERFORMANCE_BY_PAYER' as metric_type,
    p.name as payer_name,
    COUNT(DISTINCT s.id) as submission_count,
    COUNT(DISTINCT c.id) as claim_count,
    AVG(ifa.duration_ms) as avg_duration_ms,
    SUM(ifa.parsed_claims) as total_claims_processed
FROM claims.submission s
JOIN claims.claim c ON s.id = c.submission_id
JOIN claims_ref.payer p ON c.payer_id = p.id
JOIN claims.ingestion_file_audit ifa ON s.ingestion_file_id = ifa.ingestion_file_id
WHERE ifa.status = 1
GROUP BY p.id, p.name
ORDER BY total_claims_processed DESC
LIMIT 10;

-- ==========================================================================================================
-- SECTION 8: VERIFICATION SUCCESS RATE
-- ==========================================================================================================

SELECT 
    'VERIFICATION_STATUS' as metric_type,
    COUNT(*) as total_files,
    COUNT(CASE WHEN verification_failures = 0 THEN 1 END) as verification_passed,
    COUNT(CASE WHEN verification_failures > 0 THEN 1 END) as verification_failed,
    ROUND(COUNT(CASE WHEN verification_failures = 0 THEN 1 END) * 100.0 / COUNT(*), 2) as verification_success_rate
FROM claims.ingestion_file_audit
WHERE status = 1;

-- ==========================================================================================================
-- SECTION 9: MEMORY AND THREAD USAGE (if available)
-- ==========================================================================================================

-- This section would show JVM metrics if Prometheus is enabled
-- For now, we'll show database connection usage
SELECT 
    'DATABASE_CONNECTIONS' as metric_type,
    COUNT(*) as active_connections,
    'Check application logs for JVM metrics' as note
FROM pg_stat_activity
WHERE datname = 'claims';

-- ==========================================================================================================
-- SECTION 10: ESTIMATED COMPLETION TIME
-- ==========================================================================================================

WITH recent_stats AS (
    SELECT 
        COUNT(*) as files_processed,
        AVG(duration_ms) as avg_duration_ms,
        MIN(created_at) as start_time,
        MAX(created_at) as end_time
    FROM claims.ingestion_file_audit
    WHERE created_at > NOW() - INTERVAL '1 hour'
    AND status = 1
),
total_remaining AS (
    SELECT 
        COUNT(*) as remaining_files
    FROM claims.ingestion_file_audit
    WHERE status IN (2, 4) -- processing or skipped
)
SELECT 
    'ESTIMATED_COMPLETION' as metric_type,
    rs.files_processed as files_processed_last_hour,
    rs.avg_duration_ms,
    tr.remaining_files,
    CASE 
        WHEN rs.files_processed > 0 THEN 
            ROUND(tr.remaining_files * rs.avg_duration_ms / 1000.0 / 60.0, 2)
        ELSE NULL
    END as estimated_minutes_remaining,
    CASE 
        WHEN rs.files_processed > 0 THEN 
            NOW() + INTERVAL '1 minute' * (tr.remaining_files * rs.avg_duration_ms / 1000.0 / 60.0)
        ELSE NULL
    END as estimated_completion_time
FROM recent_stats rs, total_remaining tr;
