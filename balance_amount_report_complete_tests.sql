-- ==========================================================================================================
-- BALANCE AMOUNT REPORT - COMPLETE TEST QUERIES (FINAL VERSION)
-- ==========================================================================================================
-- Run these queries to verify the report is working correctly
-- ALL COLUMN NAMES VERIFIED AGAINST ACTUAL DATABASE STRUCTURE
-- ==========================================================================================================

-- ==========================================================================================================
-- 1. BASIC HEALTH CHECKS
-- ==========================================================================================================

-- Check if views were created successfully
SELECT 
  schemaname, 
  viewname, 
  definition IS NOT NULL as has_definition
FROM pg_views 
WHERE schemaname = 'claims' 
  AND viewname LIKE 'v_balance_amount%'
ORDER BY viewname;

-- Check if function was created successfully
SELECT 
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'claims' 
  AND p.proname LIKE '%balance_amount%'
ORDER BY p.proname;

-- ==========================================================================================================
-- 2. DATA AVAILABILITY CHECKS
-- ==========================================================================================================

-- Check if we have any data in the base tables
SELECT 'claim_key' as table_name, COUNT(*) as row_count FROM claims.claim_key
UNION ALL
SELECT 'claim' as table_name, COUNT(*) as row_count FROM claims.claim
UNION ALL
SELECT 'encounter' as table_name, COUNT(*) as row_count FROM claims.encounter
UNION ALL
SELECT 'remittance_claim' as table_name, COUNT(*) as row_count FROM claims.remittance_claim
UNION ALL
SELECT 'claim_event' as table_name, COUNT(*) as row_count FROM claims.claim_event
ORDER BY table_name;

-- ==========================================================================================================
-- 3. BASE VIEW TEST (This should work - has all columns)
-- ==========================================================================================================

-- Test the base enhanced view (limit to 5 rows for quick check)
SELECT 
  claim_key_id,
  claim_id,
  facility_group_id,
  provider_name,
  payer_name,
  initial_net_amount,
  pending_amount,
  current_claim_status,
  aging_days
FROM claims.v_balance_amount_base_enhanced 
LIMIT 5;

-- ==========================================================================================================
-- 4. TAB A TEST (Balance Amount to be received) - VERIFIED COLUMNS
-- ==========================================================================================================

-- Test Tab A view (limit to 3 rows for quick check)
-- VERIFIED: Using actual column names from the view
SELECT 
  claim_key_id,
  claim_id,
  facility_group_id,
  facility_name,
  claim_number,
  encounter_start_date,
  encounter_end_date,
  id_payer,
  patient_id,
  member_id,
  billed_amount,
  amount_received,
  outstanding_balance,
  claim_status,
  aging_days,
  aging_bucket
FROM claims.v_balance_amount_tab_a_corrected 
LIMIT 3;

-- ==========================================================================================================
-- 5. TAB B TEST (Initial Not Remitted Balance) - VERIFIED COLUMNS
-- ==========================================================================================================

-- Test Tab B view (limit to 3 rows for quick check)
-- VERIFIED: Using actual column names from the view
SELECT 
  claim_key_id,
  claim_id,
  facility_group_id,
  facility_name,
  claim_number,
  encounter_start_date,
  encounter_end_date,
  id_payer,
  patient_id,
  member_id,
  billed_amount,
  amount_received,
  outstanding_balance,
  claim_status,
  aging_days,
  aging_bucket
FROM claims.v_balance_amount_tab_b_corrected 
LIMIT 3;

-- ==========================================================================================================
-- 6. TAB C TEST (Resubmitted Balance) - VERIFIED COLUMNS FROM YOUR OUTPUT
-- ==========================================================================================================

-- Test Tab C view (limit to 3 rows for quick check)
-- VERIFIED: Using actual column names from your database output
SELECT 
  claim_key_id,
  claim_id,
  facility_group,  -- VERIFIED: Tab C uses 'facility_group' not 'facility_group_id'
  health_authority,
  facility_id,
  facility_name,
  claim_number,
  encounter_start_date,
  encounter_end_date,
  encounter_start_year,
  encounter_start_month,
  id_payer,
  patient_id,
  member_id,
  emirates_id_number,
  billed_amount,
  amount_received,
  write_off_amount,
  denied_amount,
  outstanding_balance,
  submission_date,
  resubmission_count,
  last_resubmission_date,
  last_resubmission_comment,
  claim_status,
  remittance_count,
  aging_days,
  aging_bucket
FROM claims.v_balance_amount_tab_c_corrected 
LIMIT 3;

-- ==========================================================================================================
-- 7. FUNCTION TEST - VERIFIED PARAMETERS
-- ==========================================================================================================

