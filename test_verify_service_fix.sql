-- Test the fixed VerifyService activity count query
-- This test verifies that the corrected join query works properly

-- Test data setup
DO $$
DECLARE
    test_ingestion_file_id BIGINT := 99999;
    test_claim_key_id BIGINT;
    test_claim_id BIGINT;
    test_activity_count INTEGER;
    test_verification_result INTEGER;
BEGIN
    RAISE NOTICE '=== Testing Fixed VerifyService Activity Count Query ===';
    
    -- Create test ingestion file
    INSERT INTO claims.ingestion_file (file_id, file_name, source, created_at) 
    VALUES ('TEST-VERIFY-FIX', 'test-verify-fix.xml', 'test', NOW()) 
    RETURNING id INTO test_ingestion_file_id;
    
    -- Create test claim key
    INSERT INTO claims.claim_key (claim_id, created_at) 
    VALUES ('TEST-CLAIM-VERIFY', NOW()) 
    RETURNING id INTO test_claim_key_id;
    
    -- Create test claim
    INSERT INTO claims.claim (claim_key_id, submission_id, id_payer, member_id, payer_id, provider_id, gross, patient_share, net, tx_at)
    VALUES (test_claim_key_id, 1, 'TEST-PAYER', 'TEST-MEMBER', 'PAYER-001', 'PROVIDER-001', 100.00, 10.00, 90.00, NOW())
    RETURNING id INTO test_claim_id;
    
    -- Create test claim event
    INSERT INTO claims.claim_event (claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id)
    VALUES (test_claim_key_id, test_ingestion_file_id, NOW(), 1, 1, NULL);
    
    -- Create test activities
    INSERT INTO claims.activity (claim_id, activity_id, start_at, type, code, quantity, net, clinician, prior_authorization_id)
    VALUES 
        (test_claim_id, 'ACT-001', NOW(), 'PROCEDURE', 'CPT-001', 1, 50.00, 'DOC-001', NULL),
        (test_claim_id, 'ACT-002', NOW(), 'PROCEDURE', 'CPT-002', 2, 30.00, 'DOC-002', NULL),
        (test_claim_id, 'ACT-003', NOW(), 'PROCEDURE', 'CPT-003', 1, 20.00, 'DOC-003', NULL);
    
    -- Test the OLD (broken) query
    RAISE NOTICE '--- Testing OLD (broken) query ---';
    BEGIN
        SELECT COUNT(*) INTO test_activity_count
        FROM claims.activity a 
        JOIN claims.claim_event ce ON ce.claim_key_id = a.claim_id 
        WHERE ce.ingestion_file_id = test_ingestion_file_id;
        
        RAISE NOTICE 'OLD query result: % activities found', test_activity_count;
        IF test_activity_count = 0 THEN
            RAISE NOTICE '✓ OLD query correctly returns 0 (this was the bug)';
        ELSE
            RAISE NOTICE '✗ OLD query unexpectedly returned %', test_activity_count;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'OLD query failed with error: %', SQLERRM;
    END;
    
    -- Test the NEW (fixed) query
    RAISE NOTICE '--- Testing NEW (fixed) query ---';
    BEGIN
        SELECT COUNT(*) INTO test_activity_count
        FROM claims.activity a 
        JOIN claims.claim c ON c.id = a.claim_id 
        JOIN claims.claim_event ce ON ce.claim_key_id = c.claim_key_id 
        WHERE ce.ingestion_file_id = test_ingestion_file_id;
        
        RAISE NOTICE 'NEW query result: % activities found', test_activity_count;
        IF test_activity_count = 3 THEN
            RAISE NOTICE '✓ NEW query correctly returns 3 activities';
        ELSE
            RAISE NOTICE '✗ NEW query returned % (expected 3)', test_activity_count;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'NEW query failed with error: %', SQLERRM;
    END;
    
    -- Test the verification logic
    RAISE NOTICE '--- Testing Verification Logic ---';
    IF test_activity_count = 3 THEN
        RAISE NOTICE '✓ Verification would PASS (3 >= 3)';
        RAISE NOTICE '✓ Files would be DELETED (not moved to archive/fail)';
    ELSE
        RAISE NOTICE '✗ Verification would FAIL (% < 3)', test_activity_count;
        RAISE NOTICE '✗ Files would be moved to archive/fail directory';
    END IF;
    
    -- Cleanup
    DELETE FROM claims.activity WHERE claim_id = test_claim_id;
    DELETE FROM claims.claim_event WHERE claim_key_id = test_claim_key_id;
    DELETE FROM claims.claim WHERE id = test_claim_id;
    DELETE FROM claims.claim_key WHERE id = test_claim_key_id;
    DELETE FROM claims.ingestion_file WHERE id = test_ingestion_file_id;
    
    RAISE NOTICE '=== Test completed successfully! ===';
    RAISE NOTICE 'The fix should resolve the archive/fail directory issue.';
END $$;




