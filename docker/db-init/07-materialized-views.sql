-- ==========================================================================================================
-- MATERIALIZED VIEWS - PRE-COMPUTED AGGREGATIONS FOR SUB-SECOND PERFORMANCE
-- ==========================================================================================================
-- 
-- Purpose: Create all materialized views for claims reporting with sub-second performance
-- Version: 2.0
-- Date: 2025-10-24
-- 
-- This script creates materialized views for:
-- - Balance amount summary with cumulative-with-cap logic
-- - Remittance advice summary by payer
-- - Doctor denial summary with risk analysis
-- - Claims monthly aggregation
-- - Claim details complete with activity timeline
-- - Resubmission cycles tracking
-- - Remittances resubmission activity level
-- - Rejected claims summary
-- - Claim summary by payer and encounter type
-- - Balance amount overall, initial, and resubmission views
-- - Monthly aggregation tables
--
-- Note: Extensions and schemas are created in 01-init-db.sql
-- Note: Core tables are created in 02-core-tables.sql
-- Note: Reference data is created in 03-ref-data-tables.sql
-- Note: SQL views are created in 06-report-views.sql
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: BALANCE AMOUNT MATERIALIZED VIEWS
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_balance_amount_summary (Pre-computed balance amount aggregations)
-- ----------------------------------------------------------------------------------------------------------
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
  -- CUMULATIVE-WITH-CAP: Aggregate claim-level remittance metrics from pre-computed per-activity summary
  -- Using cumulative-with-cap semantics via claim_activity_summary to prevent overcounting
  SELECT 
    cas.claim_key_id,
    SUM(cas.paid_amount)                                  AS total_payment,      -- capped paid across activities
    SUM(cas.denied_amount)                                AS total_denied,       -- denied only when latest denial and zero paid
    MAX(cas.remittance_count)                             AS remittance_count,   -- per-claim max across activities
    MIN(rc.date_settlement)                               AS first_remittance_date,
    MAX(rc.date_settlement)                               AS last_remittance_date
  FROM claims.claim_activity_summary cas
  LEFT JOIN claims.remittance_claim rc 
    ON rc.claim_key_id = cas.claim_key_id
  GROUP BY cas.claim_key_id
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
    e.claim_id,
    MAX(e.facility_id) as facility_id,
    MIN(e.start_at) as encounter_start,
    MAX(f.name) as facility_name,
    EXTRACT(DAYS FROM (CURRENT_DATE - DATE_TRUNC('day', MIN(e.start_at)))) as aging_days
  FROM claims.encounter e
  LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
  GROUP BY e.claim_id
) enc_agg ON enc_agg.claim_id = c.id;

-- SUB-SECOND PERFORMANCE INDEXES
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_balance_unique 
ON claims.mv_balance_amount_summary(claim_key_id);

CREATE INDEX IF NOT EXISTS idx_mv_balance_covering 
ON claims.mv_balance_amount_summary(claim_key_id, payer_id, provider_id) 
INCLUDE (pending_amount, aging_days, current_status);

CREATE INDEX IF NOT EXISTS idx_mv_balance_facility 
ON claims.mv_balance_amount_summary(facility_id, encounter_start);

CREATE INDEX IF NOT EXISTS idx_mv_balance_status 
ON claims.mv_balance_amount_summary(current_status, last_status_date);

COMMENT ON MATERIALIZED VIEW claims.mv_balance_amount_summary IS 'Pre-computed balance amount aggregations for sub-second report performance';

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_balance_amount_overall (Overall balance amount view)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_balance_amount_overall CASCADE;
CREATE MATERIALIZED VIEW claims.mv_balance_amount_overall AS
SELECT * FROM claims.mv_balance_amount_summary;

COMMENT ON MATERIALIZED VIEW claims.mv_balance_amount_overall IS 'Overall balance amount view (alias for mv_balance_amount_summary)';

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_balance_amount_initial (Initial balance amount view)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_balance_amount_initial CASCADE;
CREATE MATERIALIZED VIEW claims.mv_balance_amount_initial AS
SELECT * FROM claims.mv_balance_amount_summary WHERE remittance_count = 0;

COMMENT ON MATERIALIZED VIEW claims.mv_balance_amount_initial IS 'Initial balance amount view (no remittances yet)';

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_balance_amount_resubmission (Resubmission balance amount view)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_balance_amount_resubmission CASCADE;
CREATE MATERIALIZED VIEW claims.mv_balance_amount_resubmission AS
SELECT * FROM claims.mv_balance_amount_summary WHERE resubmission_count > 0;

COMMENT ON MATERIALIZED VIEW claims.mv_balance_amount_resubmission IS 'Resubmission balance amount view (has resubmissions)';

