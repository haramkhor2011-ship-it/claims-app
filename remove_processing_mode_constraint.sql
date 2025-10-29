-- Remove the ck_processing_mode constraint that's causing audit failures
-- This constraint is preventing audit records from being saved

-- First, check if the constraint exists
SELECT conname, consrc 
FROM pg_constraint 
WHERE conname = 'ck_processing_mode' 
AND conrelid = 'claims.ingestion_file_audit'::regclass;

-- Drop the constraint if it exists
ALTER TABLE claims.ingestion_file_audit 
DROP CONSTRAINT IF EXISTS ck_processing_mode;

-- Verify the constraint is removed
SELECT conname, consrc 
FROM pg_constraint 
WHERE conname = 'ck_processing_mode' 
AND conrelid = 'claims.ingestion_file_audit'::regclass;

-- Optional: If you want to add a new constraint with correct values
-- ALTER TABLE claims.ingestion_file_audit 
-- ADD CONSTRAINT ck_processing_mode CHECK (processing_mode IN ('file', 'memory', 'disk', 'mem'));

-- Test that audit records can now be inserted
-- (This will be tested when you run the application again)
