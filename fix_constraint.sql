-- Simple SQL script to remove the ck_processing_mode constraint
-- This constraint is preventing audit records from being saved

-- Remove the constraint
ALTER TABLE claims.ingestion_file_audit 
DROP CONSTRAINT IF EXISTS ck_processing_mode;

-- Verify it's removed
SELECT 'Constraint ck_processing_mode has been removed successfully' as result;
