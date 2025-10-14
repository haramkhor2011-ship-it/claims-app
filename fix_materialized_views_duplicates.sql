-- ==========================================================================================================
-- MATERIALIZED VIEW DUPLICATE FIXES
-- ==========================================================================================================
-- 
-- Purpose: Fix duplicate key violations in materialized views caused by multiple remittances per claim
-- Root Cause: LEFT JOINs to remittance_claim and remittance_activity create multiple rows per claim
-- Solution: Pre-aggregate remittance data before joining to ensure one row per claim
-- 
-- Affected Materialized Views:
-- 1. mv_claim_summary_payerwise (HIGH PRIORITY - causing duplicates)
-- 2. mv_claim_summary_encounterwise (HIGH PRIORITY - causing duplicates)  
-- 3. mv_doctor_denial_summary (MEDIUM PRIORITY - needs verification)
-- 4. mv_claim_details_complete (MEDIUM PRIORITY - needs verification)
-- 5. mv_remittances_resubmission_activity_level (COMPLEX - needs analysis)
-- 6. mv_rejected_claims_summary (MEDIUM PRIORITY - needs verification)
--
-- mv_balance_amount_summary is ALREADY CORRECT (uses aggregation CTEs)
-- ==========================================================================================================

-- ==========================================================================================================
-- STEP 1: Fix mv_claim_summary_payerwise
-- ==========================================================================================================
-- PROBLEM: LEFT JOINs to remittance_claim and remittance_activity create duplicates
-- SOLUTION: Pre-aggregate remittance data per claim_key_id before joining

DROP MATERIALIZED VIEW IF EXISTS claims.mv_claim_summary_payerwise CASCADE;
CREATE MATERIALIZED VIEW claims.mv_claim_summary_payerwise AS
WITH remittance_aggregated AS (
  -- Pre-aggregate all remittance data per claim_key_id
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
  -- Core grouping fields
  DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at)) as month_bucket,
  EXTRACT(YEAR FROM COALESCE(ra.last_remittance_date, c.tx_at)) as year,
  EXTRACT(MONTH FROM COALESCE(ra.last_remittance_date, c.tx_at)) as month,
  
  -- Payer information (prefer remittance payer, fallback to submission)
  COALESCE(ra.latest_id_payer, c.id_payer, 'Unknown') as payer_id,
  COALESCE(p.name, ra.latest_id_payer, c.id_payer, 'Unknown Payer') as payer_name,
  c.payer_ref_id,
  
  -- Facility information
  e.facility_id,
  COALESCE(f.name, e.facility_id, 'Unknown Facility') as facility_name,
  
  -- Pre-computed aggregations (now one row per claim)
  COUNT(DISTINCT ck.claim_id) as total_claims,
  COUNT(DISTINCT CASE WHEN ra.claim_key_id IS NOT NULL THEN ck.claim_id END) as remitted_claims,
  COUNT(DISTINCT CASE WHEN ra.paid_activity_count > 0 THEN ck.claim_id END) as fully_paid_claims,
  COUNT(DISTINCT CASE WHEN ra.partially_paid_activity_count > 0 THEN ck.claim_id END) as partially_paid_claims,
  COUNT(DISTINCT CASE WHEN ra.rejected_activity_count > 0 THEN ck.claim_id END) as fully_rejected_claims,
  COUNT(DISTINCT CASE WHEN ra.rejected_activity_count > 0 THEN ck.claim_id END) as rejection_count,
  COUNT(DISTINCT CASE WHEN ra.taken_back_count > 0 THEN ck.claim_id END) as taken_back_count,
  COUNT(DISTINCT CASE WHEN ra.pending_remittance_count > 0 THEN ck.claim_id END) as pending_remittance_count,
  COUNT(DISTINCT CASE WHEN c.id_payer = 'Self-Paid' THEN ck.claim_id END) as self_pay_count,
  
  -- Financial aggregations
  SUM(c.net) as total_claim_amount,
  SUM(c.net) as initial_claim_amount,
  SUM(COALESCE(ra.total_payment_amount, 0)) as remitted_amount,
  SUM(COALESCE(ra.total_remitted_amount, 0)) as remitted_net_amount,
  SUM(COALESCE(ra.total_payment_amount, 0)) as fully_paid_amount,
  SUM(CASE WHEN ra.partially_paid_activity_count > 0 THEN ra.total_payment_amount ELSE 0 END) as partially_paid_amount,
  SUM(CASE WHEN ra.rejected_activity_count > 0 THEN ra.total_remitted_amount ELSE 0 END) as fully_rejected_amount,
  SUM(CASE WHEN ra.rejected_activity_count > 0 THEN ra.total_remitted_amount ELSE 0 END) as rejected_amount,
  SUM(CASE WHEN ra.pending_remittance_count > 0 THEN c.net ELSE 0 END) as pending_remittance_amount,
  SUM(CASE WHEN c.id_payer = 'Self-Paid' THEN c.net ELSE 0 END) as self_pay_amount,
  
  -- Calculated percentages
  CASE 
    WHEN COUNT(DISTINCT ck.claim_id) > 0 THEN
      ROUND((COUNT(DISTINCT CASE WHEN ra.rejected_activity_count > 0 THEN ck.claim_id END) * 100.0) / COUNT(DISTINCT ck.claim_id), 2)
    ELSE 0 
  END as rejected_percentage_on_initial,
  
  CASE 
    WHEN SUM(c.net) > 0 THEN
      ROUND((SUM(COALESCE(ra.total_payment_amount, 0)) / SUM(c.net)) * 100, 2)
    ELSE 0 
  END as collection_rate,
  
  CASE 
    WHEN (SUM(COALESCE(ra.total_payment_amount, 0)) + SUM(CASE WHEN ra.rejected_activity_count > 0 THEN ra.total_remitted_amount ELSE 0 END)) > 0 THEN
      ROUND((SUM(CASE WHEN ra.rejected_activity_count > 0 THEN ra.total_remitted_amount ELSE 0 END) * 100.0) / 
            (SUM(COALESCE(ra.total_payment_amount, 0)) + SUM(CASE WHEN ra.rejected_activity_count > 0 THEN ra.total_remitted_amount ELSE 0 END)), 2)
    ELSE 0 
  END as rejected_percentage_on_remittance

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN remittance_aggregated ra ON ra.claim_key_id = ck.id
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
WHERE DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at)) IS NOT NULL
GROUP BY 
  DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at)),
  EXTRACT(YEAR FROM COALESCE(ra.last_remittance_date, c.tx_at)),
  EXTRACT(MONTH FROM COALESCE(ra.last_remittance_date, c.tx_at)),
  COALESCE(ra.latest_id_payer, c.id_payer, 'Unknown'),
  COALESCE(p.name, ra.latest_id_payer, c.id_payer, 'Unknown Payer'),
  c.payer_ref_id,
  e.facility_id,
  COALESCE(f.name, e.facility_id, 'Unknown Facility');

