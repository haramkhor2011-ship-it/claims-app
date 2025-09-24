-- ==========================================================================================================
-- REFERENCE DATA LOADING FROM CSV FILES
-- ==========================================================================================================
-- This script loads reference data from CSV files in src/main/resources/refdata/
-- Run this when you need to update reference data (not on every app startup)
-- ==========================================================================================================

-- ==========================================================================================================
-- 1. CLEAR EXISTING REFERENCE DATA (OPTIONAL)
-- ==========================================================================================================

-- Uncomment these lines if you want to clear existing data first
-- TRUNCATE TABLE claims_ref.provider CASCADE;
-- TRUNCATE TABLE claims_ref.payer CASCADE;
-- TRUNCATE TABLE claims_ref.facility CASCADE;
-- TRUNCATE TABLE claims_ref.clinician CASCADE;
-- TRUNCATE TABLE claims_ref.activity_code CASCADE;
-- TRUNCATE TABLE claims_ref.diagnosis_code CASCADE;
-- TRUNCATE TABLE claims_ref.denial_code CASCADE;
-- TRUNCATE TABLE claims_ref.contract_package CASCADE;

-- ==========================================================================================================
-- 2. LOAD PROVIDERS FROM CSV
-- ==========================================================================================================

-- Note: You'll need to copy the CSV files to a location accessible by PostgreSQL
-- or use COPY command with proper file paths

-- Example for providers.csv (adjust path as needed):
-- COPY claims_ref.provider (provider_code, name, status) 
-- FROM '/path/to/providers.csv' 
-- WITH CSV HEADER;

-- For now, let's create a sample insert based on your existing data
-- You can replace this with actual CSV loading
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

-- ==========================================================================================================
-- 3. LOAD PAYERS FROM CSV
-- ==========================================================================================================

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

-- ==========================================================================================================
-- 4. LOAD FACILITIES FROM CSV
-- ==========================================================================================================

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
-- 5. LOAD CLINICIANS FROM CSV (if needed)
-- ==========================================================================================================

-- Extract unique clinicians from activities
INSERT INTO claims_ref.clinician (clinician_code, name, specialty, status)
SELECT DISTINCT 
  a.clinician as clinician_code,
  'Clinician ' || a.clinician as name,
  'General' as specialty,
  'ACTIVE' as status
FROM claims.activity a
WHERE a.clinician IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM claims_ref.clinician c WHERE c.clinician_code = a.clinician)
ON CONFLICT (clinician_code) DO UPDATE SET
  name = EXCLUDED.name,
  specialty = EXCLUDED.specialty,
  status = EXCLUDED.status,
  updated_at = NOW();

-- ==========================================================================================================
-- 6. LOAD ACTIVITY CODES FROM CSV (if needed)
-- ==========================================================================================================

-- Extract unique activity codes from activities
INSERT INTO claims_ref.activity_code (code, code_system, description, status)
SELECT DISTINCT 
  a.code,
  'LOCAL' as code_system,
  'Activity ' || a.code as description,
  'ACTIVE' as status
FROM claims.activity a
WHERE a.code IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM claims_ref.activity_code ac WHERE ac.code = a.code AND ac.code_system = 'LOCAL')
ON CONFLICT (code, code_system) DO UPDATE SET
  description = EXCLUDED.description,
  status = EXCLUDED.status,
  updated_at = NOW();

-- ==========================================================================================================
-- 7. LOAD DIAGNOSIS CODES FROM CSV (if needed)
-- ==========================================================================================================

-- Extract unique diagnosis codes from diagnoses
INSERT INTO claims_ref.diagnosis_code (code, code_system, description, status)
SELECT DISTINCT 
  d.code,
  'ICD-10' as code_system,
  'Diagnosis ' || d.code as description,
  'ACTIVE' as status
FROM claims.diagnosis d
WHERE d.code IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM claims_ref.diagnosis_code dc WHERE dc.code = d.code AND dc.code_system = 'ICD-10')
ON CONFLICT (code, code_system) DO UPDATE SET
  description = EXCLUDED.description,
  status = EXCLUDED.status,
  updated_at = NOW();

-- ==========================================================================================================
-- 8. LOAD DENIAL CODES FROM CSV (if needed)
-- ==========================================================================================================

-- Extract unique denial codes from remittance activities
INSERT INTO claims_ref.denial_code (code, description, payer_code)
SELECT DISTINCT 
  ra.denial_code,
  'Denial ' || ra.denial_code as description,
  rc.id_payer as payer_code
