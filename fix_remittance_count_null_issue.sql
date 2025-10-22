-- ==========================================================================================================
-- FIX FOR REMITTANCE_COUNT NULL CONSTRAINT VIOLATION
-- ==========================================================================================================
-- 
-- Issue: The recalculate_claim_payment function was inserting NULL values for remittance_count
-- when there were no rows in claims.claim_activity_summary, violating the NOT NULL constraint.
-- 
-- Root Cause: MAX(cas.remittance_count) returns NULL when there are no rows
-- 
-- Solution: Use COALESCE(MAX(cas.remittance_count), 0) to default to 0
-- 
-- Date: 2025-10-22
-- ==========================================================================================================

-- Update the recalculate_claim_payment function to handle NULL remittance_count
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
    COALESCE(MAX(cas.remittance_count), 0)                                 AS remittance_count
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

-- Verify the fix
DO $$
BEGIN
  RAISE NOTICE 'Fixed recalculate_claim_payment function - remittance_count now uses COALESCE(MAX(cas.remittance_count), 0)';
  RAISE NOTICE 'This will prevent NULL constraint violations when there are no rows in claims.claim_activity_summary';
END$$;
