-- Test script to verify the duplicate submission fix
-- This script simulates the scenario that was causing the duplicate key exception

-- Test data setup
INSERT INTO claims.claim_key (claim_id, created_at) VALUES ('TEST-CLAIM-001', NOW()) ON CONFLICT (claim_id) DO NOTHING;

-- Get the claim_key_id for testing
DO $$
DECLARE
    test_claim_key_id BIGINT;
BEGIN
    -- Get the claim key ID
    SELECT id INTO test_claim_key_id FROM claims.claim_key WHERE claim_id = 'TEST-CLAIM-001';
    
    IF test_claim_key_id IS NOT NULL THEN
        RAISE NOTICE 'Testing with claim_key_id: %', test_claim_key_id;
        
        -- Test 1: Insert first submission event (should succeed)
        BEGIN
            INSERT INTO claims.claim_event (
                claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
            ) VALUES (
                test_claim_key_id, 1, NOW(), 1, 1, NULL
            );
            RAISE NOTICE 'First submission event inserted successfully';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'First submission failed: %', SQLERRM;
        END;
        
        -- Test 2: Try to insert duplicate submission event (should be handled gracefully)
        BEGIN
            INSERT INTO claims.claim_event (
                claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
            ) VALUES (
                test_claim_key_id, 2, NOW(), 1, 2, NULL
            );
            RAISE NOTICE 'Duplicate submission event inserted (unexpected)';
        EXCEPTION
            WHEN unique_violation THEN
                RAISE NOTICE 'Duplicate submission correctly rejected by constraint: %', SQLERRM;
            WHEN OTHERS THEN
                RAISE NOTICE 'Unexpected error on duplicate submission: %', SQLERRM;
        END;
        
        -- Test 3: Insert resubmission event (should succeed)
        BEGIN
            INSERT INTO claims.claim_event (
                claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
            ) VALUES (
                test_claim_key_id, 3, NOW(), 2, 3, NULL
            );
            RAISE NOTICE 'Resubmission event inserted successfully';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Resubmission failed: %', SQLERRM;
        END;
        
        -- Test 4: Insert remittance event (should succeed)
        BEGIN
            INSERT INTO claims.claim_event (
                claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
            ) VALUES (
                test_claim_key_id, 4, NOW(), 3, NULL, 1
            );
            RAISE NOTICE 'Remittance event inserted successfully';
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Remittance failed: %', SQLERRM;
        END;
        
        -- Show final state
        RAISE NOTICE 'Final event count for claim: %', (
            SELECT COUNT(*) FROM claims.claim_event WHERE claim_key_id = test_claim_key_id
        );
        
    ELSE
        RAISE NOTICE 'Test claim key not found';
    END IF;
END $$;

-- Cleanup
DELETE FROM claims.claim_event WHERE claim_key_id IN (
    SELECT id FROM claims.claim_key WHERE claim_id = 'TEST-CLAIM-001'
);
DELETE FROM claims.claim_key WHERE claim_id = 'TEST-CLAIM-001';
