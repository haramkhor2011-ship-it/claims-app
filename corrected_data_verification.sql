-- ==========================================================================================================
-- CORRECTED DATA VERIFICATION - FIXED COLUMN NAMES
-- ==========================================================================================================
-- Fixed based on actual database structure
-- ==========================================================================================================

-- ==========================================================================================================
-- 1. CHECK CLAIM STATUS DISTRIBUTION
-- ==========================================================================================================

-- Let's see what statuses exist (this explains the "FAIL" result)
SELECT 
  'Claim Status Distribution' as analysis,
  current_claim_status,
  COUNT(*) as count
FROM claims.v_balance_amount_base_enhanced
GROUP BY current_claim_status
ORDER BY count DESC;

-- ==========================================================================================================
-- 2. CORRECTED AGING ANALYSIS (using pending_amount from base view)
-- ==========================================================================================================

-- Check aging distribution using correct column names
SELECT 
  'Aging Distribution' as analysis,
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
-- 3. FACILITY ANALYSIS (using correct columns)
-- ==========================================================================================================

-- Top facilities by pending amount (from base view)
SELECT 
  'Top Facilities by Pending Amount' as analysis,
  facility_name,
  COUNT(*) as claim_count,
  ROUND(SUM(pending_amount), 2) as total_pending_amount,
  ROUND(AVG(pending_amount), 2) as avg_pending_amount
FROM claims.v_balance_amount_base_enhanced
WHERE facility_name IS NOT NULL AND facility_name != 'UNKNOWN'
GROUP BY facility_name
ORDER BY total_pending_amount DESC
LIMIT 5;

-- ==========================================================================================================
-- 4. PAYER ANALYSIS (using correct columns)
-- ==========================================================================================================

-- Top payers by pending amount (from base view)
SELECT 
  'Top Payers by Pending Amount' as analysis,
  payer_name,
  COUNT(*) as claim_count,
  ROUND(SUM(pending_amount), 2) as total_pending_amount,
  ROUND(AVG(pending_amount), 2) as avg_pending_amount
FROM claims.v_balance_amount_base_enhanced
WHERE payer_name IS NOT NULL AND payer_name != 'UNKNOWN'
GROUP BY payer_name
ORDER BY total_pending_amount DESC
LIMIT 5;

-- ==========================================================================================================
-- 5. DETAILED STATUS ANALYSIS
-- ==========================================================================================================

-- Let's see what non-pending statuses exist
SELECT 
  'Non-Pending Claims Analysis' as analysis,
  current_claim_status,
  COUNT(*) as count,
  ROUND(AVG(pending_amount), 2) as avg_pending_amount,
  ROUND(SUM(pending_amount), 2) as total_pending_amount
FROM claims.v_balance_amount_base_enhanced
WHERE current_claim_status != 'PENDING'
GROUP BY current_claim_status
ORDER BY count DESC;

-- ==========================================================================================================
-- 6. PAYMENT ANALYSIS
-- ==========================================================================================================

-- Check payment amounts in base view
SELECT 
  'Payment Analysis' as analysis,
  COUNT(*) as total_claims,
  COUNT(CASE WHEN total_payment_amount > 0 THEN 1 END) as claims_with_payments,
  COUNT(CASE WHEN total_payment_amount = 0 THEN 1 END) as claims_with_no_payments,
  ROUND(AVG(total_payment_amount), 2) as avg_payment_amount,
  ROUND(SUM(total_payment_amount), 2) as total_payment_amount
FROM claims.v_balance_amount_base_enhanced;

-- ==========================================================================================================
-- 7. REMITTANCE ANALYSIS
-- ==========================================================================================================

-- Check remittance counts
SELECT 
  'Remittance Analysis' as analysis,
  COUNT(*) as total_claims,
  COUNT(CASE WHEN remittance_count > 0 THEN 1 END) as claims_with_remittances,
  COUNT(CASE WHEN remittance_count = 0 THEN 1 END) as claims_with_no_remittances,
  ROUND(AVG(remittance_count), 2) as avg_remittance_count,
  MAX(remittance_count) as max_remittance_count
FROM claims.v_balance_amount_base_enhanced;

-- ==========================================================================================================
-- 8. RESUBMISSION ANALYSIS
-- ==========================================================================================================

-- Check resubmission counts
SELECT 
  'Resubmission Analysis' as analysis,
  COUNT(*) as total_claims,
  COUNT(CASE WHEN resubmission_count > 0 THEN 1 END) as claims_with_resubmissions,
  COUNT(CASE WHEN resubmission_count = 0 THEN 1 END) as claims_with_no_resubmissions,
  ROUND(AVG(resubmission_count), 2) as avg_resubmission_count,
  MAX(resubmission_count) as max_resubmission_count
FROM claims.v_balance_amount_base_enhanced;

-- ==========================================================================================================
-- 9. SAMPLE NON-PENDING CLAIMS
-- ==========================================================================================================

-- Show sample claims that are not pending
SELECT 
  'Sample Non-Pending Claims' as analysis,
  claim_id,
  current_claim_status,
  pending_amount,
  total_payment_amount,
  remittance_count,
  resubmission_count,
  aging_days
FROM claims.v_balance_amount_base_enhanced
WHERE current_claim_status != 'PENDING'
LIMIT 5;

-- ==========================================================================================================
-- 10. CORRECTED SUMMARY STATISTICS
-- ==========================================================================================================

-- Base View Summary (using correct columns)
SELECT 
  'Base View Summary' as view_name,
  COUNT(*) as total_claims,
  COUNT(DISTINCT provider_name) as unique_providers,
  COUNT(DISTINCT payer_name) as unique_payers,
  COUNT(DISTINCT facility_name) as unique_facilities,
  ROUND(AVG(pending_amount), 2) as avg_pending_amount,
  ROUND(SUM(pending_amount), 2) as total_pending_amount,
  ROUND(AVG(total_payment_amount), 2) as avg_payment_amount,
  ROUND(SUM(total_payment_amount), 2) as total_payment_amount
FROM claims.v_balance_amount_base_enhanced;

-- ==========================================================================================================
-- 11. CORRECTED DATA CONSISTENCY CHECKS
-- ==========================================================================================================

-- Check if pending amount equals initial amount (should be true for no payments)
SELECT 
  'Pending vs Initial Amount Check' as check_name,
  CASE 
    WHEN COUNT(*) = COUNT(CASE WHEN pending_amount = initial_net_amount THEN 1 END) 
    THEN 'PASS - No payments received yet' 
    ELSE 'FAIL - Some payments have been received' 
  END as result
FROM claims.v_balance_amount_base_enhanced;

-- Check if all claims have zero payment amount
SELECT 
  'Zero Payment Amount Check' as check_name,
  CASE 
    WHEN COUNT(*) = COUNT(CASE WHEN total_payment_amount = 0 THEN 1 END) 
    THEN 'PASS - No payments received yet' 
    ELSE 'FAIL - Some payments have been received' 
  END as result
FROM claims.v_balance_amount_base_enhanced;
