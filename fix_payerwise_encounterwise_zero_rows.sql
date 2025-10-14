-- ==========================================================================================================
-- FIX: Zero Rows Issue in mv_claim_summary_payerwise and mv_claim_summary_encounterwise
-- ==========================================================================================================
-- 
-- PROBLEM IDENTIFIED:
-- The WHERE clause "WHERE DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at)) IS NOT NULL"
-- is filtering out all rows because:
-- 1. ra.last_remittance_date is NULL for claims without remittances
-- 2. c.tx_at might be NULL for some claims
-- 3. COALESCE(NULL, NULL) = NULL
-- 4. DATE_TRUNC('month', NULL) = NULL
-- 5. WHERE ... IS NOT NULL filters out all NULL dates
--
-- SOLUTION:
-- Remove the restrictive WHERE clause and handle NULL dates in the GROUP BY and SELECT clauses
-- Use COALESCE with a default date to ensure we always have a valid month bucket
-- ==========================================================================================================

-- Fix for mv_claim_summary_payerwise
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
  
  -- Payer information with fallbacks
  COALESCE(ra.latest_id_payer, c.id_payer, 'Unknown') as payer_id,
  COALESCE(p.name, ra.latest_id_payer, c.id_payer, 'Unknown Payer') as payer_name,
  
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

-- REMOVED: WHERE DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at)) IS NOT NULL
-- This was filtering out all rows where both dates were NULL

GROUP BY 
  DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)),
  EXTRACT(YEAR FROM COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)),
  EXTRACT(MONTH FROM COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)),
  COALESCE(ra.latest_id_payer, c.id_payer, 'Unknown'),
  COALESCE(p.name, ra.latest_id_payer, c.id_payer, 'Unknown Payer'),
  COALESCE(e.facility_id, 'Unknown'),
  COALESCE(f.name, e.facility_id, 'Unknown Facility'),
  c.payer_ref_id,
  e.facility_id,
  COALESCE(f.name, e.facility_id, 'Unknown Facility');

-- SUB-SECOND PERFORMANCE INDEXES
CREATE UNIQUE INDEX IF NOT EXISTS mv_claim_summary_payerwise_pk 
ON claims.mv_claim_summary_payerwise (month_bucket, payer_id, facility_id);

CREATE INDEX IF NOT EXISTS mv_claim_summary_payerwise_month_idx 
ON claims.mv_claim_summary_payerwise (month_bucket);

CREATE INDEX IF NOT EXISTS mv_claim_summary_payerwise_payer_idx 
ON claims.mv_claim_summary_payerwise (payer_id);

CREATE INDEX IF NOT EXISTS mv_claim_summary_payerwise_facility_idx 
ON claims.mv_claim_summary_payerwise (facility_id);

COMMENT ON MATERIALIZED VIEW claims.mv_claim_summary_payerwise IS 'Pre-computed payerwise summary data for sub-second report performance - FIXED: Removed restrictive WHERE clause to handle claims at all lifecycle stages';

-- ==========================================================================================================

-- Fix for mv_claim_summary_encounterwise
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
  
  -- Payer information with fallbacks
  COALESCE(ra.latest_id_payer, c.id_payer, 'Unknown') as payer_id,
  COALESCE(p.name, ra.latest_id_payer, c.id_payer, 'Unknown Payer') as payer_name,
  
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
  COALESCE(ra.latest_id_payer, c.id_payer, 'Unknown') as raw_payer_id,
  COALESCE(p.name, ra.latest_id_payer, c.id_payer, 'Unknown Payer') as payer_display_name

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN remittance_aggregated ra ON ra.claim_key_id = ck.id
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type

-- REMOVED: WHERE DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at)) IS NOT NULL
-- This was filtering out all rows where both dates were NULL

