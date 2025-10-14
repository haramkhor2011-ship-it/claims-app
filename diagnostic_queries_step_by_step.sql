-- ==========================================================================================================
-- STEP-BY-STEP DIAGNOSTIC QUERIES FOR MATERIALIZED VIEWS
-- ==========================================================================================================
-- Run these queries ONE AT A TIME and share the results
-- ==========================================================================================================

-- ==========================================================================================================
-- QUERY 1: Check if Materialized Views Exist
-- ==========================================================================================================
-- This tells us if the materialized views were created in the database

SELECT 
    schemaname,
    matviewname,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||matviewname)) as size
FROM pg_matviews 
WHERE schemaname = 'claims' AND matviewname LIKE 'mv_%'
ORDER BY matviewname;

-- EXPECTED: Should show 10 materialized views
-- IF EMPTY: Materialized views were never created - need to run sub_second_materialized_views.sql
-- SHARE THIS OUTPUT FIRST, THEN I'LL GIVE YOU QUERY 2

-- ==========================================================================================================
-- QUERY 2: Check Base Table Row Counts (Run this ONLY AFTER sharing Query 1 results)
-- ==========================================================================================================

SELECT 
    'claim_key' as table_name, COUNT(*) as row_count FROM claims.claim_key
UNION ALL SELECT 'claim', COUNT(*) FROM claims.claim
UNION ALL SELECT 'encounter', COUNT(*) FROM claims.encounter
UNION ALL SELECT 'activity', COUNT(*) FROM claims.activity
UNION ALL SELECT 'remittance_claim', COUNT(*) FROM claims.remittance_claim
UNION ALL SELECT 'remittance_activity', COUNT(*) FROM claims.remittance_activity
UNION ALL SELECT 'claim_event', COUNT(*) FROM claims.claim_event
UNION ALL SELECT 'claim_status_timeline', COUNT(*) FROM claims.claim_status_timeline
ORDER BY table_name;

-- EXPECTED: Should show row counts > 0 for each table
-- IF ALL ZERO: No data has been ingested yet
-- WAIT FOR INSTRUCTION BEFORE RUNNING THIS

-- ==========================================================================================================
-- QUERY 3: Check Reference Data (Run this ONLY AFTER sharing Query 2 results)
-- ==========================================================================================================

SELECT 
    'provider' as table_name, COUNT(*) as row_count FROM claims_ref.provider
UNION ALL SELECT 'payer', COUNT(*) FROM claims_ref.payer
UNION ALL SELECT 'facility', COUNT(*) FROM claims_ref.facility
UNION ALL SELECT 'clinician', COUNT(*) FROM claims_ref.clinician
UNION ALL SELECT 'denial_code', COUNT(*) FROM claims_ref.denial_code
ORDER BY table_name;

-- EXPECTED: Should show row counts > 0 for reference tables
-- IF ZERO: Reference data not loaded
-- WAIT FOR INSTRUCTION BEFORE RUNNING THIS

-- ==========================================================================================================
-- QUERY 4: Check Materialized View Row Counts (Run ONLY if Query 1 showed MVs exist)
-- ==========================================================================================================

SELECT 'mv_balance_amount_summary' as view_name, COUNT(*) as row_count FROM claims.mv_balance_amount_summary
UNION ALL SELECT 'mv_remittance_advice_summary', COUNT(*) FROM claims.mv_remittance_advice_summary
UNION ALL SELECT 'mv_doctor_denial_summary', COUNT(*) FROM claims.mv_doctor_denial_summary
UNION ALL SELECT 'mv_claims_monthly_agg', COUNT(*) FROM claims.mv_claims_monthly_agg
UNION ALL SELECT 'mv_claim_details_complete', COUNT(*) FROM claims.mv_claim_details_complete
UNION ALL SELECT 'mv_resubmission_cycles', COUNT(*) FROM claims.mv_resubmission_cycles
UNION ALL SELECT 'mv_remittances_resubmission_activity_level', COUNT(*) FROM claims.mv_remittances_resubmission_activity_level
UNION ALL SELECT 'mv_rejected_claims_summary', COUNT(*) FROM claims.mv_rejected_claims_summary
UNION ALL SELECT 'mv_claim_summary_payerwise', COUNT(*) FROM claims.mv_claim_summary_payerwise
UNION ALL SELECT 'mv_claim_summary_encounterwise', COUNT(*) FROM claims.mv_claim_summary_encounterwise
ORDER BY view_name;

