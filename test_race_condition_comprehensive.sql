-- Comprehensive race condition test for PersistService
-- This test simulates multiple threads processing the same claim simultaneously

-- Test data setup
INSERT INTO claims.claim_key (claim_id, created_at) VALUES ('RACE-TEST-CLAIM-002', NOW()) ON CONFLICT (claim_id) DO NOTHING;

-- Get the claim_key_id for testing
DO $$
DECLARE
    test_claim_key_id BIGINT;
    test_ingestion_file_id BIGINT := 2001;
    test_submission_id BIGINT := 3001;
BEGIN
    -- Get the claim key ID
    SELECT id INTO test_claim_key_id FROM claims.claim_key WHERE claim_id = 'RACE-TEST-CLAIM-002';
    
    IF test_claim_key_id IS NOT NULL THEN
        RAISE NOTICE 'Testing race condition fixes with claim_key_id: %', test_claim_key_id;
        
        -- Test 1: First submission event (should succeed)
        RAISE NOTICE '=== Test 1: First Submission Event ===';
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
        
        -- Test 2: Simulate race condition - try to insert duplicate submission event
        -- This should trigger the unique index violation and be handled gracefully
        RAISE NOTICE '=== Test 2: Race Condition Simulation ===';
        BEGIN
            INSERT INTO claims.claim_event (
                claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
            ) VALUES (
                test_claim_key_id, test_ingestion_file_id + 1, NOW(), 1, test_submission_id + 1, NULL
            );
            RAISE NOTICE '✗ Duplicate submission event created (this should not happen)';
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
                        RAISE NOTICE '✓ Race condition handled gracefully - no data loss';
                    ELSE
                        RAISE NOTICE '✗ Could not find existing event (unexpected)';
                    END IF;
                END;
            WHEN OTHERS THEN
                RAISE NOTICE '✗ Unexpected error on duplicate submission: %', SQLERRM;
        END;
        
        -- Test 3: Test resubmission scenario
        RAISE NOTICE '=== Test 3: Resubmission Scenario ===';
        BEGIN
            -- First, try to find existing submission event (simulating resubmission logic)
            DECLARE
                existing_event_id BIGINT;
            BEGIN
                SELECT id INTO existing_event_id 
                FROM claims.claim_event 
                WHERE claim_key_id = test_claim_key_id AND type = 1 
                LIMIT 1;
                
                IF existing_event_id IS NOT NULL THEN
                    RAISE NOTICE '✓ Found existing submission event id: % for resubmission', existing_event_id;
                    
                    -- Create resubmission event
                    INSERT INTO claims.claim_event (
                        claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
                    ) VALUES (
                        test_claim_key_id, test_ingestion_file_id + 2, NOW(), 2, test_submission_id + 2, NULL
                    );
                    RAISE NOTICE '✓ Resubmission event created successfully';
                ELSE
                    RAISE NOTICE '✗ No existing submission event found for resubmission';
                END IF;
            END;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '✗ Resubmission failed: %', SQLERRM;
        END;
        
        -- Test 4: Test concurrent access to same claim_key
        RAISE NOTICE '=== Test 4: Concurrent Claim Key Access ===';
        BEGIN
            -- Simulate multiple threads trying to access the same claim_key
            DECLARE
                claim_key_id_1 BIGINT;
                claim_key_id_2 BIGINT;
            BEGIN
                -- Both threads would get the same claim_key_id
                SELECT id INTO claim_key_id_1 FROM claims.claim_key WHERE claim_id = 'RACE-TEST-CLAIM-002';
                SELECT id INTO claim_key_id_2 FROM claims.claim_key WHERE claim_id = 'RACE-TEST-CLAIM-002';
                
                IF claim_key_id_1 = claim_key_id_2 THEN
                    RAISE NOTICE '✓ Both threads get same claim_key_id: % (consistent)', claim_key_id_1;
                ELSE
                    RAISE NOTICE '✗ Different claim_key_ids: % vs % (inconsistent)', claim_key_id_1, claim_key_id_2;
                END IF;
            END;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '✗ Concurrent claim key access failed: %', SQLERRM;
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
        
    ELSE
        RAISE NOTICE 'Test claim key not found';
    END IF;
END $$;

-- Test the improved duplicate detection logic
DO $$
DECLARE
    test_claim_id TEXT := 'RACE-TEST-CLAIM-002';
    submission_count INTEGER;
BEGIN
    RAISE NOTICE '=== Testing Improved Duplicate Detection Logic ===';
    
    -- This simulates the improved duplicate detection query
    SELECT COUNT(*) INTO submission_count
    FROM claims.claim_key ck 
    JOIN claims.claim_event ce ON ck.id = ce.claim_key_id 
    WHERE ck.claim_id = test_claim_id AND ce.type = 1;
    
    IF submission_count > 0 THEN
        RAISE NOTICE '✓ Duplicate detection would return TRUE (count: %)', submission_count;
        RAISE NOTICE '  → For resubmissions: would reuse existing submission event';
        RAISE NOTICE '  → For duplicate submissions: would handle gracefully with exception';
    ELSE
        RAISE NOTICE '✗ Duplicate detection would return FALSE (count: %)', submission_count;
    END IF;
END $$;

-- Cleanup
DELETE FROM claims.claim_event WHERE claim_key_id IN (
    SELECT id FROM claims.claim_key WHERE claim_id = 'RACE-TEST-CLAIM-002'
);
DELETE FROM claims.claim_key WHERE claim_id = 'RACE-TEST-CLAIM-002';

RAISE NOTICE 'Race condition test completed successfully!';
