-- ==========================================================================================================
-- POPULATE REFERENCE DATA IDs - ONE-TIME SCRIPT
-- ==========================================================================================================
-- 
-- Purpose: Populate all _ref_id columns in core claims tables by matching with claims_ref tables
-- Version: 1.0
-- Date: 2025-01-03
-- 
-- This script will:
-- 1. Update claims.claim table with payer_ref_id and provider_ref_id
-- 2. Update claims.encounter table with facility_ref_id
-- 3. Update claims.activity table with clinician_ref_id and activity_code_ref_id
-- 4. Update claims.diagnosis table with diagnosis_code_ref_id
-- 5. Update claims.remittance_claim table with denial_code_ref_id, payer_ref_id, provider_ref_id
-- 6. Update claims.remittance_activity table with activity_code_ref_id
--
-- IMPORTANT: This is a one-time script. Run with caution in production.
-- ==========================================================================================================

-- Start transaction for safety
BEGIN;

-- ==========================================================================================================
-- SECTION 1: CLAIMS.CLAIM TABLE UPDATES
-- ==========================================================================================================

-- Update payer_ref_id in claims.claim
UPDATE claims.claim 
SET payer_ref_id = p.id
FROM claims_ref.payer p
WHERE claims.claim.payer_id = p.payer_code
  AND claims.claim.payer_ref_id IS NULL
  AND p.status = 'ACTIVE';

-- Log the update
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE 'Updated % rows in claims.claim with payer_ref_id', updated_count;
END$$;

-- Update provider_ref_id in claims.claim
UPDATE claims.claim 
SET provider_ref_id = p.id
FROM claims_ref.provider p
WHERE claims.claim.provider_id = p.provider_code
  AND claims.claim.provider_ref_id IS NULL
  AND p.status = 'ACTIVE';

-- Log the update
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE 'Updated % rows in claims.claim with provider_ref_id', updated_count;
END$$;

-- ==========================================================================================================
-- SECTION 2: CLAIMS.ENCOUNTER TABLE UPDATES
-- ==========================================================================================================

-- Update facility_ref_id in claims.encounter
UPDATE claims.encounter 
SET facility_ref_id = f.id
FROM claims_ref.facility f
WHERE claims.encounter.facility_id = f.facility_code
  AND claims.encounter.facility_ref_id IS NULL
  AND f.status = 'ACTIVE';

-- Log the update
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE 'Updated % rows in claims.encounter with facility_ref_id', updated_count;
END$$;

-- ==========================================================================================================
-- SECTION 3: CLAIMS.ACTIVITY TABLE UPDATES
-- ==========================================================================================================

-- Update clinician_ref_id in claims.activity
UPDATE claims.activity 
SET clinician_ref_id = c.id
FROM claims_ref.clinician c
WHERE claims.activity.clinician = c.clinician_code
  AND claims.activity.clinician_ref_id IS NULL
  AND c.status = 'ACTIVE';

-- Log the update
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE 'Updated % rows in claims.activity with clinician_ref_id', updated_count;
END$$;

-- Update activity_code_ref_id in claims.activity
UPDATE claims.activity 
SET activity_code_ref_id = ac.id
FROM claims_ref.activity_code ac
WHERE claims.activity.code = ac.code
  AND claims.activity.activity_code_ref_id IS NULL
  AND ac.status = 'ACTIVE';

-- Log the update
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE 'Updated % rows in claims.activity with activity_code_ref_id', updated_count;
END$$;

-- ==========================================================================================================
-- SECTION 4: CLAIMS.DIAGNOSIS TABLE UPDATES
-- ==========================================================================================================

-- Update diagnosis_code_ref_id in claims.diagnosis
UPDATE claims.diagnosis 
SET diagnosis_code_ref_id = dc.id
FROM claims_ref.diagnosis_code dc
WHERE claims.diagnosis.code = dc.code
  AND claims.diagnosis.diagnosis_code_ref_id IS NULL
  AND dc.status = 'ACTIVE';

-- Log the update
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE 'Updated % rows in claims.diagnosis with diagnosis_code_ref_id', updated_count;
END$$;

-- ==========================================================================================================
-- SECTION 5: CLAIMS.REMITTANCE_CLAIM TABLE UPDATES
-- ==========================================================================================================

-- Update denial_code_ref_id in claims.remittance_claim
UPDATE claims.remittance_claim 
SET denial_code_ref_id = dc.id
FROM claims_ref.denial_code dc
WHERE claims.remittance_claim.denial_code = dc.code
  AND claims.remittance_claim.denial_code_ref_id IS NULL;

