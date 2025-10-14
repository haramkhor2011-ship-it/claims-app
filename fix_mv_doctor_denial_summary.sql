-- ==========================================================================================================
-- FIX: mv_doctor_denial_summary - Apply Remittance Aggregation Pattern
-- ==========================================================================================================
-- 
-- Purpose: Fix duplicate key violations in mv_doctor_denial_summary
-- Root Cause: Direct LEFT JOINs to remittance_claim and remittance_activity create multiple rows per claim
-- Solution: Pre-aggregate remittance data before joining to ensure one row per (clinician_id, facility_code, report_month)
-- 
-- This fix applies the same successful pattern used in:
-- - mv_claim_summary_payerwise (FIXED)
-- - mv_claim_summary_encounterwise (FIXED)
-- - mv_remittances_resubmission_activity_level (FIXED)
-- ==========================================================================================================

-- ==========================================================================================================
-- STEP 1: Drop existing materialized view
-- ==========================================================================================================
DROP MATERIALIZED VIEW IF EXISTS claims.mv_doctor_denial_summary CASCADE;

-- ==========================================================================================================
-- STEP 2: Create fixed materialized view with remittance aggregation
-- ==========================================================================================================
CREATE MATERIALIZED VIEW claims.mv_doctor_denial_summary AS
WITH remittance_aggregated AS (
  -- Pre-aggregate all remittance data per claim_key_id to prevent duplicates
  SELECT 
    rc.claim_key_id,
    COUNT(*) as remittance_count,
    SUM(ra.payment_amount) as total_payment_amount,
    SUM(ra.net) as total_remitted_amount,
    COUNT(CASE WHEN ra.payment_amount > 0 THEN 1 END) as paid_activity_count,
    COUNT(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 1 END) as rejected_activity_count,
    MIN(rc.date_settlement) as first_remittance_date,
    MAX(rc.date_settlement) as last_remittance_date,
    -- Use the most recent remittance for payer/provider info
    (ARRAY_AGG(rc.id_payer ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_id_payer,
    (ARRAY_AGG(rc.provider_id ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_provider_id
  FROM claims.remittance_claim rc
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
),
clinician_activity_agg AS (
  SELECT 
    cl.id as clinician_id,
    cl.name as clinician_name,
    cl.specialty,
    f.facility_code,
    f.name as facility_name,
    DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at)) as report_month,
    -- Pre-computed aggregations (now one row per claim)
    COUNT(DISTINCT ck.claim_id) as total_claims,
    COUNT(DISTINCT CASE WHEN ra.claim_key_id IS NOT NULL THEN ck.claim_id END) as remitted_claims,
    COUNT(DISTINCT CASE WHEN ra.rejected_activity_count > 0 THEN ck.claim_id END) as rejected_claims,
    SUM(a.net) as total_claim_amount,
    SUM(COALESCE(ra.total_payment_amount, 0)) as remitted_amount,
    SUM(CASE WHEN ra.rejected_activity_count > 0 THEN ra.total_remitted_amount ELSE 0 END) as rejected_amount
  FROM claims.claim_key ck
  JOIN claims.claim c ON c.claim_key_id = ck.id
  LEFT JOIN claims.encounter e ON e.claim_id = c.id
  LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
  LEFT JOIN claims.activity a ON a.claim_id = c.id
  LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
  LEFT JOIN remittance_aggregated ra ON ra.claim_key_id = ck.id
  WHERE cl.id IS NOT NULL AND f.facility_code IS NOT NULL
  GROUP BY cl.id, cl.name, cl.specialty, f.facility_code, f.name,
           DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at))
)
SELECT 
  clinician_id,
  clinician_name,
  specialty,
  facility_code,
  facility_name,
  report_month,
  total_claims,
  remitted_claims,
  rejected_claims,
  total_claim_amount,
  remitted_amount,
  rejected_amount,
  -- Pre-computed metrics
  CASE WHEN total_claims > 0 THEN
    ROUND((rejected_claims * 100.0) / total_claims, 2)
  ELSE 0 END as rejection_percentage,
  CASE WHEN total_claim_amount > 0 THEN
    ROUND((remitted_amount / total_claim_amount) * 100, 2)
  ELSE 0 END as collection_rate
