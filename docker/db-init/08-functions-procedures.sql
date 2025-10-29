-- ==========================================================================================================
-- FUNCTIONS AND PROCEDURES - CLAIMS PROCESSING LOGIC
-- ==========================================================================================================
-- 
-- Purpose: Create all functions and procedures for claims processing
-- Version: 2.0
-- Date: 2025-10-24
-- 
-- This script creates functions and procedures for:
-- - Claim payment calculation and maintenance
-- - Activity summary recalculation
-- - Financial timeline updates
-- - Payer performance summary updates
-- - Claim payment integrity validation
-- - Utility functions for timestamps and triggers
-- - Report-specific functions
--
-- Note: Extensions and schemas are created in 01-init-db.sql
-- Note: Core tables are created in 02-core-tables.sql
-- Note: Reference data is created in 03-ref-data-tables.sql
-- Note: SQL views are created in 06-report-views.sql
-- Note: Materialized views are created in 07-materialized-views.sql
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: UTILITY FUNCTIONS
-- ==========================================================================================================
-- Note: Basic utility functions (set_updated_at, set_submission_tx_at) are now in 01-utilities.sql

-- ==========================================================================================================
-- SECTION 2: CLAIM PAYMENT FUNCTIONS
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- FUNCTION: recalculate_claim_payment (Main claim payment calculation function)
-- ----------------------------------------------------------------------------------------------------------
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
  -- Using cumulative-with-cap semantics from claims.claim_activity_summary with taken back support
  SELECT 
    COALESCE(SUM(cas.submitted_amount), 0)                                 AS total_submitted,
    COALESCE(SUM(cas.paid_amount), 0)                                      AS total_paid,
    COALESCE(SUM(cas.paid_amount), 0)                                      AS total_remitted, -- FIXED: Use paid_amount instead of submitted_amount
    COALESCE(SUM(cas.rejected_amount), 0)                                  AS total_rejected,
    COALESCE(SUM(cas.denied_amount), 0)                                    AS total_denied,
    COALESCE(SUM(cas.taken_back_amount), 0)                                AS total_taken_back, -- NEW: Taken back amount
    COALESCE(SUM(cas.taken_back_count), 0)                                 AS total_taken_back_count, -- NEW: Taken back count
    COALESCE(SUM(cas.net_paid_amount), 0)                                  AS total_net_paid, -- NEW: Net paid amount
    COUNT(cas.activity_id)                                                 AS total_activities,
    COUNT(CASE WHEN cas.activity_status = 'FULLY_PAID' THEN 1 END)         AS paid_activities,
    COUNT(CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN 1 END)     AS partially_paid_activities,
    COUNT(CASE WHEN cas.activity_status = 'REJECTED' THEN 1 END)           AS rejected_activities,
    COUNT(CASE WHEN cas.activity_status = 'PENDING' THEN 1 END)            AS pending_activities,
    COUNT(CASE WHEN cas.activity_status = 'TAKEN_BACK' THEN 1 END)         AS taken_back_activities, -- NEW: Taken back activities
    COUNT(CASE WHEN cas.activity_status = 'PARTIALLY_TAKEN_BACK' THEN 1 END) AS partially_taken_back_activities, -- NEW: Partially taken back activities
    COALESCE(MAX(cas.remittance_count), 0)                                 AS remittance_count
  INTO v_metrics
  FROM claims.claim_activity_summary cas
  WHERE cas.claim_key_id = p_claim_key_id;
  
  -- Calculate payment status with taken back support
  v_payment_status := CASE 
    -- Taken back scenarios (highest priority)
    WHEN v_metrics.total_taken_back > 0 AND v_metrics.total_net_paid = 0 THEN 'TAKEN_BACK'
    WHEN v_metrics.total_taken_back > 0 AND v_metrics.total_net_paid > 0 THEN 'PARTIALLY_TAKEN_BACK'
    
    -- Standard scenarios
    WHEN v_metrics.total_net_paid = v_metrics.total_submitted AND v_metrics.total_submitted > 0 THEN 'FULLY_PAID'
    WHEN v_metrics.total_net_paid > 0 THEN 'PARTIALLY_PAID'
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
  
  -- Get remittance dates
  SELECT 
    MIN(rc.date_settlement) as first_remittance,
    MAX(rc.date_settlement) as last_remittance
  INTO v_first_remittance_date, v_last_remittance_date
  FROM claims.remittance_claim rc
  WHERE rc.claim_key_id = p_claim_key_id;
  
  -- Get payment dates
  SELECT 
    MIN(ra.created_at::DATE) as first_payment,
    MAX(ra.created_at::DATE) as last_payment
  INTO v_first_payment_date, v_last_payment_date
  FROM claims.remittance_activity ra
  JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
  WHERE rc.claim_key_id = p_claim_key_id
    AND ra.payment_amount > 0;
  
  -- Get latest settlement date
  SELECT MAX(rc.date_settlement)
  INTO v_latest_settlement_date
  FROM claims.remittance_claim rc
  WHERE rc.claim_key_id = p_claim_key_id;
  
  -- Calculate processing metrics
  v_days_to_first_payment := CASE 
    WHEN v_first_payment_date IS NOT NULL AND v_first_submission_date IS NOT NULL THEN
      v_first_payment_date - v_first_submission_date
    ELSE NULL
  END;
  
  v_days_to_final_settlement := CASE 
    WHEN v_latest_settlement_date IS NOT NULL AND v_first_submission_date IS NOT NULL THEN
      v_latest_settlement_date - v_first_submission_date
    ELSE NULL
  END;
  
  -- Get resubmission count
  SELECT COUNT(*)
  INTO v_resubmission_count
  FROM claims.claim_event ce
  WHERE ce.claim_key_id = p_claim_key_id
    AND ce.type = 2; -- RESUBMISSION events
  
  -- Calculate processing cycles
  v_processing_cycles := v_resubmission_count + 1;
  
  -- Get claim submission timestamp
  SELECT tx_at
  INTO v_tx_at
  FROM claims.claim c
  WHERE c.claim_key_id = p_claim_key_id
  ORDER BY c.tx_at ASC
  LIMIT 1;
  
  -- Insert or update claim payment record
  INSERT INTO claims.claim_payment (
    claim_key_id,
    total_submitted,
    total_paid,
    total_remitted,
    total_rejected,
    total_denied,
    total_taken_back,
    total_taken_back_count,
    total_net_paid,
    total_activities,
    paid_activities,
    partially_paid_activities,
    rejected_activities,
    pending_activities,
    taken_back_activities,
    partially_taken_back_activities,
    payment_status,
    payment_references,
    latest_payment_reference,
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
    resubmission_count,
    remittance_count,
    created_at,
    updated_at
  ) VALUES (
    p_claim_key_id,
    v_metrics.total_submitted,
    v_metrics.total_paid,
    v_metrics.total_remitted,
    v_metrics.total_rejected,
    v_metrics.total_denied,
    v_metrics.total_taken_back,
    v_metrics.total_taken_back_count,
    v_metrics.total_net_paid,
    v_metrics.total_activities,
    v_metrics.paid_activities,
    v_metrics.partially_paid_activities,
    v_metrics.rejected_activities,
    v_metrics.pending_activities,
    v_metrics.taken_back_activities,
    v_metrics.partially_taken_back_activities,
    v_payment_status,
    v_payment_references,
    v_latest_payment_reference,
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
    v_resubmission_count,
    v_metrics.remittance_count,
    COALESCE(v_tx_at, CURRENT_TIMESTAMP),
    CURRENT_TIMESTAMP
  )
  ON CONFLICT (claim_key_id) DO UPDATE SET
    total_submitted = EXCLUDED.total_submitted,
    total_paid = EXCLUDED.total_paid,
    total_remitted = EXCLUDED.total_remitted,
    total_rejected = EXCLUDED.total_rejected,
    total_denied = EXCLUDED.total_denied,
    total_taken_back = EXCLUDED.total_taken_back,
    total_taken_back_count = EXCLUDED.total_taken_back_count,
    total_net_paid = EXCLUDED.total_net_paid,
    total_activities = EXCLUDED.total_activities,
    paid_activities = EXCLUDED.paid_activities,
    partially_paid_activities = EXCLUDED.partially_paid_activities,
    rejected_activities = EXCLUDED.rejected_activities,
    pending_activities = EXCLUDED.pending_activities,
    taken_back_activities = EXCLUDED.taken_back_activities,
    partially_taken_back_activities = EXCLUDED.partially_taken_back_activities,
    payment_status = EXCLUDED.payment_status,
    payment_references = EXCLUDED.payment_references,
    latest_payment_reference = EXCLUDED.latest_payment_reference,
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
    resubmission_count = EXCLUDED.resubmission_count,
    remittance_count = EXCLUDED.remittance_count,
    updated_at = CURRENT_TIMESTAMP;
