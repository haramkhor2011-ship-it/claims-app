-- ==========================================================================================================
-- DIAGNOSTIC QUERY FOR DIAGNOSIS DUPLICATES
-- ==========================================================================================================
-- 
-- Purpose: Identify why diagnosis JOINs are creating duplicates
-- Target: Key (claim_key_id, activity_id)=(5336, 200110011) is duplicated
-- ==========================================================================================================

-- Check the specific claim and its diagnoses
SELECT 
    'Diagnosis Details' as check_type,
    c.claim_key_id,
    c.id as claim_id,
    d.id as diagnosis_id,
    d.diag_type,
    d.code,
    COUNT(*) as diagnosis_count
FROM claims.claim c
JOIN claims.diagnosis d ON c.id = d.claim_id
WHERE c.claim_key_id = 5336
GROUP BY c.claim_key_id, c.id, d.id, d.diag_type, d.code
ORDER BY d.diag_type, d.code;

-- Check how many rows the diagnosis JOINs create
SELECT 
    'Diagnosis JOIN Impact' as check_type,
    c.claim_key_id,
    c.id as claim_id,
    a.activity_id,
    COUNT(*) as rows_created
FROM claims.claim_key ck
JOIN claims.claim c ON ck.id = c.claim_key_id
JOIN claims.activity a ON c.id = a.claim_id
LEFT JOIN claims.diagnosis d1 ON c.id = d1.claim_id AND d1.diag_type = 'Principal'
LEFT JOIN claims.diagnosis d2 ON c.id = d2.claim_id AND d2.diag_type = 'Secondary'
WHERE ck.id = 5336 AND a.activity_id = '200110011'
GROUP BY c.claim_key_id, c.id, a.activity_id;

-- Check the exact problem: multiple secondary diagnoses
SELECT 
    'Secondary Diagnosis Count' as check_type,
    c.claim_key_id,
    c.id as claim_id,
    COUNT(*) as secondary_diagnosis_count
FROM claims.claim c
JOIN claims.diagnosis d ON c.id = d.claim_id
WHERE c.claim_key_id = 5336 AND d.diag_type = 'Secondary'
GROUP BY c.claim_key_id, c.id;

-- Test the problematic JOIN pattern
SELECT 
    'Problematic JOIN Test' as check_type,
    ck.id as claim_key_id,
    a.activity_id,
    d1.code as primary_diagnosis,
    d2.code as secondary_diagnosis,
    COUNT(*) as row_count
FROM claims.claim_key ck
JOIN claims.claim c ON ck.id = c.claim_key_id
JOIN claims.activity a ON c.id = a.claim_id
LEFT JOIN claims.diagnosis d1 ON c.id = d1.claim_id AND d1.diag_type = 'Principal'
LEFT JOIN claims.diagnosis d2 ON c.id = d2.claim_id AND d2.diag_type = 'Secondary'
WHERE ck.id = 5336 AND a.activity_id = '200110011'
GROUP BY ck.id, a.activity_id, d1.code, d2.code
ORDER BY row_count DESC;

-- Check if there are multiple primary diagnoses (should be 1)
SELECT 
    'Primary Diagnosis Check' as check_type,
    c.claim_key_id,
    c.id as claim_id,
    COUNT(*) as primary_diagnosis_count
FROM claims.claim c
JOIN claims.diagnosis d ON c.id = d.claim_id
WHERE c.claim_key_id = 5336 AND d.diag_type = 'Principal'
GROUP BY c.claim_key_id, c.id;

-- The root cause: LEFT JOIN to diagnosis creates Cartesian product
-- When there are multiple secondary diagnoses, each one creates a separate row
-- This is why we get 10 rows for the same (claim_key_id, activity_id) combination
