-- ==========================================================================================================
-- DIAGNOSTIC SCRIPT FOR MATERIALIZED VIEWS
-- ==========================================================================================================

-- Check if materialized views exist and their row counts
SELECT 
    schemaname,
    matviewname,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||matviewname)) as size,
    (SELECT count(*) FROM pg_catalog.pg_class c WHERE c.relname = matviewname) as exists
FROM pg_matviews 
WHERE schemaname = 'claims' AND matviewname LIKE 'mv_%'
ORDER BY matviewname;

-- Check row counts in materialized views
SELECT 'mv_balance_amount_summary' as view_name, COUNT(*) as row_count FROM claims.mv_balance_amount_summary
UNION ALL
SELECT 'mv_remittance_advice_summary', COUNT(*) FROM claims.mv_remittance_advice_summary
UNION ALL
SELECT 'mv_doctor_denial_summary', COUNT(*) FROM claims.mv_doctor_denial_summary
UNION ALL
SELECT 'mv_claims_monthly_agg', COUNT(*) FROM claims.mv_claims_monthly_agg
UNION ALL
SELECT 'mv_claim_details_complete', COUNT(*) FROM claims.mv_claim_details_complete
UNION ALL
SELECT 'mv_resubmission_cycles', COUNT(*) FROM claims.mv_resubmission_cycles
UNION ALL
SELECT 'mv_remittances_resubmission_activity_level', COUNT(*) FROM claims.mv_remittances_resubmission_activity_level
UNION ALL
SELECT 'mv_rejected_claims_summary', COUNT(*) FROM claims.mv_rejected_claims_summary
UNION ALL
SELECT 'mv_claim_summary_payerwise', COUNT(*) FROM claims.mv_claim_summary_payerwise
UNION ALL
SELECT 'mv_claim_summary_encounterwise', COUNT(*) FROM claims.mv_claim_summary_encounterwise;

-- Check row counts in base tables
SELECT 'claim_key' as table_name, COUNT(*) as row_count FROM claims.claim_key
UNION ALL
SELECT 'claim', COUNT(*) FROM claims.claim
UNION ALL
SELECT 'encounter', COUNT(*) FROM claims.encounter
UNION ALL
SELECT 'activity', COUNT(*) FROM claims.activity
UNION ALL
SELECT 'remittance_claim', COUNT(*) FROM claims.remittance_claim
UNION ALL
SELECT 'remittance_activity', COUNT(*) FROM claims.remittance_activity
UNION ALL
SELECT 'claim_event', COUNT(*) FROM claims.claim_event
UNION ALL
SELECT 'claim_status_timeline', COUNT(*) FROM claims.claim_status_timeline;

-- Check reference data tables
SELECT 'provider (ref)' as table_name, COUNT(*) as row_count FROM claims_ref.provider
UNION ALL
SELECT 'payer (ref)', COUNT(*) FROM claims_ref.payer
UNION ALL
SELECT 'facility (ref)', COUNT(*) FROM claims_ref.facility
UNION ALL
SELECT 'clinician (ref)', COUNT(*) FROM claims_ref.clinician
UNION ALL
SELECT 'denial_code (ref)', COUNT(*) FROM claims_ref.denial_code;

-- Test basic JOIN to see what's missing
SELECT 
    'claim_key to claim' as join_test,
    COUNT(DISTINCT ck.id) as claim_keys,
    COUNT(DISTINCT c.id) as claims_joined
FROM claims.claim_key ck
LEFT JOIN claims.claim c ON c.claim_key_id = ck.id;

SELECT 
    'claim to encounter' as join_test,
    COUNT(DISTINCT c.id) as claims,
    COUNT(DISTINCT e.id) as encounters_joined
FROM claims.claim c
LEFT JOIN claims.encounter e ON e.claim_id = c.id;

SELECT 
    'claim to activity' as join_test,
    COUNT(DISTINCT c.id) as claims,
    COUNT(DISTINCT a.id) as activities_joined
FROM claims.claim c
LEFT JOIN claims.activity a ON a.claim_id = c.id;

SELECT 
    'claim_key to remittance_claim' as join_test,
    COUNT(DISTINCT ck.id) as claim_keys,
    COUNT(DISTINCT rc.id) as remittance_claims_joined
FROM claims.claim_key ck
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id;

-- Check if ref_id columns are populated
SELECT 
    'claim.provider_ref_id' as field,
    COUNT(*) as total,
    COUNT(provider_ref_id) as populated,
    COUNT(*) - COUNT(provider_ref_id) as nulls
FROM claims.claim
UNION ALL
SELECT 
    'claim.payer_ref_id',
    COUNT(*),
    COUNT(payer_ref_id),
    COUNT(*) - COUNT(payer_ref_id)
FROM claims.claim
UNION ALL
SELECT 
    'encounter.facility_ref_id',
    COUNT(*),
    COUNT(facility_ref_id),
    COUNT(*) - COUNT(facility_ref_id)
FROM claims.encounter
UNION ALL
SELECT 
    'activity.clinician_ref_id',
    COUNT(*),
    COUNT(clinician_ref_id),
    COUNT(*) - COUNT(clinician_ref_id)
FROM claims.activity;

-- Sample data from first MV to see what it should contain
SELECT * FROM claims.mv_balance_amount_summary LIMIT 5;

