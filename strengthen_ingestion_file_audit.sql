-- =====================================================================================
-- STRENGTHEN INGESTION_FILE_AUDIT TABLE - CRITICAL FIXES
-- =====================================================================================
-- This script adds missing core fields to strengthen the ingestion_file_audit table
-- without breaking existing functionality

-- =====================================================================================
-- 1. ADD MISSING CORE FIELDS
-- =====================================================================================

-- Add processing timing fields
ALTER TABLE claims.ingestion_file_audit 
  ADD COLUMN IF NOT EXISTS processing_started_at        TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS processing_ended_at          TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS processing_duration_ms       INTEGER;

-- Add file and processing context fields
ALTER TABLE claims.ingestion_file_audit 
  ADD COLUMN IF NOT EXISTS file_size_bytes              BIGINT,
  ADD COLUMN IF NOT EXISTS processing_mode              TEXT, -- 'MEM' or 'DISK'
  ADD COLUMN IF NOT EXISTS worker_thread_name           TEXT,
  ADD COLUMN IF NOT EXISTS retry_count                  INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS source_file_path             TEXT;

-- Add missing audit fields that exist in DDL but not populated
ALTER TABLE claims.ingestion_file_audit 
  ADD COLUMN IF NOT EXISTS verification_passed          BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS ack_attempted                BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS ack_sent                     BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS verification_failed_count    INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS projected_events             INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS projected_status_rows        INTEGER DEFAULT 0;

-- Add retry tracking fields
ALTER TABLE claims.ingestion_file_audit 
  ADD COLUMN IF NOT EXISTS retry_reasons                TEXT[], -- Array of retry reasons
  ADD COLUMN IF NOT EXISTS retry_error_codes            TEXT[], -- Array of error codes that caused retries
  ADD COLUMN IF NOT EXISTS first_attempt_at             TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_attempt_at              TIMESTAMPTZ;

