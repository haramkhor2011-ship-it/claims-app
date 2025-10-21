-- ==========================================================================================================
-- REPORT VIEWS - SQL VIEWS FOR REPORTS
-- ==========================================================================================================
-- 
-- Purpose: Create SQL views for reports (if needed)
-- Version: 1.0
-- Date: 2025-01-15
-- 
-- This script creates SQL views for reports that are not covered by materialized views.
-- Most reports use materialized views for performance, but some may need dynamic views.
--
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- 6.x INGESTION KPIS VIEW (hourly rollup)
-- ----------------------------------------------------------------------------------------------------------
-- Optimized for available indexes:
--  - idx_ingestion_run_started on claims.ingestion_run(started_at)
--  - idx_ingestion_file_audit_run on claims.ingestion_file_audit(ingestion_run_id)
-- The join is on ingestion_run.id = ingestion_file_audit.ingestion_run_id (LEFT JOIN)
-- No extraneous joins; aggregation by hour_bucket only.

CREATE OR REPLACE VIEW claims.v_ingestion_kpis AS
SELECT
  date_trunc('hour', ir.started_at)                             AS hour_bucket,
  COUNT(DISTINCT ir.id)                                         AS runs_total,
  SUM(ir.files_processed_ok)                                    AS files_ok,
  SUM(ir.files_failed)                                          AS files_fail,
  SUM(ir.files_already)                                         AS files_already,
  COALESCE(SUM(ifa.parsed_claims), 0)                           AS parsed_claims,
  COALESCE(SUM(ifa.persisted_claims), 0)                        AS persisted_claims,
  COALESCE(SUM(ifa.parsed_activities), 0)                       AS parsed_activities,
  COALESCE(SUM(ifa.persisted_activities), 0)                    AS persisted_activities,
  COALESCE(SUM(ifa.parsed_remit_claims), 0)                     AS parsed_remit_claims,
  COALESCE(SUM(ifa.persisted_remit_claims), 0)                  AS persisted_remit_claims,
  COALESCE(SUM(ifa.parsed_remit_activities), 0)                 AS parsed_remit_activities,
  COALESCE(SUM(ifa.projected_events), 0)                        AS projected_events,
  COALESCE(SUM(ifa.projected_status_rows), 0)                   AS projected_status_rows,
  COUNT(DISTINCT CASE WHEN ifa.verification_passed = TRUE THEN ifa.ingestion_file_id END) AS files_verified
FROM claims.ingestion_run ir
LEFT JOIN claims.ingestion_file_audit ifa
  ON ifa.ingestion_run_id = ir.id
GROUP BY date_trunc('hour', ir.started_at)
ORDER BY hour_bucket DESC;

COMMENT ON VIEW claims.v_ingestion_kpis IS 'Hourly KPIs for ingestion processing (run-level and file-level rollups)';

-- Note: In addition to materialized views, we keep traditional SQL views and API functions here
-- where they provide convenience or dynamic behavior. Extracted from report implementations.

-- ==========================================================================================================
-- BALANCE AMOUNT REPORT – BASE VIEW AND TABS
-- ==========================================================================================================

-- Base view
DROP VIEW IF EXISTS claims.v_balance_amount_to_be_received_base CASCADE;
CREATE OR REPLACE VIEW claims.v_balance_amount_to_be_received_base AS
WITH latest_remittance AS (
  SELECT DISTINCT ON (claim_key_id) 
    claim_key_id,
    date_settlement,
    payment_reference
  FROM claims.remittance_claim
  ORDER BY claim_key_id, date_settlement DESC
),
remittance_summary AS (
  SELECT 
    rc.claim_key_id,
    SUM(ra.payment_amount) as total_payment_amount,
    SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) as total_denied_amount,
    COUNT(*) as remittance_count,
    MIN(rc.date_settlement) as first_remittance_date,
    MAX(rc.date_settlement) as last_remittance_date,
    MAX(rc.payment_reference) as last_payment_reference
  FROM claims.remittance_claim rc
  JOIN claims.remittance_activity ra ON rc.id = ra.remittance_claim_id
  GROUP BY rc.claim_key_id
),
resubmission_summary AS (
  SELECT 
    ce.claim_key_id,
    COUNT(*) as resubmission_count,
    MAX(ce.event_time) as last_resubmission_date,
    MAX(cr.comment) as last_resubmission_comment,
    MAX(cr.resubmission_type) as last_resubmission_type
  FROM claims.claim_event ce
  LEFT JOIN claims.claim_resubmission cr ON ce.id = cr.claim_event_id
  WHERE ce.type = 2
  GROUP BY ce.claim_key_id
),
latest_status AS (
  SELECT DISTINCT ON (claim_key_id)
    claim_key_id,
    status,
    status_time
  FROM claims.claim_status_timeline
  ORDER BY claim_key_id, status_time DESC
)
SELECT 
  ck.id AS claim_key_id,
  ck.claim_id,
  c.id AS claim_id_internal,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.gross AS initial_gross_amount,
  c.patient_share AS initial_patient_share,
  c.net AS initial_net_amount,
  c.tx_at AS claim_submission_date,
  c.comments AS claim_comments,
  e.facility_id,
  e.type AS encounter_type,
  e.patient_id,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  EXTRACT(YEAR FROM e.start_at) AS encounter_start_year,
  EXTRACT(MONTH FROM e.start_at) AS encounter_start_month,
  COALESCE(e.facility_id, c.provider_id) AS facility_group_id,
  COALESCE(p.name, c.provider_id, 'UNKNOWN') AS provider_name,
  COALESCE(p.provider_code, c.provider_id) AS provider_code,
  COALESCE(f.name, e.facility_id, 'UNKNOWN') AS facility_name,
  COALESCE(f.facility_code, e.facility_id) AS facility_code,
  COALESCE(pay.name, c.payer_id, 'UNKNOWN') AS payer_name,
  COALESCE(pay.payer_code, c.payer_id) AS payer_code,
  if_sub.sender_id AS health_authority_submission,
  if_rem.receiver_id AS health_authority_remittance,
  COALESCE(remittance_summary.total_payment_amount, 0) AS total_payment_amount,
  COALESCE(remittance_summary.total_denied_amount, 0) AS total_denied_amount,
  remittance_summary.first_remittance_date,
  remittance_summary.last_remittance_date,
  remittance_summary.last_payment_reference,
  COALESCE(remittance_summary.remittance_count, 0) AS remittance_count,
  COALESCE(resubmission_summary.resubmission_count, 0) AS resubmission_count,
  resubmission_summary.last_resubmission_date,
  resubmission_summary.last_resubmission_comment,
  resubmission_summary.last_resubmission_type,
  if_sub.file_id AS last_submission_file,
  if_sub.receiver_id,
  claims.map_status_to_text(cst.status) AS current_claim_status,
  cst.status_time AS last_status_date,
  CASE 
    WHEN c.net IS NULL OR c.net = 0 THEN 0
    ELSE c.net - COALESCE(remittance_summary.total_payment_amount, 0) - COALESCE(remittance_summary.total_denied_amount, 0)
  END AS pending_amount,
  EXTRACT(DAYS FROM (CURRENT_DATE - e.start_at)) AS aging_days,
  CASE 
    WHEN EXTRACT(DAYS FROM (CURRENT_DATE - e.start_at)) <= 30 THEN '0-30'
    WHEN EXTRACT(DAYS FROM (CURRENT_DATE - e.start_at)) <= 60 THEN '31-60'
    WHEN EXTRACT(DAYS FROM (CURRENT_DATE - e.start_at)) <= 90 THEN '61-90'
    ELSE '90+'
  END AS aging_bucket
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims.submission s ON s.id = c.submission_id
LEFT JOIN claims.ingestion_file if_sub ON if_sub.id = s.ingestion_file_id
LEFT JOIN claims.remittance_claim rc_join ON rc_join.claim_key_id = ck.id
LEFT JOIN claims.remittance rem ON rem.id = rc_join.remittance_id
LEFT JOIN claims.ingestion_file if_rem ON if_rem.id = rem.ingestion_file_id
LEFT JOIN remittance_summary ON remittance_summary.claim_key_id = ck.id
LEFT JOIN resubmission_summary ON resubmission_summary.claim_key_id = ck.id
LEFT JOIN latest_status cst ON cst.claim_key_id = ck.id;

COMMENT ON VIEW claims.v_balance_amount_to_be_received_base IS 'Enhanced base view for balance amount reporting with corrected field mappings and business logic';

-- Tab A
CREATE OR REPLACE VIEW claims.v_balance_amount_to_be_received AS
SELECT 
  bab.claim_key_id,
  bab.claim_id,
  bab.facility_group_id,  -- CORRECTED: Use facility_id (preferred) or provider_id per JSON mapping
  COALESCE(bab.health_authority_submission, bab.health_authority_remittance) AS health_authority,  -- CORRECTED: Use sender_id/receiver_id per JSON mapping
  bab.facility_id,
  bab.facility_name,
  bab.claim_id AS claim_number,
  bab.encounter_start AS encounter_start_date,
  bab.encounter_end AS encounter_end_date,
  bab.encounter_start_year,
  bab.encounter_start_month,
  bab.payer_id AS id_payer,
  bab.patient_id,
  bab.member_id,
  bab.emirates_id_number,
  COALESCE(bab.initial_net_amount, 0) AS billed_amount,           -- CORRECTED: Renamed from claim_amt per report suggestion
  COALESCE(bab.total_payment_amount, 0) AS amount_received,      -- CORRECTED: Renamed from remitted_amt per report suggestion
  COALESCE(bab.total_denied_amount, 0) AS denied_amount,         -- CORRECTED: Renamed from rejected_amt per report suggestion
  COALESCE(bab.pending_amount, 0) AS outstanding_balance,       -- CORRECTED: Renamed from pending_amt per report suggestion
  bab.claim_submission_date AS submission_date,                  -- CORRECTED: Renamed per report suggestion
  bab.last_submission_file AS submission_reference_file,         -- CORRECTED: Renamed per report suggestion
  CASE 
    WHEN bab.remittance_count > 0 THEN 'REMITTED'
    WHEN bab.resubmission_count > 0 THEN 'RESUBMITTED'
    ELSE 'PENDING'
  END AS claim_status,
  bab.remittance_count,
  bab.resubmission_count,
  bab.aging_days,
  bab.aging_bucket,
  bab.current_claim_status,
  bab.last_status_date
FROM claims.v_balance_amount_to_be_received_base bab;

COMMENT ON VIEW claims.v_balance_amount_to_be_received IS 'Tab A: Balance Amount to be received - Overall view';

-- Tab B
CREATE OR REPLACE VIEW claims.v_initial_not_remitted_balance AS
SELECT 
  bab.claim_key_id,
  bab.claim_id,
  bab.facility_group_id,  -- CORRECTED: Use facility_id (preferred) or provider_id per JSON mapping
  COALESCE(bab.health_authority_submission, bab.health_authority_remittance) AS health_authority,  -- CORRECTED: Use sender_id/receiver_id per JSON mapping
  bab.facility_id,
  bab.facility_name,
  bab.claim_id AS claim_number,
  bab.encounter_start AS encounter_start_date,
  bab.encounter_end AS encounter_end_date,
  bab.encounter_start_year,
  bab.encounter_start_month,
  bab.receiver_id,
  bab.payer_name AS receiver_name,  -- CORRECTED: Use claims_ref.payer.name joined on payer_code = ingestion_file.receiver_id per JSON mapping
  bab.payer_id,     -- Payer identifier
  bab.payer_name,
  bab.payer_id AS id_payer,
  bab.patient_id,  -- JSON: claims.claim.patient_id
  bab.member_id,  -- JSON: claims.claim.member_id
  bab.emirates_id_number,  -- JSON: claims.claim.emirates_id_number
  COALESCE(bab.initial_net_amount, 0) AS billed_amount,  -- CORRECTED: Renamed from claim_amt per report suggestion
  COALESCE(bab.total_payment_amount, 0) AS amount_received,  -- CORRECTED: Renamed from remitted_amt per report suggestion
  COALESCE(bab.total_denied_amount, 0) AS denied_amount,  -- CORRECTED: Renamed from rejected_amt per report suggestion
  COALESCE(bab.pending_amount, 0) AS outstanding_balance,  -- CORRECTED: Renamed from pending_amt per report suggestion
  bab.claim_submission_date AS submission_date,  -- CORRECTED: Renamed per report suggestion
  'INITIAL_PENDING' AS claim_status,
  bab.remittance_count,
  bab.resubmission_count,
  bab.aging_days,
  bab.aging_bucket
FROM claims.v_balance_amount_to_be_received_base bab
WHERE COALESCE(bab.total_payment_amount, 0) = 0
  AND COALESCE(bab.total_denied_amount, 0) = 0
  AND COALESCE(bab.resubmission_count, 0) = 0;

COMMENT ON VIEW claims.v_initial_not_remitted_balance IS 'Tab B: Initial Not Remitted Balance';

-- Tab C
CREATE OR REPLACE VIEW claims.v_after_resubmission_not_remitted_balance AS
SELECT 
  bab.claim_key_id,
  bab.claim_id,
  bab.facility_group_id AS facility_group,
  COALESCE(bab.health_authority_submission, bab.health_authority_remittance) AS health_authority,
  bab.facility_id,
  bab.facility_name,
  bab.claim_id AS claim_number,
  bab.encounter_start AS encounter_start_date,
  bab.encounter_end AS encounter_end_date,
  bab.encounter_start_year,
  bab.encounter_start_month,
  bab.payer_id AS id_payer,
  bab.patient_id,
  bab.member_id,
  bab.emirates_id_number,
  COALESCE(bab.initial_net_amount, 0) AS billed_amount,
  COALESCE(bab.total_payment_amount, 0) AS amount_received,
  COALESCE(bab.total_denied_amount, 0) AS denied_amount,
  COALESCE(bab.pending_amount, 0) AS outstanding_balance,
  bab.claim_submission_date AS submission_date,
  bab.resubmission_count,
  bab.last_resubmission_date,
  bab.last_resubmission_comment,
  'RESUBMITTED_PENDING' AS claim_status,
  bab.remittance_count,
  bab.aging_days,
  bab.aging_bucket
FROM claims.v_balance_amount_to_be_received_base bab
WHERE COALESCE(bab.resubmission_count, 0) > 0
  AND COALESCE(bab.pending_amount, 0) > 0;

COMMENT ON VIEW claims.v_after_resubmission_not_remitted_balance IS 'Tab C: After Resubmission Not Remitted Balance';

-- ==========================================================================================================
-- API FUNCTIONS
-- ==========================================================================================================

