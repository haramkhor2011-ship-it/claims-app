-- ==========================================================================================================
-- PRECISE ALTER STATEMENTS BASED ON CURRENT DB STRUCTURE ANALYSIS
-- ==========================================================================================================
-- 
-- Issues Found:
-- 1. activity_code has wrong unique constraint: (code, code_system) instead of (code, type)
-- 2. Missing created_at columns in several tables
-- 3. Wrong created_at data type in facility and payer tables
--
-- ==========================================================================================================

-- ==========================================================================================================
-- 1. FIX ACTIVITY_CODE UNIQUE CONSTRAINT
-- ==========================================================================================================

-- Drop the wrong unique constraint
ALTER TABLE claims_ref.activity_code DROP CONSTRAINT uq_activity_code;

-- Add the correct unique constraint (code, type) as expected by entity
ALTER TABLE claims_ref.activity_code ADD CONSTRAINT uq_activity_code UNIQUE (code, type);

-- ==========================================================================================================
-- 2. ADD MISSING CREATED_AT COLUMNS
-- ==========================================================================================================

-- Add created_at to activity_code table
ALTER TABLE claims_ref.activity_code ADD COLUMN created_at TIMESTAMPTZ DEFAULT NOW();

-- Add created_at to clinician table  
ALTER TABLE claims_ref.clinician ADD COLUMN created_at TIMESTAMPTZ DEFAULT NOW();

-- Add created_at to denial_code table
ALTER TABLE claims_ref.denial_code ADD COLUMN created_at TIMESTAMPTZ DEFAULT NOW();

-- Add created_at to diagnosis_code table
ALTER TABLE claims_ref.diagnosis_code ADD COLUMN created_at TIMESTAMPTZ DEFAULT NOW();

-- Add created_at to provider table
ALTER TABLE claims_ref.provider ADD COLUMN created_at TIMESTAMPTZ DEFAULT NOW();

-- ==========================================================================================================
-- 3. FIX CREATED_AT DATA TYPES
-- ==========================================================================================================

-- Fix facility created_at from timestamp without time zone to timestamp with time zone
ALTER TABLE claims_ref.facility ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at::TIMESTAMPTZ;

-- Fix payer created_at from timestamp without time zone to timestamp with time zone  
ALTER TABLE claims_ref.payer ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at::TIMESTAMPTZ;

-- ==========================================================================================================
-- 4. VERIFICATION QUERIES
-- ==========================================================================================================

-- Check final table structures
SELECT 'Final table structures after fixes:' as info;
SELECT 
    table_schema,
    table_name,
    column_name,
    ordinal_position,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'claims_ref' 
AND table_name IN ('facility', 'payer', 'provider', 'clinician', 'diagnosis_code', 'activity_code', 'denial_code')
ORDER BY table_name, ordinal_position;

-- Check constraints
SELECT 'Final constraints:' as info;
SELECT 
    tc.table_schema,
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    kcu.ordinal_position
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name 
    AND tc.table_schema = kcu.table_schema
WHERE tc.table_schema = 'claims_ref' 
AND tc.table_name IN ('facility', 'payer', 'provider', 'clinician', 'diagnosis_code', 'activity_code', 'denial_code')
AND tc.constraint_type IN ('UNIQUE', 'PRIMARY KEY')
ORDER BY tc.table_name, tc.constraint_name, kcu.ordinal_position;

-- Test that lower() function works (should not have bytea issues)
SELECT 'Testing lower() function...' as test;
SELECT COUNT(*) as facility_count FROM claims_ref.facility WHERE lower(facility_code) LIKE '%test%';
SELECT COUNT(*) as payer_count FROM claims_ref.payer WHERE lower(payer_code) LIKE '%test%';
SELECT COUNT(*) as activity_count FROM claims_ref.activity_code WHERE lower(code) LIKE '%test%';

SELECT 'All ALTER statements completed successfully!' as completion_message;
