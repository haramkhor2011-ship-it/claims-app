-- ==========================================================================================================
-- MANUAL TESTING QUERIES FOR REJECTED CLAIMS REPORT
-- ==========================================================================================================
-- 
-- Date: 2025-09-24
-- Purpose: Manual testing queries to verify the Rejected Claims Report implementation
-- 
-- Run these queries one by one to test different aspects of the report
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: BASIC FUNCTIONALITY TESTS
-- ==========================================================================================================

-- Test 1: Check if all views exist
SELECT 
    'View Existence Check' as test_name,
    schemaname,
    viewname,
    'EXISTS' as status
FROM pg_views 
WHERE schemaname = 'claims' 
AND viewname IN (
    'v_rejected_claims_base',
    'v_rejected_claims_summary', 
    'v_rejected_claims_tab_a',
    'v_rejected_claims_tab_b',
    'v_rejected_claims_tab_c'
)
ORDER BY viewname;

-- Test 2: Check if all functions exist
SELECT 
    'Function Existence Check' as test_name,
    routine_schema,
    routine_name,
    'EXISTS' as status
FROM information_schema.routines 
WHERE routine_schema = 'claims' 
AND routine_name IN (
    'get_rejected_claims_tab_a',
    'get_rejected_claims_tab_b',
    'get_rejected_claims_tab_c'
)
ORDER BY routine_name;

-- ==========================================================================================================
-- SECTION 2: DATA QUALITY TESTS
-- ==========================================================================================================

-- Test 3: Check base view data
SELECT 
    'Base View Data Check' as test_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN rejection_type IS NOT NULL THEN 1 END) as records_with_rejection_type,
    COUNT(CASE WHEN rejected_amount IS NOT NULL THEN 1 END) as records_with_rejected_amount,
    COUNT(CASE WHEN facility_name IS NOT NULL THEN 1 END) as records_with_facility_name,
    COUNT(CASE WHEN payer_name IS NOT NULL THEN 1 END) as records_with_payer_name
FROM claims.v_rejected_claims_base;

-- Test 4: Check rejection type distribution
SELECT 
    'Rejection Type Distribution' as analysis_type,
    rejection_type,
    COUNT(*) as record_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM claims.v_rejected_claims_base
GROUP BY rejection_type
ORDER BY record_count DESC;

-- Test 5: Check denial code distribution
SELECT 
    'Denial Code Distribution' as analysis_type,
    activity_denial_code,
    denial_type,
    COUNT(*) as record_count
FROM claims.v_rejected_claims_base
WHERE activity_denial_code IS NOT NULL
GROUP BY activity_denial_code, denial_type
ORDER BY record_count DESC
LIMIT 10;

-- ==========================================================================================================
-- SECTION 3: BUSINESS LOGIC TESTS
-- ==========================================================================================================

-- Test 6: Validate rejection type logic
SELECT 
    'Rejection Type Logic Validation' as test_name,
    rejection_type,
    COUNT(*) as total_records,
    COUNT(CASE 
        WHEN rejection_type = 'Fully Rejected' AND activity_payment_amount = 0 THEN 1 
    END) as correct_fully_rejected,
    COUNT(CASE 
        WHEN rejection_type = 'Partially Rejected' AND activity_payment_amount > 0 AND activity_payment_amount < activity_net_amount THEN 1 
    END) as correct_partially_rejected,
    COUNT(CASE 
        WHEN rejection_type = 'Fully Paid' AND activity_payment_amount = activity_net_amount THEN 1 
    END) as correct_fully_paid
FROM claims.v_rejected_claims_base
GROUP BY rejection_type
ORDER BY total_records DESC;