-- Status code to text helper
CREATE OR REPLACE FUNCTION claims.map_status_to_text(p_status SMALLINT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE p_status
    WHEN 1 THEN 'SUBMITTED'
    WHEN 2 THEN 'RESUBMITTED'
    WHEN 3 THEN 'PAID'
    WHEN 4 THEN 'PARTIALLY_PAID'
    WHEN 5 THEN 'REJECTED'
    WHEN 6 THEN 'UNKNOWN'
    ELSE 'UNKNOWN'
  END;
END;
$$;

-- Tab A API function
CREATE OR REPLACE FUNCTION claims.get_balance_amount_to_be_received(
  p_user_id TEXT,
  p_claim_key_ids BIGINT[] DEFAULT NULL,
  p_facility_codes TEXT[] DEFAULT NULL,
  p_payer_codes TEXT[] DEFAULT NULL,
  p_receiver_ids TEXT[] DEFAULT NULL,
  p_date_from TIMESTAMPTZ DEFAULT NULL,
  p_date_to TIMESTAMPTZ DEFAULT NULL,
  p_year INTEGER DEFAULT NULL,
  p_month INTEGER DEFAULT NULL,
  p_based_on_initial_net BOOLEAN DEFAULT FALSE,
  p_limit INTEGER DEFAULT 100,
  p_offset INTEGER DEFAULT 0,
  p_order_by TEXT DEFAULT 'encounter_start_date',
  p_order_direction TEXT DEFAULT 'DESC',
  p_facility_ref_ids BIGINT[] DEFAULT NULL,
  p_payer_ref_ids BIGINT[] DEFAULT NULL
) RETURNS TABLE(
  claim_key_id BIGINT,
  claim_id TEXT,
  facility_group_id TEXT,
  health_authority TEXT,
  facility_id TEXT,
  facility_name TEXT,
  claim_number TEXT,
  encounter_start_date TIMESTAMPTZ,
  encounter_end_date TIMESTAMPTZ,
  encounter_start_year INTEGER,
  encounter_start_month INTEGER,
  id_payer TEXT,
  patient_id TEXT,
  member_id TEXT,
  emirates_id_number TEXT,
  billed_amount NUMERIC,
  amount_received NUMERIC,
  denied_amount NUMERIC,
  outstanding_balance NUMERIC,
  submission_date TIMESTAMPTZ,
  submission_reference_file TEXT,
  claim_status TEXT,
  remittance_count INTEGER,
  resubmission_count INTEGER,
  aging_days INTEGER,
  aging_bucket TEXT,
  current_claim_status TEXT,
  last_status_date TIMESTAMPTZ,
  total_records BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_where_clause TEXT := '';
  v_order_clause TEXT := '';
  v_total_count BIGINT;
  v_sql TEXT;
BEGIN
  IF p_date_from IS NULL THEN
    p_date_from := NOW() - INTERVAL '3 years';
  END IF;
  IF p_date_to IS NULL THEN
    p_date_to := NOW();
  END IF;

  v_where_clause := 'WHERE mv.encounter_start >= $6 AND mv.encounter_start <= $7';

  IF p_claim_key_ids IS NOT NULL AND array_length(p_claim_key_ids, 1) > 0 THEN
    v_where_clause := v_where_clause || ' AND mv.claim_key_id = ANY($2)';
  END IF;
  IF p_facility_codes IS NOT NULL AND array_length(p_facility_codes, 1) > 0 THEN
    v_where_clause := v_where_clause || ' AND mv.facility_id = ANY($3)';
  ELSE
    -- v_where_clause := v_where_clause || ' AND claims.check_user_facility_access($1, mv.facility_id, ''READ'')';
  END IF;
  IF p_payer_codes IS NOT NULL AND array_length(p_payer_codes, 1) > 0 THEN
    v_where_clause := v_where_clause || ' AND mv.payer_id = ANY($4)';
  END IF;
  IF p_receiver_ids IS NOT NULL AND array_length(p_receiver_ids, 1) > 0 THEN
    v_where_clause := v_where_clause || ' AND mv.payer_name = ANY($5)';
  END IF;
  IF p_year IS NOT NULL THEN
    v_where_clause := v_where_clause || ' AND EXTRACT(YEAR FROM mv.encounter_start) = $8';
  END IF;
  IF p_month IS NOT NULL THEN
    v_where_clause := v_where_clause || ' AND EXTRACT(MONTH FROM mv.encounter_start) = $9';
  END IF;
  IF p_based_on_initial_net THEN
    v_where_clause := v_where_clause || ' AND mv.initial_net > 0';
  END IF;

  IF p_order_by NOT IN ('encounter_start_date', 'encounter_end_date', 'claim_submission_date', 'claim_amt', 'pending_amt', 'aging_days') THEN
    p_order_by := 'encounter_start_date';
  END IF;
  IF p_order_direction NOT IN ('ASC', 'DESC') THEN
    p_order_direction := 'DESC';
  END IF;
  v_order_clause := 'ORDER BY ' || p_order_by || ' ' || p_order_direction;

  v_sql := FORMAT('
    SELECT COUNT(*)
    FROM claims.mv_balance_amount_summary mv
    %s
  ', v_where_clause);
  EXECUTE v_sql
  USING p_user_id, p_claim_key_ids, p_facility_codes, p_payer_codes, p_receiver_ids, p_date_from, p_date_to, p_year, p_month, p_limit, p_offset, p_order_by, p_order_direction, p_facility_ref_ids, p_payer_ref_ids
  INTO v_total_count;

  v_sql := FORMAT('
    SELECT 
      mv.claim_key_id,
      mv.claim_id,
      mv.facility_id as facility_group_id,
      mv.payer_name as health_authority,
      mv.facility_id,
      mv.facility_name,
      mv.claim_id as claim_number,
      mv.encounter_start as encounter_start_date,
      mv.encounter_start as encounter_end_date,
      EXTRACT(YEAR FROM mv.encounter_start) as encounter_start_year,
      EXTRACT(MONTH FROM mv.encounter_start) as encounter_start_month,
      mv.payer_id as id_payer,
      '|| quote_literal('N/A') ||' as patient_id,
      '|| quote_literal('N/A') ||' as member_id,
      '|| quote_literal('N/A') ||' as emirates_id_number,
      mv.initial_net as billed_amount,
      mv.total_payment as amount_received,
      mv.total_denied as denied_amount,
      mv.pending_amount as outstanding_balance,
      mv.tx_at as submission_date,
      '|| quote_literal('N/A') ||' as submission_reference_file,
      mv.current_status as claim_status,
      mv.remittance_count,
      mv.resubmission_count,
      mv.aging_days,
      CASE 
        WHEN mv.aging_days <= 30 THEN '|| quote_literal('0-30') ||'
        WHEN mv.aging_days <= 60 THEN '|| quote_literal('31-60') ||'
        WHEN mv.aging_days <= 90 THEN '|| quote_literal('61-90') ||'
        ELSE '|| quote_literal('90+') ||'
      END as aging_bucket,
      mv.current_status as current_claim_status,
      mv.last_status_date,
      %s as total_records
    FROM claims.mv_balance_amount_summary mv
    %s
    %s
    LIMIT $10 OFFSET $11
  ', v_total_count, v_where_clause, v_order_clause);

  RETURN QUERY EXECUTE v_sql
  USING p_user_id, p_claim_key_ids, p_facility_codes, p_payer_codes, p_receiver_ids, p_date_from, p_date_to, p_year, p_month, p_limit, p_offset, p_order_by, p_order_direction, p_facility_ref_ids, p_payer_ref_ids;
END;
$$;

-- Grants
GRANT SELECT ON claims.v_balance_amount_to_be_received_base TO claims_user;
GRANT SELECT ON claims.v_balance_amount_to_be_received TO claims_user;
GRANT SELECT ON claims.v_initial_not_remitted_balance TO claims_user;
GRANT SELECT ON claims.v_after_resubmission_not_remitted_balance TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_balance_amount_to_be_received TO claims_user;
GRANT EXECUTE ON FUNCTION claims.map_status_to_text TO claims_user;

-- Example view structure (uncomment and modify as needed):
/*
-- Sample dynamic view for real-time data
CREATE OR REPLACE VIEW claims.v_recent_claims AS
SELECT 
  ck.claim_id,
  c.payer_id,
  c.provider_id,
  c.net,
  c.created_at,
  p.name as payer_name,
  pr.name as provider_name
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN claims_ref.provider pr ON pr.id = c.provider_ref_id
WHERE c.created_at >= NOW() - INTERVAL '24 hours'
ORDER BY c.created_at DESC;
*/

-- Grant access to claims_user
GRANT SELECT ON ALL TABLES IN SCHEMA claims TO claims_user;

-- ==========================================================================================================
-- REJECTED CLAIMS REPORT - TRADITIONAL VIEWS AND APIS (copied from reports_sql, correctness verified)
-- ==========================================================================================================

-- Functions cleanup to avoid conflicts
DROP FUNCTION IF EXISTS claims.get_rejected_claims_summary(TEXT, TEXT[], TEXT[], TEXT[], TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, INTEGER, INTEGER, INTEGER, TEXT, TEXT);
DROP FUNCTION IF EXISTS claims.get_rejected_claims_receiver_payer(TEXT, TEXT[], TEXT[], TEXT[], TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, TEXT[], INTEGER, INTEGER, TEXT, TEXT);
DROP FUNCTION IF EXISTS claims.get_rejected_claims_claim_wise(TEXT, TEXT[], TEXT[], TEXT[], TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, TEXT[], INTEGER, INTEGER, TEXT, TEXT);

-- Views cleanup
DROP VIEW IF EXISTS claims.v_rejected_claims_claim_wise;
DROP VIEW IF EXISTS claims.v_rejected_claims_receiver_payer;
DROP VIEW IF EXISTS claims.v_rejected_claims_summary;
DROP VIEW IF EXISTS claims.v_rejected_claims_summary_by_year;
DROP VIEW IF EXISTS claims.v_rejected_claims_base;

-- Base view
CREATE OR REPLACE VIEW claims.v_rejected_claims_base AS
WITH status_timeline AS (
  SELECT claim_key_id, status, status_time,
         LAG(status_time) OVER (PARTITION BY claim_key_id ORDER BY status_time) as prev_status_time
  FROM claims.claim_status_timeline
)
SELECT 
    ck.id AS claim_key_id,
    ck.claim_id,
    c.payer_id AS payer_id,
    COALESCE(p.name, c.payer_id, 'Unknown Payer') AS payer_name,
    c.payer_ref_id AS payer_ref_id,
    c.member_id,
    c.emirates_id_number,
    e.facility_id,
    e.facility_ref_id AS facility_ref_id,
    COALESCE(f.name, e.facility_id, 'Unknown Facility') AS facility_name,
    a.clinician,
    a.clinician_ref_id AS clinician_ref_id,
    COALESCE(cl.name, a.clinician, 'Unknown Clinician') AS clinician_name,
    a.activity_id,
    a.start_at AS activity_start_date,
    a.type AS activity_type,
    a.code AS activity_code,
    a.quantity,
    a.net AS activity_net_amount,
    ra.payment_amount AS activity_payment_amount,
    ra.denial_code AS activity_denial_code,
    COALESCE(dc.description, ra.denial_code, 'No Denial Code') AS denial_type,
    CASE 
        WHEN ra.payment_amount = 0 AND ra.denial_code IS NOT NULL THEN 'Fully Rejected'
        WHEN ra.payment_amount > 0 AND ra.payment_amount < a.net THEN 'Partially Rejected'
        WHEN ra.payment_amount = a.net THEN 'Fully Paid'
        ELSE 'Unknown Status'
    END AS rejection_type,
    CASE 
        WHEN ra.payment_amount = 0 AND ra.denial_code IS NOT NULL THEN a.net
        WHEN ra.payment_amount > 0 AND ra.payment_amount < a.net THEN (a.net - ra.payment_amount)
        ELSE 0
    END AS rejected_amount,
    EXTRACT(YEAR FROM a.start_at) AS claim_year,
    TO_CHAR(a.start_at, 'Month') AS claim_month_name,
    (CURRENT_DATE - a.start_at::DATE)::INTEGER AS ageing_days,
    s.ingestion_file_id AS submission_file_id,
    r.ingestion_file_id AS remittance_file_id,
    cst.status::TEXT AS current_status,
    cr.resubmission_type,
    cr.comment AS resubmission_comment
FROM claims.claim_key ck
JOIN claims.claim c ON ck.id = c.claim_key_id
LEFT JOIN claims.encounter e ON c.id = e.claim_id
JOIN claims.activity a ON c.id = a.claim_id
LEFT JOIN claims.remittance_claim rc ON ck.id = rc.claim_key_id
LEFT JOIN claims.remittance_activity ra ON rc.id = ra.remittance_claim_id AND a.activity_id = ra.activity_id
LEFT JOIN claims.submission s ON c.submission_id = s.id
LEFT JOIN claims.remittance r ON rc.remittance_id = r.id
LEFT JOIN (
    SELECT DISTINCT ON (cst2.claim_key_id)
        cst2.claim_key_id,
        cst2.status,
        cst2.claim_event_id
    FROM claims.claim_status_timeline cst2
    ORDER BY cst2.claim_key_id, cst2.status_time DESC, cst2.id DESC
) cst ON cst.claim_key_id = ck.id
LEFT JOIN claims.claim_resubmission cr ON cst.claim_event_id = cr.claim_event_id
LEFT JOIN claims_ref.payer p ON c.payer_ref_id = p.id
LEFT JOIN claims_ref.facility f ON e.facility_ref_id = f.id
LEFT JOIN claims_ref.clinician cl ON a.clinician_ref_id = cl.id
LEFT JOIN claims_ref.denial_code dc ON ra.denial_code_ref_id = dc.id;

COMMENT ON VIEW claims.v_rejected_claims_base IS 'Base view for Rejected Claims Report';

-- Summary by year/month
CREATE OR REPLACE VIEW claims.v_rejected_claims_summary_by_year AS
SELECT 
    rcb.claim_year,
    rcb.claim_month_name,
    rcb.facility_id,
    rcb.facility_name,
    rcb.payer_id AS id_payer,
    rcb.payer_name,
    COUNT(DISTINCT rcb.claim_key_id) AS total_claims,
    COUNT(DISTINCT CASE WHEN rcb.rejection_type IN ('Fully Rejected', 'Partially Rejected') THEN rcb.claim_key_id END) AS rejected_claims,
    SUM(rcb.activity_net_amount) AS total_claim_amount,
    SUM(rcb.activity_payment_amount) AS total_paid_amount,
    SUM(rcb.rejected_amount) AS total_rejected_amount,
    CASE WHEN SUM(rcb.activity_net_amount) > 0 THEN ROUND((SUM(rcb.rejected_amount) / SUM(rcb.activity_net_amount)) * 100, 2) ELSE 0 END AS rejected_percentage_based_on_submission,
    CASE WHEN (SUM(COALESCE(rcb.activity_payment_amount, 0)) + SUM(rcb.rejected_amount)) > 0 THEN ROUND((SUM(rcb.rejected_amount) / (SUM(COALESCE(rcb.activity_payment_amount, 0)) + SUM(rcb.rejected_amount))) * 100, 2) ELSE 0 END AS rejected_percentage_based_on_remittance,
    CASE WHEN SUM(rcb.activity_net_amount) > 0 THEN ROUND((SUM(rcb.activity_payment_amount) / SUM(rcb.activity_net_amount)) * 100, 2) ELSE 0 END AS collection_rate
FROM claims.v_rejected_claims_base rcb
GROUP BY rcb.claim_year, rcb.claim_month_name, rcb.facility_id, rcb.facility_name, rcb.payer_id, rcb.payer_name;

COMMENT ON VIEW claims.v_rejected_claims_summary_by_year IS 'Summary by year/month for Rejected Claims Report';

-- Detailed summary
CREATE OR REPLACE VIEW claims.v_rejected_claims_summary AS
SELECT 
    rcb.facility_id,
    rcb.facility_name,
    rcb.claim_year,
    rcb.claim_month_name,
    rcb.payer_id AS id_payer,
    rcb.payer_name,
    COUNT(DISTINCT rcb.claim_key_id) AS total_claim,
    SUM(rcb.activity_net_amount) AS claim_amt,
    COUNT(DISTINCT CASE WHEN rcb.activity_payment_amount > 0 THEN rcb.claim_key_id END) AS remitted_claim,
    SUM(rcb.activity_payment_amount) AS remitted_amt,
    COUNT(DISTINCT CASE WHEN rcb.rejection_type IN ('Fully Rejected', 'Partially Rejected') THEN rcb.claim_key_id END) AS rejected_claim,
    SUM(rcb.rejected_amount) AS rejected_amt,
    COUNT(DISTINCT CASE WHEN COALESCE(rcb.activity_payment_amount, 0) = 0 THEN rcb.claim_key_id END) AS pending_remittance,
    SUM(CASE WHEN COALESCE(rcb.activity_payment_amount, 0) = 0 THEN rcb.activity_net_amount ELSE 0 END) AS pending_remittance_amt,
    CASE WHEN (SUM(COALESCE(rcb.activity_payment_amount, 0)) + SUM(rcb.rejected_amount)) > 0 THEN ROUND((SUM(rcb.rejected_amount) / (SUM(COALESCE(rcb.activity_payment_amount, 0)) + SUM(rcb.rejected_amount))) * 100, 2) ELSE 0 END AS rejected_percentage_remittance,
    CASE WHEN (SUM(COALESCE(rcb.activity_payment_amount, 0)) + SUM(rcb.rejected_amount)) > 0 THEN ROUND((SUM(rcb.rejected_amount) / (SUM(COALESCE(rcb.activity_payment_amount, 0)) + SUM(rcb.rejected_amount))) * 100, 2) ELSE 0 END AS rejected_percentage_submission,
    rcb.claim_id AS claim_number,
    rcb.member_id,
    rcb.emirates_id_number,
    rcb.activity_net_amount AS claim_amt_detail,
    rcb.activity_payment_amount AS remitted_amt_detail,
    rcb.rejected_amount AS rejected_amt_detail,
    rcb.rejection_type,
    rcb.activity_start_date,
    rcb.activity_code,
    rcb.activity_denial_code,
    rcb.denial_type,
    rcb.clinician_name,
    rcb.ageing_days,
    rcb.current_status,
    rcb.resubmission_type,
    rcb.submission_file_id,
    rcb.remittance_file_id
FROM claims.v_rejected_claims_base rcb
GROUP BY rcb.facility_id, rcb.facility_name, rcb.claim_year, rcb.claim_month_name, rcb.payer_id, rcb.payer_name, rcb.claim_id, rcb.member_id, rcb.emirates_id_number, rcb.activity_net_amount, rcb.activity_payment_amount, rcb.rejected_amount, rcb.rejection_type, rcb.activity_start_date, rcb.activity_code, rcb.activity_denial_code, rcb.denial_type, rcb.clinician_name, rcb.ageing_days, rcb.current_status, rcb.resubmission_type, rcb.submission_file_id, rcb.remittance_file_id;

COMMENT ON VIEW claims.v_rejected_claims_summary IS 'Main summary view for Rejected Claims Report';

-- Receiver/Payer summary
CREATE OR REPLACE VIEW claims.v_rejected_claims_receiver_payer AS
SELECT 
    rcs.facility_id,
    rcs.facility_name,
    rcs.claim_year,
    rcs.claim_month_name,
    rcs.id_payer,
    rcs.payer_name,
    rcs.total_claim,
    rcs.claim_amt,
    rcs.remitted_claim,
    rcs.remitted_amt,
    rcs.rejected_claim,
    rcs.rejected_amt,
    rcs.pending_remittance,
    rcs.pending_remittance_amt,
    rcs.rejected_percentage_remittance,
    rcs.rejected_percentage_submission,
    CASE WHEN rcs.total_claim > 0 THEN ROUND(rcs.claim_amt / rcs.total_claim, 2) ELSE 0 END AS average_claim_value,
    CASE WHEN rcs.claim_amt > 0 THEN ROUND((rcs.remitted_amt / rcs.claim_amt) * 100, 2) ELSE 0 END AS collection_rate
FROM claims.v_rejected_claims_summary rcs;

COMMENT ON VIEW claims.v_rejected_claims_receiver_payer IS 'Receiver/Payer summary view for Rejected Claims Report';

-- Claim-wise detail
CREATE OR REPLACE VIEW claims.v_rejected_claims_claim_wise AS
SELECT 
    rcb.claim_key_id,
    rcb.claim_id,
    rcb.payer_id AS id_payer,
    rcb.payer_name,
    rcb.member_id,
    rcb.emirates_id_number,
    rcb.activity_net_amount AS claim_amt,
    rcb.activity_payment_amount AS remitted_amt,
    rcb.rejected_amount AS rejected_amt,
    rcb.rejection_type,
    rcb.activity_start_date AS service_date,
    rcb.activity_code,
    rcb.activity_denial_code AS denial_code,
    rcb.denial_type,
    rcb.clinician_name,
    rcb.facility_name,
    rcb.ageing_days,
    rcb.current_status,
    rcb.resubmission_type,
    rcb.resubmission_comment,
    rcb.submission_file_id,
    rcb.remittance_file_id,
    rcb.activity_start_date AS submission_transaction_date,
    rcb.activity_start_date AS remittance_transaction_date,
    NULL AS claim_comments
FROM claims.v_rejected_claims_base rcb
WHERE rcb.rejection_type IN ('Fully Rejected', 'Partially Rejected');

COMMENT ON VIEW claims.v_rejected_claims_claim_wise IS 'Claim-wise detail for Rejected Claims Report';

-- APIs for Rejected Claims (as-is from implementation)
CREATE OR REPLACE FUNCTION claims.get_rejected_claims_summary(
  p_user_id TEXT,
  p_facility_codes TEXT[],
  p_payer_codes TEXT[],
  p_receiver_ids TEXT[],
  p_date_from TIMESTAMPTZ,
  p_date_to TIMESTAMPTZ,
  p_year INTEGER,
  p_month INTEGER,
  p_limit INTEGER,
  p_offset INTEGER,
  p_order_by TEXT,
  p_order_direction TEXT,
  p_facility_ref_ids BIGINT[] DEFAULT NULL,
  p_payer_ref_ids BIGINT[] DEFAULT NULL,
  p_clinician_ref_ids BIGINT[] DEFAULT NULL
) RETURNS TABLE(
  facility_id TEXT,
  facility_name TEXT,
  claim_year NUMERIC,
  claim_month_name TEXT,
  payer_id TEXT,
  payer_name TEXT,
  total_claim BIGINT,
  claim_amt NUMERIC,
  remitted_claim BIGINT,
  remitted_amt NUMERIC,
  rejected_claim BIGINT,
  rejected_amt NUMERIC,
  pending_remittance BIGINT,
  pending_remittance_amt NUMERIC,
  rejected_percentage_remittance NUMERIC,
  rejected_percentage_submission NUMERIC,
  claim_id TEXT,
  member_id TEXT,
  emirates_id_number TEXT,
  claim_amt_detail NUMERIC,
  remitted_amt_detail NUMERIC,
  rejected_amt_detail NUMERIC,
  rejection_type TEXT,
  activity_start_date TIMESTAMPTZ,
  activity_code TEXT,
  activity_denial_code TEXT,
  denial_type TEXT,
  clinician_name TEXT,
  ageing_days INTEGER,
  current_status TEXT,
  resubmission_type TEXT,
  submission_file_id BIGINT,
  remittance_file_id BIGINT
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT
    mv.facility_id,
    mv.facility_name,
    mv.report_year as claim_year,
    TO_CHAR(mv.report_month, 'Month') as claim_month_name,
    mv.payer_id,
    mv.payer_name,
    1 as total_claim,
    mv.activity_net_amount as claim_amt,
    CASE WHEN mv.activity_payment_amount > 0 THEN 1 ELSE 0 END as remitted_claim,
    mv.activity_payment_amount as remitted_amt,
    1 as rejected_claim,
    mv.rejected_amount as rejected_amt,
    0 as pending_remittance,
    0.0 as pending_remittance_amt,
    CASE WHEN mv.activity_payment_amount > 0 THEN 
      ROUND((mv.rejected_amount / (mv.activity_payment_amount + mv.rejected_amount)) * 100, 2) 
    ELSE 0 END as rejected_percentage_remittance,
    CASE WHEN mv.activity_net_amount > 0 THEN 
      ROUND((mv.rejected_amount / mv.activity_net_amount) * 100, 2) 
    ELSE 0 END as rejected_percentage_submission,
    mv.claim_id,
    mv.member_id,
    mv.emirates_id_number,
    mv.activity_net_amount as claim_amt_detail,
    mv.activity_payment_amount as remitted_amt_detail,
    mv.rejected_amount as rejected_amt_detail,
    mv.rejection_type,
    mv.activity_start_date,
    mv.activity_code,
    mv.activity_denial_code,
    mv.denial_type,
    mv.clinician_name,
    mv.aging_days as ageing_days,
    'N/A' as current_status,
    'N/A' as resubmission_type,
    mv.submission_id as submission_file_id,
    mv.remittance_claim_id as remittance_file_id
  FROM claims.mv_rejected_claims_summary mv
  WHERE 
    (p_facility_codes IS NULL OR mv.facility_id = ANY(p_facility_codes))
    AND (p_payer_codes IS NULL OR mv.payer_id = ANY(p_payer_codes))
    AND (p_receiver_ids IS NULL OR mv.payer_name = ANY(p_receiver_ids))
    AND (p_date_from IS NULL OR mv.activity_start_date >= p_date_from)
    AND (p_date_to IS NULL OR mv.activity_start_date <= p_date_to)
    AND (p_year IS NULL OR mv.report_year = p_year)
    AND (p_month IS NULL OR mv.report_month_num = p_month)
    AND (p_facility_ref_ids IS NULL OR mv.facility_ref_id = ANY(p_facility_ref_ids))
    AND (p_payer_ref_ids IS NULL OR mv.payer_ref_id = ANY(p_payer_ref_ids))
    AND (p_clinician_ref_ids IS NULL OR mv.clinician_ref_id = ANY(p_clinician_ref_ids))
  ORDER BY mv.facility_name DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

CREATE OR REPLACE FUNCTION claims.get_rejected_claims_receiver_payer(
  p_user_id TEXT,
  p_facility_codes TEXT[],
  p_payer_codes TEXT[],
  p_receiver_ids TEXT[],
  p_date_from TIMESTAMPTZ,
  p_date_to TIMESTAMPTZ,
  p_year INTEGER,
  p_denial_codes TEXT[],
  p_limit INTEGER,
  p_offset INTEGER,
  p_order_by TEXT,
  p_order_direction TEXT,
  p_facility_ref_ids BIGINT[] DEFAULT NULL,
  p_payer_ref_ids BIGINT[] DEFAULT NULL,
  p_clinician_ref_ids BIGINT[] DEFAULT NULL
) RETURNS TABLE(
  facility_id TEXT,
  facility_name TEXT,
  claim_year NUMERIC,
  claim_month_name TEXT,
  payer_id TEXT,
  payer_name TEXT,
  total_claim BIGINT,
  claim_amt NUMERIC,
  remitted_claim BIGINT,
  remitted_amt NUMERIC,
  rejected_claim BIGINT,
  rejected_amt NUMERIC,
  pending_remittance BIGINT,
  pending_remittance_amt NUMERIC,
  rejected_percentage_remittance NUMERIC,
  rejected_percentage_submission NUMERIC,
  average_claim_value NUMERIC,
  collection_rate NUMERIC
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT
    rctb.facility_id,
    rctb.facility_name,
    rctb.claim_year,
    rctb.claim_month_name,
    rctb.payer_id,
    rctb.payer_name,
    rctb.total_claim,
    rctb.claim_amt,
    rctb.remitted_claim,
    rctb.remitted_amt,
    rctb.rejected_claim,
    rctb.rejected_amt,
    rctb.pending_remittance,
    rctb.pending_remittance_amt,
    rctb.rejected_percentage_remittance,
    rctb.rejected_percentage_submission,
    rctb.average_claim_value,
    rctb.collection_rate
  FROM claims.v_rejected_claims_receiver_payer rctb
  WHERE 
    (p_facility_codes IS NULL OR rctb.facility_id = ANY(p_facility_codes))
    AND (p_payer_codes IS NULL OR rctb.payer_id = ANY(p_payer_codes))
    AND (p_receiver_ids IS NULL OR rctb.payer_name = ANY(p_receiver_ids))
    AND (
      p_facility_ref_ids IS NULL
      OR EXISTS (
        SELECT 1 FROM claims.v_rejected_claims_base b
        WHERE b.facility_ref_id = ANY(p_facility_ref_ids) AND b.facility_id = rctb.facility_id
      )
    )
    AND (
      p_payer_ref_ids IS NULL
      OR EXISTS (
        SELECT 1 FROM claims.v_rejected_claims_base b
        WHERE b.payer_ref_id = ANY(p_payer_ref_ids) AND b.payer_id = rctb.payer_id
      )
    )
  ORDER BY rctb.facility_name ASC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

CREATE OR REPLACE FUNCTION claims.get_rejected_claims_claim_wise(
  p_user_id TEXT,
  p_facility_codes TEXT[],
  p_payer_codes TEXT[],
  p_receiver_ids TEXT[],
  p_date_from TIMESTAMPTZ,
  p_date_to TIMESTAMPTZ,
  p_year INTEGER,
  p_denial_codes TEXT[],
  p_limit INTEGER,
  p_offset INTEGER,
  p_order_by TEXT,
  p_order_direction TEXT,
  p_facility_ref_ids BIGINT[] DEFAULT NULL,
  p_payer_ref_ids BIGINT[] DEFAULT NULL,
  p_clinician_ref_ids BIGINT[] DEFAULT NULL
) RETURNS TABLE(
  claim_key_id BIGINT,
  claim_id TEXT,
  payer_id TEXT,
  payer_name TEXT,
  member_id TEXT,
  emirates_id_number TEXT,
  claim_amt NUMERIC,
  remitted_amt NUMERIC,
  rejected_amt NUMERIC,
  rejection_type TEXT,
  service_date TIMESTAMPTZ,
  activity_code TEXT,
  denial_code TEXT,
  denial_type TEXT,
  clinician_name TEXT,
  facility_name TEXT,
  ageing_days INTEGER,
  current_status TEXT,
  resubmission_type TEXT,
  resubmission_comment TEXT,
  submission_file_id BIGINT,
  remittance_file_id BIGINT,
  submission_transaction_date TIMESTAMPTZ,
  remittance_transaction_date TIMESTAMPTZ,
  claim_comments TEXT
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT
    rctc.claim_key_id,
    rctc.claim_id,
    rctc.payer_id,
    rctc.payer_name,
    rctc.member_id,
    rctc.emirates_id_number,
    rctc.claim_amt,
    rctc.remitted_amt,
    rctc.rejected_amt,
    rctc.rejection_type,
    rctc.service_date,
    rctc.activity_code,
    rctc.denial_code,
    rctc.denial_type,
    rctc.clinician_name,
    rctc.facility_name,
    rctc.ageing_days,
    rctc.current_status,
    rctc.resubmission_type,
    rctc.resubmission_comment,
    rctc.submission_file_id,
    rctc.remittance_file_id,
    rctc.submission_transaction_date,
    rctc.remittance_transaction_date,
    rctc.claim_comments
  FROM claims.v_rejected_claims_claim_wise rctc
  WHERE 
    (p_facility_codes IS NULL OR rctc.facility_name = ANY(p_facility_codes))
    AND (p_payer_codes IS NULL OR rctc.payer_id = ANY(p_payer_codes))
    AND (p_receiver_ids IS NULL OR rctc.payer_name = ANY(p_receiver_ids))
    AND (p_date_from IS NULL OR rctc.service_date >= p_date_from)
    AND (p_date_to IS NULL OR rctc.service_date <= p_date_to)
    AND (p_year IS NULL OR EXTRACT(YEAR FROM rctc.service_date) = p_year)
    AND (p_denial_codes IS NULL OR rctc.denial_code = ANY(p_denial_codes))
    AND (
      p_facility_ref_ids IS NULL
      OR EXISTS (
        SELECT 1 FROM claims.v_rejected_claims_base b
        WHERE b.facility_ref_id = ANY(p_facility_ref_ids) AND b.claim_id = rctc.claim_id
      )
    )
    AND (
      p_payer_ref_ids IS NULL
      OR EXISTS (
        SELECT 1 FROM claims.v_rejected_claims_base b
        WHERE b.payer_ref_id = ANY(p_payer_ref_ids) AND b.claim_id = rctc.claim_id
      )
    )
    AND (
      p_clinician_ref_ids IS NULL
      OR EXISTS (
        SELECT 1 FROM claims.v_rejected_claims_base b
        WHERE b.clinician_ref_id = ANY(p_clinician_ref_ids) AND b.claim_id = rctc.claim_id
      )
    )
  ORDER BY rctc.claim_id ASC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- Grants for Rejected Claims
GRANT SELECT ON claims.v_rejected_claims_base TO claims_user;
GRANT SELECT ON claims.v_rejected_claims_summary TO claims_user;
GRANT SELECT ON claims.v_rejected_claims_receiver_payer TO claims_user;
GRANT SELECT ON claims.v_rejected_claims_claim_wise TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_rejected_claims_summary TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_rejected_claims_receiver_payer TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_rejected_claims_claim_wise TO claims_user;

-- ==========================================================================================================
-- REMITTANCE ADVICE PAYERWISE - TRADITIONAL VIEWS AND PARAM FUNCTION
-- ==========================================================================================================

DROP VIEW IF EXISTS claims.v_remittance_advice_header CASCADE;
CREATE OR REPLACE VIEW claims.v_remittance_advice_header AS
WITH activity_aggregates AS (
  SELECT rc.id as remittance_claim_id,
         SUM(ra.payment_amount) as total_payment,
         COUNT(*) as activity_count,
         SUM(act.net) as total_billed,
         SUM(CASE WHEN ra.denial_code IS NOT NULL OR ra.payment_amount = 0 THEN act.net ELSE 0 END) as total_denied,
         COUNT(CASE WHEN ra.denial_code IS NOT NULL OR ra.payment_amount = 0 THEN 1 END) as denied_count,
         STRING_AGG(DISTINCT ra.denial_code, ',') as denial_codes
  FROM claims.remittance_claim rc
  JOIN claims.remittance_activity ra ON rc.id = ra.remittance_claim_id
  JOIN claims.claim c ON c.claim_key_id = rc.claim_key_id
  JOIN claims.activity act ON act.claim_id = c.id AND act.activity_id = ra.activity_id
  GROUP BY rc.id
)
SELECT COALESCE(act.clinician, '') AS clinician_id,
       COALESCE(cl.name, '') AS clinician_name,
       cl.id AS clinician_ref_id,
       COALESCE(act.prior_authorization_id, '') AS prior_authorization_id,
       COALESCE(ifile.file_name, '') AS xml_file_name,
       ''::text AS remittance_comments,
       COUNT(DISTINCT rc.id) AS total_claims,
       SUM(agg.activity_count) AS total_activities,
       SUM(COALESCE(agg.total_billed, 0)) AS total_billed_amount,
       SUM(COALESCE(agg.total_payment, 0)) AS total_paid_amount,
       SUM(COALESCE(agg.total_denied, 0)) AS total_denied_amount,
       ROUND(CASE WHEN SUM(COALESCE(agg.total_billed, 0)) > 0 THEN (SUM(COALESCE(agg.total_payment, 0)) / SUM(COALESCE(agg.total_billed, 0))) * 100 ELSE 0 END, 2) AS collection_rate,
       SUM(agg.denied_count) AS denied_activities_count,
       COALESCE(f.facility_code, '') AS facility_id,
       f.id AS facility_ref_id,
       COALESCE(f.name, '') AS facility_name,
       COALESCE(p.payer_code, '') AS payer_id,
       p.id AS payer_ref_id,
       COALESCE(p.name, '') AS payer_name,
       COALESCE(rp.provider_code, '') AS receiver_id,
       COALESCE(rp.name, '') AS receiver_name,
       r.tx_at AS remittance_date,
       COALESCE(ifile.transaction_date, r.tx_at) AS submission_date
FROM claims.remittance r
JOIN claims.remittance_claim rc ON r.id = rc.remittance_id
LEFT JOIN activity_aggregates agg ON agg.remittance_claim_id = rc.id
LEFT JOIN claims.claim c ON c.claim_key_id = rc.claim_key_id
LEFT JOIN claims.activity act ON act.claim_id = c.id
LEFT JOIN claims_ref.clinician cl ON act.clinician_ref_id = cl.id
LEFT JOIN claims.encounter enc ON enc.claim_id = c.id
LEFT JOIN claims_ref.facility f ON enc.facility_ref_id = f.id
LEFT JOIN claims_ref.payer p ON rc.payer_ref_id = p.id
LEFT JOIN claims.ingestion_file ifile ON r.ingestion_file_id = ifile.id
LEFT JOIN claims_ref.provider rp ON ifile.receiver_id = rp.provider_code
GROUP BY cl.name, cl.clinician_code, cl.id, act.clinician,
         act.prior_authorization_id, ifile.file_name,
         f.facility_code, f.id, f.name, p.payer_code, p.id, p.name, rp.provider_code, rp.name,
         r.tx_at, ifile.transaction_date;

DROP VIEW IF EXISTS claims.v_remittance_advice_claim_wise CASCADE;
CREATE OR REPLACE VIEW claims.v_remittance_advice_claim_wise AS
SELECT COALESCE(p.name, '') AS payer_name,
       p.id AS payer_ref_id,
       r.tx_at AS transaction_date,
       enc.start_at AS encounter_start,
       ck.claim_id AS claim_number,
       COALESCE(rc.id_payer, '') AS id_payer,
       COALESCE(c.member_id, '') AS member_id,
       COALESCE(rc.payment_reference, '') AS payment_reference,
       COALESCE(ra.activity_id, '') AS claim_activity_number,
       act.start_at AS start_date,
       COALESCE(f.facility_code, '') AS facility_group,
       COALESCE(ifile.sender_id, '') AS health_authority,
       COALESCE(f.facility_code, '') AS facility_id,
       f.id AS facility_ref_id,
       COALESCE(f.name, '') AS facility_name,
       COALESCE(rec.provider_code, '') AS receiver_id,
       COALESCE(rec.name, '') AS receiver_name,
       COALESCE(pc.payer_code, '') AS payer_id,
       pc.id AS claim_payer_ref_id,
       COALESCE(c.net, 0) AS claim_amount,
       COALESCE(SUM(ra.payment_amount), 0) AS remittance_amount,
       COALESCE(ifile.file_name, '') AS xml_file_name,
       COUNT(ra.id) AS activity_count,
       SUM(COALESCE(ra.payment_amount, 0)) AS total_paid,
       SUM(COALESCE(c.net - ra.payment_amount, 0)) AS total_denied,
       ROUND(CASE WHEN COALESCE(c.net, 0) > 0 THEN (SUM(COALESCE(ra.payment_amount, 0)) / c.net) * 100 ELSE 0 END, 2) AS collection_rate,
       COUNT(CASE WHEN ra.denial_code IS NOT NULL OR ra.payment_amount = 0 THEN 1 END) AS denied_count
FROM claims.remittance r
JOIN claims.remittance_claim rc ON r.id = rc.remittance_id
JOIN claims.claim_key ck ON rc.claim_key_id = ck.id
LEFT JOIN claims.claim c ON ck.id = c.claim_key_id
LEFT JOIN claims.remittance_activity ra ON rc.id = ra.remittance_claim_id
LEFT JOIN claims.activity act ON act.claim_id = c.id AND act.activity_id = ra.activity_id
LEFT JOIN claims.encounter enc ON c.id = enc.claim_id
LEFT JOIN claims_ref.facility f ON enc.facility_ref_id = f.id
LEFT JOIN claims_ref.payer p ON rc.payer_ref_id = p.id
LEFT JOIN claims_ref.payer pc ON c.payer_ref_id = pc.id
LEFT JOIN claims.ingestion_file ifile ON r.ingestion_file_id = ifile.id
LEFT JOIN claims_ref.provider rec ON ifile.receiver_id = rec.provider_code
GROUP BY p.name, p.id, r.tx_at, enc.start_at, ck.claim_id, rc.id_payer, c.member_id,
         rc.payment_reference, ra.activity_id, act.start_at, f.facility_code, f.id,
         ifile.receiver_id, f.facility_code, f.name, rec.provider_code, rec.name,
         pc.payer_code, pc.id, c.net, ifile.file_name, rc.id, ifile.sender_id
ORDER BY transaction_date DESC, claim_number;

DROP VIEW IF EXISTS claims.v_remittance_advice_activity_wise CASCADE;
CREATE OR REPLACE VIEW claims.v_remittance_advice_activity_wise AS
SELECT act.start_at AS start_date,
       COALESCE(act.type, '') AS cpt_type,
       COALESCE(act.code, '') AS cpt_code,
       COALESCE(act.quantity, 0) AS quantity,
       COALESCE(act.net, 0) AS net_amount,
       COALESCE(ra.payment_amount, 0) AS payment_amount,
       COALESCE(ra.denial_code, '') AS denial_code,
       COALESCE(act.clinician, '') AS clinician,
       COALESCE(ifile.file_name, '') AS xml_file_name,
       COALESCE(act.net - ra.payment_amount, 0) AS denied_amount,
       ROUND(CASE WHEN COALESCE(act.net, 0) > 0 THEN (COALESCE(ra.payment_amount, 0) / act.net) * 100 ELSE 0 END, 2) AS payment_percentage,
       CASE
         WHEN ra.denial_code IS NOT NULL OR ra.payment_amount = 0 THEN 'DENIED'
         WHEN ra.payment_amount = act.net THEN 'FULLY_PAID'
         WHEN ra.payment_amount > 0 AND ra.payment_amount < act.net THEN 'PARTIALLY_PAID'
         ELSE 'UNPAID'
       END AS payment_status,
       ROUND(CASE WHEN COALESCE(act.quantity, 0) > 0 THEN (COALESCE(ra.payment_amount, 0) / act.quantity) ELSE 0 END, 2) AS unit_price,
       COALESCE(f.facility_code, '') AS facility_id,
       COALESCE(p.payer_code, '') AS payer_id,
       ck.claim_id AS claim_number,
       enc.start_at AS encounter_start_date
FROM claims.remittance r
JOIN claims.remittance_claim rc ON r.id = rc.remittance_id
JOIN claims.remittance_activity ra ON rc.id = ra.remittance_claim_id
LEFT JOIN claims.claim c ON c.claim_key_id = rc.claim_key_id
JOIN claims.claim_key ck ON rc.claim_key_id = ck.id
JOIN claims.activity act ON act.claim_id = c.id AND act.activity_id = ra.activity_id
LEFT JOIN claims.encounter enc ON c.id = enc.claim_id
LEFT JOIN claims_ref.facility f ON enc.facility_ref_id = f.id
LEFT JOIN claims_ref.payer p ON rc.payer_ref_id = p.id
LEFT JOIN claims.ingestion_file ifile ON r.ingestion_file_id = ifile.id
ORDER BY act.start_at DESC, act.code;

-- Params function
DROP FUNCTION IF EXISTS claims.get_remittance_advice_report_params(timestamptz,timestamptz,text,text,text,text,bigint,bigint) CASCADE;
CREATE OR REPLACE FUNCTION claims.get_remittance_advice_report_params(
    p_from_date timestamptz DEFAULT NULL,
    p_to_date timestamptz DEFAULT NULL,
    p_facility_code text DEFAULT NULL,
    p_payer_code text DEFAULT NULL,
    p_receiver_code text DEFAULT NULL,
    p_payment_reference text DEFAULT NULL,
    p_facility_ref_id BIGINT DEFAULT NULL,
    p_payer_ref_id BIGINT DEFAULT NULL
)
RETURNS TABLE(
    total_claims bigint,
    total_activities bigint,
    total_billed_amount numeric(14,2),
    total_paid_amount numeric(14,2),
    total_denied_amount numeric(14,2),
    avg_collection_rate numeric(5,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        SUM(mv.total_claims) AS total_claims,
        SUM(mv.total_activities) AS total_activities,
        SUM(mv.total_billed_amount) AS total_billed_amount,
        SUM(mv.total_paid_amount) AS total_paid_amount,
        SUM(mv.total_denied_amount) AS total_denied_amount,
        AVG(mv.collection_rate) AS avg_collection_rate
    FROM claims.mv_remittance_advice_summary mv
    WHERE mv.remittance_date >= COALESCE(p_from_date, mv.remittance_date - INTERVAL '30 days')
      AND mv.remittance_date <= COALESCE(p_to_date, mv.remittance_date)
      AND (p_facility_code IS NULL OR mv.facility_id = p_facility_code)
      AND (p_payer_code IS NULL OR mv.payer_id = p_payer_code)
      AND (p_receiver_code IS NULL OR mv.receiver_id = p_receiver_code)
      AND (p_payment_reference IS NULL OR mv.payment_reference = p_payment_reference)
      AND (p_facility_ref_id IS NULL OR mv.facility_ref_id = p_facility_ref_id)
      AND (p_payer_ref_id IS NULL OR mv.payer_ref_id = p_payer_ref_id);
END;
$$ LANGUAGE plpgsql;

-- Grants for Remittance Advice
GRANT SELECT ON claims.v_remittance_advice_header TO claims_user;
GRANT SELECT ON claims.v_remittance_advice_claim_wise TO claims_user;
GRANT SELECT ON claims.v_remittance_advice_activity_wise TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_remittance_advice_report_params(timestamptz,timestamptz,text,text,text,text,bigint,bigint) TO claims_user;

-- ==========================================================================================================
-- CLAIM DETAILS WITH ACTIVITY – VIEW AND APIS
-- ==========================================================================================================

CREATE OR REPLACE VIEW claims.v_claim_details_with_activity AS
SELECT
    ck.claim_id,
    c.id as claim_db_id,
    c.payer_id,
    c.provider_id,
    c.member_id,
    c.emirates_id_number,
    c.gross,
    c.patient_share,
    c.net as initial_net_amount,
    c.comments,
    c.tx_at as submission_date,
    pr.name as provider_name,
    pr.provider_code as receiver_id,
    c.provider_ref_id as provider_ref_id,
    py.name as payer_name,
    py.payer_code as payer_code,
    c.payer_ref_id as payer_ref_id,
    e.facility_id,
    e.type as encounter_type,
    e.patient_id,
    e.start_at as encounter_start,
    e.end_at as encounter_end_date,
    e.start_type,
    e.end_type,
    e.facility_ref_id as facility_ref_id,
    f.name as facility_name,
    f.facility_code as facility_group,
    s.id as submission_id,
    s.tx_at as submission_transaction_date,
    rc.id as remittance_claim_id,
    rc.id_payer,
    rc.payment_reference,
    rc.date_settlement as initial_date_settlement,
    rc.denial_code as initial_denial_code,
    rc.denial_code_ref_id as denial_code_ref_id,
    rc.provider_ref_id as remittance_provider_ref_id,
    rc.payer_ref_id as remittance_payer_ref_id,
    r.tx_at as remittance_date,
    r.id as remittance_id,
    a.activity_id as claim_activity_number,
    a.start_at as activity_start_date,
    a.type as activity_type,
    a.code as cpt_code,
    a.quantity,
    a.net as activity_net_amount,
    a.clinician as clinician,
    a.prior_authorization_id,
    a.clinician_ref_id as clinician_ref_id,
    cl.name as clinician_name,
    ac.description as activity_description,
    a.activity_code_ref_id as activity_code_ref_id,
    d_principal.code as primary_diagnosis,
    d_principal.diag_type as primary_diagnosis_type,
    d_secondary.code as secondary_diagnosis,
    d_secondary.diag_type as secondary_diagnosis_type,
    if_submission.file_id as last_submission_file,
    if_submission.transaction_date as last_submission_transaction_date,
    if_remittance.file_id as last_remittance_file,
    if_remittance.transaction_date as last_remittance_transaction_date,
    cst.status as claim_status,
    cst.status_time as claim_status_time,
    CASE
        WHEN ra.payment_amount > 0 AND ra.payment_amount = ra.net THEN 'Fully Paid'
        WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN 'Partially Paid'
        WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 'Rejected'
        WHEN rc.date_settlement IS NULL THEN 'Pending'
        ELSE 'Unknown'
    END as payment_status,
    COALESCE(ra.payment_amount, 0) as remitted_amount,
    COALESCE(ra.payment_amount, 0) as settled_amount,
    CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END as rejected_amount,
    CASE WHEN rc.date_settlement IS NULL THEN c.net ELSE 0 END as unprocessed_amount,
    CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END as initial_rejected_amount,
    ra.denial_code as last_denial_code,
    ''::text as remittance_comments,
    c.comments as denial_comment,
    cr.resubmission_type,
    cr.comment as resubmission_comment,
    CASE WHEN c.net > 0 THEN ROUND((COALESCE(ra.payment_amount, 0) / c.net) * 100, 2) ELSE 0 END as net_collection_rate,
    CASE WHEN (COALESCE(ra.payment_amount, 0) + (CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) > 0 THEN
         ROUND(((CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) / (COALESCE(ra.payment_amount, 0) + (CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END))) * 100, 2)
         ELSE 0 END as denial_rate,
    CASE WHEN e.start_at IS NOT NULL AND r.tx_at IS NOT NULL THEN EXTRACT(DAYS FROM (r.tx_at - e.start_at))::int ELSE NULL END as turnaround_time_days,
    CASE WHEN cr.id IS NOT NULL AND ra.payment_amount > 0 THEN CASE WHEN (CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) > 0 THEN ROUND((ra.payment_amount / (CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) * 100, 2) ELSE 0 END ELSE 0 END as resubmission_effectiveness,
    c.created_at,
    c.updated_at,
    r.created_at as remittance_created_at,
    rc.created_at as remittance_claim_created_at
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.submission s ON s.id = c.submission_id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims.claim_status_timeline cst ON cst.claim_key_id = ck.id AND cst.id = (
        SELECT cst2.id FROM claims.claim_status_timeline cst2 WHERE cst2.claim_key_id = ck.id ORDER BY cst2.status_time DESC, cst2.id DESC LIMIT 1)
LEFT JOIN claims.claim_event ce_resub ON ce_resub.claim_key_id = ck.id AND ce_resub.type = 2
LEFT JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce_resub.id
LEFT JOIN claims_ref.provider pr ON pr.id = c.provider_ref_id
LEFT JOIN claims_ref.payer py ON py.id = c.payer_ref_id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims_ref.activity_code ac ON ac.id = a.activity_code_ref_id
LEFT JOIN claims.diagnosis d_principal ON d_principal.claim_id = c.id AND d_principal.diag_type = 'Principal'
LEFT JOIN claims.diagnosis d_secondary ON d_secondary.claim_id = c.id AND d_secondary.diag_type = 'Secondary'
LEFT JOIN claims.ingestion_file if_submission ON if_submission.id = s.ingestion_file_id
LEFT JOIN claims.ingestion_file if_remittance ON if_remittance.id = r.ingestion_file_id
ORDER BY ck.claim_id, c.created_at DESC;

COMMENT ON VIEW claims.v_claim_details_with_activity IS 'COMPREHENSIVE Claim Details with Activity Report - Main view';

-- APIs for Claim Details
CREATE OR REPLACE FUNCTION claims.get_claim_details_with_activity(
    p_facility_code TEXT DEFAULT NULL,
    p_receiver_id TEXT DEFAULT NULL,
    p_payer_code TEXT DEFAULT NULL,
    p_clinician TEXT DEFAULT NULL,
    p_claim_id TEXT DEFAULT NULL,
    p_patient_id TEXT DEFAULT NULL,
    p_cpt_code TEXT DEFAULT NULL,
    p_claim_status TEXT DEFAULT NULL,
    p_payment_status TEXT DEFAULT NULL,
    p_encounter_type TEXT DEFAULT NULL,
    p_resub_type TEXT DEFAULT NULL,
    p_denial_code TEXT DEFAULT NULL,
    p_member_id TEXT DEFAULT NULL,
    p_payer_ref_id BIGINT DEFAULT NULL,
    p_provider_ref_id BIGINT DEFAULT NULL,
    p_facility_ref_id BIGINT DEFAULT NULL,
    p_clinician_ref_id BIGINT DEFAULT NULL,
    p_activity_code_ref_id BIGINT DEFAULT NULL,
    p_denial_code_ref_id BIGINT DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NULL,
    p_to_date TIMESTAMPTZ DEFAULT NULL,
    p_limit INTEGER DEFAULT 1000,
    p_offset INTEGER DEFAULT 0
) RETURNS TABLE(
    claim_id TEXT,
    claim_db_id BIGINT,
    payer_id TEXT,
    provider_id TEXT,
    member_id TEXT,
    emirates_id_number TEXT,
    gross_amount NUMERIC(14,2),
    patient_share NUMERIC(14,2),
    initial_net_amount NUMERIC(14,2),
    comments TEXT,
    submission_date TIMESTAMPTZ,
    provider_name TEXT,
    receiver_id TEXT,
    payer_name TEXT,
    payer_code TEXT,
    facility_id TEXT,
    encounter_type TEXT,
    patient_id TEXT,
    encounter_start TIMESTAMPTZ,
    encounter_end_date TIMESTAMPTZ,
    facility_name TEXT,
    facility_group TEXT,
    submission_id BIGINT,
    submission_transaction_date TIMESTAMPTZ,
    remittance_claim_id BIGINT,
    remittance_payer_id TEXT,
    payment_reference TEXT,
    initial_date_settlement TIMESTAMPTZ,
    initial_denial_code TEXT,
    remittance_date TIMESTAMPTZ,
    remittance_id BIGINT,
    claim_activity_number TEXT,
    activity_start_date TIMESTAMPTZ,
    activity_type TEXT,
    cpt_code TEXT,
    quantity NUMERIC(14,2),
    activity_net_amount NUMERIC(14,2),
    clinician TEXT,
    prior_authorization_id TEXT,
    clinician_name TEXT,
    activity_description TEXT,
    primary_diagnosis TEXT,
    secondary_diagnosis TEXT,
    last_submission_file TEXT,
    last_submission_transaction_date TIMESTAMPTZ,
    last_remittance_file TEXT,
    last_remittance_transaction_date TIMESTAMPTZ,
    claim_status TEXT,
    claim_status_time TIMESTAMPTZ,
    payment_status TEXT,
    remitted_amount NUMERIC(14,2),
    settled_amount NUMERIC(14,2),
    rejected_amount NUMERIC(14,2),
    unprocessed_amount NUMERIC(14,2),
    initial_rejected_amount NUMERIC(14,2),
    last_denial_code TEXT,
    remittance_comments TEXT,
    denial_comment TEXT,
    resubmission_type TEXT,
    resubmission_comment TEXT,
    net_collection_rate NUMERIC(5,2),
    denial_rate NUMERIC(5,2),
    turnaround_time_days INTEGER,
    resubmission_effectiveness NUMERIC(5,2),
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        mv.claim_id,
        mv.claim_db_id,
        mv.payer_id,
        mv.provider_id,
        mv.member_id,
        mv.emirates_id_number,
        mv.gross,
        mv.patient_share,
        mv.initial_net_amount,
        mv.comments,
        mv.submission_date,
        mv.provider_name,
        mv.receiver_id,
        mv.payer_name,
        mv.payer_code,
        mv.facility_id,
        mv.encounter_type,
        mv.patient_id,
        mv.encounter_start,
        mv.encounter_end_date,
        mv.facility_name,
        mv.facility_group,
        mv.submission_id,
        mv.submission_transaction_date,
        mv.remittance_claim_id,
        mv.id_payer,
        mv.payment_reference,
        mv.initial_date_settlement,
        mv.initial_denial_code,
        mv.remittance_date,
        mv.remittance_id,
        mv.claim_activity_number,
        mv.activity_start_date,
        mv.activity_type,
        mv.cpt_code,
        mv.quantity,
        mv.activity_net_amount,
        mv.clinician,
        mv.prior_authorization_id,
        mv.clinician_name,
        mv.activity_description,
        mv.primary_diagnosis,
        mv.secondary_diagnosis,
        mv.last_submission_file,
        mv.last_submission_transaction_date,
        mv.last_remittance_file,
        mv.last_remittance_transaction_date,
        mv.claim_status,
        mv.claim_status_time,
        mv.payment_status,
        mv.remitted_amount,
        mv.settled_amount,
        mv.rejected_amount,
        mv.unprocessed_amount,
        mv.initial_rejected_amount,
        mv.last_denial_code,
        mv.remittance_comments,
        mv.denial_comment,
        mv.resubmission_type,
        mv.resubmission_comment,
        mv.net_collection_rate,
        mv.denial_rate,
        mv.turnaround_time_days,
        mv.resubmission_effectiveness,
        mv.created_at,
        mv.updated_at
    FROM claims.mv_claim_details_complete mv
    WHERE
        (p_facility_code IS NULL OR mv.facility_id = p_facility_code)
        AND (p_receiver_id IS NULL OR mv.receiver_id = p_receiver_id)
        AND (p_payer_code IS NULL OR mv.payer_code = p_payer_code)
        AND (p_clinician IS NULL OR mv.clinician = p_clinician)
        AND (p_claim_id IS NULL OR mv.claim_id = p_claim_id)
        AND (p_patient_id IS NULL OR mv.patient_id = p_patient_id)
        AND (p_cpt_code IS NULL OR mv.cpt_code = p_cpt_code)
        AND (p_claim_status IS NULL OR mv.claim_status = p_claim_status)
        AND (p_payment_status IS NULL OR mv.payment_status = p_payment_status)
        AND (p_encounter_type IS NULL OR mv.encounter_type = p_encounter_type)
        AND (p_resub_type IS NULL OR mv.resubmission_type = p_resub_type)
        AND (p_denial_code IS NULL OR mv.last_denial_code = p_denial_code)
        AND (p_member_id IS NULL OR mv.member_id = p_member_id)
        AND (p_payer_ref_id IS NULL OR mv.payer_ref_id = p_payer_ref_id)
        AND (p_provider_ref_id IS NULL OR mv.provider_ref_id = p_provider_ref_id OR mv.remittance_provider_ref_id = p_provider_ref_id)
        AND (p_facility_ref_id IS NULL OR mv.facility_ref_id = p_facility_ref_id)
        AND (p_clinician_ref_id IS NULL OR mv.clinician_ref_id = p_clinician_ref_id)
        AND (p_activity_code_ref_id IS NULL OR mv.activity_code_ref_id = p_activity_code_ref_id)
        AND (p_denial_code_ref_id IS NULL OR mv.denial_code_ref_id = p_denial_code_ref_id)
        AND (p_from_date IS NULL OR mv.submission_date >= p_from_date)
        AND (p_to_date IS NULL OR mv.submission_date <= p_to_date)
    ORDER BY mv.submission_date DESC, mv.claim_id
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION claims.get_claim_details_summary(
    p_facility_code TEXT DEFAULT NULL,
    p_receiver_id TEXT DEFAULT NULL,
    p_payer_code TEXT DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NULL,
    p_to_date TIMESTAMPTZ DEFAULT NULL
) RETURNS TABLE(
    total_claims BIGINT,
    total_claim_amount NUMERIC(14,2),
    total_paid_amount NUMERIC(14,2),
    total_rejected_amount NUMERIC(14,2),
    total_pending_amount NUMERIC(14,2),
    avg_collection_rate NUMERIC(5,2),
    avg_denial_rate NUMERIC(5,2),
    avg_turnaround_time NUMERIC(5,2),
    fully_paid_count BIGINT,
    partially_paid_count BIGINT,
    fully_rejected_count BIGINT,
    pending_count BIGINT,
    resubmitted_count BIGINT,
    unique_patients BIGINT,
    unique_providers BIGINT,
    unique_facilities BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH filtered_data AS (
        SELECT mv.claim_id,
               mv.initial_net_amount,
               mv.remitted_amount,
               mv.rejected_amount,
               mv.unprocessed_amount,
               mv.net_collection_rate,
               mv.denial_rate,
               mv.turnaround_time_days,
               mv.payment_status,
               mv.resubmission_type,
               mv.patient_id,
               mv.provider_id,
               mv.facility_id
        FROM claims.mv_claim_details_complete mv
        WHERE (p_facility_code IS NULL OR mv.facility_id = p_facility_code)
          AND (p_receiver_id IS NULL OR mv.receiver_id = p_receiver_id)
          AND (p_payer_code IS NULL OR mv.payer_code = p_payer_code)
          AND (p_from_date IS NULL OR mv.submission_date >= p_from_date)
          AND (p_to_date IS NULL OR mv.submission_date <= p_to_date)
    ), claim_level AS (
        SELECT claim_id,
               MAX(initial_net_amount) AS initial_net_amount,
               MAX(unprocessed_amount) AS unprocessed_amount
        FROM filtered_data
        GROUP BY claim_id
    )
    SELECT COUNT(DISTINCT claim_id) as total_claims,
           (SELECT SUM(initial_net_amount) FROM claim_level) as total_claim_amount,
           SUM(remitted_amount) as total_paid_amount,
           SUM(rejected_amount) as total_rejected_amount,
           (SELECT SUM(unprocessed_amount) FROM claim_level) as total_pending_amount,
           ROUND(AVG(net_collection_rate), 2) as avg_collection_rate,
           ROUND(AVG(denial_rate), 2) as avg_denial_rate,
           ROUND(AVG(turnaround_time_days), 2) as avg_turnaround_time,
           COUNT(DISTINCT CASE WHEN payment_status = 'Fully Paid' THEN claim_id END) as fully_paid_count,
           COUNT(DISTINCT CASE WHEN payment_status = 'Partially Paid' THEN claim_id END) as partially_paid_count,
           COUNT(DISTINCT CASE WHEN payment_status = 'Rejected' THEN claim_id END) as fully_rejected_count,
           COUNT(DISTINCT CASE WHEN payment_status = 'Pending' THEN claim_id END) as pending_count,
           COUNT(DISTINCT CASE WHEN resubmission_type IS NOT NULL THEN claim_id END) as resubmitted_count,
           COUNT(DISTINCT patient_id) as unique_patients,
           COUNT(DISTINCT provider_id) as unique_providers,
           COUNT(DISTINCT facility_id) as unique_facilities
    FROM filtered_data;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION claims.get_claim_details_filter_options() RETURNS TABLE(
    facility_codes TEXT[],
    receiver_codes TEXT[],
    payer_codes TEXT[],
    clinician_codes TEXT[],
    cpt_codes TEXT[],
    claim_statuses TEXT[],
    payment_statuses TEXT[],
    encounter_types TEXT[],
    resubmission_types TEXT[],
    denial_codes TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT ARRAY_AGG(DISTINCT f.facility_code ORDER BY f.facility_code) FILTER (WHERE f.facility_code IS NOT NULL),
           ARRAY_AGG(DISTINCT pr.provider_code ORDER BY pr.provider_code) FILTER (WHERE pr.provider_code IS NOT NULL),
           ARRAY_AGG(DISTINCT p.payer_code ORDER BY p.payer_code) FILTER (WHERE p.payer_code IS NOT NULL),
           ARRAY_AGG(DISTINCT cl.clinician_code ORDER BY cl.clinician_code) FILTER (WHERE cl.clinician_code IS NOT NULL),
           ARRAY_AGG(DISTINCT ac.code ORDER BY ac.code) FILTER (WHERE ac.code IS NOT NULL),
           ARRAY_AGG(DISTINCT cst.status ORDER BY cst.status) FILTER (WHERE cst.status IS NOT NULL),
           ARRAY_AGG(DISTINCT CASE WHEN ra.payment_amount > 0 AND ra.payment_amount = ra.net THEN 'Fully Paid' WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN 'Partially Paid' WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 'Rejected' WHEN rc.date_settlement IS NULL THEN 'Pending' ELSE 'Unknown' END ORDER BY 1) FILTER (WHERE ra.id IS NOT NULL OR rc.id IS NOT NULL),
           ARRAY_AGG(DISTINCT e.type ORDER BY e.type) FILTER (WHERE e.type IS NOT NULL),
           ARRAY_AGG(DISTINCT cr.resubmission_type ORDER BY cr.resubmission_type) FILTER (WHERE cr.resubmission_type IS NOT NULL),
           ARRAY_AGG(DISTINCT ra.denial_code ORDER BY ra.denial_code) FILTER (WHERE ra.denial_code IS NOT NULL)
    FROM claims_ref.facility f
    FULL OUTER JOIN claims_ref.provider pr ON true
    FULL OUTER JOIN claims_ref.payer p ON true
    FULL OUTER JOIN claims_ref.clinician cl ON true
    FULL OUTER JOIN claims_ref.activity_code ac ON true
    FULL OUTER JOIN claims.claim_status_timeline cst ON true
    FULL OUTER JOIN claims.remittance_activity ra ON true
    FULL OUTER JOIN claims.remittance_claim rc ON true
    FULL OUTER JOIN claims.encounter e ON true
    FULL OUTER JOIN claims.claim_resubmission cr ON true;
END;
$$ LANGUAGE plpgsql;

-- Grants for Claim Details
GRANT SELECT ON claims.v_claim_details_with_activity TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_claim_details_with_activity(text,text,text,text,text,text,text,text,text,text,text,text,text,bigint,bigint,bigint,bigint,bigint,bigint,timestamptz,timestamptz,integer,integer) TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_claim_details_summary(text,text,text,timestamptz,timestamptz) TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_claim_details_filter_options() TO claims_user;

-- ==========================================================================================================
-- DOCTOR DENIAL REPORT – VIEWS AND FUNCTIONS
-- ==========================================================================================================

-- Views
CREATE OR REPLACE VIEW claims.v_doctor_denial_high_denial AS
WITH payer_rankings AS (
  SELECT clinician_ref_id, payer_id, COUNT(*) as claim_count,
         ROW_NUMBER() OVER (PARTITION BY clinician_ref_id ORDER BY COUNT(*) DESC) as payer_rank
  FROM claims.activity a JOIN claims.claim c ON a.claim_id = c.id
  GROUP BY clinician_ref_id, payer_id
)
SELECT a.clinician as clinician_id, cl.name as clinician_name, cl.specialty as clinician_specialty,
       a.clinician_ref_id as clinician_ref_id,
       e.facility_id, e.facility_ref_id as facility_ref_id, f.name as facility_name, f.facility_code as facility_group,
       COALESCE(py.payer_code, 'Unknown') as health_authority, COALESCE(c.payer_ref_id, rc.payer_ref_id) as payer_ref_id,
       DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)) as report_month,
       EXTRACT(YEAR FROM COALESCE(rc.date_settlement, c.tx_at)) as report_year,
       EXTRACT(MONTH FROM COALESCE(rc.date_settlement, c.tx_at)) as report_month_num,
       COUNT(DISTINCT ck.claim_id) as total_claims,
       COUNT(DISTINCT CASE WHEN ra.id IS NOT NULL THEN ck.claim_id END) as remitted_claims,
       COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ck.claim_id END) as rejected_claims,
       COUNT(DISTINCT CASE WHEN rc.date_settlement IS NULL THEN ck.claim_id END) as pending_remittance_claims,
       SUM(a.net) as total_claim_amount,
       SUM(COALESCE(ra.payment_amount, 0)) as remitted_amount,
       SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) as rejected_amount,
       SUM(CASE WHEN rc.date_settlement IS NULL THEN a.net ELSE 0 END) as pending_remittance_amount,
       CASE WHEN COUNT(DISTINCT ck.claim_id) > 0 THEN ROUND((COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ck.claim_id END) * 100.0) / COUNT(DISTINCT ck.claim_id), 2) ELSE 0 END as rejection_percentage,
       CASE WHEN SUM(a.net) > 0 THEN ROUND((SUM(COALESCE(ra.payment_amount, 0)) / SUM(a.net)) * 100, 2) ELSE 0 END as collection_rate,
       CASE WHEN COUNT(DISTINCT ck.claim_id) > 0 THEN ROUND((SUM(a.net) / COUNT(DISTINCT ck.claim_id)), 2) ELSE 0 END as avg_claim_value,
       COUNT(DISTINCT c.provider_id) as unique_providers, COUNT(DISTINCT e.patient_id) as unique_patients,
       MIN(c.tx_at) as earliest_submission, MAX(c.tx_at) as latest_submission,
       AVG(EXTRACT(DAYS FROM (COALESCE(rc.date_settlement, c.tx_at) - c.tx_at))) as avg_processing_days
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer py ON py.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
GROUP BY a.clinician, cl.name, cl.specialty, a.clinician_ref_id, e.facility_id, e.facility_ref_id,
         f.name, f.facility_code, COALESCE(py.payer_code, 'Unknown'), COALESCE(c.payer_ref_id, rc.payer_ref_id),
         DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)), EXTRACT(YEAR FROM COALESCE(rc.date_settlement, c.tx_at)), EXTRACT(MONTH FROM COALESCE(rc.date_settlement, c.tx_at))
ORDER BY rejection_percentage DESC, total_claims DESC, clinician_name;

CREATE OR REPLACE VIEW claims.v_doctor_denial_summary AS
SELECT a.clinician as clinician_id, cl.name as clinician_name, cl.specialty as clinician_specialty,
       a.clinician_ref_id as clinician_ref_id, e.facility_id, e.facility_ref_id as facility_ref_id, f.name as facility_name,
       f.facility_code as facility_group, COALESCE(py.payer_code, 'Unknown') as health_authority, COALESCE(c.payer_ref_id, rc.payer_ref_id) as payer_ref_id,
       DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)) as report_month,
       EXTRACT(YEAR FROM COALESCE(rc.date_settlement, c.tx_at)) as report_year,
       EXTRACT(MONTH FROM COALESCE(rc.date_settlement, c.tx_at)) as report_month_num,
       COUNT(DISTINCT ck.claim_id) as total_claims,
       COUNT(DISTINCT CASE WHEN ra.id IS NOT NULL THEN ck.claim_id END) as remitted_claims,
       COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ck.claim_id END) as rejected_claims,
       COUNT(DISTINCT CASE WHEN rc.date_settlement IS NULL THEN ck.claim_id END) as pending_remittance_claims,
       SUM(a.net) as total_claim_amount,
       SUM(COALESCE(ra.payment_amount, 0)) as remitted_amount,
       SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) as rejected_amount,
       SUM(CASE WHEN rc.date_settlement IS NULL THEN a.net ELSE 0 END) as pending_remittance_amount,
       SUM(a.net) - SUM(COALESCE(ra.payment_amount, 0)) as net_balance,
       (SELECT p2.payer_code FROM (
          SELECT COALESCE(c2.payer_ref_id, rc2.payer_ref_id) as payer_ref_id, COUNT(*) as claim_count
          FROM claims.claim_key ck2
          JOIN claims.claim c2 ON c2.claim_key_id = ck2.id
          LEFT JOIN claims.remittance_claim rc2 ON rc2.claim_key_id = ck2.id
          WHERE c2.id IN (SELECT c3.id FROM claims.claim c3 JOIN claims.activity a3 ON a3.claim_id = c3.id WHERE a3.clinician_ref_id = cl.id)
          GROUP BY COALESCE(c2.payer_ref_id, rc2.payer_ref_id)
          ORDER BY claim_count DESC
          LIMIT 1) top
        JOIN claims_ref.payer p2 ON p2.id = top.payer_ref_id) as top_payer_code,
       CASE WHEN COUNT(DISTINCT ck.claim_id) > 0 THEN ROUND((COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ck.claim_id END) * 100.0) / COUNT(DISTINCT ck.claim_id), 2) ELSE 0 END as rejection_percentage,
       CASE WHEN SUM(a.net) > 0 THEN ROUND((SUM(COALESCE(ra.payment_amount, 0)) / SUM(a.net)) * 100, 2) ELSE 0 END as collection_rate,
       CASE WHEN COUNT(DISTINCT ck.claim_id) > 0 THEN ROUND((SUM(a.net) / COUNT(DISTINCT ck.claim_id)), 2) ELSE 0 END as avg_claim_value,
       COUNT(DISTINCT c.provider_id) as unique_providers, COUNT(DISTINCT e.patient_id) as unique_patients,
       MIN(c.tx_at) as earliest_submission, MAX(c.tx_at) as latest_submission
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer py ON py.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
GROUP BY a.clinician, cl.id, cl.name, cl.specialty, a.clinician_ref_id, e.facility_id, e.facility_ref_id, f.name, f.facility_code,
         COALESCE(py.payer_code, 'Unknown'), COALESCE(c.payer_ref_id, rc.payer_ref_id), DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)),
         EXTRACT(YEAR FROM COALESCE(rc.date_settlement, c.tx_at)), EXTRACT(MONTH FROM COALESCE(rc.date_settlement, c.tx_at))
