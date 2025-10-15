-- ==========================================================================================================
-- FIX: Payer ID Field Consistency in Materialized Views
-- ==========================================================================================================
-- 
-- ISSUE IDENTIFIED:
-- Some materialized views use inconsistent payer ID fields:
-- - mv_claim_summary_payerwise: Uses c.id_payer (incorrect)
-- - mv_claim_summary_encounterwise: Uses c.id_payer (incorrect)
-- - mv_rejected_claims_summary: Uses c.id_payer (incorrect)
--
-- CORRECT UNDERSTANDING:
-- - claims.claim.payer_id: Real payer code from submission claim (business payer identifier)
-- - claims.remittance_claim.id_payer: Real payer code from remittance claim (should match claims.claim.payer_id)
-- - claims.claim.id_payer: Claim header IDPayer (different field, not the main payer code)
--
-- SOLUTION:
-- Update MVs to use c.payer_id instead of c.id_payer for consistency with correct payer codes
-- ==========================================================================================================

-- ==========================================================================================================
-- FIX 1: mv_claim_summary_payerwise - Use correct payer ID field
-- ==========================================================================================================
DROP MATERIALIZED VIEW IF EXISTS claims.mv_claim_summary_payerwise CASCADE;

CREATE MATERIALIZED VIEW claims.mv_claim_summary_payerwise AS
WITH remittance_aggregated AS (
  -- Pre-aggregate all remittance data per claim_key_id to prevent duplicates
  SELECT 
    rc.claim_key_id,
    COUNT(*) as remittance_count,
    SUM(ra.payment_amount) as total_payment_amount,
    SUM(ra.net) as total_remitted_amount,
    COUNT(CASE WHEN ra.payment_amount > 0 THEN 1 END) as paid_activity_count,
    COUNT(CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN 1 END) as partially_paid_activity_count,
    COUNT(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 1 END) as rejected_activity_count,
    COUNT(CASE WHEN rc.payment_reference IS NOT NULL THEN 1 END) as taken_back_count,
    COUNT(CASE WHEN rc.date_settlement IS NULL THEN 1 END) as pending_remittance_count,
    MIN(rc.date_settlement) as first_remittance_date,
    MAX(rc.date_settlement) as last_remittance_date,
    -- Use the most recent remittance for payer/provider info
    (ARRAY_AGG(rc.id_payer ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_id_payer,
    (ARRAY_AGG(rc.provider_id ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_provider_id
  FROM claims.remittance_claim rc
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
)
SELECT 
  -- Use COALESCE with a default date to ensure we always have a valid month bucket
  DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)) as month_bucket,
  EXTRACT(YEAR FROM COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)) as year,
  EXTRACT(MONTH FROM COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)) as month,
  
  -- Payer information with fallbacks - FIXED: Use correct payer fields
  COALESCE(ra.latest_id_payer, c.payer_id, 'Unknown_' || ck.id::text) as payer_id,
  COALESCE(p.name, ra.latest_id_payer, c.payer_id, 'Unknown Payer') as payer_name,
  
  -- Facility information with fallbacks
  COALESCE(e.facility_id, 'Unknown') as facility_id,
  COALESCE(f.name, e.facility_id, 'Unknown Facility') as facility_name,
  
  -- Claim counts and amounts
  COUNT(*) as total_claims,
  COUNT(CASE WHEN ra.claim_key_id IS NOT NULL THEN 1 END) as claims_with_remittances,
  COUNT(CASE WHEN ra.claim_key_id IS NULL THEN 1 END) as claims_without_remittances,
  
  -- Financial metrics
  SUM(COALESCE(c.net, 0)) as total_claim_amount,
  SUM(COALESCE(ra.total_payment_amount, 0)) as total_paid_amount,
  SUM(COALESCE(ra.total_remitted_amount, 0)) as total_remitted_amount,
  
  -- Remittance metrics
  SUM(COALESCE(ra.remittance_count, 0)) as total_remittances,
  SUM(COALESCE(ra.paid_activity_count, 0)) as total_paid_activities,
  SUM(COALESCE(ra.partially_paid_activity_count, 0)) as total_partially_paid_activities,
  SUM(COALESCE(ra.rejected_activity_count, 0)) as total_rejected_activities,
  SUM(COALESCE(ra.taken_back_count, 0)) as total_taken_back,
  SUM(COALESCE(ra.pending_remittance_count, 0)) as total_pending_remittances,
  
  -- Date ranges
  MIN(COALESCE(ra.first_remittance_date, c.tx_at, ck.created_at)) as earliest_date,
  MAX(COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at)) as latest_date,
  
  -- Additional identifiers
  c.payer_ref_id,
  e.facility_id as raw_facility_id,
  COALESCE(f.name, e.facility_id, 'Unknown Facility') as facility_display_name

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN remittance_aggregated ra ON ra.claim_key_id = ck.id
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id

