-- Quick diagnostic to check remittance data before cleanup
-- Run this first to understand what remittance data exists

SELECT '=== REMITTANCE DATA ANALYSIS ===' as section;

-- Check remittance counts
SELECT 
    'TOTAL_REMITTANCES' as table_name,
    COUNT(*) as count
FROM claims.remittance
UNION ALL
SELECT 
    'TOTAL_REMITTANCE_CLAIMS' as table_name,
    COUNT(*) as count
FROM claims.remittance_claim;

-- Check for orphaned remittance_claims (remittance claims without submission claims)
SELECT 
    'ORPHANED_REMITTANCE_CLAIMS' as issue_type,
    COUNT(*) as count,
    'Remittance claims without corresponding submission claims' as description
FROM claims.remittance_claim rc
LEFT JOIN claims.claim c ON rc.claim_key_id = c.claim_key_id
WHERE c.id IS NULL;

-- Check for orphaned remittances (remittances without claims)
SELECT 
    'ORPHANED_REMITTANCES' as issue_type,
    COUNT(*) as count,
    'Remittances without any claims' as description
FROM claims.remittance r
LEFT JOIN claims.remittance_claim rc ON r.id = rc.remittance_id
WHERE rc.id IS NULL;

-- Check for claim_keys referenced by remittance_claims but not by submission claims
SELECT 
    'CLAIM_KEYS_REFERENCED_BY_REMITTANCE_ONLY' as issue_type,
    COUNT(*) as count,
    'Claim keys only referenced by remittance claims' as description
FROM claims.claim_key ck
LEFT JOIN claims.claim c ON ck.id = c.claim_key_id
LEFT JOIN claims.remittance_claim rc ON ck.id = rc.claim_key_id
WHERE c.id IS NULL AND rc.id IS NOT NULL;

-- Sample of problematic claim_keys
SELECT 
    'SAMPLE_PROBLEMATIC_CLAIM_KEYS' as section,
    ck.id as claim_key_id,
    ck.claim_id as business_claim_id,
    CASE WHEN c.id IS NOT NULL THEN 'HAS_SUBMISSION_CLAIM' ELSE 'NO_SUBMISSION_CLAIM' END as submission_status,
    CASE WHEN rc.id IS NOT NULL THEN 'HAS_REMITTANCE_CLAIM' ELSE 'NO_REMITTANCE_CLAIM' END as remittance_status
FROM claims.claim_key ck
LEFT JOIN claims.claim c ON ck.id = c.claim_key_id
LEFT JOIN claims.remittance_claim rc ON ck.id = rc.claim_key_id
WHERE c.id IS NULL AND rc.id IS NOT NULL
LIMIT 10;