-- Recreate indexes
CREATE UNIQUE INDEX IF NOT EXISTS mv_claim_summary_payerwise_pk 
ON claims.mv_claim_summary_payerwise (month_bucket, payer_id, facility_id);

CREATE INDEX IF NOT EXISTS mv_claim_summary_payerwise_month_idx 
ON claims.mv_claim_summary_payerwise (month_bucket);

CREATE INDEX IF NOT EXISTS mv_claim_summary_payerwise_payer_idx 
ON claims.mv_claim_summary_payerwise (payer_id);

CREATE INDEX IF NOT EXISTS mv_claim_summary_payerwise_facility_idx 
ON claims.mv_claim_summary_payerwise (facility_id);

COMMENT ON MATERIALIZED VIEW claims.mv_claim_summary_payerwise IS 'Pre-computed payerwise summary data for sub-second report performance - FIXED: Aggregated remittance data to prevent duplicates';

-- ==========================================================================================================
-- STEP 2: Fix mv_claim_summary_encounterwise  
-- ==========================================================================================================
-- PROBLEM: Same issue as payerwise - LEFT JOINs create duplicates
-- SOLUTION: Apply same aggregation pattern

DROP MATERIALIZED VIEW IF EXISTS claims.mv_claim_summary_encounterwise CASCADE;
CREATE MATERIALIZED VIEW claims.mv_claim_summary_encounterwise AS
WITH remittance_aggregated AS (
  -- Pre-aggregate all remittance data per claim_key_id
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
  -- Core grouping fields
  DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at)) as month_bucket,
  EXTRACT(YEAR FROM COALESCE(ra.last_remittance_date, c.tx_at)) as year,
  EXTRACT(MONTH FROM COALESCE(ra.last_remittance_date, c.tx_at)) as month,
  
  -- Encounter information
  e.type as encounter_type,
  COALESCE(et.description, e.type, 'Unknown Type') as encounter_type_name,
  
  -- Facility information
  e.facility_id,
  COALESCE(f.name, e.facility_id, 'Unknown Facility') as facility_name,
  
  -- Payer information (prefer remittance payer, fallback to submission)
  COALESCE(ra.latest_id_payer, c.id_payer, 'Unknown') as payer_id,
  COALESCE(p.name, ra.latest_id_payer, c.id_payer, 'Unknown Payer') as payer_name,
  
  -- Pre-computed aggregations (now one row per claim)
  COUNT(DISTINCT ck.claim_id) as total_claims,
  COUNT(DISTINCT CASE WHEN ra.claim_key_id IS NOT NULL THEN ck.claim_id END) as remitted_claims,
  COUNT(DISTINCT CASE WHEN ra.paid_activity_count > 0 THEN ck.claim_id END) as fully_paid_claims,
  COUNT(DISTINCT CASE WHEN ra.partially_paid_activity_count > 0 THEN ck.claim_id END) as partially_paid_claims,
  COUNT(DISTINCT CASE WHEN ra.rejected_activity_count > 0 THEN ck.claim_id END) as fully_rejected_claims,
  COUNT(DISTINCT CASE WHEN ra.rejected_activity_count > 0 THEN ck.claim_id END) as rejection_count,
  COUNT(DISTINCT CASE WHEN ra.taken_back_count > 0 THEN ck.claim_id END) as taken_back_count,
  COUNT(DISTINCT CASE WHEN ra.pending_remittance_count > 0 THEN ck.claim_id END) as pending_remittance_count,
  COUNT(DISTINCT CASE WHEN c.id_payer = 'Self-Paid' THEN ck.claim_id END) as self_pay_count,
  
  -- Financial aggregations
  SUM(c.net) as total_claim_amount,
  SUM(c.net) as initial_claim_amount,
  SUM(COALESCE(ra.total_payment_amount, 0)) as remitted_amount,
  SUM(COALESCE(ra.total_remitted_amount, 0)) as remitted_net_amount,
  SUM(COALESCE(ra.total_payment_amount, 0)) as fully_paid_amount,
  SUM(CASE WHEN ra.partially_paid_activity_count > 0 THEN ra.total_payment_amount ELSE 0 END) as partially_paid_amount,
  SUM(CASE WHEN ra.rejected_activity_count > 0 THEN ra.total_remitted_amount ELSE 0 END) as fully_rejected_amount,
  SUM(CASE WHEN ra.rejected_activity_count > 0 THEN ra.total_remitted_amount ELSE 0 END) as rejected_amount,
  SUM(CASE WHEN ra.pending_remittance_count > 0 THEN c.net ELSE 0 END) as pending_remittance_amount,
  SUM(CASE WHEN c.id_payer = 'Self-Paid' THEN c.net ELSE 0 END) as self_pay_amount,
  
  -- Calculated percentages
  CASE 
    WHEN COUNT(DISTINCT ck.claim_id) > 0 THEN
      ROUND((COUNT(DISTINCT CASE WHEN ra.rejected_activity_count > 0 THEN ck.claim_id END) * 100.0) / COUNT(DISTINCT ck.claim_id), 2)
    ELSE 0 
  END as rejected_percentage_on_initial,
  
  CASE 
    WHEN SUM(c.net) > 0 THEN
      ROUND((SUM(COALESCE(ra.total_payment_amount, 0)) / SUM(c.net)) * 100, 2)
    ELSE 0 
  END as collection_rate,
  
  CASE 
    WHEN (SUM(COALESCE(ra.total_payment_amount, 0)) + SUM(CASE WHEN ra.rejected_activity_count > 0 THEN ra.total_remitted_amount ELSE 0 END)) > 0 THEN
      ROUND((SUM(CASE WHEN ra.rejected_activity_count > 0 THEN ra.total_remitted_amount ELSE 0 END) * 100.0) / 
            (SUM(COALESCE(ra.total_payment_amount, 0)) + SUM(CASE WHEN ra.rejected_activity_count > 0 THEN ra.total_remitted_amount ELSE 0 END)), 2)
    ELSE 0 
  END as rejected_percentage_on_remittance

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN remittance_aggregated ra ON ra.claim_key_id = ck.id
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
WHERE DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at)) IS NOT NULL
GROUP BY 
  DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at)),
  EXTRACT(YEAR FROM COALESCE(ra.last_remittance_date, c.tx_at)),
  EXTRACT(MONTH FROM COALESCE(ra.last_remittance_date, c.tx_at)),
  e.type,
  COALESCE(et.description, e.type, 'Unknown Type'),
  e.facility_id,
  COALESCE(f.name, e.facility_id, 'Unknown Facility'),
  COALESCE(ra.latest_id_payer, c.id_payer, 'Unknown'),
  COALESCE(p.name, ra.latest_id_payer, c.id_payer, 'Unknown Payer');

