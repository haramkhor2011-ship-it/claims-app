-- Diagnostic queries to understand the verification issue
-- Check if the ingestion_file_id exists in ingestion_file table

-- 1. Check if ingestion_file_id exists in ingestion_file table
SELECT 
    id,
    file_id,
    file_name,
    root_type,
    sender_id,
    receiver_id,
    transaction_date,
    record_count_declared,
    created_at
FROM claims.ingestion_file 
WHERE id = 9728;

-- 2. Check if submission exists for this ingestion_file_id
SELECT 
    s.id as submission_id,
    s.ingestion_file_id,
    s.created_at,
    s.tx_at
FROM claims.submission s
WHERE s.ingestion_file_id = 9728;

-- 3. Check if claims exist for this submission
SELECT 
    c.id as claim_id,
    c.claim_key_id,
    c.submission_id,
    c.payer_id,
    c.provider_id,
    c.emirates_id_number
FROM claims.claim c
JOIN claims.submission s ON c.submission_id = s.id
WHERE s.ingestion_file_id = 9728;

-- 4. Check if claim_events exist for these claims
SELECT 
    ce.id as event_id,
    ce.claim_key_id,
    ce.type,
    ce.event_time,
    ce.ingestion_file_id,
    c.claim_id as business_claim_id
FROM claims.claim_event ce
JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id
JOIN claims.submission s ON c.submission_id = s.id
WHERE s.ingestion_file_id = 9728;

-- 5. Check the verification query that's failing
SELECT COUNT(*) as event_count
FROM claims.claim_event ce 
JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id 
JOIN claims.submission s ON c.submission_id = s.id 
WHERE s.ingestion_file_id = 9728;

-- 6. Check if there are any claim_events with ingestion_file_id = 9728 directly
SELECT 
    id,
    claim_key_id,
    type,
    event_time,
    ingestion_file_id
FROM claims.claim_event 
WHERE ingestion_file_id = 9728;
