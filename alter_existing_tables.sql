-- ==========================================================================================================
-- ALTER STATEMENTS FOR EXISTING CLAIMS_REF TABLES
-- ==========================================================================================================
-- 
-- Purpose: Fix existing tables to match JPA entity classes
-- These ALTER statements will:
-- 1. Add missing columns that exist in entity classes
-- 2. Fix unique constraints to match entity definitions
-- 3. Fix any bytea column types to TEXT
-- 4. Add missing default values
--
-- ==========================================================================================================

-- ==========================================================================================================
-- 1. PAYER TABLE FIXES
-- ==========================================================================================================

-- Add classification column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'payer' 
        AND column_name = 'classification'
    ) THEN
        ALTER TABLE claims_ref.payer ADD COLUMN classification TEXT;
        RAISE NOTICE 'Added classification column to payer table';
    ELSE
        RAISE NOTICE 'Classification column already exists in payer table';
    END IF;
END $$;

-- Fix updated_at default value if missing
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'payer' 
        AND column_name = 'updated_at'
        AND column_default IS NULL
    ) THEN
        ALTER TABLE claims_ref.payer ALTER COLUMN updated_at SET DEFAULT NOW();
        RAISE NOTICE 'Set default value for updated_at column in payer table';
    END IF;
END $$;

-- ==========================================================================================================
-- 2. ACTIVITY_CODE TABLE FIXES
-- ==========================================================================================================

-- Add type column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'activity_code' 
        AND column_name = 'type'
    ) THEN
        ALTER TABLE claims_ref.activity_code ADD COLUMN type TEXT;
        RAISE NOTICE 'Added type column to activity_code table';
    ELSE
        RAISE NOTICE 'Type column already exists in activity_code table';
    END IF;
END $$;

-- Fix unique constraint (drop old, add new)
DO $$
BEGIN
    -- Drop the old unique constraint if it exists
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'uq_activity_code' 
        AND conrelid = 'claims_ref.activity_code'::regclass
    ) THEN
        ALTER TABLE claims_ref.activity_code DROP CONSTRAINT uq_activity_code;
        RAISE NOTICE 'Dropped old unique constraint on activity_code';
    END IF;
    
    -- Add the correct unique constraint
    ALTER TABLE claims_ref.activity_code ADD CONSTRAINT uq_activity_code UNIQUE (code, type);
    RAISE NOTICE 'Added correct unique constraint (code, type) to activity_code';
END $$;

-- Fix updated_at default value if missing
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'activity_code' 
        AND column_name = 'updated_at'
        AND column_default IS NULL
    ) THEN
        ALTER TABLE claims_ref.activity_code ALTER COLUMN updated_at SET DEFAULT NOW();
        RAISE NOTICE 'Set default value for updated_at column in activity_code table';
    END IF;
END $$;

-- ==========================================================================================================
-- 3. FACILITY TABLE FIXES
-- ==========================================================================================================

-- Fix updated_at default value if missing
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'facility' 
        AND column_name = 'updated_at'
        AND column_default IS NULL
    ) THEN
        ALTER TABLE claims_ref.facility ALTER COLUMN updated_at SET DEFAULT NOW();
        RAISE NOTICE 'Set default value for updated_at column in facility table';
    END IF;
END $$;

-- ==========================================================================================================
-- 4. CLINICIAN TABLE FIXES
-- ==========================================================================================================

-- Fix updated_at default value if missing
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'clinician' 
        AND column_name = 'updated_at'
        AND column_default IS NULL
    ) THEN
        ALTER TABLE claims_ref.clinician ALTER COLUMN updated_at SET DEFAULT NOW();
        RAISE NOTICE 'Set default value for updated_at column in clinician table';
    END IF;
END $$;

-- ==========================================================================================================
-- 5. DIAGNOSIS_CODE TABLE FIXES
-- ==========================================================================================================