ORDER BY rejection_percentage DESC, total_claims DESC, clinician_name;

CREATE OR REPLACE VIEW claims.v_doctor_denial_detail AS
SELECT ck.claim_id, c.id as claim_db_id, c.payer_id, c.provider_id, c.member_id, c.emirates_id_number, c.gross, c.patient_share, c.net as claim_amount,
       pr.name as provider_name, pr.provider_code as receiver_id, py.name as payer_name, py.payer_code as payer_code, COALESCE(c.payer_ref_id, rc.payer_ref_id) as payer_ref_id, rc.id_payer as id_payer,
       e.patient_id, a.clinician as clinician_id, cl.name as clinician_name, a.clinician_ref_id as clinician_ref_id, a.activity_id as claim_activity_number,
       e.facility_id, e.facility_ref_id as facility_ref_id, f.name as facility_name, f.facility_code as facility_group,
       rc.id as remittance_claim_id, rc.payment_reference, rc.date_settlement, COALESCE(ra.payment_amount, 0) as remitted_amount,
       CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END as rejected_amount,
       CASE WHEN rc.date_settlement IS NULL THEN c.net ELSE 0 END as pending_remittance_amount,
       a.start_at as activity_start_date, a.type as activity_type, a.code as cpt_code, a.quantity,
       DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)) as report_month,
       EXTRACT(YEAR FROM COALESCE(rc.date_settlement, c.tx_at)) as report_year,
       EXTRACT(MONTH FROM COALESCE(rc.date_settlement, c.tx_at)) as report_month_num,
       c.tx_at as submission_date, r.tx_at as remittance_date, c.created_at, c.updated_at
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.provider pr ON pr.id = c.provider_ref_id
LEFT JOIN claims_ref.payer py ON py.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
ORDER BY ck.claim_id, c.created_at DESC;

