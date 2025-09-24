-- ==========================================================================================================
-- BALANCE AMOUNT REPORT - CORRECTED TEST QUERIES
-- ==========================================================================================================
-- Run these queries to verify the report is working correctly
-- FIXED: Column names match actual view structures and function signatures
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
-- 4. TAB A TEST (Balance Amount to be received) - FIXED COLUMNS
-- ==========================================================================================================

-- Test Tab A view (limit to 3 rows for quick check)
-- FIXED: Using actual column names from the view
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
-- 5. TAB B TEST (Initial Not Remitted Balance) - FIXED COLUMNS
-- ==========================================================================================================

-- Test Tab B view (limit to 3 rows for quick check)
-- FIXED: Using actual column names from the view
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
-- 6. TAB C TEST (Resubmitted Balance) - FIXED COLUMNS
-- ==========================================================================================================

-- Test Tab C view (limit to 3 rows for quick check)
-- FIXED: Using actual column names from the view (Tab C uses 'facility_group' not 'facility_group_id')
SELECT 
  claim_key_id,
  claim_id,
  facility_group,  -- CORRECTED: Tab C uses 'facility_group' not 'facility_group_id'
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
  resubmission_count,
  last_resubmission_date,
  last_resubmission_comment
FROM claims.v_balance_amount_tab_c_corrected 
LIMIT 3;

-- ==========================================================================================================
-- 7. FUNCTION TEST - FIXED PARAMETERS
-- ==========================================================================================================

-- Test the API function (this should return a result set)
-- FIXED: Using correct parameter names and types
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
-- 8. DATA QUALITY CHECKS - FIXED COLUMNS
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
FROM claims.v_balance_amount_tab_a_corrected;

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
-- 10. SUMMARY STATISTICS - FIXED COLUMNS
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
  COUNT(DISTINCT facility_name) as unique_facilities,
  COUNT(DISTINCT id_payer) as unique_payers,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance
FROM claims.v_balance_amount_tab_a_corrected

UNION ALL

SELECT 
  'Tab B (Initial Not Remitted)' as view_name,
  COUNT(*) as total_claims,
  COUNT(DISTINCT facility_group_id) as unique_facilities,
  COUNT(DISTINCT facility_name) as unique_facilities,
  COUNT(DISTINCT id_payer) as unique_payers,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance
FROM claims.v_balance_amount_tab_b_corrected

UNION ALL

SELECT 
  'Tab C (Resubmitted)' as view_name,
  COUNT(*) as total_claims,
  COUNT(DISTINCT facility_group) as unique_facilities,  -- CORRECTED: Tab C uses 'facility_group'
  COUNT(DISTINCT facility_name) as unique_facility_names,
  COUNT(DISTINCT id_payer) as unique_payers,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance
FROM claims.v_balance_amount_tab_c_corrected;

-- ==========================================================================================================
-- 11. COLUMN MAPPING VERIFICATION
-- ==========================================================================================================

-- Verify what columns are actually available in each view
SELECT 
  'Base Enhanced' as view_name,
  column_name,
  data_type
FROM information_schema.columns 
WHERE table_schema = 'claims' 
  AND table_name = 'v_balance_amount_base_enhanced'
  AND column_name IN ('provider_name', 'payer_name', 'facility_name', 'claim_key_id', 'pending_amount')
ORDER BY column_name

UNION ALL

SELECT 
  'Tab A' as view_name,
  column_name,
  data_type
FROM information_schema.columns 
WHERE table_schema = 'claims' 
  AND table_name = 'v_balance_amount_tab_a_corrected'
  AND column_name IN ('facility_group_id', 'facility_name', 'id_payer', 'claim_key_id', 'outstanding_balance', 'billed_amount')
ORDER BY column_name

UNION ALL

SELECT 
  'Tab C' as view_name,
  column_name,
  data_type
FROM information_schema.columns 
WHERE table_schema = 'claims' 
  AND table_name = 'v_balance_amount_tab_c_corrected'
  AND column_name IN ('facility_group', 'facility_name', 'id_payer', 'claim_key_id', 'outstanding_balance', 'billed_amount')
ORDER BY column_name;

-- ==========================================================================================================
-- QUICK TEST INSTRUCTIONS
-- ==========================================================================================================
-- 1. Run sections 1-2 first to verify basic setup
-- 2. Run section 3 to test base view (should work)
-- 3. Run sections 4-6 to test each tab view (now with correct columns)
-- 4. Run section 7 to test the API function (now with correct parameters)
-- 5. Run sections 8-11 for data quality and performance checks
-- 6. If any section fails, check the error message and let me know
-- ==========================================================================================================
