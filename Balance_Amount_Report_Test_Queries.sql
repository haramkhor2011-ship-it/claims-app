-- ==========================================================================================================
-- BALANCE AMOUNT REPORT - VALIDATION TEST QUERIES
-- ==========================================================================================================
-- 
-- Purpose: Comprehensive test queries to validate the Balance Amount to be Received report
-- Usage: Run these queries to verify data accuracy and report correctness
-- 
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: BASIC HEALTH CHECKS
-- ==========================================================================================================

-- 1.1 Check if all required components exist
SELECT 
    'Views' as component_type,
    COUNT(*) as count,
    STRING_AGG(viewname, ', ') as names
FROM pg_views 
WHERE schemaname = 'claims' 
AND viewname LIKE '%balance_amount%'
UNION ALL
SELECT 
    'Functions' as component_type,
    COUNT(*) as count,
    STRING_AGG(routine_name, ', ') as names
FROM information_schema.routines 
WHERE routine_schema = 'claims' 
AND routine_name LIKE '%balance_amount%'
UNION ALL
SELECT 
    'Tables' as component_type,
    COUNT(*) as count,
    STRING_AGG(table_name, ', ') as names
FROM information_schema.tables 
WHERE table_schema IN ('claims', 'claims_ref')
AND table_name IN (
    'claim_key', 'claim', 'encounter', 'remittance_claim', 
    'remittance_activity', 'claim_event', 'claim_resubmission',
    'claim_status_timeline', 'provider', 'facility', 'payer'
);

-- 1.2 Check view definitions
SELECT 
    viewname,
    definition
FROM pg_views 
WHERE schemaname = 'claims' 
AND viewname = 'v_balance_amount_base_enhanced';

-- ==========================================================================================================
-- SECTION 2: DATA QUALITY VALIDATION
-- ==========================================================================================================

-- 2.1 Check for NULL values in critical fields
WITH null_check AS (
    SELECT 
        'claim_id' as field_name,
        COUNT(*) as total_records,
        COUNT(claim_id) as non_null_records,
        COUNT(*) - COUNT(claim_id) as null_records,
        ROUND((COUNT(*) - COUNT(claim_id))::numeric / COUNT(*) * 100, 2) as null_percentage
    FROM claims.v_balance_amount_tab_a_corrected
    UNION ALL
    SELECT 
        'billed_amount' as field_name,
        COUNT(*) as total_records,
        COUNT(billed_amount) as non_null_records,
        COUNT(*) - COUNT(billed_amount) as null_records,
        ROUND((COUNT(*) - COUNT(billed_amount))::numeric / COUNT(*) * 100, 2) as null_percentage
    FROM claims.v_balance_amount_tab_a_corrected
    UNION ALL
    SELECT 
        'facility_group_id' as field_name,
        COUNT(*) as total_records,
        COUNT(facility_group_id) as non_null_records,
        COUNT(*) - COUNT(facility_group_id) as null_records,
        ROUND((COUNT(*) - COUNT(facility_group_id))::numeric / COUNT(*) * 100, 2) as null_percentage
    FROM claims.v_balance_amount_tab_a_corrected
    UNION ALL
    SELECT 
        'outstanding_balance' as field_name,
        COUNT(*) as total_records,
        COUNT(outstanding_balance) as non_null_records,
        COUNT(*) - COUNT(outstanding_balance) as null_records,
        ROUND((COUNT(*) - COUNT(outstanding_balance))::numeric / COUNT(*) * 100, 2) as null_percentage
    FROM claims.v_balance_amount_tab_a_corrected
)
SELECT * FROM null_check
WHERE null_records > 0
ORDER BY null_percentage DESC;

-- 2.2 Check for negative amounts (should be investigated)
SELECT 
    'Negative Billed Amount' as issue_type,
    COUNT(*) as count
FROM claims.v_balance_amount_tab_a_corrected 
WHERE billed_amount < 0
UNION ALL
SELECT 
    'Negative Outstanding Balance' as issue_type,
    COUNT(*) as count
FROM claims.v_balance_amount_tab_a_corrected 
WHERE outstanding_balance < 0
UNION ALL
SELECT 
    'Negative Amount Received' as issue_type,
    COUNT(*) as count
FROM claims.v_balance_amount_tab_a_corrected 
WHERE amount_received < 0;

-- 2.3 Check for unrealistic amounts (over 1 million)
SELECT 
    'High Billed Amount (>1M)' as issue_type,
    COUNT(*) as count,
    MAX(billed_amount) as max_amount
FROM claims.v_balance_amount_tab_a_corrected 
WHERE billed_amount > 1000000
UNION ALL
SELECT 
    'High Outstanding Balance (>1M)' as issue_type,
    COUNT(*) as count,
    MAX(outstanding_balance) as max_amount
