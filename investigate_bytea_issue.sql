-- ==========================================================================================================
-- INVESTIGATE BYTEA ISSUE - TEST QUERIES
-- ==========================================================================================================
-- 
-- Purpose: Test if the columns are actually bytea or if it's a Hibernate interpretation issue
--
-- ==========================================================================================================

-- Test 1: Check actual column types
SELECT 'Actual column types in facility table:' as test;
SELECT column_name, data_type, character_maximum_length
FROM information_schema.columns 
WHERE table_schema = 'claims_ref' 
AND table_name = 'facility' 
ORDER BY ordinal_position;

-- Test 2: Try the exact query that's failing
SELECT 'Testing the failing query manually:' as test;
SELECT f1_0.id, f1_0.city, f1_0.country, f1_0.created_at, f1_0.facility_code, f1_0.name, f1_0.status, f1_0.updated_at 
FROM claims_ref.facility f1_0 
WHERE (NULL IS NULL OR lower(f1_0.facility_code) LIKE lower(('%'||NULL||'%')) ESCAPE '' OR lower(f1_0.name) LIKE lower(('%'||NULL||'%')) ESCAPE '') 
AND (NULL IS NULL OR f1_0.status = NULL) 
ORDER BY f1_0.facility_code, f1_0.name 
FETCH FIRST 10 ROWS ONLY;

-- Test 3: Test lower() function on each column individually
SELECT 'Testing lower() on facility_code:' as test;
SELECT COUNT(*) FROM claims_ref.facility WHERE lower(facility_code) LIKE '%test%';

SELECT 'Testing lower() on name:' as test;
SELECT COUNT(*) FROM claims_ref.facility WHERE lower(name) LIKE '%test%';

SELECT 'Testing lower() on city:' as test;
SELECT COUNT(*) FROM claims_ref.facility WHERE lower(city) LIKE '%test%';

SELECT 'Testing lower() on country:' as test;
SELECT COUNT(*) FROM claims_ref.facility WHERE lower(country) LIKE '%test%';

SELECT 'Testing lower() on status:' as test;
SELECT COUNT(*) FROM claims_ref.facility WHERE lower(status) LIKE '%test%';

-- Test 4: Check if there are any bytea columns
SELECT 'Checking for bytea columns:' as test;
SELECT table_name, column_name, data_type
FROM information_schema.columns 
WHERE table_schema = 'claims_ref' 
AND data_type = 'bytea'
ORDER BY table_name, column_name;

-- Test 5: Check Hibernate metadata interpretation
SELECT 'Checking column metadata:' as test;
SELECT 
    c.column_name,
    c.data_type,
    c.character_maximum_length,
    c.numeric_precision,
    c.numeric_scale,
    c.is_nullable,
    c.column_default
FROM information_schema.columns c
WHERE c.table_schema = 'claims_ref' 
AND c.table_name = 'facility'
ORDER BY c.ordinal_position;

-- Test 6: Try explicit casting
SELECT 'Testing explicit casting:' as test;
SELECT COUNT(*) FROM claims_ref.facility WHERE lower(facility_code::TEXT) LIKE '%test%';
SELECT COUNT(*) FROM claims_ref.facility WHERE lower(name::TEXT) LIKE '%test%';

SELECT 'Investigation complete!' as completion_message;