-- Log the update
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE 'Updated % rows in claims.remittance_claim with denial_code_ref_id', updated_count;
END$$;

-- Update payer_ref_id in claims.remittance_claim
UPDATE claims.remittance_claim 
SET payer_ref_id = p.id
FROM claims_ref.payer p
WHERE claims.remittance_claim.id_payer = p.payer_code
  AND claims.remittance_claim.payer_ref_id IS NULL
  AND p.status = 'ACTIVE';

-- Log the update
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE 'Updated % rows in claims.remittance_claim with payer_ref_id', updated_count;
END$$;

-- Update provider_ref_id in claims.remittance_claim
UPDATE claims.remittance_claim 
SET provider_ref_id = p.id
FROM claims_ref.provider p
WHERE claims.remittance_claim.provider_id = p.provider_code
  AND claims.remittance_claim.provider_ref_id IS NULL
  AND p.status = 'ACTIVE';

-- Log the update
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE 'Updated % rows in claims.remittance_claim with provider_ref_id', updated_count;
END$$;

-- ==========================================================================================================
-- SECTION 6: CLAIMS.REMITTANCE_ACTIVITY TABLE UPDATES
-- ==========================================================================================================

-- Update activity_code_ref_id in claims.remittance_activity
UPDATE claims.remittance_activity 
SET activity_code_ref_id = ac.id
FROM claims_ref.activity_code ac
WHERE claims.remittance_activity.code = ac.code
  AND claims.remittance_activity.activity_code_ref_id IS NULL
  AND ac.status = 'ACTIVE';

-- Log the update
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE 'Updated % rows in claims.remittance_activity with activity_code_ref_id', updated_count;
END$$;

-- Update clinician_ref_id in claims.remittance_activity
UPDATE claims.remittance_activity 
SET clinician_ref_id = c.id
FROM claims_ref.clinician c
WHERE claims.remittance_activity.clinician = c.clinician_code
  AND claims.remittance_activity.clinician_ref_id IS NULL
  AND c.status = 'ACTIVE';

-- Log the update
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE 'Updated % rows in claims.remittance_activity with clinician_ref_id', updated_count;
END$$;

-- Update denial_code_ref_id in claims.remittance_activity
UPDATE claims.remittance_activity 
SET denial_code_ref_id = dc.id
FROM claims_ref.denial_code dc
WHERE claims.remittance_activity.denial_code = dc.code
  AND claims.remittance_activity.denial_code_ref_id IS NULL;

-- Log the update
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE 'Updated % rows in claims.remittance_activity with denial_code_ref_id', updated_count;
END$$;

-- ==========================================================================================================
-- SECTION 7: SUMMARY REPORT
-- ==========================================================================================================

-- Generate summary report
DO $$
DECLARE
    claim_payer_count INTEGER;
    claim_provider_count INTEGER;
    encounter_facility_count INTEGER;
    activity_clinician_count INTEGER;
    activity_code_count INTEGER;
    diagnosis_code_count INTEGER;
    remit_denial_count INTEGER;
    remit_payer_count INTEGER;
    remit_provider_count INTEGER;
    remit_activity_code_count INTEGER;
    remit_activity_clinician_count INTEGER;
    remit_activity_denial_count INTEGER;
