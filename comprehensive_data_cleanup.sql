-- ==========================================================================================================
-- COMPREHENSIVE DATA CLEANUP - REMOVE ALL ORPHANED DATA
-- ==========================================================================================================
-- This script removes ALL data related to orphaned claim keys
-- Run this to clean up the 2058 orphaned claim keys and their dependencies
-- ==========================================================================================================

-- ==========================================================================================================
-- 1. IDENTIFY ORPHANED CLAIM KEYS
-- ==========================================================================================================

-- Create a temporary table with orphaned claim key IDs
CREATE TEMP TABLE orphaned_claim_keys AS
SELECT ck.id as claim_key_id
FROM claims.claim_key ck
WHERE NOT EXISTS (SELECT 1 FROM claims.claim c WHERE c.claim_key_id = ck.id);

-- Show how many orphaned claim keys we have
SELECT 
  'Orphaned claim keys to clean up' as analysis,
  COUNT(*) as count
FROM orphaned_claim_keys;

-- ==========================================================================================================
-- 2. ANALYZE DEPENDENT DATA FOR ORPHANED CLAIM KEYS
-- ==========================================================================================================

-- Check what dependent data exists for orphaned claim keys
SELECT 
  'Claim events for orphaned keys' as analysis,
  COUNT(*) as count
FROM claims.claim_event ce
WHERE ce.claim_key_id IN (SELECT claim_key_id FROM orphaned_claim_keys);

SELECT 
  'Remittance claims for orphaned keys' as analysis,
  COUNT(*) as count
FROM claims.remittance_claim rc
WHERE rc.claim_key_id IN (SELECT claim_key_id FROM orphaned_claim_keys);

SELECT 
  'Status timeline for orphaned keys' as analysis,
  COUNT(*) as count
FROM claims.claim_status_timeline cst
WHERE cst.claim_key_id IN (SELECT claim_key_id FROM orphaned_claim_keys);

-- ==========================================================================================================
-- 3. DELETE DEPENDENT DATA IN CORRECT ORDER
-- ==========================================================================================================

-- Delete claim event activities first (deepest level)
DELETE FROM claims.claim_event_activity 
WHERE claim_event_id IN (
  SELECT ce.id 
  FROM claims.claim_event ce
  WHERE ce.claim_key_id IN (SELECT claim_key_id FROM orphaned_claim_keys)
);

-- Delete event observations
DELETE FROM claims.event_observation 
WHERE claim_event_activity_id IN (
  SELECT cea.id 
  FROM claims.claim_event_activity cea
  JOIN claims.claim_event ce ON ce.id = cea.claim_event_id
  WHERE ce.claim_key_id IN (SELECT claim_key_id FROM orphaned_claim_keys)
);

-- Delete claim resubmissions
DELETE FROM claims.claim_resubmission 
WHERE claim_event_id IN (
  SELECT ce.id 
  FROM claims.claim_event ce
  WHERE ce.claim_key_id IN (SELECT claim_key_id FROM orphaned_claim_keys)
);

-- Delete claim attachments
DELETE FROM claims.claim_attachment 
WHERE claim_key_id IN (SELECT claim_key_id FROM orphaned_claim_keys);

-- Delete remittance activities
DELETE FROM claims.remittance_activity 
WHERE remittance_claim_id IN (
  SELECT rc.id 
  FROM claims.remittance_claim rc
  WHERE rc.claim_key_id IN (SELECT claim_key_id FROM orphaned_claim_keys)
);

-- Delete remittance claims
DELETE FROM claims.remittance_claim 
WHERE claim_key_id IN (SELECT claim_key_id FROM orphaned_claim_keys);

-- Delete claim events
DELETE FROM claims.claim_event 
WHERE claim_key_id IN (SELECT claim_key_id FROM orphaned_claim_keys);

-- Delete claim status timeline
DELETE FROM claims.claim_status_timeline 
WHERE claim_key_id IN (SELECT claim_key_id FROM orphaned_claim_keys);

-- Finally, delete the orphaned claim keys
DELETE FROM claims.claim_key 
WHERE id IN (SELECT claim_key_id FROM orphaned_claim_keys);

-- ==========================================================================================================
-- 4. VERIFY CLEANUP
-- ==========================================================================================================

-- Check remaining data counts
SELECT 
  'claim_key' as table_name,
  COUNT(*) as row_count
FROM claims.claim_key

UNION ALL

SELECT 
  'claim' as table_name,
  COUNT(*) as row_count
FROM claims.claim

UNION ALL

SELECT 
  'encounter' as table_name,
  COUNT(*) as row_count
FROM claims.encounter

UNION ALL

SELECT 
  'claim_event' as table_name,
  COUNT(*) as row_count
FROM claims.claim_event

UNION ALL

SELECT 
  'remittance_claim' as table_name,
  COUNT(*) as row_count
FROM claims.remittance_claim

UNION ALL

SELECT 
  'claim_status_timeline' as table_name,
  COUNT(*) as row_count
FROM claims.claim_status_timeline

ORDER BY table_name;

-- Verify no orphaned claim keys remain
SELECT 
  'Remaining orphaned claim keys' as analysis,
  COUNT(*) as count
FROM claims.claim_key ck
WHERE NOT EXISTS (SELECT 1 FROM claims.claim c WHERE c.claim_key_id = ck.id);

-- ==========================================================================================================
-- 5. REFERENCE DATA SOLUTION - MANUAL POPULATION
-- ==========================================================================================================

-- Since bootstrap=false, we need to manually populate ref_ids
-- This will run every time you need to update reference data

-- Populate providers from existing claims
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

-- Populate payers from existing claims
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

-- Populate facilities from existing encounters
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
-- 6. UPDATE REF_IDS AFTER REFERENCE DATA POPULATION
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
-- 7. VERIFY REFERENCE DATA FIXES
-- ==========================================================================================================

-- Check reference data counts
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
-- 8. FINAL DATA SUMMARY
-- ==========================================================================================================

-- Complete data summary after cleanup and fixes
SELECT 
  'FINAL DATA SUMMARY' as summary,
  '' as details

UNION ALL

SELECT 
  'claim_key' as table_name,
  COUNT(*)::text as row_count
FROM claims.claim_key

UNION ALL

SELECT 
  'claim' as table_name,
  COUNT(*)::text as row_count
FROM claims.claim

UNION ALL

SELECT 
  'encounter' as table_name,
  COUNT(*)::text as row_count
FROM claims.encounter

UNION ALL

SELECT 
  'claim_event' as table_name,
  COUNT(*)::text as row_count
FROM claims.claim_event

UNION ALL

SELECT 
  'remittance_claim' as table_name,
  COUNT(*)::text as row_count
FROM claims.remittance_claim

UNION ALL

SELECT 
  'claim_status_timeline' as table_name,
  COUNT(*)::text as row_count
FROM claims.claim_status_timeline;

-- ==========================================================================================================
-- INSTRUCTIONS
-- ==========================================================================================================
-- 1. Run this script to clean up ALL orphaned data
-- 2. This will remove 2058 orphaned claim keys and ALL their dependent data
-- 3. Reference data will be populated from existing claims
-- 4. All ref_ids will be updated for better performance
-- 5. After this, your data should be clean and reports should work fast
-- 6. Keep bootstrap=false and run this script when you need to update reference data
-- ==========================================================================================================
