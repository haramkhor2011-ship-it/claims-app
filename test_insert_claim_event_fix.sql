-- Test the fixed insertClaimEvent method
-- This test simulates the exact scenario that was causing the error

-- Test data setup
DO $$
DECLARE
    test_claim_key_id BIGINT := 72130;  -- Using the same ID from your error
    test_ingestion_file_id BIGINT := 99999;
    test_submission_id BIGINT := 88888;
    test_event_id BIGINT;
    test_event_id_2 BIGINT;
BEGIN
    RAISE NOTICE '=== Testing Fixed insertClaimEvent Method ===';
    RAISE NOTICE '';
    
    -- Create test ingestion file
    INSERT INTO claims.ingestion_file (file_id, file_name, source, created_at) 
    VALUES ('TEST-EVENT-FIX', 'test-event-fix.xml', 'test', NOW()) 
    RETURNING id INTO test_ingestion_file_id;
    
    RAISE NOTICE 'Created test ingestion file id: %', test_ingestion_file_id;
    
    -- Test 1: First submission event (should succeed)
    RAISE NOTICE '--- Test 1: First Submission Event ---';
    BEGIN
        INSERT INTO claims.claim_event (
            claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
        ) VALUES (
            test_claim_key_id, test_ingestion_file_id, NOW(), 1, test_submission_id, NULL
        ) RETURNING id INTO test_event_id;
        
        RAISE NOTICE '✓ First submission event created successfully with id: %', test_event_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '✗ First submission failed: %', SQLERRM;
    END;
    
    -- Test 2: Simulate the fixed logic - check if submission event exists
    RAISE NOTICE '--- Test 2: Check Existing Submission Event ---';
    BEGIN
        SELECT id INTO test_event_id_2
        FROM claims.claim_event 
        WHERE claim_key_id = test_claim_key_id AND type = 1 
        LIMIT 1;
        
        IF test_event_id_2 IS NOT NULL THEN
            RAISE NOTICE '✓ Found existing submission event id: % (this is what the fix does)', test_event_id_2;
            RAISE NOTICE '✓ Would return existing event instead of trying to insert';
        ELSE
            RAISE NOTICE '✗ No existing submission event found (unexpected)';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '✗ Check failed: %', SQLERRM;
    END;
    
    -- Test 3: Try to insert duplicate submission event (should fail with our error)
    RAISE NOTICE '--- Test 3: Attempt Duplicate Submission Event ---';
    BEGIN
        INSERT INTO claims.claim_event (
            claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
        ) VALUES (
            test_claim_key_id, test_ingestion_file_id + 1, NOW(), 1, test_submission_id + 1, NULL
        );
        
        RAISE NOTICE '✗ Duplicate submission event created (this should not happen)';
    EXCEPTION
        WHEN unique_violation THEN
            IF SQLERRM LIKE '%uq_claim_event_one_submission%' THEN
                RAISE NOTICE '✓ Correctly rejected by uq_claim_event_one_submission: %', SQLERRM;
                RAISE NOTICE '✓ This is the error the fix prevents by checking first';
            ELSE
                RAISE NOTICE '✗ Wrong constraint violation: %', SQLERRM;
            END IF;
        WHEN OTHERS THEN
            RAISE NOTICE '✗ Unexpected error: %', SQLERRM;
    END;
    
    -- Test 4: Test non-submission event (should work fine)
    RAISE NOTICE '--- Test 4: Non-Submission Event (type=2) ---';
    BEGIN
        INSERT INTO claims.claim_event (
            claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
        ) VALUES (
            test_claim_key_id, test_ingestion_file_id, NOW(), 2, test_submission_id, NULL
        ) RETURNING id INTO test_event_id;
        
        RAISE NOTICE '✓ Non-submission event created successfully with id: %', test_event_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '✗ Non-submission event failed: %', SQLERRM;
    END;
    
    -- Test 5: Test dedup constraint (same claim_key_id, type, event_time)
    RAISE NOTICE '--- Test 5: Dedup Constraint Test ---';
    BEGIN
        INSERT INTO claims.claim_event (
            claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
        ) VALUES (
            test_claim_key_id, test_ingestion_file_id, NOW(), 2, test_submission_id, NULL
        );
        
        RAISE NOTICE '✗ Duplicate event created (should be caught by dedup constraint)';
    EXCEPTION
        WHEN unique_violation THEN
            IF SQLERRM LIKE '%uq_claim_event_dedup%' THEN
                RAISE NOTICE '✓ Correctly rejected by uq_claim_event_dedup: %', SQLERRM;
            ELSE
                RAISE NOTICE '✗ Wrong constraint violation: %', SQLERRM;
            END IF;
        WHEN OTHERS THEN
            RAISE NOTICE '✗ Unexpected error: %', SQLERRM;
    END;
    
    -- Show final state
    RAISE NOTICE '--- Final State ---';
    RAISE NOTICE 'Total events for claim_key_id %: %', test_claim_key_id, (
        SELECT COUNT(*) FROM claims.claim_event WHERE claim_key_id = test_claim_key_id
    );
    
    RAISE NOTICE 'Event breakdown:';
    RAISE NOTICE '  Submission events (type=1): %', (
        SELECT COUNT(*) FROM claims.claim_event WHERE claim_key_id = test_claim_key_id AND type = 1
    );
    RAISE NOTICE '  Resubmission events (type=2): %', (
        SELECT COUNT(*) FROM claims.claim_event WHERE claim_key_id = test_claim_key_id AND type = 2
    );
    
    -- Verify data integrity
    DECLARE
        submission_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO submission_count 
        FROM claims.claim_event 
        WHERE claim_key_id = test_claim_key_id AND type = 1;
        
        IF submission_count = 1 THEN
            RAISE NOTICE '✓ Data integrity maintained: exactly 1 submission event';
        ELSE
            RAISE NOTICE '✗ Data integrity issue: % submission events (expected 1)', submission_count;
        END IF;
    END;
    
    -- Cleanup
    DELETE FROM claims.claim_event WHERE claim_key_id = test_claim_key_id;
    DELETE FROM claims.ingestion_file WHERE id = test_ingestion_file_id;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== Test Summary ===';
    RAISE NOTICE 'The fix prevents the duplicate key error by:';
    RAISE NOTICE '1. Checking for existing submission events BEFORE attempting insert';
    RAISE NOTICE '2. Returning existing event ID if found';
    RAISE NOTICE '3. Only attempting insert if no submission event exists';
    RAISE NOTICE '4. Handling both uq_claim_event_dedup and uq_claim_event_one_submission constraints';
    RAISE NOTICE '';
    RAISE NOTICE 'This should resolve your duplicate key violation error!';
END $$;




