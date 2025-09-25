-- ==========================================================================================================
-- REJECTED CLAIMS REPORT - COMPLETE IMPLEMENTATION
-- ==========================================================================================================
-- 
-- Date: 2025-09-24
-- Purpose: Complete implementation for Rejected Claims Report
-- 
-- BUSINESS OVERVIEW:
-- This report provides three complementary views for tracking rejected claims:
-- 1. Tab A: Rejected Claims (with expandable sub-data) - Summary and detailed view
-- 2. Tab B: Receiver and Payer wise - Analysis by receiver and payer combinations
-- 3. Tab C: Claim wise - Individual claim details with rejection information
--
-- DATA SOURCES:
-- - Primary: claims.claim, claims.encounter, claims.claim_key
-- - Remittance: claims.remittance_claim, claims.remittance_activity
-- - Status: claims.claim_status_timeline, claims.claim_event
-- - Reference: claims_ref.provider, claims_ref.facility, claims_ref.payer, claims_ref.clinician
--
-- FIELD MAPPINGS (Based on XML mapping and report requirements):
-- 1. FacilityGroup → claims.encounter.facility_id (preferred) or claims.claim.provider_id
-- 2. HealthAuthority → claims.ingestion_file.sender_id (submission) / receiver_id (remittance)
-- 3. FacilityID → claims.encounter.facility_id
-- 4. Facility_Name → claims_ref.facility.name (via facility_code lookup)
-- 5. Receiver_Name → claims_ref.payer.name (via payer_code = ingestion_file.receiver_id)
-- 6. Payer_Name → claims_ref.payer.name (via payer_code = claim.payer_id)
-- 7. Clinician_Name → claims_ref.clinician.name (via clinician_code = activity.clinician)
-- 8. RejectionType → Derived from payment_amount vs net comparison
-- 9. DenialCode → claims.remittance_activity.denial_code
-- 10. DenialType → claims_ref.denial_code.description (via denial_code lookup)
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: ENHANCED BASE VIEW
-- ==========================================================================================================
-- This is the foundation view that provides all necessary data for the three report tabs.
-- It includes:
-- - Claim details (amounts, dates, identifiers)
-- - Encounter information (facility, dates, patient)
-- - Remittance summary (payments, denials, dates)
-- - Rejection analysis (denial codes, rejection types, amounts)
-- - Reference data (facility names, payer names, clinician names)
-- - Calculated fields (rejection percentages, aging, status)
-- ==========================================================================================================