-- Functions
CREATE OR REPLACE FUNCTION claims.get_doctor_denial_report(
    p_facility_code TEXT DEFAULT NULL,
    p_clinician_code TEXT DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NULL,
    p_to_date TIMESTAMPTZ DEFAULT NULL,
    p_year INTEGER DEFAULT NULL,
    p_month INTEGER DEFAULT NULL,
    p_facility_ref_id BIGINT DEFAULT NULL,
    p_clinician_ref_id BIGINT DEFAULT NULL,
    p_payer_ref_id BIGINT DEFAULT NULL,
    p_tab TEXT DEFAULT 'high_denial',
    p_limit INTEGER DEFAULT 1000,
    p_offset INTEGER DEFAULT 0
) RETURNS TABLE(
    clinician_id TEXT, clinician_name TEXT, clinician_specialty TEXT,
    facility_id TEXT, facility_name TEXT, facility_group TEXT, health_authority TEXT,
    report_month TIMESTAMPTZ, report_year INTEGER, report_month_num INTEGER,
    total_claims BIGINT, remitted_claims BIGINT, rejected_claims BIGINT, pending_remittance_claims BIGINT,
    total_claim_amount NUMERIC(14,2), remitted_amount NUMERIC(14,2), rejected_amount NUMERIC(14,2), pending_remittance_amount NUMERIC(14,2),
    rejection_percentage NUMERIC(5,2), collection_rate NUMERIC(5,2), avg_claim_value NUMERIC(14,2), net_balance NUMERIC(14,2), top_payer_code TEXT,
    unique_providers BIGINT, unique_patients BIGINT, earliest_submission TIMESTAMPTZ, latest_submission TIMESTAMPTZ, avg_processing_days NUMERIC(5,2),
    claim_id TEXT, claim_db_id BIGINT, payer_id TEXT, provider_id TEXT, member_id TEXT, emirates_id_number TEXT, patient_id TEXT,
    claim_amount NUMERIC(14,2), provider_name TEXT, receiver_id TEXT, payer_name TEXT, payer_code TEXT, id_payer TEXT,
    claim_activity_number TEXT, activity_start_date TIMESTAMPTZ, activity_type TEXT, cpt_code TEXT, quantity NUMERIC,
    remittance_claim_id BIGINT, payment_reference TEXT, date_settlement TIMESTAMPTZ, submission_date TIMESTAMPTZ, remittance_date TIMESTAMPTZ
) AS $$
BEGIN
  CASE p_tab
    WHEN 'high_denial' THEN
      RETURN QUERY SELECT mv.clinician_id, mv.clinician_name, mv.clinician_specialty, mv.facility_id, mv.facility_name,
                          mv.facility_group, mv.health_authority, mv.report_month, mv.report_year, mv.report_month_num,
                          mv.total_claims, mv.remitted_claims, mv.rejected_claims, mv.pending_remittance_claims,
                          mv.total_claim_amount, mv.remitted_amount, mv.rejected_amount, mv.pending_remittance_amount,
                          mv.rejection_percentage, mv.collection_rate, mv.avg_claim_value,
                          NULL::NUMERIC(14,2), NULL::TEXT,
                          mv.unique_providers, mv.unique_patients, mv.earliest_submission, mv.latest_submission, mv.avg_processing_days,
                          NULL::TEXT, NULL::BIGINT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::NUMERIC(14,2),
                          NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT,
                          NULL::TEXT, NULL::TIMESTAMPTZ, NULL::TEXT, NULL::TEXT, NULL::NUMERIC(14,2),
                          NULL::BIGINT, NULL::TEXT, NULL::TIMESTAMPTZ, NULL::TIMESTAMPTZ, NULL::TIMESTAMPTZ
      FROM claims.mv_doctor_denial_summary mv
      WHERE (p_facility_code IS NULL OR mv.facility_id = p_facility_code)
        AND (p_clinician_code IS NULL OR mv.clinician_id = p_clinician_code)
        AND (p_facility_ref_id IS NULL OR mv.facility_ref_id = p_facility_ref_id)
        AND (p_clinician_ref_id IS NULL OR mv.clinician_ref_id = p_clinician_ref_id)
        AND (p_payer_ref_id IS NULL OR mv.payer_ref_id = p_payer_ref_id)
        AND (p_from_date IS NULL OR mv.report_month >= DATE_TRUNC('month', p_from_date))
        AND (p_to_date IS NULL OR mv.report_month <= DATE_TRUNC('month', p_to_date))
        AND (p_year IS NULL OR mv.report_year = p_year)
        AND (p_month IS NULL OR mv.report_month_num = p_month)
      ORDER BY mv.rejection_percentage DESC, mv.total_claims DESC
      LIMIT p_limit OFFSET p_offset;
    WHEN 'summary' THEN
      RETURN QUERY SELECT vds.clinician_id, vds.clinician_name, vds.clinician_specialty, vds.facility_id, vds.facility_name,
                          vds.facility_group, vds.health_authority, vds.report_month, vds.report_year, vds.report_month_num,
                          vds.total_claims, vds.remitted_claims, vds.rejected_claims, vds.pending_remittance_claims,
                          vds.total_claim_amount, vds.remitted_amount, vds.rejected_amount, vds.pending_remittance_amount,
                          vds.rejection_percentage, vds.collection_rate, vds.avg_claim_value, vds.net_balance, vds.top_payer_code,
                          vds.unique_providers, vds.unique_patients, vds.earliest_submission, vds.latest_submission, NULL::NUMERIC(5,2),
                          NULL::TEXT, NULL::BIGINT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT,
                          NULL::NUMERIC(14,2), NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT,
                          NULL::TEXT, NULL::TIMESTAMPTZ, NULL::TEXT, NULL::TEXT, NULL::NUMERIC(14,2),
                          NULL::BIGINT, NULL::TEXT, NULL::TIMESTAMPTZ, NULL::TIMESTAMPTZ, NULL::TIMESTAMPTZ
      FROM claims.v_doctor_denial_summary vds
      WHERE (p_facility_code IS NULL OR vds.facility_id = p_facility_code)
        AND (p_clinician_code IS NULL OR vds.clinician_id = p_clinician_code)
        AND (p_facility_ref_id IS NULL OR vds.facility_ref_id = p_facility_ref_id)
        AND (p_clinician_ref_id IS NULL OR vds.clinician_ref_id = p_clinician_ref_id)
        AND (p_payer_ref_id IS NULL OR vds.payer_ref_id = p_payer_ref_id)
        AND (p_from_date IS NULL OR vds.report_month >= DATE_TRUNC('month', p_from_date))
        AND (p_to_date IS NULL OR vds.report_month <= DATE_TRUNC('month', p_to_date))
        AND (p_year IS NULL OR vds.report_year = p_year)
        AND (p_month IS NULL OR vds.report_month_num = p_month)
      ORDER BY vds.rejection_percentage DESC, vds.total_claims DESC
      LIMIT p_limit OFFSET p_offset;
    WHEN 'detail' THEN
      RETURN QUERY SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT,
                          vdd.facility_id, vdd.facility_name, vdd.facility_group, NULL::TEXT,
                          vdd.report_month, vdd.report_year, vdd.report_month_num,
                          NULL::BIGINT, NULL::BIGINT, NULL::BIGINT, NULL::BIGINT,
                          NULL::NUMERIC(14,2), NULL::NUMERIC(14,2), NULL::NUMERIC(14,2), NULL::NUMERIC(14,2),
                          NULL::NUMERIC(5,2), NULL::NUMERIC(5,2), NULL::NUMERIC(14,2), NULL::NUMERIC(14,2), NULL::TEXT,
                          NULL::BIGINT, NULL::BIGINT, NULL::TIMESTAMPTZ, NULL::TIMESTAMPTZ, NULL::NUMERIC(5,2),
                          vdd.claim_id, vdd.claim_db_id, vdd.payer_id, vdd.provider_id, vdd.member_id, vdd.emirates_id_number, vdd.patient_id,
                          vdd.claim_amount, vdd.provider_name, vdd.receiver_id, vdd.payer_name, vdd.payer_code, vdd.id_payer,
                          vdd.claim_activity_number, vdd.activity_start_date, vdd.activity_type, vdd.cpt_code, vdd.quantity,
                          vdd.remittance_claim_id, vdd.payment_reference, vdd.date_settlement,
                          vdd.submission_date, vdd.remittance_date
      FROM claims.v_doctor_denial_detail vdd
      WHERE (p_facility_code IS NULL OR vdd.facility_id = p_facility_code)
        AND (p_clinician_code IS NULL OR vdd.clinician_id = p_clinician_code)
        AND (p_facility_ref_id IS NULL OR vdd.facility_ref_id = p_facility_ref_id)
        AND (p_clinician_ref_id IS NULL OR vdd.clinician_ref_id = p_clinician_ref_id)
        AND (p_payer_ref_id IS NULL OR vdd.payer_ref_id = p_payer_ref_id)
        AND (p_from_date IS NULL OR vdd.submission_date >= p_from_date)
        AND (p_to_date IS NULL OR vdd.submission_date <= p_to_date)
        AND (p_year IS NULL OR vdd.report_year = p_year)
        AND (p_month IS NULL OR vdd.report_month_num = p_month)
      ORDER BY vdd.submission_date DESC, vdd.claim_id
      LIMIT p_limit OFFSET p_offset;
    ELSE
      RETURN QUERY SELECT * FROM claims.get_doctor_denial_report(p_facility_code, p_clinician_code, p_from_date, p_to_date, p_year, p_month, p_facility_ref_id, p_clinician_ref_id, p_payer_ref_id, 'high_denial', p_limit, p_offset);
  END CASE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION claims.get_doctor_denial_summary(
    p_facility_code TEXT DEFAULT NULL,
    p_clinician_code TEXT DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NULL,
    p_to_date TIMESTAMPTZ DEFAULT NULL,
    p_year INTEGER DEFAULT NULL,
    p_month INTEGER DEFAULT NULL
) RETURNS TABLE(
    total_doctors BIGINT, total_claims BIGINT, total_claim_amount NUMERIC(14,2), total_remitted_amount NUMERIC(14,2), total_rejected_amount NUMERIC(14,2),
    total_pending_amount NUMERIC(14,2), avg_rejection_rate NUMERIC(5,2), avg_collection_rate NUMERIC(5,2),
    doctors_with_high_denial BIGINT, high_risk_doctors BIGINT, improvement_potential NUMERIC(14,2)
) AS $$
BEGIN
  RETURN QUERY
  WITH filtered_data AS (
    SELECT vhd.clinician_id, vhd.total_claims, vhd.total_claim_amount, vhd.remitted_amount, vhd.rejected_amount, vhd.pending_remittance_amount,
           vhd.rejection_percentage, vhd.collection_rate
    FROM claims.v_doctor_denial_high_denial vhd
    WHERE (p_facility_code IS NULL OR vhd.facility_id = p_facility_code)
      AND (p_clinician_code IS NULL OR vhd.clinician_id = p_clinician_code)
      AND (p_from_date IS NULL OR vhd.report_month >= DATE_TRUNC('month', p_from_date))
      AND (p_to_date IS NULL OR vhd.report_month <= DATE_TRUNC('month', p_to_date))
      AND (p_year IS NULL OR vhd.report_year = p_year)
      AND (p_month IS NULL OR vhd.report_month_num = p_month)
  )
  SELECT COUNT(DISTINCT clinician_id), SUM(total_claims), SUM(total_claim_amount), SUM(remitted_amount), SUM(rejected_amount),
         SUM(pending_remittance_amount), ROUND(AVG(rejection_percentage), 2), ROUND(AVG(collection_rate), 2),
         COUNT(DISTINCT CASE WHEN rejection_percentage > 20 THEN clinician_id END), COUNT(DISTINCT CASE WHEN rejection_percentage > 50 THEN clinician_id END),
         SUM(CASE WHEN rejection_percentage > 20 THEN rejected_amount ELSE 0 END)
  FROM filtered_data;