FROM claims.v_balance_amount_tab_a_corrected 
WHERE outstanding_balance > 1000000;

-- ==========================================================================================================
-- SECTION 3: BUSINESS LOGIC VALIDATION
-- ==========================================================================================================

-- 3.1 Outstanding Balance Calculation Validation
WITH balance_validation AS (
    SELECT 
        claim_id,
        billed_amount,
        amount_received,
        denied_amount,
        outstanding_balance,
        (billed_amount - amount_received - denied_amount) AS calculated_outstanding,
        CASE 
            WHEN outstanding_balance = (billed_amount - amount_received - denied_amount) 
            THEN 'CORRECT' 
            ELSE 'ERROR' 
        END AS validation_status,
        ABS(outstanding_balance - (billed_amount - amount_received - denied_amount)) AS difference
    FROM claims.v_balance_amount_tab_a_corrected 
    WHERE outstanding_balance != (billed_amount - amount_received - denied_amount)
)
SELECT 
    validation_status,
    COUNT(*) as count,
    AVG(difference) as avg_difference,
    MAX(difference) as max_difference
FROM balance_validation
GROUP BY validation_status;

-- 3.2 Aging Calculation Validation
WITH aging_validation AS (
    SELECT 
        claim_id,
        encounter_start_date,
        aging_days,
        EXTRACT(DAYS FROM (CURRENT_DATE - encounter_start_date)) AS calculated_aging,
        aging_bucket,
        CASE 
            WHEN aging_days = EXTRACT(DAYS FROM (CURRENT_DATE - encounter_start_date)) 
            THEN 'CORRECT' 
            ELSE 'ERROR' 
        END AS aging_validation_status,
        ABS(aging_days - EXTRACT(DAYS FROM (CURRENT_DATE - encounter_start_date))) AS aging_difference
    FROM claims.v_balance_amount_tab_a_corrected 
    WHERE aging_days != EXTRACT(DAYS FROM (CURRENT_DATE - encounter_start_date))
)
SELECT 
    aging_validation_status,
    COUNT(*) as count,
    AVG(aging_difference) as avg_difference,
    MAX(aging_difference) as max_difference
FROM aging_validation
GROUP BY aging_validation_status;

-- 3.3 Aging Bucket Validation
SELECT 
    aging_bucket,
    COUNT(*) as count,
    MIN(aging_days) as min_days,
    MAX(aging_days) as max_days,
    AVG(aging_days) as avg_days
FROM claims.v_balance_amount_tab_a_corrected 
GROUP BY aging_bucket
ORDER BY 
    CASE aging_bucket
        WHEN '0-30' THEN 1
        WHEN '31-60' THEN 2
        WHEN '61-90' THEN 3
        WHEN '90+' THEN 4
    END;

-- ==========================================================================================================
-- SECTION 4: TAB LOGIC VALIDATION
-- ==========================================================================================================

-- 4.1 Tab A - All Balance Amounts Summary
SELECT 
    'Tab A - All Balance Amounts' as tab_name,
    COUNT(*) as total_claims,
    COUNT(CASE WHEN outstanding_balance > 0 THEN 1 END) as claims_with_outstanding,
    COUNT(CASE WHEN outstanding_balance = 0 THEN 1 END) as claims_without_outstanding,
    COUNT(CASE WHEN outstanding_balance < 0 THEN 1 END) as claims_with_negative_balance,
    SUM(billed_amount) as total_billed,
    SUM(outstanding_balance) as total_outstanding
FROM claims.v_balance_amount_tab_a_corrected;

-- 4.2 Tab B - Initial Not Remitted Validation
SELECT 
    'Tab B - Initial Not Remitted' as tab_name,
    COUNT(*) as total_claims,
    COUNT(CASE WHEN remittance_count = 0 THEN 1 END) as no_remittances,
    COUNT(CASE WHEN resubmission_count = 0 THEN 1 END) as no_resubmissions,
    COUNT(CASE WHEN denied_amount = 0 THEN 1 END) as no_denials,
    COUNT(CASE WHEN outstanding_balance > 0 THEN 1 END) as has_outstanding
FROM claims.v_balance_amount_tab_b_corrected;

-- 4.3 Tab C - After Resubmission Not Remitted Validation
SELECT 
    'Tab C - After Resubmission Not Remitted' as tab_name,
    COUNT(*) as total_claims,
    COUNT(CASE WHEN resubmission_count > 0 THEN 1 END) as has_resubmissions,
    COUNT(CASE WHEN outstanding_balance > 0 THEN 1 END) as has_outstanding,
    COUNT(CASE WHEN remittance_count > 0 THEN 1 END) as has_remittances
FROM claims.v_balance_amount_tab_c_corrected;

-- 4.4 Cross-Tab Overlap Check (should be minimal or zero)
SELECT 
    'Tab A vs Tab B Overlap' as comparison,
    COUNT(*) as overlap_count
