-- ==========================================================================================================
-- MATERIALIZED VIEWS INITIALIZATION SCRIPT
-- ==========================================================================================================
-- 
-- PURPOSE: Initialize all materialized views for sub-second report performance
-- 
-- PREREQUISITES:
-- 1. Database schema must be created (claims_unified_ddl_fresh.sql)
-- 2. Base tables must have data (claims, encounter, activity, remittance_claim, etc.)
-- 3. Reference data must be populated (payer, provider, facility, clinician)
--
-- HOW TO RUN:
-- Option 1 (psql):     psql -U claims_user -d claims -f initialize_materialized_views.sql
-- Option 2 (pgAdmin):  Open and execute this file in Query Tool
-- Option 3 (DBeaver):  Open and execute this file
--
-- EXECUTION TIME: ~5-15 minutes depending on data volume
--
-- ==========================================================================================================

\timing on
\echo '========================================='
\echo 'MATERIALIZED VIEWS INITIALIZATION'
\echo '========================================='

-- Step 1: Check if base tables have data
\echo ''
\echo '=== Step 1: Checking Base Tables ==='
SELECT 
    'claim_key' as table_name, COUNT(*) as row_count FROM claims.claim_key
UNION ALL SELECT 'claim', COUNT(*) FROM claims.claim
UNION ALL SELECT 'encounter', COUNT(*) FROM claims.encounter
UNION ALL SELECT 'activity', COUNT(*) FROM claims.activity
UNION ALL SELECT 'remittance_claim', COUNT(*) FROM claims.remittance_claim
UNION ALL SELECT 'remittance_activity', COUNT(*) FROM claims.remittance_activity
ORDER BY table_name;

-- Step 2: Check reference data
\echo ''
\echo '=== Step 2: Checking Reference Data ==='
SELECT 
    'provider' as table_name, COUNT(*) as row_count FROM claims_ref.provider
UNION ALL SELECT 'payer', COUNT(*) FROM claims_ref.payer
UNION ALL SELECT 'facility', COUNT(*) FROM claims_ref.facility
UNION ALL SELECT 'clinician', COUNT(*) FROM claims_ref.clinician
ORDER BY table_name;

-- If the above queries return 0, you need to load data first!

-- Step 3: Create materialized views
\echo ''
\echo '=== Step 3: Creating Materialized Views ==='

-- Include the full sub_second_materialized_views.sql here
\ir src/main/resources/db/reports_sql/sub_second_materialized_views.sql

-- Step 4: Verify materialized views were created
\echo ''
\echo '=== Step 4: Verifying Materialized Views ==='
SELECT 
    matviewname,
    pg_size_pretty(pg_total_relation_size('claims.'||matviewname)) as size
FROM pg_matviews 
WHERE schemaname = 'claims' AND matviewname LIKE 'mv_%'
ORDER BY matviewname;

-- Step 5: Check row counts
\echo ''
\echo '=== Step 5: Checking Materialized View Row Counts ==='
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

\echo ''
\echo '========================================='
\echo 'INITIALIZATION COMPLETE!'
\echo '========================================='
\echo ''
\echo 'Next Steps:'
\echo '1. Check the row counts above - they should match or be less than your base table counts'
\echo '2. If any MV has 0 rows, check the JOIN conditions or reference data population'
\echo '3. Set up a refresh schedule: SELECT refresh_report_mvs_subsecond();'
\echo '4. Test your reports - they should now return data!'
\echo ''