-- ==========================================================================================================
-- SECTION 2: REMITTANCE ADVICE MATERIALIZED VIEWS
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_remittance_advice_summary (Pre-aggregated by payer)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_remittance_advice_summary CASCADE;
CREATE MATERIALIZED VIEW claims.mv_remittance_advice_summary AS
WITH claim_remittance_agg AS (
  -- CUMULATIVE-WITH-CAP: Pre-aggregate all remittance data per claim_key_id using claim_activity_summary
  -- Using cumulative-with-cap semantics to prevent overcounting from multiple remittances per activity
  SELECT 
    cas.claim_key_id,
    -- Aggregate all remittances for this claim using pre-computed activity summary
    MAX(cas.remittance_count) as remittance_count,                    -- max across activities
    SUM(cas.paid_amount) as total_payment,                           -- capped paid across activities
    SUM(cas.submitted_amount) as total_remitted,                     -- submitted as remitted baseline
    COUNT(CASE WHEN cas.activity_status = 'REJECTED' THEN 1 END) as denied_count,  -- activities with latest denial
    SUM(cas.denied_amount) as denied_amount,                         -- denied only when latest denial and zero paid
    COUNT(cas.activity_id) as total_activity_count,                  -- count of activities
    -- Use the most recent remittance for payer/provider info (from remittance_claim)
    (ARRAY_AGG(rc.id_payer ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_id_payer,
    (ARRAY_AGG(rc.provider_id ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_provider_id,
    (ARRAY_AGG(rc.id ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_remittance_claim_id,
    MAX(rc.date_settlement) as latest_settlement_date,
    MAX(rc.payment_reference) as latest_payment_reference,
    -- Additional metrics
    MIN(rc.date_settlement) as first_settlement_date,
    (SELECT STRING_AGG(DISTINCT denial_code, ', ') 
     FROM UNNEST(cas.denial_codes) AS denial_code) as all_denial_codes  -- flatten denial codes array
  FROM claims.claim_activity_summary cas
  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = cas.claim_key_id
  GROUP BY cas.claim_key_id, cas.denial_codes
)
SELECT 
  -- Core identifiers (claim-level)
  ck.id as claim_key_id,
  ck.claim_id,
  c.id as claim_internal_id,
  
  -- Payer information (from latest remittance)
  cra.latest_id_payer as id_payer,
  COALESCE(p.name, cra.latest_id_payer, 'Unknown Payer') as payer_name,
  c.payer_ref_id,
  
  -- Provider information (from latest remittance)
  cra.latest_provider_id as provider_id,
  COALESCE(pr.name, cra.latest_provider_id, 'Unknown Provider') as provider_name,
  c.provider_ref_id,
  
  -- Settlement information (from latest remittance)
  cra.latest_settlement_date as date_settlement,
  cra.latest_payment_reference as payment_reference,
  cra.latest_remittance_claim_id as remittance_claim_id,
  
  -- Aggregated activity metrics (across all remittances)
  cra.total_activity_count as activity_count,
  COALESCE(cra.total_payment, 0) as total_payment,
  COALESCE(cra.total_remitted, 0) as total_remitted,
  COALESCE(cra.denied_count, 0) as denied_count,
  COALESCE(cra.denied_amount, 0) as denied_amount,
  
  -- Additional metrics
  cra.remittance_count,
  cra.first_settlement_date,
  cra.all_denial_codes,
  
  -- Calculated fields
  CASE 
    WHEN COALESCE(cra.total_remitted, 0) > 0 THEN
      ROUND((COALESCE(cra.total_payment, 0) / COALESCE(cra.total_remitted, 0)) * 100, 2)
    ELSE 0 
  END as collection_rate,
  
  CASE 
    WHEN COALESCE(cra.denied_count, 0) > 0 THEN 'Has Denials'
    WHEN COALESCE(cra.total_payment, 0) = COALESCE(cra.total_remitted, 0) THEN 'Fully Paid'
    WHEN COALESCE(cra.total_payment, 0) > 0 THEN 'Partially Paid'
    ELSE 'No Payment'
  END as payment_status

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claim_remittance_agg cra ON cra.claim_key_id = ck.id
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN claims_ref.provider pr ON pr.id = c.provider_ref_id
WHERE cra.claim_key_id IS NOT NULL; -- Only include claims that have remittance data

-- SUB-SECOND PERFORMANCE INDEXES
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_remittance_unique 
ON claims.mv_remittance_advice_summary(claim_key_id);

CREATE INDEX IF NOT EXISTS idx_mv_remittance_covering 
ON claims.mv_remittance_advice_summary(id_payer, date_settlement) 
INCLUDE (total_payment, total_remitted, denied_amount);

CREATE INDEX IF NOT EXISTS idx_mv_remittance_provider 
ON claims.mv_remittance_advice_summary(provider_id, date_settlement);

CREATE INDEX IF NOT EXISTS idx_mv_remittance_status 
ON claims.mv_remittance_advice_summary(payment_status, date_settlement);

COMMENT ON MATERIALIZED VIEW claims.mv_remittance_advice_summary IS 'Pre-aggregated remittance advice by payer with cumulative-with-cap logic';

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_remittance_advice_header (Remittance advice header)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_remittance_advice_header CASCADE;
CREATE MATERIALIZED VIEW claims.mv_remittance_advice_header AS
SELECT 
  r.id AS remittance_id,
  r.receiver_name,
  r.receiver_id,
  r.created_at AS remittance_date,
  r.payment_reference,
  COUNT(DISTINCT rc.id) AS claim_count,
  COUNT(DISTINCT ra.id) AS activity_count,
  SUM(ra.payment_amount) AS total_payment_amount,
  SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS total_denied_amount,
  SUM(ra.net) AS total_remittance_amount
FROM claims.remittance r
LEFT JOIN claims.remittance_claim rc ON rc.remittance_id = r.id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
GROUP BY r.id, r.receiver_name, r.receiver_id, r.created_at, r.payment_reference;

COMMENT ON MATERIALIZED VIEW claims.mv_remittance_advice_header IS 'Remittance advice header information with summary statistics';

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_remittance_advice_claim_wise (Remittance advice claim-wise)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_remittance_advice_claim_wise CASCADE;
CREATE MATERIALIZED VIEW claims.mv_remittance_advice_claim_wise AS
SELECT 
  r.id AS remittance_id,
  r.receiver_name,
  r.receiver_id,
  r.created_at AS remittance_date,
  r.payment_reference,
  rc.id AS remittance_claim_id,
  rc.date_settlement,
  ck.claim_id AS external_claim_id,
  c.id AS claim_id_internal,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.gross AS claim_gross_amount,
  c.patient_share AS claim_patient_share,
  c.net AS claim_net_amount,
  c.tx_at AS claim_submission_date,
  
  -- Encounter information
  e.facility_id,
  e.type AS encounter_type,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  
  -- Remittance claim summary
  COUNT(DISTINCT ra.id) AS activity_count,
  SUM(ra.payment_amount) AS total_payment_amount,
  SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS total_denied_amount,
  SUM(ra.net) AS total_remittance_amount,
  
  -- Reference data
  f.name AS facility_name,
  p.name AS provider_name,
  pay.name AS payer_name,
  et.description AS encounter_type_description

FROM claims.remittance r
JOIN claims.remittance_claim rc ON rc.remittance_id = r.id
JOIN claims.claim_key ck ON ck.id = rc.claim_key_id
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
GROUP BY 
  r.id, r.receiver_name, r.receiver_id, r.created_at, r.payment_reference,
  rc.id, rc.date_settlement, ck.claim_id, c.id, c.payer_id, c.provider_id, 
  c.member_id, c.emirates_id_number, c.gross, c.patient_share, c.net, c.tx_at,
  e.facility_id, e.type, e.start_at, e.end_at,
  f.name, p.name, pay.name, et.description;

COMMENT ON MATERIALIZED VIEW claims.mv_remittance_advice_claim_wise IS 'Remittance advice claim-wise details with summary statistics';

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_remittance_advice_activity_wise (Remittance advice activity-wise)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_remittance_advice_activity_wise CASCADE;
CREATE MATERIALIZED VIEW claims.mv_remittance_advice_activity_wise AS
SELECT 
  r.id AS remittance_id,
  r.receiver_name,
  r.receiver_id,
  r.created_at AS remittance_date,
  r.payment_reference,
  rc.id AS remittance_claim_id,
  rc.date_settlement,
  ra.id AS remittance_activity_id,
  ra.activity_id,
  ra.net AS activity_net_amount,
  ra.payment_amount AS activity_payment_amount,
  ra.denial_code,
  ra.denial_reason,
  ra.created_at AS remittance_activity_created_at,
  
  -- Activity information
  a.code AS activity_code,
  a.description AS activity_description,
  a.clinician AS activity_clinician,
  a.created_at AS activity_created_at,
  
  -- Claim information
  ck.claim_id AS external_claim_id,
  c.id AS claim_id_internal,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.net AS claim_net_amount,
  c.tx_at AS claim_submission_date,
  
  -- Encounter information
  e.facility_id,
  e.type AS encounter_type,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  
  -- Reference data
  f.name AS facility_name,
  p.name AS provider_name,
  pay.name AS payer_name,
  cl.name AS clinician_name,
  et.description AS encounter_type_description,
  ac.description AS activity_code_description,
  dc.description AS denial_code_description

FROM claims.remittance r
JOIN claims.remittance_claim rc ON rc.remittance_id = r.id
JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
JOIN claims.activity a ON a.id = ra.activity_id
JOIN claims.claim_key ck ON ck.id = rc.claim_key_id
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
LEFT JOIN claims_ref.activity_code ac ON ac.id = a.activity_code_ref_id
LEFT JOIN claims_ref.denial_code dc ON dc.code = ra.denial_code;

COMMENT ON MATERIALIZED VIEW claims.mv_remittance_advice_activity_wise IS 'Remittance advice activity-wise details with comprehensive reference data';

-- ==========================================================================================================
-- SECTION 3: DOCTOR DENIAL MATERIALIZED VIEWS
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_doctor_denial_summary (Doctor denial summary with risk analysis)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_doctor_denial_summary CASCADE;
CREATE MATERIALIZED VIEW claims.mv_doctor_denial_summary AS
WITH doctor_denial_stats AS (
  SELECT 
    a.clinician,
    cl.name AS clinician_name,
    cl.clinician_code,
    cl.specialty AS clinician_specialty,
    COUNT(DISTINCT a.id) AS total_activities,
    COUNT(DISTINCT CASE WHEN ra.denial_code IS NOT NULL THEN a.id END) AS denied_activities,
    COUNT(DISTINCT ck.claim_id) AS total_claims,
    COUNT(DISTINCT CASE WHEN ra.denial_code IS NOT NULL THEN ck.claim_id END) AS denied_claims,
    SUM(a.net) AS total_activity_amount,
    SUM(CASE WHEN ra.denial_code IS NOT NULL THEN a.net ELSE 0 END) AS denied_activity_amount,
    ROUND(
      (COUNT(DISTINCT CASE WHEN ra.denial_code IS NOT NULL THEN a.id END)::DECIMAL / 
       COUNT(DISTINCT a.id)) * 100, 2
    ) AS activity_denial_rate_percentage,
    ROUND(
      (COUNT(DISTINCT CASE WHEN ra.denial_code IS NOT NULL THEN ck.claim_id END)::DECIMAL / 
       COUNT(DISTINCT ck.claim_id)) * 100, 2
    ) AS claim_denial_rate_percentage,
    ROUND(
      (SUM(CASE WHEN ra.denial_code IS NOT NULL THEN a.net ELSE 0 END)::DECIMAL / 
       SUM(a.net)) * 100, 2
    ) AS amount_denial_rate_percentage
  FROM claims.activity a
  JOIN claims.claim c ON c.id = a.claim_id
  JOIN claims.claim_key ck ON ck.id = c.claim_key_id
  LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
  LEFT JOIN claims.remittance_activity ra ON ra.activity_id = a.id
  WHERE a.clinician IS NOT NULL
  GROUP BY a.clinician, cl.name, cl.clinician_code, cl.specialty
)
SELECT 
  clinician,
  clinician_name,
  clinician_code,
  clinician_specialty,
  total_activities,
  denied_activities,
  total_claims,
  denied_claims,
  total_activity_amount,
  denied_activity_amount,
  activity_denial_rate_percentage,
  claim_denial_rate_percentage,
  amount_denial_rate_percentage,
  CASE 
    WHEN activity_denial_rate_percentage >= 50 THEN 'HIGH'
    WHEN activity_denial_rate_percentage >= 25 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS denial_risk_level
FROM doctor_denial_stats
ORDER BY denied_activity_amount DESC, activity_denial_rate_percentage DESC;

-- SUB-SECOND PERFORMANCE INDEXES
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_doctor_denial_unique 
ON claims.mv_doctor_denial_summary(clinician);

CREATE INDEX IF NOT EXISTS idx_mv_doctor_denial_risk 
ON claims.mv_doctor_denial_summary(denial_risk_level, activity_denial_rate_percentage);

CREATE INDEX IF NOT EXISTS idx_mv_doctor_denial_amount 
ON claims.mv_doctor_denial_summary(denied_activity_amount DESC);

COMMENT ON MATERIALIZED VIEW claims.mv_doctor_denial_summary IS 'Doctor denial summary with risk analysis and comprehensive metrics';

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_doctor_denial_high_denial (High denial rate doctors)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_doctor_denial_high_denial CASCADE;
CREATE MATERIALIZED VIEW claims.mv_doctor_denial_high_denial AS
SELECT * FROM claims.mv_doctor_denial_summary WHERE denial_risk_level = 'HIGH';

COMMENT ON MATERIALIZED VIEW claims.mv_doctor_denial_high_denial IS 'High denial rate doctors with risk level classification';

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_doctor_denial_detail (Detailed doctor denial information)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_doctor_denial_detail CASCADE;
CREATE MATERIALIZED VIEW claims.mv_doctor_denial_detail AS
SELECT 
  a.clinician,
  cl.name AS clinician_name,
  cl.clinician_code,
  cl.specialty AS clinician_specialty,
  a.id AS activity_id,
  a.code AS activity_code,
  a.description AS activity_description,
  a.net AS activity_net_amount,
  a.created_at AS activity_created_at,
  
  -- Claim information
  ck.claim_id AS external_claim_id,
  c.id AS claim_id_internal,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.net AS claim_net_amount,
  c.tx_at AS claim_submission_date,
  
  -- Encounter information
  e.facility_id,
  e.type AS encounter_type,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  
  -- Denial information
  ra.denial_code,
  ra.denial_reason,
  ra.created_at AS denial_date,
  rc.date_settlement,
  rc.payment_reference,
  r.receiver_name,
  r.receiver_id,
  
  -- Reference data
  f.name AS facility_name,
  p.name AS provider_name,
  pay.name AS payer_name,
  et.description AS encounter_type_description,
  ac.description AS activity_code_description,
  dc.description AS denial_code_description

FROM claims.activity a
JOIN claims.claim c ON c.id = a.claim_id
JOIN claims.claim_key ck ON ck.id = c.claim_key_id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
LEFT JOIN claims_ref.activity_code ac ON ac.id = a.activity_code_ref_id
LEFT JOIN claims_ref.denial_code dc ON dc.code = ra.denial_code
LEFT JOIN claims.remittance_activity ra ON ra.activity_id = a.id
LEFT JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
WHERE ra.denial_code IS NOT NULL  -- Only denied activities
  AND a.clinician IS NOT NULL     -- Only activities with clinician
ORDER BY a.clinician, ra.created_at DESC;

COMMENT ON MATERIALIZED VIEW claims.mv_doctor_denial_detail IS 'Detailed doctor denial information with activity and claim details';

-- ==========================================================================================================
-- SECTION 4: CLAIMS MONTHLY AGGREGATION MATERIALIZED VIEWS
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_claims_monthly_agg (Monthly claims aggregation)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_claims_monthly_agg CASCADE;
CREATE MATERIALIZED VIEW claims.mv_claims_monthly_agg AS
SELECT 
  DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)) AS month_year,
  EXTRACT(YEAR FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))) AS year,
  EXTRACT(MONTH FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))) AS month,
  
  -- Count Metrics
  COUNT(DISTINCT ck.claim_id) AS count_claims,
  COUNT(DISTINCT cas.activity_id) AS remitted_count,
  COUNT(DISTINCT CASE WHEN cas.activity_status = 'FULLY_PAID' THEN cas.activity_id END) AS fully_paid_count,
  COUNT(DISTINCT CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.activity_id END) AS partially_paid_count,
  COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS fully_rejected_count,
  COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS rejection_count,
  COUNT(DISTINCT CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.activity_id END) AS taken_back_count,
  COUNT(DISTINCT CASE WHEN cas.activity_status = 'PENDING' THEN cas.activity_id END) AS pending_remittance_count,
  COUNT(DISTINCT CASE WHEN c.payer_id = 'Self-Paid' THEN ck.claim_id END) AS self_pay_count,

  -- Amount Metrics
  SUM(DISTINCT c.net) AS claim_amount,
  SUM(DISTINCT c.net) AS initial_claim_amount,
  SUM(COALESCE(cas.paid_amount, 0)) AS remitted_amount,
  SUM(COALESCE(cas.paid_amount, 0)) AS remitted_net_amount,
  SUM(COALESCE(cas.paid_amount, 0)) AS fully_paid_amount,
  SUM(CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.paid_amount ELSE 0 END) AS partially_paid_amount,
  SUM(COALESCE(cas.denied_amount, 0)) AS fully_rejected_amount,
  SUM(COALESCE(cas.denied_amount, 0)) AS rejected_amount,
  SUM(CASE WHEN cas.activity_status = 'PENDING' THEN cas.submitted_amount ELSE 0 END) AS pending_remittance_amount,
  SUM(CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.taken_back_amount ELSE 0 END) AS taken_back_amount,
  SUM(CASE WHEN c.payer_id = 'Self-Paid' THEN c.net ELSE 0 END) AS self_pay_amount,

  -- Facility and Health Authority
  e.facility_id,
  f.name AS facility_name,
  COALESCE(p2.payer_code, 'Unknown') AS health_authority,

  -- Percentage Calculations
  CASE
    WHEN SUM(c.net) > 0 THEN
      ROUND((SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) / SUM(c.net)) * 100, 2)
    ELSE 0
  END AS rejected_percentage_on_initial,
  CASE
  WHEN (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) > 0 THEN
      ROUND(
          (
              SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)
              /
              (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END))
          ) * 100, 2)
      ELSE 0
  END AS rejected_percentage_on_remittance,
  CASE
      WHEN SUM(c.net) > 0 THEN
          ROUND((SUM(COALESCE(ra.payment_amount, 0)) / SUM(c.net)) * 100, 2)
      ELSE 0
  END AS collection_rate

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
GROUP BY 
  DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)),
  e.facility_id,
  f.name,
  COALESCE(p2.payer_code, 'Unknown')
