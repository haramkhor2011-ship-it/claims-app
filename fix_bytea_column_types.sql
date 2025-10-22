-- ==========================================================================================================
-- FIX BYTEA COLUMN TYPES ISSUE
-- ==========================================================================================================
-- 
-- Purpose: Fix columns that were incorrectly created as bytea instead of TEXT
-- Issue: PostgreSQL doesn't have lower(bytea) function, causing cache refresh failures
-- 
-- This script converts bytea columns back to TEXT type for proper string operations
--
-- ==========================================================================================================

-- Fix facility table columns
DO $$
BEGIN
    -- Check if facility_code is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'facility' 
        AND column_name = 'facility_code' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.facility ALTER COLUMN facility_code TYPE TEXT USING facility_code::TEXT;
        RAISE NOTICE 'Converted facility_code from bytea to TEXT';
    END IF;
    
    -- Check if name is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'facility' 
        AND column_name = 'name' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.facility ALTER COLUMN name TYPE TEXT USING name::TEXT;
        RAISE NOTICE 'Converted facility name from bytea to TEXT';
    END IF;
    
    -- Check if city is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'facility' 
        AND column_name = 'city' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.facility ALTER COLUMN city TYPE TEXT USING city::TEXT;
        RAISE NOTICE 'Converted facility city from bytea to TEXT';
    END IF;
    
    -- Check if country is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'facility' 
        AND column_name = 'country' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.facility ALTER COLUMN country TYPE TEXT USING country::TEXT;
        RAISE NOTICE 'Converted facility country from bytea to TEXT';
    END IF;
    
    -- Check if status is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'facility' 
        AND column_name = 'status' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.facility ALTER COLUMN status TYPE TEXT USING status::TEXT;
        RAISE NOTICE 'Converted facility status from bytea to TEXT';
    END IF;
END $$;

-- Fix payer table columns
DO $$
BEGIN
    -- Check if payer_code is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'payer' 
        AND column_name = 'payer_code' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.payer ALTER COLUMN payer_code TYPE TEXT USING payer_code::TEXT;
        RAISE NOTICE 'Converted payer_code from bytea to TEXT';
    END IF;
    
    -- Check if name is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'payer' 
        AND column_name = 'name' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.payer ALTER COLUMN name TYPE TEXT USING name::TEXT;
        RAISE NOTICE 'Converted payer name from bytea to TEXT';
    END IF;
    
    -- Check if status is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'payer' 
        AND column_name = 'status' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.payer ALTER COLUMN status TYPE TEXT USING status::TEXT;
        RAISE NOTICE 'Converted payer status from bytea to TEXT';
    END IF;
    
    -- Check if classification is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'payer' 
        AND column_name = 'classification' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.payer ALTER COLUMN classification TYPE TEXT USING classification::TEXT;
        RAISE NOTICE 'Converted payer classification from bytea to TEXT';
    END IF;
END $$;

-- Fix clinician table columns
DO $$
BEGIN
    -- Check if clinician_code is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'clinician' 
        AND column_name = 'clinician_code' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.clinician ALTER COLUMN clinician_code TYPE TEXT USING clinician_code::TEXT;
        RAISE NOTICE 'Converted clinician_code from bytea to TEXT';
    END IF;
    
    -- Check if name is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'clinician' 
        AND column_name = 'name' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.clinician ALTER COLUMN name TYPE TEXT USING name::TEXT;
        RAISE NOTICE 'Converted clinician name from bytea to TEXT';
    END IF;
    
    -- Check if specialty is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'clinician' 
        AND column_name = 'specialty' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.clinician ALTER COLUMN specialty TYPE TEXT USING specialty::TEXT;
        RAISE NOTICE 'Converted clinician specialty from bytea to TEXT';
    END IF;
    
    -- Check if status is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'clinician' 
        AND column_name = 'status' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.clinician ALTER COLUMN status TYPE TEXT USING status::TEXT;
        RAISE NOTICE 'Converted clinician status from bytea to TEXT';
    END IF;
END $$;

