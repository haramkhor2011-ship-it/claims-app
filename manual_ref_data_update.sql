-- ==========================================================================================================
-- MANUAL REFERENCE DATA UPDATE SCRIPT
-- ==========================================================================================================
-- Run this script whenever you need to update reference data
-- Since bootstrap=false, this needs to be run manually after new data ingestion
-- ==========================================================================================================

-- ==========================================================================================================
-- 1. UPDATE REFERENCE DATA FROM NEW CLAIMS
-- ==========================================================================================================

-- Add new providers from recently ingested claims
INSERT INTO claims_ref.provider (provider_code, name, status)
SELECT DISTINCT 
  c.provider_id as provider_code,
  'Provider ' || c.provider_id as name,
  'ACTIVE' as status
FROM claims.claim c
WHERE c.provider_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM claims_ref.provider p WHERE p.provider_code = c.provider_id)
ON CONFLICT (provider_code) DO UPDATE SET
  name = EXCLUDED.name,
  status = EXCLUDED.status,
  updated_at = NOW();

-- Add new payers from recently ingested claims
INSERT INTO claims_ref.payer (payer_code, name, status)
SELECT DISTINCT 
  c.payer_id as payer_code,
  'Payer ' || c.payer_id as name,
  'ACTIVE' as status
FROM claims.claim c
WHERE c.payer_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM claims_ref.payer p WHERE p.payer_code = c.payer_id)
ON CONFLICT (payer_code) DO UPDATE SET
  name = EXCLUDED.name,
  status = EXCLUDED.status,
  updated_at = NOW();

-- Add new facilities from recently ingested encounters
INSERT INTO claims_ref.facility (facility_code, name, status)
SELECT DISTINCT 
  e.facility_id as facility_code,
  'Facility ' || e.facility_id as name,
  'ACTIVE' as status
FROM claims.encounter e
WHERE e.facility_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM claims_ref.facility f WHERE f.facility_code = e.facility_id)
ON CONFLICT (facility_code) DO UPDATE SET
  name = EXCLUDED.name,
  status = EXCLUDED.status,
  updated_at = NOW();

-- ==========================================================================================================
-- 2. UPDATE REF_IDS FOR NEW CLAIMS
-- ==========================================================================================================

-- Update claims with NULL ref_ids
UPDATE claims.claim c 
SET payer_ref_id = p.id 
FROM claims_ref.payer p 
WHERE p.payer_code = c.payer_id 
  AND c.payer_ref_id IS NULL;

UPDATE claims.claim c 
SET provider_ref_id = p.id 
FROM claims_ref.provider p 
WHERE p.provider_code = c.provider_id 
  AND c.provider_ref_id IS NULL;

-- Update encounters with NULL ref_ids
UPDATE claims.encounter e 
SET facility_ref_id = f.id 
FROM claims_ref.facility f 
WHERE f.facility_code = e.facility_id 
  AND e.facility_ref_id IS NULL;

-- Update remittance claims with NULL ref_ids
UPDATE claims.remittance_claim rc 
SET payer_ref_id = p.id 
FROM claims_ref.payer p 
WHERE p.payer_code = rc.id_payer 
  AND rc.payer_ref_id IS NULL;

UPDATE claims.remittance_claim rc 
SET provider_ref_id = p.id 
FROM claims_ref.provider p 
WHERE p.provider_code = rc.provider_id 
  AND rc.provider_ref_id IS NULL;

-- ==========================================================================================================
-- 3. VERIFY UPDATES
-- ==========================================================================================================

-- Check how many claims still have NULL ref_ids
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
WHERE facility_ref_id IS NULL

UNION ALL

SELECT 
  'Remittance claims with NULL payer_ref_id' as analysis,
  COUNT(*) as count
FROM claims.remittance_claim
WHERE payer_ref_id IS NULL

UNION ALL

SELECT 
  'Remittance claims with NULL provider_ref_id' as analysis,
  COUNT(*) as count
FROM claims.remittance_claim
WHERE provider_ref_id IS NULL;

-- ==========================================================================================================
-- 4. REFERENCE DATA SUMMARY
-- ==========================================================================================================

-- Show current reference data counts
SELECT 
  'Providers in claims_ref' as table_name,
  COUNT(*) as count
FROM claims_ref.provider

UNION ALL

SELECT 
  'Payers in claims_ref' as table_name,
  COUNT(*) as count
FROM claims_ref.payer

UNION ALL

SELECT 
  'Facilities in claims_ref' as table_name,
  COUNT(*) as count
FROM claims_ref.facility;

-- ==========================================================================================================
-- 5. PERFORMANCE CHECK
-- ==========================================================================================================

-- Test if reports work faster now
SELECT 
  'Base view test' as test_name,
  COUNT(*) as row_count
FROM claims.v_balance_amount_base_enhanced;

-- ==========================================================================================================
-- USAGE INSTRUCTIONS
-- ==========================================================================================================
-- 1. Run this script after every new data ingestion
-- 2. This will update reference data and ref_ids for new claims
-- 3. Keep bootstrap=false in your application
-- 4. Run this manually when you need to update reference data
-- 5. This ensures ref_ids are always populated for better performance
-- ==========================================================================================================
