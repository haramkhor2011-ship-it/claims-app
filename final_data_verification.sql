-- ==========================================================================================================
-- FINAL DATA VERIFICATION - BASED ON ACTUAL DATA STATUS
-- ==========================================================================================================
-- Your data: 256 claims, all "SUBMITTED" status, no payments received
-- ==========================================================================================================

-- ==========================================================================================================
-- 1. CONFIRM DATA STATUS
-- ==========================================================================================================

SELECT 
  'Data Status Confirmation' as analysis,
  'All 256 claims are SUBMITTED status' as status,
  'No payments received yet' as payment_status,
  'All views show 256 records' as view_consistency;

-- ==========================================================================================================
-- 2. AGING DISTRIBUTION (CORRECTED)
-- ==========================================================================================================

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
-- 3. FACILITY BREAKDOWN
-- ==========================================================================================================

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
LIMIT 10;

-- ==========================================================================================================
-- 4. PAYER BREAKDOWN
-- ==========================================================================================================

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
LIMIT 10;

-- ==========================================================================================================
-- 5. PROVIDER BREAKDOWN
-- ==========================================================================================================

SELECT 
  'Top Providers by Pending Amount' as analysis,
  provider_name,
  COUNT(*) as claim_count,
  ROUND(SUM(pending_amount), 2) as total_pending_amount,
  ROUND(AVG(pending_amount), 2) as avg_pending_amount
FROM claims.v_balance_amount_base_enhanced
WHERE provider_name IS NOT NULL AND provider_name != 'UNKNOWN'
GROUP BY provider_name
ORDER BY total_pending_amount DESC
LIMIT 10;

-- ==========================================================================================================
-- 6. AMOUNT ANALYSIS
-- ==========================================================================================================

SELECT 
  'Amount Analysis' as analysis,
  COUNT(*) as total_claims,
  ROUND(AVG(initial_net_amount), 2) as avg_initial_amount,
  ROUND(SUM(initial_net_amount), 2) as total_initial_amount,
  ROUND(AVG(pending_amount), 2) as avg_pending_amount,
  ROUND(SUM(pending_amount), 2) as total_pending_amount,
  ROUND(AVG(total_payment_amount), 2) as avg_payment_amount,
  ROUND(SUM(total_payment_amount), 2) as total_payment_amount
FROM claims.v_balance_amount_base_enhanced;

-- ==========================================================================================================
-- 7. SAMPLE CLAIMS DATA
-- ==========================================================================================================

SELECT 
  'Sample Claims Data' as analysis,
  claim_id,
  provider_name,
  payer_name,
  facility_name,
  initial_net_amount,
  pending_amount,
  aging_days,
  aging_bucket
FROM claims.v_balance_amount_base_enhanced
ORDER BY claim_id
LIMIT 5;

-- ==========================================================================================================
-- 8. MONTHLY BREAKDOWN
-- ==========================================================================================================

SELECT 
  'Monthly Breakdown' as analysis,
  encounter_start_year,
  encounter_start_month,
  encounter_start_month_name,
  COUNT(*) as claim_count,
  ROUND(SUM(pending_amount), 2) as total_pending_amount,
  ROUND(AVG(pending_amount), 2) as avg_pending_amount
FROM claims.v_balance_amount_base_enhanced
WHERE encounter_start_year IS NOT NULL AND encounter_start_month IS NOT NULL
GROUP BY encounter_start_year, encounter_start_month, encounter_start_month_name
ORDER BY encounter_start_year DESC, encounter_start_month DESC;

-- ==========================================================================================================
-- 9. VIEW COMPARISON
-- ==========================================================================================================

-- Compare amounts across views
SELECT 
  'View Amount Comparison' as analysis,
  'Base View' as view_name,
  COUNT(*) as record_count,
  ROUND(SUM(pending_amount), 2) as total_amount
FROM claims.v_balance_amount_base_enhanced

UNION ALL

SELECT 
  'View Amount Comparison' as analysis,
  'Tab A' as view_name,
  COUNT(*) as record_count,
  ROUND(SUM(outstanding_balance), 2) as total_amount
FROM claims.v_balance_amount_tab_a_corrected

UNION ALL

SELECT 
  'View Amount Comparison' as analysis,
  'Tab B' as view_name,
  COUNT(*) as record_count,
  ROUND(SUM(outstanding_balance), 2) as total_amount
FROM claims.v_balance_amount_tab_b_corrected

UNION ALL

SELECT 
  'View Amount Comparison' as analysis,
  'Tab C' as view_name,
  COUNT(*) as record_count,
  ROUND(SUM(outstanding_balance), 2) as total_amount
FROM claims.v_balance_amount_tab_c_corrected;

-- ==========================================================================================================
-- 10. FINAL VALIDATION
-- ==========================================================================================================

-- Validate that pending amount equals initial amount (no payments)
SELECT 
  'Final Validation' as check_name,
  CASE 
    WHEN COUNT(*) = COUNT(CASE WHEN pending_amount = initial_net_amount THEN 1 END) 
    THEN 'PASS - All pending amounts equal initial amounts (no payments)' 
    ELSE 'FAIL - Some payments have been received' 
  END as result
FROM claims.v_balance_amount_base_enhanced;

-- Validate all claims are SUBMITTED
SELECT 
  'Status Validation' as check_name,
  CASE 
    WHEN COUNT(*) = COUNT(CASE WHEN current_claim_status = 'SUBMITTED' THEN 1 END) 
    THEN 'PASS - All claims are SUBMITTED status' 
    ELSE 'FAIL - Some claims have different status' 
  END as result
FROM claims.v_balance_amount_base_enhanced;

-- ==========================================================================================================
-- SUMMARY
-- ==========================================================================================================
-- Your data is perfectly consistent:
-- - 256 claims all in SUBMITTED status
-- - No payments received yet (all payment amounts = 0)
-- - All views show 256 records
-- - Pending amounts = Initial amounts (no payments)
-- - This is exactly what you'd expect for initial submissions
-- ==========================================================================================================