-- Enhanced base rejected claims view with comprehensive field mappings
CREATE OR REPLACE VIEW claims.v_rejected_claims_base AS
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
  
  -- Encounter details
  e.facility_id,
  e.type AS encounter_type,
  e.patient_id,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  EXTRACT(YEAR FROM e.start_at) AS encounter_start_year,
  EXTRACT(MONTH FROM e.start_at) AS encounter_start_month,
  TO_CHAR(e.start_at, 'Month') AS encounter_start_month_name,
  
  -- Facility Group mapping (per JSON mapping)
  COALESCE(e.facility_id, c.provider_id) AS facility_group_id,
  
  -- Reference data with fallbacks
  COALESCE(f.name, e.facility_id, 'Unknown Facility') AS facility_name,
  COALESCE(p.name, c.payer_id, 'Unknown Payer') AS payer_name,
  COALESCE(pr.name, c.provider_id, 'Unknown Provider') AS provider_name,
  
  -- Health Authority mapping (per JSON mapping)
  if_sub.sender_id AS health_authority_submission,
  if_rem.receiver_id AS health_authority_remittance,
  
  -- Receiver information (per JSON mapping)
  if_sub.receiver_id AS receiver_id,
  COALESCE(p_receiver.name, if_sub.receiver_id, 'Unknown Receiver') AS receiver_name,
  
  -- Remittance summary
  rc.id AS remittance_claim_id,
  rc.id_payer AS remittance_id_payer,
  rc.payment_reference,
  rc.date_settlement,
  rc.denial_code AS claim_denial_code,
  
  -- Activity-level remittance data
  ra.activity_id,
  ra.start_at AS activity_start_date,
  ra.type AS activity_type,
  ra.code AS activity_code,
  ra.quantity,
  ra.net AS activity_net_amount,
  ra.payment_amount AS activity_payment_amount,
  ra.denial_code AS activity_denial_code,
  ra.clinician AS activity_clinician,
  
  -- Clinician name lookup
  COALESCE(cl.name, ra.clinician, 'Unknown Clinician') AS clinician_name,
  
  -- Denial code description lookup
  COALESCE(dc.description, ra.denial_code, 'No Denial Code') AS denial_type,
  
  -- Calculated rejection fields
  CASE 
    WHEN ra.payment_amount = 0 THEN 'Fully Rejected'
    WHEN ra.payment_amount < ra.net THEN 'Partially Rejected'
    WHEN ra.payment_amount = ra.net THEN 'Fully Paid'
    ELSE 'Unknown Status'
  END AS rejection_type,
  
  -- Rejection amounts
  CASE 
    WHEN ra.payment_amount = 0 THEN ra.net
    WHEN ra.payment_amount < ra.net THEN ra.net - ra.payment_amount
    ELSE 0
  END AS rejected_amount,
  
  -- Aging calculation
  CURRENT_DATE - DATE(COALESCE(rc.date_settlement, e.start_at)) AS ageing_days,
  
  -- Status timeline
  cst.status AS current_status,
  cst.status_time AS status_time,
  
  -- Event tracking
  ce.event_time AS last_event_time,
  ce.type AS last_event_type,
  
  -- Resubmission tracking
  cr.resubmission_type,
  cr.comment AS resubmission_comment,
  
  -- File information
  if_sub.file_id AS submission_file_id,
  if_rem.file_id AS remittance_file_id,
  if_sub.transaction_date AS submission_transaction_date,
  if_rem.transaction_date AS remittance_transaction_date

FROM claims.claim_key ck
INNER JOIN claims.claim c ON ck.id = c.claim_key_id
INNER JOIN claims.encounter e ON c.id = e.claim_id
INNER JOIN claims.submission s ON c.submission_id = s.id
INNER JOIN claims.ingestion_file if_sub ON s.ingestion_file_id = if_sub.id

-- Remittance data (LEFT JOIN to include claims without remittance)
LEFT JOIN claims.remittance_claim rc ON ck.id = rc.claim_key_id
LEFT JOIN claims.remittance r ON rc.remittance_id = r.id
LEFT JOIN claims.ingestion_file if_rem ON r.ingestion_file_id = if_rem.id
LEFT JOIN claims.remittance_activity ra ON rc.id = ra.remittance_claim_id

-- Reference data lookups
LEFT JOIN claims_ref.facility f ON e.facility_id = f.facility_code
LEFT JOIN claims_ref.payer p ON c.payer_id = p.payer_code
LEFT JOIN claims_ref.provider pr ON c.provider_id = pr.provider_code
LEFT JOIN claims_ref.payer p_receiver ON if_sub.receiver_id = p_receiver.payer_code
LEFT JOIN claims_ref.clinician cl ON ra.clinician = cl.clinician_code
LEFT JOIN claims_ref.denial_code dc ON ra.denial_code = dc.code

-- Status and event tracking
LEFT JOIN claims.claim_status_timeline cst ON ck.id = cst.claim_key_id
LEFT JOIN claims.claim_event ce ON ck.id = ce.claim_key_id
LEFT JOIN claims.claim_resubmission cr ON ce.id = cr.claim_event_id

-- Only include claims that have some form of rejection
WHERE (
  -- Claims with denial codes
  ra.denial_code IS NOT NULL
  OR 
  -- Claims with partial or no payment
  (ra.payment_amount IS NOT NULL AND ra.payment_amount < ra.net)
  OR
  -- Claims with zero payment
  (ra.payment_amount IS NOT NULL AND ra.payment_amount = 0)
);

COMMENT ON VIEW claims.v_rejected_claims_base IS 'Base view for rejected claims report with comprehensive rejection analysis';