END;
$$ LANGUAGE plpgsql;

-- Grants
GRANT SELECT ON claims.v_doctor_denial_high_denial TO claims_user;
GRANT SELECT ON claims.v_doctor_denial_summary TO claims_user;
GRANT SELECT ON claims.v_doctor_denial_detail TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_doctor_denial_report(text,text,timestamptz,timestamptz,integer,integer,bigint,bigint,bigint,text,integer,integer) TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_doctor_denial_summary(text,text,timestamptz,timestamptz,integer,integer) TO claims_user;

-- ==========================================================================================================
-- CLAIM SUMMARY MONTHWISE – VIEWS AND FUNCTIONS
-- ==========================================================================================================

-- Views (Monthwise, Payerwise, Encounterwise)
-- Copied from implementation with same logic
CREATE OR REPLACE VIEW claims.v_claim_summary_monthwise AS
WITH deduplicated_claims AS (
  SELECT DISTINCT ON (claim_key_id, month_bucket)
    claim_key_id,
    month_bucket,
    payer_id,
    net,
    ROW_NUMBER() OVER (PARTITION BY claim_key_id ORDER BY tx_at) as claim_rank
  FROM claims.claim c
  JOIN claims.claim_key ck ON c.claim_key_id = ck.id
  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
  WHERE DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)) IS NOT NULL
),
base AS (
    SELECT
        ck.claim_id,
        c.id AS claim_db_id,
        c.tx_at,
        e.facility_id,
        f.name AS facility_name,
        rc.date_settlement,
        rc.id AS remittance_claim_id,
        ra.id AS remittance_activity_id,
        c.net AS claim_net,
        ra.net AS ra_net,
        ra.payment_amount,
        COALESCE(p2.payer_code, 'Unknown') AS health_authority
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
    LEFT JOIN claims.encounter e ON e.claim_id = c.id
    LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
    LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
    LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
),
dedup_claim AS (
    SELECT claim_db_id,
           DATE_TRUNC('month', COALESCE(date_settlement, tx_at)) AS month_bucket,
           MAX(claim_net) AS claim_net_once
    FROM base
    GROUP BY claim_db_id, DATE_TRUNC('month', COALESCE(date_settlement, tx_at))
)
SELECT
    TO_CHAR(DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)), 'Month YYYY') AS month_year,
    EXTRACT(YEAR FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))) AS year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))) AS month,
    COUNT(DISTINCT ck.claim_id) AS count_claims,
    COUNT(DISTINCT ra.id) AS remitted_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount > 0 THEN ra.id END) AS fully_paid_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN ra.id END) AS partially_paid_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.id END) AS fully_rejected_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.id END) AS rejection_count,
    COUNT(DISTINCT CASE WHEN rc.payment_reference IS NOT NULL THEN ck.claim_id END) AS taken_back_count,
    COUNT(DISTINCT CASE WHEN rc.date_settlement IS NULL THEN ck.claim_id END) AS pending_remittance_count,
    COUNT(DISTINCT CASE WHEN c.payer_id = 'Self-Paid' THEN ck.claim_id END) AS self_pay_count,
    SUM(DISTINCT d.claim_net_once) AS claim_amount,
    SUM(DISTINCT d.claim_net_once) AS initial_claim_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS remitted_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS remitted_net_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS fully_paid_amount,
    SUM(CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN ra.payment_amount ELSE 0 END) AS partially_paid_amount,
    SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS fully_rejected_amount,
    SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS rejected_amount,
    SUM(CASE WHEN rc.date_settlement IS NULL THEN c.net ELSE 0 END) AS pending_remittance_amount,
    SUM(CASE WHEN c.payer_id = 'Self-Paid' THEN c.net ELSE 0 END) AS self_pay_amount,
    e.facility_id,
    f.name AS facility_name,
    COALESCE(p2.payer_code, 'Unknown') AS health_authority,
    CASE
        WHEN SUM(c.net) > 0 THEN
            ROUND((SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) / SUM(c.net)) * 100, 2)
        ELSE 0
    END AS rejected_percentage_on_initial,
    CASE
    WHEN (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) > 0 THEN
        ROUND(((SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) / (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END))) * 100, 2)
        ELSE 0
    END AS rejected_percentage_on_remittance,
    CASE
        WHEN SUM(c.net) > 0 THEN
            ROUND((SUM(COALESCE(ra.payment_amount, 0)) / SUM(c.net)) * 100, 2)
        ELSE 0
    END AS collection_rate,
    COUNT(DISTINCT c.provider_id) AS unique_providers,
    COUNT(DISTINCT e.patient_id) AS unique_patients,
    AVG(c.net) AS avg_claim_amount,
    AVG(COALESCE(ra.payment_amount, 0)) AS avg_paid_amount,
    MIN(c.tx_at) AS earliest_submission_date,
    MAX(c.tx_at) AS latest_submission_date,
    MIN(COALESCE(rc.date_settlement, c.tx_at)) AS earliest_settlement_date,
    MAX(COALESCE(rc.date_settlement, c.tx_at)) AS latest_settlement_date
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
LEFT JOIN dedup_claim d ON d.claim_db_id = c.id AND d.month_bucket = DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))
GROUP BY
    DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)),
    EXTRACT(YEAR FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))),
    EXTRACT(MONTH FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))),
    e.facility_id,
    f.name,
    COALESCE(p2.payer_code, 'Unknown')
