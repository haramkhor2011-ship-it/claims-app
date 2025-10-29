-- Diagnostic query to check verification issue
-- Check what's happening with ingestion_file_id = 31325 (OP-JB-CS-SAICO--October-2025(3).xml)

-- 1. Check if ingestion_file exists
SELECT 
    'INGESTION_FILE_EXISTS' as check_type,
    CASE 
        WHEN COUNT(*) > 0 THEN 'YES'
        ELSE 'NO'
    END as result,
    COUNT(*) as count
FROM claims.ingestion_file 
WHERE id = 31325;

-- 2. Check if submission exists
SELECT 
    'SUBMISSION_EXISTS' as check_type,
    CASE 
        WHEN COUNT(*) > 0 THEN 'YES'
        ELSE 'NO'
    END as result,
    COUNT(*) as count
FROM claims.submission 
WHERE ingestion_file_id = 31325;

-- 3. Check if claims exist
SELECT 
    'CLAIMS_EXIST' as check_type,
    CASE 
        WHEN COUNT(*) > 0 THEN 'YES'
        ELSE 'NO'
    END as result,
    COUNT(*) as count
FROM claims.claim c
JOIN claims.submission s ON c.submission_id = s.id
WHERE s.ingestion_file_id = 31325;

-- 4. Check if claim_events exist (the verification query)
SELECT 
    'CLAIM_EVENTS_EXIST' as check_type,
    CASE 
        WHEN COUNT(*) > 0 THEN 'YES'
        ELSE 'NO'
    END as result,
    COUNT(*) as count
FROM claims.claim_event ce 
JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id 
JOIN claims.submission s ON c.submission_id = s.id 
WHERE s.ingestion_file_id = 31325;

-- 5. Check if claim_events exist directly by ingestion_file_id
SELECT 
    'CLAIM_EVENTS_BY_FILE_ID' as check_type,
    CASE 
        WHEN COUNT(*) > 0 THEN 'YES'
        ELSE 'NO'
    END as result,
    COUNT(*) as count
FROM claims.claim_event 
WHERE ingestion_file_id = 31325;

-- 6. Check for any claim_events for the claims in this file
SELECT 
    'CLAIM_EVENTS_FOR_CLAIMS' as check_type,
    CASE 
        WHEN COUNT(*) > 0 THEN 'YES'
        ELSE 'NO'
    END as result,
    COUNT(*) as count
FROM claims.claim_event ce
WHERE ce.claim_key_id IN (
    SELECT c.claim_key_id 
    FROM claims.claim c
    JOIN claims.submission s ON c.submission_id = s.id
    WHERE s.ingestion_file_id = 31325
);

-- 7. Show sample claim_key_ids for this file
SELECT 
    'SAMPLE_CLAIM_KEY_IDS' as info_type,
    c.claim_key_id,
    c.id as claim_id,
    c.claim_id as business_claim_id
FROM claims.claim c
JOIN claims.submission s ON c.submission_id = s.id
WHERE s.ingestion_file_id = 31325
LIMIT 5;

-- 8. Show sample claim_events for these claim_key_ids
SELECT 
    'SAMPLE_CLAIM_EVENTS' as info_type,
    ce.id as event_id,
    ce.claim_key_id,
    ce.type,
    ce.event_time,
    ce.ingestion_file_id
FROM claims.claim_event ce
WHERE ce.claim_key_id IN (
    SELECT c.claim_key_id 
    FROM claims.claim c
    JOIN claims.submission s ON c.submission_id = s.id
    WHERE s.ingestion_file_id = 31325
)
LIMIT 5;