-- ==========================================================================================================
-- SECTION 2: AGGREGATED SUMMARY VIEW
-- ==========================================================================================================
-- This view provides aggregated data for summary-level reporting
-- ==========================================================================================================

CREATE OR REPLACE VIEW claims.v_rejected_claims_summary AS
SELECT 
  rcb.facility_group_id,
  COALESCE(rcb.health_authority_submission, rcb.health_authority_remittance) AS health_authority,
  rcb.facility_id,
  rcb.facility_name,
  EXTRACT(YEAR FROM rcb.encounter_start) AS claim_year,
  rcb.encounter_start_month_name AS claim_month_name,
  rcb.receiver_id,
  rcb.receiver_name,
  rcb.payer_id,
  rcb.payer_name,
  
  -- Aggregated counts and amounts
  COUNT(DISTINCT rcb.claim_key_id) AS total_claim_count,
  SUM(rcb.initial_net_amount) AS total_claim_amount,
  
  COUNT(DISTINCT CASE WHEN rcb.activity_payment_amount > 0 THEN rcb.claim_key_id END) AS remitted_claim_count,
  SUM(CASE WHEN rcb.activity_payment_amount > 0 THEN rcb.activity_payment_amount ELSE 0 END) AS total_remitted_amount,
  
  COUNT(DISTINCT CASE WHEN rcb.rejected_amount > 0 THEN rcb.claim_key_id END) AS rejected_claim_count,
  SUM(rcb.rejected_amount) AS total_rejected_amount,
  
  COUNT(DISTINCT CASE WHEN rcb.rejected_amount > 0 AND rcb.activity_payment_amount = 0 THEN rcb.claim_key_id END) AS pending_remittance_count,
  SUM(CASE WHEN rcb.rejected_amount > 0 AND rcb.activity_payment_amount = 0 THEN rcb.rejected_amount ELSE 0 END) AS pending_remittance_amount,
  
  -- Rejection percentages
  CASE 
    WHEN COUNT(DISTINCT CASE WHEN rcb.activity_payment_amount > 0 THEN rcb.claim_key_id END) > 0 
    THEN ROUND(
      (COUNT(DISTINCT CASE WHEN rcb.rejected_amount > 0 THEN rcb.claim_key_id END)::NUMERIC / 
       COUNT(DISTINCT CASE WHEN rcb.activity_payment_amount > 0 THEN rcb.claim_key_id END)) * 100, 2
    )
    ELSE 0 
  END AS rejected_percentage_based_on_remittance,
  
  CASE 
    WHEN COUNT(DISTINCT rcb.claim_key_id) > 0 
    THEN ROUND(
      (COUNT(DISTINCT CASE WHEN rcb.rejected_amount > 0 THEN rcb.claim_key_id END)::NUMERIC / 
       COUNT(DISTINCT rcb.claim_key_id)) * 100, 2
    )
    ELSE 0 
  END AS rejected_percentage_based_on_submission

FROM claims.v_rejected_claims_base rcb
GROUP BY 
  rcb.facility_group_id,
  COALESCE(rcb.health_authority_submission, rcb.health_authority_remittance),
  rcb.facility_id,
  rcb.facility_name,
  EXTRACT(YEAR FROM rcb.encounter_start),
  rcb.encounter_start_month_name,
  rcb.receiver_id,
  rcb.receiver_name,
  rcb.payer_id,
  rcb.payer_name;

COMMENT ON VIEW claims.v_rejected_claims_summary IS 'Aggregated summary view for rejected claims report';

-- ==========================================================================================================
-- SECTION 3: TAB VIEWS WITH CORRECTED MAPPINGS
-- ==========================================================================================================
-- 
-- BUSINESS OVERVIEW:
-- The report provides three complementary views for different business needs:
-- 1. Tab A: Rejected Claims with expandable sub-data (summary and detailed view)
-- 2. Tab B: Receiver and Payer wise analysis
-- 3. Tab C: Claim wise detailed view
--
-- Each tab is designed for specific business scenarios and user workflows.
-- ==========================================================================================================

