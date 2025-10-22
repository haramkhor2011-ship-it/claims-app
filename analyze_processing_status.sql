-- ==========================================================================================================
-- ANALYSIS OF FILES PROCESSING DURING CONSTRAINT ERROR
-- ==========================================================================================================
-- 
-- Purpose: Check which files were processing when constraint error occurred and their final status
--
-- ==========================================================================================================

-- Check if claims from the affected files were actually inserted
-- Files that had constraint errors: OP-JB-CR-NEURON--September-2025(78).xml, (81).xml, (82).xml, (85).xml, etc.

-- 1. Check ingestion files for these specific files
SELECT 'INGESTION FILES STATUS:' as info;
SELECT 
    file_id,
    file_name,
    root_type,
    record_count_declared,
    created_at
FROM claims.ingestion_file 
WHERE file_name LIKE 'OP-JB-CR-NEURON--September-2025%'
ORDER BY created_at;

-- 2. Check if claims from these files were inserted
SELECT 'CLAIMS INSERTED FROM AFFECTED FILES:' as info;
SELECT 
    if.file_name,
    COUNT(c.id) as claims_inserted,
    COUNT(DISTINCT c.claim_key_id) as unique_claims
FROM claims.ingestion_file if
LEFT JOIN claims.submission s ON s.ingestion_file_id = if.id
LEFT JOIN claims.claim c ON c.submission_id = s.id
WHERE if.file_name LIKE 'OP-JB-CR-NEURON--September-2025%'
GROUP BY if.file_name, if.id
ORDER BY if.created_at;

-- 3. Check claim events for these files
SELECT 'CLAIM EVENTS FROM AFFECTED FILES:' as info;
SELECT 
    if.file_name,
    COUNT(ce.id) as claim_events_inserted
FROM claims.ingestion_file if
LEFT JOIN claims.submission s ON s.ingestion_file_id = if.id
LEFT JOIN claims.claim c ON c.submission_id = s.id
LEFT JOIN claims.claim_event ce ON ce.claim_key_id = c.claim_key_id
WHERE if.file_name LIKE 'OP-JB-CR-NEURON--September-2025%'
GROUP BY if.file_name, if.id
ORDER BY if.created_at;

-- 4. Check specific claim IDs that had errors
SELECT 'SPECIFIC CLAIMS WITH ERRORS:' as info;
SELECT 
    ck.claim_id,
    c.id as claim_db_id,
    c.created_at,
    CASE 
        WHEN c.id IS NOT NULL THEN 'INSERTED' 
        ELSE 'NOT INSERTED' 
    END as status
FROM (
    SELECT 'DLJOI1021630698' as claim_id
    UNION ALL SELECT 'DLJOI1021630988'
    UNION ALL SELECT 'DLJOI1021629614'
    UNION ALL SELECT 'DLJOI1021629684'
    UNION ALL SELECT 'DLJOI1021630807'
    UNION ALL SELECT 'DLJOI1021630943'
    UNION ALL SELECT 'DLJOI1021629372'
    UNION ALL SELECT 'DLJOI1021629065'
) error_claims
LEFT JOIN claims.claim_key ck ON ck.claim_id = error_claims.claim_id
LEFT JOIN claims.claim c ON c.claim_key_id = ck.id
ORDER BY error_claims.claim_id;

-- 5. Check if any claim events exist for these claims
SELECT 'CLAIM EVENTS FOR ERROR CLAIMS:' as info;
SELECT 
    ck.claim_id,
    COUNT(ce.id) as event_count,
    STRING_AGG(ce.type::text, ', ') as event_types
FROM (
    SELECT 'DLJOI1021630698' as claim_id
    UNION ALL SELECT 'DLJOI1021630988'
    UNION ALL SELECT 'DLJOI1021629614'
    UNION ALL SELECT 'DLJOI1021629684'
    UNION ALL SELECT 'DLJOI1021630807'
    UNION ALL SELECT 'DLJOI1021630943'
    UNION ALL SELECT 'DLJOI1021629372'
    UNION ALL SELECT 'DLJOI1021629065'
) error_claims
LEFT JOIN claims.claim_key ck ON ck.claim_id = error_claims.claim_id
LEFT JOIN claims.claim_event ce ON ce.claim_key_id = ck.id
GROUP BY ck.claim_id, ck.id
ORDER BY error_claims.claim_id;

-- 6. Summary of processing status
SELECT 'PROCESSING SUMMARY:' as info;
SELECT 
    'Total OP-JB-CR-NEURON files processed' as metric,
    COUNT(*) as count
FROM claims.ingestion_file 
WHERE file_name LIKE 'OP-JB-CR-NEURON--September-2025%'

UNION ALL

SELECT 
    'Files with successful submission persisted' as metric,
    COUNT(DISTINCT if.file_name) as count
FROM claims.ingestion_file if
JOIN claims.submission s ON s.ingestion_file_id = if.id
WHERE if.file_name LIKE 'OP-JB-CR-NEURON--September-2025%'

UNION ALL

SELECT 
    'Total claims inserted' as metric,
    COUNT(*) as count
FROM claims.ingestion_file if
JOIN claims.submission s ON s.ingestion_file_id = if.id
JOIN claims.claim c ON c.submission_id = s.id
WHERE if.file_name LIKE 'OP-JB-CR-NEURON--September-2025%';

SELECT 'Analysis complete!' as completion_message;