ORDER BY 
  DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)) DESC,
  e.facility_id,
  f.name;

-- SUB-SECOND PERFORMANCE INDEXES
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_claims_monthly_unique 
ON claims.mv_claims_monthly_agg(month_year, facility_id, health_authority);

CREATE INDEX IF NOT EXISTS idx_mv_claims_monthly_year 
ON claims.mv_claims_monthly_agg(year, month);

CREATE INDEX IF NOT EXISTS idx_mv_claims_monthly_facility 
ON claims.mv_claims_monthly_agg(facility_id, month_year);

COMMENT ON MATERIALIZED VIEW claims.mv_claims_monthly_agg IS 'Monthly claims aggregation with comprehensive metrics';

-- ==========================================================================================================
-- SECTION 5: CLAIM DETAILS COMPLETE MATERIALIZED VIEW
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_claim_details_complete (Complete claim details with activity timeline)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_claim_details_complete CASCADE;
CREATE MATERIALIZED VIEW claims.mv_claim_details_complete AS
WITH activity_timeline AS (
  -- Get activity timeline with remittance and resubmission data
  SELECT 
    a.id AS activity_id,
    a.claim_id,
    a.code AS activity_code,
    a.description AS activity_description,
    a.net AS activity_net_amount,
    a.created_at AS activity_created_at,
    a.clinician AS activity_clinician,
    
    -- Remittance data for this activity
    ra.payment_amount AS activity_payment_amount,
    ra.denial_code AS activity_denial_code,
    ra.denial_reason AS activity_denial_reason,
    ra.created_at AS remittance_activity_created_at,
    rc.date_settlement AS remittance_date,
    rc.payment_reference,
    r.receiver_name,
    r.receiver_id,
    
    -- Resubmission data for this activity
    cr.comment AS resubmission_comment,
    cr.resubmission_type,
    ce.event_time AS resubmission_date,
    
    -- Activity status
    CASE 
      WHEN ra.payment_amount > 0 THEN 'PAID'
      WHEN ra.denial_code IS NOT NULL THEN 'DENIED'
      ELSE 'PENDING'
    END AS activity_status,
    
    ROW_NUMBER() OVER (PARTITION BY a.id ORDER BY ra.created_at DESC) AS remittance_sequence,
    ROW_NUMBER() OVER (PARTITION BY a.id ORDER BY ce.event_time DESC) AS resubmission_sequence
    
  FROM claims.activity a
  LEFT JOIN claims.remittance_activity ra ON ra.activity_id = a.id
  LEFT JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
  LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
  LEFT JOIN claims.claim_event ce ON ce.activity_id = a.id AND ce.type = 2  -- RESUBMISSION events
  LEFT JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce.id
)
SELECT 
  -- Claim information
  ck.id AS claim_key_id,
  ck.claim_id AS external_claim_id,
  c.id AS claim_id_internal,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.gross AS claim_gross_amount,
  c.patient_share AS claim_patient_share,
  c.net AS claim_net_amount,
  c.tx_at AS claim_submission_date,
  c.comments AS claim_comments,
  
  -- Encounter information
  e.facility_id,
  e.type AS encounter_type,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  e.patient_id,
  
  -- Activity information
  at.activity_id,
  at.activity_code,
  at.activity_description,
  at.activity_net_amount,
  at.activity_created_at,
  at.activity_clinician,
  
  -- Remittance information
  at.activity_payment_amount,
  at.activity_denial_code,
  at.activity_denial_reason,
  at.remittance_activity_created_at,
  at.remittance_date,
  at.payment_reference,
  at.receiver_name,
  at.receiver_id,
  
  -- Resubmission information
  at.resubmission_comment,
  at.resubmission_type,
  at.resubmission_date,
  
  -- Status and sequence information
  at.activity_status,
  at.remittance_sequence,
  at.resubmission_sequence,
  
  -- Reference data
  f.name AS facility_name,
  f.facility_code,
  p.name AS provider_name,
  p.provider_code,
  pay.name AS payer_name,
  pay.payer_code,
  cl.name AS clinician_name,
  cl.clinician_code,
  ac.description AS activity_code_description,
  et.description AS encounter_type_description

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
LEFT JOIN activity_timeline at ON at.claim_id = c.id
WHERE at.remittance_sequence = 1 OR at.remittance_sequence IS NULL  -- Get latest remittance per activity
ORDER BY ck.claim_id, at.activity_created_at;