FROM claims.remittance_activity ra
JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
WHERE ra.denial_code IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM claims_ref.denial_code dc WHERE dc.code = ra.denial_code)
ON CONFLICT (code) DO UPDATE SET
  description = EXCLUDED.description,
  payer_code = EXCLUDED.payer_code,
  updated_at = NOW();

-- ==========================================================================================================
-- 9. UPDATE REFERENCE IDS AFTER LOADING
-- ==========================================================================================================

-- Update claims with proper ref_ids
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

-- Update encounters with proper ref_ids
UPDATE claims.encounter e 
SET facility_ref_id = f.id 
FROM claims_ref.facility f 
WHERE f.facility_code = e.facility_id 
  AND e.facility_ref_id IS NULL;

-- Update activities with proper ref_ids
UPDATE claims.activity a 
SET clinician_ref_id = c.id 
FROM claims_ref.clinician c 
WHERE c.clinician_code = a.clinician 
  AND a.clinician_ref_id IS NULL;

UPDATE claims.activity a 
SET activity_code_ref_id = ac.id 
FROM claims_ref.activity_code ac 
WHERE ac.code = a.code 
  AND ac.code_system = 'LOCAL'
  AND a.activity_code_ref_id IS NULL;

-- Update diagnoses with proper ref_ids
UPDATE claims.diagnosis d 
SET diagnosis_code_ref_id = dc.id 
FROM claims_ref.diagnosis_code dc 
WHERE dc.code = d.code 
  AND dc.code_system = 'ICD-10'
  AND d.diagnosis_code_ref_id IS NULL;

-- Update remittance claims with proper ref_ids
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
-- 10. VERIFY REFERENCE DATA LOADING
-- ==========================================================================================================

-- Check reference data counts
SELECT 
  'Providers' as table_name,
  COUNT(*) as count
FROM claims_ref.provider

UNION ALL

SELECT 
  'Payers' as table_name,
  COUNT(*) as count
FROM claims_ref.payer

UNION ALL

SELECT 
  'Facilities' as table_name,
  COUNT(*) as count
FROM claims_ref.facility

UNION ALL

SELECT 
  'Clinicians' as table_name,
  COUNT(*) as count
FROM claims_ref.clinician

UNION ALL

SELECT 
  'Activity Codes' as table_name,
  COUNT(*) as count
FROM claims_ref.activity_code

UNION ALL

SELECT 
  'Diagnosis Codes' as table_name,
  COUNT(*) as count
FROM claims_ref.diagnosis_code

UNION ALL

SELECT 
  'Denial Codes' as table_name,
  COUNT(*) as count
FROM claims_ref.denial_code;

-- Check updated ref_ids
SELECT 
  'Claims with payer_ref_id' as analysis,
  COUNT(*) as count
FROM claims.claim
WHERE payer_ref_id IS NOT NULL

UNION ALL

SELECT 
  'Claims with provider_ref_id' as analysis,
  COUNT(*) as count
FROM claims.claim
WHERE provider_ref_id IS NOT NULL

UNION ALL

SELECT 
  'Encounters with facility_ref_id' as analysis,
  COUNT(*) as count
FROM claims.encounter
WHERE facility_ref_id IS NOT NULL;

-- ==========================================================================================================
-- 11. CLEAN UP ORPHANED CLAIM KEYS
-- ==========================================================================================================

-- Check how many orphaned claim keys exist
SELECT 
  'Orphaned claim keys to delete' as analysis,
  COUNT(*) as count
FROM claims.claim_key ck
WHERE NOT EXISTS (SELECT 1 FROM claims.claim c WHERE c.claim_key_id = ck.id);

-- Uncomment the next line to actually delete orphaned claim keys
-- DELETE FROM claims.claim_key WHERE id NOT IN (SELECT claim_key_id FROM claims.claim);

-- ==========================================================================================================
-- INSTRUCTIONS FOR CSV LOADING
-- ==========================================================================================================
-- 1. Copy CSV files from src/main/resources/refdata/ to a PostgreSQL accessible location
-- 2. Use COPY commands like:
--    COPY claims_ref.provider (provider_code, name, status) FROM '/path/to/providers.csv' WITH CSV HEADER;
-- 3. Or use the INSERT statements above which extract data from existing claims
-- 4. Run this script when you need to update reference data
-- 5. Keep bootstrap property as false to avoid loading on every startup
-- ==========================================================================================================
