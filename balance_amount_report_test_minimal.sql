-- ==========================================================================================================
-- BALANCE AMOUNT REPORT - MINIMAL TEST VERSION
-- ==========================================================================================================
-- 
-- Purpose: Test the basic structure with actual table columns
-- This version removes problematic parts and tests core functionality
-- 
-- ==========================================================================================================

-- Test 1: Create the status mapping function
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

-- Test 2: Create a minimal base view to test table joins
CREATE OR REPLACE VIEW claims.v_balance_amount_test AS
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
  c.created_at AS claim_submission_date,
  c.comments AS claim_comments,
  
  -- Encounter details
  e.facility_id,
  e.type AS encounter_type,
  e.patient_id,
  e.start AS encounter_start,
  e.end AS encounter_end,
  EXTRACT(YEAR FROM e.start) AS encounter_start_year,
  EXTRACT(MONTH FROM e.start) AS encounter_start_month,
  
  -- Provider/Facility Group mapping
  COALESCE(e.facility_id, c.provider_id) AS facility_group_id,
  
  -- Reference data with fallbacks
  COALESCE(c.provider_id, 'UNKNOWN') AS provider_name,
  c.provider_id AS provider_code,
  COALESCE(e.facility_id, 'UNKNOWN') AS facility_name,
  e.facility_id AS facility_code,
  COALESCE(c.payer_id, 'UNKNOWN') AS payer_name,
  c.payer_id AS payer_code,
  
  -- Health Authority mapping
  if_sub.sender_id AS health_authority_submission,
  if_rem.receiver_id AS health_authority_remittance,
  
  -- Submission file details
  if_sub.file_id AS last_submission_file,
  if_sub.receiver_id,
  
  -- Calculated fields
  CASE 
    WHEN c.net IS NULL OR c.net = 0 THEN 0
    ELSE c.net
  END AS pending_amount,
  
  -- Aging calculation
  EXTRACT(DAYS FROM (CURRENT_DATE - e.start)) AS aging_days,
  CASE 
    WHEN EXTRACT(DAYS FROM (CURRENT_DATE - e.start)) <= 30 THEN '0-30'
    WHEN EXTRACT(DAYS FROM (CURRENT_DATE - e.start)) <= 60 THEN '31-60'
    WHEN EXTRACT(DAYS FROM (CURRENT_DATE - e.start)) <= 90 THEN '61-90'
    ELSE '90+'
  END AS aging_bucket

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims.submission s ON s.id = c.submission_id
LEFT JOIN claims.ingestion_file if_sub ON if_sub.id = s.ingestion_file_id
-- Remittance joins (simplified)
LEFT JOIN claims.remittance_claim rc_join ON rc_join.claim_key_id = ck.id
LEFT JOIN claims.remittance rem ON rem.id = rc_join.remittance_id
LEFT JOIN claims.ingestion_file if_rem ON if_rem.id = rem.ingestion_file_id;

-- Test 3: Create a simple tab view
CREATE OR REPLACE VIEW claims.v_balance_amount_tab_a_test AS
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
  0 AS amount_received,  -- Simplified for testing
  0 AS write_off_amount,  -- Simplified for testing
  0 AS denied_amount,  -- Simplified for testing
  COALESCE(bab.pending_amount, 0) AS outstanding_balance,
  bab.claim_submission_date AS submission_date,
  bab.last_submission_file AS submission_reference_file,
  
  'PENDING' AS claim_status,
  0 AS remittance_count,
  0 AS resubmission_count,
  bab.aging_days,
  bab.aging_bucket,
  'UNKNOWN' AS current_claim_status,
  NULL AS last_status_date

FROM claims.v_balance_amount_test bab;

-- Grant permissions
GRANT SELECT ON claims.v_balance_amount_test TO claims_user;
GRANT SELECT ON claims.v_balance_amount_tab_a_test TO claims_user;
GRANT EXECUTE ON FUNCTION claims.map_status_to_text TO claims_user;

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'Balance Amount Report - MINIMAL TEST VERSION created successfully!';
  RAISE NOTICE 'This version tests basic table joins and structure';
  RAISE NOTICE 'Run: SELECT COUNT(*) FROM claims.v_balance_amount_tab_a_test;';
  RAISE NOTICE 'Ready for testing!';
END$$;
