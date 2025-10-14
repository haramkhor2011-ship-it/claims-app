-- ==========================================================================================================
-- DIAGNOSTIC: mv_doctor_denial_summary Issues
-- ==========================================================================================================
-- 
-- Purpose: Diagnose any issues with mv_doctor_denial_summary
-- Run this to identify the specific problem
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
  AND matviewname = 'mv_doctor_denial_summary';

-- Check 2: What indexes exist on the MV?
SELECT 'Check 2: Indexes' as check_name;
SELECT 
  indexname,
  indexdef
FROM pg_indexes 
WHERE schemaname = 'claims' 
  AND tablename = 'mv_doctor_denial_summary';

-- Check 3: Try a simple count (this should work)
SELECT 'Check 3: Simple Count' as check_name;
SELECT COUNT(*) as row_count FROM claims.mv_doctor_denial_summary;

-- Check 4: Try to get column information
SELECT 'Check 4: Column Info' as check_name;
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_schema = 'claims' 
  AND table_name = 'mv_doctor_denial_summary'
ORDER BY ordinal_position;

-- Check 5: Try a simple select with key columns
SELECT 'Check 5: Simple Select' as check_name;
SELECT 
  clinician_id,
  facility_code,
  report_month,
  total_claims
FROM claims.mv_doctor_denial_summary
LIMIT 5;

-- Check 6: Test the problematic COUNT(DISTINCT) syntax
SELECT 'Check 6: Count Distinct Test' as check_name;
SELECT 
  COUNT(*) as total_rows,
  COUNT(DISTINCT clinician_id) as distinct_clinicians,
  COUNT(DISTINCT facility_code) as distinct_facilities
FROM claims.mv_doctor_denial_summary;

-- Check 7: Test grouping approach
SELECT 'Check 7: Grouping Test' as check_name;
SELECT 
  clinician_id,
  facility_code,
  report_month,
  COUNT(*) as row_count
FROM claims.mv_doctor_denial_summary
GROUP BY clinician_id, facility_code, report_month
HAVING COUNT(*) > 1
LIMIT 5;

-- Check 8: Check for any NULL values in key fields
SELECT 'Check 8: NULL Check' as check_name;
SELECT 
  COUNT(*) as total_rows,
  COUNT(clinician_id) as non_null_clinician_id,
  COUNT(facility_code) as non_null_facility_code,
  COUNT(report_month) as non_null_report_month
FROM claims.mv_doctor_denial_summary;

-- ==========================================================================================================
-- EXPECTED RESULTS:
-- ==========================================================================================================
-- Check 1: Should show the MV exists and is populated
-- Check 2: Should show the unique index exists
-- Check 3: Should return a positive number
-- Check 4: Should show all expected columns
-- Check 5: Should return sample data
-- Check 6: Should work without errors
-- Check 7: Should return 0 rows (no duplicates)
-- Check 8: Should show no NULLs in key fields
-- ==========================================================================================================

