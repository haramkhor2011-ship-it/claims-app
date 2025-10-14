-- ==========================================================================================================
-- QUICK DIAGNOSTIC: Zero Rows in Payerwise/Encounterwise MVs
-- ==========================================================================================================
-- 
-- Purpose: Quick diagnosis of why MVs return 0 rows
-- Run this first to get a quick overview of the issue
-- ==========================================================================================================

-- Check 1: Do the MVs exist and have data?
SELECT 'MV Status Check' as check_name;
SELECT 
  matviewname,
  ispopulated,
  pg_size_pretty(pg_total_relation_size('claims.'||matviewname)) as size
FROM pg_matviews 
WHERE schemaname = 'claims' 
  AND matviewname IN ('mv_claim_summary_payerwise', 'mv_claim_summary_encounterwise');

-- Check 2: Basic data counts
SELECT 'Basic Data Counts' as check_name;
SELECT 
  (SELECT COUNT(*) FROM claims.claim_key) as claim_key_count,
  (SELECT COUNT(*) FROM claims.claim) as claim_count,
  (SELECT COUNT(*) FROM claims.encounter) as encounter_count,
  (SELECT COUNT(*) FROM claims.remittance_claim) as remittance_claim_count;

-- Check 3: Test the WHERE clause that might be the issue
SELECT 'WHERE Clause Test' as check_name;
SELECT 
  COUNT(*) as total_claims,
  COUNT(CASE WHEN c.tx_at IS NOT NULL THEN 1 END) as claims_with_tx_at,
  COUNT(CASE WHEN rc.date_settlement IS NOT NULL THEN 1 END) as claims_with_settlement_date,
  COUNT(CASE WHEN DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)) IS NOT NULL THEN 1 END) as claims_with_valid_month_bucket
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id;

-- Check 4: Test without the restrictive WHERE clause
SELECT 'Test Without WHERE Clause' as check_name;
WITH remittance_aggregated AS (
  SELECT 
    rc.claim_key_id,
    COUNT(*) as remittance_count,
    SUM(ra.payment_amount) as total_payment_amount,
    SUM(ra.net) as total_remitted_amount,
    MIN(rc.date_settlement) as first_remittance_date,
    MAX(rc.date_settlement) as last_remittance_date
  FROM claims.remittance_claim rc
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
)
SELECT 
  COUNT(*) as total_rows,
  COUNT(CASE WHEN ra.claim_key_id IS NOT NULL THEN 1 END) as rows_with_remittance_data,
  COUNT(CASE WHEN ra.claim_key_id IS NULL THEN 1 END) as rows_without_remittance_data
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN remittance_aggregated ra ON ra.claim_key_id = ck.id;

-- Check 5: Sample data from source tables
SELECT 'Sample Data Check' as check_name;
SELECT 
  'claim_key' as table_name,
  COUNT(*) as row_count,
  MIN(created_at) as earliest_record,
  MAX(created_at) as latest_record
FROM claims.claim_key
UNION ALL
SELECT 
  'claim' as table_name,
  COUNT(*) as row_count,
  MIN(tx_at) as earliest_record,
  MAX(tx_at) as latest_record
FROM claims.claim
UNION ALL
SELECT 
  'remittance_claim' as table_name,
  COUNT(*) as row_count,
  MIN(date_settlement) as earliest_record,
  MAX(date_settlement) as latest_record
FROM claims.remittance_claim;

