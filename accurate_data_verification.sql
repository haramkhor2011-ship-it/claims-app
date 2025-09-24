-- ==========================================================================================================
-- ACCURATE DATA VERIFICATION - BASED ON ACTUAL DATABASE STRUCTURE
-- ==========================================================================================================
-- Using the actual column names from your database
-- ==========================================================================================================

-- ==========================================================================================================
-- 1. BASIC RECORD COUNTS
-- ==========================================================================================================

SELECT 
  'Base Enhanced View' as view_name,
  COUNT(*) as total_records
FROM claims.v_balance_amount_base_enhanced

UNION ALL

SELECT 
  'Tab A View' as view_name,
  COUNT(*) as total_records
FROM claims.v_balance_amount_tab_a_corrected

UNION ALL

SELECT 
  'Tab B View' as view_name,
  COUNT(*) as total_records
FROM claims.v_balance_amount_tab_b_corrected

UNION ALL

SELECT 
  'Tab C View' as view_name,
  COUNT(*) as total_records
FROM claims.v_balance_amount_tab_c_corrected;

-- ==========================================================================================================
-- 2. SAMPLE DATA FROM BASE VIEW
-- ==========================================================================================================

SELECT 
  claim_key_id,
  claim_id,
  provider_name,
  payer_name,
  initial_net_amount,
  pending_amount,
  current_claim_status,
  aging_days
FROM claims.v_balance_amount_base_enhanced 
LIMIT 3;

-- ==========================================================================================================
-- 3. SAMPLE DATA FROM TAB A
-- ==========================================================================================================

SELECT 
  claim_key_id,
  claim_id,
  facility_name,
  id_payer,
  billed_amount,
  amount_received,
  outstanding_balance,
  claim_status,
  aging_days
FROM claims.v_balance_amount_tab_a_corrected 
LIMIT 3;

-- ==========================================================================================================
-- 4. SAMPLE DATA FROM TAB B
-- ==========================================================================================================

SELECT 
  claim_key_id,
  claim_id,
  facility_name,
  payer_name,
  billed_amount,
  amount_received,
  outstanding_balance,
  claim_status,
  aging_days
FROM claims.v_balance_amount_tab_b_corrected 
LIMIT 3;

-- ==========================================================================================================
-- 5. SAMPLE DATA FROM TAB C
-- ==========================================================================================================

SELECT 
  claim_key_id,
  claim_id,
  facility_name,
  id_payer,
  billed_amount,
  amount_received,
  outstanding_balance,
  resubmission_count,
  claim_status,
  aging_days
FROM claims.v_balance_amount_tab_c_corrected 
LIMIT 3;

-- ==========================================================================================================
-- 6. BUSINESS LOGIC VERIFICATION
-- ==========================================================================================================

-- Check claim status distribution in Base View
SELECT 
  'Base View Status Distribution' as analysis,
  current_claim_status,
  COUNT(*) as count
FROM claims.v_balance_amount_base_enhanced
GROUP BY current_claim_status
ORDER BY count DESC;

-- Check if outstanding balance equals initial amount (should be true for no payments)
SELECT 
  'Outstanding vs Initial Amount Check' as analysis,
  COUNT(*) as total_claims,
  COUNT(CASE WHEN outstanding_balance = billed_amount THEN 1 END) as claims_with_same_amount,
  COUNT(CASE WHEN outstanding_balance < billed_amount THEN 1 END) as claims_with_payments,
  COUNT(CASE WHEN outstanding_balance = 0 THEN 1 END) as claims_fully_paid
FROM claims.v_balance_amount_tab_a_corrected;

-- ==========================================================================================================
-- 7. AGING ANALYSIS
-- ==========================================================================================================

-- Check aging distribution
SELECT 
  'Aging Distribution' as analysis,
  aging_bucket,
  COUNT(*) as claim_count,
  ROUND(AVG(aging_days), 1) as avg_aging_days,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance
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
-- 8. FACILITY ANALYSIS
-- ==========================================================================================================