BEGIN
    -- Count populated reference IDs
    SELECT COUNT(*) INTO claim_payer_count FROM claims.claim WHERE payer_ref_id IS NOT NULL;
    SELECT COUNT(*) INTO claim_provider_count FROM claims.claim WHERE provider_ref_id IS NOT NULL;
    SELECT COUNT(*) INTO encounter_facility_count FROM claims.encounter WHERE facility_ref_id IS NOT NULL;
    SELECT COUNT(*) INTO activity_clinician_count FROM claims.activity WHERE clinician_ref_id IS NOT NULL;
    SELECT COUNT(*) INTO activity_code_count FROM claims.activity WHERE activity_code_ref_id IS NOT NULL;
    SELECT COUNT(*) INTO diagnosis_code_count FROM claims.diagnosis WHERE diagnosis_code_ref_id IS NOT NULL;
    SELECT COUNT(*) INTO remit_denial_count FROM claims.remittance_claim WHERE denial_code_ref_id IS NOT NULL;
    SELECT COUNT(*) INTO remit_payer_count FROM claims.remittance_claim WHERE payer_ref_id IS NOT NULL;
    SELECT COUNT(*) INTO remit_provider_count FROM claims.remittance_claim WHERE provider_ref_id IS NOT NULL;
    SELECT COUNT(*) INTO remit_activity_code_count FROM claims.remittance_activity WHERE activity_code_ref_id IS NOT NULL;
    SELECT COUNT(*) INTO remit_activity_clinician_count FROM claims.remittance_activity WHERE clinician_ref_id IS NOT NULL;
    SELECT COUNT(*) INTO remit_activity_denial_count FROM claims.remittance_activity WHERE denial_code_ref_id IS NOT NULL;
    
    RAISE NOTICE '=== REFERENCE ID POPULATION SUMMARY ===';
    RAISE NOTICE 'claims.claim.payer_ref_id: % populated', claim_payer_count;
    RAISE NOTICE 'claims.claim.provider_ref_id: % populated', claim_provider_count;
    RAISE NOTICE 'claims.encounter.facility_ref_id: % populated', encounter_facility_count;
    RAISE NOTICE 'claims.activity.clinician_ref_id: % populated', activity_clinician_count;
    RAISE NOTICE 'claims.activity.activity_code_ref_id: % populated', activity_code_count;
    RAISE NOTICE 'claims.diagnosis.diagnosis_code_ref_id: % populated', diagnosis_code_count;
    RAISE NOTICE 'claims.remittance_claim.denial_code_ref_id: % populated', remit_denial_count;
    RAISE NOTICE 'claims.remittance_claim.payer_ref_id: % populated', remit_payer_count;
    RAISE NOTICE 'claims.remittance_claim.provider_ref_id: % populated', remit_provider_count;
    RAISE NOTICE 'claims.remittance_activity.activity_code_ref_id: % populated', remit_activity_code_count;
    RAISE NOTICE 'claims.remittance_activity.clinician_ref_id: % populated', remit_activity_clinician_count;
    RAISE NOTICE 'claims.remittance_activity.denial_code_ref_id: % populated', remit_activity_denial_count;
    RAISE NOTICE '=== END SUMMARY ===';
END$$;

-- ==========================================================================================================
-- SECTION 8: VALIDATION QUERIES
-- ==========================================================================================================

-- Check for any remaining NULL reference IDs that should have been populated
DO $$
DECLARE
    unmatched_claim_payer INTEGER;
    unmatched_claim_provider INTEGER;
    unmatched_encounter_facility INTEGER;
    unmatched_activity_clinician INTEGER;
    unmatched_activity_code INTEGER;
    unmatched_diagnosis_code INTEGER;
    unmatched_remit_denial INTEGER;
    unmatched_remit_payer INTEGER;
    unmatched_remit_provider INTEGER;
    unmatched_remit_activity_code INTEGER;
    unmatched_remit_activity_clinician INTEGER;
    unmatched_remit_activity_denial INTEGER;