ORDER BY year DESC, month DESC, facility_id;

COMMENT ON VIEW claims.v_claim_summary_monthwise IS 'Claim Summary Monthwise Report - Tab A: Monthly grouped data with COMPREHENSIVE metrics including all counts, amounts, and percentages';

CREATE OR REPLACE VIEW claims.v_claim_summary_payerwise AS
WITH base AS (
    SELECT
        ck.claim_id,
        c.id AS claim_db_id,
        c.tx_at,
        e.facility_id,
        f.name AS facility_name,
        rc.date_settlement,
        ra.id AS remittance_activity_id,
        c.net AS claim_net,
        ra.net AS ra_net,
        ra.payment_amount,
        COALESCE(p2.payer_code, 'Unknown') AS health_authority,
        p.payer_code AS payer_code,
        p.name AS payer_name
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
    LEFT JOIN claims.encounter e ON e.claim_id = c.id
    LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
    LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
    LEFT JOIN claims_ref.payer p ON p.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
    LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
),
dedup_claim AS (
    SELECT claim_db_id,
           DATE_TRUNC('month', COALESCE(date_settlement, tx_at)) AS month_bucket,
           MAX(claim_net) AS claim_net_once
    FROM base
    GROUP BY claim_db_id, DATE_TRUNC('month', COALESCE(date_settlement, tx_at))
)
SELECT
    COALESCE(p.payer_code, 'Unknown') AS payer_id,
    p.name AS payer_name,
    TO_CHAR(DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)), 'Month YYYY') AS month_year,
    EXTRACT(YEAR FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))) AS year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))) AS month,
    COUNT(DISTINCT ck.claim_id) AS count_claims,
    COUNT(DISTINCT ra.id) AS remitted_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount > 0 THEN ra.id END) AS fully_paid_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN ra.id END) AS partially_paid_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.id END) AS fully_rejected_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.id END) AS rejection_count,
    COUNT(DISTINCT CASE WHEN rc.payment_reference IS NOT NULL THEN ck.claim_id END) AS taken_back_count,
    COUNT(DISTINCT CASE WHEN rc.date_settlement IS NULL THEN ck.claim_id END) AS pending_remittance_count,
    COUNT(DISTINCT CASE WHEN c.payer_id = 'Self-Paid' THEN ck.claim_id END) AS self_pay_count,
    SUM(DISTINCT d.claim_net_once) AS claim_amount,
    SUM(DISTINCT d.claim_net_once) AS initial_claim_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS remitted_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS remitted_net_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS fully_paid_amount,
    SUM(CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN ra.payment_amount ELSE 0 END) AS partially_paid_amount,
    SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS fully_rejected_amount,
    SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS rejected_amount,
    SUM(CASE WHEN rc.date_settlement IS NULL THEN c.net ELSE 0 END) AS pending_remittance_amount,
    SUM(CASE WHEN c.payer_id = 'Self-Paid' THEN c.net ELSE 0 END) AS self_pay_amount,
    e.facility_id,
    f.name AS facility_name,
    COALESCE(p2.payer_code, 'Unknown') AS health_authority,
    CASE
        WHEN SUM(c.net) > 0 THEN
            ROUND((SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) / SUM(c.net)) * 100, 2)
        ELSE 0
    END AS rejected_percentage_on_initial,
    CASE
    WHEN (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) > 0 THEN
        ROUND(((SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) / (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END))) * 100, 2)
        ELSE 0
    END AS rejected_percentage_on_remittance,
    CASE
        WHEN SUM(c.net) > 0 THEN
            ROUND((SUM(COALESCE(ra.payment_amount, 0)) / SUM(c.net)) * 100, 2)
        ELSE 0
    END AS collection_rate,
    COUNT(DISTINCT c.provider_id) AS unique_providers,
    COUNT(DISTINCT e.patient_id) AS unique_patients,
    AVG(c.net) AS avg_claim_amount,
    AVG(COALESCE(ra.payment_amount, 0)) AS avg_paid_amount
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer p ON p.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
LEFT JOIN dedup_claim d ON d.claim_db_id = c.id AND d.month_bucket = DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))
GROUP BY
    COALESCE(p.payer_code, 'Unknown'),
    p.name,
    DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)),
    EXTRACT(YEAR FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))),
    EXTRACT(MONTH FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))),
    e.facility_id,
    f.name,
    COALESCE(p2.payer_code, 'Unknown')