-- Top facilities by outstanding balance
SELECT 
  'Top Facilities by Outstanding Balance' as analysis,
  facility_name,
  COUNT(*) as claim_count,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance
FROM claims.v_balance_amount_tab_a_corrected
WHERE facility_name IS NOT NULL AND facility_name != 'UNKNOWN'
GROUP BY facility_name
ORDER BY total_outstanding_balance DESC
LIMIT 5;

-- ==========================================================================================================
-- 9. PAYER ANALYSIS
-- ==========================================================================================================

-- Top payers by outstanding balance (using id_payer from Tab A)
SELECT 
  'Top Payers by Outstanding Balance' as analysis,
  id_payer,
  COUNT(*) as claim_count,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance
FROM claims.v_balance_amount_tab_a_corrected
WHERE id_payer IS NOT NULL AND id_payer != 'UNKNOWN'
GROUP BY id_payer
ORDER BY total_outstanding_balance DESC
LIMIT 5;

-- ==========================================================================================================
-- 10. DATA CONSISTENCY CHECKS
-- ==========================================================================================================

-- Check if all views have same number of records
SELECT 
  'Record Count Consistency' as check_name,
  CASE 
    WHEN (SELECT COUNT(*) FROM claims.v_balance_amount_base_enhanced) = 
         (SELECT COUNT(*) FROM claims.v_balance_amount_tab_a_corrected) AND
         (SELECT COUNT(*) FROM claims.v_balance_amount_tab_a_corrected) = 
         (SELECT COUNT(*) FROM claims.v_balance_amount_tab_b_corrected)
    THEN 'PASS - All views have same record count' 
    ELSE 'FAIL - Views have different record counts' 
  END as result;

-- Check if all claims are pending (no payments received)
SELECT 
  'All Claims Pending Check' as check_name,
  CASE 
    WHEN COUNT(*) = COUNT(CASE WHEN current_claim_status = 'PENDING' THEN 1 END) 
    THEN 'PASS - All claims are pending' 
    ELSE 'FAIL - Some claims are not pending' 
  END as result
FROM claims.v_balance_amount_base_enhanced;

-- Check if outstanding balance equals billed amount (no payments)
SELECT 
  'No Payments Received Check' as check_name,
  CASE 
    WHEN COUNT(*) = COUNT(CASE WHEN outstanding_balance = billed_amount THEN 1 END) 
    THEN 'PASS - No payments received yet' 
    ELSE 'FAIL - Some payments have been received' 
  END as result
FROM claims.v_balance_amount_tab_a_corrected;

-- ==========================================================================================================
-- 11. SUMMARY STATISTICS
-- ==========================================================================================================

-- Base View Summary
SELECT 
  'Base View Summary' as view_name,
  COUNT(*) as total_claims,
  COUNT(DISTINCT provider_name) as unique_providers,
  COUNT(DISTINCT payer_name) as unique_payers,
  COUNT(DISTINCT facility_name) as unique_facilities,
  ROUND(AVG(pending_amount), 2) as avg_pending_amount,
  ROUND(SUM(pending_amount), 2) as total_pending_amount
FROM claims.v_balance_amount_base_enhanced;

-- Tab A Summary
SELECT 
  'Tab A Summary' as view_name,
  COUNT(*) as total_claims,
  COUNT(DISTINCT facility_name) as unique_facilities,
  COUNT(DISTINCT id_payer) as unique_payers,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance
FROM claims.v_balance_amount_tab_a_corrected;

-- Tab B Summary
SELECT 
  'Tab B Summary' as view_name,
  COUNT(*) as total_claims,
  COUNT(DISTINCT facility_name) as unique_facilities,
  COUNT(DISTINCT payer_name) as unique_payers,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance
FROM claims.v_balance_amount_tab_b_corrected;

-- Tab C Summary
SELECT 
  'Tab C Summary' as view_name,
  COUNT(*) as total_claims,
  COUNT(DISTINCT facility_name) as unique_facilities,
  COUNT(DISTINCT id_payer) as unique_payers,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance
FROM claims.v_balance_amount_tab_c_corrected;
