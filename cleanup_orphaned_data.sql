-- ==========================================================================================================
-- CLEANUP ORPHANED DATA
-- ==========================================================================================================
-- This script cleans up orphaned claim keys and other data integrity issues
-- ==========================================================================================================

-- ==========================================================================================================
-- 1. BACKUP ORPHANED DATA (OPTIONAL)
-- ==========================================================================================================

-- Create a backup table of orphaned claim keys before deletion
CREATE TABLE IF NOT EXISTS claims.claim_key_orphaned_backup AS
SELECT 
  ck.*,
  'Orphaned - no corresponding claim' as reason,
  NOW() as backup_date
FROM claims.claim_key ck
WHERE NOT EXISTS (SELECT 1 FROM claims.claim c WHERE c.claim_key_id = ck.id);

-- ==========================================================================================================
-- 2. ANALYZE ORPHANED DATA
-- ==========================================================================================================

-- Check what orphaned claim keys look like
SELECT 
  'Orphaned claim keys analysis' as analysis,
  COUNT(*) as total_orphaned,
  MIN(created_at) as earliest_created,
  MAX(created_at) as latest_created,
  COUNT(DISTINCT claim_id) as unique_claim_ids
FROM claims.claim_key_orphaned_backup;

-- Sample of orphaned claim keys
SELECT 
  id,
  claim_id,
  created_at
FROM claims.claim_key_orphaned_backup
ORDER BY created_at DESC
LIMIT 10;

-- ==========================================================================================================
-- 3. CHECK FOR DEPENDENCIES
-- ==========================================================================================================

-- Check if orphaned claim keys have any dependent data
SELECT 
  'Claim events for orphaned keys' as analysis,
  COUNT(*) as count
FROM claims.claim_event ce
WHERE ce.claim_key_id IN (
  SELECT id FROM claims.claim_key_orphaned_backup
);

SELECT 
  'Remittance claims for orphaned keys' as analysis,
  COUNT(*) as count
FROM claims.remittance_claim rc
WHERE rc.claim_key_id IN (
  SELECT id FROM claims.claim_key_orphaned_backup
);

SELECT 
  'Status timeline for orphaned keys' as analysis,
  COUNT(*) as count
FROM claims.claim_status_timeline cst
WHERE cst.claim_key_id IN (
  SELECT id FROM claims.claim_key_orphaned_backup
);

-- ==========================================================================================================
-- 4. SAFE CLEANUP (WITH DEPENDENCY CHECK)
-- ==========================================================================================================

-- Only delete orphaned claim keys that have NO dependent data
DELETE FROM claims.claim_key 
WHERE id IN (
  SELECT ck.id 
  FROM claims.claim_key ck
  WHERE NOT EXISTS (SELECT 1 FROM claims.claim c WHERE c.claim_key_id = ck.id)
    AND NOT EXISTS (SELECT 1 FROM claims.claim_event ce WHERE ce.claim_key_id = ck.id)
    AND NOT EXISTS (SELECT 1 FROM claims.remittance_claim rc WHERE rc.claim_key_id = ck.id)
    AND NOT EXISTS (SELECT 1 FROM claims.claim_status_timeline cst WHERE cst.claim_key_id = ck.id)
);

-- ==========================================================================================================
-- 5. VERIFY CLEANUP
-- ==========================================================================================================

-- Check remaining orphaned claim keys
SELECT 
  'Remaining orphaned claim keys' as analysis,
  COUNT(*) as count
FROM claims.claim_key ck
WHERE NOT EXISTS (SELECT 1 FROM claims.claim c WHERE c.claim_key_id = ck.id);

-- Check total claim keys after cleanup
SELECT 
  'Total claim keys after cleanup' as analysis,
  COUNT(*) as count
FROM claims.claim_key;

-- Check total claims
SELECT 
  'Total claims' as analysis,
  COUNT(*) as count
FROM claims.claim;

-- ==========================================================================================================
-- 6. DATA INTEGRITY VERIFICATION
-- ==========================================================================================================

-- Verify all remaining claim keys have corresponding claims
SELECT 
  'Claim keys with claims' as analysis,
  COUNT(*) as count
FROM claims.claim_key ck
WHERE EXISTS (SELECT 1 FROM claims.claim c WHERE c.claim_key_id = ck.id);

-- Verify all claims have corresponding claim keys
SELECT 
  'Claims with claim keys' as analysis,
  COUNT(*) as count
FROM claims.claim c
WHERE EXISTS (SELECT 1 FROM claims.claim_key ck WHERE ck.id = c.claim_key_id);

-- ==========================================================================================================
-- 7. FINAL DATA SUMMARY
-- ==========================================================================================================

-- Complete data summary after cleanup
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

-- ==========================================================================================================
-- INSTRUCTIONS
-- ==========================================================================================================
-- 1. Run section 1 to backup orphaned data
-- 2. Run section 2 to analyze orphaned data
-- 3. Run section 3 to check for dependencies
-- 4. Run section 4 to perform safe cleanup
-- 5. Run sections 5-7 to verify cleanup results
-- 6. The cleanup only removes claim keys with NO dependent data
-- 7. Orphaned data is backed up in claims.claim_key_orphaned_backup table
-- ==========================================================================================================