-- Test 7: Validate rejected amount calculations
SELECT 
    'Rejected Amount Calculation Validation' as test_name,
    rejection_type,
    COUNT(*) as total_records,
    COUNT(CASE 
        WHEN rejection_type = 'Fully Rejected' AND rejected_amount = activity_net_amount THEN 1 
    END) as correct_fully_rejected_amount,
    COUNT(CASE 
        WHEN rejection_type = 'Partially Rejected' AND rejected_amount = (activity_net_amount - activity_payment_amount) THEN 1 
    END) as correct_partially_rejected_amount,
    COUNT(CASE 
        WHEN rejection_type = 'Fully Paid' AND rejected_amount = 0 THEN 1 
    END) as correct_fully_paid_amount
FROM claims.v_rejected_claims_base
GROUP BY rejection_type
ORDER BY total_records DESC;

-- ==========================================================================================================
-- SECTION 4: TAB-SPECIFIC TESTS
-- ==========================================================================================================

-- Test 8: Tab A (Detailed Rejected Claims) - Check data
SELECT 
    'Tab A Data Check' as test_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN rejected_amt_detail IS NOT NULL THEN 1 END) as records_with_rejected_amount,
    COUNT(CASE WHEN facility_name IS NOT NULL THEN 1 END) as records_with_facility_name,
    COUNT(CASE WHEN payer_name IS NOT NULL THEN 1 END) as records_with_payer_name,
    COUNT(CASE WHEN clinician_name IS NOT NULL THEN 1 END) as records_with_clinician_name
FROM claims.v_rejected_claims_tab_a;

-- Test 9: Tab B (Summary by Facility) - Check data
SELECT 
    'Tab B Data Check' as test_name,
    COUNT(*) as total_facilities,
    SUM(total_claim) as total_claims,
    SUM(total_rejected_amt) as total_rejected_amount,
    SUM(total_paid_amt) as total_paid_amount,
    ROUND(AVG(rejection_percentage), 2) as avg_rejection_percentage
FROM claims.v_rejected_claims_tab_b;

-- Test 10: Tab C (Summary by Payer) - Check data
SELECT 
    'Tab C Data Check' as test_name,
    COUNT(*) as total_payers,
    SUM(total_claim) as total_claims,
    SUM(total_rejected_amt) as total_rejected_amount,
    SUM(total_paid_amt) as total_paid_amount,
    ROUND(AVG(rejection_percentage), 2) as avg_rejection_percentage
FROM claims.v_rejected_claims_tab_c;

-- ==========================================================================================================
-- SECTION 5: API FUNCTION TESTS
-- ==========================================================================================================

-- Test 11: Test Tab A API function
SELECT 
    'Tab A API Function Test' as test_name,
    COUNT(*) as result_count,
    COUNT(CASE WHEN facility_name IS NOT NULL THEN 1 END) as records_with_facility_name,
    COUNT(CASE WHEN payer_name IS NOT NULL THEN 1 END) as records_with_payer_name
FROM claims.get_rejected_claims_tab_a(
    'test_user',
    NULL,  -- facility_id
    NULL,  -- payer_id
    NULL,  -- clinician_id
    NULL,  -- start_date
    NULL,  -- end_date
    NULL,  -- claim_year
    NULL,  -- denial_code
    10,    -- limit
    0,     -- offset
    'facility_name',  -- sort_by
    'ASC'  -- sort_order
);

-- Test 12: Test Tab B API function
SELECT 
    'Tab B API Function Test' as test_name,
    COUNT(*) as result_count,
    SUM(total_claim) as total_claims,
    SUM(total_rejected_amt) as total_rejected_amount
FROM claims.get_rejected_claims_tab_b(
    'test_user',
    NULL,  -- facility_id
    NULL,  -- payer_id
    NULL,  -- start_date
    NULL,  -- end_date
    2024,  -- claim_year
    NULL,  -- denial_code
    10,    -- limit
    0,     -- offset
    'receiver_name',  -- sort_by
    'ASC'  -- sort_order
);

-- Test 13: Test Tab C API function
SELECT 
    'Tab C API Function Test' as test_name,
    COUNT(*) as result_count,
    SUM(total_claim) as total_claims,
    SUM(total_rejected_amt) as total_rejected_amount
