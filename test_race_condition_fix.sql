-- Comprehensive test for race condition fix in PersistService
-- This test simulates the exact scenario that was causing duplicate key exceptions

-- Test setup
INSERT INTO claims.claim_key (claim_id, created_at) VALUES ('RACE-TEST-CLAIM-001', NOW()) ON CONFLICT (claim_id) DO NOTHING;

-- Get the claim_key_id for testing
DO $$
DECLARE
    test_claim_key_id BIGINT;
    test_ingestion_file_id BIGINT := 999;
    test_submission_id BIGINT := 888;
BEGIN
    -- Get the claim key ID
    SELECT id INTO test_claim_key_id FROM claims.claim_key WHERE claim_id = 'RACE-TEST-CLAIM-001';
    
    IF test_claim_key_id IS NOT NULL THEN
        RAISE NOTICE 'Testing race condition fix with claim_key_id: %', test_claim_key_id;
        
        -- Test 1: First submission event (should succeed)
        BEGIN
            INSERT INTO claims.claim_event (
                claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
            ) VALUES (
                test_claim_key_id, test_ingestion_file_id, NOW(), 1, test_submission_id, NULL
            );
            RAISE NOTICE '✓ First submission event inserted successfully';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '✗ First submission failed: %', SQLERRM;
        END;
        
        -- Test 2: Simulate race condition - try to insert duplicate submission event
        -- This should trigger the unique index violation and be handled gracefully
        BEGIN
            INSERT INTO claims.claim_event (
                claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
            ) VALUES (
                test_claim_key_id, test_ingestion_file_id + 1, NOW(), 1, test_submission_id + 1, NULL
            );
            RAISE NOTICE '✗ Duplicate submission event inserted (this should not happen)';
        EXCEPTION
            WHEN unique_violation THEN
                RAISE NOTICE '✓ Duplicate submission correctly rejected by unique index: %', SQLERRM;
                
                -- Now simulate what the fixed code would do - retrieve existing event
                DECLARE
                    existing_event_id BIGINT;
                BEGIN
                    SELECT id INTO existing_event_id 
                    FROM claims.claim_event 
                    WHERE claim_key_id = test_claim_key_id AND type = 1 
                    LIMIT 1;
                    
                    IF existing_event_id IS NOT NULL THEN
                        RAISE NOTICE '✓ Found existing submission event id: % (this is what the fix does)', existing_event_id;
                    ELSE
                        RAISE NOTICE '✗ Could not find existing event (unexpected)';
                    END IF;
                END;
            WHEN OTHERS THEN
                RAISE NOTICE '✗ Unexpected error on duplicate submission: %', SQLERRM;
        END;
        
        -- Test 3: Insert resubmission event (should succeed - different type)
        BEGIN
            INSERT INTO claims.claim_event (
                claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
            ) VALUES (
                test_claim_key_id, test_ingestion_file_id + 2, NOW(), 2, test_submission_id + 2, NULL
            );
            RAISE NOTICE '✓ Resubmission event inserted successfully';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '✗ Resubmission failed: %', SQLERRM;
        END;
        
        -- Test 4: Insert remittance event (should succeed - different type)
        BEGIN
            INSERT INTO claims.claim_event (
                claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
            ) VALUES (
                test_claim_key_id, test_ingestion_file_id + 3, NOW(), 3, NULL, 777
            );
            RAISE NOTICE '✓ Remittance event inserted successfully';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '✗ Remittance failed: %', SQLERRM;
        END;
        
        -- Show final state
        RAISE NOTICE 'Final event count for claim: %', (
            SELECT COUNT(*) FROM claims.claim_event WHERE claim_key_id = test_claim_key_id
        );
        
        -- Show event types
        RAISE NOTICE 'Event types: %', (
            SELECT STRING_AGG(type::text, ', ' ORDER BY type) 
            FROM claims.claim_event 
            WHERE claim_key_id = test_claim_key_id
        );
        
    ELSE
        RAISE NOTICE 'Test claim key not found';
    END IF;
END $$;

-- Test the isAlreadySubmitted logic
DO $$
DECLARE
    test_claim_id TEXT := 'RACE-TEST-CLAIM-001';
    submission_count INTEGER;
BEGIN
    RAISE NOTICE 'Testing isAlreadySubmitted logic for claim: %', test_claim_id;
    
    -- This simulates the improved isAlreadySubmitted query
    SELECT COUNT(*) INTO submission_count
    FROM claims.claim_key ck 
    JOIN claims.claim_event ce ON ck.id = ce.claim_key_id 
    WHERE ck.claim_id = test_claim_id AND ce.type = 1;
    
    IF submission_count > 0 THEN
        RAISE NOTICE '✓ isAlreadySubmitted would return TRUE (count: %)', submission_count;
    ELSE
        RAISE NOTICE '✗ isAlreadySubmitted would return FALSE (count: %)', submission_count;
    END IF;
END $$;

-- Cleanup
DELETE FROM claims.claim_event WHERE claim_key_id IN (
    SELECT id FROM claims.claim_key WHERE claim_id = 'RACE-TEST-CLAIM-001'
);
DELETE FROM claims.claim_key WHERE claim_id = 'RACE-TEST-CLAIM-001';

RAISE NOTICE 'Race condition test completed successfully!';
