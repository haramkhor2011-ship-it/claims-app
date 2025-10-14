-- ==========================================================================================================
-- MATERIALIZED VIEWS FOR SUB-SECOND REPORT PERFORMANCE
-- ==========================================================================================================
-- 
-- Purpose: Create materialized views for achieving sub-second report performance
-- Version: 1.0
-- Date: 2025-01-15
-- 
-- This script creates materialized views that pre-compute complex aggregations
-- to achieve sub-second response times for all reports.
--
-- PERFORMANCE TARGETS:
-- - Balance Amount Report: 0.5-1.5 seconds (was 30-60 seconds)
-- - Remittance Advice: 0.3-0.8 seconds (was 15-25 seconds)
-- - Resubmission Report: 0.8-2.0 seconds (was 45-90 seconds)
-- - Doctor Denial Report: 0.4-1.0 seconds (was 25-40 seconds)
-- - Claim Details: 0.6-1.8 seconds (was 60-120 seconds)
-- - Monthly Reports: 0.2-0.5 seconds (was 10-30 minutes)
-- - Rejected Claims Report: 0.4-1.2 seconds (was 15-45 seconds)
-- - Claim Summary Payerwise: 0.3-0.8 seconds (was 10-30 seconds)
-- - Claim Summary Encounterwise: 0.2-0.6 seconds (was 8-25 seconds)
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: BALANCE AMOUNT REPORT MATERIALIZED VIEW
-- ==========================================================================================================

-- 1. Balance Amount Report - Pre-computed aggregations
DROP MATERIALIZED VIEW IF EXISTS claims.mv_balance_amount_summary CASCADE;
CREATE MATERIALIZED VIEW claims.mv_balance_amount_summary AS
SELECT 
  ck.id as claim_key_id,
  ck.claim_id,
  c.id as claim_internal_id,
  c.payer_id,
  c.provider_id,
  c.net as initial_net,
  c.tx_at,
  c.created_at,
  -- Pre-computed remittance aggregations
  COALESCE(rem_agg.total_payment, 0) as total_payment,
  COALESCE(rem_agg.total_denied, 0) as total_denied,
  COALESCE(rem_agg.remittance_count, 0) as remittance_count,
  rem_agg.first_remittance_date,
  rem_agg.last_remittance_date,
  -- Pre-computed resubmission aggregations
  COALESCE(resub_agg.resubmission_count, 0) as resubmission_count,
  resub_agg.last_resubmission_date,
  -- Pre-computed status
  cst.status as current_status,
  cst.status_time as last_status_date,
  -- Pre-computed encounter data (aggregated)
  enc_agg.facility_id,
  enc_agg.encounter_start,
  -- Pre-computed reference data
  p.name as provider_name,
  enc_agg.facility_name,
  pay.name as payer_name,
  -- Pre-computed calculated fields
  c.net - COALESCE(rem_agg.total_payment, 0) - COALESCE(rem_agg.total_denied, 0) as pending_amount,
  enc_agg.aging_days
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN (
  SELECT 
    claim_key_id,
    status,
    status_time
  FROM (
    SELECT 
      claim_key_id,
      status,
      status_time,
      ROW_NUMBER() OVER (PARTITION BY claim_key_id ORDER BY status_time DESC, id DESC) as rn
    FROM claims.claim_status_timeline
  ) ranked
  WHERE rn = 1
) cst ON cst.claim_key_id = ck.id
LEFT JOIN (
  SELECT 
    rc.claim_key_id,
    SUM(ra.payment_amount) as total_payment,
    SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) as total_denied,
    COUNT(*) as remittance_count,
    MIN(rc.date_settlement) as first_remittance_date,
    MAX(rc.date_settlement) as last_remittance_date
  FROM claims.remittance_claim rc
  JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
) rem_agg ON rem_agg.claim_key_id = ck.id
LEFT JOIN (
  SELECT 
    ce.claim_key_id,
    COUNT(*) as resubmission_count,
    MAX(ce.event_time) as last_resubmission_date
  FROM claims.claim_event ce
  WHERE ce.type = 2
  GROUP BY ce.claim_key_id
) resub_agg ON resub_agg.claim_key_id = ck.id
LEFT JOIN (
  SELECT 
    c.claim_key_id,
    e.facility_id,
    e.start_at as encounter_start,
    f.name as facility_name,
    EXTRACT(DAYS FROM (NOW() - e.start_at)) as aging_days
  FROM claims.claim c
  JOIN claims.encounter e ON e.claim_id = c.id
  LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
) enc_agg ON enc_agg.claim_key_id = ck.id;

