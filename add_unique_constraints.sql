-- ==========================================================================================================
-- ADD UNIQUE CONSTRAINTS FOR ON CONFLICT CLAUSES
-- ==========================================================================================================
-- 
-- Purpose: Add named UNIQUE constraints to match ON CONFLICT clauses in application code
-- Date: Generated for database migration
-- 
-- IMPORTANT: Run the inspection query first to check which constraints already exist!
-- 
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: REFERENCE DATA TABLES (claims_ref schema)
-- ==========================================================================================================

-- Check if constraint exists before adding (safe to run multiple times)
DO $$
BEGIN
    -- Facility code constraint
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'uq_facility_code' 
        AND conrelid = 'claims_ref.facility'::regclass
    ) THEN
        ALTER TABLE claims_ref.facility 
        ADD CONSTRAINT uq_facility_code UNIQUE (facility_code);
        RAISE NOTICE 'Added constraint: uq_facility_code on claims_ref.facility';
    ELSE
        RAISE NOTICE 'Constraint already exists: uq_facility_code on claims_ref.facility';
    END IF;

    -- Payer code constraint
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'uq_payer_code' 
        AND conrelid = 'claims_ref.payer'::regclass
    ) THEN
        ALTER TABLE claims_ref.payer 
        ADD CONSTRAINT uq_payer_code UNIQUE (payer_code);
        RAISE NOTICE 'Added constraint: uq_payer_code on claims_ref.payer';
    ELSE
        RAISE NOTICE 'Constraint already exists: uq_payer_code on claims_ref.payer';
    END IF;

    -- Provider code constraint
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'uq_provider_code' 
        AND conrelid = 'claims_ref.provider'::regclass
    ) THEN
        ALTER TABLE claims_ref.provider 
        ADD CONSTRAINT uq_provider_code UNIQUE (provider_code);
        RAISE NOTICE 'Added constraint: uq_provider_code on claims_ref.provider';
    ELSE
        RAISE NOTICE 'Constraint already exists: uq_provider_code on claims_ref.provider';
    END IF;

    -- Clinician code constraint
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'uq_clinician_code' 
        AND conrelid = 'claims_ref.clinician'::regclass
    ) THEN
        ALTER TABLE claims_ref.clinician 
        ADD CONSTRAINT uq_clinician_code UNIQUE (clinician_code);
        RAISE NOTICE 'Added constraint: uq_clinician_code on claims_ref.clinician';
    ELSE
        RAISE NOTICE 'Constraint already exists: uq_clinician_code on claims_ref.clinician';
    END IF;

    -- Denial code constraint
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'uq_denial_code' 
        AND conrelid = 'claims_ref.denial_code'::regclass
    ) THEN
        ALTER TABLE claims_ref.denial_code 
        ADD CONSTRAINT uq_denial_code UNIQUE (code);
        RAISE NOTICE 'Added constraint: uq_denial_code on claims_ref.denial_code';
    ELSE
        RAISE NOTICE 'Constraint already exists: uq_denial_code on claims_ref.denial_code';
    END IF;
END $$;

-- ==========================================================================================================
-- SECTION 2: CORE TABLES (claims schema)
-- ==========================================================================================================

-- Check if constraint exists before adding (safe to run multiple times)
DO $$
DECLARE
    old_constraint_name TEXT;
BEGIN
    -- Claim key constraint
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'uq_claim_key_claim_id' 
        AND conrelid = 'claims.claim_key'::regclass
    ) THEN
        ALTER TABLE claims.claim_key 
        ADD CONSTRAINT uq_claim_key_claim_id UNIQUE (claim_id);
        RAISE NOTICE 'Added constraint: uq_claim_key_claim_id on claims.claim_key';
    ELSE
        RAISE NOTICE 'Constraint already exists: uq_claim_key_claim_id on claims.claim_key';
    END IF;

    -- Facility DHPO config constraint (convert unnamed UNIQUE to named constraint)
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'uq_facility_dhpo_config' 
        AND conrelid = 'claims.facility_dhpo_config'::regclass
    ) THEN
        -- Drop any existing unnamed UNIQUE constraint on facility_code
        SELECT c.conname INTO old_constraint_name
        FROM pg_constraint c
        JOIN pg_class t ON c.conrelid = t.oid
        JOIN pg_namespace n ON t.relnamespace = n.oid
        WHERE n.nspname = 'claims' AND t.relname = 'facility_dhpo_config'
        AND c.contype = 'u'
        AND c.conname != 'uq_facility_dhpo_config'
        LIMIT 1;
        
        IF old_constraint_name IS NOT NULL THEN
            EXECUTE 'ALTER TABLE claims.facility_dhpo_config DROP CONSTRAINT IF EXISTS ' || quote_ident(old_constraint_name);
            RAISE NOTICE 'Dropped unnamed constraint: %', old_constraint_name;
        END IF;
        
        ALTER TABLE claims.facility_dhpo_config 
        ADD CONSTRAINT uq_facility_dhpo_config UNIQUE (facility_code);
        RAISE NOTICE 'Added constraint: uq_facility_dhpo_config on claims.facility_dhpo_config';
    ELSE
        RAISE NOTICE 'Constraint already exists: uq_facility_dhpo_config on claims.facility_dhpo_config';
    END IF;
END $$;

-- ==========================================================================================================
-- SECTION 3: VERIFICATION
-- ==========================================================================================================

-- Verify all constraints were added successfully
SELECT 
    'VERIFICATION: All UNIQUE Constraints' as section,
    con.conname as constraint_name,
    sch.nspname as schema_name,
    tab.relname as table_name,
    pg_get_constraintdef(con.oid) as constraint_definition
FROM pg_constraint con
JOIN pg_class tab ON con.conrelid = tab.oid
JOIN pg_namespace sch ON tab.relnamespace = sch.oid
WHERE con.contype = 'u'
AND (
    -- Reference data constraints
    con.conname IN ('uq_facility_code', 'uq_payer_code', 'uq_provider_code', 'uq_clinician_code', 'uq_denial_code')
    OR 
    -- Core constraints
    con.conname IN ('uq_claim_key_claim_id')
    OR
    -- Other ON CONFLICT constraints used in code
    con.conname IN (
        'uq_ingestion_file', 
        'uq_submission_per_file', 
        'uq_remittance_per_file',
        'uq_claim_per_key',
        'uq_activity_bk',
        'uq_remittance_claim',
        'uq_remittance_activity',
        'uq_claim_event_dedup',
        'uq_claim_resubmission_event',
        'uq_facility_dhpo_config',
        'uq_verification_rule_code',
        'uq_ingestion_file_audit',
        'uq_claim_submission_claimkey'
    )
)
ORDER BY sch.nspname, tab.relname, con.conname;