-- Add business metrics fields
ALTER TABLE claims.ingestion_file_audit 
  ADD COLUMN IF NOT EXISTS total_gross_amount           NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_net_amount             NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_patient_share          NUMERIC(15,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS unique_payers                INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS unique_providers             INTEGER DEFAULT 0;

-- =====================================================================================
-- 2. ADD CONSTRAINTS FOR DATA QUALITY
-- =====================================================================================

-- Add constraints to ensure data quality
ALTER TABLE claims.ingestion_file_audit ADD CONSTRAINT
  ck_processing_duration CHECK (processing_duration_ms >= 0);

ALTER TABLE claims.ingestion_file_audit ADD CONSTRAINT 
  ck_file_size CHECK (file_size_bytes >= 0);

ALTER TABLE claims.ingestion_file_audit ADD CONSTRAINT 
  ck_retry_count CHECK (retry_count >= 0);

ALTER TABLE claims.ingestion_file_audit ADD CONSTRAINT 
  ck_processing_mode CHECK (processing_mode IN ('MEM', 'DISK'));

-- =====================================================================================
-- 3. ADD MISSING INDEXES FOR PERFORMANCE
-- =====================================================================================

-- Add indexes for frequently queried fields
CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_processing_time 
ON claims.ingestion_file_audit(processing_started_at);

CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_duration 
ON claims.ingestion_file_audit(processing_duration_ms);

CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_file_size 
ON claims.ingestion_file_audit(file_size_bytes);

CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_status_created 
ON claims.ingestion_file_audit(status, created_at);

CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_verification 
ON claims.ingestion_file_audit(verification_passed, validation_ok);

CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_retry_count 
ON claims.ingestion_file_audit(retry_count);

CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_processing_mode 
ON claims.ingestion_file_audit(processing_mode);

-- =====================================================================================
-- 4. ADD COMMENTS FOR DOCUMENTATION
-- =====================================================================================

COMMENT ON COLUMN claims.ingestion_file_audit.processing_started_at IS 'When file processing started';
COMMENT ON COLUMN claims.ingestion_file_audit.processing_ended_at IS 'When file processing ended';
COMMENT ON COLUMN claims.ingestion_file_audit.processing_duration_ms IS 'Total processing time in milliseconds';
COMMENT ON COLUMN claims.ingestion_file_audit.file_size_bytes IS 'Size of the XML file in bytes';
COMMENT ON COLUMN claims.ingestion_file_audit.processing_mode IS 'Processing mode: MEM (in-memory) or DISK (staged to disk)';
COMMENT ON COLUMN claims.ingestion_file_audit.worker_thread_name IS 'Name of the worker thread that processed this file';
COMMENT ON COLUMN claims.ingestion_file_audit.retry_count IS 'Number of times this file was retried due to errors';
COMMENT ON COLUMN claims.ingestion_file_audit.source_file_path IS 'Path to the source file (for disk-staged files)';
COMMENT ON COLUMN claims.ingestion_file_audit.verification_passed IS 'Whether post-processing verification passed';
COMMENT ON COLUMN claims.ingestion_file_audit.ack_attempted IS 'Whether acknowledgment was attempted';
COMMENT ON COLUMN claims.ingestion_file_audit.ack_sent IS 'Whether acknowledgment was successfully sent';
COMMENT ON COLUMN claims.ingestion_file_audit.verification_failed_count IS 'Number of verification rules that failed';
COMMENT ON COLUMN claims.ingestion_file_audit.projected_events IS 'Number of events projected for this file';
COMMENT ON COLUMN claims.ingestion_file_audit.projected_status_rows IS 'Number of status timeline rows created';
COMMENT ON COLUMN claims.ingestion_file_audit.retry_reasons IS 'Array of reasons why this file was retried';
COMMENT ON COLUMN claims.ingestion_file_audit.retry_error_codes IS 'Array of error codes that caused retries';
COMMENT ON COLUMN claims.ingestion_file_audit.first_attempt_at IS 'When the first processing attempt started';
COMMENT ON COLUMN claims.ingestion_file_audit.last_attempt_at IS 'When the last processing attempt started';
COMMENT ON COLUMN claims.ingestion_file_audit.total_gross_amount IS 'Total gross amount from all claims in this file';
COMMENT ON COLUMN claims.ingestion_file_audit.total_net_amount IS 'Total net amount from all claims in this file';
COMMENT ON COLUMN claims.ingestion_file_audit.total_patient_share IS 'Total patient share from all claims in this file';
COMMENT ON COLUMN claims.ingestion_file_audit.unique_payers IS 'Number of unique payers in this file';
COMMENT ON COLUMN claims.ingestion_file_audit.unique_providers IS 'Number of unique providers in this file';

-- =====================================================================================
-- 5. VALIDATION QUERIES
-- =====================================================================================

-- Check if all new fields were added successfully
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_schema = 'claims' 
  AND table_name = 'ingestion_file_audit'
  AND column_name IN (
    'processing_started_at', 'processing_ended_at', 'processing_duration_ms',
    'file_size_bytes', 'processing_mode', 'worker_thread_name', 'retry_count',
    'source_file_path', 'verification_passed', 'ack_attempted', 'ack_sent',
    'verification_failed_count', 'projected_events', 'projected_status_rows',
    'retry_reasons', 'retry_error_codes', 'first_attempt_at', 'last_attempt_at',
    'total_gross_amount', 'total_net_amount', 'total_patient_share',
    'unique_payers', 'unique_providers'
  )
ORDER BY column_name;

-- Check if all indexes were created successfully
SELECT 
    indexname, 
    indexdef
FROM pg_indexes 
WHERE schemaname = 'claims' 
  AND tablename = 'ingestion_file_audit'
  AND indexname LIKE 'idx_ingestion_file_audit_%'
ORDER BY indexname;

-- =====================================================================================
-- 6. ROLLBACK SCRIPT (if needed)
-- =====================================================================================

/*
-- To rollback these changes, run:
DROP INDEX IF EXISTS claims.idx_ingestion_file_audit_processing_time;
DROP INDEX IF EXISTS claims.idx_ingestion_file_audit_duration;
DROP INDEX IF EXISTS claims.idx_ingestion_file_audit_file_size;
DROP INDEX IF EXISTS claims.idx_ingestion_file_audit_status_created;
DROP INDEX IF EXISTS claims.idx_ingestion_file_audit_verification;
DROP INDEX IF EXISTS claims.idx_ingestion_file_audit_retry_count;
DROP INDEX IF EXISTS claims.idx_ingestion_file_audit_processing_mode;

ALTER TABLE claims.ingestion_file_audit DROP CONSTRAINT IF EXISTS ck_processing_duration;
ALTER TABLE claims.ingestion_file_audit DROP CONSTRAINT IF EXISTS ck_file_size;
ALTER TABLE claims.ingestion_file_audit DROP CONSTRAINT IF EXISTS ck_retry_count;
ALTER TABLE claims.ingestion_file_audit DROP CONSTRAINT IF EXISTS ck_processing_mode;

ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS processing_started_at;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS processing_ended_at;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS processing_duration_ms;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS file_size_bytes;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS processing_mode;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS worker_thread_name;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS retry_count;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS source_file_path;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS verification_passed;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS ack_attempted;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS ack_sent;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS verification_failed_count;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS projected_events;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS projected_status_rows;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS retry_reasons;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS retry_error_codes;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS first_attempt_at;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS last_attempt_at;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS total_gross_amount;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS total_net_amount;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS total_patient_share;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS unique_payers;
ALTER TABLE claims.ingestion_file_audit DROP COLUMN IF EXISTS unique_providers;
*/