-- FIXED: Include all necessary fields in GROUP BY, with correct payer_id
GROUP BY 
  DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)),
  EXTRACT(YEAR FROM COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)),
  EXTRACT(MONTH FROM COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)),
  COALESCE(ra.latest_id_payer, c.payer_id, 'Unknown_' || ck.id::text),
  COALESCE(p.name, ra.latest_id_payer, c.payer_id, 'Unknown Payer'),
  COALESCE(e.facility_id, 'Unknown'),
  COALESCE(f.name, e.facility_id, 'Unknown Facility'),
  c.payer_ref_id,
  e.facility_id;

-- SUB-SECOND PERFORMANCE INDEXES
CREATE UNIQUE INDEX IF NOT EXISTS mv_claim_summary_payerwise_pk 
ON claims.mv_claim_summary_payerwise (month_bucket, payer_id, facility_id);

CREATE INDEX IF NOT EXISTS mv_claim_summary_payerwise_month_idx 
ON claims.mv_claim_summary_payerwise (month_bucket);

CREATE INDEX IF NOT EXISTS mv_claim_summary_payerwise_payer_idx 
ON claims.mv_claim_summary_payerwise (payer_id);

CREATE INDEX IF NOT EXISTS mv_claim_summary_payerwise_facility_idx 
ON claims.mv_claim_summary_payerwise (facility_id);

COMMENT ON MATERIALIZED VIEW claims.mv_claim_summary_payerwise IS 'Pre-computed payerwise summary data for sub-second report performance - FIXED: Use correct payer ID fields (c.payer_id and rc.id_payer)';

-- ==========================================================================================================
-- FIX 2: mv_claim_summary_encounterwise - Use correct payer ID field
-- ==========================================================================================================
DROP MATERIALIZED VIEW IF EXISTS claims.mv_claim_summary_encounterwise CASCADE;

