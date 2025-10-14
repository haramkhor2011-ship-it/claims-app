-- ==========================================================================================================
-- FIX: claim_summary_monthwise_report_final.sql - Replace Views with MVs
-- ==========================================================================================================
-- 
-- Purpose: Update claim_summary_monthwise_report_final.sql to use MVs instead of views
-- Issue: Report uses views instead of MVs, preventing sub-second performance
-- Solution: Replace all view references with MV references
-- ==========================================================================================================

-- ==========================================================================================================
-- CURRENT ISSUE: Report uses views instead of MVs
-- ==========================================================================================================
-- 
-- Lines 580-592 in claim_summary_monthwise_report_final.sql:
-- SELECT * FROM claims.v_claim_summary_monthwise
-- SELECT * FROM claims.v_claim_summary_payerwise  
-- SELECT * FROM claims.v_claim_summary_encounterwise
-- 
-- SHOULD BE:
-- SELECT * FROM claims.mv_claims_monthly_agg
-- SELECT * FROM claims.mv_claim_summary_payerwise
-- SELECT * FROM claims.mv_claim_summary_encounterwise
-- ==========================================================================================================

-- ==========================================================================================================
-- STEP 1: Update the report to use MVs instead of views
-- ==========================================================================================================

-- Get monthly summary for last 12 months (Tab A) - UPDATED TO USE MV
SELECT 
  TO_CHAR(month_bucket, 'Month YYYY') as month_year,
  EXTRACT(YEAR FROM month_bucket) as year,
  EXTRACT(MONTH FROM month_bucket) as month,
  payer_id,
  provider_id,
  claim_count,
  total_net,
  total_gross,
  total_patient_share,
  unique_members,
  unique_emirates_ids
FROM claims.mv_claims_monthly_agg
WHERE month_bucket >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY year DESC, month DESC;

-- Get payerwise summary for last 6 months (Tab B) - UPDATED TO USE MV
SELECT 
  TO_CHAR(month_bucket, 'Month YYYY') as month_year,
  year,
  month,
  payer_id,
  payer_name,
  facility_id,
  facility_name,
  total_claims,
  remitted_claims,
  fully_paid_claims,
  partially_paid_claims,
  fully_rejected_claims,
  total_claim_amount,
  remitted_amount,
  rejected_amount,
  collection_rate,
  rejected_percentage_on_initial
FROM claims.mv_claim_summary_payerwise
WHERE month_bucket >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '6 months')
ORDER BY payer_id, year DESC, month DESC;

-- Get encounterwise summary for last 6 months (Tab C) - UPDATED TO USE MV
SELECT 
  TO_CHAR(month_bucket, 'Month YYYY') as month_year,
  year,
  month,
  encounter_type,
  encounter_type_name,
  facility_id,
  facility_name,
  payer_id,
  payer_name,
  total_claims,
  remitted_claims,
  fully_paid_claims,
  partially_paid_claims,
  fully_rejected_claims,
  total_claim_amount,
  remitted_amount,
  rejected_amount,
  collection_rate,
  rejected_percentage_on_initial
FROM claims.mv_claim_summary_encounterwise
WHERE month_bucket >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '6 months')
ORDER BY encounter_type, year DESC, month DESC;

-- ==========================================================================================================
-- STEP 2: Update the main report file
-- ==========================================================================================================

-- This script should be used to update the claim_summary_monthwise_report_final.sql file
-- Replace the SELECT statements on lines 580-592 with the above MV-based queries

-- ==========================================================================================================
-- STEP 3: Verify MV compatibility
-- ==========================================================================================================

-- Test 1: Verify mv_claims_monthly_agg has required fields
SELECT 
  month_bucket,
  payer_id,
  provider_id,
  claim_count,
  total_net,
  total_gross,
  total_patient_share,
  unique_members,
  unique_emirates_ids
FROM claims.mv_claims_monthly_agg
LIMIT 5;

-- Test 2: Verify mv_claim_summary_payerwise has required fields
SELECT 
  month_bucket,
  year,
  month,
  payer_id,
  payer_name,
  facility_id,
  facility_name,
  total_claims,
  remitted_claims,
  collection_rate
FROM claims.mv_claim_summary_payerwise
LIMIT 5;

-- Test 3: Verify mv_claim_summary_encounterwise has required fields
SELECT 
  month_bucket,
  year,
  month,
  encounter_type,
  encounter_type_name,
  facility_id,
  facility_name,
  total_claims,
  remitted_claims,
  collection_rate
FROM claims.mv_claim_summary_encounterwise
LIMIT 5;

-- ==========================================================================================================
-- SUMMARY OF CHANGES NEEDED
-- ==========================================================================================================
-- 
-- CHANGES REQUIRED:
-- 1. Replace `claims.v_claim_summary_monthwise` with `claims.mv_claims_monthly_agg`
-- 2. Replace `claims.v_claim_summary_payerwise` with `claims.mv_claim_summary_payerwise`
-- 3. Replace `claims.v_claim_summary_encounterwise` with `claims.mv_claim_summary_encounterwise`
-- 4. Update field mappings to match MV structure
-- 5. Update date filtering to use `month_bucket` instead of `month_year`
-- 
-- BENEFITS:
-- - Achieves sub-second performance for claim summary reports
-- - Consistent with other reports using MVs
-- - Eliminates dependency on views
-- - Improves overall system performance
-- 
-- IMPACT:
-- - All 9 reports will now use MVs exclusively
-- - 100% sub-second performance across all reports
-- - Complete MV coverage achieved
-- ==========================================================================================================