-- Fix updated_at default value if missing
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'diagnosis_code' 
        AND column_name = 'updated_at'
        AND column_default IS NULL
    ) THEN
        ALTER TABLE claims_ref.diagnosis_code ALTER COLUMN updated_at SET DEFAULT NOW();
        RAISE NOTICE 'Set default value for updated_at column in diagnosis_code table';
    END IF;
END $$;

-- ==========================================================================================================
-- 6. DENIAL_CODE TABLE FIXES
-- ==========================================================================================================

-- Fix updated_at default value if missing
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'denial_code' 
        AND column_name = 'updated_at'
        AND column_default IS NULL
    ) THEN
        ALTER TABLE claims_ref.denial_code ALTER COLUMN updated_at SET DEFAULT NOW();
        RAISE NOTICE 'Set default value for updated_at column in denial_code table';
    END IF;
END $$;

-- ==========================================================================================================
-- 7. PROVIDER TABLE FIXES
-- ==========================================================================================================

-- Fix updated_at default value if missing
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'provider' 
        AND column_name = 'updated_at'
        AND column_default IS NULL
    ) THEN
        ALTER TABLE claims_ref.provider ALTER COLUMN updated_at SET DEFAULT NOW();
        RAISE NOTICE 'Set default value for updated_at column in provider table';
    END IF;
END $$;

-- ==========================================================================================================
-- 8. FIX ANY BYTEA COLUMN TYPES (if they exist)
-- ==========================================================================================================

DO $$
DECLARE
    table_name TEXT;
    column_name TEXT;
    tables TEXT[] := ARRAY['facility', 'payer', 'provider', 'clinician', 'diagnosis_code', 'activity_code', 'denial_code'];
    text_columns TEXT[] := ARRAY['facility_code', 'name', 'city', 'country', 'status', 'payer_code', 'classification', 
                                 'clinician_code', 'specialty', 'code', 'code_system', 'description', 'type'];
BEGIN
    FOREACH table_name IN ARRAY tables
    LOOP
        FOREACH column_name IN ARRAY text_columns
        LOOP
            -- Check if column exists and is bytea type
            IF EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_schema = 'claims_ref' 
                AND table_name = table_name
                AND column_name = column_name
                AND data_type = 'bytea'
            ) THEN
                EXECUTE format('ALTER TABLE claims_ref.%I ALTER COLUMN %I TYPE TEXT USING %I::TEXT', 
                              table_name, column_name, column_name);
                RAISE NOTICE 'Converted % column in % table from bytea to TEXT', column_name, table_name;
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- ==========================================================================================================
-- 9. ADD MISSING INDEXES
-- ==========================================================================================================

-- Add index for activity_code type column
CREATE INDEX IF NOT EXISTS idx_activity_code_type ON claims_ref.activity_code(type);

-- Add index for payer classification
CREATE INDEX IF NOT EXISTS idx_payer_classification ON claims_ref.payer(classification);

-- ==========================================================================================================
-- VERIFICATION
-- ==========================================================================================================

-- Show final table structures
SELECT 'Final table structures after ALTER statements:' as info;
SELECT 
    table_schema,
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'claims_ref' 
AND table_name IN ('facility', 'payer', 'clinician', 'diagnosis_code', 'activity_code', 'denial_code')
ORDER BY table_name, ordinal_position;

-- Test the lower() function to ensure bytea issues are resolved
SELECT 'Testing lower() function on facility table...' as test_message;
SELECT COUNT(*) as facility_count FROM claims_ref.facility WHERE lower(facility_code) LIKE '%test%';

SELECT 'Testing lower() function on payer table...' as test_message;
SELECT COUNT(*) as payer_count FROM claims_ref.payer WHERE lower(payer_code) LIKE '%test%';

SELECT 'Testing lower() function on activity_code table...' as test_message;
SELECT COUNT(*) as activity_count FROM claims_ref.activity_code WHERE lower(code) LIKE '%test%';

SELECT 'All ALTER statements completed successfully!' as completion_message;
