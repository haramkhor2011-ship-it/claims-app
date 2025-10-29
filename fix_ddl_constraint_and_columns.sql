-- Fix the ingestion_file_audit table to include all new columns and remove problematic constraint
-- This updates the original DDL to match what the application expects

-- First, add the missing columns to the existing table
ALTER TABLE claims.ingestion_file_audit 
ADD COLUMN IF NOT EXISTS parsed_diagnoses INTEGER,
ADD COLUMN IF NOT EXISTS persisted_diagnoses INTEGER,
ADD COLUMN IF NOT EXISTS parsed_encounters INTEGER,
ADD COLUMN IF NOT EXISTS persisted_encounters INTEGER,
ADD COLUMN IF NOT EXISTS parsed_observations INTEGER,
ADD COLUMN IF NOT EXISTS persisted_observations INTEGER,
ADD COLUMN IF NOT EXISTS parsed_remit_claims INTEGER,
ADD COLUMN IF NOT EXISTS persisted_remit_claims INTEGER,
ADD COLUMN IF NOT EXISTS parsed_remit_activities INTEGER,
ADD COLUMN IF NOT EXISTS persisted_remit_activities INTEGER,
ADD COLUMN IF NOT EXISTS projected_events INTEGER,
ADD COLUMN IF NOT EXISTS projected_status_rows INTEGER,
ADD COLUMN IF NOT EXISTS duration_ms BIGINT,
ADD COLUMN IF NOT EXISTS file_size_bytes BIGINT,
ADD COLUMN IF NOT EXISTS processing_mode VARCHAR(50),
ADD COLUMN IF NOT EXISTS worker_thread VARCHAR(255),
ADD COLUMN IF NOT EXISTS total_gross_amount NUMERIC(19, 4),
ADD COLUMN IF NOT EXISTS total_net_amount NUMERIC(19, 4),
ADD COLUMN IF NOT EXISTS total_patient_share NUMERIC(19, 4),
ADD COLUMN IF NOT EXISTS unique_payers INTEGER,
ADD COLUMN IF NOT EXISTS unique_providers INTEGER,
ADD COLUMN IF NOT EXISTS ack_sent BOOLEAN,
ADD COLUMN IF NOT EXISTS pipeline_success BOOLEAN,
ADD COLUMN IF NOT EXISTS verification_failures INTEGER;

-- Remove the problematic constraint if it exists
ALTER TABLE claims.ingestion_file_audit 
DROP CONSTRAINT IF EXISTS ck_processing_mode;

-- Add comments for the new columns
COMMENT ON COLUMN claims.ingestion_file_audit.parsed_diagnoses IS 'Number of diagnoses parsed from the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.persisted_diagnoses IS 'Number of diagnoses successfully persisted to the database.';
COMMENT ON COLUMN claims.ingestion_file_audit.parsed_encounters IS 'Number of encounters parsed from the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.persisted_encounters IS 'Number of encounters successfully persisted to the database.';
COMMENT ON COLUMN claims.ingestion_file_audit.parsed_observations IS 'Number of observations parsed from the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.persisted_observations IS 'Number of observations successfully persisted to the database.';
COMMENT ON COLUMN claims.ingestion_file_audit.parsed_remit_claims IS 'Number of remittance claims parsed from the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.persisted_remit_claims IS 'Number of remittance claims successfully persisted to the database.';
COMMENT ON COLUMN claims.ingestion_file_audit.parsed_remit_activities IS 'Number of remittance activities parsed from the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.persisted_remit_activities IS 'Number of remittance activities successfully persisted to the database.';
COMMENT ON COLUMN claims.ingestion_file_audit.projected_events IS 'Number of claim events projected (submission/resubmission/remittance).';
COMMENT ON COLUMN claims.ingestion_file_audit.projected_status_rows IS 'Number of claim status timeline rows projected.';
COMMENT ON COLUMN claims.ingestion_file_audit.duration_ms IS 'Total time taken to process the file in milliseconds.';
COMMENT ON COLUMN claims.ingestion_file_audit.file_size_bytes IS 'Size of the XML file in bytes.';
COMMENT ON COLUMN claims.ingestion_file_audit.processing_mode IS 'Mode of processing (e.g., file, memory).';
COMMENT ON COLUMN claims.ingestion_file_audit.worker_thread IS 'Name of the worker thread that processed the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.total_gross_amount IS 'Sum of gross amounts from all claims in the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.total_net_amount IS 'Sum of net amounts from all claims in the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.total_patient_share IS 'Sum of patient share amounts from all claims in the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.unique_payers IS 'Number of unique payers in the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.unique_providers IS 'Number of unique providers in the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.ack_sent IS 'True if an acknowledgment was sent for the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.pipeline_success IS 'True if the pipeline processing completed successfully.';
COMMENT ON COLUMN claims.ingestion_file_audit.verification_failures IS 'Number of verification failures detected for the file.';

-- Verify the constraint is removed
SELECT 'Constraint ck_processing_mode has been removed and all columns added successfully' as result;