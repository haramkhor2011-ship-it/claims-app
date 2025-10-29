-- Comprehensive diagnostic for verification issue
-- Check what's happening with ingestion_file_id = 31269 (OP-JB-CS-NEXTCARE--October-2025(13).xml)

-- 1. Check if ingestion_file exists
SELECT 
    'INGESTION_FILE_CHECK' as check_type,
    id,
    file_name,
    created_at,
    CASE 
        WHEN COUNT(*) > 0 THEN 'EXISTS'
        ELSE 'NOT_FOUND'
    END as status
FROM claims.ingestion_file 
WHERE id = 31269
GROUP BY id, file_name, created_at;

-- 2. Check if submission exists
SELECT 
    'SUBMISSION_CHECK' as check_type,
    id as submission_id,
    ingestion_file_id,
    created_at,
    CASE 
        WHEN COUNT(*) > 0 THEN 'EXISTS'
        ELSE 'NOT_FOUND'
    END as status
FROM claims.submission 
WHERE ingestion_file_id = 31269
GROUP BY id, ingestion_file_id, created_at;

-- 3. Check if claims exist
SELECT 
    'CLAIMS_CHECK' as check_type,
    COUNT(*) as claim_count,
    MIN(created_at) as earliest_claim,
    MAX(created_at) as latest_claim,
    CASE 
        WHEN COUNT(*) > 0 THEN 'EXISTS'
        ELSE 'NOT_FOUND'
    END as status
FROM claims.claim c
JOIN claims.submission s ON c.submission_id = s.id
WHERE s.ingestion_file_id = 31269;

-- 4. Check if claim_events exist (the verification query)
SELECT 
    'CLAIM_EVENTS_CHECK' as check_type,
    COUNT(*) as event_count,
    MIN(created_at) as earliest_event,
    MAX(created_at) as latest_event,
    CASE 
        WHEN COUNT(*) > 0 THEN 'EXISTS'
        ELSE 'NOT_FOUND'
    END as status
FROM claims.claim_event ce 
JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id 
JOIN claims.submission s ON c.submission_id = s.id 
WHERE s.ingestion_file_id = 31269;

-- 5. Check if claim_events exist directly by ingestion_file_id
SELECT 
    'CLAIM_EVENTS_BY_FILE_ID_CHECK' as check_type,
    COUNT(*) as event_count,
    MIN(created_at) as earliest_event,
    MAX(created_at) as latest_event,
    CASE 
        WHEN COUNT(*) > 0 THEN 'EXISTS'
        ELSE 'NOT_FOUND'
    END as status
FROM claims.claim_event 
WHERE ingestion_file_id = 31269;

-- 6. Check for any claim_events for the claims in this file
SELECT 
    'CLAIM_EVENTS_FOR_CLAIMS_CHECK' as check_type,
    COUNT(*) as event_count,
    MIN(created_at) as earliest_event,
    MAX(created_at) as latest_event,
    CASE 
        WHEN COUNT(*) > 0 THEN 'EXISTS'
        ELSE 'NOT_FOUND'
    END as status
FROM claims.claim_event ce
WHERE ce.claim_key_id IN (
    SELECT c.claim_key_id 
    FROM claims.claim c
    JOIN claims.submission s ON c.submission_id = s.id
    WHERE s.ingestion_file_id = 31269
);

-- 7. Show sample claim_key_ids for this file
SELECT 
    'SAMPLE_CLAIM_KEY_IDS' as info_type,
    c.claim_key_id,
    c.id as claim_id,
    c.claim_id as business_claim_id,
    c.created_at
FROM claims.claim c
JOIN claims.submission s ON c.submission_id = s.id
WHERE s.ingestion_file_id = 31269
ORDER BY c.created_at DESC
LIMIT 5;

-- 8. Show sample claim_events for these claim_key_ids
SELECT 
    'SAMPLE_CLAIM_EVENTS' as info_type,
    ce.id as event_id,
    ce.claim_key_id,
    ce.type,
    ce.event_time,
    ce.ingestion_file_id,
    ce.created_at
FROM claims.claim_event ce
WHERE ce.claim_key_id IN (
    SELECT c.claim_key_id 
    FROM claims.claim c
    JOIN claims.submission s ON c.submission_id = s.id
    WHERE s.ingestion_file_id = 31269
)
ORDER BY ce.created_at DESC
LIMIT 5;

-- 9. Check if there are any recent claim_events at all
SELECT 
    'RECENT_CLAIM_EVENTS_CHECK' as check_type,
    COUNT(*) as event_count,
    MIN(created_at) as earliest_event,
    MAX(created_at) as latest_event
FROM claims.claim_event 
WHERE created_at > NOW() - INTERVAL '10 minutes';

-- 10. Check if there are any recent claims at all
SELECT 
    'RECENT_CLAIMS_CHECK' as check_type,
    COUNT(*) as claim_count,
    MIN(created_at) as earliest_claim,
    MAX(created_at) as latest_claim
FROM claims.claim 
WHERE created_at > NOW() - INTERVAL '10 minutes';
