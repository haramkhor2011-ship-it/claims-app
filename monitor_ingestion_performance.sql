-- Real-time ingestion monitoring dashboard
SELECT 
    ir.id as run_id,
    ir.started_at,
    ir.ended_at,
    EXTRACT(EPOCH FROM (ir.ended_at - ir.started_at)) as duration_seconds,
    ir.files_processed_ok,
    ir.files_failed,
    ir.files_already,
    ROUND(ir.files_processed_ok::numeric / NULLIF(EXTRACT(EPOCH FROM (ir.ended_at - ir.started_at)), 0) * 60, 2) as files_per_minute,
    COUNT(ifa.id) as total_files_audited,
    ROUND(AVG(ifa.processing_duration_ms)) as avg_processing_ms,
    MAX(ifa.processing_duration_ms) as max_processing_ms,
    SUM(ifa.parsed_claims) as total_parsed_claims,
    SUM(ifa.persisted_claims) as total_persisted_claims,
    ROUND(100.0 * SUM(ifa.persisted_claims)::numeric / NULLIF(SUM(ifa.parsed_claims), 0), 2) as persistence_success_rate,
    SUM(ifa.parsed_activities) as total_parsed_activities,
    SUM(ifa.persisted_activities) as total_persisted_activities,
    COUNT(*) FILTER (WHERE ifa.verification_passed = false) as verification_failures,
    COUNT(*) FILTER (WHERE ifa.verification_passed = true) as verification_passes
FROM claims.ingestion_run ir
LEFT JOIN claims.ingestion_file_audit ifa ON ifa.ingestion_run_id = ir.id
WHERE ir.id = (SELECT MAX(id) FROM claims.ingestion_run)
GROUP BY ir.id, ir.started_at, ir.ended_at, ir.files_processed_ok, ir.files_failed, ir.files_already;
