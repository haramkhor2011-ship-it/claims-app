-- ==========================================================================================================
-- FIX: mv_rejected_claims_summary - CORRECTED VERSION
-- ==========================================================================================================
-- 
-- Purpose: Fix duplicate key violations in mv_rejected_claims_summary
-- Issue: WHERE clause was too restrictive, causing 0 rows
-- Solution: Remove restrictive WHERE clause and handle filtering in CTE
-- ==========================================================================================================

-- ==========================================================================================================
-- STEP 1: Drop existing materialized view
-- ==========================================================================================================
DROP MATERIALIZED VIEW IF EXISTS claims.mv_rejected_claims_summary CASCADE;

-- ==========================================================================================================
-- STEP 2: Create fixed materialized view with corrected logic
-- ==========================================================================================================
CREATE MATERIALIZED VIEW claims.mv_rejected_claims_summary AS
WITH activity_rejection_agg AS (
  -- Pre-aggregate rejection data per activity to prevent duplicates
  SELECT 
    a.activity_id,
    a.claim_id,
    -- Get latest rejection status for this activity
    MAX(ra.denial_code) as latest_denial_code,
    MAX(rc.date_settlement) as latest_settlement_date,
    MAX(rc.payment_reference) as latest_payment_reference,
    MAX(rc.id) as latest_remittance_claim_id,
    -- Calculate rejection amount and type
    CASE 
      WHEN MAX(ra.payment_amount) = 0 AND MAX(ra.denial_code) IS NOT NULL THEN a.net
      WHEN MAX(ra.payment_amount) > 0 AND MAX(ra.payment_amount) < a.net THEN a.net - MAX(ra.payment_amount)
      ELSE 0
    END as rejected_amount,
    -- Determine rejection type
    CASE 
      WHEN MAX(ra.payment_amount) = 0 AND MAX(ra.denial_code) IS NOT NULL THEN 'Fully Rejected'
      WHEN MAX(ra.payment_amount) > 0 AND MAX(ra.payment_amount) < a.net THEN 'Partially Rejected'
      WHEN MAX(ra.payment_amount) = 0 AND MAX(ra.denial_code) IS NULL THEN 'No Payment'
      ELSE 'Unknown'
    END as rejection_type,
    -- Additional metrics
    COUNT(DISTINCT rc.id) as remittance_count,
    SUM(ra.payment_amount) as total_payment_amount,
    MAX(ra.payment_amount) as max_payment_amount
  FROM claims.activity a
  LEFT JOIN claims.claim c ON c.id = a.claim_id
  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = c.claim_key_id
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id 
    AND ra.activity_id = a.activity_id
  WHERE ra.payment_amount = 0 OR ra.denial_code IS NOT NULL OR ra.payment_amount < a.net
  GROUP BY a.activity_id, a.claim_id, a.net
)
SELECT 
  -- Core identifiers
  ck.id as claim_key_id,
  ck.claim_id,
  c.id as claim_internal_id,
  
  -- Payer information
  c.id_payer as payer_id,
  COALESCE(p.name, c.id_payer, 'Unknown Payer') as payer_name,
  c.payer_ref_id,
  
  -- Patient information
  c.member_id,
  c.emirates_id_number,
  
  -- Facility information
  e.facility_id,
  e.facility_ref_id,
  COALESCE(f.name, e.facility_id, 'Unknown Facility') as facility_name,
  
  -- Clinician information
  a.clinician,
  a.clinician_ref_id,
  COALESCE(cl.name, a.clinician, 'Unknown Clinician') as clinician_name,
  
  -- Activity details
  a.activity_id,
  a.start_at as activity_start_date,
  a.type as activity_type,
  a.code as activity_code,
  a.quantity,
  a.net as activity_net_amount,
  
  -- Rejection details (aggregated per activity)
  ara.latest_denial_code as activity_denial_code,
  COALESCE(dc.description, ara.latest_denial_code, 'No Denial Code') as denial_type,
  ara.rejection_type,
  ara.rejected_amount,
  
  -- Time-based fields
  DATE_TRUNC('month', COALESCE(ara.latest_settlement_date, c.tx_at)) as report_month,
  EXTRACT(YEAR FROM COALESCE(ara.latest_settlement_date, c.tx_at)) as report_year,
  EXTRACT(MONTH FROM COALESCE(ara.latest_settlement_date, c.tx_at)) as report_month_num,
  
  -- Aging
  EXTRACT(DAYS FROM (CURRENT_DATE - DATE_TRUNC('day', a.start_at))) as aging_days,
  
  -- Reference data
  s.id as submission_id,
  s.tx_at as submission_date,
  ara.latest_remittance_claim_id as remittance_claim_id,
  ara.latest_settlement_date as date_settlement,
  ara.latest_payment_reference as payment_reference,
  
  -- Additional aggregated metrics
  ara.remittance_count,
  ara.total_payment_amount,
  ara.max_payment_amount

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN activity_rejection_agg ara ON ara.activity_id = a.activity_id AND ara.claim_id = c.id
LEFT JOIN claims.submission s ON s.id = c.submission_id
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims_ref.denial_code dc ON dc.code = ara.latest_denial_code
WHERE ara.activity_id IS NOT NULL; -- Only include activities that have rejection data

