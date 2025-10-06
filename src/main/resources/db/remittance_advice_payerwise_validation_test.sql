-- =====================================================
-- REMITTANCE ADVICE PAYERWISE REPORT - VALIDATION & TESTING
-- =====================================================
-- This script creates dummy data and validates the report views
-- Run this after deploying the report views to test functionality

-- =====================================================
-- 1. SETUP TEST DATA
-- =====================================================

-- Create test facilities
INSERT INTO claims_ref.facility (facility_code, name, city, country, status) VALUES
    ('TEST_FAC_001', 'Test Hospital Main', 'Dubai', 'UAE', 'ACTIVE'),
    ('TEST_FAC_002', 'Test Clinic Branch', 'Abu Dhabi', 'UAE', 'ACTIVE')
ON CONFLICT (facility_code) DO UPDATE SET name = EXCLUDED.name;

-- Create test payers
INSERT INTO claims_ref.payer (payer_code, name, status) VALUES
    ('TEST_PAYER_001', 'Test Insurance Company A', 'ACTIVE'),
    ('TEST_PAYER_002', 'Test Insurance Company B', 'ACTIVE'),
    ('TEST_PAYER_003', 'Self Pay', 'ACTIVE')
ON CONFLICT (payer_code) DO UPDATE SET name = EXCLUDED.name;

-- Create test providers/clinicians
INSERT INTO claims_ref.provider (provider_code, name, status) VALUES
    ('TEST_PROV_001', 'Dr. John Smith', 'ACTIVE'),
    ('TEST_PROV_002', 'Dr. Sarah Johnson', 'ACTIVE'),
    ('TEST_PROV_003', 'Test Hospital Provider', 'ACTIVE')