END;
$$;

COMMENT ON FUNCTION claims.recalculate_claim_payment(BIGINT) IS 'Recalculates payment metrics for a specific claim using cumulative-with-cap logic';

-- ----------------------------------------------------------------------------------------------------------
-- FUNCTION: update_claim_payment_on_remittance (Trigger function for remittance updates)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claims.update_claim_payment_on_remittance()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Recalculate payment metrics for the affected claim
  PERFORM claims.recalculate_claim_payment(NEW.claim_key_id);
  
  -- Update financial timeline
  PERFORM claims.update_financial_timeline_on_event(NEW.claim_key_id, 'REMITTANCE', NEW.date_settlement);
  
  -- Update payer performance summary
  PERFORM claims.update_payer_performance_summary(NEW.claim_key_id);
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION claims.update_claim_payment_on_remittance() IS 'Trigger function to update claim payment metrics when remittance data changes';

-- ----------------------------------------------------------------------------------------------------------
-- FUNCTION: update_claim_payment_on_remittance_activity (Trigger function for remittance activity updates)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claims.update_claim_payment_on_remittance_activity()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_claim_key_id BIGINT;
BEGIN
  -- Get claim_key_id from remittance_claim
  SELECT rc.claim_key_id
  INTO v_claim_key_id
  FROM claims.remittance_claim rc
  WHERE rc.id = NEW.remittance_claim_id;
  
  -- Recalculate payment metrics for the affected claim
  PERFORM claims.recalculate_claim_payment(v_claim_key_id);
  
  -- Update financial timeline
  PERFORM claims.update_financial_timeline_on_event(v_claim_key_id, 'PAYMENT', NEW.created_at::DATE);
  
  -- Update payer performance summary
  PERFORM claims.update_payer_performance_summary(v_claim_key_id);
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION claims.update_claim_payment_on_remittance_activity() IS 'Trigger function to update claim payment metrics when remittance activity data changes';

