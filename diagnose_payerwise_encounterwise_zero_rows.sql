-- ==========================================================================================================
-- DIAGNOSTIC: mv_claim_summary_payerwise and mv_claim_summary_encounterwise - Zero Rows Issue
-- ==========================================================================================================
-- 
-- Purpose: Diagnose why payerwise and encounterwise MVs are returning 0 rows
-- This could be due to:
-- 1. Data issues (no data in source tables)
-- 2. Logic issues (WHERE clause too restrictive)
-- 3. JOIN issues (missing relationships)
-- 4. Date filtering issues
-- ==========================================================================================================

-- ==========================================================================================================
-- STEP 1: Check if the MVs exist and are populated
-- ==========================================================================================================
SELECT 'Step 1: MV Existence Check' as diagnostic_step;
SELECT 
  schemaname,
  matviewname,
  hasindexes,
  ispopulated,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||matviewname)) as size
FROM pg_matviews 
WHERE schemaname = 'claims' 
  AND matviewname IN ('mv_claim_summary_payerwise', 'mv_claim_summary_encounterwise')
ORDER BY matviewname;

-- ==========================================================================================================
-- STEP 2: Check basic data availability in source tables
-- ==========================================================================================================
SELECT 'Step 2: Source Data Availability' as diagnostic_step;
SELECT 
  'claim_key' as table_name,
  COUNT(*) as row_count
FROM claims.claim_key
UNION ALL
SELECT 
  'claim' as table_name,
  COUNT(*) as row_count
FROM claims.claim
UNION ALL
SELECT 
  'encounter' as table_name,
  COUNT(*) as row_count
FROM claims.encounter
UNION ALL
SELECT 
  'remittance_claim' as table_name,
  COUNT(*) as row_count
FROM claims.remittance_claim
UNION ALL
SELECT 
  'remittance_activity' as table_name,
  COUNT(*) as row_count
FROM claims.remittance_activity;

