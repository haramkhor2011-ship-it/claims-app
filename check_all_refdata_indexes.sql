-- Check all indexes (including unique constraints) on refdata tables
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'claims_ref'
ORDER BY tablename, indexname;