-- ==========================================================================================================
-- TAB A: REJECTED CLAIMS (with expandable sub-data)
-- ==========================================================================================================
-- Purpose: Summary-level view with expandable claim details
-- Use Case: General reporting, facility analysis, drill-down capabilities
-- Key Features: Summary data with expandable sub-data for detailed analysis
-- ==========================================================================================================

CREATE OR REPLACE VIEW claims.v_rejected_claims_tab_a AS
SELECT 
  rcs.facility_group_id,
  rcs.health_authority,
  rcs.facility_id,
  rcs.facility_name,
  rcs.claim_year,
  rcs.claim_month_name,
  rcs.receiver_id,
  rcs.receiver_name,
  
  -- Summary columns (parent grid)
  rcs.total_claim_count AS total_claim,
  rcs.total_claim_amount AS claim_amt,
  rcs.remitted_claim_count AS remitted_claim,
  rcs.total_remitted_amount AS remitted_amt,
  rcs.rejected_claim_count AS rejected_claim,
  rcs.total_rejected_amount AS rejected_amt,
  rcs.pending_remittance_count AS pending_remittance,
  rcs.pending_remittance_amount AS pending_remittance_amt,
  rcs.rejected_percentage_based_on_remittance AS rejected_percentage_remittance,
  rcs.rejected_percentage_based_on_submission AS rejected_percentage_submission,
  
  -- Sub-data columns (expandable details)
  rcb.claim_id AS claim_number,
  rcb.remittance_id_payer AS id_payer,
  rcb.patient_id,
  rcb.member_id,
  rcb.emirates_id_number,
  rcb.initial_net_amount AS claim_amt_detail,
  rcb.activity_payment_amount AS remitted_amt_detail,
  rcb.rejected_amount AS rejected_amt_detail,
  rcb.rejection_type,
  
  -- Additional detail fields
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

FROM claims.v_rejected_claims_summary rcs
LEFT JOIN claims.v_rejected_claims_base rcb ON (
  rcs.facility_group_id = rcb.facility_group_id
  AND rcs.health_authority = COALESCE(rcb.health_authority_submission, rcb.health_authority_remittance)
  AND rcs.facility_id = rcb.facility_id
  AND rcs.receiver_id = rcb.receiver_id
  AND rcs.payer_id = rcb.payer_id
  AND rcs.claim_year = EXTRACT(YEAR FROM rcb.encounter_start)
  AND rcs.claim_month_name = rcb.encounter_start_month_name
);

COMMENT ON VIEW claims.v_rejected_claims_tab_a IS 'Tab A: Rejected Claims with expandable sub-data';

-- ==========================================================================================================
-- TAB B: RECEIVER AND PAYER WISE
-- ==========================================================================================================
-- Purpose: Analysis by receiver and payer combinations
-- Use Case: Payer performance analysis, receiver efficiency analysis
-- Key Features: Aggregated data by receiver-payer combinations
-- ==========================================================================================================