BEGIN
    -- Count unmatched records
    SELECT COUNT(*) INTO unmatched_claim_payer 
    FROM claims.claim c 
    LEFT JOIN claims_ref.payer p ON c.payer_id = p.payer_code AND p.status = 'ACTIVE'
    WHERE c.payer_ref_id IS NULL AND p.id IS NOT NULL;
    
    SELECT COUNT(*) INTO unmatched_claim_provider 
    FROM claims.claim c 
    LEFT JOIN claims_ref.provider p ON c.provider_id = p.provider_code AND p.status = 'ACTIVE'
    WHERE c.provider_ref_id IS NULL AND p.id IS NOT NULL;
    
    SELECT COUNT(*) INTO unmatched_encounter_facility 
    FROM claims.encounter e 
    LEFT JOIN claims_ref.facility f ON e.facility_id = f.facility_code AND f.status = 'ACTIVE'
    WHERE e.facility_ref_id IS NULL AND f.id IS NOT NULL;
    
    SELECT COUNT(*) INTO unmatched_activity_clinician 
    FROM claims.activity a 
    LEFT JOIN claims_ref.clinician c ON a.clinician = c.clinician_code AND c.status = 'ACTIVE'
    WHERE a.clinician_ref_id IS NULL AND c.id IS NOT NULL;
    
    SELECT COUNT(*) INTO unmatched_activity_code 
    FROM claims.activity a 
    LEFT JOIN claims_ref.activity_code ac ON a.code = ac.code AND ac.status = 'ACTIVE'
    WHERE a.activity_code_ref_id IS NULL AND ac.id IS NOT NULL;
    
    SELECT COUNT(*) INTO unmatched_diagnosis_code 
    FROM claims.diagnosis d 
    LEFT JOIN claims_ref.diagnosis_code dc ON d.code = dc.code AND dc.status = 'ACTIVE'
    WHERE d.diagnosis_code_ref_id IS NULL AND dc.id IS NOT NULL;
    
    SELECT COUNT(*) INTO unmatched_remit_denial 
    FROM claims.remittance_claim rc 
    LEFT JOIN claims_ref.denial_code dc ON rc.denial_code = dc.code
    WHERE rc.denial_code_ref_id IS NULL AND dc.id IS NOT NULL;
    
    SELECT COUNT(*) INTO unmatched_remit_payer 
    FROM claims.remittance_claim rc 
    LEFT JOIN claims_ref.payer p ON rc.id_payer = p.payer_code AND p.status = 'ACTIVE'
    WHERE rc.payer_ref_id IS NULL AND p.id IS NOT NULL;
    
    SELECT COUNT(*) INTO unmatched_remit_provider 
    FROM claims.remittance_claim rc 
    LEFT JOIN claims_ref.provider p ON rc.provider_id = p.provider_code AND p.status = 'ACTIVE'
    WHERE rc.provider_ref_id IS NULL AND p.id IS NOT NULL;
    
    SELECT COUNT(*) INTO unmatched_remit_activity_code 
    FROM claims.remittance_activity ra 
    LEFT JOIN claims_ref.activity_code ac ON ra.code = ac.code AND ac.status = 'ACTIVE'
    WHERE ra.activity_code_ref_id IS NULL AND ac.id IS NOT NULL;
    
    SELECT COUNT(*) INTO unmatched_remit_activity_clinician 
    FROM claims.remittance_activity ra 
    LEFT JOIN claims_ref.clinician c ON ra.clinician = c.clinician_code AND c.status = 'ACTIVE'
    WHERE ra.clinician_ref_id IS NULL AND c.id IS NOT NULL;
    
    SELECT COUNT(*) INTO unmatched_remit_activity_denial 
    FROM claims.remittance_activity ra 
    LEFT JOIN claims_ref.denial_code dc ON ra.denial_code = dc.code
    WHERE ra.denial_code_ref_id IS NULL AND dc.id IS NOT NULL;
    
    RAISE NOTICE '=== UNMATCHED RECORDS (should be 0) ===';
    RAISE NOTICE 'Unmatched claim.payer_ref_id: %', unmatched_claim_payer;
    RAISE NOTICE 'Unmatched claim.provider_ref_id: %', unmatched_claim_provider;
    RAISE NOTICE 'Unmatched encounter.facility_ref_id: %', unmatched_encounter_facility;
    RAISE NOTICE 'Unmatched activity.clinician_ref_id: %', unmatched_activity_clinician;
    RAISE NOTICE 'Unmatched activity.activity_code_ref_id: %', unmatched_activity_code;
    RAISE NOTICE 'Unmatched diagnosis.diagnosis_code_ref_id: %', unmatched_diagnosis_code;
    RAISE NOTICE 'Unmatched remittance_claim.denial_code_ref_id: %', unmatched_remit_denial;
    RAISE NOTICE 'Unmatched remittance_claim.payer_ref_id: %', unmatched_remit_payer;
    RAISE NOTICE 'Unmatched remittance_claim.provider_ref_id: %', unmatched_remit_provider;
    RAISE NOTICE 'Unmatched remittance_activity.activity_code_ref_id: %', unmatched_remit_activity_code;
    RAISE NOTICE 'Unmatched remittance_activity.clinician_ref_id: %', unmatched_remit_activity_clinician;
    RAISE NOTICE 'Unmatched remittance_activity.denial_code_ref_id: %', unmatched_remit_activity_denial;
    RAISE NOTICE '=== END UNMATCHED RECORDS ===';
END$$;

-- Commit the transaction
COMMIT;

-- ==========================================================================================================
-- END OF SCRIPT
-- ==========================================================================================================

-- Final completion message
DO $$
BEGIN
    RAISE NOTICE 'Reference ID population script completed successfully!';
    RAISE NOTICE 'All _ref_id columns have been populated where matching reference data exists.';
    RAISE NOTICE 'Check the summary report above for details.';
END$$;
