-- ==========================================================================================================
-- CHECK: NULL values in c.payer_id vs c.id_payer
-- ==========================================================================================================
-- 
-- Purpose: Check if c.payer_id has NULL values that could cause duplicate key violations
-- ==========================================================================================================

-- Check NULL distribution in both payer fields
SELECT 'Payer ID Field Analysis' as analysis_name;

SELECT 
  'c.payer_id NULL count' as field_name,
  COUNT(*) as total_claims,
  COUNT(CASE WHEN c.payer_id IS NULL THEN 1 END) as null_count,
  COUNT(CASE WHEN c.payer_id IS NOT NULL THEN 1 END) as not_null_count,
  ROUND(COUNT(CASE WHEN c.payer_id IS NULL THEN 1 END) * 100.0 / COUNT(*), 2) as null_percentage
FROM claims.claim c

UNION ALL

SELECT 
  'c.id_payer NULL count' as field_name,
  COUNT(*) as total_claims,
  COUNT(CASE WHEN c.id_payer IS NULL THEN 1 END) as null_count,
  COUNT(CASE WHEN c.id_payer IS NOT NULL THEN 1 END) as not_null_count,
  ROUND(COUNT(CASE WHEN c.id_payer IS NULL THEN 1 END) * 100.0 / COUNT(*), 2) as null_percentage
FROM claims.claim c;

-- Check if both fields are NULL for the same claims
SELECT 'Claims with both payer fields NULL' as analysis_name;

SELECT 
  COUNT(*) as total_claims,
  COUNT(CASE WHEN c.payer_id IS NULL AND c.id_payer IS NULL THEN 1 END) as both_null,
  COUNT(CASE WHEN c.payer_id IS NULL AND c.id_payer IS NOT NULL THEN 1 END) as payer_id_null_only,
  COUNT(CASE WHEN c.payer_id IS NOT NULL AND c.id_payer IS NULL THEN 1 END) as id_payer_null_only,
  COUNT(CASE WHEN c.payer_id IS NOT NULL AND c.id_payer IS NOT NULL THEN 1 END) as both_not_null
FROM claims.claim c;

-- Check value differences between the two fields
SELECT 'Payer Field Value Comparison' as analysis_name;

SELECT 
  CASE 
    WHEN c.payer_id = c.id_payer THEN 'Same Values'
    WHEN c.payer_id IS NULL AND c.id_payer IS NULL THEN 'Both NULL'
    WHEN c.payer_id IS NULL THEN 'payer_id NULL, id_payer has value'
    WHEN c.id_payer IS NULL THEN 'id_payer NULL, payer_id has value'
    ELSE 'Different Values'
  END as comparison_result,
  COUNT(*) as count
FROM claims.claim c
GROUP BY 
  CASE 
    WHEN c.payer_id = c.id_payer THEN 'Same Values'
    WHEN c.payer_id IS NULL AND c.id_payer IS NULL THEN 'Both NULL'
    WHEN c.payer_id IS NULL THEN 'payer_id NULL, id_payer has value'
    WHEN c.id_payer IS NULL THEN 'id_payer NULL, payer_id has value'
    ELSE 'Different Values'
  END
ORDER BY count DESC;

-- Sample of different values
SELECT 'Sample of Different Payer Values' as analysis_name;

SELECT 
  c.payer_id,
  c.id_payer,
  COUNT(*) as count
FROM claims.claim c
WHERE c.payer_id IS NOT NULL 
  AND c.id_payer IS NOT NULL 
  AND c.payer_id != c.id_payer
GROUP BY c.payer_id, c.id_payer
ORDER BY count DESC
LIMIT 10;

-- Check if c.payer_id has the same NULL problem as c.id_payer
SELECT 'Potential Duplicate Key Violation Check' as analysis_name;

WITH payer_id_analysis AS (
  SELECT 
    DATE_TRUNC('month', COALESCE(c.tx_at, ck.created_at, CURRENT_DATE)) as month_bucket,
    COALESCE(c.payer_id, 'Unknown') as payer_id,
    COALESCE(e.facility_id, 'Unknown') as facility_id,
    COUNT(*) as row_count
  FROM claims.claim_key ck
  JOIN claims.claim c ON c.claim_key_id = ck.id
  LEFT JOIN claims.encounter e ON e.claim_id = c.id
  GROUP BY 
    DATE_TRUNC('month', COALESCE(c.tx_at, ck.created_at, CURRENT_DATE)),
    COALESCE(c.payer_id, 'Unknown'),
    COALESCE(e.facility_id, 'Unknown')
  HAVING COUNT(*) > 1
)
SELECT 
  COUNT(*) as potential_duplicate_combinations,
  SUM(row_count) as total_duplicate_rows
FROM payer_id_analysis;