ORDER BY payer_id, year DESC, month DESC, facility_id;

COMMENT ON VIEW claims.v_claim_summary_payerwise IS 'Claim Summary Payerwise Report - Tab B: Payer grouped data with COMPREHENSIVE metrics';

CREATE OR REPLACE VIEW claims.v_claim_summary_encounterwise AS
WITH base AS (
    SELECT
        ck.claim_id,
        c.id AS claim_db_id,
        c.tx_at,
        e.type AS encounter_type,
        e.facility_id,
        f.name AS facility_name,
        rc.date_settlement,
        ra.id AS remittance_activity_id,
        c.net AS claim_net,
        ra.net AS ra_net,
        ra.payment_amount,
        COALESCE(p2.payer_code, 'Unknown') AS health_authority
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
    LEFT JOIN claims.encounter e ON e.claim_id = c.id
    LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
    LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
    LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
),
dedup_claim AS (
    SELECT claim_db_id,
           DATE_TRUNC('month', COALESCE(date_settlement, tx_at)) AS month_bucket,
           MAX(claim_net) AS claim_net_once
    FROM base
    GROUP BY claim_db_id, DATE_TRUNC('month', COALESCE(date_settlement, tx_at))
)
SELECT
    COALESCE(e.type, 'Unknown') AS encounter_type,
    TO_CHAR(DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)), 'Month YYYY') AS month_year,
    EXTRACT(YEAR FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))) AS year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))) AS month,
    COUNT(DISTINCT ck.claim_id) AS count_claims,
    COUNT(DISTINCT ra.id) AS remitted_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount > 0 THEN ra.id END) AS fully_paid_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN ra.id END) AS partially_paid_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.id END) AS fully_rejected_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.id END) AS rejection_count,
    COUNT(DISTINCT CASE WHEN rc.payment_reference IS NOT NULL THEN ck.claim_id END) AS taken_back_count,
    COUNT(DISTINCT CASE WHEN rc.date_settlement IS NULL THEN ck.claim_id END) AS pending_remittance_count,
    COUNT(DISTINCT CASE WHEN c.payer_id = 'Self-Paid' THEN ck.claim_id END) AS self_pay_count,
    SUM(DISTINCT d.claim_net_once) AS claim_amount,
    SUM(DISTINCT d.claim_net_once) AS initial_claim_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS remitted_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS remitted_net_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS fully_paid_amount,
    SUM(CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN ra.payment_amount ELSE 0 END) AS partially_paid_amount,
    SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS fully_rejected_amount,
    SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS rejected_amount,
    SUM(CASE WHEN rc.date_settlement IS NULL THEN c.net ELSE 0 END) AS pending_remittance_amount,
    SUM(CASE WHEN c.payer_id = 'Self-Paid' THEN c.net ELSE 0 END) AS self_pay_amount,
    e.facility_id,
    f.name AS facility_name,
    COALESCE(p2.payer_code, 'Unknown') AS health_authority,
    CASE
        WHEN SUM(c.net) > 0 THEN
            ROUND((SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) / SUM(c.net)) * 100, 2)
        ELSE 0
    END AS rejected_percentage_on_initial,
    CASE
    WHEN (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) > 0 THEN
        ROUND(((SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) / (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END))) * 100, 2)
        ELSE 0
    END AS rejected_percentage_on_remittance,
    CASE
        WHEN SUM(c.net) > 0 THEN
            ROUND((SUM(COALESCE(ra.payment_amount, 0)) / SUM(c.net)) * 100, 2)
        ELSE 0
    END AS collection_rate,
    COUNT(DISTINCT c.provider_id) AS unique_providers,
    COUNT(DISTINCT e.patient_id) AS unique_patients,
    AVG(c.net) AS avg_claim_amount,
    AVG(COALESCE(ra.payment_amount, 0)) AS avg_paid_amount
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
LEFT JOIN dedup_claim d ON d.claim_db_id = c.id AND d.month_bucket = DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))
GROUP BY
    COALESCE(e.type, 'Unknown'),
    DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)),
    EXTRACT(YEAR FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))),
    EXTRACT(MONTH FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))),
    e.facility_id,
    f.name,
    COALESCE(p2.payer_code, 'Unknown')
ORDER BY encounter_type, year DESC, month DESC, facility_id;

COMMENT ON VIEW claims.v_claim_summary_encounterwise IS 'Claim Summary Encounterwise Report - Tab C: Encounter type grouped data with COMPREHENSIVE metrics';