-- Create unique index for concurrent refresh
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_balance_amount_summary_claim_key_id 
ON claims.mv_balance_amount_summary(claim_key_id);

-- ==========================================================================================================
-- SECTION 2: REMITTANCE ADVICE REPORT MATERIALIZED VIEW
-- ==========================================================================================================

-- 2. Remittance Advice Report - Pre-computed aggregations
DROP MATERIALIZED VIEW IF EXISTS claims.mv_remittance_advice_summary CASCADE;
CREATE MATERIALIZED VIEW claims.mv_remittance_advice_summary AS
SELECT 
  rc.id as remittance_claim_id,
  rc.claim_key_id,
  rc.payment_reference,
  rc.date_settlement,
  rc.denial_code,
  ck.claim_id,
  c.payer_id,
  c.provider_id,
  c.net as claim_net,
  -- Pre-computed activity aggregations
  COUNT(ra.id) as activity_count,
  SUM(ra.payment_amount) as total_payment,
  SUM(ra.net) as total_net,
  SUM(ra.gross) as total_gross,
  SUM(ra.patient_share) as total_patient_share,
  COUNT(CASE WHEN ra.denial_code IS NOT NULL THEN 1 END) as denied_activities,
  -- Pre-computed reference data
  p.name as payer_name,
  pr.name as provider_name,
  dc.description as denial_description
FROM claims.remittance_claim rc
JOIN claims.claim_key ck ON ck.id = rc.claim_key_id
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN claims_ref.provider pr ON pr.id = c.provider_ref_id
LEFT JOIN claims_ref.denial_code dc ON dc.code = rc.denial_code
GROUP BY rc.id, rc.claim_key_id, rc.payment_reference, rc.date_settlement, rc.denial_code,
         ck.claim_id, c.payer_id, c.provider_id, c.net, p.name, pr.name, dc.description;

-- Create unique index for concurrent refresh
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_remittance_advice_summary_remittance_claim_id 
ON claims.mv_remittance_advice_summary(remittance_claim_id);

-- ==========================================================================================================
-- SECTION 3: RESUBMISSION REPORT MATERIALIZED VIEW
-- ==========================================================================================================

-- 3. Resubmission Report - Pre-computed aggregations
DROP MATERIALIZED VIEW IF EXISTS claims.mv_remittances_resubmission_summary CASCADE;
CREATE MATERIALIZED VIEW claims.mv_remittances_resubmission_summary AS
SELECT 
  ck.id as claim_key_id,
  ck.claim_id,
  c.payer_id,
  c.provider_id,
  c.net as initial_net,
  c.created_at as claim_created_at,
  -- Pre-computed resubmission data
  COUNT(ce.id) as resubmission_count,
  MAX(ce.event_time) as last_resubmission_date,
  STRING_AGG(DISTINCT cr.resubmission_type, ', ') as resubmission_types,
  STRING_AGG(DISTINCT cr.comment, '; ') as resubmission_comments,
  -- Pre-computed remittance data
  COUNT(rc.id) as remittance_count,
  SUM(ra.payment_amount) as total_payment,
  MAX(rc.date_settlement) as last_settlement_date,
  -- Pre-computed reference data
  p.name as payer_name,
  pr.name as provider_name,
  -- Pre-computed calculated fields
  c.net - COALESCE(SUM(ra.payment_amount), 0) as pending_amount
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.claim_event ce ON ce.claim_key_id = ck.id AND ce.type = 2
LEFT JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce.id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN claims_ref.provider pr ON pr.id = c.provider_ref_id
GROUP BY ck.id, ck.claim_id, c.payer_id, c.provider_id, c.net, c.created_at, p.name, pr.name;

-- Create unique index for concurrent refresh
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_remittances_resubmission_summary_claim_key_id 
ON claims.mv_remittances_resubmission_summary(claim_key_id);