-- SUB-SECOND PERFORMANCE INDEXES
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_claim_details_unique 
ON claims.mv_claim_details_complete(claim_key_id, activity_id);

CREATE INDEX IF NOT EXISTS idx_mv_claim_details_claim 
ON claims.mv_claim_details_complete(external_claim_id, claim_submission_date);

CREATE INDEX IF NOT EXISTS idx_mv_claim_details_activity 
ON claims.mv_claim_details_complete(activity_id, activity_status);

COMMENT ON MATERIALIZED VIEW claims.mv_claim_details_complete IS 'Complete claim details with activity timeline and remittance/resubmission data';

-- ==========================================================================================================
-- SECTION 6: RESUBMISSION CYCLES MATERIALIZED VIEW
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_resubmission_cycles (Resubmission cycles tracking)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_resubmission_cycles CASCADE;
CREATE MATERIALIZED VIEW claims.mv_resubmission_cycles AS
WITH resubmission_cycles AS (
  SELECT 
    ce.claim_key_id,
    ce.activity_id,
    ce.event_time AS resubmission_date,
    cr.comment AS resubmission_comment,
    cr.resubmission_type,
    ROW_NUMBER() OVER (PARTITION BY ce.claim_key_id ORDER BY ce.event_time) AS resubmission_sequence,
    COUNT(*) OVER (PARTITION BY ce.claim_key_id) AS total_resubmissions
  FROM claims.claim_event ce
  JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce.id
  WHERE ce.type = 2  -- RESUBMISSION events
)
SELECT 
  rc.claim_key_id,
  ck.claim_id AS external_claim_id,
  c.id AS claim_id_internal,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.net AS claim_net_amount,
  c.tx_at AS claim_submission_date,
  
  -- Encounter information
  e.facility_id,
  e.type AS encounter_type,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  
  -- Resubmission information
  rc.activity_id,
  rc.resubmission_date,
  rc.resubmission_comment,
  rc.resubmission_type,
  rc.resubmission_sequence,
  rc.total_resubmissions,
  
  -- Reference data
  f.name AS facility_name,
  p.name AS provider_name,
  pay.name AS payer_name,
  et.description AS encounter_type_description