CREATE OR REPLACE VIEW claims.v_rejected_claims_tab_b AS
SELECT 
  rcb.receiver_name,
  rcb.payer_id,
  rcb.payer_name,
  
  -- Aggregated counts and amounts
  COUNT(DISTINCT rcb.claim_key_id) AS total_claim,
  SUM(rcb.initial_net_amount) AS claim_amt,
  
  COUNT(DISTINCT CASE WHEN rcb.activity_payment_amount > 0 THEN rcb.claim_key_id END) AS remitted_claim,
  SUM(CASE WHEN rcb.activity_payment_amount > 0 THEN rcb.activity_payment_amount ELSE 0 END) AS remitted_amt,
  
  COUNT(DISTINCT CASE WHEN rcb.rejected_amount > 0 THEN rcb.claim_key_id END) AS rejected_claim,
  SUM(rcb.rejected_amount) AS rejected_amt,
  
  COUNT(DISTINCT CASE WHEN rcb.rejected_amount > 0 AND rcb.activity_payment_amount = 0 THEN rcb.claim_key_id END) AS pending_remittance,
  SUM(CASE WHEN rcb.rejected_amount > 0 AND rcb.activity_payment_amount = 0 THEN rcb.rejected_amount ELSE 0 END) AS pending_remittance_amt,
  
  -- Rejection percentages
  CASE 
    WHEN COUNT(DISTINCT CASE WHEN rcb.activity_payment_amount > 0 THEN rcb.claim_key_id END) > 0 
    THEN ROUND(
      (COUNT(DISTINCT CASE WHEN rcb.rejected_amount > 0 THEN rcb.claim_key_id END)::NUMERIC / 
       COUNT(DISTINCT CASE WHEN rcb.activity_payment_amount > 0 THEN rcb.claim_key_id END)) * 100, 2
    )
    ELSE 0 
  END AS rejected_percentage_remittance,
  
  CASE 
    WHEN COUNT(DISTINCT rcb.claim_key_id) > 0 
    THEN ROUND(
      (COUNT(DISTINCT CASE WHEN rcb.rejected_amount > 0 THEN rcb.claim_key_id END)::NUMERIC / 
       COUNT(DISTINCT rcb.claim_key_id)) * 100, 2
    )
    ELSE 0 
  END AS rejected_percentage_submission,
  
  -- Additional metrics
  CASE 
    WHEN COUNT(DISTINCT rcb.claim_key_id) > 0 
    THEN ROUND(SUM(rcb.initial_net_amount) / COUNT(DISTINCT rcb.claim_key_id), 2)
    ELSE 0 
  END AS average_claim_value,
  
  CASE 
    WHEN SUM(rcb.initial_net_amount) > 0 
    THEN ROUND((SUM(CASE WHEN rcb.activity_payment_amount > 0 THEN rcb.activity_payment_amount ELSE 0 END) / SUM(rcb.initial_net_amount)) * 100, 2)
    ELSE 0 
  END AS collection_rate

FROM claims.v_rejected_claims_base rcb
GROUP BY 
  rcb.receiver_name,
  rcb.payer_id,
  rcb.payer_name;

COMMENT ON VIEW claims.v_rejected_claims_tab_b IS 'Tab B: Receiver and Payer wise analysis';

-- ==========================================================================================================
-- TAB C: CLAIM WISE
-- ==========================================================================================================
-- Purpose: Individual claim details with rejection information
-- Use Case: Detailed claim analysis, denial reason analysis, audit trails
-- Key Features: Complete claim information with rejection details
-- ==========================================================================================================

CREATE OR REPLACE VIEW claims.v_rejected_claims_tab_c AS
SELECT 
  rcb.claim_key_id,
  rcb.claim_id AS claim_number,
  rcb.payer_name,
  rcb.remittance_id_payer AS id_payer,
  rcb.patient_id,
  rcb.member_id,
  rcb.emirates_id_number,
  rcb.initial_net_amount AS claim_amt,
  rcb.activity_payment_amount AS remitted_amt,
  rcb.rejected_amount AS rejected_amt,
  rcb.rejection_type,
  
  -- Additional claim details
  rcb.activity_start_date AS service_date,
  rcb.activity_code,
  rcb.activity_denial_code AS denial_code,
  rcb.denial_type,
  rcb.clinician_name,
  rcb.facility_name,
  rcb.receiver_name,
  rcb.ageing_days,
  rcb.current_status,
  rcb.resubmission_type,
  rcb.resubmission_comment,
  rcb.submission_file_id,
  rcb.remittance_file_id,
  rcb.submission_transaction_date,
  rcb.remittance_transaction_date,
  rcb.claim_comments

FROM claims.v_rejected_claims_base rcb;

COMMENT ON VIEW claims.v_rejected_claims_tab_c IS 'Tab C: Claim wise detailed view';

-- ==========================================================================================================
-- SECTION 4: API FUNCTIONS
-- ==========================================================================================================
-- Production-ready API functions for application integration
-- ==========================================================================================================

-- ==========================================================================================================
-- API FUNCTION: Get Rejected Claims Tab A
-- ==========================================================================================================

