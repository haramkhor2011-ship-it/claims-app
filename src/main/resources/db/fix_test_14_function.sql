-- ==========================================================================================================
-- FIX FOR TEST 14 - API FUNCTION COLUMN REFERENCE ERROR
-- ==========================================================================================================
-- 
-- Date: 2025-09-24
-- Purpose: Fix the column reference error in get_rejected_claims_tab_a function
-- 
-- Test 14 is failing because the function references 'payer_id' but the view has 'id_payer'
--
-- ==========================================================================================================

-- Fix the Tab A API function with correct column references
CREATE OR REPLACE FUNCTION claims.get_rejected_claims_tab_a(
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
  p_order_direction TEXT
) RETURNS TABLE(
  facility_group_id TEXT,
  health_authority TEXT,
  facility_id TEXT,
  facility_name TEXT,
  claim_year NUMERIC,
  claim_month_name TEXT,
  receiver_id TEXT,
  receiver_name TEXT,
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
  claim_number TEXT,
  id_payer TEXT,
  patient_id TEXT,
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
  submission_file_id TEXT,
  remittance_file_id TEXT
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT
    rcta.facility_group_id,
    rcta.health_authority,
    rcta.facility_id,
    rcta.facility_name,
    rcta.claim_year,
    rcta.claim_month_name,
    rcta.receiver_id,
    rcta.receiver_name,
    rcta.total_claim,
    rcta.claim_amt,
    rcta.remitted_claim,
    rcta.remitted_amt,
    rcta.rejected_claim,
    rcta.rejected_amt,
    rcta.pending_remittance,
    rcta.pending_remittance_amt,
    rcta.rejected_percentage_remittance,
    rcta.rejected_percentage_submission,
    rcta.claim_number,
    rcta.id_payer,
    rcta.patient_id,
    rcta.member_id,
    rcta.emirates_id_number,
    rcta.claim_amt_detail,
    rcta.remitted_amt_detail,
    rcta.rejected_amt_detail,
    rcta.rejection_type,
    rcta.activity_start_date,
    rcta.activity_code,
    rcta.activity_denial_code,
    rcta.denial_type,
    rcta.clinician_name,
    rcta.ageing_days,
    rcta.current_status,
    rcta.resubmission_type,
    rcta.submission_file_id,
    rcta.remittance_file_id
  FROM claims.v_rejected_claims_tab_a rcta
  WHERE 
    (p_facility_codes IS NULL OR rcta.facility_id = ANY(p_facility_codes))
    AND (p_payer_codes IS NULL OR rcta.id_payer = ANY(p_payer_codes))  -- FIXED: was payer_id
    AND (p_receiver_ids IS NULL OR rcta.receiver_id = ANY(p_receiver_ids))
    AND (p_date_from IS NULL OR rcta.activity_start_date >= p_date_from)
    AND (p_date_to IS NULL OR rcta.activity_start_date <= p_date_to)
    AND (p_year IS NULL OR rcta.claim_year = p_year)
    AND (p_month IS NULL OR EXTRACT(MONTH FROM rcta.activity_start_date) = p_month)
  ORDER BY
    CASE WHEN p_order_direction = 'DESC' THEN
      CASE p_order_by
        WHEN 'facility_name' THEN rcta.facility_name
        WHEN 'claim_year' THEN rcta.claim_year::TEXT
        WHEN 'rejected_amt' THEN rcta.rejected_amt::TEXT
        WHEN 'rejected_percentage_remittance' THEN rcta.rejected_percentage_remittance::TEXT
        ELSE rcta.facility_name
      END
    END DESC,
    CASE WHEN p_order_direction = 'ASC' OR p_order_direction IS NULL THEN
      CASE p_order_by
        WHEN 'facility_name' THEN rcta.facility_name
        WHEN 'claim_year' THEN rcta.claim_year::TEXT
        WHEN 'rejected_amt' THEN rcta.rejected_amt::TEXT
        WHEN 'rejected_percentage_remittance' THEN rcta.rejected_percentage_remittance::TEXT
        ELSE rcta.facility_name
      END
    END ASC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION claims.get_rejected_claims_tab_a IS 'Fixed API function for Rejected Claims Tab A - corrected column reference from payer_id to id_payer';

-- Test the fix
SELECT 'Test 14 Fix Applied' as status;
SELECT COUNT(*) as function_test_result FROM claims.get_rejected_claims_tab_a(
    'test_user',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    10,
    0,
    'facility_name',
    'ASC'
);
