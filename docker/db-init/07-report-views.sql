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
  bab.facility_group_id,
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
  bab.last_submission_file AS submission_reference_file,
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
  bab.facility_group_id,
  COALESCE(bab.health_authority_submission, bab.health_authority_remittance) AS health_authority,
  bab.facility_id,
  bab.facility_name,
  bab.claim_id AS claim_number,
  bab.encounter_start AS encounter_start_date,
  bab.encounter_end AS encounter_end_date,
  bab.encounter_start_year,
  bab.encounter_start_month,
  bab.receiver_id,
  bab.payer_name AS receiver_name,
  bab.payer_id,
  bab.payer_name,
  bab.payer_id AS id_payer,
  bab.patient_id,
  bab.member_id,
  bab.emirates_id_number,
  COALESCE(bab.initial_net_amount, 0) AS billed_amount,
  COALESCE(bab.total_payment_amount, 0) AS amount_received,
  COALESCE(bab.total_denied_amount, 0) AS denied_amount,
  COALESCE(bab.pending_amount, 0) AS outstanding_balance,
  bab.claim_submission_date AS submission_date,
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
