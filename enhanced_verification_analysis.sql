-- Enhanced verification script to identify missing checks
-- This will help identify what verification gaps exist

-- 1. Check for files with constraint errors that caused rollbacks
SELECT 
    ifa.ingestion_file_id,
    ifa.file_name,
    ifa.status,
    ifa.error_message,
    COUNT(ie.id) as error_count
FROM claims.ingestion_file_audit ifa
LEFT JOIN claims.ingestion_error ie ON ifa.ingestion_file_id = ie.ingestion_file_id
WHERE ifa.status != 1 -- Not successful
   OR ie.error_message LIKE '%constraint%'
   OR ie.error_message LIKE '%transaction%'
GROUP BY ifa.ingestion_file_id, ifa.file_name, ifa.status, ifa.error_message
ORDER BY error_count DESC
LIMIT 10;

-- 2. Check for files with parsed but not persisted activities
SELECT 
    ifa.ingestion_file_id,
    ifa.file_name,
    ifa.parsed_activities,
    ifa.persisted_activities,
    (ifa.parsed_activities - ifa.persisted_activities) as missing_activities
FROM claims.ingestion_file_audit ifa
WHERE ifa.parsed_activities > 0 
  AND ifa.persisted_activities = 0
ORDER BY missing_activities DESC
LIMIT 10;

-- 3. Check for orphaned reference data
SELECT 'Missing Payers' as issue_type, COUNT(*) as count
FROM claims.claim c 
LEFT JOIN claims_ref.payer p ON c.payer_id = p.payer_code
WHERE p.id IS NULL AND c.payer_id IS NOT NULL

UNION ALL

SELECT 'Missing Providers' as issue_type, COUNT(*) as count
FROM claims.claim c 
LEFT JOIN claims_ref.provider p ON c.provider_id = p.provider_code
WHERE p.id IS NULL AND c.provider_id IS NOT NULL

UNION ALL

SELECT 'Missing Facilities' as issue_type, COUNT(*) as count
FROM claims.encounter e 
LEFT JOIN claims_ref.facility f ON e.facility_id = f.facility_code
WHERE f.id IS NULL AND e.facility_id IS NOT NULL;

-- 4. Check for data quality issues
SELECT 
    'Claims with zero amounts' as issue_type,
    COUNT(*) as count
FROM claims.claim 
WHERE gross = 0 AND patient_share = 0 AND net = 0

UNION ALL

SELECT 
    'Activities with zero amounts' as issue_type,
    COUNT(*) as count
FROM claims.activity 
WHERE quantity = 0 AND net = 0

UNION ALL

SELECT 
    'Claims with future dates' as issue_type,
    COUNT(*) as count
FROM claims.claim 
WHERE tx_at > NOW() + INTERVAL '1 day';

-- 5. Check for duplicate detection issues
SELECT 
    claim_id,
    COUNT(*) as submission_count
FROM claims.claim_key ck
JOIN claims.claim_event ce ON ck.id = ce.claim_key_id
WHERE ce.type = 1 -- Submission events
GROUP BY claim_id
HAVING COUNT(*) > 1
ORDER BY submission_count DESC
LIMIT 10;
