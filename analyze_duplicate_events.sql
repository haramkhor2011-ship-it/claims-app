-- Analysis query to understand the issue
-- Check if there are multiple claim_event records for the same claim_key_id

SELECT 
    ce.id,
    ce.claim_key_id,
    ce.type,
    ce.ingestion_file_id,
    ce.event_time,
    ifa.file_name,
    ck.claim_id
FROM claims.claim_event ce
JOIN claims.claim_key ck ON ce.claim_key_id = ck.id
LEFT JOIN claims.ingestion_file_audit ifa ON ce.ingestion_file_id = ifa.ingestion_file_id
WHERE ck.claim_id = 'DLJOI1021622192'
ORDER BY ce.event_time;

-- Check if there are multiple submission events for the same claim
SELECT 
    claim_key_id,
    COUNT(*) as event_count,
    STRING_AGG(CAST(id AS TEXT), ', ') as event_ids,
    STRING_AGG(CAST(ingestion_file_id AS TEXT), ', ') as file_ids
FROM claims.claim_event 
WHERE type = 1
GROUP BY claim_key_id
HAVING COUNT(*) > 1
ORDER BY event_count DESC
LIMIT 10;