CREATE OR REPLACE FUNCTION claims.get_rejected_claims_tab_a(
  p_user_id TEXT,
  p_facility_codes TEXT[] DEFAULT NULL,
  p_payer_codes TEXT[] DEFAULT NULL,
  p_receiver_ids TEXT[] DEFAULT NULL,
  p_date_from TIMESTAMPTZ DEFAULT NULL,
  p_date_to TIMESTAMPTZ DEFAULT NULL,
  p_year INTEGER DEFAULT NULL,
  p_month INTEGER DEFAULT NULL,
  p_limit INTEGER DEFAULT 100,
  p_offset INTEGER DEFAULT 0,
  p_order_by TEXT DEFAULT 'facility_name',
  p_order_direction TEXT DEFAULT 'ASC'
)
RETURNS TABLE (
  facility_group_id TEXT,
  health_authority TEXT,
  facility_id TEXT,
  facility_name TEXT,
  claim_year INTEGER,
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
  current_status SMALLINT,
  resubmission_type TEXT,
  submission_file_id TEXT,
  remittance_file_id TEXT
) 
LANGUAGE plpgsql
AS $$
BEGIN
  -- Set default date range if not provided
  IF p_date_from IS NULL THEN
    p_date_from := CURRENT_DATE - INTERVAL '3 years';
  END IF;
  
  IF p_date_to IS NULL THEN
    p_date_to := CURRENT_DATE;
  END IF;

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
    AND (p_payer_codes IS NULL OR rcta.id_payer = ANY(p_payer_codes))
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

COMMENT ON FUNCTION claims.get_rejected_claims_tab_a IS 'API function for Rejected Claims Tab A with comprehensive filtering and pagination';

-- ==========================================================================================================
-- API FUNCTION: Get Rejected Claims Tab B
-- ==========================================================================================================

CREATE OR REPLACE FUNCTION claims.get_rejected_claims_tab_b(
  p_user_id TEXT,
  p_facility_codes TEXT[] DEFAULT NULL,
  p_payer_codes TEXT[] DEFAULT NULL,
  p_receiver_ids TEXT[] DEFAULT NULL,
  p_date_from TIMESTAMPTZ DEFAULT NULL,
  p_date_to TIMESTAMPTZ DEFAULT NULL,
  p_year INTEGER DEFAULT NULL,
  p_month INTEGER DEFAULT NULL,
  p_limit INTEGER DEFAULT 100,
  p_offset INTEGER DEFAULT 0,
  p_order_by TEXT DEFAULT 'receiver_name',
  p_order_direction TEXT DEFAULT 'ASC'
)
RETURNS TABLE (
  receiver_name TEXT,
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
) 
LANGUAGE plpgsql
AS $$
BEGIN
  -- Set default date range if not provided
  IF p_date_from IS NULL THEN
    p_date_from := CURRENT_DATE - INTERVAL '3 years';
  END IF;
  
  IF p_date_to IS NULL THEN
    p_date_to := CURRENT_DATE;
  END IF;

  RETURN QUERY
  SELECT 
    rctb.receiver_name,
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
  FROM claims.v_rejected_claims_tab_b rctb
  WHERE 
    (p_facility_codes IS NULL OR rctb.facility_id = ANY(p_facility_codes))
    AND (p_payer_codes IS NULL OR rctb.id_payer = ANY(p_payer_codes))
    AND (p_receiver_ids IS NULL OR rctb.receiver_name = ANY(p_receiver_ids))
  ORDER BY 
    CASE WHEN p_order_direction = 'DESC' THEN
      CASE p_order_by
        WHEN 'receiver_name' THEN rctb.receiver_name
        WHEN 'payer_name' THEN rctb.payer_name
        WHEN 'rejected_amt' THEN rctb.rejected_amt::TEXT
        WHEN 'rejected_percentage_remittance' THEN rctb.rejected_percentage_remittance::TEXT
        ELSE rctb.receiver_name
      END
    END DESC,
    CASE WHEN p_order_direction = 'ASC' OR p_order_direction IS NULL THEN
      CASE p_order_by
        WHEN 'receiver_name' THEN rctb.receiver_name
        WHEN 'payer_name' THEN rctb.payer_name
        WHEN 'rejected_amt' THEN rctb.rejected_amt::TEXT
        WHEN 'rejected_percentage_remittance' THEN rctb.rejected_percentage_remittance::TEXT
        ELSE rctb.receiver_name
      END
    END ASC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION claims.get_rejected_claims_tab_b IS 'API function for Rejected Claims Tab B with comprehensive filtering and pagination';

