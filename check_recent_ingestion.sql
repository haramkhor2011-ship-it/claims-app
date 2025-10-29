-- Simple diagnostic to check the verification issue
-- Run this to see what's happening with the verification

-- Check recent ingestion files and their claim_events
SELECT 
    if.id as ingestion_file_id,
    if.file_name,
    if.created_at as file_created_at,
    COUNT(DISTINCT s.id) as submission_count,
    COUNT(DISTINCT c.id) as claim_count,
    COUNT(DISTINCT ce.id) as event_count
FROM claims.ingestion_file if
LEFT JOIN claims.submission s ON if.id = s.ingestion_file_id
LEFT JOIN claims.claim c ON s.id = c.submission_id
LEFT JOIN claims.claim_event ce ON c.claim_key_id = ce.claim_key_id
WHERE if.created_at > NOW() - INTERVAL '1 hour'
GROUP BY if.id, if.file_name, if.created_at
ORDER BY if.created_at DESC
LIMIT 10;

-- Check if there are any claim_events created in the last hour
SELECT 
    'RECENT_CLAIM_EVENTS' as info_type,
    COUNT(*) as count,
    MIN(created_at) as earliest,
    MAX(created_at) as latest
FROM claims.claim_event 
WHERE created_at > NOW() - INTERVAL '1 hour';

-- Check if there are any claims created in the last hour
SELECT 
    'RECENT_CLAIMS' as info_type,
    COUNT(*) as count,
    MIN(created_at) as earliest,
    MAX(created_at) as latest
FROM claims.claim 
WHERE created_at > NOW() - INTERVAL '1 hour';

-- Check if there are any submissions created in the last hour
SELECT 
    'RECENT_SUBMISSIONS' as info_type,
    COUNT(*) as count,
    MIN(created_at) as earliest,
    MAX(created_at) as latest
FROM claims.submission 
WHERE created_at > NOW() - INTERVAL '1 hour';