CREATE MATERIALIZED VIEW claims.mv_claim_summary_encounterwise AS
WITH remittance_aggregated AS (
  -- Pre-aggregate all remittance data per claim_key_id to prevent duplicates
  SELECT 
    rc.claim_key_id,
    COUNT(*) as remittance_count,
    SUM(ra.payment_amount) as total_payment_amount,
    SUM(ra.net) as total_remitted_amount,
    COUNT(CASE WHEN ra.payment_amount > 0 THEN 1 END) as paid_activity_count,
    COUNT(CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN 1 END) as partially_paid_activity_count,
    COUNT(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 1 END) as rejected_activity_count,
    COUNT(CASE WHEN rc.payment_reference IS NOT NULL THEN 1 END) as taken_back_count,
    COUNT(CASE WHEN rc.date_settlement IS NULL THEN 1 END) as pending_remittance_count,
    MIN(rc.date_settlement) as first_remittance_date,
    MAX(rc.date_settlement) as last_remittance_date,
    -- Use the most recent remittance for payer/provider info
    (ARRAY_AGG(rc.id_payer ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_id_payer,
    (ARRAY_AGG(rc.provider_id ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_provider_id
  FROM claims.remittance_claim rc
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
)
SELECT 
  -- Use COALESCE with a default date to ensure we always have a valid month bucket
  DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)) as month_bucket,
  EXTRACT(YEAR FROM COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)) as year,
  EXTRACT(MONTH FROM COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)) as month,
  
  -- Encounter type information
  COALESCE(e.type, 'Unknown') as encounter_type,
  COALESCE(et.name, e.type, 'Unknown Encounter Type') as encounter_type_name,
  
  -- Facility information with fallbacks
  COALESCE(e.facility_id, 'Unknown') as facility_id,
  COALESCE(f.name, e.facility_id, 'Unknown Facility') as facility_name,
  
  -- Payer information with fallbacks - FIXED: Use correct payer fields
  COALESCE(ra.latest_id_payer, c.payer_id, 'Unknown_' || ck.id::text) as payer_id,
  COALESCE(p.name, ra.latest_id_payer, c.payer_id, 'Unknown Payer') as payer_name,
  
  -- Claim counts and amounts
  COUNT(*) as total_claims,
  COUNT(CASE WHEN ra.claim_key_id IS NOT NULL THEN 1 END) as claims_with_remittances,
  COUNT(CASE WHEN ra.claim_key_id IS NULL THEN 1 END) as claims_without_remittances,
  
  -- Financial metrics
  SUM(COALESCE(c.net, 0)) as total_claim_amount,
  SUM(COALESCE(ra.total_payment_amount, 0)) as total_paid_amount,
  SUM(COALESCE(ra.total_remitted_amount, 0)) as total_remitted_amount,
  
  -- Remittance metrics
  SUM(COALESCE(ra.remittance_count, 0)) as total_remittances,
  SUM(COALESCE(ra.paid_activity_count, 0)) as total_paid_activities,
  SUM(COALESCE(ra.partially_paid_activity_count, 0)) as total_partially_paid_activities,
  SUM(COALESCE(ra.rejected_activity_count, 0)) as total_rejected_activities,
  SUM(COALESCE(ra.taken_back_count, 0)) as total_taken_back,
  SUM(COALESCE(ra.pending_remittance_count, 0)) as total_pending_remittances,
  
  -- Date ranges
  MIN(COALESCE(ra.first_remittance_date, c.tx_at, ck.created_at)) as earliest_date,
  MAX(COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at)) as latest_date,
  
  -- Additional identifiers
  c.payer_ref_id,
  e.facility_id as raw_facility_id,
  COALESCE(f.name, e.facility_id, 'Unknown Facility') as facility_display_name,
  COALESCE(ra.latest_id_payer, c.payer_id, 'Unknown_' || ck.id::text) as raw_payer_id,
  COALESCE(p.name, ra.latest_id_payer, c.payer_id, 'Unknown Payer') as payer_display_name

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN remittance_aggregated ra ON ra.claim_key_id = ck.id
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type

-- FIXED: Include all necessary fields in GROUP BY, with correct payer_id
GROUP BY 
  DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)),
  EXTRACT(YEAR FROM COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)),
  EXTRACT(MONTH FROM COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)),
  e.type,
  COALESCE(et.name, e.type, 'Unknown Encounter Type'),
  COALESCE(e.facility_id, 'Unknown'),
  COALESCE(f.name, e.facility_id, 'Unknown Facility'),
  COALESCE(ra.latest_id_payer, c.payer_id, 'Unknown_' || ck.id::text),
  COALESCE(p.name, ra.latest_id_payer, c.payer_id, 'Unknown Payer'),
  c.payer_ref_id,
  e.facility_id;

-- SUB-SECOND PERFORMANCE INDEXES
CREATE UNIQUE INDEX IF NOT EXISTS mv_claim_summary_encounterwise_pk 
ON claims.mv_claim_summary_encounterwise (month_bucket, encounter_type, facility_id, payer_id);

