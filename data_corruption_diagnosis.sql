-- ==========================================================================================================
-- DATA CORRUPTION DIAGNOSIS QUERIES
-- ==========================================================================================================
-- Run these queries to understand what went wrong with your data
-- ==========================================================================================================

-- ==========================================================================================================
-- 1. CLAIM KEY vs CLAIM ANALYSIS
-- ==========================================================================================================

-- Check how many claim keys have corresponding claims
SELECT 
  'Claim Keys with Claims' as analysis,
  COUNT(*) as count
FROM claims.claim_key ck
WHERE EXISTS (SELECT 1 FROM claims.claim c WHERE c.claim_key_id = ck.id)

UNION ALL

SELECT 
  'Claim Keys without Claims' as analysis,
  COUNT(*) as count
FROM claims.claim_key ck
WHERE NOT EXISTS (SELECT 1 FROM claims.claim c WHERE c.claim_key_id = ck.id)

UNION ALL

SELECT 
  'Total Claim Keys' as analysis,
  COUNT(*) as count
FROM claims.claim_key

UNION ALL

SELECT 
  'Total Claims' as analysis,
  COUNT(*) as count
FROM claims.claim;

-- ==========================================================================================================
-- 2. REFERENCE DATA ANALYSIS
-- ==========================================================================================================

-- Check reference data population
SELECT 
  'Claims with NULL payer_ref_id' as analysis,
  COUNT(*) as count
FROM claims.claim
WHERE payer_ref_id IS NULL

UNION ALL

SELECT 
  'Claims with NULL provider_ref_id' as analysis,
  COUNT(*) as count
FROM claims.claim
WHERE provider_ref_id IS NULL

UNION ALL

SELECT 
  'Encounters with NULL facility_ref_id' as analysis,
  COUNT(*) as count
FROM claims.encounter
WHERE facility_ref_id IS NULL;

-- ==========================================================================================================
-- 3. CLAIM EVENT ANALYSIS
-- ==========================================================================================================

-- Check claim events distribution
SELECT 
  'Total Claim Events' as analysis,
  COUNT(*) as count
FROM claims.claim_event

UNION ALL

SELECT 
  'Events with Submission (type=1)' as analysis,
  COUNT(*) as count
FROM claims.claim_event
WHERE type = 1

UNION ALL

SELECT 
  'Events with Resubmission (type=2)' as analysis,
  COUNT(*) as count
FROM claims.claim_event
WHERE type = 2

UNION ALL

SELECT 
  'Events with Remittance (type=3)' as analysis,
  COUNT(*) as count
FROM claims.claim_event
WHERE type = 3;

-- ==========================================================================================================
-- 4. REMITTANCE ANALYSIS
-- ==========================================================================================================

-- Check remittance data
SELECT 
  'Total Remittance Claims' as analysis,
  COUNT(*) as count
FROM claims.remittance_claim

UNION ALL

SELECT 
  'Remittance Claims with NULL payer_ref_id' as analysis,
  COUNT(*) as count
FROM claims.remittance_claim
WHERE payer_ref_id IS NULL

UNION ALL

SELECT 
  'Remittance Claims with NULL provider_ref_id' as analysis,
  COUNT(*) as count
FROM claims.remittance_claim
WHERE provider_ref_id IS NULL;

-- ==========================================================================================================
-- 5. DATA INTEGRITY CHECKS
-- ==========================================================================================================

-- Check for orphaned records
SELECT 
  'Orphaned Claim Events (no claim_key)' as analysis,
  COUNT(*) as count
FROM claims.claim_event ce
WHERE NOT EXISTS (SELECT 1 FROM claims.claim_key ck WHERE ck.id = ce.claim_key_id)

UNION ALL

SELECT 
  'Orphaned Remittance Claims (no claim_key)' as analysis,
  COUNT(*) as count
FROM claims.remittance_claim rc
WHERE NOT EXISTS (SELECT 1 FROM claims.claim_key ck WHERE ck.id = rc.claim_key_id)

UNION ALL

SELECT 
  'Orphaned Status Timeline (no claim_key)' as analysis,
  COUNT(*) as count
FROM claims.claim_status_timeline cst
WHERE NOT EXISTS (SELECT 1 FROM claims.claim_key ck WHERE ck.id = cst.claim_key_id);

-- ==========================================================================================================
-- 6. REFERENCE DATA AVAILABILITY
-- ==========================================================================================================

-- Check if reference data exists
SELECT 
  'Total Providers in claims_ref' as analysis,
  COUNT(*) as count
FROM claims_ref.provider

UNION ALL

SELECT 
  'Total Payers in claims_ref' as analysis,
  COUNT(*) as count
FROM claims_ref.payer

UNION ALL

SELECT 
  'Total Facilities in claims_ref' as analysis,
  COUNT(*) as count
FROM claims_ref.facility;

-- ==========================================================================================================
-- 7. SAMPLE DATA INSPECTION
-- ==========================================================================================================

-- Look at sample claim keys without claims
SELECT 
  ck.id,
  ck.claim_id,
  ck.created_at
FROM claims.claim_key ck
WHERE NOT EXISTS (SELECT 1 FROM claims.claim c WHERE c.claim_key_id = ck.id)
LIMIT 10;

-- Look at sample claims with NULL ref_ids
SELECT 
  c.id,
  c.claim_id,
  c.payer_id,
  c.provider_id,
  c.payer_ref_id,
  c.provider_ref_id,
  c.created_at
FROM claims.claim c
WHERE c.payer_ref_id IS NULL OR c.provider_ref_id IS NULL
LIMIT 10;

-- ==========================================================================================================
-- 8. INGESTION FILE ANALYSIS
-- ==========================================================================================================

-- Check ingestion files
SELECT 
  'Total Ingestion Files' as analysis,
  COUNT(*) as count
FROM claims.ingestion_file

UNION ALL

SELECT 
  'Submission Files (root_type=1)' as analysis,
  COUNT(*) as count
FROM claims.ingestion_file
WHERE root_type = 1

UNION ALL

SELECT 
  'Remittance Files (root_type=2)' as analysis,
  COUNT(*) as count
FROM claims.ingestion_file
WHERE root_type = 2;

-- ==========================================================================================================
-- RECOMMENDATIONS BASED ON RESULTS
-- ==========================================================================================================
-- 1. If many claim keys have no claims: Ingestion process failed for submissions
-- 2. If ref_ids are NULL: Reference data resolver is not working
-- 3. If excessive events: Duplicate event creation
-- 4. If orphaned records: Data integrity issues
-- ==========================================================================================================
