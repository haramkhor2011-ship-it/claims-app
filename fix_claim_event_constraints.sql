-- ==========================================================================================================
-- FIX CLAIM_EVENT CONSTRAINTS AND INDEXES
-- ==========================================================================================================
-- 
-- Purpose: Convert unique indexes to constraints and add missing indexes
-- Issue: Hibernate/JPA expects constraints, not just unique indexes
--
-- ==========================================================================================================

-- 1. Add missing indexes
CREATE INDEX IF NOT EXISTS idx_claim_event_type ON claims.claim_event(type);
CREATE INDEX IF NOT EXISTS idx_claim_event_file ON claims.claim_event(ingestion_file_id);

-- 2. Add missing performance indexes
CREATE INDEX IF NOT EXISTS idx_balance_amount_base_enhanced_resubmission ON claims.claim_event(claim_key_id, type, event_time) WHERE type = 2;
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_claim_event_type ON claims.claim_event(claim_key_id, type);

-- 3. Convert unique indexes to constraints (for Hibernate/JPA compatibility)
-- First, drop the existing unique indexes
DROP INDEX IF EXISTS claims.uq_claim_event_dedup;
DROP INDEX IF EXISTS claims.uq_claim_event_one_submission;

-- Then add them as constraints
ALTER TABLE claims.claim_event ADD CONSTRAINT uq_claim_event_dedup UNIQUE (claim_key_id, type, event_time);
-- Note: Partial unique constraints (with WHERE clause) must remain as unique indexes
CREATE UNIQUE INDEX IF NOT EXISTS uq_claim_event_one_submission ON claims.claim_event(claim_key_id) WHERE type = 1;

-- 4. Verify the changes
SELECT 'CONSTRAINTS AFTER FIX:' as info;
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'claims.claim_event'::regclass 
ORDER BY conname;

SELECT 'INDEXES AFTER FIX:' as info;
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'claim_event' 
AND schemaname = 'claims' 
ORDER BY indexname;

SELECT 'Fix completed successfully!' as completion_message;