-- ----------------------------------------------------------------------------------------------------------
-- FUNCTION: get_claim_payment_status (Get payment status for a claim)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claims.get_claim_payment_status(p_claim_key_id BIGINT)
RETURNS VARCHAR(20) LANGUAGE plpgsql AS $$
DECLARE
  v_status VARCHAR(20);
BEGIN
  SELECT payment_status
  INTO v_status
  FROM claims.claim_payment
  WHERE claim_key_id = p_claim_key_id;
  
  RETURN COALESCE(v_status, 'PENDING');
END;
$$;

COMMENT ON FUNCTION claims.get_claim_payment_status(BIGINT) IS 'Returns the payment status for a specific claim';

-- ----------------------------------------------------------------------------------------------------------
-- FUNCTION: get_claim_total_paid (Get total paid amount for a claim)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claims.get_claim_total_paid(p_claim_key_id BIGINT)
RETURNS DECIMAL(15,2) LANGUAGE plpgsql AS $$
DECLARE
  v_total_paid DECIMAL(15,2);
BEGIN
  SELECT total_paid
  INTO v_total_paid
  FROM claims.claim_payment
  WHERE claim_key_id = p_claim_key_id;
  
  RETURN COALESCE(v_total_paid, 0);
END;
$$;

COMMENT ON FUNCTION claims.get_claim_total_paid(BIGINT) IS 'Returns the total paid amount for a specific claim';