FROM claims.get_rejected_claims_tab_c(
    'test_user',
    NULL,  -- facility_id
    NULL,  -- payer_id
    NULL,  -- start_date
    NULL,  -- end_date
    2024,  -- claim_year
    NULL,  -- denial_code
    10,    -- limit
    0,     -- offset
    'payer_name',  -- sort_by
    'ASC'  -- sort_order
);

-- ==========================================================================================================
-- SECTION 6: SAMPLE DATA DISPLAY
-- ==========================================================================================================

-- Test 14: Sample data from Tab A
SELECT 
    'Sample Tab A Data' as data_type,
    claim_number,
    facility_name,
    payer_name,
    clinician_name,
    rejection_type,
    rejected_amt_detail,
    activity_denial_code,
    denial_type,
    ageing_days
FROM claims.v_rejected_claims_tab_a
LIMIT 10;

-- Test 15: Sample data from Tab B
SELECT 
    'Sample Tab B Data' as data_type,
    facility_name,
    total_claim,
    total_rejected_amt,
    total_paid_amt,
    rejection_percentage,
    collection_rate
FROM claims.v_rejected_claims_tab_b
LIMIT 10;

-- Test 16: Sample data from Tab C
SELECT 
    'Sample Tab C Data' as data_type,
    payer_name,
    total_claim,
    total_rejected_amt,
    total_paid_amt,
    rejection_percentage,
    collection_rate
FROM claims.v_rejected_claims_tab_c
LIMIT 10;

-- ==========================================================================================================
-- SECTION 7: PERFORMANCE TESTS
-- ==========================================================================================================

-- Test 17: Performance test for base view
SELECT 
    'Base View Performance Test' as test_name,
    COUNT(*) as record_count,
    'Base view executed successfully' as status
FROM claims.v_rejected_claims_base;

-- Test 18: Performance test for summary view
SELECT 
    'Summary View Performance Test' as test_name,
    COUNT(*) as record_count,
    'Summary view executed successfully' as status
FROM claims.v_rejected_claims_summary;

-- ==========================================================================================================
-- SECTION 8: DATA CONSISTENCY TESTS
-- ==========================================================================================================

-- Test 19: Check amount consistency across tabs
SELECT 
    'Amount Consistency Check' as test_name,
    (SELECT COALESCE(SUM(rejected_amount), 0) FROM claims.v_rejected_claims_base) as base_total_rejected,
    (SELECT COALESCE(SUM(rejected_amt_detail), 0) FROM claims.v_rejected_claims_tab_a WHERE rejected_amt_detail IS NOT NULL) as tab_a_total_rejected,
    (SELECT COALESCE(SUM(total_rejected_amt), 0) FROM claims.v_rejected_claims_tab_b) as tab_b_total_rejected,
    (SELECT COALESCE(SUM(total_rejected_amt), 0) FROM claims.v_rejected_claims_tab_c) as tab_c_total_rejected;

-- Test 20: Check claim count consistency
SELECT 
    'Claim Count Consistency Check' as test_name,
    (SELECT COUNT(DISTINCT claim_key_id) FROM claims.v_rejected_claims_base) as base_unique_claims,
    (SELECT SUM(total_claim) FROM claims.v_rejected_claims_tab_b) as tab_b_total_claims,
    (SELECT SUM(total_claim) FROM claims.v_rejected_claims_tab_c) as tab_c_total_claims;

-- ==========================================================================================================
-- END OF MANUAL TESTING QUERIES
-- ==========================================================================================================

-- Instructions for running these tests:
-- 1. Run the implementation script first: rejected_claims_report_implementation.sql
-- 2. Run these manual test queries one by one
-- 3. Review the results to ensure data quality and business logic
-- 4. Check for any errors or unexpected results
-- 5. Verify that the API functions return expected data