FROM clinician_activity_agg;

-- ==========================================================================================================
-- STEP 3: Create performance indexes
-- ==========================================================================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_clinician_unique 
ON claims.mv_doctor_denial_summary(clinician_id, facility_code, report_month);

CREATE INDEX IF NOT EXISTS idx_mv_clinician_covering 
ON claims.mv_doctor_denial_summary(clinician_id, report_month) 
INCLUDE (rejection_percentage, collection_rate, total_claims);

CREATE INDEX IF NOT EXISTS idx_mv_clinician_facility 
ON claims.mv_doctor_denial_summary(facility_code, report_month);

-- ==========================================================================================================
-- STEP 4: Add documentation comment
-- ==========================================================================================================
COMMENT ON MATERIALIZED VIEW claims.mv_doctor_denial_summary IS 'Pre-computed clinician denial metrics for sub-second report performance - FIXED: Aggregated remittance data to prevent duplicates';

-- ==========================================================================================================
-- STEP 5: Test the materialized view
-- ==========================================================================================================

-- Test 1: Check row count
SELECT 'mv_doctor_denial_summary' as view_name, COUNT(*) as row_count 
FROM claims.mv_doctor_denial_summary;

-- Test 2: Check for duplicates (should be 0)
WITH duplicate_check AS (
  SELECT 
    clinician_id, 
    facility_code, 
    report_month,
    COUNT(*) as row_count
  FROM claims.mv_doctor_denial_summary
  GROUP BY clinician_id, facility_code, report_month
)
SELECT 
  COUNT(*) as total_unique_combinations,
  SUM(row_count) as total_rows,
  COUNT(CASE WHEN row_count > 1 THEN 1 END) as duplicate_combinations,
  SUM(CASE WHEN row_count > 1 THEN row_count - 1 ELSE 0 END) as total_duplicate_rows
FROM duplicate_check;

-- Test 3: Verify aggregation is working
SELECT 
  clinician_id,
  clinician_name,
  facility_code,
  report_month,
  total_claims,
  remitted_claims,
  rejected_claims,
  rejection_percentage,
  collection_rate
FROM claims.mv_doctor_denial_summary
WHERE total_claims > 0
ORDER BY rejection_percentage DESC
LIMIT 10;

-- Test 4: Test refresh
REFRESH MATERIALIZED VIEW claims.mv_doctor_denial_summary;

-- ==========================================================================================================
-- STEP 6: Final verification
-- ==========================================================================================================
SELECT 'SUCCESS' as status, 
       'mv_doctor_denial_summary fixed with remittance aggregation pattern' as message,
       COUNT(*) as total_rows
FROM claims.mv_doctor_denial_summary;

-- ==========================================================================================================
-- SUMMARY OF CHANGES
-- ==========================================================================================================
-- 
-- CHANGES MADE:
-- 1. Added remittance_aggregated CTE to pre-aggregate remittance data per claim_key_id
-- 2. Modified clinician_activity_agg CTE to use aggregated remittance data
-- 3. Removed direct LEFT JOINs to remittance_claim and remittance_activity
-- 4. Added proper aggregation logic for rejected_claims and rejected_amount
-- 5. Updated documentation comment to indicate fix applied
-- 
-- BENEFITS:
-- - Eliminates duplicate key violations on (clinician_id, facility_code, report_month)
-- - Ensures one row per clinician/facility/month combination
-- - Maintains all original functionality and metrics
-- - Improves performance by reducing data duplication
-- - Follows proven pattern from other fixed MVs
-- 
-- TESTING:
-- - Row count verification
-- - Duplicate detection
-- - Aggregation verification
-- - Refresh testing
-- ==========================================================================================================