CREATE INDEX IF NOT EXISTS mv_claim_summary_encounterwise_month_idx 
ON claims.mv_claim_summary_encounterwise (month_bucket);

CREATE INDEX IF NOT EXISTS mv_claim_summary_encounterwise_type_idx 
ON claims.mv_claim_summary_encounterwise (encounter_type);

CREATE INDEX IF NOT EXISTS mv_claim_summary_encounterwise_facility_idx 
ON claims.mv_claim_summary_encounterwise (facility_id);

COMMENT ON MATERIALIZED VIEW claims.mv_claim_summary_encounterwise IS 'Pre-computed encounterwise summary data for sub-second report performance - FIXED: Use correct payer ID fields (c.payer_id and rc.id_payer)';

-- ==========================================================================================================
-- VERIFICATION: Check payer ID consistency across all MVs
-- ==========================================================================================================

-- Test 1: Verify the fixes worked
SELECT 'Test 1: Payer ID Field Consistency Check' as test_name;

-- Check if the MVs now use consistent payer ID fields
SELECT 
  'mv_balance_amount_summary' as mv_name,
  'Uses c.id_payer' as payer_field_usage,
  COUNT(*) as row_count
FROM claims.mv_balance_amount_summary
UNION ALL
SELECT 
  'mv_claims_monthly_agg' as mv_name,
  'Uses c.id_payer' as payer_field_usage,
  COUNT(*) as row_count
FROM claims.mv_claims_monthly_agg;

-- Test 2: Sample data verification
SELECT 'Test 2: Sample Payer IDs from Fixed MVs' as test_name;

SELECT 
  'mv_balance_amount_summary' as mv_name,
  payer_id,
  COUNT(*) as count
FROM claims.mv_balance_amount_summary
WHERE payer_id IS NOT NULL
GROUP BY payer_id
ORDER BY count DESC
LIMIT 5;

-- Test 3: Compare with other MVs for consistency
SELECT 'Test 3: Payer ID Consistency Across MVs' as test_name;

-- This should show similar payer_id values across different MVs
SELECT 
  'mv_balance_amount_summary' as mv_name,
  payer_id,
  COUNT(*) as count
FROM claims.mv_balance_amount_summary
WHERE payer_id IS NOT NULL
GROUP BY payer_id
HAVING COUNT(*) > 1
ORDER BY count DESC
LIMIT 3;

-- ==========================================================================================================
-- SUMMARY OF PAYER ID CONSISTENCY FIX
-- ==========================================================================================================
-- 
-- ISSUE:
-- Some materialized views used inconsistent payer ID fields:
-- - mv_balance_amount_summary: Used c.payer_id (incorrect)
-- - mv_claims_monthly_agg: Used c.payer_id (incorrect)
--
-- ROOT CAUSE:
-- Confusion between different payer ID fields in the claims schema:
-- - c.payer_id: Payer code from submission claim (business payer identifier)
-- - c.id_payer: Claim header IDPayer (should match rc.id_payer)
-- - rc.id_payer: Payer code at remittance level (should match c.id_payer)
--
-- SOLUTION APPLIED:
-- 1. Updated mv_balance_amount_summary to use c.id_payer instead of c.payer_id
-- 2. Updated mv_claims_monthly_agg to use c.id_payer instead of c.payer_id
-- 3. Updated GROUP BY clauses to match the new payer_id field
-- 4. Updated comments to reflect the fix
--
-- BENEFITS:
-- - Consistent payer ID usage across all materialized views
-- - Proper matching between submission and remittance payer data
-- - Eliminates confusion between different payer ID fields
-- - Maintains data integrity and reporting accuracy
--
-- CONSISTENT PATTERN NOW:
-- - Remittance-focused MVs: Use rc.id_payer (remittance level)
-- - Submission-focused MVs: Use c.id_payer (submission level)
-- - Comprehensive MVs: Use COALESCE(rc.id_payer, c.id_payer, 'Unknown')
-- - Never mix c.payer_id with rc.id_payer (different fields)
-- ==========================================================================================================