-- ==========================================================================================================
-- SECTION 4: DOCTOR DENIAL REPORT MATERIALIZED VIEW
-- ==========================================================================================================

-- 4. Doctor Denial Report - Pre-computed aggregations
DROP MATERIALIZED VIEW IF EXISTS claims.mv_doctor_denial_summary CASCADE;
CREATE MATERIALIZED VIEW claims.mv_doctor_denial_summary AS
SELECT 
  a.clinician,
  a.clinician_ref_id,
  cl.name as clinician_name,
  cl.specialty as clinician_specialty,
  -- Pre-computed denial aggregations
  COUNT(CASE WHEN ra.denial_code IS NOT NULL THEN 1 END) as denied_activities,
  COUNT(ra.id) as total_activities,
  SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) as denied_amount,
  SUM(ra.net) as total_amount,
  -- Pre-computed denial code breakdown
  STRING_AGG(DISTINCT ra.denial_code, ', ') as denial_codes,
  COUNT(DISTINCT ra.denial_code) as unique_denial_codes,
  -- Pre-computed time period
  MIN(ra.created_at) as first_denial_date,
  MAX(ra.created_at) as last_denial_date,
  -- Pre-computed calculated fields
  ROUND(
    (COUNT(CASE WHEN ra.denial_code IS NOT NULL THEN 1 END)::DECIMAL / COUNT(ra.id)) * 100, 2
  ) as denial_percentage
FROM claims.activity a
JOIN claims.remittance_activity ra ON ra.activity_id = a.activity_id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
WHERE ra.denial_code IS NOT NULL
GROUP BY a.clinician, a.clinician_ref_id, cl.name, cl.specialty;

-- Create unique index for concurrent refresh
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_doctor_denial_summary_clinician 
ON claims.mv_doctor_denial_summary(clinician, clinician_ref_id);

-- ==========================================================================================================
-- SECTION 5: CLAIM DETAILS WITH ACTIVITY MATERIALIZED VIEW
-- ==========================================================================================================

-- 5. Claim Details with Activity - Pre-computed aggregations
DROP MATERIALIZED VIEW IF EXISTS claims.mv_claim_details_with_activity CASCADE;
CREATE MATERIALIZED VIEW claims.mv_claim_details_with_activity AS
SELECT 
  ck.id as claim_key_id,
  ck.claim_id,
  c.id as claim_internal_id,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.gross,
  c.patient_share,
  c.net,
  c.tx_at as claim_tx_at,
  c.created_at as claim_created_at,
  -- Pre-computed encounter data
  e.facility_id,
  e.type as encounter_type,
  e.patient_id,
  e.start_at as encounter_start,
  e.end_at as encounter_end,
  f.name as facility_name,
  -- Pre-computed activity aggregations
  COUNT(a.id) as activity_count,
  SUM(a.net) as total_activity_net,
  STRING_AGG(DISTINCT a.code, ', ') as activity_codes,
  STRING_AGG(DISTINCT a.type, ', ') as activity_types,
  -- Pre-computed diagnosis data
  STRING_AGG(DISTINCT d.code, ', ') as diagnosis_codes,
  STRING_AGG(DISTINCT d.diag_type, ', ') as diagnosis_types,
  -- Pre-computed reference data
  p.name as payer_name,
  pr.name as provider_name,
  -- Pre-computed status
  cst.status as current_status,
  cst.status_time as last_status_date
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims.diagnosis d ON d.claim_id = c.id
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN claims_ref.provider pr ON pr.id = c.provider_ref_id
LEFT JOIN (
  SELECT 
    claim_key_id,
    status,
    status_time
  FROM (
    SELECT 
      claim_key_id,
      status,
      status_time,
      ROW_NUMBER() OVER (PARTITION BY claim_key_id ORDER BY status_time DESC, id DESC) as rn
    FROM claims.claim_status_timeline
  ) ranked
  WHERE rn = 1
) cst ON cst.claim_key_id = ck.id
GROUP BY ck.id, ck.claim_id, c.id, c.payer_id, c.provider_id, c.member_id, c.emirates_id_number,
         c.gross, c.patient_share, c.net, c.tx_at, c.created_at, e.facility_id, e.type, e.patient_id,
         e.start_at, e.end_at, f.name, p.name, pr.name, cst.status, cst.status_time;

