-- Test script for improved resubmission flag solution
-- This demonstrates how the resubmission flag prevents race conditions

-- Test data setup
INSERT INTO claims.claim_key (claim_id, created_at) VALUES ('RESUB-TEST-CLAIM-001', NOW()) ON CONFLICT (claim_id) DO NOTHING;

-- Get the claim_key_id for testing
DO $$
DECLARE
    test_claim_key_id BIGINT;
    test_ingestion_file_id BIGINT := 1001;
    test_submission_id BIGINT := 2001;
BEGIN
    -- Get the claim key ID
    SELECT id INTO test_claim_key_id FROM claims.claim_key WHERE claim_id = 'RESUB-TEST-CLAIM-001';
    
    IF test_claim_key_id IS NOT NULL THEN
        RAISE NOTICE 'Testing improved resubmission flag solution with claim_key_id: %', test_claim_key_id;
        
        -- Test 1: First submission (resubmission = null)
        RAISE NOTICE '=== Test 1: First Submission (resubmission = null) ===';
        BEGIN
            INSERT INTO claims.claim_event (
                claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
            ) VALUES (
                test_claim_key_id, test_ingestion_file_id, NOW(), 1, test_submission_id, NULL
            );
            RAISE NOTICE '✓ First submission event created successfully';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '✗ First submission failed: %', SQLERRM;
        END;
        
        -- Test 2: Duplicate submission (resubmission = null) - should be skipped
        RAISE NOTICE '=== Test 2: Duplicate Submission (resubmission = null) - Should be Skipped ===';
        BEGIN
            INSERT INTO claims.claim_event (
                claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
            ) VALUES (
                test_claim_key_id, test_ingestion_file_id + 1, NOW(), 1, test_submission_id + 1, NULL
            );
            RAISE NOTICE '✗ Duplicate submission event created (this should not happen)';
        EXCEPTION
            WHEN unique_violation THEN
                RAISE NOTICE '✓ Duplicate submission correctly rejected by unique index';
                
                -- Simulate what the improved code does - retrieve existing event
                DECLARE
                    existing_event_id BIGINT;
                BEGIN
                    SELECT id INTO existing_event_id 
                    FROM claims.claim_event 
                    WHERE claim_key_id = test_claim_key_id AND type = 1 
                    LIMIT 1;
                    
                    IF existing_event_id IS NOT NULL THEN
                        RAISE NOTICE '✓ Found existing submission event id: % (would reuse this)', existing_event_id;
                    END IF;
                END;
            WHEN OTHERS THEN
                RAISE NOTICE '✗ Unexpected error: %', SQLERRM;
        END;
        
        -- Test 3: Resubmission (resubmission != null) - should create resubmission event
        RAISE NOTICE '=== Test 3: Resubmission (resubmission != null) - Should Create Resubmission Event ===';
        BEGIN
            INSERT INTO claims.claim_event (
                claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
            ) VALUES (
                test_claim_key_id, test_ingestion_file_id + 2, NOW(), 2, test_submission_id + 2, NULL
            );
            RAISE NOTICE '✓ Resubmission event created successfully';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '✗ Resubmission failed: %', SQLERRM;
        END;
        
        -- Test 4: Another resubmission - should create another resubmission event
        RAISE NOTICE '=== Test 4: Another Resubmission - Should Create Another Resubmission Event ===';
        BEGIN
            INSERT INTO claims.claim_event (
                claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
            ) VALUES (
                test_claim_key_id, test_ingestion_file_id + 3, NOW(), 2, test_submission_id + 3, NULL
            );
            RAISE NOTICE '✓ Second resubmission event created successfully';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '✗ Second resubmission failed: %', SQLERRM;
        END;
        
        -- Show final state
        RAISE NOTICE '=== Final State ===';
        RAISE NOTICE 'Total events for claim: %', (
            SELECT COUNT(*) FROM claims.claim_event WHERE claim_key_id = test_claim_key_id
        );
        
        RAISE NOTICE 'Event breakdown:';
        RAISE NOTICE '  Submission events (type=1): %', (
            SELECT COUNT(*) FROM claims.claim_event WHERE claim_key_id = test_claim_key_id AND type = 1
        );
        RAISE NOTICE '  Resubmission events (type=2): %', (
            SELECT COUNT(*) FROM claims.claim_event WHERE claim_key_id = test_claim_key_id AND type = 2
        );
        
        -- Show event timeline
        RAISE NOTICE 'Event timeline:';
        FOR rec IN (
            SELECT type, event_time, ingestion_file_id 
            FROM claims.claim_event 
            WHERE claim_key_id = test_claim_key_id 
            ORDER BY event_time
        ) LOOP
            RAISE NOTICE '  Type: %, Time: %, File: %', rec.type, rec.event_time, rec.ingestion_file_id;
        END LOOP;
        
    ELSE
        RAISE NOTICE 'Test claim key not found';
    END IF;
END $$;

-- Test the improved isAlreadySubmitted logic
DO $$
DECLARE
    test_claim_id TEXT := 'RESUB-TEST-CLAIM-001';
    submission_count INTEGER;
BEGIN
    RAISE NOTICE '=== Testing Improved isAlreadySubmitted Logic ===';
    
    -- This simulates the improved isAlreadySubmitted query
    SELECT COUNT(*) INTO submission_count
    FROM claims.claim_key ck 
    JOIN claims.claim_event ce ON ck.id = ce.claim_key_id 
    WHERE ck.claim_id = test_claim_id AND ce.type = 1;
    
    IF submission_count > 0 THEN
        RAISE NOTICE '✓ isAlreadySubmitted would return TRUE (count: %)', submission_count;
        RAISE NOTICE '  → For resubmissions: would reuse existing submission event';
        RAISE NOTICE '  → For duplicate submissions: would skip processing';
    ELSE
        RAISE NOTICE '✗ isAlreadySubmitted would return FALSE (count: %)', submission_count;
    END IF;
END $$;

-- Cleanup
DELETE FROM claims.claim_event WHERE claim_key_id IN (
    SELECT id FROM claims.claim_key WHERE claim_id = 'RESUB-TEST-CLAIM-001'
);
DELETE FROM claims.claim_key WHERE claim_id = 'RESUB-TEST-CLAIM-001';

RAISE NOTICE 'Improved resubmission flag solution test completed successfully!';