-- EXPECTED: Row counts should be > 0 if base tables have data
-- IF ALL ZERO: MVs exist but have no data (JOIN or data issue)
-- WAIT FOR INSTRUCTION BEFORE RUNNING THIS

-- ==========================================================================================================
-- QUERY 5: Check JOIN Relationships (Run ONLY if instructed)
-- ==========================================================================================================

SELECT 
    'claim_key to claim' as join_test,
    (SELECT COUNT(*) FROM claims.claim_key) as left_table_count,
    COUNT(DISTINCT ck.id) as claim_keys_with_claims,
    COUNT(DISTINCT c.id) as claims_joined
FROM claims.claim_key ck
LEFT JOIN claims.claim c ON c.claim_key_id = ck.id;

-- EXPECTED: claim_keys_with_claims should equal left_table_count
-- IF MISMATCH: JOIN condition broken
-- WAIT FOR INSTRUCTION BEFORE RUNNING THIS

-- ==========================================================================================================
-- QUERY 6: Check ref_id Population (Run ONLY if instructed)
-- ==========================================================================================================

SELECT 
    'claim.provider_ref_id' as field,
    COUNT(*) as total,
    COUNT(provider_ref_id) as populated,
    COUNT(*) - COUNT(provider_ref_id) as nulls,
    ROUND(100.0 * COUNT(provider_ref_id) / NULLIF(COUNT(*), 0), 2) as populated_pct
FROM claims.claim
UNION ALL
SELECT 
    'claim.payer_ref_id',
    COUNT(*),
    COUNT(payer_ref_id),
    COUNT(*) - COUNT(payer_ref_id),
    ROUND(100.0 * COUNT(payer_ref_id) / NULLIF(COUNT(*), 0), 2)
FROM claims.claim
UNION ALL
SELECT 
    'encounter.facility_ref_id',
    COUNT(*),
    COUNT(facility_ref_id),
    COUNT(*) - COUNT(facility_ref_id),
    ROUND(100.0 * COUNT(facility_ref_id) / NULLIF(COUNT(*), 0), 2)
FROM claims.encounter
UNION ALL
SELECT 
    'activity.clinician_ref_id',
    COUNT(*),
    COUNT(clinician_ref_id),
    COUNT(*) - COUNT(clinician_ref_id),
    ROUND(100.0 * COUNT(clinician_ref_id) / NULLIF(COUNT(*), 0), 2)
FROM claims.activity;

-- EXPECTED: populated_pct should be high (> 80%)
-- IF LOW: Reference ID linking is broken - auto-insert may not be working
-- WAIT FOR INSTRUCTION BEFORE RUNNING THIS

-- ==========================================================================================================
-- QUERY 7: Sample Data from First MV (Run ONLY if MV exists and has data)
-- ==========================================================================================================

SELECT 
    claim_key_id,
    claim_id,
    initial_net,
    total_payment,
    total_denied,
    pending_amount,
    remittance_count,
    resubmission_count,
    current_status
FROM claims.mv_balance_amount_summary 
LIMIT 5;

-- EXPECTED: Should show sample rows with data
-- WAIT FOR INSTRUCTION BEFORE RUNNING THIS

-- ==========================================================================================================
-- INSTRUCTIONS:
-- ==========================================================================================================
-- 1. Run QUERY 1 first
-- 2. Share the complete output (including if it's empty)
-- 3. Wait for next instruction
-- 4. DO NOT run all queries at once - we need to diagnose step by step
-- ==========================================================================================================