GROUP BY 
  DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)),
  EXTRACT(YEAR FROM COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)),
  EXTRACT(MONTH FROM COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)),
  e.type,
  COALESCE(et.name, e.type, 'Unknown Encounter Type'),
  COALESCE(e.facility_id, 'Unknown'),
  COALESCE(f.name, e.facility_id, 'Unknown Facility'),
  COALESCE(ra.latest_id_payer, c.id_payer, 'Unknown'),
  COALESCE(p.name, ra.latest_id_payer, c.id_payer, 'Unknown Payer'),
  c.payer_ref_id,
  e.facility_id,
  COALESCE(f.name, e.facility_id, 'Unknown Facility'),
  COALESCE(ra.latest_id_payer, c.id_payer, 'Unknown'),
  COALESCE(p.name, ra.latest_id_payer, c.id_payer, 'Unknown Payer');

-- SUB-SECOND PERFORMANCE INDEXES
CREATE UNIQUE INDEX IF NOT EXISTS mv_claim_summary_encounterwise_pk 
ON claims.mv_claim_summary_encounterwise (month_bucket, encounter_type, facility_id, payer_id);

CREATE INDEX IF NOT EXISTS mv_claim_summary_encounterwise_month_idx 
ON claims.mv_claim_summary_encounterwise (month_bucket);

CREATE INDEX IF NOT EXISTS mv_claim_summary_encounterwise_type_idx 
ON claims.mv_claim_summary_encounterwise (encounter_type);

CREATE INDEX IF NOT EXISTS mv_claim_summary_encounterwise_facility_idx 
ON claims.mv_claim_summary_encounterwise (facility_id);

COMMENT ON MATERIALIZED VIEW claims.mv_claim_summary_encounterwise IS 'Pre-computed encounterwise summary data for sub-second report performance - FIXED: Removed restrictive WHERE clause to handle claims at all lifecycle stages';

-- ==========================================================================================================
-- TEST THE FIX
-- ==========================================================================================================

-- Test 1: Check if MVs now have data
SELECT 'Test 1: MV Row Counts' as test_name;
SELECT 
  'mv_claim_summary_payerwise' as mv_name,
  COUNT(*) as row_count
FROM claims.mv_claim_summary_payerwise
UNION ALL
SELECT 
  'mv_claim_summary_encounterwise' as mv_name,
  COUNT(*) as row_count
FROM claims.mv_claim_summary_encounterwise;

-- Test 2: Check sample data
SELECT 'Test 2: Sample Data from Payerwise MV' as test_name;
SELECT 
  month_bucket,
  payer_id,
  facility_id,
  total_claims,
  claims_with_remittances,
  claims_without_remittances,
  total_claim_amount
FROM claims.mv_claim_summary_payerwise
ORDER BY month_bucket DESC
LIMIT 5;

-- Test 3: Check sample data from encounterwise
SELECT 'Test 3: Sample Data from Encounterwise MV' as test_name;
SELECT 
  month_bucket,
  encounter_type,
  facility_id,
  payer_id,
  total_claims,
  claims_with_remittances,
  claims_without_remittances,
  total_claim_amount
FROM claims.mv_claim_summary_encounterwise
ORDER BY month_bucket DESC
LIMIT 5;

-- ==========================================================================================================
-- EXPLANATION OF THE FIX
-- ==========================================================================================================
-- 
-- WHY WE GOT ZERO ROWS:
-- The original WHERE clause "WHERE DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at)) IS NOT NULL"
-- was filtering out all rows because:
-- 1. For claims without remittances: ra.last_remittance_date = NULL
-- 2. For claims with NULL tx_at: c.tx_at = NULL  
-- 3. COALESCE(NULL, NULL) = NULL
-- 4. DATE_TRUNC('month', NULL) = NULL
-- 5. WHERE ... IS NOT NULL filtered out all NULL results
--
-- WHAT WE GOT:
-- Zero rows in both MVs because the WHERE clause was too restrictive
--
-- WHAT IS EXPECTED:
-- Both MVs should now return data for all claims, regardless of their lifecycle stage:
-- - Claims with remittances (using ra.last_remittance_date)
-- - Claims without remittances but with tx_at (using c.tx_at)
-- - Claims without remittances and NULL tx_at (using ck.created_at as fallback)
-- - Claims with all NULL dates (using CURRENT_DATE as final fallback)
--
-- The fix ensures that every claim gets a valid month_bucket for grouping,
-- allowing the MVs to provide comprehensive reporting across all claim stages.
-- ==========================================================================================================
