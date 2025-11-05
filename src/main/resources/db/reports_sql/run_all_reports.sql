-- ==========================================================================================================
-- RUN ALL REPORTS: Create materialized views first, then report views (correct dependency order)
-- ==========================================================================================================
-- How to run (from repo root):
--   psql -U <user> -d <db> -f src/main/resources/db/reports_sql/run_all_reports.sql
--
-- Prerequisites (already in this repo if you need them):
-- - Core schemas/tables exist and have data (see src/main/resources/db/claims_unified_ddl_fresh.sql)
-- - Reference data exists (see src/main/resources/db/claims_ref_ddl.sql)
--
-- What this script does:
-- 1) Creates/updates all mv_* used by reports (sub-second views)
-- 2) Creates/updates all v_* report views
-- 3) Refreshes all mv_* once
-- 4) Prints quick row-count checks
-- ==========================================================================================================

\timing on
\echo '========================================='
\echo 'RUNNING: All Report SQL (MVs -> Views)'
\echo '========================================='

-- Optional: Ensure schemas exist (safe to re-run if needed)
-- \ir src/main/resources/db/claims_ref_ddl.sql
-- \ir src/main/resources/db/claims_unified_ddl_fresh.sql

\echo ''
\echo '=== Step 1: Creating Materialized Views (sub-second) ==='
\ir src/main/resources/db/reports_sql/sub_second_materialized_views.sql

\echo ''
\echo '=== Step 2: Creating Report Views (v_*) ==='
-- Single script that defines all report v_* views
\ir docker/db-init/07-report-views.sql

\echo ''
\echo '=== Step 3: One-time refresh of all materialized views ==='
SELECT refresh_report_mvs_subsecond();

\echo ''
\echo '=== Step 4: Quick verification (row counts) ==='
SELECT 'mv_balance_amount_summary' as mv, COUNT(*) as rows FROM claims.mv_balance_amount_summary
UNION ALL SELECT 'mv_remittance_advice_summary', COUNT(*) FROM claims.mv_remittance_advice_summary
UNION ALL SELECT 'mv_doctor_denial_summary', COUNT(*) FROM claims.mv_doctor_denial_summary
UNION ALL SELECT 'mv_claims_monthly_agg', COUNT(*) FROM claims.mv_claims_monthly_agg
UNION ALL SELECT 'mv_claim_details_complete', COUNT(*) FROM claims.mv_claim_details_complete
UNION ALL SELECT 'mv_resubmission_cycles', COUNT(*) FROM claims.mv_resubmission_cycles
UNION ALL SELECT 'mv_remittances_resubmission_activity_level', COUNT(*) FROM claims.mv_remittances_resubmission_activity_level
UNION ALL SELECT 'mv_rejected_claims_summary', COUNT(*) FROM claims.mv_rejected_claims_summary
UNION ALL SELECT 'mv_claim_summary_payerwise', COUNT(*) FROM claims.mv_claim_summary_payerwise
UNION ALL SELECT 'mv_claim_summary_encounterwise', COUNT(*) FROM claims.mv_claim_summary_encounterwise
ORDER BY mv;

\echo ''
\echo '========================================='
\echo 'DONE: All reports initialized successfully.'
\echo 'Next: run your report functions/views as needed.'
\echo '========================================='
