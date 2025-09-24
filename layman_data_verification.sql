-- ==========================================================================================================
-- LAYMAN DATA VERIFICATION - UNDERSTAND YOUR DATA STEP BY STEP
-- ==========================================================================================================
-- This will help you understand what each view is showing and verify the data is correct
-- ==========================================================================================================

-- ==========================================================================================================
-- 1. UNDERSTAND YOUR BASE DATA
-- ==========================================================================================================

-- Let's look at a few sample claims to understand what we have
SELECT 
  'SAMPLE CLAIMS' as section,
  '' as claim_id,
  '' as provider_id,
  '' as payer_id,
  '' as net_amount,
  '' as created_at

UNION ALL

SELECT 
  'Sample Claim 1' as section,
  ck.claim_id,
  c.provider_id,
  c.payer_id,
  c.net::text as net_amount,
  c.created_at::text as created_at
FROM claims.claim c
JOIN claims.claim_key ck ON ck.id = c.claim_key_id
ORDER BY c.created_at DESC
LIMIT 1;

-- ==========================================================================================================
-- 2. UNDERSTAND WHAT EACH VIEW SHOWS
-- ==========================================================================================================

-- Base View: Shows ALL claims with their current status
SELECT 
  'BASE VIEW SUMMARY' as view_name,
  COUNT(*) as total_records,
  COUNT(DISTINCT claim_id) as unique_claims,
  COUNT(DISTINCT provider_name) as unique_providers,
  COUNT(DISTINCT payer_name) as unique_payers,
  ROUND(AVG(pending_amount), 2) as avg_pending_amount,
  ROUND(SUM(pending_amount), 2) as total_pending_amount
FROM claims.v_balance_amount_base_enhanced;

-- Tab A: Shows claims that have outstanding balance (money still owed)
SELECT 
  'TAB A SUMMARY (Outstanding Balance)' as view_name,
  COUNT(*) as total_records,
  COUNT(DISTINCT claim_id) as unique_claims,
  COUNT(DISTINCT facility_name) as unique_facilities,
  COUNT(DISTINCT id_payer) as unique_payers,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance
FROM claims.v_balance_amount_tab_a_corrected;

-- Tab B: Shows initial submissions that haven't been paid yet
SELECT 
  'TAB B SUMMARY (Initial Not Paid)' as view_name,
  COUNT(*) as total_records,
  COUNT(DISTINCT claim_id) as unique_claims,
  COUNT(DISTINCT facility_name) as unique_facilities,
  COUNT(DISTINCT id_payer) as unique_payers,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance
FROM claims.v_balance_amount_tab_b_corrected;

-- Tab C: Shows claims that have been resubmitted (should be 0 since no resubmissions)
SELECT 
  'TAB C SUMMARY (Resubmitted Claims)' as view_name,
  COUNT(*) as total_records,
  COUNT(DISTINCT claim_id) as unique_claims,
  COUNT(DISTINCT facility_name) as unique_facilities,
  COUNT(DISTINCT id_payer) as unique_payers,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance
FROM claims.v_balance_amount_tab_c_corrected;

-- ==========================================================================================================
-- 3. VERIFY BUSINESS LOGIC
-- ==========================================================================================================

-- Check: Are all claims showing as "PENDING" status? (They should be since no payments)
SELECT 
  'CLAIM STATUS DISTRIBUTION' as analysis,
  current_claim_status,
  COUNT(*) as count
FROM claims.v_balance_amount_base_enhanced
GROUP BY current_claim_status
ORDER BY count DESC;

-- Check: Are all claims showing outstanding balance = initial amount? (They should be since no payments)
SELECT 
  'OUTSTANDING BALANCE CHECK' as analysis,
  COUNT(*) as total_claims,
  COUNT(CASE WHEN outstanding_balance = initial_net_amount THEN 1 END) as claims_with_full_outstanding,
  COUNT(CASE WHEN outstanding_balance < initial_net_amount THEN 1 END) as claims_with_partial_payment,
  COUNT(CASE WHEN outstanding_balance = 0 THEN 1 END) as claims_fully_paid
FROM claims.v_balance_amount_tab_a_corrected;

-- ==========================================================================================================
-- 4. SAMPLE DATA INSPECTION
-- ==========================================================================================================

-- Look at a few sample records from each view to understand the data
SELECT 
  'SAMPLE BASE VIEW RECORDS' as section,
  '' as claim_id,
  '' as provider_name,
  '' as payer_name,
  '' as initial_net_amount,
  '' as pending_amount,
  '' as current_claim_status

UNION ALL

SELECT 
  'Sample 1' as section,
  claim_id,
  provider_name,
  payer_name,
  initial_net_amount::text,
  pending_amount::text,
  current_claim_status