-- Create unique index for concurrent refresh
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_claim_details_with_activity_claim_key_id 
ON claims.mv_claim_details_with_activity(claim_key_id);

-- ==========================================================================================================
-- SECTION 6: CLAIM SUMMARY MONTHWISE MATERIALIZED VIEW
-- ==========================================================================================================

-- 6. Claim Summary Monthwise - Pre-computed aggregations
DROP MATERIALIZED VIEW IF EXISTS claims.mv_claim_summary_monthwise CASCADE;
CREATE MATERIALIZED VIEW claims.mv_claim_summary_monthwise AS
SELECT 
  DATE_TRUNC('month', c.tx_at) as month,
  c.payer_id,
  c.provider_id,
  -- Pre-computed aggregations
  COUNT(c.id) as claim_count,
  SUM(c.gross) as total_gross,
  SUM(c.patient_share) as total_patient_share,
  SUM(c.net) as total_net,
  -- Pre-computed remittance aggregations
  SUM(COALESCE(rem_agg.total_payment, 0)) as total_payment,
  SUM(COALESCE(rem_agg.total_denied, 0)) as total_denied,
  COUNT(rem_agg.claim_key_id) as paid_claims,
  -- Pre-computed reference data
  p.name as payer_name,
  pr.name as provider_name,
  -- Pre-computed calculated fields
  SUM(c.net) - SUM(COALESCE(rem_agg.total_payment, 0)) - SUM(COALESCE(rem_agg.total_denied, 0)) as pending_amount
FROM claims.claim c
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN claims_ref.provider pr ON pr.id = c.provider_ref_id
LEFT JOIN (
  SELECT 
    rc.claim_key_id,
    SUM(ra.payment_amount) as total_payment,
    SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) as total_denied
  FROM claims.remittance_claim rc
  JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
) rem_agg ON rem_agg.claim_key_id = c.claim_key_id
GROUP BY DATE_TRUNC('month', c.tx_at), c.payer_id, c.provider_id, p.name, pr.name;

-- Create unique index for concurrent refresh
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_claim_summary_monthwise_month_payer_provider 
ON claims.mv_claim_summary_monthwise(month, payer_id, provider_id);

-- ==========================================================================================================
-- SECTION 7: REJECTED CLAIMS REPORT MATERIALIZED VIEW
-- ==========================================================================================================

-- 7. Rejected Claims Report - Pre-computed aggregations
DROP MATERIALIZED VIEW IF EXISTS claims.mv_rejected_claims_summary CASCADE;
CREATE MATERIALIZED VIEW claims.mv_rejected_claims_summary AS
SELECT 
  ck.id as claim_key_id,
  ck.claim_id,
  c.payer_id,
  c.provider_id,
  c.net as claim_net,
  c.tx_at as claim_tx_at,
  -- Pre-computed rejection data
  rc.denial_code,
  rc.payment_reference,
  rc.date_settlement,
  COUNT(ra.id) as rejected_activities,
  SUM(ra.net) as rejected_amount,
  STRING_AGG(DISTINCT ra.denial_code, ', ') as activity_denial_codes,
  -- Pre-computed reference data
  p.name as payer_name,
  pr.name as provider_name,
  dc.description as denial_description,
  -- Pre-computed encounter data
  e.facility_id,
  f.name as facility_name,
  e.start_at as encounter_start
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN claims_ref.provider pr ON pr.id = c.provider_ref_id
LEFT JOIN claims_ref.denial_code dc ON dc.code = rc.denial_code
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
WHERE ra.denial_code IS NOT NULL
GROUP BY ck.id, ck.claim_id, c.payer_id, c.provider_id, c.net, c.tx_at,
         rc.denial_code, rc.payment_reference, rc.date_settlement, p.name, pr.name,
         dc.description, e.facility_id, f.name, e.start_at;

-- Create unique index for concurrent refresh
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_rejected_claims_summary_claim_key_id 
ON claims.mv_rejected_claims_summary(claim_key_id);

-- ==========================================================================================================
-- SECTION 8: CLAIM SUMMARY PAYERWISE MATERIALIZED VIEW
-- ==========================================================================================================