-- Fix diagnosis_code table columns
DO $$
BEGIN
    -- Check if code is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'diagnosis_code' 
        AND column_name = 'code' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.diagnosis_code ALTER COLUMN code TYPE TEXT USING code::TEXT;
        RAISE NOTICE 'Converted diagnosis_code code from bytea to TEXT';
    END IF;
    
    -- Check if code_system is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'diagnosis_code' 
        AND column_name = 'code_system' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.diagnosis_code ALTER COLUMN code_system TYPE TEXT USING code_system::TEXT;
        RAISE NOTICE 'Converted diagnosis_code code_system from bytea to TEXT';
    END IF;
    
    -- Check if description is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'diagnosis_code' 
        AND column_name = 'description' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.diagnosis_code ALTER COLUMN description TYPE TEXT USING description::TEXT;
        RAISE NOTICE 'Converted diagnosis_code description from bytea to TEXT';
    END IF;
    
    -- Check if status is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'diagnosis_code' 
        AND column_name = 'status' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.diagnosis_code ALTER COLUMN status TYPE TEXT USING status::TEXT;
        RAISE NOTICE 'Converted diagnosis_code status from bytea to TEXT';
    END IF;
END $$;

-- Fix activity_code table columns
DO $$
BEGIN
    -- Check if type is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'activity_code' 
        AND column_name = 'type' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.activity_code ALTER COLUMN type TYPE TEXT USING type::TEXT;
        RAISE NOTICE 'Converted activity_code type from bytea to TEXT';
    END IF;
    
    -- Check if code is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'activity_code' 
        AND column_name = 'code' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.activity_code ALTER COLUMN code TYPE TEXT USING code::TEXT;
        RAISE NOTICE 'Converted activity_code code from bytea to TEXT';
    END IF;
    
    -- Check if code_system is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'activity_code' 
        AND column_name = 'code_system' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.activity_code ALTER COLUMN code_system TYPE TEXT USING code_system::TEXT;
        RAISE NOTICE 'Converted activity_code code_system from bytea to TEXT';
    END IF;
    
    -- Check if description is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'activity_code' 
        AND column_name = 'description' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.activity_code ALTER COLUMN description TYPE TEXT USING description::TEXT;
        RAISE NOTICE 'Converted activity_code description from bytea to TEXT';
    END IF;
    
    -- Check if status is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'activity_code' 
        AND column_name = 'status' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.activity_code ALTER COLUMN status TYPE TEXT USING status::TEXT;
        RAISE NOTICE 'Converted activity_code status from bytea to TEXT';
    END IF;
END $$;

-- Fix denial_code table columns
DO $$
BEGIN
    -- Check if code is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'denial_code' 
        AND column_name = 'code' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.denial_code ALTER COLUMN code TYPE TEXT USING code::TEXT;
        RAISE NOTICE 'Converted denial_code code from bytea to TEXT';
    END IF;
    
    -- Check if description is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'denial_code' 
        AND column_name = 'description' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.denial_code ALTER COLUMN description TYPE TEXT USING description::TEXT;
        RAISE NOTICE 'Converted denial_code description from bytea to TEXT';
    END IF;
    
    -- Check if payer_code is bytea and convert to TEXT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'claims_ref' 
        AND table_name = 'denial_code' 
        AND column_name = 'payer_code' 
        AND data_type = 'bytea'
    ) THEN
        ALTER TABLE claims_ref.denial_code ALTER COLUMN payer_code TYPE TEXT USING payer_code::TEXT;
        RAISE NOTICE 'Converted denial_code payer_code from bytea to TEXT';
    END IF;
END $$;

-- Verify the fixes
SELECT 
    table_schema,
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'claims_ref' 
AND table_name IN ('facility', 'payer', 'clinician', 'diagnosis_code', 'activity_code', 'denial_code')
AND column_name IN ('facility_code', 'name', 'city', 'country', 'status', 'payer_code', 'classification', 
                   'clinician_code', 'specialty', 'code', 'code_system', 'description', 'type')
ORDER BY table_name, column_name;

-- Test the lower() function on a sample query
SELECT 'Testing lower() function on facility table...' as test_message;
SELECT COUNT(*) as facility_count FROM claims_ref.facility WHERE lower(facility_code) LIKE '%test%';

SELECT 'Bytea column type fix completed successfully!' as completion_message;