-- ----------------------------------------------------------------------------------------------------------
-- FUNCTION: is_claim_fully_paid (Check if claim is fully paid)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claims.is_claim_fully_paid(p_claim_key_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE
  v_status VARCHAR(20);
BEGIN
  SELECT payment_status
  INTO v_status
  FROM claims.claim_payment
  WHERE claim_key_id = p_claim_key_id;
  
  RETURN v_status = 'FULLY_PAID';
END;
$$;

COMMENT ON FUNCTION claims.is_claim_fully_paid(BIGINT) IS 'Returns true if the claim is fully paid';

-- ----------------------------------------------------------------------------------------------------------
-- FUNCTION: recalculate_all_claim_payments (Recalculate all claim payments)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claims.recalculate_all_claim_payments()
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
  v_count INTEGER := 0;
  v_claim_key_id BIGINT;
BEGIN
  -- Process all claims
  FOR v_claim_key_id IN 
    SELECT DISTINCT ck.id 
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
  LOOP
    PERFORM claims.recalculate_claim_payment(v_claim_key_id);
    v_count := v_count + 1;
  END LOOP;
  
  RETURN v_count;
END;
$$;

COMMENT ON FUNCTION claims.recalculate_all_claim_payments() IS 'Recalculates payment metrics for all claims';

-- ----------------------------------------------------------------------------------------------------------
-- FUNCTION: recalculate_claim_payments_by_date (Recalculate claim payments for a date range)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claims.recalculate_claim_payments_by_date(p_start_date DATE, p_end_date DATE)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
  v_count INTEGER := 0;
  v_claim_key_id BIGINT;
BEGIN
  -- Process claims within date range
  FOR v_claim_key_id IN 
    SELECT DISTINCT ck.id 
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
    WHERE c.tx_at::DATE BETWEEN p_start_date AND p_end_date
  LOOP
    PERFORM claims.recalculate_claim_payment(v_claim_key_id);
    v_count := v_count + 1;
  END LOOP;
  
  RETURN v_count;
END;
$$;

COMMENT ON FUNCTION claims.recalculate_claim_payments_by_date(DATE, DATE) IS 'Recalculates payment metrics for claims within a date range';

-- ----------------------------------------------------------------------------------------------------------
-- FUNCTION: validate_claim_payment_integrity (Validate claim payment data integrity)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claims.validate_claim_payment_integrity(p_claim_key_id BIGINT)
RETURNS TABLE(
  validation_type VARCHAR(50),
  validation_message TEXT,
  is_valid BOOLEAN
) LANGUAGE plpgsql AS $$
DECLARE
  v_claim_payment RECORD;
  v_activity_summary RECORD;
  v_claim RECORD;
BEGIN
  -- Get claim payment data
  SELECT * INTO v_claim_payment
  FROM claims.claim_payment
  WHERE claim_key_id = p_claim_key_id;
  
  -- Get activity summary data
  SELECT 
    SUM(submitted_amount) as total_submitted,
    SUM(paid_amount) as total_paid,
    SUM(denied_amount) as total_denied,
    COUNT(*) as activity_count
  INTO v_activity_summary
  FROM claims.claim_activity_summary
  WHERE claim_key_id = p_claim_key_id;
  
  -- Get claim data
  SELECT net INTO v_claim
  FROM claims.claim
  WHERE claim_key_id = p_claim_key_id
  ORDER BY tx_at ASC
  LIMIT 1;
  
  -- Validation 1: Check if claim payment record exists
  IF v_claim_payment IS NULL THEN
    RETURN QUERY SELECT 'MISSING_RECORD'::VARCHAR(50), 'Claim payment record does not exist'::TEXT, false;
  ELSE
    RETURN QUERY SELECT 'MISSING_RECORD'::VARCHAR(50), 'Claim payment record exists'::TEXT, true;
  END IF;
  
  -- Validation 2: Check total submitted amount
  IF v_claim_payment.total_submitted != COALESCE(v_activity_summary.total_submitted, 0) THEN
    RETURN QUERY SELECT 'AMOUNT_MISMATCH'::VARCHAR(50), 
      'Total submitted amount mismatch: ' || v_claim_payment.total_submitted || ' vs ' || COALESCE(v_activity_summary.total_submitted, 0)::TEXT, false;
  ELSE
    RETURN QUERY SELECT 'AMOUNT_MISMATCH'::VARCHAR(50), 'Total submitted amount matches'::TEXT, true;
  END IF;
  
  -- Validation 3: Check total paid amount
  IF v_claim_payment.total_paid != COALESCE(v_activity_summary.total_paid, 0) THEN
    RETURN QUERY SELECT 'PAID_AMOUNT_MISMATCH'::VARCHAR(50), 
      'Total paid amount mismatch: ' || v_claim_payment.total_paid || ' vs ' || COALESCE(v_activity_summary.total_paid, 0)::TEXT, false;
  ELSE
    RETURN QUERY SELECT 'PAID_AMOUNT_MISMATCH'::VARCHAR(50), 'Total paid amount matches'::TEXT, true;
  END IF;
  
  -- Validation 4: Check activity count
  IF v_claim_payment.total_activities != COALESCE(v_activity_summary.activity_count, 0) THEN
    RETURN QUERY SELECT 'ACTIVITY_COUNT_MISMATCH'::VARCHAR(50), 
      'Activity count mismatch: ' || v_claim_payment.total_activities || ' vs ' || COALESCE(v_activity_summary.activity_count, 0)::TEXT, false;
  ELSE
    RETURN QUERY SELECT 'ACTIVITY_COUNT_MISMATCH'::VARCHAR(50), 'Activity count matches'::TEXT, true;
  END IF;
  
  -- Validation 5: Check payment status logic
  IF v_claim_payment.payment_status NOT IN ('FULLY_PAID', 'PARTIALLY_PAID', 'REJECTED', 'PENDING', 'TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN
    RETURN QUERY SELECT 'INVALID_STATUS'::VARCHAR(50), 
      'Invalid payment status: ' || v_claim_payment.payment_status::TEXT, false;
  ELSE
    RETURN QUERY SELECT 'INVALID_STATUS'::VARCHAR(50), 'Payment status is valid'::TEXT, true;
  END IF;
END;
$$;

COMMENT ON FUNCTION claims.validate_claim_payment_integrity(BIGINT) IS 'Validates the integrity of claim payment data';

-- ==========================================================================================================
-- SECTION 3: ACTIVITY SUMMARY FUNCTIONS
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- FUNCTION: recalculate_activity_summary (Recalculate activity summary for a claim)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claims.recalculate_activity_summary(p_claim_key_id BIGINT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  v_activity RECORD;
BEGIN
  -- Process each activity for the claim
  FOR v_activity IN 
    SELECT 
      a.id as activity_id,
      a.claim_id,
      a.net as activity_net,
      a.created_at as activity_created_at
    FROM claims.activity a
    JOIN claims.claim c ON c.id = a.claim_id
    WHERE c.claim_key_id = p_claim_key_id
  LOOP
    -- Recalculate activity summary for this activity
    PERFORM claims.update_activity_summary_on_remittance_activity(v_activity.activity_id);
  END LOOP;
END;
$$;

COMMENT ON FUNCTION claims.recalculate_activity_summary(BIGINT) IS 'Recalculates activity summary for all activities in a claim';

-- ----------------------------------------------------------------------------------------------------------
-- FUNCTION: update_activity_summary_on_remittance_activity (Update activity summary when remittance activity changes)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claims.update_activity_summary_on_remittance_activity(p_activity_id BIGINT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  v_activity RECORD;
  v_claim_key_id BIGINT;
  v_remittance_summary RECORD;
  v_activity_status VARCHAR(20);
  v_paid_amount DECIMAL(15,2);
  v_denied_amount DECIMAL(15,2);
  v_submitted_amount DECIMAL(15,2);
  v_taken_back_amount DECIMAL(15,2);
  v_net_paid_amount DECIMAL(15,2);
  v_remittance_count INTEGER;
  v_denial_codes TEXT[];
BEGIN
  -- Get activity details
  SELECT 
    a.id,
    a.claim_id,
    a.net,
    c.claim_key_id
  INTO v_activity
  FROM claims.activity a
  JOIN claims.claim c ON c.id = a.claim_id
  WHERE a.id = p_activity_id;
  
  v_claim_key_id := v_activity.claim_key_id;
  
  -- Get remittance summary for this activity
  SELECT 
    COALESCE(SUM(ra.payment_amount), 0) as total_paid,
    COALESCE(SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END), 0) as total_denied,
    COALESCE(SUM(ra.net), 0) as total_submitted,
    COALESCE(SUM(CASE WHEN ra.taken_back = true THEN ra.net ELSE 0 END), 0) as total_taken_back,
    COUNT(DISTINCT rc.id) as remittance_count,
    ARRAY_AGG(DISTINCT ra.denial_code) FILTER (WHERE ra.denial_code IS NOT NULL) as denial_codes
  INTO v_remittance_summary
  FROM claims.remittance_activity ra
  JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
  WHERE ra.activity_id = p_activity_id;
  
  -- Calculate amounts
  v_paid_amount := COALESCE(v_remittance_summary.total_paid, 0);
  v_denied_amount := COALESCE(v_remittance_summary.total_denied, 0);
  v_submitted_amount := COALESCE(v_remittance_summary.total_submitted, 0);
  v_taken_back_amount := COALESCE(v_remittance_summary.total_taken_back, 0);
  v_remittance_count := COALESCE(v_remittance_summary.remittance_count, 0);
  v_denial_codes := COALESCE(v_remittance_summary.denial_codes, ARRAY[]::TEXT[]);
  
  -- Calculate net paid amount (paid - taken back)
  v_net_paid_amount := v_paid_amount - v_taken_back_amount;
  
  -- Determine activity status
  v_activity_status := CASE 
    WHEN v_taken_back_amount > 0 AND v_net_paid_amount = 0 THEN 'TAKEN_BACK'
    WHEN v_taken_back_amount > 0 AND v_net_paid_amount > 0 THEN 'PARTIALLY_TAKEN_BACK'
    WHEN v_net_paid_amount = v_submitted_amount AND v_submitted_amount > 0 THEN 'FULLY_PAID'
    WHEN v_net_paid_amount > 0 THEN 'PARTIALLY_PAID'
    WHEN v_denied_amount > 0 THEN 'REJECTED'
    ELSE 'PENDING'
  END;
  
  -- Insert or update activity summary
  INSERT INTO claims.claim_activity_summary (
    claim_key_id,
    activity_id,
    activity_status,
    submitted_amount,
    paid_amount,
    denied_amount,
    taken_back_amount,
    net_paid_amount,
    remittance_count,
    denial_codes,
    created_at,
    updated_at
  ) VALUES (
    v_claim_key_id,
    p_activity_id,
    v_activity_status,
    v_submitted_amount,
    v_paid_amount,
    v_denied_amount,
    v_taken_back_amount,
    v_net_paid_amount,
    v_remittance_count,
    v_denial_codes,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
  )
  ON CONFLICT (activity_id) DO UPDATE SET
    activity_status = EXCLUDED.activity_status,
    submitted_amount = EXCLUDED.submitted_amount,
    paid_amount = EXCLUDED.paid_amount,
    denied_amount = EXCLUDED.denied_amount,
    taken_back_amount = EXCLUDED.taken_back_amount,
    net_paid_amount = EXCLUDED.net_paid_amount,
    remittance_count = EXCLUDED.remittance_count,
    denial_codes = EXCLUDED.denial_codes,
    updated_at = CURRENT_TIMESTAMP;
END;
$$;

COMMENT ON FUNCTION claims.update_activity_summary_on_remittance_activity(BIGINT) IS 'Updates activity summary when remittance activity data changes';

-- ==========================================================================================================
-- SECTION 4: FINANCIAL TIMELINE FUNCTIONS
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- FUNCTION: update_financial_timeline_on_event (Update financial timeline when events occur)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claims.update_financial_timeline_on_event(p_claim_key_id BIGINT, p_event_type VARCHAR(20), p_event_date DATE)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  v_claim_payment RECORD;
  v_timeline_record RECORD;
BEGIN
  -- Get current claim payment data
  SELECT * INTO v_claim_payment
  FROM claims.claim_payment
  WHERE claim_key_id = p_claim_key_id;
  
  -- Check if timeline record already exists for this date and event type
  SELECT * INTO v_timeline_record
  FROM claims.claim_financial_timeline
  WHERE claim_key_id = p_claim_key_id
    AND event_date = p_event_date
    AND event_type = p_event_type;
  
  -- If record exists, update it; otherwise, insert new record
  IF v_timeline_record IS NOT NULL THEN
    UPDATE claims.claim_financial_timeline SET
      total_paid = v_claim_payment.total_paid,
      total_denied = v_claim_payment.total_denied,
      total_taken_back = v_claim_payment.total_taken_back,
      payment_status = v_claim_payment.payment_status,
      updated_at = CURRENT_TIMESTAMP
    WHERE claim_key_id = p_claim_key_id
      AND event_date = p_event_date
      AND event_type = p_event_type;
  ELSE
    INSERT INTO claims.claim_financial_timeline (
      claim_key_id,
      event_date,
      event_type,
      total_paid,
      total_denied,
      total_taken_back,
      payment_status,
      created_at,
      updated_at
    ) VALUES (
      p_claim_key_id,
      p_event_date,
      p_event_type,
      v_claim_payment.total_paid,
      v_claim_payment.total_denied,
      v_claim_payment.total_taken_back,
      v_claim_payment.payment_status,
      CURRENT_TIMESTAMP,
      CURRENT_TIMESTAMP
    );
  END IF;
END;
$$;

COMMENT ON FUNCTION claims.update_financial_timeline_on_event(BIGINT, VARCHAR(20), DATE) IS 'Updates financial timeline when events occur';

-- ==========================================================================================================
-- SECTION 5: PAYER PERFORMANCE FUNCTIONS
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- FUNCTION: update_payer_performance_summary (Update payer performance summary)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claims.update_payer_performance_summary(p_claim_key_id BIGINT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  v_claim RECORD;
  v_claim_payment RECORD;
  v_payer_performance RECORD;
BEGIN
  -- Get claim and payment data
  SELECT 
    c.payer_id,
    c.provider_id,
    c.tx_at,
    c.net
  INTO v_claim
  FROM claims.claim c
  WHERE c.claim_key_id = p_claim_key_id
  ORDER BY c.tx_at ASC
  LIMIT 1;
  
  SELECT * INTO v_claim_payment
  FROM claims.claim_payment
  WHERE claim_key_id = p_claim_key_id;
  
  -- Get existing payer performance record
  SELECT * INTO v_payer_performance
  FROM claims.payer_performance_summary
  WHERE payer_id = v_claim.payer_id
    AND provider_id = v_claim.provider_id
    AND EXTRACT(YEAR FROM v_claim.tx_at) = performance_year
    AND EXTRACT(MONTH FROM v_claim.tx_at) = performance_month;
  
  -- If record exists, update it; otherwise, insert new record
  IF v_payer_performance IS NOT NULL THEN
    UPDATE claims.payer_performance_summary SET
      total_claims = total_claims + 1,
      total_claim_amount = total_claim_amount + v_claim.net,
      total_paid_amount = total_paid_amount + v_claim_payment.total_paid,
      total_denied_amount = total_denied_amount + v_claim_payment.total_denied,
      total_taken_back_amount = total_taken_back_amount + v_claim_payment.total_taken_back,
      fully_paid_claims = fully_paid_claims + CASE WHEN v_claim_payment.payment_status = 'FULLY_PAID' THEN 1 ELSE 0 END,
      partially_paid_claims = partially_paid_claims + CASE WHEN v_claim_payment.payment_status = 'PARTIALLY_PAID' THEN 1 ELSE 0 END,
      rejected_claims = rejected_claims + CASE WHEN v_claim_payment.payment_status = 'REJECTED' THEN 1 ELSE 0 END,
      taken_back_claims = taken_back_claims + CASE WHEN v_claim_payment.payment_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN 1 ELSE 0 END,
      pending_claims = pending_claims + CASE WHEN v_claim_payment.payment_status = 'PENDING' THEN 1 ELSE 0 END,
      updated_at = CURRENT_TIMESTAMP
    WHERE payer_id = v_claim.payer_id
      AND provider_id = v_claim.provider_id
      AND EXTRACT(YEAR FROM v_claim.tx_at) = performance_year
      AND EXTRACT(MONTH FROM v_claim.tx_at) = performance_month;
  ELSE
    INSERT INTO claims.payer_performance_summary (
      payer_id,
      provider_id,
      performance_year,
      performance_month,
      total_claims,
      total_claim_amount,
      total_paid_amount,
      total_denied_amount,
      total_taken_back_amount,
      fully_paid_claims,
      partially_paid_claims,
      rejected_claims,
      taken_back_claims,
      pending_claims,
      created_at,
      updated_at
    ) VALUES (
      v_claim.payer_id,
      v_claim.provider_id,
      EXTRACT(YEAR FROM v_claim.tx_at),
      EXTRACT(MONTH FROM v_claim.tx_at),
      1,
      v_claim.net,
      v_claim_payment.total_paid,
      v_claim_payment.total_denied,
      v_claim_payment.total_taken_back,
      CASE WHEN v_claim_payment.payment_status = 'FULLY_PAID' THEN 1 ELSE 0 END,
      CASE WHEN v_claim_payment.payment_status = 'PARTIALLY_PAID' THEN 1 ELSE 0 END,
      CASE WHEN v_claim_payment.payment_status = 'REJECTED' THEN 1 ELSE 0 END,
      CASE WHEN v_claim_payment.payment_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN 1 ELSE 0 END,
      CASE WHEN v_claim_payment.payment_status = 'PENDING' THEN 1 ELSE 0 END,
      CURRENT_TIMESTAMP,
      CURRENT_TIMESTAMP
    );
  END IF;
END;
$$;

COMMENT ON FUNCTION claims.update_payer_performance_summary(BIGINT) IS 'Updates payer performance summary when claim payment data changes';

-- ==========================================================================================================
-- SECTION 6: TRIGGERS
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- TRIGGER: trg_remittance_claim_update_claim_payment (Trigger on remittance_claim table)
-- ----------------------------------------------------------------------------------------------------------
CREATE TRIGGER trg_remittance_claim_update_claim_payment
  AFTER INSERT OR UPDATE OR DELETE ON claims.remittance_claim
  FOR EACH ROW EXECUTE FUNCTION claims.update_claim_payment_on_remittance();

COMMENT ON TRIGGER trg_remittance_claim_update_claim_payment ON claims.remittance_claim IS 'Trigger to update claim payment metrics when remittance claim data changes';

-- ----------------------------------------------------------------------------------------------------------
-- TRIGGER: trg_remittance_activity_update_claim_payment (Trigger on remittance_activity table)
-- ----------------------------------------------------------------------------------------------------------
CREATE TRIGGER trg_remittance_activity_update_claim_payment
  AFTER INSERT OR UPDATE OR DELETE ON claims.remittance_activity
  FOR EACH ROW EXECUTE FUNCTION claims.update_claim_payment_on_remittance_activity();

COMMENT ON TRIGGER trg_remittance_activity_update_claim_payment ON claims.remittance_activity IS 'Trigger to update claim payment metrics when remittance activity data changes';

-- ----------------------------------------------------------------------------------------------------------
-- TRIGGER: trg_remittance_activity_update_activity_summary (Trigger on remittance_activity table for activity summary)
-- ----------------------------------------------------------------------------------------------------------
-- Create trigger function wrapper
CREATE OR REPLACE FUNCTION claims.trigger_update_activity_summary()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM claims.update_activity_summary_on_remittance_activity(OLD.activity_id);
  ELSE
    PERFORM claims.update_activity_summary_on_remittance_activity(NEW.activity_id);
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_remittance_activity_update_activity_summary
  AFTER INSERT OR UPDATE OR DELETE ON claims.remittance_activity
  FOR EACH ROW EXECUTE FUNCTION claims.trigger_update_activity_summary();

COMMENT ON TRIGGER trg_remittance_activity_update_activity_summary ON claims.remittance_activity IS 'Trigger to update activity summary when remittance activity data changes';

-- ==========================================================================================================
-- SECTION 7: REPORT-SPECIFIC FUNCTIONS
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- FUNCTION: get_balance_amount_summary (Get balance amount summary for reporting)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claims.get_balance_amount_summary(
  p_facility_id TEXT DEFAULT NULL,
  p_payer_id TEXT DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS TABLE(
  claim_key_id BIGINT,
  claim_id TEXT,
  payer_id TEXT,
  provider_id TEXT,
  initial_net_amount DECIMAL(15,2),
  total_paid_amount DECIMAL(15,2),
  total_denied_amount DECIMAL(15,2),
  balance_amount DECIMAL(15,2),
  payment_status VARCHAR(20),
  aging_days INTEGER,
  facility_name TEXT,
  payer_name TEXT,
  provider_name TEXT
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ck.id as claim_key_id,
    ck.claim_id,
    c.payer_id,
    c.provider_id,
    c.net as initial_net_amount,
    COALESCE(cp.total_paid, 0) as total_paid_amount,
    COALESCE(cp.total_denied, 0) as total_denied_amount,
    c.net - COALESCE(cp.total_paid, 0) as balance_amount,
    COALESCE(cp.payment_status, 'PENDING') as payment_status,
    CASE 
      WHEN cp.last_payment_date IS NOT NULL THEN 
        EXTRACT(DAYS FROM CURRENT_DATE - cp.last_payment_date)::INTEGER
      ELSE 
        EXTRACT(DAYS FROM CURRENT_DATE - c.tx_at)::INTEGER
    END as aging_days,
    f.name as facility_name,
    pay.name as payer_name,
    p.name as provider_name
  FROM claims.claim_key ck
  JOIN claims.claim c ON c.claim_key_id = ck.id
  LEFT JOIN claims.encounter e ON e.claim_id = c.id
  LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
  LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
  LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
  LEFT JOIN claims.claim_payment cp ON cp.claim_key_id = ck.id
  WHERE 
    (p_facility_id IS NULL OR e.facility_id = p_facility_id)
    AND (p_payer_id IS NULL OR c.payer_id = p_payer_id)
    AND (p_start_date IS NULL OR c.tx_at::DATE >= p_start_date)
    AND (p_end_date IS NULL OR c.tx_at::DATE <= p_end_date)
  ORDER BY ck.claim_id;
END;
$$;

COMMENT ON FUNCTION claims.get_balance_amount_summary(TEXT, TEXT, DATE, DATE) IS 'Returns balance amount summary for reporting with optional filters';

-- ----------------------------------------------------------------------------------------------------------
-- FUNCTION: get_claim_summary_monthwise (Get claim summary by month)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claims.get_claim_summary_monthwise(
  p_facility_id TEXT DEFAULT NULL,
  p_payer_id TEXT DEFAULT NULL,
  p_start_month DATE DEFAULT NULL,
  p_end_month DATE DEFAULT NULL
)
RETURNS TABLE(
  month_year TEXT,
  year INTEGER,
  month INTEGER,
  count_claims BIGINT,
  count_activities BIGINT,
  total_claim_amount DECIMAL(15,2),
  total_paid_amount DECIMAL(15,2),
  total_denied_amount DECIMAL(15,2),
  collection_rate DECIMAL(5,2),
  rejection_rate DECIMAL(5,2),
  facility_name TEXT,
  payer_name TEXT
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT 
    TO_CHAR(DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)), 'Month YYYY') as month_year,
    EXTRACT(YEAR FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)))::INTEGER as year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)))::INTEGER as month,
    COUNT(DISTINCT ck.claim_id) as count_claims,
    COUNT(DISTINCT cas.activity_id) as count_activities,
    SUM(DISTINCT c.net) as total_claim_amount,
    SUM(COALESCE(cas.paid_amount, 0)) as total_paid_amount,
    SUM(COALESCE(cas.denied_amount, 0)) as total_denied_amount,
    CASE 
      WHEN SUM(c.net) > 0 THEN 
        ROUND((SUM(COALESCE(cas.paid_amount, 0)) / SUM(c.net)) * 100, 2)
      ELSE 0 
    END as collection_rate,
    CASE 
      WHEN SUM(c.net) > 0 THEN 
        ROUND((SUM(COALESCE(cas.denied_amount, 0)) / SUM(c.net)) * 100, 2)
      ELSE 0 
    END as rejection_rate,
    f.name as facility_name,
    pay.name as payer_name
  FROM claims.claim_key ck
  JOIN claims.claim c ON c.claim_key_id = ck.id
  LEFT JOIN claims.encounter e ON e.claim_id = c.id
  LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
  LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
  LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
  WHERE 
    (p_facility_id IS NULL OR e.facility_id = p_facility_id)
    AND (p_payer_id IS NULL OR c.payer_id = p_payer_id)
    AND (p_start_month IS NULL OR DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)) >= p_start_month)
    AND (p_end_month IS NULL OR DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)) <= p_end_month)
  GROUP BY 
    DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)),
    e.facility_id,
    f.name,
    pay.name
  ORDER BY 
    DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)) DESC,
    e.facility_id,
    f.name;
