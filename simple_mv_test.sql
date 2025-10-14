-- ==========================================================================================================
-- SIMPLE TEST: mv_doctor_denial_summary
-- ==========================================================================================================
-- 
-- Purpose: Simple test to verify mv_doctor_denial_summary is working
-- This is the most basic test possible
-- ==========================================================================================================

-- Test 1: Basic existence and count
SELECT 'mv_doctor_denial_summary' as view_name, COUNT(*) as row_count 
FROM claims.mv_doctor_denial_summary;

-- Test 2: Check for duplicates using a simple approach
SELECT 
  COUNT(*) as total_rows,
  COUNT(DISTINCT clinician_id) as unique_clinicians,
  COUNT(DISTINCT facility_code) as unique_facilities,
  COUNT(DISTINCT report_month) as unique_months
FROM claims.mv_doctor_denial_summary;

-- Test 3: Sample data
SELECT 
  clinician_id,
  facility_code,
  report_month,
  total_claims,
  rejection_percentage
FROM claims.mv_doctor_denial_summary
LIMIT 3;

-- Test 4: Refresh test
REFRESH MATERIALIZED VIEW claims.mv_doctor_denial_summary;
SELECT 'SUCCESS: Refresh completed' as status;