FROM claims.v_balance_amount_tab_a_corrected a
JOIN claims.v_balance_amount_tab_b_corrected b ON a.claim_key_id = b.claim_key_id
UNION ALL
SELECT 
    'Tab A vs Tab C Overlap' as comparison,
    COUNT(*) as overlap_count
FROM claims.v_balance_amount_tab_a_corrected a
JOIN claims.v_balance_amount_tab_c_corrected c ON a.claim_key_id = c.claim_key_id
UNION ALL
SELECT 
    'Tab B vs Tab C Overlap' as comparison,
    COUNT(*) as overlap_count
FROM claims.v_balance_amount_tab_b_corrected b
JOIN claims.v_balance_amount_tab_c_corrected c ON b.claim_key_id = c.claim_key_id;

-- ==========================================================================================================
-- SECTION 5: STATUS AND REFERENCE DATA VALIDATION
-- ==========================================================================================================

-- 5.1 Status Distribution
SELECT 
    current_claim_status,
    COUNT(*) as count,
    ROUND(COUNT(*)::numeric / (SELECT COUNT(*) FROM claims.v_balance_amount_tab_a_corrected) * 100, 2) as percentage
FROM claims.v_balance_amount_tab_a_corrected 
GROUP BY current_claim_status
ORDER BY count DESC;

-- 5.2 Facility Distribution
SELECT 
    facility_id,
    facility_name,
    COUNT(*) as claim_count,
    SUM(billed_amount) as total_billed,
    SUM(outstanding_balance) as total_outstanding
FROM claims.v_balance_amount_tab_a_corrected 
GROUP BY facility_id, facility_name
ORDER BY claim_count DESC
LIMIT 10;

-- 5.3 Payer Distribution
SELECT 
    id_payer,
    COUNT(*) as claim_count,
    SUM(billed_amount) as total_billed,
    SUM(outstanding_balance) as total_outstanding,
    AVG(outstanding_balance) as avg_outstanding
FROM claims.v_balance_amount_tab_a_corrected 
GROUP BY id_payer
ORDER BY total_outstanding DESC
LIMIT 10;

-- ==========================================================================================================
-- SECTION 6: PERFORMANCE VALIDATION
-- ==========================================================================================================

-- 6.1 Query Performance Test (run with \timing on)
-- Enable timing: \timing on

-- Test base view performance
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) 
SELECT COUNT(*) 
FROM claims.v_balance_amount_base_enhanced 
WHERE encounter_start >= '2024-01-01';

-- Test tab view performance
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) 
SELECT COUNT(*) 
FROM claims.v_balance_amount_tab_a_corrected 
WHERE encounter_start_date >= '2024-01-01';

-- 6.2 Index Usage Check
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    ROUND(idx_tup_read::numeric / NULLIF(idx_scan, 0), 2) as avg_tuples_per_scan
FROM pg_stat_user_indexes 
WHERE schemaname = 'claims' 
AND indexname LIKE '%balance_amount%'
ORDER BY idx_scan DESC;

-- ==========================================================================================================
-- SECTION 7: API FUNCTION VALIDATION
-- ==========================================================================================================

-- 7.1 Basic API Function Test
SELECT 
    'API Function Test' as test_name,
    COUNT(*) as result_count,
    MIN(encounter_start_date) as earliest_date,
    MAX(encounter_start_date) as latest_date,
    SUM(billed_amount) as total_billed,
    SUM(outstanding_balance) as total_outstanding
FROM claims.get_balance_amount_tab_a_corrected(
    'test_user',                    -- p_user_id
    NULL,                           -- p_claim_key_ids
    NULL,                           -- p_facility_codes
    NULL,                           -- p_payer_codes
    NULL,                           -- p_receiver_ids
    '2024-01-01'::timestamptz,     -- p_date_from
    '2024-12-31'::timestamptz,     -- p_date_to
    NULL,                           -- p_year
    NULL,                           -- p_month
    FALSE,                          -- p_based_on_initial_net
    100,                            -- p_limit
    0,                              -- p_offset
    'encounter_start_date',         -- p_order_by
    'DESC'                          -- p_order_direction
);

-- 7.2 API Function with Filters Test
SELECT 
    'API Function with Filters' as test_name,
    COUNT(*) as result_count,
    COUNT(DISTINCT facility_id) as unique_facilities,
    COUNT(DISTINCT id_payer) as unique_payers
FROM claims.get_balance_amount_tab_a_corrected(
    'test_user',                    -- p_user_id
    NULL,                           -- p_claim_key_ids
    ARRAY['DHA-F-0045446'],        -- p_facility_codes
    NULL,                           -- p_payer_codes
    NULL,                           -- p_receiver_ids
    '2024-01-01'::timestamptz,     -- p_date_from
    '2024-12-31'::timestamptz,     -- p_date_to
    2024,                           -- p_year
    NULL,                           -- p_month
    FALSE,                          -- p_based_on_initial_net
    50,                             -- p_limit
    0,                              -- p_offset
    'aging_days',                   -- p_order_by
    'DESC'                          -- p_order_direction
);