FROM claims.v_balance_amount_base_enhanced
ORDER BY claim_id
LIMIT 1;

-- ==========================================================================================================
-- 5. DATA CONSISTENCY CHECKS
-- ==========================================================================================================

-- Check: Do all views have the same number of records? (They should since no payments/resubmissions)
SELECT 
  'VIEW RECORD COUNTS' as analysis,
  'Base View' as view_name,
  COUNT(*)::text as record_count
FROM claims.v_balance_amount_base_enhanced

UNION ALL

SELECT 
  'VIEW RECORD COUNTS' as analysis,
  'Tab A' as view_name,
  COUNT(*)::text as record_count
FROM claims.v_balance_amount_tab_a_corrected

UNION ALL

SELECT 
  'VIEW RECORD COUNTS' as analysis,
  'Tab B' as view_name,
  COUNT(*)::text as record_count
FROM claims.v_balance_amount_tab_b_corrected

UNION ALL

SELECT 
  'VIEW RECORD COUNTS' as analysis,
  'Tab C' as view_name,
  COUNT(*)::text as record_count
FROM claims.v_balance_amount_tab_c_corrected;

-- ==========================================================================================================
-- 6. AGING ANALYSIS
-- ==========================================================================================================

-- Check: How old are these claims? (This helps understand if they're recent submissions)
SELECT 
  'CLAIM AGING ANALYSIS' as analysis,
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
-- 7. FACILITY AND PAYER BREAKDOWN
-- ==========================================================================================================

-- Check: Which facilities have the most outstanding claims?
SELECT 
  'TOP FACILITIES BY OUTSTANDING AMOUNT' as analysis,
  facility_name,
  COUNT(*) as claim_count,
  ROUND(SUM(outstanding_balance), 2) as total_outstanding_balance,
  ROUND(AVG(outstanding_balance), 2) as avg_outstanding_balance
FROM claims.v_balance_amount_tab_a_corrected
WHERE facility_name IS NOT NULL AND facility_name != 'UNKNOWN'
GROUP BY facility_name
ORDER BY total_outstanding_balance DESC
LIMIT 5;

-- Check: Which payers have the most outstanding claims?
SELECT 
  'TOP PAYERS BY OUTSTANDING AMOUNT' as analysis,
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
-- 8. SIMPLE VALIDATION QUESTIONS
-- ==========================================================================================================

-- Question 1: Are all claims showing the same amount in initial_net_amount and outstanding_balance?
-- Answer: YES = No payments received yet, NO = Some payments received
SELECT 
  'SAME AMOUNT CHECK' as question,
  CASE 
    WHEN COUNT(*) = COUNT(CASE WHEN outstanding_balance = initial_net_amount THEN 1 END) 
    THEN 'YES - No payments received yet' 
    ELSE 'NO - Some payments received' 
  END as answer
FROM claims.v_balance_amount_tab_a_corrected;

-- Question 2: Are all claims showing as PENDING status?
-- Answer: YES = No remittances processed yet, NO = Some remittances processed
SELECT 
  'PENDING STATUS CHECK' as question,
  CASE 
    WHEN COUNT(*) = COUNT(CASE WHEN current_claim_status = 'PENDING' THEN 1 END) 
    THEN 'YES - No remittances processed yet' 
    ELSE 'NO - Some remittances processed' 
  END as answer
FROM claims.v_balance_amount_base_enhanced;

-- Question 3: Do all views show the same number of records?
-- Answer: YES = Data is consistent, NO = There might be an issue
SELECT 
  'SAME RECORD COUNT CHECK' as question,
  CASE 
    WHEN (SELECT COUNT(*) FROM claims.v_balance_amount_base_enhanced) = 
         (SELECT COUNT(*) FROM claims.v_balance_amount_tab_a_corrected) AND
         (SELECT COUNT(*) FROM claims.v_balance_amount_tab_a_corrected) = 
         (SELECT COUNT(*) FROM claims.v_balance_amount_tab_b_corrected)
    THEN 'YES - Data is consistent' 
    ELSE 'NO - There might be an issue' 
  END as answer;

-- ==========================================================================================================
-- LAYMAN EXPLANATION
-- ==========================================================================================================
-- 1. Base View: Shows ALL your claims with their current status
-- 2. Tab A: Shows claims that still have money owed (outstanding balance)
-- 3. Tab B: Shows initial submissions that haven't been paid yet
-- 4. Tab C: Shows claims that have been resubmitted (should be 0 for you)
-- 5. All views showing 256 records means all your claims are in the same state
-- 6. This is normal for initial submissions with no payments yet
-- ==========================================================================================================
