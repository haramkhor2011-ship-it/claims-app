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

-- NOTE: Application sets submission.tx_at directly now; trigger disabled
DROP TRIGGER IF EXISTS trigger_set_submission_tx_at ON claims.submission;

-- NOTE: Application sets remittance.tx_at directly now; trigger disabled
DROP TRIGGER IF EXISTS trigger_set_remittance_tx_at ON claims.remittance;

-- NOTE: Application sets claim.tx_at directly now; trigger disabled
DROP TRIGGER IF EXISTS trigger_set_claim_tx_at ON claims.claim;

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
-- SECTION 5: CLAIM PAYMENT FUNCTIONS AND TRIGGERS
-- ==========================================================================================================

-- Function to recalculate payment metrics for a claim
CREATE OR REPLACE FUNCTION claims.recalculate_claim_payment(p_claim_key_id BIGINT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  v_metrics RECORD;
  v_payment_status VARCHAR(20);
BEGIN
  -- Calculate all financial metrics (SOURCE: pre-computed per-activity summary)
  -- Using cumulative-with-cap semantics from claims.claim_activity_summary
  SELECT 
    COALESCE(SUM(cas.submitted_amount), 0)                                 AS total_submitted_amount,
    COALESCE(SUM(cas.paid_amount), 0)                                      AS total_paid_amount,
    /* If business differentiates remitted vs paid later, adjust here */
    COALESCE(SUM(cas.submitted_amount), 0)                                 AS total_remitted_amount,
    COALESCE(SUM(cas.rejected_amount), 0)                                  AS total_rejected_amount,
    COALESCE(SUM(cas.denied_amount), 0)                                    AS total_denied_amount,
    COUNT(cas.activity_id)                                                 AS total_activities,
    COUNT(CASE WHEN cas.activity_status = 'FULLY_PAID' THEN 1 END)         AS paid_activities,
    COUNT(CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN 1 END)     AS partially_paid_activities,
    COUNT(CASE WHEN cas.activity_status = 'REJECTED' THEN 1 END)           AS rejected_activities,
    COUNT(CASE WHEN cas.activity_status = 'PENDING' THEN 1 END)            AS pending_activities,
    MAX(cas.remittance_count)                                              AS remittance_count,
    COUNT(DISTINCT CASE WHEN ce.type = 2 THEN ce.id END) as resubmission_count,
    MIN(DATE(c.tx_at)) as first_submission_date,
    MAX(DATE(c.tx_at)) as last_submission_date,
    MIN(DATE(rc.date_settlement)) as first_remittance_date,
    MAX(DATE(rc.date_settlement)) as last_remittance_date,
    MIN(DATE(rc.date_settlement)) FILTER (WHERE ra.payment_amount > 0) as first_payment_date,
    MAX(DATE(rc.date_settlement)) FILTER (WHERE ra.payment_amount > 0) as last_payment_date,
    MAX(DATE(rc.date_settlement)) as latest_settlement_date,
    CASE 
      WHEN MIN(DATE(c.tx_at)) IS NOT NULL AND MIN(DATE(rc.date_settlement)) FILTER (WHERE ra.payment_amount > 0) IS NOT NULL 
      THEN MIN(DATE(rc.date_settlement)) FILTER (WHERE ra.payment_amount > 0) - MIN(DATE(c.tx_at))
      ELSE NULL
    END as days_to_first_payment,
    CASE 
      WHEN MIN(DATE(c.tx_at)) IS NOT NULL AND MAX(DATE(rc.date_settlement)) IS NOT NULL 
      THEN MAX(DATE(rc.date_settlement)) - MIN(DATE(c.tx_at))
      ELSE NULL
    END as days_to_final_settlement,
    MAX(rc.payment_reference) as payment_reference,
    MAX(rc.payment_reference) as latest_payment_reference,
    MAX(c.tx_at) as tx_at
  INTO v_metrics
  FROM claims.claim_activity_summary cas
  LEFT JOIN claims.claim c ON c.claim_key_id = cas.claim_key_id
  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = cas.claim_key_id
  LEFT JOIN claims.claim_event ce ON ce.claim_key_id = cas.claim_key_id
  WHERE cas.claim_key_id = p_claim_key_id;
  
  -- Calculate payment status
  v_payment_status := CASE 
    WHEN v_metrics.total_paid_amount = v_metrics.total_submitted_amount AND v_metrics.total_submitted_amount > 0 THEN 'FULLY_PAID'
    WHEN v_metrics.total_paid_amount > 0 THEN 'PARTIALLY_PAID'
    WHEN v_metrics.total_rejected_amount > 0 THEN 'REJECTED'
    ELSE 'PENDING'
  END;
  
  -- Upsert claim payment record
  INSERT INTO claims.claim_payment (
    claim_key_id, total_submitted_amount, total_paid_amount, total_remitted_amount, 
    total_rejected_amount, total_denied_amount, total_activities, paid_activities, 
    partially_paid_activities, rejected_activities, pending_activities, payment_status,
    remittance_count, resubmission_count, processing_cycles, first_submission_date, 
    last_submission_date, first_remittance_date, last_remittance_date, first_payment_date,
    last_payment_date, latest_settlement_date, days_to_first_payment, days_to_final_settlement,
    payment_reference, latest_payment_reference, tx_at, updated_at
  ) VALUES (
    p_claim_key_id, v_metrics.total_submitted_amount, v_metrics.total_paid_amount, v_metrics.total_remitted_amount,
    v_metrics.total_rejected_amount, v_metrics.total_denied_amount, v_metrics.total_activities, v_metrics.paid_activities,
    v_metrics.partially_paid_activities, v_metrics.rejected_activities, v_metrics.pending_activities, v_payment_status,
    v_metrics.remittance_count, v_metrics.resubmission_count, v_metrics.remittance_count + v_metrics.resubmission_count,
    v_metrics.first_submission_date, v_metrics.last_submission_date, v_metrics.first_remittance_date, v_metrics.last_remittance_date,
    v_metrics.first_payment_date, v_metrics.last_payment_date, v_metrics.latest_settlement_date, v_metrics.days_to_first_payment,
    v_metrics.days_to_final_settlement, v_metrics.payment_reference, v_metrics.latest_payment_reference, v_metrics.tx_at, NOW()
  )
  ON CONFLICT (claim_key_id) DO UPDATE SET
    total_submitted_amount = EXCLUDED.total_submitted_amount,
    total_paid_amount = EXCLUDED.total_paid_amount,
    total_remitted_amount = EXCLUDED.total_remitted_amount,
    total_rejected_amount = EXCLUDED.total_rejected_amount,
    total_denied_amount = EXCLUDED.total_denied_amount,
    total_activities = EXCLUDED.total_activities,
    paid_activities = EXCLUDED.paid_activities,
    partially_paid_activities = EXCLUDED.partially_paid_activities,
    rejected_activities = EXCLUDED.rejected_activities,
    pending_activities = EXCLUDED.pending_activities,
    payment_status = EXCLUDED.payment_status,
    remittance_count = EXCLUDED.remittance_count,
    resubmission_count = EXCLUDED.resubmission_count,
    processing_cycles = EXCLUDED.processing_cycles,
    first_submission_date = EXCLUDED.first_submission_date,
    last_submission_date = EXCLUDED.last_submission_date,
    first_remittance_date = EXCLUDED.first_remittance_date,
    last_remittance_date = EXCLUDED.last_remittance_date,
    first_payment_date = EXCLUDED.first_payment_date,
    last_payment_date = EXCLUDED.last_payment_date,
    latest_settlement_date = EXCLUDED.latest_settlement_date,
    days_to_first_payment = EXCLUDED.days_to_first_payment,
    days_to_final_settlement = EXCLUDED.days_to_final_settlement,
    payment_reference = EXCLUDED.payment_reference,
    latest_payment_reference = EXCLUDED.latest_payment_reference,
    tx_at = EXCLUDED.tx_at,
    updated_at = NOW();
END$$;

COMMENT ON FUNCTION claims.recalculate_claim_payment(BIGINT) IS 'Recalculates and updates payment metrics for a claim';

-- Trigger function for claim payment updates
CREATE OR REPLACE FUNCTION claims.update_claim_payment_on_remittance_claim()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_claim_key_id BIGINT;
BEGIN
  v_claim_key_id := COALESCE(NEW.claim_key_id, OLD.claim_key_id);
  PERFORM claims.recalculate_claim_payment(v_claim_key_id);
  RETURN COALESCE(NEW, OLD);
END$$;

COMMENT ON FUNCTION claims.update_claim_payment_on_remittance_claim() IS 'Trigger function to update claim payment when remittance_claim changes';

-- Trigger function for claim payment updates on remittance activity
CREATE OR REPLACE FUNCTION claims.update_claim_payment_on_remittance_activity()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_claim_key_id BIGINT;
BEGIN
  SELECT rc.claim_key_id INTO v_claim_key_id
  FROM claims.remittance_claim rc
  WHERE rc.id = COALESCE(NEW.remittance_claim_id, OLD.remittance_claim_id);
  
  IF v_claim_key_id IS NOT NULL THEN
    PERFORM claims.recalculate_claim_payment(v_claim_key_id);
  END IF;
  RETURN COALESCE(NEW, OLD);
END$$;

COMMENT ON FUNCTION claims.update_claim_payment_on_remittance_activity() IS 'Trigger function to update claim payment when remittance_activity changes';

-- Trigger function for activity summary updates
CREATE OR REPLACE FUNCTION claims.update_activity_summary_on_remittance_activity()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_claim_key_id BIGINT;
BEGIN
  SELECT rc.claim_key_id INTO v_claim_key_id
  FROM claims.remittance_claim rc
  WHERE rc.id = COALESCE(NEW.remittance_claim_id, OLD.remittance_claim_id);
  
  IF v_claim_key_id IS NOT NULL THEN
    PERFORM claims.recalculate_activity_summary(v_claim_key_id);
  END IF;
  RETURN COALESCE(NEW, OLD);
END$$;

COMMENT ON FUNCTION claims.update_activity_summary_on_remittance_activity() IS 'Trigger function to update activity summary when remittance_activity changes';

-- Function to recalculate activity summary for a claim
CREATE OR REPLACE FUNCTION claims.recalculate_activity_summary(p_claim_key_id BIGINT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  v_activity RECORD;
BEGIN
  -- Loop through all activities for the claim
  -- CUMULATIVE-WITH-CAP IMPLEMENTATION
  -- Rationale:
  --  - Sum all remittance payments per activity across cycles
  --  - Cap cumulative paid at the activity's submitted net (prevents overcounting)
  --  - Treat as REJECTED only if the latest remittance shows a denial AND capped paid = 0
  --  - Denied amount equals submitted net only in that latest-denied-and-zero-paid scenario
  FOR v_activity IN 
    SELECT 
      a.activity_id,
      a.net as submitted_amount,
      -- cumulative sum of payments across all remittances for this activity
      COALESCE(SUM(ra.payment_amount), 0)                                         AS cumulative_paid_raw,
      -- CAP at submitted net to avoid overcounting beyond amount billed
      LEAST(COALESCE(SUM(ra.payment_amount), 0), a.net)                           AS paid_amount,
      -- latest denial across remittances (order by settlement desc, then row id)
      (ARRAY_AGG(ra.denial_code ORDER BY rc.date_settlement DESC NULLS LAST, ra.id DESC))[1]
                                                                                   AS latest_denial_code,
      -- REJECTED when latest indicates denial and capped paid is zero
      CASE 
        WHEN (ARRAY_AGG(ra.denial_code ORDER BY rc.date_settlement DESC NULLS LAST, ra.id DESC))[1] IS NOT NULL
             AND LEAST(COALESCE(SUM(ra.payment_amount), 0), a.net) = 0 
        THEN a.net 
        ELSE 0 
      END                                                                           AS rejected_amount,
      -- DENIED amount mirrors rejected under latest-denial-and-zero-paid semantics
      CASE 
        WHEN (ARRAY_AGG(ra.denial_code ORDER BY rc.date_settlement DESC NULLS LAST, ra.id DESC))[1] IS NOT NULL
             AND LEAST(COALESCE(SUM(ra.payment_amount), 0), a.net) = 0 
        THEN a.net 
        ELSE 0 
      END                                                                           AS denied_amount,
      COUNT(DISTINCT rc.id)                                                         AS remittance_count,
      ARRAY_AGG(DISTINCT ra.denial_code ORDER BY ra.denial_code) FILTER (WHERE ra.denial_code IS NOT NULL)
                                                                                   AS denial_codes,
      MIN(DATE(rc.date_settlement))                                                AS first_payment_date,
      MAX(DATE(rc.date_settlement))                                                AS last_payment_date,
      CASE 
        WHEN MIN(DATE(c.tx_at)) IS NOT NULL AND MIN(DATE(rc.date_settlement)) IS NOT NULL 
        THEN MIN(DATE(rc.date_settlement)) - MIN(DATE(c.tx_at))
        ELSE NULL
      END                                                                           AS days_to_first_payment,
      MAX(c.tx_at)                                                                  AS tx_at
    FROM claims.claim c
    JOIN claims.activity a ON a.claim_id = c.id
    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = c.claim_key_id
    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id 
      AND ra.activity_id = a.activity_id
    WHERE c.claim_key_id = p_claim_key_id
    GROUP BY a.activity_id, a.net, c.tx_at
  LOOP
      -- Calculate activity status
      DECLARE
        v_activity_status VARCHAR(20);
      BEGIN
        -- Status from capped paid and latest-denial semantics
        v_activity_status := CASE 
          WHEN v_activity.paid_amount = v_activity.submitted_amount AND v_activity.submitted_amount > 0 THEN 'FULLY_PAID'
          WHEN v_activity.paid_amount > 0 THEN 'PARTIALLY_PAID'
          WHEN v_activity.rejected_amount > 0 THEN 'REJECTED'
          ELSE 'PENDING'
        END;
      
      -- Upsert activity summary record
      INSERT INTO claims.claim_activity_summary (
        claim_key_id, activity_id, submitted_amount, paid_amount, rejected_amount, denied_amount,
        activity_status, remittance_count, denial_codes, first_payment_date, last_payment_date,
        days_to_first_payment, tx_at, updated_at
      ) VALUES (
        p_claim_key_id, v_activity.activity_id, v_activity.submitted_amount, v_activity.paid_amount,
        v_activity.rejected_amount, v_activity.denied_amount, v_activity_status, v_activity.remittance_count,
        v_activity.denial_codes, v_activity.first_payment_date, v_activity.last_payment_date,
        v_activity.days_to_first_payment, v_activity.tx_at, NOW()
      )
      ON CONFLICT (claim_key_id, activity_id) DO UPDATE SET
        submitted_amount = EXCLUDED.submitted_amount,
        paid_amount = EXCLUDED.paid_amount,
        rejected_amount = EXCLUDED.rejected_amount,
        denied_amount = EXCLUDED.denied_amount,
        activity_status = EXCLUDED.activity_status,
        remittance_count = EXCLUDED.remittance_count,
        denial_codes = EXCLUDED.denial_codes,
        first_payment_date = EXCLUDED.first_payment_date,
        last_payment_date = EXCLUDED.last_payment_date,
        days_to_first_payment = EXCLUDED.days_to_first_payment,
        tx_at = EXCLUDED.tx_at,
        updated_at = NOW();
    END;
  END LOOP;
END$$;

COMMENT ON FUNCTION claims.recalculate_activity_summary(BIGINT) IS 'Recalculates and updates activity summary for a claim';

-- ==========================================================================================================
-- SECTION 6: GRANTS TO CLAIMS_USER
-- ==========================================================================================================

-- Grant execute privileges on functions to claims_user
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA claims TO claims_user;
