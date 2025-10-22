-- Test the constraint and SQL statement
-- This will help identify the exact issue

-- First, check if the constraint exists
SELECT constraint_name, constraint_type, table_name 
FROM information_schema.table_constraints 
WHERE constraint_name = 'uq_claim_event_dedup' 
AND table_schema = 'claims';

-- Test the exact SQL statement that's failing
WITH ins AS (
  INSERT INTO claims.claim_event(
    claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
  )
  VALUES (1, 1, '2024-01-01 00:00:00+00', 1, 1, NULL)
  ON CONFLICT ON CONSTRAINT uq_claim_event_dedup DO UPDATE
    SET ingestion_file_id = EXCLUDED.ingestion_file_id
  RETURNING id
)
SELECT id FROM ins
UNION ALL
SELECT id
  FROM claims.claim_event
 WHERE claim_key_id = 1 AND type = 1 AND event_time = '2024-01-01 00:00:00+00'
LIMIT 1;
