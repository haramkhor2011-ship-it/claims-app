-- Add missing persisted_remit_activities column
ALTER TABLE claims.ingestion_file_audit 
ADD COLUMN IF NOT EXISTS persisted_remit_activities INTEGER DEFAULT 0;

-- Add performance and metadata columns
ALTER TABLE claims.ingestion_file_audit 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS verification_passed BOOLEAN,
ADD COLUMN IF NOT EXISTS processing_duration_ms BIGINT,
ADD COLUMN IF NOT EXISTS file_size_bytes BIGINT,
ADD COLUMN IF NOT EXISTS processing_mode TEXT,  -- 'disk' or 'mem'
ADD COLUMN IF NOT EXISTS worker_thread_name TEXT;

-- Add business data aggregates (optional - for advanced metrics)
ALTER TABLE claims.ingestion_file_audit 
ADD COLUMN IF NOT EXISTS total_gross_amount NUMERIC(15,2),
ADD COLUMN IF NOT EXISTS total_net_amount NUMERIC(15,2),
ADD COLUMN IF NOT EXISTS total_patient_share NUMERIC(15,2),
ADD COLUMN IF NOT EXISTS unique_payers INTEGER,
ADD COLUMN IF NOT EXISTS unique_providers INTEGER;

-- Add helpful comments
COMMENT ON COLUMN claims.ingestion_file_audit.persisted_remit_activities IS 'Count of successfully persisted remittance activities';
COMMENT ON COLUMN claims.ingestion_file_audit.processing_duration_ms IS 'Total processing time in milliseconds';
COMMENT ON COLUMN claims.ingestion_file_audit.verification_passed IS 'True if post-persistence verification succeeded';

-- Create indexes for performance queries
CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_duration 
ON claims.ingestion_file_audit(processing_duration_ms) 
WHERE processing_duration_ms IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_verification 
ON claims.ingestion_file_audit(verification_passed) 
WHERE verification_passed IS NOT NULL;
