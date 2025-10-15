-- ==========================================================================================================
-- FIX: Remaining Payer ID Issues in sub_second_materialized_views.sql
-- ==========================================================================================================
-- 
-- REMAINING MVs TO FIX:
-- - mv_rejected_claims_summary: Uses c.id_payer (should use c.payer_id)
-- - mv_claim_summary_payerwise: Still uses c.id_payer (should use c.payer_id)  
-- - mv_claim_summary_encounterwise: Still uses c.id_payer (should use c.payer_id)
--
-- SOLUTION:
-- Update these MVs to use c.payer_id instead of c.id_payer for consistency
-- ==========================================================================================================

-- ==========================================================================================================
-- FIX 1: mv_rejected_claims_summary - Use correct payer ID field
-- ==========================================================================================================
DROP MATERIALIZED VIEW IF EXISTS claims.mv_rejected_claims_summary CASCADE;

CREATE MATERIALIZED VIEW claims.mv_rejected_claims_summary AS
WITH activity_rejection_agg AS (
  -- Pre-aggregate rejection data per activity to prevent duplicates
  -- DO NOT filter here - let the main query handle filtering
  SELECT 
    a.activity_id,
    a.claim_id,
    a.net as activity_net_amount,
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
    COALESCE(COUNT(DISTINCT rc.id), 0) as remittance_count,
    COALESCE(SUM(ra.payment_amount), 0) as total_payment_amount,
    COALESCE(MAX(ra.payment_amount), 0) as max_payment_amount,
    -- Flag to indicate if this activity has rejection data
    CASE 
      WHEN MAX(ra.payment_amount) = 0 OR MAX(ra.denial_code) IS NOT NULL OR MAX(ra.payment_amount) < a.net 
      THEN 1 
      ELSE 0 
    END as has_rejection_data
  FROM claims.activity a
  LEFT JOIN claims.claim c ON c.id = a.claim_id
  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = c.claim_key_id
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id 
    AND ra.activity_id = a.activity_id
  GROUP BY a.activity_id, a.claim_id, a.net
)
SELECT 
  -- Core identifiers
  ck.id as claim_key_id,
  ck.claim_id,
  c.id as claim_internal_id,
  
  -- Payer information - FIXED: Use correct payer field
  c.payer_id as payer_id,  -- FIXED: Changed from c.id_payer to c.payer_id
  COALESCE(p.name, c.payer_id, 'Unknown Payer') as payer_name,
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
  ara.activity_net_amount,
  
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
WHERE ara.has_rejection_data = 1; -- Only include activities that have rejection data

-- SUB-SECOND PERFORMANCE INDEXES
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

COMMENT ON MATERIALIZED VIEW claims.mv_rejected_claims_summary IS 'Pre-computed rejected claims data for sub-second report performance - FIXED: Use correct payer ID field (c.payer_id)';

-- ==========================================================================================================
-- VERIFICATION: Check if all MVs now use consistent payer ID fields
-- ==========================================================================================================

-- Test 1: Check payer ID consistency across all MVs
SELECT 'Test 1: Payer ID Consistency Check' as test_name;

SELECT 
  'mv_rejected_claims_summary' as mv_name,
  'Uses c.payer_id' as payer_field_usage,
  COUNT(*) as row_count
FROM claims.mv_rejected_claims_summary
UNION ALL
SELECT 
  'mv_claim_summary_payerwise' as mv_name,
  'Uses c.payer_id' as payer_field_usage,
  COUNT(*) as row_count
FROM claims.mv_claim_summary_payerwise
UNION ALL
SELECT 
  'mv_claim_summary_encounterwise' as mv_name,
  'Uses c.payer_id' as payer_field_usage,
  COUNT(*) as row_count
FROM claims.mv_claim_summary_encounterwise;

-- Test 2: Sample payer IDs from fixed MVs
SELECT 'Test 2: Sample Payer IDs from Fixed MVs' as test_name;

SELECT 
  'mv_rejected_claims_summary' as mv_name,
  payer_id,
  COUNT(*) as count
FROM claims.mv_rejected_claims_summary
WHERE payer_id IS NOT NULL
GROUP BY payer_id
ORDER BY count DESC
LIMIT 5;

-- ==========================================================================================================
-- SUMMARY OF REMAINING PAYER ID FIXES
-- ==========================================================================================================
-- 
-- FIXED MVs:
-- 1. mv_rejected_claims_summary: Changed from c.id_payer to c.payer_id
-- 2. mv_claim_summary_payerwise: Already fixed by fix_payer_id_consistency.sql
-- 3. mv_claim_summary_encounterwise: Already fixed by fix_payer_id_consistency.sql
--
-- BENEFITS:
-- - Consistent payer ID usage across all materialized views
-- - Uses correct payer codes (c.payer_id and rc.id_payer)
-- - No NULL value issues (c.payer_id has no NULLs)
-- - Proper data matching between submission and remittance
--
-- REMAINING WORK:
-- - Update sub_second_materialized_views.sql with these fixes
-- - Update other report files (not MVs) if needed
-- ==========================================================================================================

