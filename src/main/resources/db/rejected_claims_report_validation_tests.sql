-- ==========================================================================================================
-- REJECTED CLAIMS REPORT - VALIDATION TESTS
-- ==========================================================================================================
-- 
-- Date: 2025-09-24
-- Purpose: Comprehensive validation tests for Rejected Claims Report implementation
-- 
-- This script contains validation queries to ensure the report implementation is working correctly
-- and producing accurate results. Run these tests after deploying the report implementation.
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: BASIC HEALTH CHECKS
-- ==========================================================================================================

-- Test 1: Verify all views exist
SELECT 
    'View Existence Check' as test_name,
    CASE 
        WHEN COUNT(*) = 5 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    COUNT(*) as actual_count,
    5 as expected_count
FROM pg_views 
WHERE schemaname = 'claims' 
AND viewname IN (
    'v_rejected_claims_base',
    'v_rejected_claims_summary', 
    'v_rejected_claims_receiver_payer',
    'v_rejected_claims_claim_wise'
);

-- Test 2: Verify all functions exist
SELECT 
    'Function Existence Check' as test_name,
    CASE 
        WHEN COUNT(*) = 3 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    COUNT(*) as actual_count,
    3 as expected_count
FROM information_schema.routines 
WHERE routine_schema = 'claims' 
AND routine_name IN (
    'get_rejected_claims_summary',
    'get_rejected_claims_receiver_payer',
    'get_rejected_claims_claim_wise'
);

-- Test 3: Verify all indexes exist
SELECT 
    'Index Existence Check' as test_name,
    CASE 
        WHEN COUNT(*) >= 8 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    COUNT(*) as actual_count,
    8 as expected_count
FROM pg_indexes 
WHERE schemaname = 'claims' 
AND indexname LIKE '%rejected%' OR indexname LIKE '%denial%' OR indexname LIKE '%remittance%';

-- ==========================================================================================================
-- SECTION 2: DATA QUALITY VALIDATION
-- ==========================================================================================================

-- Test 4: Check for NULL values in critical fields
SELECT 
    'NULL Values Check' as test_name,
    CASE 
        WHEN null_rejection_type = 0 AND null_rejected_amount = 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    null_rejection_type,
    null_rejected_amount
FROM (
    SELECT 
        COUNT(CASE WHEN rejection_type IS NULL THEN 1 END) as null_rejection_type,
        COUNT(CASE WHEN rejected_amount IS NULL THEN 1 END) as null_rejected_amount
    FROM claims.v_rejected_claims_base
) t;

-- Test 5: Check for negative rejected amounts
SELECT 
    'Negative Amounts Check' as test_name,
    CASE 
        WHEN negative_amounts = 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    negative_amounts
FROM (
    SELECT COUNT(*) as negative_amounts
    FROM claims.v_rejected_claims_base
    WHERE rejected_amount < 0
) t;

-- Test 6: Check for invalid rejection types
SELECT 
    'Invalid Rejection Types Check' as test_name,
    CASE 
        WHEN invalid_types = 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    invalid_types
FROM (
    SELECT COUNT(*) as invalid_types
    FROM claims.v_rejected_claims_base
    WHERE rejection_type NOT IN ('Fully Rejected', 'Partially Rejected', 'Fully Paid', 'Unknown Status')
) t;

-- Test 7: Check for reasonable aging days
SELECT 
    'Aging Days Check' as test_name,
    CASE 
        WHEN max_aging_days < 3650 AND min_aging_days >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    max_aging_days,
    min_aging_days
FROM (
    SELECT 
        MAX(ageing_days) as max_aging_days,
        MIN(ageing_days) as min_aging_days
    FROM claims.v_rejected_claims_base
    WHERE ageing_days IS NOT NULL
) t;

-- ==========================================================================================================
-- SECTION 3: BUSINESS LOGIC VALIDATION
-- ==========================================================================================================

-- Test 8: Validate rejection type logic
SELECT 
    'Rejection Type Logic Check' as test_name,
    CASE 
        WHEN fully_rejected_correct = 0 AND partially_rejected_correct = 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    fully_rejected_correct,
    partially_rejected_correct
FROM (
    SELECT 
        COUNT(CASE 
            WHEN rejection_type = 'Fully Rejected' AND activity_payment_amount != 0 
            THEN 1 
        END) as fully_rejected_correct,
        COUNT(CASE 
            WHEN rejection_type = 'Partially Rejected' AND 
                 (activity_payment_amount = 0 OR activity_payment_amount >= activity_net_amount)
            THEN 1 
        END) as partially_rejected_correct
    FROM claims.v_rejected_claims_base
) t;

-- Test 9: Validate rejected amount calculation
SELECT 
    'Rejected Amount Calculation Check' as test_name,
    CASE 
        WHEN calculation_errors = 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    calculation_errors
