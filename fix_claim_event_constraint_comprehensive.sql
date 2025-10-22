-- Comprehensive fix for claim_event constraint issue
-- This script will check and fix the missing constraint that's causing claim persistence failures

-- Step 1: Check if the constraint exists
DO $$
DECLARE
    constraint_exists BOOLEAN;
BEGIN
    -- Check if the constraint exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'uq_claim_event_dedup' 
        AND table_name = 'claim_event' 
        AND table_schema = 'claims'
    ) INTO constraint_exists;
    
    IF NOT constraint_exists THEN
        RAISE NOTICE 'Constraint uq_claim_event_dedup does not exist. Creating it...';
        
        -- Add the missing constraint
        ALTER TABLE claims.claim_event 
        ADD CONSTRAINT uq_claim_event_dedup 
        UNIQUE (claim_key_id, type, event_time);
        
        RAISE NOTICE 'Successfully created constraint uq_claim_event_dedup';
    ELSE
        RAISE NOTICE 'Constraint uq_claim_event_dedup already exists';
    END IF;
END $$;

-- Step 2: Verify the constraint exists
SELECT 
    constraint_name, 
    constraint_type, 
    table_name,
    table_schema
FROM information_schema.table_constraints 
WHERE constraint_name = 'uq_claim_event_dedup' 
AND table_schema = 'claims';

-- Step 3: Test the SQL statement that was failing
-- This will help verify that the constraint works properly
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
    
    RAISE NOTICE 'Test SQL executed successfully. Result: %', test_result;
    
    -- Clean up test data
    DELETE FROM claims.claim_event WHERE claim_key_id = 999999;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Test SQL failed: %', SQLERRM;
END $$;
