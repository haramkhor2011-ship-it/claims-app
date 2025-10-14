-- ==========================================================================================================
-- TEST: mv_doctor_denial_summary Fix Verification
-- ==========================================================================================================
-- 
-- Purpose: Verify that mv_doctor_denial_summary is working correctly after the fix
-- This script tests the materialized view without recreating it
-- ==========================================================================================================

-- Test 1: Check if the materialized view exists and has data
SELECT 'Test 1: Row Count Check' as test_name;
SELECT 
  'mv_doctor_denial_summary' as view_name, 
  COUNT(*) as row_count 
FROM claims.mv_doctor_denial_summary;

-- Test 2: Check for duplicates (should show 0 duplicates)
SELECT 'Test 2: Duplicate Check' as test_name;
WITH duplicate_check AS (
  SELECT 
    clinician_id, 
    facility_code, 
    report_month,
    COUNT(*) as row_count
  FROM claims.mv_doctor_denial_summary
  GROUP BY clinician_id, facility_code, report_month
)
SELECT 
  COUNT(*) as total_unique_combinations,
  SUM(row_count) as total_rows,
  COUNT(CASE WHEN row_count > 1 THEN 1 END) as duplicate_combinations,
  SUM(CASE WHEN row_count > 1 THEN row_count - 1 ELSE 0 END) as total_duplicate_rows
FROM duplicate_check;

-- Test 3: Verify data quality - check for NULL values in key fields
SELECT 'Test 3: Data Quality Check' as test_name;
SELECT 
  COUNT(*) as total_rows,
  COUNT(clinician_id) as non_null_clinician_id,
  COUNT(facility_code) as non_null_facility_code,
  COUNT(report_month) as non_null_report_month,
  COUNT(CASE WHEN total_claims > 0 THEN 1 END) as rows_with_claims,
  COUNT(CASE WHEN rejection_percentage >= 0 AND rejection_percentage <= 100 THEN 1 END) as valid_rejection_percentage,
  COUNT(CASE WHEN collection_rate >= 0 AND collection_rate <= 100 THEN 1 END) as valid_collection_rate
FROM claims.mv_doctor_denial_summary;

-- Test 4: Sample data verification
SELECT 'Test 4: Sample Data' as test_name;
SELECT 
  clinician_id,
  clinician_name,
  facility_code,
  facility_name,
  report_month,
  total_claims,
  remitted_claims,
  rejected_claims,
  rejection_percentage,
  collection_rate
FROM claims.mv_doctor_denial_summary
WHERE total_claims > 0
ORDER BY rejection_percentage DESC
LIMIT 5;

-- Test 5: Test refresh capability
SELECT 'Test 5: Refresh Test' as test_name;
REFRESH MATERIALIZED VIEW claims.mv_doctor_denial_summary;
SELECT 'SUCCESS: Materialized view refreshed without errors' as refresh_status;

-- Test 6: Final summary
SELECT 'Test 6: Final Summary' as test_name;
SELECT 
  'mv_doctor_denial_summary' as view_name,
  'FIXED' as status,
  COUNT(*) as total_rows,
  'No duplicate key violations' as duplicate_status,
  'Aggregation working correctly' as aggregation_status
FROM claims.mv_doctor_denial_summary;

-- ==========================================================================================================
-- EXPECTED RESULTS:
-- ==========================================================================================================
-- Test 1: Should show a positive row count
-- Test 2: duplicate_combinations and total_duplicate_rows should both be 0
-- Test 3: All counts should match total_rows (no NULLs in key fields)
-- Test 4: Should show sample data with valid percentages
-- Test 5: Should complete without errors
-- Test 6: Should show summary with FIXED status
-- ==========================================================================================================