ON CONFLICT (provider_code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO claims_ref.clinician (clinician_code, name, specialty, status) VALUES
    ('TEST_CLIN_001', 'Dr. John Smith', 'General Medicine', 'ACTIVE'),
    ('TEST_CLIN_002', 'Dr. Sarah Johnson', 'Cardiology', 'ACTIVE')
ON CONFLICT (clinician_code) DO UPDATE SET name = EXCLUDED.name;

-- Create test activity codes
INSERT INTO claims_ref.activity_code (code, code_system, description, status) VALUES
    ('99213', 'CPT', 'Office Visit Level 3', 'ACTIVE'),
    ('85025', 'CPT', 'CBC with Differential', 'ACTIVE'),
    ('71020', 'CPT', 'Chest X-Ray', 'ACTIVE')
ON CONFLICT (code, code_system) DO UPDATE SET description = EXCLUDED.description;

-- Create test denial codes
INSERT INTO claims_ref.denial_code (code, description, payer_code) VALUES
    ('DEN001', 'Not Clinically Indicated', 'TEST_PAYER_001'),
    ('DEN002', 'Pre-authorization Required', 'TEST_PAYER_002'),
    ('DEN003', 'Invalid CPT Code', NULL)
ON CONFLICT (code) DO UPDATE SET description = EXCLUDED.description;

-- =====================================================
-- 2. CREATE TEST INGESTION FILES
-- =====================================================

-- Create test ingestion files (1 submission, 1 remittance)
INSERT INTO claims.ingestion_file (
    file_id, file_name, root_type, sender_id, receiver_id,
    transaction_date, record_count_declared, disposition_flag, xml_bytes
) VALUES
    (
        'TEST_SUB_001', 'test_submission_001.xml', 1, 'TEST_FAC_001', 'TEST_PAYER_001',
        NOW() - INTERVAL '5 days', 2, 'ACCEPTED',
        '<test>submission xml content</test>'::bytea
    ),
    (
        'TEST_REMIT_001', 'test_remittance_001.xml', 2, 'TEST_PAYER_001', 'TEST_FAC_001',
        NOW() - INTERVAL '2 days', 2, 'ACCEPTED',
        '<test>remittance xml content</test>'::bytea
    )
ON CONFLICT (file_id) DO UPDATE SET
    transaction_date = EXCLUDED.transaction_date,
    disposition_flag = EXCLUDED.disposition_flag;

-- =====================================================
-- 3. CREATE TEST CLAIM KEYS
-- =====================================================

INSERT INTO claims.claim_key (claim_id) VALUES
    ('TEST_CLAIM_001'),
    ('TEST_CLAIM_002')
ON CONFLICT (claim_id) DO NOTHING;

-- =====================================================
-- 4. CREATE TEST SUBMISSIONS
-- =====================================================

INSERT INTO claims.submission (ingestion_file_id, tx_at) VALUES
    ((SELECT id FROM claims.ingestion_file WHERE file_id = 'TEST_SUB_001'), NOW() - INTERVAL '5 days'),
    ((SELECT id FROM claims.ingestion_file WHERE file_id = 'TEST_SUB_001'), NOW() - INTERVAL '3 days')
ON CONFLICT DO NOTHING;

-- =====================================================
-- 5. CREATE TEST CLAIMS
-- =====================================================

-- Test Claim 1: Fully Paid
INSERT INTO claims.claim (
    claim_key_id, submission_id, id_payer, member_id, payer_id, provider_id,
    emirates_id_number, gross, patient_share, net, comments,
    payer_ref_id, provider_ref_id, tx_at
) VALUES
    (
        (SELECT id FROM claims.claim_key WHERE claim_id = 'TEST_CLAIM_001'),
        (SELECT id FROM claims.submission LIMIT 1),
        'ID001', 'MEM001', 'TEST_PAYER_001', 'TEST_FAC_001',
        '784-1234-5678901-2', 150.00, 10.00, 140.00, 'Test claim 1',
        (SELECT id FROM claims_ref.payer WHERE payer_code = 'TEST_PAYER_001'),
        (SELECT id FROM claims_ref.provider WHERE provider_code = 'TEST_PROV_001'),
        NOW() - INTERVAL '5 days'
    ),
    -- Test Claim 2: Partially Paid with Denial
    (
        (SELECT id FROM claims.claim_key WHERE claim_id = 'TEST_CLAIM_002'),
        (SELECT id FROM claims.submission LIMIT 1),
        'ID002', 'MEM002', 'TEST_PAYER_002', 'TEST_FAC_001',
        '784-1234-5678902-3', 300.00, 20.00, 280.00, 'Test claim 2',
        (SELECT id FROM claims_ref.payer WHERE payer_code = 'TEST_PAYER_002'),
        (SELECT id FROM claims_ref.provider WHERE provider_code = 'TEST_PROV_002'),
        NOW() - INTERVAL '3 days'
    )
ON CONFLICT (claim_key_id) DO UPDATE SET
    net = EXCLUDED.net, comments = EXCLUDED.comments;

-- =====================================================
-- 6. CREATE TEST ENCOUNTERS
-- =====================================================

INSERT INTO claims.encounter (
    claim_id, facility_id, type, patient_id, start_at, end_at, start_type, end_type,
    facility_ref_id
) VALUES
    (
        (SELECT id FROM claims.claim WHERE claim_key_id = (SELECT id FROM claims.claim_key WHERE claim_id = 'TEST_CLAIM_001')),
        'TEST_FAC_001', 'OUTPATIENT', 'PAT001', NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days' + INTERVAL '2 hours',
        'ARRIVAL', 'DEPARTURE',
        (SELECT id FROM claims_ref.facility WHERE facility_code = 'TEST_FAC_001')
    ),
    (
        (SELECT id FROM claims.claim WHERE claim_key_id = (SELECT id FROM claims.claim_key WHERE claim_id = 'TEST_CLAIM_002')),
        'TEST_FAC_001', 'OUTPATIENT', 'PAT002', NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days' + INTERVAL '1 hour',
        'ARRIVAL', 'DEPARTURE',
        (SELECT id FROM claims_ref.facility WHERE facility_code = 'TEST_FAC_001')
    );

-- =====================================================
-- 7. CREATE TEST ACTIVITIES
-- =====================================================

-- Activities for Claim 1 (Fully Paid)
INSERT INTO claims.activity (
    claim_id, activity_id, start_at, type, code, quantity, net, clinician,
    prior_authorization_id, clinician_ref_id, activity_code_ref_id
) VALUES
    (
        (SELECT id FROM claims.claim WHERE claim_key_id = (SELECT id FROM claims.claim_key WHERE claim_id = 'TEST_CLAIM_001')),
        'ACT001', NOW() - INTERVAL '5 days', 'PROCEDURE', '99213', 1, 100.00, 'TEST_CLIN_001',
        NULL,
        (SELECT id FROM claims_ref.clinician WHERE clinician_code = 'TEST_CLIN_001'),
        (SELECT id FROM claims_ref.activity_code WHERE code = '99213')
    ),
    (
        (SELECT id FROM claims.claim WHERE claim_key_id = (SELECT id FROM claims.claim_key WHERE claim_id = 'TEST_CLAIM_001')),
        'ACT002', NOW() - INTERVAL '5 days', 'DIAGNOSIS', '85025', 1, 40.00, 'TEST_CLIN_001',
        NULL,
        (SELECT id FROM claims_ref.clinician WHERE clinician_code = 'TEST_CLIN_001'),
        (SELECT id FROM claims_ref.activity_code WHERE code = '85025')
    );

-- Activities for Claim 2 (Partially Paid with Denial)
INSERT INTO claims.activity (
    claim_id, activity_id, start_at, type, code, quantity, net, clinician,
    prior_authorization_id, clinician_ref_id, activity_code_ref_id
) VALUES
    (
        (SELECT id FROM claims.claim WHERE claim_key_id = (SELECT id FROM claims.claim_key WHERE claim_id = 'TEST_CLAIM_002')),
        'ACT003', NOW() - INTERVAL '3 days', 'PROCEDURE', '99213', 1, 150.00, 'TEST_CLIN_002',
        'PA001',
        (SELECT id FROM claims_ref.clinician WHERE clinician_code = 'TEST_CLIN_002'),
        (SELECT id FROM claims_ref.activity_code WHERE code = '99213')
    ),
    (
        (SELECT id FROM claims.claim WHERE claim_key_id = (SELECT id FROM claims.claim_key WHERE claim_id = 'TEST_CLAIM_002')),
        'ACT004', NOW() - INTERVAL '3 days', 'DIAGNOSIS', '71020', 1, 130.00, 'TEST_CLIN_002',
        NULL,
        (SELECT id FROM claims_ref.clinician WHERE clinician_code = 'TEST_CLIN_002'),
        (SELECT id FROM claims_ref.activity_code WHERE code = '71020')
    );

-- =====================================================
-- 8. CREATE TEST REMITTANCES
-- =====================================================

INSERT INTO claims.remittance (ingestion_file_id, tx_at) VALUES
    ((SELECT id FROM claims.ingestion_file WHERE file_id = 'TEST_REMIT_001'), NOW() - INTERVAL '2 days')
ON CONFLICT DO NOTHING;

-- =====================================================
-- 9. CREATE TEST REMITTANCE CLAIMS
-- =====================================================

-- Remittance for Claim 1 (Fully Paid)
INSERT INTO claims.remittance_claim (
    remittance_id, claim_key_id, id_payer, provider_id, denial_code, payment_reference,
    date_settlement, facility_id, payer_ref_id, provider_ref_id
) VALUES
    (
        (SELECT id FROM claims.remittance LIMIT 1),
        (SELECT id FROM claims.claim_key WHERE claim_id = 'TEST_CLAIM_001'),
        'ID001', 'TEST_FAC_001', NULL, 'PAY_REF_001',
        NOW() - INTERVAL '2 days', 'TEST_FAC_001',
        (SELECT id FROM claims_ref.payer WHERE payer_code = 'TEST_PAYER_001'),
        (SELECT id FROM claims_ref.provider WHERE provider_code = 'TEST_PROV_001')
    );

-- Remittance for Claim 2 (Partially Paid with Denial)
INSERT INTO claims.remittance_claim (
    remittance_id, claim_key_id, id_payer, provider_id, denial_code, payment_reference,
    date_settlement, facility_id, payer_ref_id, provider_ref_id
) VALUES
    (
        (SELECT id FROM claims.remittance LIMIT 1),
        (SELECT id FROM claims.claim_key WHERE claim_id = 'TEST_CLAIM_002'),
        'ID002', 'TEST_FAC_001', 'DEN002', 'PAY_REF_002',
        NOW() - INTERVAL '2 days', 'TEST_FAC_001',
        (SELECT id FROM claims_ref.payer WHERE payer_code = 'TEST_PAYER_002'),
        (SELECT id FROM claims_ref.provider WHERE provider_code = 'TEST_PROV_002')
    );

-- =====================================================
-- 10. CREATE TEST REMITTANCE ACTIVITIES
-- =====================================================

-- Remittance Activities for Claim 1 (Fully Paid)
INSERT INTO claims.remittance_activity (
    remittance_claim_id, activity_id, start_at, type, code, quantity, net,
    list_price, clinician, prior_authorization_id, gross, patient_share,
    payment_amount, denial_code
) VALUES
    (
        (SELECT id FROM claims.remittance_claim WHERE claim_key_id = (SELECT id FROM claims.claim_key WHERE claim_id = 'TEST_CLAIM_001')),
        'ACT001', NOW() - INTERVAL '5 days', 'PROCEDURE', '99213', 1, 100.00,
        120.00, 'TEST_CLIN_001', NULL, 110.00, 10.00, 100.00, NULL
    ),
    (
        (SELECT id FROM claims.remittance_claim WHERE claim_key_id = (SELECT id FROM claims.claim_key WHERE claim_id = 'TEST_CLAIM_001')),
        'ACT002', NOW() - INTERVAL '5 days', 'DIAGNOSIS', '85025', 1, 40.00,
        50.00, 'TEST_CLIN_001', NULL, 45.00, 5.00, 40.00, NULL
    );

-- Remittance Activities for Claim 2 (Partially Paid with Denial)
INSERT INTO claims.remittance_activity (
    remittance_claim_id, activity_id, start_at, type, code, quantity, net,
    list_price, clinician, prior_authorization_id, gross, patient_share,
    payment_amount, denial_code
) VALUES
    (
        (SELECT id FROM claims.remittance_claim WHERE claim_key_id = (SELECT id FROM claims.claim_key WHERE claim_id = 'TEST_CLAIM_002')),
        'ACT003', NOW() - INTERVAL '3 days', 'PROCEDURE', '99213', 1, 150.00,
        180.00, 'TEST_CLIN_002', 'PA001', 165.00, 15.00, 120.00, NULL
    ),
    (
        (SELECT id FROM claims.remittance_claim WHERE claim_key_id = (SELECT id FROM claims.claim_key WHERE claim_id = 'TEST_CLAIM_002')),
        'ACT004', NOW() - INTERVAL '3 days', 'DIAGNOSIS', '71020', 1, 130.00,
        150.00, 'TEST_CLIN_002', NULL, 140.00, 10.00, 0.00, 'DEN002'
    );

-- =====================================================
-- 11. VALIDATION QUERIES
-- =====================================================

-- Test 1: Check if views are created successfully
SELECT '=== VIEW CREATION CHECK ===' as test_name;
SELECT
    schemaname as schema_name,
    viewname as view_name,
    viewowner as owner,
    definition LIKE '%v_remittance_advice%' as contains_report_views
FROM pg_views
WHERE schemaname = 'claims'
  AND viewname LIKE '%remittance_advice%'
ORDER BY viewname;

-- Test 2: Check Header Tab Data
SELECT '=== HEADER TAB VALIDATION ===' as test_name;
SELECT
    ordering_clinician_name,
    total_claims,
    total_activities,
    total_billed_amount,
    total_paid_amount,
    total_denied_amount,
    collection_rate,
    denied_activities_count
FROM claims.v_remittance_advice_header
WHERE facility_id = 'TEST_FAC_001'
ORDER BY total_paid_amount DESC;

-- Test 3: Check Claim Wise Tab Data
SELECT '=== CLAIM WISE TAB VALIDATION ===' as test_name;
SELECT
    payer_name,
    claim_number,
    claim_amount,
    remittance_amount,
    collection_rate,
    denied_count,
    activity_count
FROM claims.v_remittance_advice_claim_wise
WHERE facility_id = 'TEST_FAC_001'
ORDER BY claim_number;

-- Test 4: Check Activity Wise Tab Data
SELECT '=== ACTIVITY WISE TAB VALIDATION ===' as test_name;
SELECT
    cpt_code,
    net_amount,
    payment_amount,
    denied_amount,
    payment_percentage,
    payment_status,
    unit_price,
    quantity
FROM claims.v_remittance_advice_activity_wise
WHERE facility_id = 'TEST_FAC_001'
ORDER BY cpt_code;

-- Test 5: Check Report Parameters Function
SELECT '=== REPORT PARAMETERS VALIDATION ===' as test_name;
SELECT * FROM claims.get_remittance_advice_report_params(
    NOW() - INTERVAL '10 days',
    NOW(),
    'TEST_FAC_001',
    NULL,
    NULL,
    NULL
);

-- Test 6: Test Filtering - By Payer
SELECT '=== PAYER FILTERING TEST ===' as test_name;
SELECT
    payer_name,
    COUNT(*) as claim_count,
    SUM(remittance_amount) as total_paid
FROM claims.v_remittance_advice_claim_wise
WHERE payer_id = 'TEST_PAYER_001'
GROUP BY payer_name;

-- Test 7: Test Filtering - By Date Range
SELECT '=== DATE RANGE FILTERING TEST ===' as test_name;
SELECT
    COUNT(*) as activity_count,
    SUM(net_amount) as total_billed,
    SUM(payment_amount) as total_paid
FROM claims.v_remittance_advice_activity_wise
WHERE start_date >= NOW() - INTERVAL '7 days'
  AND start_date <= NOW();

-- Test 8: Test Calculations
SELECT '=== CALCULATIONS VALIDATION ===' as test_name;
SELECT
    'Header Tab Collection Rate' as calculation_type,
    ROUND(
        CASE
            WHEN SUM(total_billed_amount) > 0
            THEN (SUM(total_paid_amount) / SUM(total_billed_amount)) * 100
            ELSE 0
        END, 2
    ) as calculated_rate
FROM claims.v_remittance_advice_header
WHERE facility_id = 'TEST_FAC_001'

UNION ALL

SELECT
    'Claim Wise Collection Rate' as calculation_type,
    ROUND(
        CASE
            WHEN SUM(claim_amount) > 0
            THEN (SUM(remittance_amount) / SUM(claim_amount)) * 100
            ELSE 0
        END, 2
    ) as calculated_rate
FROM claims.v_remittance_advice_claim_wise
WHERE facility_id = 'TEST_FAC_001';

-- =====================================================
-- 12. EXPECTED RESULTS VERIFICATION
-- =====================================================

-- Expected Results for Validation:
-- Header Tab:
-- - Should show 2 clinicians with aggregated data
-- - Total claims: 2, Total activities: 4
-- - Total billed: 420.00, Total paid: 260.00, Total denied: 160.00
-- - Collection rate: ~61.90%

-- Claim Wise Tab:
-- - Should show 2 claims with their details
-- - Claim 1: Fully paid (140.00 billed, 140.00 paid)
-- - Claim 2: Partially paid (280.00 billed, 120.00 paid, 160.00 denied)

-- Activity Wise Tab:
-- - Should show 4 activities with CPT codes
-- - Activity 1 & 2: Fully paid
-- - Activity 3: Partially paid
-- - Activity 4: Fully denied

-- =====================================================
-- 13. CLEANUP TEST DATA (Optional)
-- =====================================================

-- Uncomment to clean up test data:
/*
DELETE FROM claims.remittance_activity WHERE remittance_claim_id IN (
    SELECT id FROM claims.remittance_claim WHERE claim_key_id IN (
        SELECT id FROM claims.claim_key WHERE claim_id LIKE 'TEST_CLAIM_%'
    )
);

DELETE FROM claims.remittance_claim WHERE claim_key_id IN (
    SELECT id FROM claims.claim_key WHERE claim_id LIKE 'TEST_CLAIM_%'
);

DELETE FROM claims.remittance WHERE ingestion_file_id IN (
    SELECT id FROM claims.ingestion_file WHERE file_id LIKE 'TEST_REMIT_%'
);

DELETE FROM claims.activity WHERE claim_id IN (
    SELECT id FROM claims.claim WHERE claim_key_id IN (
        SELECT id FROM claims.claim_key WHERE claim_id LIKE 'TEST_CLAIM_%'
    )
);

DELETE FROM claims.encounter WHERE claim_id IN (
    SELECT id FROM claims.claim WHERE claim_key_id IN (
        SELECT id FROM claims.claim_key WHERE claim_id LIKE 'TEST_CLAIM_%'
    )
);

DELETE FROM claims.claim WHERE claim_key_id IN (
    SELECT id FROM claims.claim_key WHERE claim_id LIKE 'TEST_CLAIM_%'
);

DELETE FROM claims.submission WHERE ingestion_file_id IN (
    SELECT id FROM claims.ingestion_file WHERE file_id LIKE 'TEST_SUB_%'
);

DELETE FROM claims.claim_key WHERE claim_id LIKE 'TEST_CLAIM_%';
DELETE FROM claims.ingestion_file WHERE file_id LIKE 'TEST_%';

-- Clean up reference data (be careful with this)
-- DELETE FROM claims_ref.facility WHERE facility_code LIKE 'TEST_%';
-- DELETE FROM claims_ref.payer WHERE payer_code LIKE 'TEST_%';
-- DELETE FROM claims_ref.provider WHERE provider_code LIKE 'TEST_%';
-- DELETE FROM claims_ref.clinician WHERE clinician_code LIKE 'TEST_%';
*/

-- =====================================================
-- 14. PERFORMANCE CHECKS
-- =====================================================

-- Check if indexes are being used
SELECT '=== INDEX USAGE CHECK ===' as check_type;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM claims.v_remittance_advice_header
WHERE facility_id = 'TEST_FAC_001';

-- Check view dependencies
SELECT '=== VIEW DEPENDENCIES ===' as check_type;
SELECT
    v.schemaname as schema_name,
    v.viewname as view_name,
    v.viewowner as owner,
    d.refobjid::regclass as dependency_table,
    d.refobjsubid as column_number
FROM pg_views v
JOIN pg_depend d ON v.oid = d.objid
WHERE v.schemaname = 'claims'
  AND v.viewname LIKE '%remittance_advice%'
  AND d.classid = 'pg_class'::regclass
ORDER BY v.viewname, d.refobjid;

-- =====================================================
-- 15. FINAL VALIDATION SUMMARY
-- =====================================================

SELECT '=== VALIDATION SUMMARY ===' as summary;
SELECT
    'Views Created' as component,
    COUNT(*) as count,
    '✅ All views should exist' as status
FROM pg_views
WHERE schemaname = 'claims'
  AND viewname LIKE '%remittance_advice%'

UNION ALL

SELECT
    'Test Data Created' as component,
    COUNT(*) as count,
    CASE
        WHEN COUNT(*) > 0 THEN '✅ Test data exists'
        ELSE '❌ No test data found'
    END as status
FROM claims.claim
WHERE claim_key_id IN (SELECT id FROM claims.claim_key WHERE claim_id LIKE 'TEST_CLAIM_%')

UNION ALL

SELECT
    'Header Tab Working' as component,
    COUNT(*) as count,
    CASE
        WHEN COUNT(*) > 0 THEN '✅ Returns data'
        ELSE '❌ No data returned'
    END as status
FROM claims.v_remittance_advice_header
WHERE facility_id = 'TEST_FAC_001'

UNION ALL

SELECT
    'Claim Wise Tab Working' as component,
    COUNT(*) as count,
    CASE
        WHEN COUNT(*) > 0 THEN '✅ Returns data'
        ELSE '❌ No data returned'
    END as status
FROM claims.v_remittance_advice_claim_wise
WHERE facility_id = 'TEST_FAC_001'

UNION ALL

SELECT
    'Activity Wise Tab Working' as component,
    COUNT(*) as count,
    CASE
        WHEN COUNT(*) > 0 THEN '✅ Returns data'
        ELSE '❌ No data returned'
    END as status
FROM claims.v_remittance_advice_activity_wise
WHERE facility_id = 'TEST_FAC_001';

-- =====================================================
-- 16. RUN VALIDATION
-- =====================================================

-- To run this validation:
-- 1. Deploy the report views first (run 09_remittance_advice_payerwise_report_production.sql)
-- 2. Run this validation script
-- 3. Check the results to ensure everything works as expected
-- 4. Use the cleanup section if you want to remove test data

SELECT '=== VALIDATION SCRIPT READY ===' as status;
SELECT 'Run each section above to validate the report functionality' as instructions;
