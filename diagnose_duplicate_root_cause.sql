-- ==========================================================================================================
-- DIAGNOSE: Root Cause of Duplicate Key Violations
-- ==========================================================================================================
-- 
-- Purpose: Identify the exact source of duplicates in the materialized views
-- ==========================================================================================================

-- ==========================================================================================================
-- DIAGNOSTIC 1: Check for NULL dates and date fallback behavior
-- ==========================================================================================================
SELECT 'DIAGNOSTIC 1: Date Analysis' as diagnostic_name;

-- Check claims with NULL dates
SELECT 
  'Claims with NULL tx_at' as category,
  COUNT(*) as count
FROM claims.claim c
WHERE c.tx_at IS NULL

UNION ALL

SELECT 
  'Claims with NULL created_at' as category,
  COUNT(*) as count
FROM claims.claim_key ck
WHERE ck.created_at IS NULL

UNION ALL

SELECT 
  'Claims with both NULL tx_at and created_at' as category,
  COUNT(*) as count
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
WHERE c.tx_at IS NULL AND ck.created_at IS NULL;

-- ==========================================================================================================
-- DIAGNOSTIC 2: Check the date fallback logic in detail
-- ==========================================================================================================
SELECT 'DIAGNOSTIC 2: Date Fallback Analysis' as diagnostic_name;

WITH date_analysis AS (
  SELECT 
    ck.id as claim_key_id,
    ck.claim_id,
    ra.last_remittance_date,
    c.tx_at,
    ck.created_at,
    CURRENT_DATE as current_date_fallback,
    -- Test the COALESCE logic
    COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE) as final_date,
    DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)) as month_bucket
  FROM claims.claim_key ck
  JOIN claims.claim c ON c.claim_key_id = ck.id
  LEFT JOIN (
    SELECT 
      rc.claim_key_id,
      MAX(rc.date_settlement) as last_remittance_date
    FROM claims.remittance_claim rc
    GROUP BY rc.claim_key_id
  ) ra ON ra.claim_key_id = ck.id
  LIMIT 100
)
SELECT 
  'Date Fallback Distribution' as analysis,
  CASE 
    WHEN last_remittance_date IS NOT NULL THEN 'Has Remittance Date'
    WHEN tx_at IS NOT NULL THEN 'Has Transaction Date'
    WHEN created_at IS NOT NULL THEN 'Has Created Date'
    ELSE 'Using CURRENT_DATE Fallback'
  END as date_source,
  COUNT(*) as count,
  MIN(final_date) as min_date,
  MAX(final_date) as max_date
FROM date_analysis
GROUP BY 
  CASE 
    WHEN last_remittance_date IS NOT NULL THEN 'Has Remittance Date'
    WHEN tx_at IS NOT NULL THEN 'Has Transaction Date'
    WHEN created_at IS NOT NULL THEN 'Has Created Date'
    ELSE 'Using CURRENT_DATE Fallback'
  END;

-- ==========================================================================================================
-- DIAGNOSTIC 3: Check for duplicates in the base data
-- ==========================================================================================================
SELECT 'DIAGNOSTIC 3: Base Data Duplicate Analysis' as diagnostic_name;

-- Check for duplicate claim_key_id in encounters
SELECT 
  'Duplicate Encounters per Claim' as category,
  COUNT(*) as duplicate_count
FROM (
  SELECT 
    c.id as claim_id,
    COUNT(*) as encounter_count
  FROM claims.claim c
  JOIN claims.encounter e ON e.claim_id = c.id
  GROUP BY c.id
  HAVING COUNT(*) > 1
) duplicates;

-- Check for multiple facilities per claim
SELECT 
  'Claims with Multiple Facilities' as category,
  COUNT(*) as duplicate_count
FROM (
  SELECT 
    c.id as claim_id,
    COUNT(DISTINCT e.facility_id) as facility_count
  FROM claims.claim c
  JOIN claims.encounter e ON e.claim_id = c.id
  GROUP BY c.id
  HAVING COUNT(DISTINCT e.facility_id) > 1
) duplicates;

-- ==========================================================================================================
-- DIAGNOSTIC 4: Check the exact duplicate combinations
-- ==========================================================================================================
SELECT 'DIAGNOSTIC 4: Exact Duplicate Analysis' as diagnostic_name;

