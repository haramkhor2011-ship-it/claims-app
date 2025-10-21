-- ==========================================================================================================
-- CLAIM PAYMENT FUNCTIONS AND TRIGGERS
-- ==========================================================================================================
-- 
-- Purpose: Functions and triggers for claim_payment table population and maintenance
-- Version: 1.0
-- Date: 2025-01-03
-- 
-- This file contains:
-- - Recalculation function for claim payment metrics
-- - Trigger functions for real-time updates
-- - Triggers on remittance tables for automatic updates
--
-- ==========================================================================================================

-- Function to recalculate payment metrics for a claim
CREATE OR REPLACE FUNCTION claims.recalculate_claim_payment(p_claim_key_id BIGINT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  v_metrics RECORD;
  v_payment_status VARCHAR(20);
  v_payment_references TEXT[];
  v_first_submission_date DATE;
  v_last_submission_date DATE;
  v_first_remittance_date DATE;
  v_last_remittance_date DATE;
  v_first_payment_date DATE;
  v_last_payment_date DATE;
  v_latest_settlement_date DATE;
  v_days_to_first_payment INTEGER;
  v_days_to_final_settlement INTEGER;
  v_processing_cycles INTEGER;
  v_resubmission_count INTEGER;
  v_latest_payment_reference VARCHAR(100);
  v_tx_at TIMESTAMPTZ;
BEGIN
  -- Calculate all financial metrics (SOURCE: pre-computed per-activity summary)
  -- Using cumulative-with-cap semantics from claims.claim_activity_summary
  SELECT 
    COALESCE(SUM(cas.submitted_amount), 0)                                 AS total_submitted,
    COALESCE(SUM(cas.paid_amount), 0)                                      AS total_paid,
    /* If business differentiates remitted vs paid later, adjust here */
    COALESCE(SUM(cas.submitted_amount), 0)                                 AS total_remitted,
    COALESCE(SUM(cas.rejected_amount), 0)                                  AS total_rejected,
    COALESCE(SUM(cas.denied_amount), 0)                                    AS total_denied,
    COUNT(cas.activity_id)                                                 AS total_activities,
    COUNT(CASE WHEN cas.activity_status = 'FULLY_PAID' THEN 1 END)         AS paid_activities,
    COUNT(CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN 1 END)     AS partially_paid_activities,
    COUNT(CASE WHEN cas.activity_status = 'REJECTED' THEN 1 END)           AS rejected_activities,
    COUNT(CASE WHEN cas.activity_status = 'PENDING' THEN 1 END)            AS pending_activities,
    MAX(cas.remittance_count)                                              AS remittance_count
  INTO v_metrics
  FROM claims.claim_activity_summary cas
  WHERE cas.claim_key_id = p_claim_key_id;
  
  -- Calculate payment status
  v_payment_status := CASE 
    WHEN v_metrics.total_paid = v_metrics.total_submitted AND v_metrics.total_submitted > 0 THEN 'FULLY_PAID'
    WHEN v_metrics.total_paid > 0 THEN 'PARTIALLY_PAID'
    WHEN v_metrics.total_rejected > 0 THEN 'REJECTED'
    ELSE 'PENDING'
  END;
  
  -- Get payment references
  SELECT ARRAY_AGG(DISTINCT rc.payment_reference ORDER BY rc.payment_reference)
  INTO v_payment_references
  FROM claims.remittance_claim rc
  WHERE rc.claim_key_id = p_claim_key_id
    AND rc.payment_reference IS NOT NULL;
  
  -- Get latest payment reference
  SELECT payment_reference
  INTO v_latest_payment_reference
  FROM claims.remittance_claim rc
  WHERE rc.claim_key_id = p_claim_key_id
  ORDER BY rc.date_settlement DESC NULLS LAST
  LIMIT 1;
  
  -- Get submission dates
  SELECT 
    MIN(DATE(c.tx_at)) as first_submission,
    MAX(DATE(c.tx_at)) as last_submission
  INTO v_first_submission_date, v_last_submission_date
  FROM claims.claim c
  WHERE c.claim_key_id = p_claim_key_id;
  
  -- Get remittance and payment dates
  SELECT 
    MIN(DATE(r.tx_at)) as first_remittance,
    MAX(DATE(r.tx_at)) as last_remittance,
    MIN(DATE(rc.date_settlement)) as first_payment,
    MAX(DATE(rc.date_settlement)) as last_payment,
    MAX(DATE(rc.date_settlement)) as latest_settlement
  INTO v_first_remittance_date, v_last_remittance_date, 
       v_first_payment_date, v_last_payment_date, v_latest_settlement_date
  FROM claims.remittance_claim rc
  JOIN claims.remittance r ON r.id = rc.remittance_id
  WHERE rc.claim_key_id = p_claim_key_id;
  
  -- Calculate processing cycles and resubmissions
  SELECT 
    COUNT(DISTINCT ce.id) as processing_cycles,
    COUNT(DISTINCT CASE WHEN ce.type = 2 THEN ce.id END) as resubmissions
  INTO v_processing_cycles, v_resubmission_count
  FROM claims.claim_event ce
  WHERE ce.claim_key_id = p_claim_key_id;
  
  -- Calculate days to payment
  v_days_to_first_payment := CASE 
    WHEN v_first_submission_date IS NOT NULL AND v_first_payment_date IS NOT NULL 
    THEN v_first_payment_date - v_first_submission_date
    ELSE NULL
  END;
  
  v_days_to_final_settlement := CASE 
    WHEN v_first_submission_date IS NOT NULL AND v_latest_settlement_date IS NOT NULL 
    THEN v_latest_settlement_date - v_first_submission_date
    ELSE NULL
  END;
  
  -- Get transaction time with safe fallbacks:
  -- 1) submission header time (claims.claim.tx_at)
  -- 2) remittance header time (claims.remittance.tx_at)
  -- 3) latest settlement date from remittance_claim
  SELECT COALESCE(
           (
             SELECT MAX(c.tx_at)
               FROM claims.claim c
              WHERE c.claim_key_id = p_claim_key_id
           ),
           (
             SELECT MAX(r.tx_at)
               FROM claims.remittance r
               JOIN claims.remittance_claim rc
                 ON rc.remittance_id = r.id
              WHERE rc.claim_key_id = p_claim_key_id
           ),
           (
             SELECT MAX(rc.date_settlement)::timestamptz
               FROM claims.remittance_claim rc
              WHERE rc.claim_key_id = p_claim_key_id
           )
         )
  INTO v_tx_at;
  
  -- Upsert claim_payment record
  INSERT INTO claims.claim_payment (
    claim_key_id, 
    total_submitted_amount, 
    total_paid_amount, 
    total_remitted_amount,
    total_rejected_amount,
    total_denied_amount,
    total_activities,
    paid_activities,
    partially_paid_activities,
    rejected_activities,
    pending_activities,
    remittance_count,
    resubmission_count,
    payment_status,
    first_submission_date,
    last_submission_date,
    first_remittance_date,
    last_remittance_date,
    first_payment_date,
    last_payment_date,
    latest_settlement_date,
    days_to_first_payment,
    days_to_final_settlement,
    processing_cycles,
    latest_payment_reference,
    payment_references,
    tx_at,
    updated_at
  ) VALUES (
    p_claim_key_id,
    v_metrics.total_submitted,
    v_metrics.total_paid,
    v_metrics.total_remitted,
    v_metrics.total_rejected,
    v_metrics.total_denied,
    v_metrics.total_activities,
    v_metrics.paid_activities,
    v_metrics.partially_paid_activities,
    v_metrics.rejected_activities,
    v_metrics.pending_activities,
    v_metrics.remittance_count,
    v_resubmission_count,
    v_payment_status,
    v_first_submission_date,
    v_last_submission_date,
    v_first_remittance_date,
    v_last_remittance_date,
    v_first_payment_date,
    v_last_payment_date,
    v_latest_settlement_date,
    v_days_to_first_payment,
    v_days_to_final_settlement,
    v_processing_cycles,
    v_latest_payment_reference,
    v_payment_references,
    v_tx_at,
    NOW()
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
    remittance_count = EXCLUDED.remittance_count,
    resubmission_count = EXCLUDED.resubmission_count,
    payment_status = EXCLUDED.payment_status,
    first_submission_date = EXCLUDED.first_submission_date,
    last_submission_date = EXCLUDED.last_submission_date,
    first_remittance_date = EXCLUDED.first_remittance_date,
    last_remittance_date = EXCLUDED.last_remittance_date,
    first_payment_date = EXCLUDED.first_payment_date,
    last_payment_date = EXCLUDED.last_payment_date,
    latest_settlement_date = EXCLUDED.latest_settlement_date,
    days_to_first_payment = EXCLUDED.days_to_first_payment,
    days_to_final_settlement = EXCLUDED.days_to_final_settlement,
    processing_cycles = EXCLUDED.processing_cycles,
    latest_payment_reference = EXCLUDED.latest_payment_reference,
    payment_references = EXCLUDED.payment_references,
    tx_at = EXCLUDED.tx_at,
    updated_at = NOW();
END$$;

COMMENT ON FUNCTION claims.recalculate_claim_payment(BIGINT) IS 'Recalculates and updates all payment metrics for a claim';

-- Trigger function for real-time updates on remittance_claim changes
CREATE OR REPLACE FUNCTION claims.update_claim_payment_on_remittance()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Recalculate payment metrics for the affected claim
  PERFORM claims.recalculate_claim_payment(
    COALESCE(NEW.claim_key_id, OLD.claim_key_id)
  );
  RETURN COALESCE(NEW, OLD);
END$$;

COMMENT ON FUNCTION claims.update_claim_payment_on_remittance() IS 'Trigger function to update claim_payment when remittance_claim changes';

-- Trigger function for remittance activity changes
CREATE OR REPLACE FUNCTION claims.update_claim_payment_on_remittance_activity()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_claim_key_id BIGINT;
BEGIN
  -- Get claim_key_id from remittance_claim
  SELECT rc.claim_key_id INTO v_claim_key_id
  FROM claims.remittance_claim rc
  WHERE rc.id = COALESCE(NEW.remittance_claim_id, OLD.remittance_claim_id);
  
  -- Recalculate payment metrics for the affected claim
  PERFORM claims.recalculate_claim_payment(v_claim_key_id);
  RETURN COALESCE(NEW, OLD);
END$$;

COMMENT ON FUNCTION claims.update_claim_payment_on_remittance_activity() IS 'Trigger function to update claim_payment when remittance_activity changes';

-- Triggers on remittance tables for automatic updates
CREATE TRIGGER trg_update_claim_payment_remittance_claim
  AFTER INSERT OR UPDATE OR DELETE ON claims.remittance_claim
  FOR EACH ROW EXECUTE FUNCTION claims.update_claim_payment_on_remittance();

CREATE TRIGGER trg_update_claim_payment_remittance_activity
  AFTER INSERT OR UPDATE OR DELETE ON claims.remittance_activity
  FOR EACH ROW EXECUTE FUNCTION claims.update_claim_payment_on_remittance_activity();

-- Trigger on claim events (for resubmission tracking)
CREATE TRIGGER trg_update_claim_payment_claim_event
  AFTER INSERT OR UPDATE OR DELETE ON claims.claim_event
  FOR EACH ROW EXECUTE FUNCTION claims.update_claim_payment_on_remittance();

COMMENT ON TRIGGER trg_update_claim_payment_remittance_claim ON claims.remittance_claim IS 'Automatically updates claim_payment when remittance_claim changes';
COMMENT ON TRIGGER trg_update_claim_payment_remittance_activity ON claims.remittance_activity IS 'Automatically updates claim_payment when remittance_activity changes';
COMMENT ON TRIGGER trg_update_claim_payment_claim_event ON claims.claim_event IS 'Automatically updates claim_payment when claim_event changes';

-- ==========================================================================================================
-- UTILITY FUNCTIONS FOR CLAIM PAYMENT
-- ==========================================================================================================

-- Function to get payment status for a claim
CREATE OR REPLACE FUNCTION claims.get_claim_payment_status(p_claim_key_id BIGINT)
RETURNS VARCHAR(20) LANGUAGE plpgsql AS $$
DECLARE
  v_status VARCHAR(20);
BEGIN
  SELECT payment_status INTO v_status
  FROM claims.claim_payment
  WHERE claim_key_id = p_claim_key_id;
  
  RETURN COALESCE(v_status, 'PENDING');
END$$;

COMMENT ON FUNCTION claims.get_claim_payment_status(BIGINT) IS 'Returns the current payment status for a claim';

-- Function to get total paid amount for a claim
CREATE OR REPLACE FUNCTION claims.get_claim_total_paid(p_claim_key_id BIGINT)
RETURNS NUMERIC(15,2) LANGUAGE plpgsql AS $$
DECLARE
  v_amount NUMERIC(15,2);
BEGIN
  SELECT total_paid_amount INTO v_amount
  FROM claims.claim_payment
  WHERE claim_key_id = p_claim_key_id;
  
  RETURN COALESCE(v_amount, 0);
END$$;

COMMENT ON FUNCTION claims.get_claim_total_paid(BIGINT) IS 'Returns the total paid amount for a claim';

-- Function to check if claim is fully paid
CREATE OR REPLACE FUNCTION claims.is_claim_fully_paid(p_claim_key_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
  RETURN claims.get_claim_payment_status(p_claim_key_id) = 'FULLY_PAID';
END$$;

COMMENT ON FUNCTION claims.is_claim_fully_paid(BIGINT) IS 'Returns true if claim is fully paid';

-- ==========================================================================================================
-- BATCH RECALCULATION FUNCTIONS
-- ==========================================================================================================

-- Function to recalculate all claim payments (for maintenance)
CREATE OR REPLACE FUNCTION claims.recalculate_all_claim_payments()
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
  v_count INTEGER := 0;
  v_claim_key_id BIGINT;
BEGIN
  -- Loop through all claim keys and recalculate
  FOR v_claim_key_id IN 
    SELECT id FROM claims.claim_key
  LOOP
    PERFORM claims.recalculate_claim_payment(v_claim_key_id);
    v_count := v_count + 1;
    
    -- Log progress every 1000 claims
    IF v_count % 1000 = 0 THEN
      RAISE NOTICE 'Processed % claims', v_count;
    END IF;
  END LOOP;
  
  RETURN v_count;
END$$;

COMMENT ON FUNCTION claims.recalculate_all_claim_payments() IS 'Recalculates payment metrics for all claims - use for maintenance';

-- Function to recalculate claim payments for a date range
CREATE OR REPLACE FUNCTION claims.recalculate_claim_payments_by_date(p_start_date DATE, p_end_date DATE)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
  v_count INTEGER := 0;
  v_claim_key_id BIGINT;
BEGIN
  -- Loop through claim keys with transactions in the date range
  FOR v_claim_key_id IN 
    SELECT DISTINCT ck.id 
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
    WHERE DATE(c.tx_at) BETWEEN p_start_date AND p_end_date
  LOOP
    PERFORM claims.recalculate_claim_payment(v_claim_key_id);
    v_count := v_count + 1;
  END LOOP;
  
  RETURN v_count;
END$$;

COMMENT ON FUNCTION claims.recalculate_claim_payments_by_date(DATE, DATE) IS 'Recalculates payment metrics for claims in a date range';

-- ==========================================================================================================
-- VALIDATION FUNCTIONS
-- ==========================================================================================================

-- Function to validate claim payment data integrity
CREATE OR REPLACE FUNCTION claims.validate_claim_payment_integrity()
RETURNS TABLE(
  claim_key_id BIGINT,
  issue_type TEXT,
  issue_description TEXT
) LANGUAGE plpgsql AS $$
BEGIN
  -- Check for claims with payment data but no claim_payment record
  RETURN QUERY
  SELECT 
    ck.id as claim_key_id,
    'MISSING_PAYMENT_RECORD' as issue_type,
    'Claim has remittance data but no claim_payment record' as issue_description
  FROM claims.claim_key ck
  WHERE EXISTS (
    SELECT 1 FROM claims.remittance_claim rc WHERE rc.claim_key_id = ck.id
  )
  AND NOT EXISTS (
    SELECT 1 FROM claims.claim_payment cp WHERE cp.claim_key_id = ck.id
  );
  
  -- Check for claims with inconsistent payment status
  RETURN QUERY
  SELECT 
    cp.claim_key_id,
    'INCONSISTENT_STATUS' as issue_type,
    'Payment status does not match calculated status' as issue_description
  FROM claims.claim_payment cp
  WHERE cp.payment_status != (
    CASE 
      WHEN cp.total_paid_amount = cp.total_submitted_amount AND cp.total_submitted_amount > 0 THEN 'FULLY_PAID'
      WHEN cp.total_paid_amount > 0 THEN 'PARTIALLY_PAID'
      WHEN cp.total_rejected_amount > 0 THEN 'REJECTED'
      ELSE 'PENDING'
    END
  );
  
  -- Check for claims with negative amounts
  RETURN QUERY
  SELECT 
    cp.claim_key_id,
    'NEGATIVE_AMOUNT' as issue_type,
    'Claim has negative payment amounts' as issue_description
  FROM claims.claim_payment cp
  WHERE cp.total_paid_amount < 0 
     OR cp.total_submitted_amount < 0 
     OR cp.total_rejected_amount < 0;
END$$;

COMMENT ON FUNCTION claims.validate_claim_payment_integrity() IS 'Validates data integrity of claim_payment table';

-- ==========================================================================================================
-- ADDITIONAL TABLES FUNCTIONS AND TRIGGERS
-- ==========================================================================================================

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

-- Trigger function for activity summary updates
CREATE OR REPLACE FUNCTION claims.update_activity_summary_on_remittance_activity()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_claim_key_id BIGINT;
BEGIN
  -- Get claim_key_id from remittance_claim
  SELECT rc.claim_key_id INTO v_claim_key_id
  FROM claims.remittance_claim rc
  WHERE rc.id = COALESCE(NEW.remittance_claim_id, OLD.remittance_claim_id);
  
  -- Recalculate activity summary for the affected claim
  PERFORM claims.recalculate_activity_summary(v_claim_key_id);
  RETURN COALESCE(NEW, OLD);
END$$;

COMMENT ON FUNCTION claims.update_activity_summary_on_remittance_activity() IS 'Trigger function to update activity summary when remittance_activity changes';

-- Trigger on remittance_activity changes for activity summary
CREATE TRIGGER trg_update_activity_summary_remittance_activity
  AFTER INSERT OR UPDATE OR DELETE ON claims.remittance_activity
  FOR EACH ROW EXECUTE FUNCTION claims.update_activity_summary_on_remittance_activity();

COMMENT ON TRIGGER trg_update_activity_summary_remittance_activity ON claims.remittance_activity IS 'Automatically updates activity summary when remittance_activity changes';

-- Function to update financial timeline on claim events
CREATE OR REPLACE FUNCTION claims.update_financial_timeline_on_event()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_cumulative_paid NUMERIC(15,2);
  v_cumulative_rejected NUMERIC(15,2);
  v_event_amount NUMERIC(15,2);
BEGIN
  -- Calculate cumulative amounts up to this event
  SELECT 
    COALESCE(SUM(ra.payment_amount), 0),
    COALESCE(SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN a.net ELSE 0 END), 0)
  INTO v_cumulative_paid, v_cumulative_rejected
  FROM claims.remittance_activity ra
  JOIN claims.remittance_claim rc ON ra.remittance_claim_id = rc.id
  JOIN claims.activity a ON a.activity_id = ra.activity_id
  WHERE rc.claim_key_id = NEW.claim_key_id;
  
  -- Calculate event amount based on event type
  v_event_amount := CASE NEW.type
    WHEN 3 THEN v_cumulative_paid  -- PAYMENT event
    ELSE 0
  END;
  
  -- Insert timeline entry
  INSERT INTO claims.claim_financial_timeline (
    claim_key_id, event_type, event_date, amount, 
    cumulative_paid, cumulative_rejected, tx_at
  ) VALUES (
    NEW.claim_key_id,
    CASE NEW.type 
      WHEN 1 THEN 'SUBMISSION'
      WHEN 2 THEN 'RESUBMISSION' 
      WHEN 3 THEN 'PAYMENT'
    END,
    DATE(NEW.event_time),
    v_event_amount,
    v_cumulative_paid,
    v_cumulative_rejected,
    NEW.event_time
  )
  ON CONFLICT DO NOTHING;
  
  RETURN NEW;
END$$;

COMMENT ON FUNCTION claims.update_financial_timeline_on_event() IS 'Trigger function to update financial timeline when claim events occur';

-- Trigger on claim_event changes for financial timeline
CREATE TRIGGER trg_update_financial_timeline_claim_event
  AFTER INSERT ON claims.claim_event
  FOR EACH ROW EXECUTE FUNCTION claims.update_financial_timeline_on_event();

COMMENT ON TRIGGER trg_update_financial_timeline_claim_event ON claims.claim_event IS 'Automatically updates financial timeline when claim events occur';

-- Function to update payer performance summary
CREATE OR REPLACE FUNCTION claims.update_payer_performance_summary()
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  v_month_bucket DATE;
  v_payer_ref_id BIGINT;
BEGIN
  -- Update for current month
  v_month_bucket := DATE_TRUNC('month', CURRENT_DATE)::DATE;
  
  -- Loop through all payers
  FOR v_payer_ref_id IN 
    SELECT DISTINCT p.id FROM claims_ref.payer p
  LOOP
    -- Upsert payer performance for the month
    INSERT INTO claims.payer_performance_summary (
      payer_ref_id, month_bucket,
      total_claims, total_submitted_amount, total_paid_amount, total_rejected_amount,
      payment_rate, rejection_rate, avg_processing_days
    )
    SELECT 
      v_payer_ref_id,
      v_month_bucket,
      COUNT(*) as total_claims,
      SUM(cp.total_submitted_amount) as total_submitted_amount,
      SUM(cp.total_paid_amount) as total_paid_amount,
      SUM(cp.total_rejected_amount) as total_rejected_amount,
      CASE WHEN SUM(cp.total_submitted_amount) > 0 
           THEN ROUND((SUM(cp.total_paid_amount) / SUM(cp.total_submitted_amount)) * 100, 2)
           ELSE 0 END as payment_rate,
      CASE WHEN SUM(cp.total_submitted_amount) > 0 
           THEN ROUND((SUM(cp.total_rejected_amount) / SUM(cp.total_submitted_amount)) * 100, 2)
           ELSE 0 END as rejection_rate,
      AVG(cp.days_to_final_settlement) as avg_processing_days
    FROM claims.claim_payment cp
    JOIN claims.claim c ON c.claim_key_id = cp.claim_key_id
    WHERE c.payer_ref_id = v_payer_ref_id
      AND DATE_TRUNC('month', cp.tx_at)::DATE = v_month_bucket
    ON CONFLICT (payer_ref_id, month_bucket) DO UPDATE SET
      total_claims = EXCLUDED.total_claims,
      total_submitted_amount = EXCLUDED.total_submitted_amount,
      total_paid_amount = EXCLUDED.total_paid_amount,
      total_rejected_amount = EXCLUDED.total_rejected_amount,
      payment_rate = EXCLUDED.payment_rate,
      rejection_rate = EXCLUDED.rejection_rate,
      avg_processing_days = EXCLUDED.avg_processing_days,
      updated_at = NOW();
  END LOOP;
END$$;

COMMENT ON FUNCTION claims.update_payer_performance_summary() IS 'Updates payer performance summary for current month';

-- ==========================================================================================================
-- END OF CLAIM PAYMENT FUNCTIONS
-- ==========================================================================================================