-- ==========================================================================================================
-- SECTION 8: DATA CONSISTENCY CHECKS
-- ==========================================================================================================

-- 8.1 Check for orphaned records
SELECT 
    'Claims without encounters' as issue_type,
    COUNT(*) as count
FROM claims.claim c
LEFT JOIN claims.encounter e ON e.claim_id = c.id
WHERE e.id IS NULL
UNION ALL
SELECT 
    'Claims without claim_key' as issue_type,
    COUNT(*) as count
FROM claims.claim c
LEFT JOIN claims.claim_key ck ON ck.id = c.claim_key_id
WHERE ck.id IS NULL
UNION ALL
SELECT 
    'Encounters without claims' as issue_type,
    COUNT(*) as count
FROM claims.encounter e
LEFT JOIN claims.claim c ON c.id = e.claim_id
WHERE c.id IS NULL;

-- 8.2 Check for data integrity issues
SELECT 
    'Claims with negative net amount' as issue_type,
    COUNT(*) as count
FROM claims.claim 
WHERE net < 0
UNION ALL
SELECT 
    'Claims with zero net amount' as issue_type,
    COUNT(*) as count
FROM claims.claim 
WHERE net = 0
UNION ALL
SELECT 
    'Claims with future encounter dates' as issue_type,
    COUNT(*) as count
FROM claims.encounter 
WHERE start > CURRENT_DATE + INTERVAL '1 day';

-- ==========================================================================================================
-- SECTION 9: SAMPLE DATA VERIFICATION
-- ==========================================================================================================

-- 9.1 Get sample records for manual verification
SELECT 
    claim_id,
    facility_name,
    facility_group_id,
    health_authority,
    billed_amount,
    amount_received,
    denied_amount,
    outstanding_balance,
    aging_days,
    aging_bucket,
    current_claim_status,
    encounter_start_date,
    submission_date
FROM claims.v_balance_amount_tab_a_corrected 
WHERE encounter_start_date >= '2024-01-01'
ORDER BY outstanding_balance DESC
LIMIT 10;

-- 9.2 Get sample records with high outstanding balance
SELECT 
    claim_id,
    facility_name,
    billed_amount,
    outstanding_balance,
    aging_days,
    current_claim_status,
    remittance_count,
    resubmission_count
FROM claims.v_balance_amount_tab_a_corrected 
WHERE outstanding_balance > 10000
ORDER BY outstanding_balance DESC
LIMIT 5;

-- ==========================================================================================================
-- SECTION 10: SUMMARY REPORT
-- ==========================================================================================================

-- 10.1 Overall Report Health Summary
SELECT 
    'Total Claims' as metric,
    COUNT(*)::text as value
FROM claims.v_balance_amount_tab_a_corrected
UNION ALL
SELECT 
    'Claims with Outstanding Balance' as metric,
    COUNT(*)::text as value
FROM claims.v_balance_amount_tab_a_corrected
WHERE outstanding_balance > 0
UNION ALL
SELECT 
    'Total Outstanding Amount' as metric,
    TO_CHAR(SUM(outstanding_balance), 'FM999,999,999.00') as value
FROM claims.v_balance_amount_tab_a_corrected
UNION ALL
SELECT 
    'Average Outstanding Amount' as metric,
    TO_CHAR(AVG(outstanding_balance), 'FM999,999.00') as value
FROM claims.v_balance_amount_tab_a_corrected
WHERE outstanding_balance > 0
UNION ALL
SELECT 
    'Claims with Aging > 90 days' as metric,
    COUNT(*)::text as value
FROM claims.v_balance_amount_tab_a_corrected
WHERE aging_days > 90
UNION ALL
SELECT 
    'Unique Facilities' as metric,
    COUNT(DISTINCT facility_id)::text as value
FROM claims.v_balance_amount_tab_a_corrected
UNION ALL
SELECT 
    'Unique Payers' as metric,
    COUNT(DISTINCT id_payer)::text as value
FROM claims.v_balance_amount_tab_a_corrected;

-- ==========================================================================================================
-- END OF VALIDATION TEST QUERIES
-- ==========================================================================================================

-- Instructions for running these tests:
-- 1. Run each section individually to validate specific aspects
-- 2. Pay attention to any ERROR results in business logic validation
-- 3. Check for NULL values in critical fields
-- 4. Verify that tab logic is correct (minimal overlaps)
-- 5. Monitor performance metrics
-- 6. Review sample data for reasonableness
-- 7. Use the summary report for overall health assessment