FROM resubmission_cycles rc
JOIN claims.claim_key ck ON ck.id = rc.claim_key_id
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
ORDER BY rc.claim_key_id, rc.resubmission_sequence;

-- SUB-SECOND PERFORMANCE INDEXES
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_resubmission_unique 
ON claims.mv_resubmission_cycles(claim_key_id, resubmission_sequence);

CREATE INDEX IF NOT EXISTS idx_mv_resubmission_claim 
ON claims.mv_resubmission_cycles(external_claim_id, resubmission_date);

CREATE INDEX IF NOT EXISTS idx_mv_resubmission_count 
ON claims.mv_resubmission_cycles(total_resubmissions, resubmission_date);

COMMENT ON MATERIALIZED VIEW claims.mv_resubmission_cycles IS 'Resubmission cycles tracking with sequence and count information';

-- ==========================================================================================================
-- SECTION 7: REMITTANCES RESUBMISSION ACTIVITY LEVEL MATERIALIZED VIEW
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_remittances_resubmission_activity_level (Activity-level remittance and resubmission data)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_remittances_resubmission_activity_level CASCADE;
CREATE MATERIALIZED VIEW claims.mv_remittances_resubmission_activity_level AS
WITH activity_remittance_summary AS (
  -- Pre-aggregate remittance data at activity level
  SELECT 
    ra.activity_id,
    ra.remittance_claim_id,
    rc.claim_key_id,
    ra.net AS activity_net,
    ra.payment_amount AS activity_payment,
    ra.denial_code AS activity_denial_code,
    ra.denial_reason AS activity_denial_reason,
    ra.created_at AS remittance_activity_created_at,
    rc.date_settlement,
    rc.payment_reference,
    r.receiver_name,
    r.receiver_id
  FROM claims.remittance_activity ra
  JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
  JOIN claims.remittance r ON r.id = rc.remittance_id
),
activity_resubmission_summary AS (
  -- Pre-aggregate resubmission data at activity level
  SELECT 
    ce.activity_id,
    ce.claim_key_id,
    ce.event_time AS resubmission_date,
    cr.comment AS resubmission_comment,
    cr.resubmission_type,
    COUNT(*) OVER (PARTITION BY ce.activity_id ORDER BY ce.event_time) AS resubmission_sequence
  FROM claims.claim_event ce
  JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce.id
  WHERE ce.type = 2  -- RESUBMISSION events
)
SELECT 
  a.id AS activity_id,
  a.claim_id,
  a.code AS activity_code,
  a.description AS activity_description,
  a.net AS activity_net_amount,
  a.created_at AS activity_created_at,
  
  -- Claim information
  ck.claim_id AS external_claim_id,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  
  -- Encounter information
  e.facility_id,
  e.type AS encounter_type,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  
  -- Remittance information
  ars.activity_payment,
  ars.activity_denial_code,
  ars.activity_denial_reason,
  ars.date_settlement,
  ars.payment_reference,
  ars.receiver_name,
  ars.receiver_id,
  ars.remittance_activity_created_at,
  
  -- Resubmission information
  arss.resubmission_date,
  arss.resubmission_comment,
  arss.resubmission_type,
  arss.resubmission_sequence,
  
  -- Calculated fields
  CASE 
    WHEN ars.activity_payment > 0 THEN 'PAID'
    WHEN ars.activity_denial_code IS NOT NULL THEN 'DENIED'
    ELSE 'PENDING'
  END AS activity_status,
  
  CASE 
    WHEN arss.resubmission_sequence > 0 THEN true
    ELSE false
  END AS has_resubmissions,
  
  -- Reference data
  f.name AS facility_name,
  f.facility_code,
  p.name AS provider_name,
  p.provider_code,
  pay.name AS payer_name,
  pay.payer_code,
  cl.name AS clinician_name,
  cl.clinician_code,
  ac.description AS activity_code_description

FROM claims.activity a
JOIN claims.claim c ON c.id = a.claim_id
JOIN claims.claim_key ck ON ck.id = c.claim_key_id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims_ref.activity_code ac ON ac.id = a.activity_code_ref_id
LEFT JOIN activity_remittance_summary ars ON ars.activity_id = a.id
LEFT JOIN activity_resubmission_summary arss ON arss.activity_id = a.id;

-- SUB-SECOND PERFORMANCE INDEXES
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_remittances_activity_unique 
ON claims.mv_remittances_resubmission_activity_level(activity_id);

CREATE INDEX IF NOT EXISTS idx_mv_remittances_activity_claim 
ON claims.mv_remittances_resubmission_activity_level(external_claim_id, activity_status);

CREATE INDEX IF NOT EXISTS idx_mv_remittances_activity_resubmission 
ON claims.mv_remittances_resubmission_activity_level(has_resubmissions, resubmission_date);

COMMENT ON MATERIALIZED VIEW claims.mv_remittances_resubmission_activity_level IS 'Activity-level view of remittance and resubmission data with pre-computed aggregations';

-- ==========================================================================================================
-- SECTION 8: REJECTED CLAIMS MATERIALIZED VIEWS
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_rejected_claims_summary (Rejected claims summary)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_rejected_claims_summary CASCADE;
CREATE MATERIALIZED VIEW claims.mv_rejected_claims_summary AS
WITH rejected_activities AS (
  -- Get activities that have been rejected (denied)
  SELECT 
    ra.activity_id,
    ra.remittance_claim_id,
    ra.net AS activity_net,
    ra.denial_code,
    ra.denial_reason,
    ra.created_at AS rejection_date,
    rc.claim_key_id,
    rc.date_settlement,
    rc.payment_reference,
    r.receiver_name,
    r.receiver_id
  FROM claims.remittance_activity ra
  JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
  JOIN claims.remittance r ON r.id = rc.remittance_id
  WHERE ra.denial_code IS NOT NULL  -- Rejected activities
),
claim_rejection_summary AS (
  -- Aggregate rejection data at claim level
  SELECT 
    rc.claim_key_id,
    COUNT(DISTINCT ra.activity_id) AS rejected_activity_count,
    SUM(ra.net) AS total_rejected_amount,
    MIN(ra.created_at) AS first_rejection_date,
    MAX(ra.created_at) AS last_rejection_date,
    MAX(ra.denial_code) AS primary_denial_code,
    MAX(ra.denial_reason) AS primary_denial_reason
  FROM claims.remittance_activity ra
  JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
  WHERE ra.denial_code IS NOT NULL
  GROUP BY rc.claim_key_id
)
SELECT 
  -- Claim information
  ck.id AS claim_key_id,
  ck.claim_id AS external_claim_id,
  c.id AS claim_id_internal,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.gross AS claim_gross_amount,
  c.patient_share AS claim_patient_share,
  c.net AS claim_net_amount,
  c.tx_at AS claim_submission_date,
  c.comments AS claim_comments,
  
  -- Encounter information
  e.facility_id,
  e.type AS encounter_type,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  
  -- Rejection summary
  COALESCE(crs.rejected_activity_count, 0) AS rejected_activity_count,
  COALESCE(crs.total_rejected_amount, 0) AS total_rejected_amount,
  crs.first_rejection_date,
  crs.last_rejection_date,
  crs.primary_denial_code,
  crs.primary_denial_reason,
  
  -- Activity-level rejection details
  ra.activity_id,
  ra.activity_net,
  ra.denial_code,
  ra.denial_reason,
  ra.rejection_date,
  ra.date_settlement,
  ra.payment_reference,
  ra.receiver_name,
  ra.receiver_id,
  
  -- Calculated fields
  CASE 
    WHEN COALESCE(crs.rejected_activity_count, 0) > 0 THEN true
    ELSE false
  END AS has_rejections,
  
  CASE 
    WHEN COALESCE(crs.total_rejected_amount, 0) = c.net THEN 'FULLY_REJECTED'
    WHEN COALESCE(crs.total_rejected_amount, 0) > 0 THEN 'PARTIALLY_REJECTED'
    ELSE 'NOT_REJECTED'
  END AS rejection_status,
  
  -- Reference data
  f.name AS facility_name,
  f.facility_code,
  p.name AS provider_name,
  p.provider_code,
  pay.name AS payer_name,
  pay.payer_code,
  et.description AS encounter_type_description,
  dc.description AS denial_code_description

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
LEFT JOIN claim_rejection_summary crs ON crs.claim_key_id = ck.id
LEFT JOIN rejected_activities ra ON ra.claim_key_id = ck.id
LEFT JOIN claims_ref.denial_code dc ON dc.code = ra.denial_code;