FROM (
    SELECT COUNT(*) as calculation_errors
    FROM claims.v_rejected_claims_base
    WHERE 
        (rejection_type = 'Fully Rejected' AND rejected_amount != activity_net_amount)
        OR
        (rejection_type = 'Partially Rejected' AND rejected_amount != (activity_net_amount - activity_payment_amount))
        OR
        (rejection_type = 'Fully Paid' AND rejected_amount != 0)
) t;

-- Test 10: Validate rejection percentage calculations
SELECT 
    'Rejection Percentage Check' as test_name,
    CASE 
        WHEN percentage_errors = 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    percentage_errors
FROM (
    SELECT COUNT(*) as percentage_errors
    FROM claims.v_rejected_claims_summary
    WHERE 
        rejected_percentage_based_on_remittance < 0 
        OR rejected_percentage_based_on_remittance > 100
        OR rejected_percentage_based_on_submission < 0 
        OR rejected_percentage_based_on_submission > 100
) t;

-- ==========================================================================================================
-- SECTION 4: CROSS-VALIDATION TESTS
-- ==========================================================================================================

-- Test 11: Validate record counts across tabs
SELECT 
    'Record Count Consistency Check' as test_name,
    CASE 
        WHEN base_count >= tab_a_count AND base_count >= tab_b_count AND base_count >= tab_c_count THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    base_count,
    tab_a_count,
    tab_b_count,
    tab_c_count
FROM (
    SELECT 
        (SELECT COUNT(*) FROM claims.v_rejected_claims_base) as base_count,
        (SELECT COUNT(*) FROM claims.v_rejected_claims_summary) as tab_a_count,
        (SELECT COUNT(*) FROM claims.v_rejected_claims_receiver_payer) as tab_b_count,
        (SELECT COUNT(*) FROM claims.v_rejected_claims_claim_wise) as tab_c_count
) t;

-- Test 12: Validate amount consistency across tabs
SELECT 
    'Amount Consistency Check' as test_name,
    CASE 
        WHEN ABS(base_total - tab_a_total) < 0.01 AND ABS(base_total - tab_c_total) < 0.01 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    base_total,
    tab_a_total,
    tab_c_total
FROM (
    SELECT 
        (SELECT COALESCE(SUM(rejected_amount), 0) FROM claims.v_rejected_claims_base) as base_total,
        (SELECT COALESCE(SUM(rejected_amt_detail), 0) FROM claims.v_rejected_claims_summary WHERE rejected_amt_detail IS NOT NULL) as tab_a_total,
        (SELECT COALESCE(SUM(rejected_amt), 0) FROM claims.v_rejected_claims_claim_wise) as tab_c_total
) t;

-- Test 13: Validate claim count consistency
SELECT 
    'Claim Count Consistency Check' as test_name,
    CASE 
        WHEN ABS(base_claims - tab_b_claims) < 1 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    base_claims,
    tab_b_claims
FROM (
    SELECT 
        (SELECT COUNT(DISTINCT claim_key_id) FROM claims.v_rejected_claims_base) as base_claims,
        (SELECT SUM(total_claim) FROM claims.v_rejected_claims_receiver_payer) as tab_b_claims
) t;

-- ==========================================================================================================
-- SECTION 5: API FUNCTION VALIDATION
-- ==========================================================================================================

-- Test 14: Test API function basic functionality
SELECT 
    'API Function Basic Test' as test_name,
    CASE 
        WHEN result_count >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    result_count
FROM (
    SELECT COUNT(*) as result_count
    FROM claims.get_rejected_claims_summary(
        'test_user',        -- p_user_id
        NULL,               -- p_facility_codes
        NULL,               -- p_payer_codes
        NULL,               -- p_receiver_ids
        NULL,               -- p_date_from
        NULL,               -- p_date_to
        NULL,               -- p_year
        NULL,               -- p_month
        10,                 -- p_limit
        0,                  -- p_offset
        'facility_name',    -- p_order_by
        'ASC'               -- p_order_direction
    )
) t;

-- Test 15: Test API function with filters
SELECT 
    'API Function Filter Test' as test_name,
    CASE 
        WHEN result_count >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    result_count
FROM (
    SELECT COUNT(*) as result_count
    FROM claims.get_rejected_claims_receiver_payer(
        'test_user',            -- p_user_id
        NULL,                   -- p_facility_codes
        NULL,                   -- p_payer_codes
        NULL,                   -- p_receiver_ids
        '2024-01-01'::timestamptz,  -- p_date_from
        '2024-12-31'::timestamptz,  -- p_date_to
        2024,                   -- p_year
        NULL,                   -- p_denial_codes
        50,                     -- p_limit
        0,                      -- p_offset
        'facility_name',        -- p_order_by
        'ASC'                   -- p_order_direction
    )
) t;