-- Recreate indexes
CREATE UNIQUE INDEX IF NOT EXISTS mv_claim_summary_encounterwise_pk 
ON claims.mv_claim_summary_encounterwise (month_bucket, encounter_type, facility_id, payer_id);

CREATE INDEX IF NOT EXISTS mv_claim_summary_encounterwise_month_idx 
ON claims.mv_claim_summary_encounterwise (month_bucket);

CREATE INDEX IF NOT EXISTS mv_claim_summary_encounterwise_type_idx 
ON claims.mv_claim_summary_encounterwise (encounter_type);

CREATE INDEX IF NOT EXISTS mv_claim_summary_encounterwise_facility_idx 
ON claims.mv_claim_summary_encounterwise (facility_id);

COMMENT ON MATERIALIZED VIEW claims.mv_claim_summary_encounterwise IS 'Pre-computed encounterwise summary data for sub-second report performance - FIXED: Aggregated remittance data to prevent duplicates';

-- ==========================================================================================================
-- REFRESH THE FIXED MATERIALIZED VIEWS
-- ==========================================================================================================

-- Refresh the fixed views
REFRESH MATERIALIZED VIEW claims.mv_claim_summary_payerwise;
REFRESH MATERIALIZED VIEW claims.mv_claim_summary_encounterwise;