-- SUB-SECOND PERFORMANCE INDEXES
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_rejected_claims_unique 
ON claims.mv_rejected_claims_summary(claim_key_id, activity_id);

CREATE INDEX IF NOT EXISTS idx_mv_rejected_claims_status 
ON claims.mv_rejected_claims_summary(rejection_status, rejection_date);

CREATE INDEX IF NOT EXISTS idx_mv_rejected_claims_amount 
ON claims.mv_rejected_claims_summary(total_rejected_amount DESC);

COMMENT ON MATERIALIZED VIEW claims.mv_rejected_claims_summary IS 'Rejected claims summary with activity-level and claim-level rejection data';

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_rejected_claims_by_year (Rejected claims by year)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_rejected_claims_by_year CASCADE;
CREATE MATERIALIZED VIEW claims.mv_rejected_claims_by_year AS
SELECT 
  EXTRACT(YEAR FROM c.tx_at) AS year,
  COUNT(DISTINCT ck.claim_id) AS total_claims,
  COUNT(DISTINCT CASE WHEN crs.rejected_activity_count > 0 THEN ck.claim_id END) AS rejected_claims,
  SUM(c.net) AS total_claim_amount,
  SUM(CASE WHEN crs.rejected_activity_count > 0 THEN crs.total_rejected_amount ELSE 0 END) AS total_rejected_amount,
  ROUND(
    (COUNT(DISTINCT CASE WHEN crs.rejected_activity_count > 0 THEN ck.claim_id END)::DECIMAL / 
     COUNT(DISTINCT ck.claim_id)) * 100, 2
  ) AS rejection_rate_percentage,
  ROUND(
    (SUM(CASE WHEN crs.rejected_activity_count > 0 THEN crs.total_rejected_amount ELSE 0 END)::DECIMAL / 
     SUM(c.net)) * 100, 2
  ) AS rejection_amount_percentage
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN (
  SELECT 
    rc.claim_key_id,
    COUNT(DISTINCT ra.activity_id) AS rejected_activity_count,
    SUM(ra.net) AS total_rejected_amount
  FROM claims.remittance_activity ra
  JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
  WHERE ra.denial_code IS NOT NULL
  GROUP BY rc.claim_key_id
) crs ON crs.claim_key_id = ck.id
GROUP BY EXTRACT(YEAR FROM c.tx_at)
ORDER BY year DESC;

COMMENT ON MATERIALIZED VIEW claims.mv_rejected_claims_by_year IS 'Rejected claims summary grouped by year';

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_rejected_claims_summary_tab (Rejected claims summary tab)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_rejected_claims_summary_tab CASCADE;
CREATE MATERIALIZED VIEW claims.mv_rejected_claims_summary_tab AS
SELECT 
  COUNT(DISTINCT ck.claim_id) AS total_claims,
  COUNT(DISTINCT CASE WHEN crs.rejected_activity_count > 0 THEN ck.claim_id END) AS rejected_claims,
  SUM(c.net) AS total_claim_amount,
  SUM(CASE WHEN crs.rejected_activity_count > 0 THEN crs.total_rejected_amount ELSE 0 END) AS total_rejected_amount,
  ROUND(
    (COUNT(DISTINCT CASE WHEN crs.rejected_activity_count > 0 THEN ck.claim_id END)::DECIMAL / 
     COUNT(DISTINCT ck.claim_id)) * 100, 2
  ) AS rejection_rate_percentage,
  ROUND(
    (SUM(CASE WHEN crs.rejected_activity_count > 0 THEN crs.total_rejected_amount ELSE 0 END)::DECIMAL / 
     SUM(c.net)) * 100, 2
  ) AS rejection_amount_percentage
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN (
  SELECT 
    rc.claim_key_id,
    COUNT(DISTINCT ra.activity_id) AS rejected_activity_count,
    SUM(ra.net) AS total_rejected_amount
  FROM claims.remittance_activity ra
  JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
  WHERE ra.denial_code IS NOT NULL
  GROUP BY rc.claim_key_id
) crs ON crs.claim_key_id = ck.id;

COMMENT ON MATERIALIZED VIEW claims.mv_rejected_claims_summary_tab IS 'Overall rejected claims summary';

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_rejected_claims_receiver_payer (Rejected claims by receiver and payer)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_rejected_claims_receiver_payer CASCADE;
CREATE MATERIALIZED VIEW claims.mv_rejected_claims_receiver_payer AS
SELECT 
  r.receiver_name,
  r.receiver_id,
  c.payer_id,
  pay.name AS payer_name,
  COUNT(DISTINCT ck.claim_id) AS total_claims,
  COUNT(DISTINCT CASE WHEN ra.denial_code IS NOT NULL THEN ck.claim_id END) AS rejected_claims,
  SUM(c.net) AS total_claim_amount,
  SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS total_rejected_amount,
  ROUND(
    (COUNT(DISTINCT CASE WHEN ra.denial_code IS NOT NULL THEN ck.claim_id END)::DECIMAL / 
     COUNT(DISTINCT ck.claim_id)) * 100, 2
  ) AS rejection_rate_percentage
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
GROUP BY r.receiver_name, r.receiver_id, c.payer_id, pay.name
ORDER BY total_rejected_amount DESC;

COMMENT ON MATERIALIZED VIEW claims.mv_rejected_claims_receiver_payer IS 'Rejected claims grouped by receiver and payer';

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_rejected_claims_claim_wise (Claim-wise rejected claims details)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_rejected_claims_claim_wise CASCADE;
CREATE MATERIALIZED VIEW claims.mv_rejected_claims_claim_wise AS
SELECT 
  ck.claim_id AS external_claim_id,
  c.id AS claim_id_internal,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.net AS claim_net_amount,
  c.tx_at AS claim_submission_date,
  
  -- Encounter information
  e.facility_id,
  e.type AS encounter_type,
  e.start_at AS encounter_start,
  
  -- Rejection details
  ra.activity_id,
  ra.net AS rejected_activity_amount,
  ra.denial_code,
  ra.denial_reason,
  ra.created_at AS rejection_date,
  rc.date_settlement,
  rc.payment_reference,
  r.receiver_name,
  r.receiver_id,
  
  -- Reference data
  f.name AS facility_name,
  p.name AS provider_name,
  pay.name AS payer_name,
  et.description AS encounter_type_description,
  dc.description AS denial_code_description

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.denial_code dc ON dc.code = ra.denial_code
WHERE ra.denial_code IS NOT NULL  -- Only rejected activities
ORDER BY ck.claim_id, ra.created_at;

