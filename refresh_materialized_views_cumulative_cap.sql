-- ==========================================================================================================
-- MATERIALIZED VIEW REFRESH AFTER CUMULATIVE-WITH-CAP IMPLEMENTATION
-- ==========================================================================================================
-- 
-- Purpose: Refresh all materialized views after implementing cumulative-with-cap logic
-- Version: 1.0
-- Date: 2025-01-03
-- 
-- This script refreshes all materialized views that were updated to use claim_activity_summary
-- with cumulative-with-cap semantics to prevent overcounting from multiple remittances per activity.
--
-- ==========================================================================================================

-- Refresh all materialized views that were updated for cumulative-with-cap
-- Note: Using CONCURRENTLY to avoid blocking reads during refresh

-- 1. Balance Amount Summary MV
REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_balance_amount_summary;

-- 2. Remittance Advice Summary MV  
REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_remittance_advice_summary;

-- 3. Doctor Denial Summary MV (if it exists and was updated)
-- REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_doctor_denial_summary;

-- 4. Claim Details Complete MV (if it exists and was updated)
-- REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_claim_details_complete;

-- ==========================================================================================================
-- VALIDATION QUERIES
-- ==========================================================================================================

-- Validate that the cumulative-with-cap approach is working correctly
-- Compare totals from claim_activity_summary vs raw remittance_activity for sample claims

-- Sample validation: Check a few claims to ensure capped totals are <= raw sums
SELECT 
  'VALIDATION: Capped vs Raw Totals' as validation_type,
  ck.claim_id,
  -- Capped totals from claim_activity_summary
  SUM(cas.paid_amount) as capped_paid_total,
  SUM(cas.denied_amount) as capped_denied_total,
  -- Raw totals from remittance_activity (should be >= capped)
  SUM(ra.payment_amount) as raw_paid_total,
  SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) as raw_denied_total,
  -- Validation flags
  CASE WHEN SUM(cas.paid_amount) <= SUM(ra.payment_amount) THEN 'PASS' ELSE 'FAIL' END as paid_cap_validation,
  CASE WHEN SUM(cas.denied_amount) <= SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) THEN 'PASS' ELSE 'FAIL' END as denied_cap_validation
FROM claims.claim_key ck
JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id AND ra.activity_id = cas.activity_id
WHERE ck.id IN (
  SELECT claim_key_id FROM claims.claim_activity_summary 
  WHERE remittance_count > 1 
  LIMIT 5
)
GROUP BY ck.claim_id
ORDER BY ck.claim_id;

-- Sample validation: Check that latest denial logic is working
SELECT 
  'VALIDATION: Latest Denial Logic' as validation_type,
  ck.claim_id,
  cas.activity_id,
  cas.activity_status,
  cas.denied_amount,
  cas.denial_codes,
  -- Show latest denial from raw data for comparison
  (ARRAY_AGG(ra.denial_code ORDER BY rc.date_settlement DESC NULLS LAST, ra.id DESC))[1] as latest_denial_from_raw,
  SUM(ra.payment_amount) as total_payments_raw
FROM claims.claim_key ck
JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id AND ra.activity_id = cas.activity_id
WHERE cas.activity_status = 'REJECTED'
  AND ck.id IN (
    SELECT claim_key_id FROM claims.claim_activity_summary 
    WHERE activity_status = 'REJECTED'
    LIMIT 3
  )
GROUP BY ck.claim_id, cas.activity_id, cas.activity_status, cas.denied_amount, cas.denial_codes
ORDER BY ck.claim_id, cas.activity_id;

-- Summary validation: Count of activities by status
SELECT 
  'VALIDATION: Activity Status Distribution' as validation_type,
  activity_status,
  COUNT(*) as activity_count,
  SUM(paid_amount) as total_paid,
  SUM(denied_amount) as total_denied,
  SUM(submitted_amount) as total_submitted
FROM claims.claim_activity_summary
GROUP BY activity_status
ORDER BY activity_status;

COMMENT ON SCRIPT IS 'Refreshes materialized views and validates cumulative-with-cap implementation';