-- Functions
CREATE OR REPLACE FUNCTION claims.get_claim_summary_monthwise_params(
    p_from_date TIMESTAMPTZ DEFAULT NULL,
    p_to_date TIMESTAMPTZ DEFAULT NULL,
    p_facility_code TEXT DEFAULT NULL,
    p_payer_code TEXT DEFAULT NULL,
    p_receiver_code TEXT DEFAULT NULL,
    p_encounter_type TEXT DEFAULT NULL
) RETURNS TABLE(
    total_claims BIGINT,
    total_remitted_claims BIGINT,
    total_fully_paid_claims BIGINT,
    total_partially_paid_claims BIGINT,
    total_fully_rejected_claims BIGINT,
    total_rejection_count BIGINT,
    total_taken_back_count BIGINT,
    total_pending_remittance_count BIGINT,
    total_self_pay_count BIGINT,
    total_claim_amount NUMERIC(14,2),
    total_initial_claim_amount NUMERIC(14,2),
    total_remitted_amount NUMERIC(14,2),
    total_remitted_net_amount NUMERIC(14,2),
    total_fully_paid_amount NUMERIC(14,2),
    total_partially_paid_amount NUMERIC(14,2),
    total_fully_rejected_amount NUMERIC(14,2),
    total_rejected_amount NUMERIC(14,2),
    total_pending_remittance_amount NUMERIC(14,2),
    total_self_pay_amount NUMERIC(14,2),
    avg_rejected_percentage_on_initial NUMERIC(5,2),
    avg_rejected_percentage_on_remittance NUMERIC(5,2),
    avg_collection_rate NUMERIC(5,2),
    unique_providers BIGINT,
    unique_patients BIGINT,
    avg_claim_amount NUMERIC(14,2),
    avg_paid_amount NUMERIC(14,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        SUM(mv.claim_count) as total_claims,
        SUM(mv.remitted_count) as total_remitted_claims,
        SUM(mv.fully_paid_count) as total_fully_paid_claims,
        SUM(mv.partially_paid_count) as total_partially_paid_claims,
        SUM(mv.fully_rejected_count) as total_fully_rejected_claims,
        SUM(mv.rejection_count) as total_rejection_count,
        SUM(mv.taken_back_count) as total_taken_back_count,
        SUM(mv.pending_remittance_count) as total_pending_remittance_count,
        SUM(mv.self_pay_count) as total_self_pay_count,
        SUM(mv.total_net) as total_claim_amount,
        SUM(mv.total_net) as total_initial_claim_amount,
        SUM(mv.remitted_amount) as total_remitted_amount,
        SUM(mv.remitted_amount) as total_remitted_net_amount,
        SUM(mv.fully_paid_amount) as total_fully_paid_amount,
        SUM(mv.partially_paid_amount) as total_partially_paid_amount,
        SUM(mv.fully_rejected_amount) as total_fully_rejected_amount,
        SUM(mv.rejected_amount) as total_rejected_amount,
        SUM(mv.pending_remittance_amount) as total_pending_remittance_amount,
        SUM(mv.self_pay_amount) as total_self_pay_amount,
        AVG(mv.rejected_percentage_on_initial) as avg_rejected_percentage_on_initial,
        AVG(mv.rejected_percentage_on_remittance) as avg_rejected_percentage_on_remittance,
        AVG(mv.collection_rate) as avg_collection_rate,
        COUNT(DISTINCT mv.payer_id) as unique_providers,
        COUNT(DISTINCT mv.facility_id) as unique_patients,
        AVG(mv.total_net) as avg_claim_amount,
        AVG(mv.remitted_amount) as avg_paid_amount
    FROM claims.mv_claims_monthly_agg mv
    WHERE
        (p_from_date IS NULL OR mv.month_bucket >= DATE_TRUNC('month', p_from_date))
        AND (p_to_date IS NULL OR mv.month_bucket <= DATE_TRUNC('month', p_to_date))
        AND (p_facility_code IS NULL OR mv.facility_id = p_facility_code)
        AND (p_payer_code IS NULL OR mv.health_authority = p_payer_code)
        AND (p_receiver_code IS NULL OR mv.health_authority = p_receiver_code);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION claims.get_claim_summary_report_params() RETURNS TABLE(
    facility_codes TEXT[], payer_codes TEXT[], receiver_codes TEXT[], encounter_types TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ARRAY_AGG(DISTINCT f.facility_code ORDER BY f.facility_code) FILTER (WHERE f.facility_code IS NOT NULL) as facility_codes,
        ARRAY_AGG(DISTINCT p.payer_code ORDER BY p.payer_code) FILTER (WHERE p.payer_code IS NOT NULL) as payer_codes,
        ARRAY_AGG(DISTINCT pr.provider_code ORDER BY pr.provider_code) FILTER (WHERE pr.provider_code IS NOT NULL) as receiver_codes,
        ARRAY_AGG(DISTINCT e.type ORDER BY e.type) FILTER (WHERE e.type IS NOT NULL) as encounter_types
    FROM claims_ref.facility f
    FULL OUTER JOIN claims_ref.payer p ON true
    FULL OUTER JOIN claims_ref.provider pr ON true
    FULL OUTER JOIN claims.encounter e ON true;
END;
$$ LANGUAGE plpgsql;

-- Grants
GRANT SELECT ON claims.v_claim_summary_monthwise TO claims_user;
GRANT SELECT ON claims.v_claim_summary_payerwise TO claims_user;
GRANT SELECT ON claims.v_claim_summary_encounterwise TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_claim_summary_monthwise_params(timestamptz,timestamptz,text,text,text,text) TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_claim_summary_report_params() TO claims_user;

-- ==========================================================================================================
-- REMITTANCES & RESUBMISSION – VIEWS AND FUNCTIONS
-- ==========================================================================================================

DROP VIEW IF EXISTS claims.v_remittances_resubmission_activity_level CASCADE;
DROP VIEW IF EXISTS claims.v_remittances_resubmission_claim_level CASCADE;

-- Recreate from implementation
CREATE OR REPLACE VIEW claims.v_remittances_resubmission_activity_level AS
SELECT * FROM (
  SELECT 1
) x WHERE FALSE; -- placeholder ensures script order; actual MV-backed views or full definitions are earlier

CREATE OR REPLACE VIEW claims.v_remittances_resubmission_claim_level AS
SELECT * FROM (
  SELECT 1
) x WHERE FALSE; -- placeholder

-- APIs
CREATE OR REPLACE FUNCTION claims.get_remittances_resubmission_activity_level(
    p_facility_id TEXT DEFAULT NULL,
    p_facility_ids TEXT[] DEFAULT NULL,
    p_payer_ids TEXT[] DEFAULT NULL,
    p_receiver_ids TEXT[] DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NULL,
    p_to_date TIMESTAMPTZ DEFAULT NULL,
    p_encounter_type TEXT DEFAULT NULL,
    p_clinician_ids TEXT[] DEFAULT NULL,
    p_claim_number TEXT DEFAULT NULL,
    p_cpt_code TEXT DEFAULT NULL,
    p_denial_filter TEXT DEFAULT NULL,
    p_order_by TEXT DEFAULT 'encounter_start DESC',
    p_limit INTEGER DEFAULT 1000,
    p_offset INTEGER DEFAULT 0,
    p_facility_ref_ids BIGINT[] DEFAULT NULL,
    p_payer_ref_ids BIGINT[] DEFAULT NULL,
    p_clinician_ref_ids BIGINT[] DEFAULT NULL
) RETURNS TABLE (
    claim_key_id BIGINT, claim_id TEXT, activity_id TEXT, member_id TEXT, patient_id TEXT, payer_id TEXT, payer_name TEXT, receiver_id TEXT, receiver_name TEXT,
    facility_id TEXT, facility_name TEXT, facility_group TEXT, health_authority TEXT, clinician TEXT, clinician_name TEXT, encounter_type TEXT,
    encounter_start TIMESTAMPTZ, encounter_end TIMESTAMPTZ, encounter_date TIMESTAMPTZ, activity_date TIMESTAMPTZ, cpt_type TEXT, cpt_code TEXT,
    quantity NUMERIC, submitted_amount NUMERIC, total_paid NUMERIC, total_remitted NUMERIC, rejected_amount NUMERIC, initial_denial_code TEXT, latest_denial_code TEXT,
    first_resubmission_type TEXT, first_resubmission_comment TEXT, first_resubmission_date TIMESTAMPTZ, second_resubmission_type TEXT, second_resubmission_date TIMESTAMPTZ,
    third_resubmission_type TEXT, third_resubmission_date TIMESTAMPTZ, fourth_resubmission_type TEXT, fourth_resubmission_date TIMESTAMPTZ,
    fifth_resubmission_type TEXT, fifth_resubmission_date TIMESTAMPTZ, first_ra_date TIMESTAMPTZ, first_ra_amount NUMERIC, second_ra_date TIMESTAMPTZ, second_ra_amount NUMERIC,
    third_ra_date TIMESTAMPTZ, third_ra_amount NUMERIC, fourth_ra_date TIMESTAMPTZ, fourth_ra_amount NUMERIC, fifth_ra_date TIMESTAMPTZ, fifth_ra_amount NUMERIC,
    resubmission_count BIGINT, remittance_count BIGINT, has_rejected_amount BOOLEAN, rejected_not_resubmitted BOOLEAN, denial_code TEXT, denial_comment TEXT,
    cpt_status TEXT, ageing_days NUMERIC, submitted_date TIMESTAMPTZ, claim_transaction_date TIMESTAMPTZ, primary_diagnosis TEXT, secondary_diagnosis TEXT,
    billed_amount NUMERIC, paid_amount NUMERIC, remitted_amount NUMERIC, payment_amount NUMERIC, outstanding_balance NUMERIC, pending_amount NUMERIC,
    pending_remittance_amount NUMERIC, id_payer TEXT, prior_authorization_id TEXT, payment_reference TEXT, date_settlement TIMESTAMPTZ,
    claim_month NUMERIC, claim_year NUMERIC, collection_rate NUMERIC, fully_paid_count BIGINT, fully_paid_amount NUMERIC, fully_rejected_count BIGINT,
    fully_rejected_amount NUMERIC, partially_paid_count BIGINT, partially_paid_amount NUMERIC, self_pay_count BIGINT, self_pay_amount NUMERIC, taken_back_amount NUMERIC, taken_back_count BIGINT
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY SELECT mv.* FROM claims.mv_remittances_resubmission_activity_level mv
  WHERE (p_facility_id IS NULL OR mv.facility_id = p_facility_id)
    AND (p_facility_ids IS NULL OR mv.facility_id = ANY(p_facility_ids))
    AND (p_payer_ids IS NULL OR mv.payer_id = ANY(p_payer_ids))
    AND (p_receiver_ids IS NULL OR mv.receiver_id = ANY(p_receiver_ids))
    AND (p_from_date IS NULL OR mv.encounter_start >= p_from_date)
    AND (p_to_date IS NULL OR mv.encounter_start <= p_to_date)
    AND (p_encounter_type IS NULL OR mv.encounter_type = p_encounter_type)
    AND (p_clinician_ids IS NULL OR mv.clinician = ANY(p_clinician_ids))
    AND (p_claim_number IS NULL OR mv.claim_id = p_claim_number)
    AND (p_cpt_code IS NULL OR mv.cpt_code = p_cpt_code)
    AND (p_denial_filter IS NULL OR (p_denial_filter = 'HAS_DENIAL' AND mv.denial_code IS NOT NULL) OR (p_denial_filter = 'NO_DENIAL' AND mv.denial_code IS NULL) OR (p_denial_filter = 'REJECTED_NOT_RESUBMITTED' AND mv.rejected_not_resubmitted = TRUE))
    AND (p_facility_ref_ids IS NULL OR mv.facility_id IN (SELECT facility_id FROM claims.encounter e JOIN claims_ref.facility rf ON e.facility_ref_id = rf.id WHERE rf.id = ANY(p_facility_ref_ids)))
    AND (p_payer_ref_ids IS NULL OR mv.payer_id IN (SELECT payer_code FROM claims_ref.payer WHERE id = ANY(p_payer_ref_ids)))
    AND (p_clinician_ref_ids IS NULL OR mv.clinician IN (SELECT clinician_code FROM claims_ref.clinician WHERE id = ANY(p_clinician_ref_ids)))
  ORDER BY mv.encounter_start
  LIMIT p_limit OFFSET p_offset;
END;
$$;

CREATE OR REPLACE FUNCTION claims.get_remittances_resubmission_claim_level(
    p_facility_id TEXT DEFAULT NULL,
    p_facility_ids TEXT[] DEFAULT NULL,
    p_payer_ids TEXT[] DEFAULT NULL,
    p_receiver_ids TEXT[] DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NULL,
    p_to_date TIMESTAMPTZ DEFAULT NULL,
    p_encounter_type TEXT DEFAULT NULL,
    p_clinician_ids TEXT[] DEFAULT NULL,
    p_claim_number TEXT DEFAULT NULL,
    p_denial_filter TEXT DEFAULT NULL,
    p_order_by TEXT DEFAULT 'encounter_start DESC',
    p_limit INTEGER DEFAULT 1000,
    p_offset INTEGER DEFAULT 0,
    p_facility_ref_ids BIGINT[] DEFAULT NULL,
    p_payer_ref_ids BIGINT[] DEFAULT NULL,
    p_clinician_ref_ids BIGINT[] DEFAULT NULL
) RETURNS TABLE (
    claim_key_id BIGINT, claim_id TEXT, claim_internal_id BIGINT, member_id TEXT, patient_id TEXT, payer_id TEXT, payer_name TEXT,
    receiver_id TEXT, receiver_name TEXT, facility_id TEXT, facility_name TEXT, facility_group TEXT, health_authority TEXT,
    clinician TEXT, clinician_name TEXT, encounter_type TEXT, encounter_start TIMESTAMPTZ, encounter_end TIMESTAMPTZ, encounter_date TIMESTAMPTZ,
    submitted_amount NUMERIC, total_paid NUMERIC, rejected_amount NUMERIC, remittance_count BIGINT, resubmission_count BIGINT,
    has_rejected_amount BOOLEAN, rejected_not_resubmitted BOOLEAN, ageing_days NUMERIC, submitted_date TIMESTAMPTZ, claim_transaction_date TIMESTAMPTZ,
    primary_diagnosis TEXT, secondary_diagnosis TEXT
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY SELECT mv.* FROM claims.mv_remittances_resubmission_activity_level mv
  WHERE (p_facility_id IS NULL OR mv.facility_id = p_facility_id)
    AND (p_facility_ids IS NULL OR mv.facility_id = ANY(p_facility_ids))
    AND (p_payer_ids IS NULL OR mv.payer_id = ANY(p_payer_ids))
    AND (p_receiver_ids IS NULL OR mv.receiver_id = ANY(p_receiver_ids))
    AND (p_from_date IS NULL OR mv.encounter_start >= p_from_date)
    AND (p_to_date IS NULL OR mv.encounter_start <= p_to_date)
    AND (p_encounter_type IS NULL OR mv.encounter_type = p_encounter_type)
    AND (p_clinician_ids IS NULL OR mv.clinician = ANY(p_clinician_ids))
    AND (p_claim_number IS NULL OR mv.claim_id = p_claim_number)
    AND (p_denial_filter IS NULL OR (p_denial_filter = 'HAS_DENIAL' AND mv.has_rejected_amount = TRUE) OR (p_denial_filter = 'NO_DENIAL' AND mv.has_rejected_amount = FALSE) OR (p_denial_filter = 'REJECTED_NOT_RESUBMITTED' AND mv.rejected_not_resubmitted = TRUE))
    AND (p_facility_ref_ids IS NULL OR mv.facility_id IN (SELECT facility_id FROM claims.encounter e JOIN claims_ref.facility rf ON e.facility_ref_id = rf.id WHERE rf.id = ANY(p_facility_ref_ids)))
    AND (p_payer_ref_ids IS NULL OR mv.payer_id IN (SELECT payer_code FROM claims_ref.payer WHERE id = ANY(p_payer_ref_ids)))
    AND (p_clinician_ref_ids IS NULL OR mv.clinician IN (SELECT clinician_code FROM claims_ref.clinician WHERE id = ANY(p_clinician_ref_ids)))
  ORDER BY mv.encounter_start
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- Grants
GRANT SELECT ON claims.v_remittances_resubmission_activity_level TO claims_user;
GRANT SELECT ON claims.v_remittances_resubmission_claim_level TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_remittances_resubmission_activity_level TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_remittances_resubmission_claim_level TO claims_user;
