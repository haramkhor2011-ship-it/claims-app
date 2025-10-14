-- ==========================================================================================================
-- FIX: mv_claim_details_complete - Apply Activity-Level Remittance Aggregation
-- ==========================================================================================================
-- 
-- Purpose: Fix duplicate key violations in mv_claim_details_complete
-- Root Cause: Direct LEFT JOINs to remittance_claim and remittance_activity create multiple rows per activity
-- Solution: Pre-aggregate remittance data per activity before joining to ensure one row per (claim_key_id, activity_id)
-- 
-- Analysis: This MV is for Claim Details Report - activity-level view
-- - One-to-Many: claim_key → remittance_claim (multiple remittances per claim)
-- - One-to-Many: remittance_claim → remittance_activity (multiple activities per remittance)
-- - Required: Activity-level aggregation, not claim-level
-- ==========================================================================================================

-- ==========================================================================================================
-- STEP 1: Drop existing materialized view
-- ==========================================================================================================
DROP MATERIALIZED VIEW IF EXISTS claims.mv_claim_details_complete CASCADE;

-- ==========================================================================================================
-- STEP 2: Create fixed materialized view with activity-level remittance aggregation
-- ==========================================================================================================
CREATE MATERIALIZED VIEW claims.mv_claim_details_complete AS
WITH activity_remittance_agg AS (
  -- Pre-aggregate remittance data per activity to prevent duplicates
  SELECT 
    a.activity_id,
    a.claim_id,
    -- Aggregate all remittances for this activity across all remittance cycles
    SUM(ra.payment_amount) as total_payment_amount,
    MAX(ra.denial_code) as latest_denial_code,
    MAX(rc.date_settlement) as latest_settlement_date,
    MAX(rc.payment_reference) as latest_payment_reference,
    COUNT(DISTINCT rc.id) as remittance_count,
    -- Additional remittance metrics
    SUM(ra.net) as total_remitted_amount,
    COUNT(CASE WHEN ra.payment_amount > 0 THEN 1 END) as paid_remittance_count,
    COUNT(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 1 END) as rejected_remittance_count
  FROM claims.activity a
  LEFT JOIN claims.claim c ON c.id = a.claim_id
  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = c.claim_key_id
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id 
    AND ra.activity_id = a.activity_id
  GROUP BY a.activity_id, a.claim_id
)
SELECT 
  ck.id as claim_key_id,
  ck.claim_id,
  c.id as claim_db_id,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.gross,
  c.patient_share,
  c.net,
  c.tx_at as submission_date,
  -- Encounter details
  e.facility_id,
  e.type as encounter_type,
  e.patient_id,
  e.start_at as encounter_start,
  e.end_at as encounter_end,
  -- Activity details
  a.activity_id,
  a.start_at as activity_start,
  a.type as activity_type,
  a.code as activity_code,
  a.quantity,
  a.net as activity_net,
  a.clinician,
  -- Remittance details (aggregated per activity)
  COALESCE(ara.total_payment_amount, 0) as payment_amount,
  ara.latest_denial_code as denial_code,
  ara.latest_settlement_date as date_settlement,
  ara.latest_payment_reference as payment_reference,
  -- Reference data
  p.name as provider_name,
  f.name as facility_name,
  pay.name as payer_name,
  cl.name as clinician_name,
  -- Calculated fields
  CASE 
    WHEN ara.latest_denial_code IS NOT NULL AND ara.total_payment_amount = 0 THEN 'Fully Rejected'
    WHEN ara.total_payment_amount > 0 AND ara.total_payment_amount < a.net THEN 'Partially Rejected'
    WHEN ara.total_payment_amount = a.net THEN 'Fully Paid'
    ELSE 'Pending'
  END as payment_status,
  EXTRACT(DAYS FROM (CURRENT_DATE - DATE_TRUNC('day', e.start_at))) as aging_days,
  -- Additional aggregated metrics
  ara.remittance_count,
  ara.total_remitted_amount,
  ara.paid_remittance_count,
  ara.rejected_remittance_count
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN activity_remittance_agg ara ON ara.activity_id = a.activity_id AND ara.claim_id = c.id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id;