-- Test the API function (this should return a result set)
-- VERIFIED: Using correct parameter names and types
SELECT * FROM claims.get_balance_amount_tab_a_corrected(
  'test_user',                    -- p_user_id
  NULL,                           -- p_claim_key_ids (NULL = all)
  ARRAY['ALL'],                   -- p_facility_codes (ALL means no filter)
  ARRAY['ALL'],                   -- p_payer_codes (ALL means no filter)
  ARRAY['ALL'],                   -- p_receiver_ids (ALL means no filter)
  '2024-01-01'::timestamptz,     -- p_date_from
  '2024-12-31'::timestamptz,     -- p_date_to
  NULL,                           -- p_year (NULL = all years)
  NULL,                           -- p_month (NULL = all months)
  FALSE,                          -- p_based_on_initial_net
  10,                             -- p_limit
  0,                              -- p_offset
  'encounter_start_date',         -- p_order_by
  'DESC'                          -- p_order_direction
);

-- ==========================================================================================================
-- 8. DATA QUALITY CHECKS - VERIFIED COLUMNS
-- ==========================================================================================================

-- Check for any NULL values in critical fields
SELECT 
  'Base View' as view_name,
  COUNT(*) as total_rows,
  COUNT(*) - COUNT(claim_key_id) as null_claim_key_id,
  COUNT(*) - COUNT(facility_group_id) as null_facility_group_id,
  COUNT(*) - COUNT(provider_name) as null_provider_name,
  COUNT(*) - COUNT(payer_name) as null_payer_name
FROM claims.v_balance_amount_base_enhanced

UNION ALL

SELECT 
  'Tab A' as view_name,
  COUNT(*) as total_rows,
  COUNT(*) - COUNT(claim_key_id) as null_claim_key_id,
  COUNT(*) - COUNT(facility_group_id) as null_facility_group_id,
  COUNT(*) - COUNT(facility_name) as null_facility_name,
  COUNT(*) - COUNT(id_payer) as null_id_payer
FROM claims.v_balance_amount_tab_a_corrected

UNION ALL

SELECT 
  'Tab B' as view_name,
  COUNT(*) as total_rows,
  COUNT(*) - COUNT(claim_key_id) as null_claim_key_id,
  COUNT(*) - COUNT(facility_group_id) as null_facility_group_id,
  COUNT(*) - COUNT(facility_name) as null_facility_name,
  COUNT(*) - COUNT(id_payer) as null_id_payer
FROM claims.v_balance_amount_tab_b_corrected

UNION ALL

SELECT 
  'Tab C' as view_name,
  COUNT(*) as total_rows,
  COUNT(*) - COUNT(claim_key_id) as null_claim_key_id,
  COUNT(*) - COUNT(facility_group) as null_facility_group,  -- VERIFIED: Tab C uses 'facility_group'
  COUNT(*) - COUNT(facility_name) as null_facility_name,
  COUNT(*) - COUNT(id_payer) as null_id_payer
FROM claims.v_balance_amount_tab_c_corrected;

-- ==========================================================================================================
-- 9. PERFORMANCE CHECK
-- ==========================================================================================================

-- Check if indexes were created successfully
SELECT 
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes 
WHERE schemaname = 'claims' 
  AND indexname LIKE 'idx_balance_amount%'
ORDER BY tablename, indexname;

-- ==========================================================================================================
-- 10. SUMMARY STATISTICS - VERIFIED COLUMNS
-- ==========================================================================================================

-- Get summary statistics for all views
SELECT 
  'Base Enhanced' as view_name,
  COUNT(*) as total_claims,
  COUNT(DISTINCT facility_group_id) as unique_facilities,
  COUNT(DISTINCT provider_name) as unique_providers,
  COUNT(DISTINCT payer_name) as unique_payers,
  ROUND(AVG(pending_amount), 2) as avg_pending_amount,
  ROUND(SUM(pending_amount), 2) as total_pending_amount
FROM claims.v_balance_amount_base_enhanced

UNION ALL

SELECT 
  'Tab A (Balance to be received)' as view_name,
  COUNT(*) as total_claims,
  COUNT(DISTINCT facility_group_id) as unique_facilities,
  COUNT(DISTINCT facility_name) as unique_facility_names,
  COUNT(DISTINCT id_payer) as unique_payers,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance
FROM claims.v_balance_amount_tab_a_corrected

UNION ALL

SELECT 
  'Tab B (Initial Not Remitted)' as view_name,
  COUNT(*) as total_claims,
  COUNT(DISTINCT facility_group_id) as unique_facilities,
  COUNT(DISTINCT facility_name) as unique_facility_names,
  COUNT(DISTINCT id_payer) as unique_payers,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance
FROM claims.v_balance_amount_tab_b_corrected