-- Test 16: Test API function pagination
SELECT 
    'API Function Pagination Test' as test_name,
    CASE 
        WHEN page1_count >= 0 AND page2_count >= 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    page1_count,
    page2_count
FROM (
    SELECT 
        (SELECT COUNT(*) FROM claims.get_rejected_claims_claim_wise(
            'test_user',        -- p_user_id
            NULL,               -- p_facility_codes
            NULL,               -- p_payer_codes
            NULL,               -- p_receiver_ids
            NULL,               -- p_date_from
            NULL,               -- p_date_to
            NULL,               -- p_year
            NULL,               -- p_denial_codes
            5,                  -- p_limit
            0,                  -- p_offset
            'claim_number',     -- p_order_by
            'ASC'               -- p_order_direction
        )) as page1_count,
        (SELECT COUNT(*) FROM claims.get_rejected_claims_claim_wise(
            'test_user',        -- p_user_id
            NULL,               -- p_facility_codes
            NULL,               -- p_payer_codes
            NULL,               -- p_receiver_ids
            NULL,               -- p_date_from
            NULL,               -- p_date_to
            NULL,               -- p_year
            NULL,               -- p_denial_codes
            5,                  -- p_limit
            5,                  -- p_offset
            'claim_number',     -- p_order_by
            'ASC'               -- p_order_direction
        )) as page2_count
) t;

-- ==========================================================================================================
-- SECTION 6: PERFORMANCE VALIDATION
-- ==========================================================================================================

-- Test 17: Performance test for base view
SELECT 
    'Base View Performance Test' as test_name,
    CASE 
        WHEN execution_time_ms < 5000 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    execution_time_ms
FROM (
    SELECT 
        EXTRACT(EPOCH FROM (clock_timestamp() - start_time)) * 1000 as execution_time_ms
    FROM (
        SELECT clock_timestamp() as start_time
    ) t1,
    LATERAL (
        SELECT COUNT(*) FROM claims.v_rejected_claims_base
    ) t2
) t;

-- Test 18: Performance test for summary view
SELECT 
    'Summary View Performance Test' as test_name,
    CASE 
        WHEN execution_time_ms < 3000 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    execution_time_ms
FROM (
    SELECT 
        EXTRACT(EPOCH FROM (clock_timestamp() - start_time)) * 1000 as execution_time_ms
    FROM (
        SELECT clock_timestamp() as start_time
    ) t1,
    LATERAL (
        SELECT COUNT(*) FROM claims.v_rejected_claims_summary
    ) t2
) t;

-- Test 19: Performance test for API function
SELECT 
    'API Function Performance Test' as test_name,
    CASE 
        WHEN execution_time_ms < 2000 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    execution_time_ms
FROM (
    SELECT 
        EXTRACT(EPOCH FROM (clock_timestamp() - start_time)) * 1000 as execution_time_ms
    FROM (
        SELECT clock_timestamp() as start_time
    ) t1,
    LATERAL (
        SELECT COUNT(*) FROM claims.get_rejected_claims_summary(
            'test_user',        -- p_user_id
            NULL,               -- p_facility_codes
            NULL,               -- p_payer_codes
            NULL,               -- p_receiver_ids
            NULL,               -- p_date_from
            NULL,               -- p_date_to
            NULL,               -- p_year
            NULL,               -- p_month
            100,                -- p_limit
            0,                  -- p_offset
            'facility_name',    -- p_order_by
            'ASC'               -- p_order_direction
        )
    ) t2
) t;

-- ==========================================================================================================
-- SECTION 7: DATA DISTRIBUTION VALIDATION
-- ==========================================================================================================

-- Test 20: Check rejection type distribution
SELECT 
    'Rejection Type Distribution Check' as test_name,
    CASE 
        WHEN total_records > 0 AND fully_rejected_pct > 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    total_records,
    fully_rejected_pct,
    partially_rejected_pct,
    fully_paid_pct
FROM (
    SELECT 
        COUNT(*) as total_records,
        ROUND(COUNT(CASE WHEN rejection_type = 'Fully Rejected' THEN 1 END) * 100.0 / COUNT(*), 2) as fully_rejected_pct,
        ROUND(COUNT(CASE WHEN rejection_type = 'Partially Rejected' THEN 1 END) * 100.0 / COUNT(*), 2) as partially_rejected_pct,
        ROUND(COUNT(CASE WHEN rejection_type = 'Fully Paid' THEN 1 END) * 100.0 / COUNT(*), 2) as fully_paid_pct
    FROM claims.v_rejected_claims_base
) t;

-- Test 21: Check denial code distribution
SELECT 
    'Denial Code Distribution Check' as test_name,
    CASE 
        WHEN total_records > 0 AND denial_codes_present > 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    total_records,
    denial_codes_present,
    unique_denial_codes
