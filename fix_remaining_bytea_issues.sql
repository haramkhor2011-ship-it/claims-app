-- ==========================================================================================================
-- FINAL FIXES FOR REMAINING ERRORS
-- ==========================================================================================================
-- 
-- Issues Found in Logs:
-- 1. DatabaseHealthMetrics null pointer still occurring (line 303)
-- 2. ERROR: function lower(bytea) does not exist on facility table
--
-- ==========================================================================================================

-- ==========================================================================================================
-- 1. FIX BYTEA COLUMN TYPES IN FACILITY TABLE
-- ==========================================================================================================

-- Check current data types
SELECT 'Current facility table column types:' as info;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'claims_ref' 
AND table_name = 'facility' 
AND column_name IN ('facility_code', 'name', 'city', 'country', 'status');

-- Fix any bytea columns to TEXT
DO $$
DECLARE
    col_name TEXT;
    text_columns TEXT[] := ARRAY['facility_code', 'name', 'city', 'country', 'status'];
BEGIN
    FOREACH col_name IN ARRAY text_columns
    LOOP
        -- Check if column exists and is bytea type
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'claims_ref' 
            AND table_name = 'facility' 
            AND column_name = col_name
            AND data_type = 'bytea'
        ) THEN
            EXECUTE format('ALTER TABLE claims_ref.facility ALTER COLUMN %I TYPE TEXT USING %I::TEXT', 
                          col_name, col_name);
            RAISE NOTICE 'Converted % column in facility table from bytea to TEXT', col_name;
        ELSE
            RAISE NOTICE 'Column % in facility table is already TEXT or does not exist', col_name;
        END IF;
    END LOOP;
END $$;

-- ==========================================================================================================
-- 2. FIX BYTEA COLUMN TYPES IN ALL OTHER TABLES
-- ==========================================================================================================

DO $$
DECLARE
    table_name TEXT;
    column_name TEXT;
    tables TEXT[] := ARRAY['payer', 'provider', 'clinician', 'diagnosis_code', 'activity_code', 'denial_code'];
    text_columns TEXT[] := ARRAY['payer_code', 'name', 'status', 'classification', 
                                 'provider_code', 'clinician_code', 'specialty', 
                                 'code', 'code_system', 'description', 'type'];
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
-- 3. VERIFICATION
-- ==========================================================================================================

-- Check final column types
SELECT 'Final facility table column types:' as info;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'claims_ref' 
AND table_name = 'facility' 
AND column_name IN ('facility_code', 'name', 'city', 'country', 'status');

-- Test the lower() function
SELECT 'Testing lower() function on facility table...' as test;
SELECT COUNT(*) as facility_count FROM claims_ref.facility WHERE lower(facility_code) LIKE '%test%';

-- Check for any remaining bytea columns
SELECT 'Remaining bytea columns:' as info;
SELECT table_name, column_name, data_type
FROM information_schema.columns 
WHERE table_schema = 'claims_ref' 
AND data_type = 'bytea'
ORDER BY table_name, column_name;

SELECT 'All bytea fixes completed!' as completion_message;