-- Analyze the exact duplicate combinations in payerwise MV
WITH payerwise_analysis AS (
  SELECT 
    DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)) as month_bucket,
    COALESCE(ra.latest_id_payer, c.id_payer, 'Unknown') as payer_id,
    COALESCE(e.facility_id, 'Unknown') as facility_id,
    COUNT(*) as row_count
  FROM claims.claim_key ck
  JOIN claims.claim c ON c.claim_key_id = ck.id
  LEFT JOIN claims.encounter e ON e.claim_id = c.id
  LEFT JOIN (
    SELECT 
      rc.claim_key_id,
      (ARRAY_AGG(rc.id_payer ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_id_payer,
      MAX(rc.date_settlement) as last_remittance_date
    FROM claims.remittance_claim rc
    GROUP BY rc.claim_key_id
  ) ra ON ra.claim_key_id = ck.id
  GROUP BY 
    DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE)),
    COALESCE(ra.latest_id_payer, c.id_payer, 'Unknown'),
    COALESCE(e.facility_id, 'Unknown')
  HAVING COUNT(*) > 1
)
SELECT 
  'Payerwise Duplicate Details' as analysis,
  month_bucket,
  payer_id,
  facility_id,
  row_count
FROM payerwise_analysis
ORDER BY row_count DESC
LIMIT 10;

-- ==========================================================================================================
-- DIAGNOSTIC 5: Check for NULL facility_id causing duplicates
-- ==========================================================================================================
SELECT 'DIAGNOSTIC 5: NULL Facility Analysis' as diagnostic_name;

SELECT 
  'Facility ID Distribution' as category,
  CASE 
    WHEN e.facility_id IS NULL THEN 'NULL facility_id'
    WHEN e.facility_id = '' THEN 'Empty facility_id'
    ELSE 'Valid facility_id'
  END as facility_status,
  COUNT(*) as count
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
GROUP BY 
  CASE 
    WHEN e.facility_id IS NULL THEN 'NULL facility_id'
    WHEN e.facility_id = '' THEN 'Empty facility_id'
    ELSE 'Valid facility_id'
  END;

-- ==========================================================================================================
-- DIAGNOSTIC 6: Check for NULL payer_id causing duplicates
-- ==========================================================================================================
SELECT 'DIAGNOSTIC 6: NULL Payer Analysis' as diagnostic_name;

SELECT 
  'Payer ID Distribution' as category,
  CASE 
    WHEN c.id_payer IS NULL THEN 'NULL id_payer'
    WHEN c.id_payer = '' THEN 'Empty id_payer'
    ELSE 'Valid id_payer'
  END as payer_status,
  COUNT(*) as count
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
GROUP BY 
  CASE 
    WHEN c.id_payer IS NULL THEN 'NULL id_payer'
    WHEN c.id_payer = '' THEN 'Empty id_payer'
    ELSE 'Valid id_payer'
  END;

-- ==========================================================================================================
-- DIAGNOSTIC 7: Check the remittance aggregation logic
-- ==========================================================================================================
SELECT 'DIAGNOSTIC 7: Remittance Aggregation Analysis' as diagnostic_name;

-- Check if remittance_aggregated CTE is working correctly
WITH remittance_aggregated AS (
  SELECT 
    rc.claim_key_id,
    COUNT(*) as remittance_count,
    (ARRAY_AGG(rc.id_payer ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_id_payer,
    MAX(rc.date_settlement) as last_remittance_date
  FROM claims.remittance_claim rc
  GROUP BY rc.claim_key_id
)
SELECT 
  'Remittance Aggregation' as category,
  COUNT(*) as total_claim_keys,
  COUNT(CASE WHEN latest_id_payer IS NULL THEN 1 END) as null_payer_count,
  COUNT(CASE WHEN last_remittance_date IS NULL THEN 1 END) as null_date_count
FROM remittance_aggregated;

-- ==========================================================================================================
-- RECOMMENDATIONS BASED ON DIAGNOSTICS
-- ==========================================================================================================
SELECT 'RECOMMENDATIONS' as section;

SELECT 
  'Based on the diagnostics above, the likely causes are:' as recommendation,
  '1. NULL facility_id or payer_id causing multiple rows to have same key' as cause1,
  '2. CURRENT_DATE fallback creating future dates' as cause2,
  '3. Multiple encounters per claim with different facility_ids' as cause3,
  '4. Remittance aggregation not handling NULL values properly' as cause4;