UNION ALL

SELECT 
  'Tab C (Resubmitted)' as view_name,
  COUNT(*) as total_claims,
  COUNT(DISTINCT facility_group) as unique_facilities,  -- VERIFIED: Tab C uses 'facility_group'
  COUNT(DISTINCT facility_name) as unique_facility_names,
  COUNT(DISTINCT id_payer) as unique_payers,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance
FROM claims.v_balance_amount_tab_c_corrected;

-- ==========================================================================================================
-- 11. BUSINESS LOGIC VALIDATION
-- ==========================================================================================================

-- Validate that Tab A shows only claims with outstanding balance
SELECT 
  'Tab A Outstanding Balance Check' as test_name,
  COUNT(*) as total_claims,
  COUNT(CASE WHEN outstanding_balance > 0 THEN 1 END) as claims_with_outstanding,
  COUNT(CASE WHEN outstanding_balance = 0 THEN 1 END) as claims_with_zero_outstanding,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance
FROM claims.v_balance_amount_tab_a_corrected;

-- Validate that Tab B shows only initial submissions (no remittances)
SELECT 
  'Tab B Initial Submission Check' as test_name,
  COUNT(*) as total_claims,
  COUNT(CASE WHEN amount_received = 0 THEN 1 END) as claims_with_no_payments,
  COUNT(CASE WHEN amount_received > 0 THEN 1 END) as claims_with_payments,
  ROUND(AVG(amount_received), 2) as avg_amount_received
FROM claims.v_balance_amount_tab_b_corrected;

-- Validate that Tab C shows only resubmitted claims
SELECT 
  'Tab C Resubmission Check' as test_name,
  COUNT(*) as total_claims,
  COUNT(CASE WHEN resubmission_count > 0 THEN 1 END) as claims_with_resubmissions,
  COUNT(CASE WHEN resubmission_count = 0 THEN 1 END) as claims_with_no_resubmissions,
  ROUND(AVG(resubmission_count), 2) as avg_resubmission_count
FROM claims.v_balance_amount_tab_c_corrected;

-- ==========================================================================================================
-- 12. AGING ANALYSIS
-- ==========================================================================================================

-- Analyze aging distribution across all views
SELECT 
  'Base Enhanced' as view_name,
  aging_bucket,
  COUNT(*) as claim_count,
  ROUND(AVG(aging_days), 1) as avg_aging_days,
  ROUND(SUM(pending_amount), 2) as total_pending_amount
FROM claims.v_balance_amount_base_enhanced
WHERE aging_bucket IS NOT NULL
GROUP BY aging_bucket
ORDER BY 
  CASE aging_bucket
    WHEN '0-30' THEN 1
    WHEN '31-60' THEN 2
    WHEN '61-90' THEN 3
    WHEN '90+' THEN 4
  END;

-- ==========================================================================================================
-- 13. FACILITY AND PAYER ANALYSIS
-- ==========================================================================================================

-- Top facilities by outstanding balance
SELECT 
  facility_name,
  COUNT(*) as claim_count,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance
FROM claims.v_balance_amount_tab_a_corrected
WHERE facility_name IS NOT NULL AND facility_name != 'UNKNOWN'
GROUP BY facility_name
ORDER BY total_outstanding_balance DESC
LIMIT 10;

-- Top payers by outstanding balance
SELECT 
  id_payer,
  COUNT(*) as claim_count,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance
FROM claims.v_balance_amount_tab_a_corrected
WHERE id_payer IS NOT NULL AND id_payer != 'UNKNOWN'
GROUP BY id_payer
ORDER BY total_outstanding_balance DESC
LIMIT 10;

-- ==========================================================================================================
-- 14. COMPREHENSIVE COLUMN VERIFICATION
-- ==========================================================================================================

-- Verify all critical columns exist in each view
SELECT 
  'Base Enhanced' as view_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_schema = 'claims' 
  AND table_name = 'v_balance_amount_base_enhanced'
  AND column_name IN (
    'claim_key_id', 'claim_id', 'facility_group_id', 'provider_name', 'payer_name',
    'initial_net_amount', 'pending_amount', 'current_claim_status', 'aging_days', 'aging_bucket'
  )
ORDER BY column_name;

-- ==========================================================================================================
-- QUICK TEST INSTRUCTIONS
-- ==========================================================================================================
-- 1. Run sections 1-2 first to verify basic setup
-- 2. Run section 3 to test base view (should work perfectly)
-- 3. Run sections 4-6 to test each tab view (all columns verified)
-- 4. Run section 7 to test the API function
-- 5. Run sections 8-14 for comprehensive validation and analysis
-- 6. All column names are verified against your actual database structure
-- ==========================================================================================================