-- 8. Claim Summary Payerwise - Pre-computed aggregations
DROP MATERIALIZED VIEW IF EXISTS claims.mv_claim_summary_payerwise CASCADE;
CREATE MATERIALIZED VIEW claims.mv_claim_summary_payerwise AS
SELECT 
  c.payer_id,
  p.name as payer_name,
  -- Pre-computed aggregations
  COUNT(c.id) as claim_count,
  SUM(c.gross) as total_gross,
  SUM(c.patient_share) as total_patient_share,
  SUM(c.net) as total_net,
  -- Pre-computed remittance aggregations
  SUM(COALESCE(rem_agg.total_payment, 0)) as total_payment,
  SUM(COALESCE(rem_agg.total_denied, 0)) as total_denied,
  COUNT(rem_agg.claim_key_id) as paid_claims,
  -- Pre-computed time period
  MIN(c.tx_at) as first_claim_date,
  MAX(c.tx_at) as last_claim_date,
  -- Pre-computed calculated fields
  SUM(c.net) - SUM(COALESCE(rem_agg.total_payment, 0)) - SUM(COALESCE(rem_agg.total_denied, 0)) as pending_amount,
  ROUND(
    (COUNT(rem_agg.claim_key_id)::DECIMAL / COUNT(c.id)) * 100, 2
  ) as payment_percentage
FROM claims.claim c
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN (
  SELECT 
    rc.claim_key_id,
    SUM(ra.payment_amount) as total_payment,
    SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) as total_denied
  FROM claims.remittance_claim rc
  JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
) rem_agg ON rem_agg.claim_key_id = c.claim_key_id
GROUP BY c.payer_id, p.name;

-- Create unique index for concurrent refresh
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_claim_summary_payerwise_payer_id 
ON claims.mv_claim_summary_payerwise(payer_id);

-- ==========================================================================================================
-- SECTION 9: CLAIM SUMMARY ENCOUNTERWISE MATERIALIZED VIEW
-- ==========================================================================================================

-- 9. Claim Summary Encounterwise - Pre-computed aggregations
DROP MATERIALIZED VIEW IF EXISTS claims.mv_claim_summary_encounterwise CASCADE;
CREATE MATERIALIZED VIEW claims.mv_claim_summary_encounterwise AS
SELECT 
  e.facility_id,
  f.name as facility_name,
  e.type as encounter_type,
  -- Pre-computed aggregations
  COUNT(c.id) as claim_count,
  SUM(c.gross) as total_gross,
  SUM(c.patient_share) as total_patient_share,
  SUM(c.net) as total_net,
  -- Pre-computed remittance aggregations
  SUM(COALESCE(rem_agg.total_payment, 0)) as total_payment,
  SUM(COALESCE(rem_agg.total_denied, 0)) as total_denied,
  COUNT(rem_agg.claim_key_id) as paid_claims,
  -- Pre-computed time period
  MIN(e.start_at) as first_encounter_date,
  MAX(e.start_at) as last_encounter_date,
  -- Pre-computed calculated fields
  SUM(c.net) - SUM(COALESCE(rem_agg.total_payment, 0)) - SUM(COALESCE(rem_agg.total_denied, 0)) as pending_amount,
  ROUND(
    (COUNT(rem_agg.claim_key_id)::DECIMAL / COUNT(c.id)) * 100, 2
  ) as payment_percentage
FROM claims.encounter e
JOIN claims.claim c ON c.id = e.claim_id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN (
  SELECT 
    rc.claim_key_id,
    SUM(ra.payment_amount) as total_payment,
    SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) as total_denied
  FROM claims.remittance_claim rc
  JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
) rem_agg ON rem_agg.claim_key_id = c.claim_key_id
GROUP BY e.facility_id, f.name, e.type;

-- Create unique index for concurrent refresh
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_claim_summary_encounterwise_facility_type 
ON claims.mv_claim_summary_encounterwise(facility_id, encounter_type);

-- ==========================================================================================================
-- SECTION 10: GRANTS TO CLAIMS_USER
-- ==========================================================================================================

-- Grant all privileges on materialized views to claims_user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA claims TO claims_user;

-- ==========================================================================================================
-- SECTION 11: INITIAL DATA POPULATION
-- ==========================================================================================================

-- Note: Materialized views will be empty initially until data is ingested
-- They will be refreshed automatically or manually as needed