-- ==========================================================================================================
-- STEP 3: Test the remittance_aggregated CTE in isolation (for payerwise)
-- ==========================================================================================================
SELECT 'Step 3: Remittance Aggregated CTE Test (Payerwise)' as diagnostic_step;
WITH remittance_aggregated AS (
  SELECT 
    rc.claim_key_id,
    COUNT(*) as remittance_count,
    SUM(ra.payment_amount) as total_payment_amount,
    SUM(ra.net) as total_remitted_amount,
    COUNT(CASE WHEN ra.payment_amount > 0 THEN 1 END) as paid_activity_count,
    COUNT(CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN 1 END) as partially_paid_activity_count,
    COUNT(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 1 END) as rejected_activity_count,
    COUNT(CASE WHEN rc.payment_reference IS NOT NULL THEN 1 END) as taken_back_count,
    COUNT(CASE WHEN rc.date_settlement IS NULL THEN 1 END) as pending_remittance_count,
    MIN(rc.date_settlement) as first_remittance_date,
    MAX(rc.date_settlement) as last_remittance_date,
    (ARRAY_AGG(rc.id_payer ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_id_payer,
    (ARRAY_AGG(rc.provider_id ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_provider_id
  FROM claims.remittance_claim rc
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
)
SELECT 
  COUNT(*) as remittance_aggregated_rows,
  COUNT(CASE WHEN remittance_count > 0 THEN 1 END) as rows_with_remittances,
  COUNT(CASE WHEN last_remittance_date IS NOT NULL THEN 1 END) as rows_with_settlement_dates
FROM remittance_aggregated;

-- ==========================================================================================================
-- STEP 4: Test the main query structure for payerwise (without WHERE clause)
-- ==========================================================================================================
SELECT 'Step 4: Payerwise Main Query Test (No WHERE)' as diagnostic_step;
WITH remittance_aggregated AS (
  SELECT 
    rc.claim_key_id,
    COUNT(*) as remittance_count,
    SUM(ra.payment_amount) as total_payment_amount,
    SUM(ra.net) as total_remitted_amount,
    COUNT(CASE WHEN ra.payment_amount > 0 THEN 1 END) as paid_activity_count,
    COUNT(CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN 1 END) as partially_paid_activity_count,
    COUNT(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 1 END) as rejected_activity_count,
    COUNT(CASE WHEN rc.payment_reference IS NOT NULL THEN 1 END) as taken_back_count,
    COUNT(CASE WHEN rc.date_settlement IS NULL THEN 1 END) as pending_remittance_count,
    MIN(rc.date_settlement) as first_remittance_date,
    MAX(rc.date_settlement) as last_remittance_date,
    (ARRAY_AGG(rc.id_payer ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_id_payer,
    (ARRAY_AGG(rc.provider_id ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_provider_id
  FROM claims.remittance_claim rc
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
)
SELECT 
  COUNT(*) as main_query_rows,
  COUNT(CASE WHEN ra.claim_key_id IS NOT NULL THEN 1 END) as rows_with_remittance_data,
  COUNT(CASE WHEN ra.claim_key_id IS NULL THEN 1 END) as rows_without_remittance_data
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN remittance_aggregated ra ON ra.claim_key_id = ck.id;

-- ==========================================================================================================
-- STEP 5: Test the WHERE clause that might be filtering out all rows
-- ==========================================================================================================
SELECT 'Step 5: WHERE Clause Analysis (Payerwise)' as diagnostic_step;
WITH remittance_aggregated AS (
  SELECT 
    rc.claim_key_id,
    COUNT(*) as remittance_count,
    SUM(ra.payment_amount) as total_payment_amount,
    SUM(ra.net) as total_remitted_amount,
    COUNT(CASE WHEN ra.payment_amount > 0 THEN 1 END) as paid_activity_count,
    COUNT(CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN 1 END) as partially_paid_activity_count,
    COUNT(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 1 END) as rejected_activity_count,
    COUNT(CASE WHEN rc.payment_reference IS NOT NULL THEN 1 END) as taken_back_count,
    COUNT(CASE WHEN rc.date_settlement IS NULL THEN 1 END) as pending_remittance_count,
    MIN(rc.date_settlement) as first_remittance_date,
    MAX(rc.date_settlement) as last_remittance_date,
    (ARRAY_AGG(rc.id_payer ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_id_payer,
    (ARRAY_AGG(rc.provider_id ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_provider_id
  FROM claims.remittance_claim rc
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
)
SELECT 
  COUNT(*) as total_rows,
  COUNT(CASE WHEN DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at)) IS NOT NULL THEN 1 END) as rows_with_valid_month_bucket,
  COUNT(CASE WHEN DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at)) IS NULL THEN 1 END) as rows_with_null_month_bucket,
  MIN(DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at))) as earliest_month_bucket,
  MAX(DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at))) as latest_month_bucket
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN remittance_aggregated ra ON ra.claim_key_id = ck.id;

-- ==========================================================================================================
-- STEP 6: Check for NULL values in key fields
-- ==========================================================================================================
SELECT 'Step 6: NULL Values Check' as diagnostic_step;
SELECT 
  'claim.tx_at' as field_name,
  COUNT(*) as total_rows,
  COUNT(c.tx_at) as non_null_count,
  COUNT(*) - COUNT(c.tx_at) as null_count
FROM claims.claim c
UNION ALL
SELECT 
  'remittance_claim.date_settlement' as field_name,
  COUNT(*) as total_rows,
  COUNT(rc.date_settlement) as non_null_count,
  COUNT(*) - COUNT(rc.date_settlement) as null_count
FROM claims.remittance_claim rc
UNION ALL
SELECT 
  'encounter.facility_id' as field_name,
  COUNT(*) as total_rows,
  COUNT(e.facility_id) as non_null_count,
  COUNT(*) - COUNT(e.facility_id) as null_count
FROM claims.encounter e;

-- ==========================================================================================================
-- STEP 7: Test a simplified version of the payerwise MV
-- ==========================================================================================================
SELECT 'Step 7: Simplified Payerwise Test' as diagnostic_step;
SELECT 
  DATE_TRUNC('month', c.tx_at) as month_bucket,
  c.payer_id,
  e.facility_id,
  COUNT(*) as claim_count,
  SUM(c.net) as total_net
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
WHERE c.tx_at IS NOT NULL
GROUP BY DATE_TRUNC('month', c.tx_at), c.payer_id, e.facility_id
ORDER BY month_bucket DESC
LIMIT 10;

-- ==========================================================================================================
-- STEP 8: Check if there are any claims with encounters
-- ==========================================================================================================
SELECT 'Step 8: Claims with Encounters Check' as diagnostic_step;
SELECT 
  COUNT(*) as total_claims,
  COUNT(e.id) as claims_with_encounters,
  COUNT(*) - COUNT(e.id) as claims_without_encounters
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id;

-- ==========================================================================================================
-- STEP 9: Check if there are any remittances
-- ==========================================================================================================
SELECT 'Step 9: Remittances Check' as diagnostic_step;
SELECT 
  COUNT(*) as total_remittance_claims,
  COUNT(CASE WHEN rc.date_settlement IS NOT NULL THEN 1 END) as remittances_with_settlement_date,
  COUNT(CASE WHEN rc.date_settlement IS NULL THEN 1 END) as remittances_without_settlement_date,
  MIN(rc.date_settlement) as earliest_settlement,
  MAX(rc.date_settlement) as latest_settlement
FROM claims.remittance_claim rc;

-- ==========================================================================================================
-- STEP 10: Test the exact WHERE clause from the MV
-- ==========================================================================================================
SELECT 'Step 10: Exact WHERE Clause Test' as diagnostic_step;
WITH remittance_aggregated AS (
  SELECT 
    rc.claim_key_id,
    COUNT(*) as remittance_count,
    SUM(ra.payment_amount) as total_payment_amount,
    SUM(ra.net) as total_remitted_amount,
    COUNT(CASE WHEN ra.payment_amount > 0 THEN 1 END) as paid_activity_count,
    COUNT(CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN 1 END) as partially_paid_activity_count,
    COUNT(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 1 END) as rejected_activity_count,
    COUNT(CASE WHEN rc.payment_reference IS NOT NULL THEN 1 END) as taken_back_count,
    COUNT(CASE WHEN rc.date_settlement IS NULL THEN 1 END) as pending_remittance_count,
    MIN(rc.date_settlement) as first_remittance_date,
    MAX(rc.date_settlement) as last_remittance_date,
    (ARRAY_AGG(rc.id_payer ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_id_payer,
    (ARRAY_AGG(rc.provider_id ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_provider_id
  FROM claims.remittance_claim rc
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
)
SELECT 
  COUNT(*) as rows_before_where,
  COUNT(CASE WHEN DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at)) IS NOT NULL THEN 1 END) as rows_after_where,
  COUNT(CASE WHEN DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at)) IS NULL THEN 1 END) as rows_filtered_out
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN remittance_aggregated ra ON ra.claim_key_id = ck.id;

-- ==========================================================================================================
-- EXPECTED RESULTS:
-- ==========================================================================================================
-- Step 1: Should show both MVs exist and are populated
-- Step 2: Should show positive counts for all source tables
-- Step 3: Should show positive count for remittance_aggregated CTE
-- Step 4: Should show positive count for main query
-- Step 5: Should show positive count for month_bucket analysis
-- Step 6: Should show mostly non-null values in key fields
-- Step 7: Should show sample data from simplified query
-- Step 8: Should show claims with and without encounters
-- Step 9: Should show remittance data exists
-- Step 10: Should identify if WHERE clause is filtering out all rows
-- ==========================================================================================================

