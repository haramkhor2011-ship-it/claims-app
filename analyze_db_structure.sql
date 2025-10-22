-- ==========================================================================================================
-- DATABASE STRUCTURE ANALYSIS QUERIES
-- ==========================================================================================================
-- 
-- Run these queries and provide the output so we can create precise ALTER statements
--
-- ==========================================================================================================

-- 1. Get current table structures for all claims_ref tables
SELECT 
    table_schema,
    table_name,
    column_name,
    ordinal_position,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns 
WHERE table_schema = 'claims_ref' 
AND table_name IN ('facility', 'payer', 'provider', 'clinician', 'diagnosis_code', 'activity_code', 'denial_code')
ORDER BY table_name, ordinal_position;

-- 2. Get current constraints (especially unique constraints)
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

-- 3. Get current indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'claims_ref' 
AND tablename IN ('facility', 'payer', 'provider', 'clinician', 'diagnosis_code', 'activity_code', 'denial_code')
ORDER BY tablename, indexname;

-- 4. Check for any bytea columns specifically
SELECT 
    table_schema,
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'claims_ref' 
AND data_type = 'bytea'
ORDER BY table_name, column_name;

-- 5. Test if lower() function works on text columns (this will show bytea issues)
SELECT 'Testing facility table...' as test;
SELECT 
    column_name,
    data_type,
    CASE 
        WHEN data_type = 'bytea' THEN 'BYTEA - WILL CAUSE LOWER() ERROR'
        ELSE 'TEXT - OK'
    END as status
FROM information_schema.columns 
WHERE table_schema = 'claims_ref' 
AND table_name = 'facility' 
AND column_name IN ('facility_code', 'name', 'city', 'country', 'status');

SELECT 'Testing payer table...' as test;
SELECT 
    column_name,
    data_type,
    CASE 
        WHEN data_type = 'bytea' THEN 'BYTEA - WILL CAUSE LOWER() ERROR'
        ELSE 'TEXT - OK'
    END as status
FROM information_schema.columns 
WHERE table_schema = 'claims_ref' 
AND table_name = 'payer' 
AND column_name IN ('payer_code', 'name', 'status', 'classification');

SELECT 'Testing activity_code table...' as test;
SELECT 
    column_name,
    data_type,
    CASE 
        WHEN data_type = 'bytea' THEN 'BYTEA - WILL CAUSE LOWER() ERROR'
        ELSE 'TEXT - OK'
    END as status
FROM information_schema.columns 
WHERE table_schema = 'claims_ref' 
AND table_name = 'activity_code' 
AND column_name IN ('code', 'code_system', 'description', 'type');

-- 6. Check if specific columns exist
SELECT 
    table_name,
    column_name,
    CASE 
        WHEN column_name IS NOT NULL THEN 'EXISTS'
        ELSE 'MISSING'
    END as status
FROM (
    SELECT 'facility' as table_name, 'facility_code' as column_name
    UNION ALL SELECT 'facility', 'name'
    UNION ALL SELECT 'facility', 'city'
    UNION ALL SELECT 'facility', 'country'
    UNION ALL SELECT 'facility', 'status'
    UNION ALL SELECT 'facility', 'created_at'
    UNION ALL SELECT 'facility', 'updated_at'
    
    UNION ALL SELECT 'payer', 'payer_code'
    UNION ALL SELECT 'payer', 'name'
    UNION ALL SELECT 'payer', 'status'
    UNION ALL SELECT 'payer', 'classification'
    UNION ALL SELECT 'payer', 'created_at'
    UNION ALL SELECT 'payer', 'updated_at'
    
    UNION ALL SELECT 'activity_code', 'code'
    UNION ALL SELECT 'activity_code', 'code_system'
    UNION ALL SELECT 'activity_code', 'description'
    UNION ALL SELECT 'activity_code', 'type'
    UNION ALL SELECT 'activity_code', 'status'
    UNION ALL SELECT 'activity_code', 'created_at'
    UNION ALL SELECT 'activity_code', 'updated_at'
) expected
LEFT JOIN information_schema.columns ic 
    ON ic.table_schema = 'claims_ref' 
    AND ic.table_name = expected.table_name 
    AND ic.column_name = expected.column_name
ORDER BY table_name, column_name;