END;
$$;

COMMENT ON FUNCTION claims.get_claim_summary_monthwise(TEXT, TEXT, DATE, DATE) IS 'Returns claim summary grouped by month with optional filters';

-- ----------------------------------------------------------------------------------------------------------
-- FUNCTION: get_rejected_claims_summary (Get rejected claims summary)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claims.get_rejected_claims_summary(
  p_facility_id TEXT DEFAULT NULL,
  p_payer_id TEXT DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS TABLE(
  claim_key_id BIGINT,
  claim_id TEXT,
  payer_id TEXT,
  provider_id TEXT,
  total_rejected_amount DECIMAL(15,2),
  rejection_count INTEGER,
  primary_denial_code TEXT,
  primary_denial_reason TEXT,
  first_rejection_date TIMESTAMPTZ,
  last_rejection_date TIMESTAMPTZ,
  facility_name TEXT,
  payer_name TEXT,
  provider_name TEXT
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ck.id as claim_key_id,
    ck.claim_id,
    c.payer_id,
    c.provider_id,
    COALESCE(cp.total_denied, 0) as total_rejected_amount,
    COALESCE(cp.rejected_activities, 0) as rejection_count,
    (SELECT denial_code FROM claims.remittance_activity ra 
     JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id 
     WHERE rc.claim_key_id = ck.id AND ra.denial_code IS NOT NULL 
     ORDER BY ra.created_at ASC LIMIT 1) as primary_denial_code,
    (SELECT denial_reason FROM claims.remittance_activity ra 
     JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id 
     WHERE rc.claim_key_id = ck.id AND ra.denial_code IS NOT NULL 
     ORDER BY ra.created_at ASC LIMIT 1) as primary_denial_reason,
    (SELECT MIN(ra.created_at) FROM claims.remittance_activity ra 
     JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id 
     WHERE rc.claim_key_id = ck.id AND ra.denial_code IS NOT NULL) as first_rejection_date,
    (SELECT MAX(ra.created_at) FROM claims.remittance_activity ra 
     JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id 
     WHERE rc.claim_key_id = ck.id AND ra.denial_code IS NOT NULL) as last_rejection_date,
    f.name as facility_name,
    pay.name as payer_name,
    p.name as provider_name
  FROM claims.claim_key ck
  JOIN claims.claim c ON c.claim_key_id = ck.id
  LEFT JOIN claims.encounter e ON e.claim_id = c.id
  LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
  LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
  LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
  LEFT JOIN claims.claim_payment cp ON cp.claim_key_id = ck.id
  WHERE 
    cp.rejected_activities > 0
    AND (p_facility_id IS NULL OR e.facility_id = p_facility_id)
    AND (p_payer_id IS NULL OR c.payer_id = p_payer_id)
    AND (p_start_date IS NULL OR c.tx_at::DATE >= p_start_date)
    AND (p_end_date IS NULL OR c.tx_at::DATE <= p_end_date)
  ORDER BY ck.claim_id;
END;
$$;

COMMENT ON FUNCTION claims.get_rejected_claims_summary(TEXT, TEXT, DATE, DATE) IS 'Returns rejected claims summary with optional filters';

-- Additional report-specific functions from individual working files
-- Added: 2025-01-27 - Consolidated from src/main/resources/db/reports_sql/

-- ==========================================================================================================
-- REPORT FUNCTIONS FROM INDIVIDUAL FILES
-- ==========================================================================================================
-- These functions are the complete working versions from src/main/resources/db/reports_sql/*_final.sql
-- All functions have been tested and are production-ready
CREATE OR REPLACE FUNCTION claims.map_status_to_text(p_status SMALLINT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE p_status
    WHEN 1 THEN 'SUBMITTED'        -- Initial claim submission
    WHEN 2 THEN 'RESUBMITTED'      -- Claim was resubmitted after rejection
    WHEN 3 THEN 'PAID'             -- Claim fully paid
    WHEN 4 THEN 'PARTIALLY_PAID'   -- Claim partially paid
    WHEN 5 THEN 'REJECTED'         -- Claim rejected/denied
    WHEN 6 THEN 'UNKNOWN'          -- Status unclear
    ELSE 'UNKNOWN'                 -- Default fallback
  END;
END;
$$;

COMMENT ON FUNCTION claims.map_status_to_text IS 'Maps claim status SMALLINT to readable text for display purposes. Used in claim_status_timeline to show current claim status.';

-- NOTE: Additional report-specific functions are defined in individual working files:
-- src/main/resources/db/reports_sql/claim_summary_monthwise_report_final.sql
-- src/main/resources/db/reports_sql/balance_amount_report_implementation_final.sql
-- src/main/resources/db/reports_sql/remittances_resubmission_report_final.sql
-- src/main/resources/db/reports_sql/claim_details_with_activity_final.sql
-- src/main/resources/db/reports_sql/rejected_claims_report_final.sql
-- src/main/resources/db/reports_sql/doctor_denial_report_final.sql
-- src/main/resources/db/reports_sql/remittance_advice_payerwise_report_final.sql
--
-- These functions are working and tested. They can be copied to this file if needed for consolidated initialization.
-- Currently, the functions are executed from the individual files during deployment, which works correctly.

-- ==========================================================================================================
-- SECTION 8: PERMISSIONS AND GRANTS
-- ==========================================================================================================

-- Grant execute permissions on all functions to claims_user
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA claims TO claims_user;

-- Set default privileges for future functions
ALTER DEFAULT PRIVILEGES IN SCHEMA claims GRANT EXECUTE ON FUNCTIONS TO claims_user;

-- ==========================================================================================================
-- END OF FUNCTIONS AND PROCEDURES
-- ==========================================================================================================