-- ==========================================================================================================
-- API FUNCTION: Get Rejected Claims Tab C
-- ==========================================================================================================

CREATE OR REPLACE FUNCTION claims.get_rejected_claims_tab_c(
  p_user_id TEXT,
  p_facility_codes TEXT[] DEFAULT NULL,
  p_payer_codes TEXT[] DEFAULT NULL,
  p_receiver_ids TEXT[] DEFAULT NULL,
  p_date_from TIMESTAMPTZ DEFAULT NULL,
  p_date_to TIMESTAMPTZ DEFAULT NULL,
  p_year INTEGER DEFAULT NULL,
  p_month INTEGER DEFAULT NULL,
  p_limit INTEGER DEFAULT 100,
  p_offset INTEGER DEFAULT 0,
  p_order_by TEXT DEFAULT 'claim_number',
  p_order_direction TEXT DEFAULT 'ASC'
)
RETURNS TABLE (
  claim_key_id BIGINT,
  claim_number TEXT,
  payer_name TEXT,
  id_payer TEXT,
  patient_id TEXT,
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
  receiver_name TEXT,
  ageing_days INTEGER,
  current_status SMALLINT,
  resubmission_type TEXT,
  resubmission_comment TEXT,
  submission_file_id TEXT,
  remittance_file_id TEXT,
  submission_transaction_date TIMESTAMPTZ,
  remittance_transaction_date TIMESTAMPTZ,
  claim_comments TEXT
) 
LANGUAGE plpgsql
AS $$
BEGIN
  -- Set default date range if not provided
  IF p_date_from IS NULL THEN
    p_date_from := CURRENT_DATE - INTERVAL '3 years';
  END IF;
  
  IF p_date_to IS NULL THEN
    p_date_to := CURRENT_DATE;
  END IF;

  RETURN QUERY
  SELECT 
    rctc.claim_key_id,
    rctc.claim_number,
    rctc.payer_name,
    rctc.id_payer,
    rctc.patient_id,
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
    rctc.receiver_name,
    rctc.ageing_days,
    rctc.current_status,
    rctc.resubmission_type,
    rctc.resubmission_comment,
    rctc.submission_file_id,
    rctc.remittance_file_id,
    rctc.submission_transaction_date,
    rctc.remittance_transaction_date,
    rctc.claim_comments
  FROM claims.v_rejected_claims_tab_c rctc
  WHERE 
    (p_facility_codes IS NULL OR rctc.facility_name = ANY(p_facility_codes))
    AND (p_payer_codes IS NULL OR rctc.payer_name = ANY(p_payer_codes))
    AND (p_receiver_ids IS NULL OR rctc.receiver_name = ANY(p_receiver_ids))
    AND (p_date_from IS NULL OR rctc.service_date >= p_date_from)
    AND (p_date_to IS NULL OR rctc.service_date <= p_date_to)
    AND (p_year IS NULL OR EXTRACT(YEAR FROM rctc.service_date) = p_year)
    AND (p_month IS NULL OR EXTRACT(MONTH FROM rctc.service_date) = p_month)
  ORDER BY 
    CASE WHEN p_order_direction = 'DESC' THEN
      CASE p_order_by
        WHEN 'claim_number' THEN rctc.claim_number
        WHEN 'service_date' THEN rctc.service_date::TEXT
        WHEN 'rejected_amt' THEN rctc.rejected_amt::TEXT
        WHEN 'denial_code' THEN rctc.denial_code
        ELSE rctc.claim_number
      END
    END DESC,
    CASE WHEN p_order_direction = 'ASC' OR p_order_direction IS NULL THEN
      CASE p_order_by
        WHEN 'claim_number' THEN rctc.claim_number
        WHEN 'service_date' THEN rctc.service_date::TEXT
        WHEN 'rejected_amt' THEN rctc.rejected_amt::TEXT
        WHEN 'denial_code' THEN rctc.denial_code
        ELSE rctc.claim_number
      END
    END ASC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION claims.get_rejected_claims_tab_c IS 'API function for Rejected Claims Tab C with comprehensive filtering and pagination';