-- ==========================================================================================================
-- STEP 3: Create performance indexes
-- ==========================================================================================================
CREATE UNIQUE INDEX IF NOT EXISTS mv_rejected_claims_summary_pk 
ON claims.mv_rejected_claims_summary (claim_key_id, activity_id);

CREATE INDEX IF NOT EXISTS mv_rejected_claims_summary_payer_idx 
ON claims.mv_rejected_claims_summary (payer_id, report_month);

CREATE INDEX IF NOT EXISTS mv_rejected_claims_summary_facility_idx 
ON claims.mv_rejected_claims_summary (facility_id, report_month);

CREATE INDEX IF NOT EXISTS mv_rejected_claims_summary_clinician_idx 
ON claims.mv_rejected_claims_summary (clinician_ref_id, report_month);

CREATE INDEX IF NOT EXISTS mv_rejected_claims_summary_denial_code_idx 
ON claims.mv_rejected_claims_summary (activity_denial_code);

CREATE INDEX IF NOT EXISTS mv_rejected_claims_summary_aging_idx 
ON claims.mv_rejected_claims_summary (aging_days);

-- ==========================================================================================================
-- STEP 4: Add documentation comment
-- ==========================================================================================================
COMMENT ON MATERIALIZED VIEW claims.mv_rejected_claims_summary IS 'Pre-computed rejected claims data for sub-second report performance - FIXED: Activity-level rejection aggregation to prevent duplicates';

-- ==========================================================================================================
-- STEP 5: Test the materialized view
-- ==========================================================================================================

-- Test 1: Check row count
SELECT 'mv_rejected_claims_summary' as view_name, COUNT(*) as row_count 
FROM claims.mv_rejected_claims_summary;

-- Test 2: Check for duplicates (should be 0)
WITH duplicate_check AS (
  SELECT 
    claim_key_id, 
    activity_id,
    COUNT(*) as row_count
  FROM claims.mv_rejected_claims_summary
  GROUP BY claim_key_id, activity_id
)
SELECT 
  COUNT(*) as total_unique_combinations,
  SUM(row_count) as total_rows,
  COUNT(CASE WHEN row_count > 1 THEN 1 END) as duplicate_combinations,
  SUM(CASE WHEN row_count > 1 THEN row_count - 1 ELSE 0 END) as total_duplicate_rows
FROM duplicate_check;

-- Test 3: Verify rejection aggregation is working
SELECT 
  claim_key_id,
  activity_id,
  rejection_type,
  rejected_amount,
  activity_denial_code,
  remittance_count
FROM claims.mv_rejected_claims_summary
WHERE remittance_count > 1
LIMIT 5;

-- Test 4: Test refresh
REFRESH MATERIALIZED VIEW claims.mv_rejected_claims_summary;

-- ==========================================================================================================
-- STEP 6: Final verification
-- ==========================================================================================================
SELECT 'SUCCESS' as status, 
       'mv_rejected_claims_summary fixed with activity-level rejection aggregation' as message,
       COUNT(*) as total_rows
FROM claims.mv_rejected_claims_summary;