COMMENT ON MATERIALIZED VIEW claims.mv_rejected_claims_claim_wise IS 'Claim-wise rejected claims details';

-- ==========================================================================================================
-- SECTION 9: CLAIM SUMMARY MATERIALIZED VIEWS
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_claim_summary_payerwise (Claim summary by payer)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_claim_summary_payerwise CASCADE;
CREATE MATERIALIZED VIEW claims.mv_claim_summary_payerwise AS
WITH base AS (
    SELECT
        ck.claim_id,
        c.id AS claim_db_id,
        c.tx_at,
        e.facility_id,
        f.name AS facility_name,
        rc.date_settlement,
        rc.id AS remittance_claim_id,
        cas.activity_id AS remittance_activity_id,
        c.net AS claim_net,
        cas.submitted_amount AS ra_net,
        cas.paid_amount AS payment_amount,
        COALESCE(p2.payer_code, 'Unknown') AS health_authority
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
    LEFT JOIN claims.encounter e ON e.claim_id = c.id
    LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
    LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
    LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
    LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
),
dedup_claim AS (
    SELECT claim_db_id,
           health_authority,
           MAX(claim_net) AS claim_net_once
    FROM base
    GROUP BY claim_db_id, health_authority
)
SELECT
    -- Payer grouping
    COALESCE(p2.payer_code, 'Unknown') AS health_authority,
    p2.name AS payer_name,

    -- Count Metrics
    COUNT(DISTINCT ck.claim_id) AS count_claims,
    COUNT(DISTINCT cas.activity_id) AS remitted_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'FULLY_PAID' THEN cas.activity_id END) AS fully_paid_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.activity_id END) AS partially_paid_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS fully_rejected_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS rejection_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.activity_id END) AS taken_back_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'PENDING' THEN cas.activity_id END) AS pending_remittance_count,
    COUNT(DISTINCT CASE WHEN c.payer_id = 'Self-Paid' THEN ck.claim_id END) AS self_pay_count,

    -- Amount Metrics
    SUM(DISTINCT d.claim_net_once) AS claim_amount,
    SUM(DISTINCT d.claim_net_once) AS initial_claim_amount,
    SUM(COALESCE(cas.paid_amount, 0)) AS remitted_amount,
    SUM(COALESCE(cas.paid_amount, 0)) AS remitted_net_amount,
    SUM(COALESCE(cas.paid_amount, 0)) AS fully_paid_amount,
    SUM(CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.paid_amount ELSE 0 END) AS partially_paid_amount,
    SUM(COALESCE(cas.denied_amount, 0)) AS fully_rejected_amount,
    SUM(COALESCE(cas.denied_amount, 0)) AS rejected_amount,
    SUM(CASE WHEN cas.activity_status = 'PENDING' THEN cas.submitted_amount ELSE 0 END) AS pending_remittance_amount,
    SUM(CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.taken_back_amount ELSE 0 END) AS taken_back_amount,
    SUM(CASE WHEN c.payer_id = 'Self-Paid' THEN c.net ELSE 0 END) AS self_pay_amount,

    -- Facility and Health Authority
    e.facility_id,
    f.name AS facility_name,

    -- Percentage Calculations
    CASE
        WHEN SUM(c.net) > 0 THEN
            ROUND((SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) / SUM(c.net)) * 100, 2)
        ELSE 0
    END AS rejected_percentage_on_initial,
    CASE
    WHEN (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) > 0 THEN
        ROUND(
            (
                SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)
                /
                (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END))
            ) * 100, 2)
        ELSE 0
    END AS rejected_percentage_on_remittance,
    CASE
        WHEN SUM(c.net) > 0 THEN
            ROUND((SUM(COALESCE(ra.payment_amount, 0)) / SUM(c.net)) * 100, 2)
        ELSE 0
    END AS collection_rate

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
LEFT JOIN dedup_claim d ON d.claim_db_id = c.id AND d.health_authority = COALESCE(p2.payer_code, 'Unknown')
GROUP BY 
    COALESCE(p2.payer_code, 'Unknown'),
    p2.name,
    e.facility_id,
    f.name
ORDER BY 
    COALESCE(p2.payer_code, 'Unknown'),
    e.facility_id,
    f.name;

COMMENT ON MATERIALIZED VIEW claims.mv_claim_summary_payerwise IS 'Payerwise claim summary with cumulative-with-cap logic';

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_claim_summary_encounterwise (Claim summary by encounter type)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_claim_summary_encounterwise CASCADE;
CREATE MATERIALIZED VIEW claims.mv_claim_summary_encounterwise AS
WITH base AS (
    SELECT
        ck.claim_id,
        c.id AS claim_db_id,
        c.tx_at,
        e.facility_id,
        f.name AS facility_name,
        e.type AS encounter_type,
        rc.date_settlement,
        rc.id AS remittance_claim_id,
        cas.activity_id AS remittance_activity_id,
        c.net AS claim_net,
        cas.submitted_amount AS ra_net,
        cas.paid_amount AS payment_amount,
        COALESCE(p2.payer_code, 'Unknown') AS health_authority
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
    LEFT JOIN claims.encounter e ON e.claim_id = c.id
    LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
    LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
    LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
    LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
),
dedup_claim AS (
    SELECT claim_db_id,
           encounter_type,
           MAX(claim_net) AS claim_net_once
    FROM base
    GROUP BY claim_db_id, encounter_type
)
SELECT
    -- Encounter type grouping
    e.type AS encounter_type,
    et.description AS encounter_type_description,

    -- Count Metrics
    COUNT(DISTINCT ck.claim_id) AS count_claims,
    COUNT(DISTINCT cas.activity_id) AS remitted_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'FULLY_PAID' THEN cas.activity_id END) AS fully_paid_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.activity_id END) AS partially_paid_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS fully_rejected_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS rejection_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.activity_id END) AS taken_back_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'PENDING' THEN cas.activity_id END) AS pending_remittance_count,
    COUNT(DISTINCT CASE WHEN c.payer_id = 'Self-Paid' THEN ck.claim_id END) AS self_pay_count,

    -- Amount Metrics
    SUM(DISTINCT d.claim_net_once) AS claim_amount,
    SUM(DISTINCT d.claim_net_once) AS initial_claim_amount,
    SUM(COALESCE(cas.paid_amount, 0)) AS remitted_amount,
    SUM(COALESCE(cas.paid_amount, 0)) AS remitted_net_amount,
    SUM(COALESCE(cas.paid_amount, 0)) AS fully_paid_amount,
    SUM(CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.paid_amount ELSE 0 END) AS partially_paid_amount,
    SUM(COALESCE(cas.denied_amount, 0)) AS fully_rejected_amount,
    SUM(COALESCE(cas.denied_amount, 0)) AS rejected_amount,
    SUM(CASE WHEN cas.activity_status = 'PENDING' THEN cas.submitted_amount ELSE 0 END) AS pending_remittance_amount,
    SUM(CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.taken_back_amount ELSE 0 END) AS taken_back_amount,
    SUM(CASE WHEN c.payer_id = 'Self-Paid' THEN c.net ELSE 0 END) AS self_pay_amount,

    -- Facility and Health Authority
    e.facility_id,
    f.name AS facility_name,
    COALESCE(p2.payer_code, 'Unknown') AS health_authority,

    -- Percentage Calculations
    CASE
        WHEN SUM(c.net) > 0 THEN
            ROUND((SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) / SUM(c.net)) * 100, 2)
        ELSE 0
    END AS rejected_percentage_on_initial,
    CASE
    WHEN (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) > 0 THEN
        ROUND(
            (
                SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)
                /
                (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END))
            ) * 100, 2)
        ELSE 0
    END AS rejected_percentage_on_remittance,
    CASE
        WHEN SUM(c.net) > 0 THEN
            ROUND((SUM(COALESCE(ra.payment_amount, 0)) / SUM(c.net)) * 100, 2)
        ELSE 0
    END AS collection_rate

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
LEFT JOIN dedup_claim d ON d.claim_db_id = c.id AND d.encounter_type = e.type
GROUP BY 
    e.type,
    et.description,
    e.facility_id,
    f.name,
    COALESCE(p2.payer_code, 'Unknown')