-- ==========================================================================================================
-- SECTION 5: PERFORMANCE OPTIMIZATION
-- ==========================================================================================================
-- Additional indexes for optimal performance
-- ==========================================================================================================

-- Indexes for rejected claims base view performance
CREATE INDEX IF NOT EXISTS idx_remittance_activity_denial_code ON claims.remittance_activity(denial_code) WHERE denial_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_remittance_activity_payment_amount ON claims.remittance_activity(payment_amount) WHERE payment_amount < net;
CREATE INDEX IF NOT EXISTS idx_remittance_activity_rejection ON claims.remittance_activity(remittance_claim_id) WHERE payment_amount = 0 OR denial_code IS NOT NULL;

-- Indexes for facility and payer lookups
CREATE INDEX IF NOT EXISTS idx_encounter_facility_id ON claims.encounter(facility_id);
CREATE INDEX IF NOT EXISTS idx_claim_payer_id ON claims.claim(payer_id);
CREATE INDEX IF NOT EXISTS idx_ingestion_file_receiver_id ON claims.ingestion_file(receiver_id);

-- Indexes for date-based filtering
CREATE INDEX IF NOT EXISTS idx_encounter_start_at ON claims.encounter(start_at);
CREATE INDEX IF NOT EXISTS idx_remittance_claim_date_settlement ON claims.remittance_claim(date_settlement);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_claim_encounter_facility ON claims.claim(id, payer_id) INCLUDE (net, tx_at);
CREATE INDEX IF NOT EXISTS idx_remittance_claim_denial ON claims.remittance_claim(claim_key_id, denial_code) WHERE denial_code IS NOT NULL;

-- ==========================================================================================================
-- SECTION 6: GRANTS AND PERMISSIONS
-- ==========================================================================================================

-- Grant permissions to claims_user role
GRANT SELECT ON claims.v_rejected_claims_base TO claims_user;
GRANT SELECT ON claims.v_rejected_claims_summary TO claims_user;
GRANT SELECT ON claims.v_rejected_claims_tab_a TO claims_user;
GRANT SELECT ON claims.v_rejected_claims_tab_b TO claims_user;
GRANT SELECT ON claims.v_rejected_claims_tab_c TO claims_user;

GRANT EXECUTE ON FUNCTION claims.get_rejected_claims_tab_a TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_rejected_claims_tab_b TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_rejected_claims_tab_c TO claims_user;

-- ==========================================================================================================
-- SECTION 7: VALIDATION QUERIES
-- ==========================================================================================================
-- Test queries to validate the implementation
-- ==========================================================================================================

-- Basic health check
-- SELECT COUNT(*) FROM claims.v_rejected_claims_base;
-- SELECT COUNT(*) FROM claims.v_rejected_claims_tab_a;
-- SELECT COUNT(*) FROM claims.v_rejected_claims_tab_b;
-- SELECT COUNT(*) FROM claims.v_rejected_claims_tab_c;

-- Test API functions
-- SELECT * FROM claims.get_rejected_claims_tab_a('test_user', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 10, 0, 'facility_name', 'ASC');
-- SELECT * FROM claims.get_rejected_claims_tab_b('test_user', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 10, 0, 'receiver_name', 'ASC');
-- SELECT * FROM claims.get_rejected_claims_tab_c('test_user', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 10, 0, 'claim_number', 'ASC');

-- ==========================================================================================================
-- END OF REJECTED CLAIMS REPORT IMPLEMENTATION
-- ==========================================================================================================
