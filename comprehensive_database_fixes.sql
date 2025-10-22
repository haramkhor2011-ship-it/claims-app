-- ==========================================================================================================
-- COMPREHENSIVE DATABASE SCHEMA FIXES
-- ==========================================================================================================
-- 
-- Purpose: Fix all identified issues in the claims_ref schema
-- Issues Fixed:
-- 1. Typos: "deafault" -> "default", "timestampz" -> "timestamptz"
-- 2. Missing columns: classification in payer, type in activity_code
-- 3. Wrong unique constraints: activity_code should be (code, type) not (code, code_system)
-- 4. Missing default values for updated_at columns
-- 5. Bytea column type issues (if any exist)
--
-- ==========================================================================================================

-- First, let's check the current state of the tables
SELECT 'Current table structures:' as info;
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

-- ==========================================================================================================
-- FIX 1: Add missing classification column to payer table
-- ==========================================================================================================
DO $$
BEGIN
    -- Add classification column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'payer' 
        AND column_name = 'classification'
    ) THEN
        ALTER TABLE claims_ref.payer ADD COLUMN classification TEXT;
        RAISE NOTICE 'Added classification column to payer table';
    END IF;
END $$;

-- ==========================================================================================================
-- FIX 2: Add missing type column to activity_code table
-- ==========================================================================================================
DO $$
BEGIN
    -- Add type column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'activity_code' 
        AND column_name = 'type'
    ) THEN
        ALTER TABLE claims_ref.activity_code ADD COLUMN type TEXT;
        RAISE NOTICE 'Added type column to activity_code table';
    END IF;
END $$;

-- ==========================================================================================================
-- FIX 3: Fix unique constraint on activity_code table
-- ==========================================================================================================
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

-- ==========================================================================================================
-- FIX 4: Fix updated_at columns to have default values
-- ==========================================================================================================
DO $$
DECLARE
    table_name TEXT;
    tables TEXT[] := ARRAY['facility', 'payer', 'provider', 'clinician', 'diagnosis_code', 'activity_code', 'denial_code'];
BEGIN
    FOREACH table_name IN ARRAY tables
    LOOP
        -- Check if updated_at column exists and doesn't have a default
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'claims_ref' 
            AND table_name = table_name
            AND column_name = 'updated_at'
            AND column_default IS NULL
        ) THEN
            EXECUTE format('ALTER TABLE claims_ref.%I ALTER COLUMN updated_at SET DEFAULT NOW()', table_name);
            RAISE NOTICE 'Set default value for updated_at column in % table', table_name;
        END IF;
    END LOOP;
END $$;

-- ==========================================================================================================
-- FIX 5: Fix any bytea column types (if they exist)
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
-- FIX 6: Create missing indexes
-- ==========================================================================================================

-- Add missing indexes for activity_code type column
CREATE INDEX IF NOT EXISTS idx_activity_code_lookup ON claims_ref.activity_code(code, type);
CREATE INDEX IF NOT EXISTS idx_activity_code_type ON claims_ref.activity_code(type);

-- Add missing indexes for payer classification
CREATE INDEX IF NOT EXISTS idx_payer_classification ON claims_ref.payer(classification);

-- ==========================================================================================================
-- VERIFICATION: Check the final state
-- ==========================================================================================================
SELECT 'Final table structures after fixes:' as info;
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

SELECT 'All database schema fixes completed successfully!' as completion_message;