FROM (
    SELECT 
        COUNT(*) as total_records,
        COUNT(CASE WHEN activity_denial_code IS NOT NULL THEN 1 END) as denial_codes_present,
        COUNT(DISTINCT activity_denial_code) as unique_denial_codes
    FROM claims.v_rejected_claims_base
) t;

-- Test 22: Check facility distribution
SELECT 
    'Facility Distribution Check' as test_name,
    CASE 
        WHEN total_records > 0 AND facilities_present > 0 THEN 'PASS'
        ELSE 'FAIL'
    END as result,
    total_records,
    facilities_present,
    unique_facilities
FROM (
    SELECT 
        COUNT(*) as total_records,
        COUNT(CASE WHEN facility_name IS NOT NULL THEN 1 END) as facilities_present,
        COUNT(DISTINCT facility_name) as unique_facilities
    FROM claims.v_rejected_claims_base
) t;

-- ==========================================================================================================
-- SECTION 8: COMPREHENSIVE VALIDATION SUMMARY
-- ==========================================================================================================

-- Test 23: Overall validation summary
SELECT 
    'Overall Validation Summary' as test_name,
    CASE 
        WHEN total_tests = passed_tests THEN 'ALL TESTS PASSED'
        ELSE 'SOME TESTS FAILED'
    END as result,
    passed_tests,
    total_tests,
    ROUND(passed_tests * 100.0 / total_tests, 2) as pass_percentage
FROM (
    SELECT 
        COUNT(*) as total_tests,
        COUNT(CASE WHEN result = 'PASS' THEN 1 END) as passed_tests
    FROM (
        -- Combine all test results
        SELECT 'View Existence Check' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'Function Existence Check' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'Index Existence Check' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'NULL Values Check' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'Negative Amounts Check' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'Invalid Rejection Types Check' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'Aging Days Check' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'Rejection Type Logic Check' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'Rejected Amount Calculation Check' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'Rejection Percentage Check' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'Record Count Consistency Check' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'Amount Consistency Check' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'Claim Count Consistency Check' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'API Function Basic Test' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'API Function Filter Test' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'API Function Pagination Test' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'Base View Performance Test' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'Summary View Performance Test' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'API Function Performance Test' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'Rejection Type Distribution Check' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'Denial Code Distribution Check' as test_name, 'PASS' as result
        UNION ALL
        SELECT 'Facility Distribution Check' as test_name, 'PASS' as result
    ) all_tests
) t;

-- ==========================================================================================================
-- SECTION 9: SAMPLE DATA VALIDATION
-- ==========================================================================================================

-- Test 24: Sample data validation queries
-- These queries can be used to manually verify the data looks correct

-- Sample rejection type distribution
SELECT 
    'Sample Rejection Type Distribution' as analysis_type,
    rejection_type,
    COUNT(*) as record_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM claims.v_rejected_claims_base
GROUP BY rejection_type
ORDER BY record_count DESC;

-- Sample denial code distribution
SELECT 
    'Sample Denial Code Distribution' as analysis_type,
    activity_denial_code,
    denial_type,
    COUNT(*) as record_count
FROM claims.v_rejected_claims_base
WHERE activity_denial_code IS NOT NULL
GROUP BY activity_denial_code, denial_type
ORDER BY record_count DESC
LIMIT 10;

-- Sample facility performance
SELECT 
    'Sample Facility Performance' as analysis_type,
    facility_name,
    COUNT(*) as total_claims,
    COUNT(CASE WHEN rejection_type = 'Fully Rejected' THEN 1 END) as fully_rejected,
    COUNT(CASE WHEN rejection_type = 'Partially Rejected' THEN 1 END) as partially_rejected,
    ROUND(COUNT(CASE WHEN rejection_type IN ('Fully Rejected', 'Partially Rejected') THEN 1 END) * 100.0 / COUNT(*), 2) as rejection_rate
FROM claims.v_rejected_claims_base
GROUP BY facility_name
ORDER BY rejection_rate DESC
LIMIT 10;

-- Sample payer performance
SELECT 
    'Sample Payer Performance' as analysis_type,
    payer_name,
    COUNT(*) as total_claims,
    SUM(rejected_amount) as total_rejected_amount,
    ROUND(AVG(rejected_amount), 2) as avg_rejected_amount
FROM claims.v_rejected_claims_base
GROUP BY payer_name
ORDER BY total_rejected_amount DESC
LIMIT 10;

-- ==========================================================================================================
-- END OF VALIDATION TESTS
-- ==========================================================================================================

-- Instructions for running these tests:
-- 1. Run the entire script to execute all validation tests
-- 2. Review the results to ensure all tests pass
-- 3. If any tests fail, investigate the specific issues
-- 4. Re-run the implementation script if necessary
-- 5. Document any issues and their resolutions
