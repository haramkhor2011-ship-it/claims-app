-- ==========================================================================================================
-- FIX: mv_remittance_advice_summary - Apply Claim-Level Aggregation
-- ==========================================================================================================
-- 
-- Purpose: Fix mv_remittance_advice_summary to provide claim-level aggregation
-- Root Cause: Currently groups by rc.id (remittance_claim) instead of claim_key_id
-- Solution: Pre-aggregate remittance data per claim to ensure one row per claim
-- 
-- Analysis: This MV is for Remittance Advice Report - claim-level view
-- - Business Requirement: Show remittance advice per claim, not per remittance
-- - One-to-Many: claim_key → remittance_claim (multiple remittances per claim)
-- - One-to-Many: remittance_claim → remittance_activity (multiple activities per remittance)
-- - Required: Claim-level aggregation with latest remittance information
-- ==========================================================================================================

-- ==========================================================================================================
-- STEP 1: Drop existing materialized view
-- ==========================================================================================================
DROP MATERIALIZED VIEW IF EXISTS claims.mv_remittance_advice_summary CASCADE;

-- ==========================================================================================================
-- STEP 2: Create fixed materialized view with claim-level aggregation
-- ==========================================================================================================
CREATE MATERIALIZED VIEW claims.mv_remittance_advice_summary AS
WITH claim_remittance_agg AS (
  -- Pre-aggregate all remittance data per claim_key_id to prevent duplicates
  SELECT 
    rc.claim_key_id,
    -- Aggregate all remittances for this claim
    COUNT(DISTINCT rc.id) as remittance_count,
    SUM(ra.payment_amount) as total_payment,
    SUM(ra.net) as total_remitted,
    COUNT(CASE WHEN ra.denial_code IS NOT NULL THEN 1 END) as denied_count,
    SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) as denied_amount,
    COUNT(ra.id) as total_activity_count,
    -- Use the most recent remittance for payer/provider info
    (ARRAY_AGG(rc.id_payer ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_id_payer,
    (ARRAY_AGG(rc.provider_id ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_provider_id,
    (ARRAY_AGG(rc.id ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_remittance_claim_id,
    MAX(rc.date_settlement) as latest_settlement_date,
    MAX(rc.payment_reference) as latest_payment_reference,
    -- Additional metrics
    MIN(rc.date_settlement) as first_settlement_date,
    STRING_AGG(DISTINCT ra.denial_code, ', ') as all_denial_codes
  FROM claims.remittance_claim rc
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
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

-- ==========================================================================================================
-- STEP 3: Create performance indexes
-- ==========================================================================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_remittance_unique 
ON claims.mv_remittance_advice_summary(claim_key_id);

CREATE INDEX IF NOT EXISTS idx_mv_remittance_covering 
ON claims.mv_remittance_advice_summary(id_payer, date_settlement) 
INCLUDE (total_payment, total_remitted, denied_amount);

CREATE INDEX IF NOT EXISTS idx_mv_remittance_claim 
ON claims.mv_remittance_advice_summary(claim_key_id, remittance_claim_id);

CREATE INDEX IF NOT EXISTS idx_mv_remittance_payer 
ON claims.mv_remittance_advice_summary(id_payer, payment_status);

-- ==========================================================================================================
-- STEP 4: Add documentation comment
-- ==========================================================================================================
COMMENT ON MATERIALIZED VIEW claims.mv_remittance_advice_summary IS 'Pre-aggregated remittance advice data for sub-second report performance - FIXED: Claim-level aggregation to prevent duplicates from multiple remittances per claim';

-- ==========================================================================================================
-- STEP 5: Test the materialized view
-- ==========================================================================================================

-- Test 1: Check row count
SELECT 'mv_remittance_advice_summary' as view_name, COUNT(*) as row_count 
FROM claims.mv_remittance_advice_summary;

-- Test 2: Check for duplicates (should be 0)
WITH duplicate_check AS (
  SELECT 
    claim_key_id,
    COUNT(*) as row_count
  FROM claims.mv_remittance_advice_summary
  GROUP BY claim_key_id
)
SELECT 
  COUNT(*) as total_unique_claims,
  SUM(row_count) as total_rows,
  COUNT(CASE WHEN row_count > 1 THEN 1 END) as duplicate_claims,
  SUM(CASE WHEN row_count > 1 THEN row_count - 1 ELSE 0 END) as total_duplicate_rows
FROM duplicate_check;

-- Test 3: Verify claim-level aggregation is working
SELECT 
  claim_key_id,
  remittance_count,
  total_payment,
  total_remitted,
  denied_count,
  payment_status
FROM claims.mv_remittance_advice_summary
WHERE remittance_count > 1
ORDER BY remittance_count DESC
LIMIT 5;

-- Test 4: Check payment status distribution
SELECT 
  payment_status,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM claims.mv_remittance_advice_summary
GROUP BY payment_status
ORDER BY count DESC;

-- Test 5: Check claims with multiple remittances
SELECT 
  claim_key_id,
  remittance_count,
  first_settlement_date,
  date_settlement,
  total_payment,
  payment_status
FROM claims.mv_remittance_advice_summary
WHERE remittance_count > 1
LIMIT 5;

-- Test 6: Test refresh
REFRESH MATERIALIZED VIEW claims.mv_remittance_advice_summary;

-- ==========================================================================================================
-- STEP 7: Final verification
-- ==========================================================================================================
SELECT 'SUCCESS' as status, 
       'mv_remittance_advice_summary fixed with claim-level aggregation' as message,
       COUNT(*) as total_rows
FROM claims.mv_remittance_advice_summary;

-- ==========================================================================================================
-- SUMMARY OF CHANGES
-- ==========================================================================================================
-- 
-- CHANGES MADE:
-- 1. Added claim_remittance_agg CTE to pre-aggregate remittance data per claim_key_id
-- 2. Changed grouping from rc.id (remittance_claim) to claim_key_id (claim)
-- 3. Used ARRAY_AGG() to get latest remittance information for payer/provider
-- 4. Added proper aggregation logic for all remittance activities per claim
-- 5. Updated documentation comment to indicate fix applied
-- 6. Added calculated fields for collection rate and payment status
-- 
-- BENEFITS:
-- - Eliminates duplicate rows from multiple remittances per claim
-- - Ensures one row per claim with aggregated remittance data
-- - Maintains all original functionality and metrics
-- - Improves performance by reducing data duplication
-- - Follows claim-level aggregation pattern for Remittance Advice Report
-- 
-- TESTING:
-- - Row count verification
-- - Duplicate detection
-- - Claim-level aggregation verification
-- - Payment status distribution
-- - Refresh testing
-- ==========================================================================================================