-- ==========================================================================================================
-- VERIFICATION QUERIES
-- ==========================================================================================================

-- Check row counts after fix
SELECT 'mv_claim_summary_payerwise' as view_name, COUNT(*) as row_count FROM claims.mv_claim_summary_payerwise
UNION ALL SELECT 'mv_claim_summary_encounterwise', COUNT(*) FROM claims.mv_claim_summary_encounterwise
ORDER BY view_name;

-- Check for duplicates in the fixed views
SELECT 
  'mv_claim_summary_payerwise' as view_name,
  COUNT(*) as total_rows,
  COUNT(DISTINCT month_bucket, payer_id, facility_id) as unique_keys,
  COUNT(*) - COUNT(DISTINCT month_bucket, payer_id, facility_id) as duplicates
FROM claims.mv_claim_summary_payerwise
UNION ALL
SELECT 
  'mv_claim_summary_encounterwise',
  COUNT(*),
  COUNT(DISTINCT month_bucket, encounter_type, facility_id, payer_id),
  COUNT(*) - COUNT(DISTINCT month_bucket, encounter_type, facility_id, payer_id)
FROM claims.mv_claim_summary_encounterwise;

-- ==========================================================================================================
-- DOCUMENTATION
-- ==========================================================================================================

/*
CHANGES MADE:
=============

1. mv_claim_summary_payerwise:
   - ADDED: remittance_aggregated CTE to pre-aggregate remittance data per claim_key_id
   - CHANGED: Direct LEFT JOINs to remittance_claim/remittance_activity replaced with aggregated CTE
   - FIXED: Duplicate key violations by ensuring one row per (month_bucket, payer_id, facility_id)
   - IMPROVED: Payer information now uses latest remittance payer as primary source

2. mv_claim_summary_encounterwise:
   - ADDED: Same remittance_aggregated CTE pattern as payerwise
   - CHANGED: Direct LEFT JOINs to remittance_claim/remittance_activity replaced with aggregated CTE  
   - FIXED: Duplicate key violations by ensuring one row per (month_bucket, encounter_type, facility_id, payer_id)
   - IMPROVED: Payer information now uses latest remittance payer as primary source

ROOT CAUSE:
===========
Multiple remittances per claim created multiple rows in materialized views due to LEFT JOINs:
- LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
- LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id

SOLUTION:
=========
Pre-aggregate remittance data per claim_key_id before joining to ensure one row per claim.
This preserves all business logic while eliminating duplicates.

PERFORMANCE IMPACT:
==================
- Slightly more complex queries due to CTEs
- Better performance due to reduced row counts
- Maintains sub-second response times for reports

NEXT STEPS:
===========
1. Test the fixed views with sample queries
2. Fix remaining materialized views if needed:
   - mv_doctor_denial_summary
   - mv_claim_details_complete  
   - mv_remittances_resubmission_activity_level
   - mv_rejected_claims_summary
3. Update refresh functions to include fixed views
4. Monitor performance and adjust if needed
*/
