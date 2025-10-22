-- Robust fix for claim_event constraint issue
-- This handles the naming conflict and creates the constraint properly

-- Step 1: Drop any existing constraint with similar name
DO $$
DECLARE
    constraint_name TEXT;
BEGIN
    -- Find any existing constraint that might conflict
    SELECT conname INTO constraint_name
    FROM pg_constraint 
    WHERE conrelid = 'claims.claim_event'::regclass
    AND conname LIKE '%dedup%';
    
    IF constraint_name IS NOT NULL THEN
        RAISE NOTICE 'Found existing constraint: %. Dropping it...', constraint_name;
        EXECUTE 'ALTER TABLE claims.claim_event DROP CONSTRAINT IF EXISTS ' || constraint_name;
    END IF;
END $$;

-- Step 2: Drop any existing unique index that might conflict
DO $$
DECLARE
    index_name TEXT;
BEGIN
    -- Find any existing unique index that might conflict
    SELECT indexname INTO index_name
    FROM pg_indexes 
    WHERE tablename = 'claim_event' 
    AND schemaname = 'claims'
    AND indexdef LIKE '%UNIQUE%'
    AND indexdef LIKE '%claim_key_id%'
    AND indexdef LIKE '%type%'
    AND indexdef LIKE '%event_time%';
    
    IF index_name IS NOT NULL THEN
        RAISE NOTICE 'Found existing unique index: %. Dropping it...', index_name;
        EXECUTE 'DROP INDEX IF EXISTS claims.' || index_name;
    END IF;
END $$;

-- Step 3: Create the constraint with a unique name
ALTER TABLE claims.claim_event 
ADD CONSTRAINT uq_claim_event_dedup_new 
UNIQUE (claim_key_id, type, event_time);

-- Step 4: Verify the constraint exists
SELECT 
    constraint_name, 
    constraint_type, 
    table_name,
    table_schema
FROM information_schema.table_constraints 
WHERE constraint_name = 'uq_claim_event_dedup_new' 
AND table_schema = 'claims';

-- Step 5: Test the SQL statement with the new constraint name
DO $$
DECLARE
    test_result BIGINT;
BEGIN
    -- Test the exact SQL statement from PersistService (with new constraint name)
    WITH ins AS (
      INSERT INTO claims.claim_event(
        claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
      )
      VALUES (999999, 999999, '2024-01-01 00:00:00+00', 1, 999999, NULL)
      ON CONFLICT ON CONSTRAINT uq_claim_event_dedup_new DO UPDATE
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
