-- ==========================================================================================================
-- DIAGNOSTIC: mv_claim_details_complete - Why 0 rows?
-- ==========================================================================================================
-- 
-- Purpose: Diagnose why mv_claim_details_complete shows 0 rows
-- This script checks the data flow step by step
-- ==========================================================================================================

-- Check 1: Does the materialized view exist?
SELECT 'Check 1: MV Existence' as check_name;
SELECT 
  schemaname,
  matviewname,
  hasindexes,
  ispopulated
FROM pg_matviews 
WHERE schemaname = 'claims' 
  AND matviewname = 'mv_claim_details_complete';

-- Check 2: Basic data availability
SELECT 'Check 2: Basic Data Availability' as check_name;
SELECT 
  (SELECT COUNT(*) FROM claims.claim_key) as claim_key_count,
  (SELECT COUNT(*) FROM claims.claim) as claim_count,
  (SELECT COUNT(*) FROM claims.activity) as activity_count,
  (SELECT COUNT(*) FROM claims.encounter) as encounter_count;

-- Check 3: Test the activity_remittance_agg CTE in isolation
SELECT 'Check 3: Activity Remittance Agg CTE' as check_name;
WITH activity_remittance_agg AS (
  SELECT 
    a.activity_id,
    a.claim_id,
    SUM(ra.payment_amount) as total_payment_amount,
    MAX(ra.denial_code) as latest_denial_code,
    MAX(rc.date_settlement) as latest_settlement_date,
    MAX(rc.payment_reference) as latest_payment_reference,
    COUNT(DISTINCT rc.id) as remittance_count,
    SUM(ra.net) as total_remitted_amount,
    COUNT(CASE WHEN ra.payment_amount > 0 THEN 1 END) as paid_remittance_count,
    COUNT(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 1 END) as rejected_remittance_count
  FROM claims.activity a
  LEFT JOIN claims.claim c ON c.id = a.claim_id
  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = c.claim_key_id
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id 
    AND ra.activity_id = a.activity_id
  GROUP BY a.activity_id, a.claim_id
)
SELECT COUNT(*) as cte_row_count FROM activity_remittance_agg;

-- Check 4: Test the main query without the CTE
SELECT 'Check 4: Main Query Without CTE' as check_name;
SELECT COUNT(*) as main_query_count
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims.activity a ON a.claim_id = c.id;

-- Check 5: Test with a simple activity_remittance_agg (no remittance data)
SELECT 'Check 5: Simple Activity Aggregation' as check_name;
WITH simple_activity_agg AS (
  SELECT 
    a.activity_id,
    a.claim_id,
    0 as total_payment_amount,
    NULL as latest_denial_code,
    NULL as latest_settlement_date,
    NULL as latest_payment_reference,
    0 as remittance_count,
    0 as total_remitted_amount,
    0 as paid_remittance_count,
    0 as rejected_remittance_count
  FROM claims.activity a
  GROUP BY a.activity_id, a.claim_id
)
SELECT COUNT(*) as simple_agg_count FROM simple_activity_agg;

-- Check 6: Test the full query with simple aggregation
SELECT 'Check 6: Full Query with Simple Aggregation' as check_name;
WITH simple_activity_agg AS (
  SELECT 
    a.activity_id,
    a.claim_id,
    0 as total_payment_amount,
    NULL as latest_denial_code,
    NULL as latest_settlement_date,
    NULL as latest_payment_reference,
    0 as remittance_count,
    0 as total_remitted_amount,
    0 as paid_remittance_count,
    0 as rejected_remittance_count
  FROM claims.activity a
  GROUP BY a.activity_id, a.claim_id
)
SELECT COUNT(*) as full_query_count
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN simple_activity_agg ara ON ara.activity_id = a.activity_id AND ara.claim_id = c.id;

-- Check 7: Check if there are any remittance records
SELECT 'Check 7: Remittance Data Check' as check_name;
SELECT 
  (SELECT COUNT(*) FROM claims.remittance_claim) as remittance_claim_count,
  (SELECT COUNT(*) FROM claims.remittance_activity) as remittance_activity_count;

-- Check 8: Sample data from key tables
SELECT 'Check 8: Sample Data' as check_name;
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
  'activity' as table_name,
  COUNT(*) as row_count
FROM claims.activity
UNION ALL
SELECT 
  'encounter' as table_name,
  COUNT(*) as row_count
FROM claims.encounter;

-- ==========================================================================================================
-- EXPECTED RESULTS:
-- ==========================================================================================================
-- Check 1: Should show the MV exists and is populated
-- Check 2: Should show positive counts for all tables
-- Check 3: Should show positive count (activities with/without remittances)
-- Check 4: Should show positive count (all claims with activities)
-- Check 5: Should show positive count (all activities)
-- Check 6: Should show positive count (full query works)
-- Check 7: Should show remittance data exists
-- Check 8: Should show all tables have data
-- ==========================================================================================================

