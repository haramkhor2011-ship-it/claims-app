-- Simple verification that the constraint exists and works
-- This confirms the fix is working

-- Step 1: Verify the constraint exists
SELECT 
    constraint_name, 
    constraint_type, 
    table_name,
    table_schema
FROM information_schema.table_constraints 
WHERE constraint_name = 'uq_claim_event_dedup' 
AND table_schema = 'claims';

-- Step 2: Test the exact SQL from PersistService
DO $$
DECLARE
    test_result BIGINT;
BEGIN
    -- Test the exact SQL statement from PersistService
    WITH ins AS (
      INSERT INTO claims.claim_event(
        claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
      )
      VALUES (999999, 999999, '2024-01-01 00:00:00+00', 1, 999999, NULL)
      ON CONFLICT ON CONSTRAINT uq_claim_event_dedup DO UPDATE
        SET ingestion_file_id = EXCLUDED.ingestion_file_id
      RETURNING id
    )
    SELECT id INTO test_result FROM ins
    UNION ALL
    SELECT id
      FROM claims.claim_event
     WHERE claim_key_id = 999999 AND type = 1 AND event_time = '2024-01-01 00:00:00+00'
    LIMIT 1;
    
    RAISE NOTICE 'SUCCESS: Constraint uq_claim_event_dedup is working! Test result: %', test_result;
    
    -- Clean up test data
    DELETE FROM claims.claim_event WHERE claim_key_id = 999999;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR: Constraint test failed: %', SQLERRM;
END $$;