-- ==========================================================================================================
-- STEP 3: Create performance indexes
-- ==========================================================================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_claim_details_unique 
ON claims.mv_claim_details_complete(claim_key_id, activity_id);

CREATE INDEX IF NOT EXISTS idx_mv_claim_details_covering 
ON claims.mv_claim_details_complete(claim_key_id, payer_id, provider_id) 
INCLUDE (payment_status, aging_days, submission_date);

CREATE INDEX IF NOT EXISTS idx_mv_claim_details_facility 
ON claims.mv_claim_details_complete(facility_id, encounter_start);

CREATE INDEX IF NOT EXISTS idx_mv_claim_details_clinician 
ON claims.mv_claim_details_complete(clinician, activity_start);

-- ==========================================================================================================
-- STEP 4: Add documentation comment
-- ==========================================================================================================
COMMENT ON MATERIALIZED VIEW claims.mv_claim_details_complete IS 'Comprehensive pre-computed claim details for sub-second report performance - FIXED: Activity-level remittance aggregation to prevent duplicates';

-- ==========================================================================================================
-- STEP 5: Test the materialized view
-- ==========================================================================================================

-- Test 1: Check row count
SELECT 'mv_claim_details_complete' as view_name, COUNT(*) as row_count 
FROM claims.mv_claim_details_complete;

-- Test 2: Check for duplicates (should be 0)
WITH duplicate_check AS (
  SELECT 
    claim_key_id, 
    activity_id,
    COUNT(*) as row_count
  FROM claims.mv_claim_details_complete
  GROUP BY claim_key_id, activity_id
)
SELECT 
  COUNT(*) as total_unique_combinations,
  SUM(row_count) as total_rows,
  COUNT(CASE WHEN row_count > 1 THEN 1 END) as duplicate_combinations,
  SUM(CASE WHEN row_count > 1 THEN row_count - 1 ELSE 0 END) as total_duplicate_rows
FROM duplicate_check;

-- Test 3: Verify activity-level aggregation is working
SELECT 
  claim_key_id,
  activity_id,
  payment_amount,
  denial_code,
  payment_status,
  remittance_count
FROM claims.mv_claim_details_complete
WHERE remittance_count > 1
LIMIT 5;

-- Test 4: Test refresh
REFRESH MATERIALIZED VIEW claims.mv_claim_details_complete;

-- ==========================================================================================================
-- STEP 6: Final verification
-- ==========================================================================================================
SELECT 'SUCCESS' as status, 
       'mv_claim_details_complete fixed with activity-level remittance aggregation' as message,
       COUNT(*) as total_rows
FROM claims.mv_claim_details_complete;

-- ==========================================================================================================
-- SUMMARY OF CHANGES
-- ==========================================================================================================
-- 
-- CHANGES MADE:
-- 1. Added activity_remittance_agg CTE to pre-aggregate remittance data per activity
-- 2. Modified main query to use aggregated remittance data instead of direct JOINs
-- 3. Removed direct LEFT JOINs to remittance_claim and remittance_activity
-- 4. Added proper aggregation logic for payment amounts, denial codes, and settlement dates
-- 5. Updated documentation comment to indicate fix applied
-- 
-- BENEFITS:
-- - Eliminates duplicate key violations on (claim_key_id, activity_id)
-- - Ensures one row per activity with aggregated remittance data
-- - Maintains all original functionality and metrics
-- - Improves performance by reducing data duplication
-- - Follows activity-level aggregation pattern for Claim Details Report
-- 
-- TESTING:
-- - Row count verification
-- - Duplicate detection
-- - Activity-level aggregation verification
-- - Refresh testing
-- ==========================================================================================================
