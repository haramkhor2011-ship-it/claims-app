-- ==========================================================================================================
-- TEST: Payerwise and Encounterwise MVs Zero Rows Fix
-- ==========================================================================================================
-- 
-- Purpose: Test that the fix for zero rows issue works correctly
-- This script will:
-- 1. Apply the fix to both MVs
-- 2. Test that they now return data
-- 3. Verify the data makes sense
-- ==========================================================================================================

-- ==========================================================================================================
-- STEP 1: Apply the fix (run the fix script)
-- ==========================================================================================================
\echo 'Applying fix for payerwise and encounterwise MVs...'
\i fix_payerwise_encounterwise_zero_rows.sql

-- ==========================================================================================================
-- STEP 2: Test that MVs now have data
-- ==========================================================================================================
\echo 'Testing MV row counts...'
SELECT 
  'mv_claim_summary_payerwise' as mv_name,
  COUNT(*) as row_count,
  CASE 
    WHEN COUNT(*) > 0 THEN 'PASS - MV has data'
    ELSE 'FAIL - MV still has zero rows'
  END as test_result
FROM claims.mv_claim_summary_payerwise
UNION ALL
SELECT 
  'mv_claim_summary_encounterwise' as mv_name,
  COUNT(*) as row_count,
  CASE 
    WHEN COUNT(*) > 0 THEN 'PASS - MV has data'
    ELSE 'FAIL - MV still has zero rows'
  END as test_result
FROM claims.mv_claim_summary_encounterwise;

-- ==========================================================================================================
-- STEP 3: Test sample data from payerwise MV
-- ==========================================================================================================
\echo 'Testing sample data from payerwise MV...'
SELECT 
  'Payerwise Sample Data' as test_name,
  month_bucket,
  payer_id,
  facility_id,
  total_claims,
  claims_with_remittances,
  claims_without_remittances,
  total_claim_amount,
  total_paid_amount
FROM claims.mv_claim_summary_payerwise
ORDER BY month_bucket DESC, total_claims DESC
LIMIT 5;

-- ==========================================================================================================
-- STEP 4: Test sample data from encounterwise MV
-- ==========================================================================================================
\echo 'Testing sample data from encounterwise MV...'
SELECT 
  'Encounterwise Sample Data' as test_name,
  month_bucket,
  encounter_type,
  facility_id,
  payer_id,
  total_claims,
  claims_with_remittances,
  claims_without_remittances,
  total_claim_amount,
  total_paid_amount
FROM claims.mv_claim_summary_encounterwise
ORDER BY month_bucket DESC, total_claims DESC
LIMIT 5;

-- ==========================================================================================================
-- STEP 5: Test that claims at different lifecycle stages are included
-- ==========================================================================================================
\echo 'Testing claims at different lifecycle stages...'
SELECT 
  'Lifecycle Stage Test' as test_name,
  COUNT(*) as total_rows,
  SUM(claims_with_remittances) as total_claims_with_remittances,
  SUM(claims_without_remittances) as total_claims_without_remittances,
  COUNT(CASE WHEN claims_without_remittances > 0 THEN 1 END) as rows_with_claims_without_remittances,
  COUNT(CASE WHEN claims_with_remittances > 0 THEN 1 END) as rows_with_claims_with_remittances
FROM claims.mv_claim_summary_payerwise;

-- ==========================================================================================================
-- STEP 6: Test that month buckets are valid
-- ==========================================================================================================
\echo 'Testing month bucket validity...'
SELECT 
  'Month Bucket Test' as test_name,
  COUNT(*) as total_rows,
  COUNT(CASE WHEN month_bucket IS NOT NULL THEN 1 END) as rows_with_valid_month_bucket,
  COUNT(CASE WHEN month_bucket IS NULL THEN 1 END) as rows_with_null_month_bucket,
  MIN(month_bucket) as earliest_month,
  MAX(month_bucket) as latest_month
FROM claims.mv_claim_summary_payerwise;

-- ==========================================================================================================
-- STEP 7: Test that the fix handles NULL dates correctly
-- ==========================================================================================================
\echo 'Testing NULL date handling...'
SELECT 
  'NULL Date Handling Test' as test_name,
  COUNT(*) as total_claims,
  COUNT(CASE WHEN c.tx_at IS NULL THEN 1 END) as claims_with_null_tx_at,
  COUNT(CASE WHEN rc.date_settlement IS NULL THEN 1 END) as remittances_with_null_settlement,
  COUNT(CASE WHEN c.tx_at IS NULL AND rc.date_settlement IS NULL THEN 1 END) as claims_with_both_null
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id;

-- ==========================================================================================================
-- STEP 8: Verify that the COALESCE fallback chain works
-- ==========================================================================================================
\echo 'Testing COALESCE fallback chain...'
SELECT 
  'COALESCE Fallback Test' as test_name,
  COUNT(*) as total_claims,
  COUNT(CASE WHEN c.tx_at IS NOT NULL THEN 1 END) as claims_with_tx_at,
  COUNT(CASE WHEN c.tx_at IS NULL AND ck.created_at IS NOT NULL THEN 1 END) as claims_using_created_at_fallback,
  COUNT(CASE WHEN c.tx_at IS NULL AND ck.created_at IS NULL THEN 1 END) as claims_using_current_date_fallback
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id;

-- ==========================================================================================================
-- EXPECTED RESULTS:
-- ==========================================================================================================
-- Step 2: Both MVs should show positive row counts with "PASS" status
-- Step 3: Should show sample data with valid month_bucket, payer_id, facility_id
-- Step 4: Should show sample data with valid month_bucket, encounter_type, facility_id, payer_id
-- Step 5: Should show both claims with and without remittances
-- Step 6: All rows should have valid month_bucket (no NULL values)
-- Step 7: Should show some claims with NULL dates (this is normal)
-- Step 8: Should show the fallback chain is working (some claims using created_at or current_date)
-- ==========================================================================================================

