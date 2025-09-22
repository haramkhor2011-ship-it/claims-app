-- ==========================================================================================================
-- BALANCE AMOUNT REPORT - QUICK TEST QUERIES
-- ==========================================================================================================
-- Run these queries to verify the report is working correctly
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
-- 3. BASE VIEW TEST
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
-- 4. TAB A TEST (Balance Amount to be received)
-- ==========================================================================================================

-- Test Tab A view (limit to 3 rows for quick check)
SELECT 
  claim_key_id,
  claim_id,
  facility_group_id,
  provider_name,
  payer_name,
  initial_net_amount,
  pending_amount,
  current_claim_status,
  aging_bucket
FROM claims.v_balance_amount_tab_a_corrected 
LIMIT 3;

-- ==========================================================================================================
-- 5. TAB B TEST (Initial Not Remitted Balance)
-- ==========================================================================================================

-- Test Tab B view (limit to 3 rows for quick check)
SELECT 
  claim_key_id,
  claim_id,
  facility_group_id,
  provider_name,
  payer_name,
  initial_net_amount,
  pending_amount,
  current_claim_status
FROM claims.v_balance_amount_tab_b_corrected 
LIMIT 3;

-- ==========================================================================================================
-- 6. TAB C TEST (Resubmitted Balance)
-- ==========================================================================================================

-- Test Tab C view (limit to 3 rows for quick check)
SELECT 
  claim_key_id,
  claim_id,
  facility_group_id,
  provider_name,
  payer_name,
  initial_net_amount,
  pending_amount,
  resubmission_count,
  last_resubmission_date
FROM claims.v_balance_amount_tab_c_corrected 
LIMIT 3;

-- ==========================================================================================================
-- 7. FUNCTION TEST
-- ==========================================================================================================

-- Test the API function (this should return a result set)
SELECT * FROM claims.get_balance_amount_tab_a_corrected(
  'test_user',           -- user_id
  ARRAY['ALL'],          -- facility_ids (ALL means no filter)
  ARRAY['ALL'],          -- payer_ids (ALL means no filter)
  '2024-01-01'::date,    -- start_date
  '2024-12-31'::date,    -- end_date
  '2024-01-01'::date,    -- encounter_start_date
  '2024-12-31'::date,    -- encounter_end_date
  10,                    -- limit
  0                      -- offset
);

-- ==========================================================================================================
-- 8. DATA QUALITY CHECKS
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
  COUNT(*) - COUNT(provider_name) as null_provider_name,
  COUNT(*) - COUNT(payer_name) as null_payer_name
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
-- 10. SUMMARY STATISTICS
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
  COUNT(DISTINCT provider_name) as unique_providers,
  COUNT(DISTINCT payer_name) as unique_payers,
  ROUND(AVG(pending_amount), 2) as avg_pending_amount,
  ROUND(SUM(pending_amount), 2) as total_pending_amount
FROM claims.v_balance_amount_tab_a_corrected

UNION ALL

SELECT 
  'Tab B (Initial Not Remitted)' as view_name,
  COUNT(*) as total_claims,
  COUNT(DISTINCT facility_group_id) as unique_facilities,
  COUNT(DISTINCT provider_name) as unique_providers,
  COUNT(DISTINCT payer_name) as unique_payers,
  ROUND(AVG(pending_amount), 2) as avg_pending_amount,
  ROUND(SUM(pending_amount), 2) as total_pending_amount
FROM claims.v_balance_amount_tab_b_corrected

UNION ALL

SELECT 
  'Tab C (Resubmitted)' as view_name,
  COUNT(*) as total_claims,
  COUNT(DISTINCT facility_group_id) as unique_facilities,
  COUNT(DISTINCT provider_name) as unique_providers,
  COUNT(DISTINCT payer_name) as unique_payers,
  ROUND(AVG(pending_amount), 2) as avg_pending_amount,
  ROUND(SUM(pending_amount), 2) as total_pending_amount
FROM claims.v_balance_amount_tab_c_corrected;

-- ==========================================================================================================
-- QUICK TEST INSTRUCTIONS
-- ==========================================================================================================
-- 1. Run sections 1-2 first to verify basic setup
-- 2. Run sections 3-6 to test each view
-- 3. Run section 7 to test the API function
-- 4. Run sections 8-10 for data quality and performance checks
-- 5. If any section fails, check the error message and let me know tomorrow
-- ==========================================================================================================
