-- ==========================================================================================================
-- DATABASE FUNCTIONS AND PROCEDURES
-- ==========================================================================================================
-- 
-- Purpose: Create utility functions and procedures
-- Version: 1.0
-- Date: 2025-01-15
-- 
-- This script creates utility functions for:
-- - Audit timestamps
-- - Transaction date setting
-- - Data validation
-- - Performance optimization
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: AUDIT HELPER FUNCTIONS
-- ==========================================================================================================

-- Audit helper function for updated_at timestamps
CREATE OR REPLACE FUNCTION claims.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW IS DISTINCT FROM OLD THEN
    NEW.updated_at := NOW();
  END IF;
  RETURN NEW;
END$$;

-- ==========================================================================================================
-- SECTION 2: TRANSACTION DATE SETTING FUNCTIONS
-- ==========================================================================================================

-- Function to set submission tx_at from ingestion_file.transaction_date
CREATE OR REPLACE FUNCTION claims.set_submission_tx_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tx_at IS NULL THEN
    SELECT i.transaction_date INTO NEW.tx_at
    FROM claims.ingestion_file i
    WHERE i.id = NEW.ingestion_file_id;
  END IF;
  RETURN NEW;
END$$;

-- Function to set remittance tx_at from ingestion_file.transaction_date
CREATE OR REPLACE FUNCTION claims.set_remittance_tx_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tx_at IS NULL THEN
    SELECT i.transaction_date INTO NEW.tx_at
    FROM claims.ingestion_file i
    WHERE i.id = NEW.ingestion_file_id;
  END IF;
  RETURN NEW;
END$$;

-- Function to set claim tx_at from submission.tx_at
CREATE OR REPLACE FUNCTION claims.set_claim_tx_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tx_at IS NULL THEN
    SELECT s.tx_at INTO NEW.tx_at
    FROM claims.submission s
    WHERE s.id = NEW.submission_id;
  END IF;
  RETURN NEW;
END$$;

-- Function to set claim_event_activity tx_at from related claim_event.event_time
CREATE OR REPLACE FUNCTION claims.set_claim_event_activity_tx_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tx_at IS NULL THEN
    SELECT ce.event_time INTO NEW.tx_at
    FROM claims.claim_event ce
    WHERE ce.id = NEW.claim_event_id;
  END IF;
  RETURN NEW;
END$$;

-- Function to set event_observation tx_at from related claim_event_activity.tx_at
CREATE OR REPLACE FUNCTION claims.set_event_observation_tx_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tx_at IS NULL THEN
    SELECT cea.tx_at INTO NEW.tx_at
    FROM claims.claim_event_activity cea
    WHERE cea.id = NEW.claim_event_activity_id;
  END IF;
  RETURN NEW;
END$$;

-- ==========================================================================================================
-- SECTION 3: TRIGGERS FOR AUTOMATIC TIMESTAMP SETTING
-- ==========================================================================================================

-- Trigger for submission tx_at
DROP TRIGGER IF EXISTS trigger_set_submission_tx_at ON claims.submission;
CREATE TRIGGER trigger_set_submission_tx_at
  BEFORE INSERT ON claims.submission
  FOR EACH ROW
  EXECUTE FUNCTION claims.set_submission_tx_at();

-- Trigger for remittance tx_at
DROP TRIGGER IF EXISTS trigger_set_remittance_tx_at ON claims.remittance;
CREATE TRIGGER trigger_set_remittance_tx_at
  BEFORE INSERT ON claims.remittance
  FOR EACH ROW
  EXECUTE FUNCTION claims.set_remittance_tx_at();

-- Trigger for claim tx_at
DROP TRIGGER IF EXISTS trigger_set_claim_tx_at ON claims.claim;
CREATE TRIGGER trigger_set_claim_tx_at
  BEFORE INSERT ON claims.claim
  FOR EACH ROW
  EXECUTE FUNCTION claims.set_claim_tx_at();

-- Trigger for claim_event_activity tx_at
DROP TRIGGER IF EXISTS trigger_set_claim_event_activity_tx_at ON claims.claim_event_activity;
CREATE TRIGGER trigger_set_claim_event_activity_tx_at
  BEFORE INSERT ON claims.claim_event_activity
  FOR EACH ROW
  EXECUTE FUNCTION claims.set_claim_event_activity_tx_at();

-- Trigger for event_observation tx_at
DROP TRIGGER IF EXISTS trigger_set_event_observation_tx_at ON claims.event_observation;
CREATE TRIGGER trigger_set_event_observation_tx_at
  BEFORE INSERT ON claims.event_observation
  FOR EACH ROW
  EXECUTE FUNCTION claims.set_event_observation_tx_at();

-- ==========================================================================================================
-- SECTION 4: UTILITY FUNCTIONS
-- ==========================================================================================================

-- Function to refresh all materialized views
CREATE OR REPLACE FUNCTION claims.refresh_all_materialized_views()
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
  mv_record RECORD;
  result_text TEXT := '';
BEGIN
  FOR mv_record IN 
    SELECT schemaname, matviewname 
    FROM pg_matviews 
    WHERE schemaname = 'claims'
    ORDER BY matviewname
  LOOP
    BEGIN
      EXECUTE 'REFRESH MATERIALIZED VIEW CONCURRENTLY ' || mv_record.schemaname || '.' || mv_record.matviewname;
      result_text := result_text || 'Refreshed: ' || mv_record.matviewname || E'\n';
    EXCEPTION WHEN OTHERS THEN
      result_text := result_text || 'Failed: ' || mv_record.matviewname || ' - ' || SQLERRM || E'\n';
    END;
  END LOOP;
  
  RETURN result_text;
END$$;

-- Function to get database statistics
CREATE OR REPLACE FUNCTION claims.get_database_stats()
RETURNS TABLE(
  table_name TEXT,
  row_count BIGINT,
  table_size TEXT
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.table_name::TEXT,
    COALESCE(c.reltuples::BIGINT, 0) as row_count,
    pg_size_pretty(pg_total_relation_size(c.oid)) as table_size
  FROM information_schema.tables t
  LEFT JOIN pg_class c ON c.relname = t.table_name
  WHERE t.table_schema = 'claims'
  ORDER BY pg_total_relation_size(c.oid) DESC NULLS LAST;
END$$;

-- ==========================================================================================================
-- SECTION 5: GRANTS TO CLAIMS_USER
-- ==========================================================================================================

-- Grant execute privileges on functions to claims_user
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA claims TO claims_user;
