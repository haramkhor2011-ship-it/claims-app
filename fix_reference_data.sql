-- ==========================================================================================================
-- REFERENCE DATA FIX QUERIES
-- ==========================================================================================================
-- These queries will help fix the missing reference data issue
-- ==========================================================================================================

-- ==========================================================================================================
-- 1. CHECK FOR REFERENCE DATA IN OTHER LOCATIONS
-- ==========================================================================================================

-- Check if reference data exists in other schemas or tables
SELECT 
  schemaname,
  tablename,
  tableowner
FROM pg_tables 
WHERE tablename IN ('provider', 'payer', 'facility', 'clinician', 'activity_code', 'diagnosis_code', 'denial_code')
ORDER BY schemaname, tablename;

-- Check if there are any CSV files or other reference data sources
SELECT 
  'Check your data/ready/ folder for CSV files' as instruction,
  'Look for files like: providers.csv, payers.csv, facilities.csv' as expected_files;

-- ==========================================================================================================
-- 2. POPULATE REFERENCE DATA FROM EXISTING CLAIMS
-- ==========================================================================================================

-- Extract unique providers from claims and populate claims_ref.provider
INSERT INTO claims_ref.provider (provider_code, name, status)
SELECT DISTINCT 
  c.provider_id as provider_code,
  c.provider_id as name,  -- Use provider_id as name until we have proper names
  'ACTIVE' as status
FROM claims.claim c
WHERE c.provider_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM claims_ref.provider p WHERE p.provider_code = c.provider_id);

-- Extract unique payers from claims and populate claims_ref.payer
INSERT INTO claims_ref.payer (payer_code, name, status)
SELECT DISTINCT 
  c.payer_id as payer_code,
  c.payer_id as name,  -- Use payer_id as name until we have proper names
  'ACTIVE' as status
FROM claims.claim c
WHERE c.payer_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM claims_ref.payer p WHERE p.payer_code = c.payer_id);

-- Extract unique facilities from encounters and populate claims_ref.facility
INSERT INTO claims_ref.facility (facility_code, name, status)
SELECT DISTINCT 
  e.facility_id as facility_code,
  e.facility_id as name,  -- Use facility_id as name until we have proper names
  'ACTIVE' as status
FROM claims.encounter e
WHERE e.facility_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM claims_ref.facility f WHERE f.facility_code = e.facility_id);

-- ==========================================================================================================
-- 3. UPDATE REFERENCE IDS IN CLAIMS
-- ==========================================================================================================

-- Update claims with proper payer_ref_id
UPDATE claims.claim c 
SET payer_ref_id = p.id 
FROM claims_ref.payer p 
WHERE p.payer_code = c.payer_id 
  AND c.payer_ref_id IS NULL;

-- Update claims with proper provider_ref_id
UPDATE claims.claim c 
SET provider_ref_id = p.id 
FROM claims_ref.provider p 
WHERE p.provider_code = c.provider_id 
  AND c.provider_ref_id IS NULL;

-- Update encounters with proper facility_ref_id
UPDATE claims.encounter e 
SET facility_ref_id = f.id 
FROM claims_ref.facility f 
WHERE f.facility_code = e.facility_id 
  AND e.facility_ref_id IS NULL;

-- ==========================================================================================================
-- 4. UPDATE REFERENCE IDS IN REMITTANCE CLAIMS
-- ==========================================================================================================

-- Update remittance claims with proper payer_ref_id
UPDATE claims.remittance_claim rc 
SET payer_ref_id = p.id 
FROM claims_ref.payer p 
WHERE p.payer_code = rc.id_payer 
  AND rc.payer_ref_id IS NULL;

-- Update remittance claims with proper provider_ref_id
UPDATE claims.remittance_claim rc 
SET provider_ref_id = p.id 
FROM claims_ref.provider p 
WHERE p.provider_code = rc.provider_id 
  AND rc.provider_ref_id IS NULL;

-- ==========================================================================================================
-- 5. VERIFY REFERENCE DATA FIXES
-- ==========================================================================================================

-- Check reference data population
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

-- Check updated ref_ids
SELECT 
  'Claims with updated payer_ref_id' as analysis,
  COUNT(*) as count
FROM claims.claim
WHERE payer_ref_id IS NOT NULL

UNION ALL

SELECT 
  'Claims with updated provider_ref_id' as analysis,
  COUNT(*) as count
FROM claims.claim
WHERE provider_ref_id IS NOT NULL

UNION ALL

SELECT 
  'Encounters with updated facility_ref_id' as analysis,
  COUNT(*) as count
FROM claims.encounter
WHERE facility_ref_id IS NOT NULL;

-- ==========================================================================================================
-- 6. CLEAN UP ORPHANED CLAIM KEYS
-- ==========================================================================================================

-- Remove claim keys that have no corresponding claims
-- WARNING: This will delete data - run with caution!
-- DELETE FROM claims.claim_key 
-- WHERE id NOT IN (SELECT claim_key_id FROM claims.claim);

-- Check how many would be deleted (run this first)
SELECT 
  'Claim keys that would be deleted' as analysis,
  COUNT(*) as count
FROM claims.claim_key ck
WHERE NOT EXISTS (SELECT 1 FROM claims.claim c WHERE c.claim_key_id = ck.id);

-- ==========================================================================================================
-- INSTRUCTIONS
-- ==========================================================================================================
-- 1. Run section 1 to check for existing reference data
-- 2. Run section 2 to populate reference data from existing claims
-- 3. Run section 3 to update ref_ids in claims
-- 4. Run section 4 to update ref_ids in remittance claims
-- 5. Run section 5 to verify the fixes
-- 6. Run section 6 to see how many orphaned claim keys exist
-- 7. If you want to clean up orphaned data, uncomment the DELETE statement in section 6
-- ==========================================================================================================