ORDER BY 
    e.type,
    e.facility_id,
    f.name;

COMMENT ON MATERIALIZED VIEW claims.mv_claim_summary_encounterwise IS 'Encounterwise claim summary with cumulative-with-cap logic';

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_claim_summary_monthwise (Claim summary by month)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_claim_summary_monthwise CASCADE;
CREATE MATERIALIZED VIEW claims.mv_claim_summary_monthwise AS
SELECT * FROM claims.mv_claims_monthly_agg;

COMMENT ON MATERIALIZED VIEW claims.mv_claim_summary_monthwise IS 'Monthwise claim summary (alias for mv_claims_monthly_agg)';

-- ==========================================================================================================
-- SECTION 10: REMITTANCES RESUBMISSION CLAIM LEVEL MATERIALIZED VIEW
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_remittances_resubmission_claim_level (Claim-level remittance and resubmission data)
-- ----------------------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS claims.mv_remittances_resubmission_claim_level CASCADE;
CREATE MATERIALIZED VIEW claims.mv_remittances_resubmission_claim_level AS
WITH claim_remittance_summary AS (
  -- Pre-aggregate remittance data at claim level
  SELECT 
    rc.claim_key_id,
    COUNT(DISTINCT rc.id) AS remittance_count,
    SUM(ra.payment_amount) AS total_payment_amount,
    SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS total_denied_amount,
    MIN(rc.date_settlement) AS first_remittance_date,
    MAX(rc.date_settlement) AS last_remittance_date,
    MAX(rc.payment_reference) AS last_payment_reference,
    MAX(r.receiver_name) AS receiver_name,
    MAX(r.receiver_id) AS receiver_id
  FROM claims.remittance_claim rc
  JOIN claims.remittance r ON r.id = rc.remittance_id
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
),
claim_resubmission_summary AS (
  -- Pre-aggregate resubmission data at claim level
  SELECT 
    ce.claim_key_id,
    COUNT(*) AS resubmission_count,
    MIN(ce.event_time) AS first_resubmission_date,
    MAX(ce.event_time) AS last_resubmission_date,
    MAX(cr.comment) AS last_resubmission_comment,
    MAX(cr.resubmission_type) AS last_resubmission_type
  FROM claims.claim_event ce
  JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce.id
  WHERE ce.type = 2  -- RESUBMISSION events
  GROUP BY ce.claim_key_id
)
SELECT 
  ck.id AS claim_key_id,
  ck.claim_id AS external_claim_id,
  c.id AS claim_id_internal,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.gross AS claim_gross_amount,
  c.patient_share AS claim_patient_share,
  c.net AS claim_net_amount,
  c.tx_at AS claim_submission_date,
  c.comments AS claim_comments,
  
  -- Encounter information
  e.facility_id,
  e.type AS encounter_type,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  
  -- Remittance summary
  COALESCE(crs.remittance_count, 0) AS remittance_count,
  COALESCE(crs.total_payment_amount, 0) AS total_payment_amount,
  COALESCE(crs.total_denied_amount, 0) AS total_denied_amount,
  crs.first_remittance_date,
  crs.last_remittance_date,
  crs.last_payment_reference,
  crs.receiver_name,
  crs.receiver_id,
  
  -- Resubmission summary
  COALESCE(crss.resubmission_count, 0) AS resubmission_count,
  crss.first_resubmission_date,
  crss.last_resubmission_date,
  crss.last_resubmission_comment,
  crss.last_resubmission_type,
  
  -- Calculated fields
  c.net - COALESCE(crs.total_payment_amount, 0) AS balance_amount,
  CASE 
    WHEN c.net - COALESCE(crs.total_payment_amount, 0) > 0 THEN 'PENDING'
    WHEN c.net - COALESCE(crs.total_payment_amount, 0) = 0 THEN 'PAID'
    ELSE 'OVERPAID'
  END AS payment_status,
  
  CASE 
    WHEN COALESCE(crss.resubmission_count, 0) > 0 THEN true
    ELSE false
  END AS has_resubmissions,
  
  CASE 
    WHEN COALESCE(crs.remittance_count, 0) > 0 THEN true
    ELSE false
  END AS has_remittances,
  
  -- Reference data
  f.name AS facility_name,
  f.facility_code,
  p.name AS provider_name,
  p.provider_code,
  pay.name AS payer_name,
  pay.payer_code

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claim_remittance_summary crs ON crs.claim_key_id = ck.id
LEFT JOIN claim_resubmission_summary crss ON crss.claim_key_id = ck.id;

COMMENT ON MATERIALIZED VIEW claims.mv_remittances_resubmission_claim_level IS 'Claim-level view of remittance and resubmission data with pre-computed aggregations';

-- ==========================================================================================================
-- SECTION 11: PERMISSIONS AND GRANTS
-- ==========================================================================================================

-- Grant permissions on all materialized views to claims_user
GRANT SELECT ON ALL TABLES IN SCHEMA claims TO claims_user;

-- Set default privileges for future materialized views
ALTER DEFAULT PRIVILEGES IN SCHEMA claims GRANT SELECT ON TABLES TO claims_user;

-- ==========================================================================================================
-- SECTION 12: REFRESH COMMANDS (COMMENTED OUT FOR MANUAL EXECUTION)
-- ==========================================================================================================

-- Uncomment these commands to refresh materialized views after initial creation
-- REFRESH MATERIALIZED VIEW claims.mv_balance_amount_summary;
-- REFRESH MATERIALIZED VIEW claims.mv_remittance_advice_summary;
-- REFRESH MATERIALIZED VIEW claims.mv_doctor_denial_summary;
-- REFRESH MATERIALIZED VIEW claims.mv_claims_monthly_agg;
-- REFRESH MATERIALIZED VIEW claims.mv_claim_details_complete;
-- REFRESH MATERIALIZED VIEW claims.mv_resubmission_cycles;
-- REFRESH MATERIALIZED VIEW claims.mv_remittances_resubmission_activity_level;
-- REFRESH MATERIALIZED VIEW claims.mv_rejected_claims_summary;
-- REFRESH MATERIALIZED VIEW claims.mv_claim_summary_payerwise;
-- REFRESH MATERIALIZED VIEW claims.mv_claim_summary_encounterwise;
-- REFRESH MATERIALIZED VIEW claims.mv_claim_summary_monthwise;
-- REFRESH MATERIALIZED VIEW claims.mv_remittances_resubmission_claim_level;

-- ==========================================================================================================
-- END OF MATERIALIZED VIEWS
-- ==========================================================================================================