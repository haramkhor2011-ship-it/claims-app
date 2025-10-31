-- ==========================================================================================================
-- DATABASE CONSTRAINT AND INDEX INSPECTION QUERY
-- ==========================================================================================================
-- 
-- Purpose: Inspect current database structure for unique constraints and indexes
-- Run this query and share the output to verify which constraints exist
-- 
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: UNIQUE CONSTRAINTS (Named Constraints)
-- ==========================================================================================================

SELECT 
    '=== UNIQUE CONSTRAINTS ===' as section,
    con.conname as constraint_name,
    sch.nspname as schema_name,
    tab.relname as table_name,
    pg_get_constraintdef(con.oid) as constraint_definition,
    array_agg(a.attname ORDER BY array_position(con.conkey, a.attnum)) as column_names
FROM pg_constraint con
JOIN pg_class tab ON con.conrelid = tab.oid
JOIN pg_namespace sch ON tab.relnamespace = sch.oid
LEFT JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = ANY(con.conkey)
WHERE con.contype = 'u'
AND sch.nspname IN ('claims_ref', 'claims')
GROUP BY con.oid, con.conname, sch.nspname, tab.relname
ORDER BY sch.nspname, tab.relname, con.conname;

-- ==========================================================================================================
-- SECTION 2: UNIQUE INDEXES (Not Named Constraints)
-- ==========================================================================================================

SELECT 
    '=== UNIQUE INDEXES ===' as section,
    i.indexname as index_name,
    schemaname as schema_name,
    tablename as table_name,
    indexdef as index_definition
FROM pg_indexes i
WHERE schemaname IN ('claims_ref', 'claims')
AND indexdef LIKE '%UNIQUE%'
ORDER BY schemaname, tablename, indexname;

-- ==========================================================================================================
-- SECTION 3: TABLES WITH ON CONFLICT USAGE (From Code Analysis)
-- ==========================================================================================================
-- These tables are used in ON CONFLICT clauses in the application code

SELECT 
    '=== ON CONFLICT TABLES SUMMARY ===' as section,
    sch.nspname as schema_name,
    tab.relname as table_name,
    'Has constraints: ' || COALESCE(
        (SELECT COUNT(*)::text FROM pg_constraint c 
         WHERE c.conrelid = tab.oid AND c.contype = 'u'), '0'
    ) as unique_constraints_count,
    'Has unique indexes: ' || COALESCE(
        (SELECT COUNT(*)::text FROM pg_indexes idx 
         WHERE idx.schemaname = sch.nspname 
         AND idx.tablename = tab.relname 
         AND idx.indexdef LIKE '%UNIQUE%'), '0'
    ) as unique_indexes_count
FROM pg_class tab
JOIN pg_namespace sch ON tab.relnamespace = sch.oid
WHERE sch.nspname IN ('claims_ref', 'claims')
AND tab.relname IN (
    -- Reference data tables
    'facility', 'payer', 'provider', 'clinician', 'activity_code', 'diagnosis_code', 'denial_code',
    -- Core tables
    'ingestion_file', 'submission', 'remittance', 'claim_key', 'claim', 'activity', 
    'remittance_claim', 'remittance_activity', 'claim_event', 'claim_resubmission',
    'diagnosis', 'claim_event_activity', 'event_observation', 'claim_attachment',
    'claim_contract', 'integration_toggle', 'facility_dhpo_config'
)
ORDER BY sch.nspname, tab.relname;

-- ==========================================================================================================
-- SECTION 4: DETAILED CONSTRAINT MAPPING (For ON CONFLICT Verification)
-- ==========================================================================================================

SELECT 
    '=== DETAILED CONSTRAINT MAPPING ===' as section,
    'Expected Constraint' as constraint_expected,
    sch.nspname || '.' || tab.relname as table_name,
    COALESCE(con.conname, 'NOT FOUND') as actual_constraint_name,
    CASE 
        WHEN con.conname IS NOT NULL THEN 'EXISTS'
        WHEN EXISTS (
            SELECT 1 FROM pg_indexes idx 
            WHERE idx.schemaname = sch.nspname 
            AND idx.tablename = tab.relname 
            AND idx.indexdef LIKE '%UNIQUE%'
            AND idx.indexdef LIKE '%' || col_cols.cols || '%'
        ) THEN 'EXISTS AS INDEX'
        ELSE 'MISSING'
    END as status
FROM (
    VALUES
        -- Reference data constraints
        ('claims_ref', 'facility', 'uq_facility_code', 'facility_code'),
        ('claims_ref', 'payer', 'uq_payer_code', 'payer_code'),
        ('claims_ref', 'provider', 'uq_provider_code', 'provider_code'),
        ('claims_ref', 'clinician', 'uq_clinician_code', 'clinician_code'),
        ('claims_ref', 'activity_code', 'uq_activity_code', 'code, type'),
        ('claims_ref', 'diagnosis_code', 'uq_diagnosis_code', 'code'),
        ('claims_ref', 'denial_code', 'uq_denial_code', 'code'),
        -- Core constraints
        ('claims', 'ingestion_file', 'uq_ingestion_file', 'file_id'),
        ('claims', 'submission', 'uq_submission_per_file', 'ingestion_file_id'),
        ('claims', 'remittance', 'uq_remittance_per_file', 'ingestion_file_id'),
        ('claims', 'claim_key', 'uq_claim_key_claim_id', 'claim_id'),
        ('claims', 'claim', 'uq_claim_per_key', 'claim_key_id'),
        ('claims', 'activity', 'uq_activity_bk', 'claim_id, activity_id'),
        ('claims', 'remittance_claim', 'uq_remittance_claim', 'remittance_id, claim_key_id'),
        ('claims', 'remittance_activity', 'uq_remittance_activity', 'remittance_claim_id, activity_id'),
        ('claims', 'claim_event', 'uq_claim_event_dedup', 'claim_key_id, type, event_time'),
        ('claims', 'claim_resubmission', 'uq_claim_resubmission_event', 'claim_event_id'),
        ('claims', 'integration_toggle', 'PRIMARY KEY', 'code'),  -- PRIMARY KEY used
        ('claims', 'facility_dhpo_config', 'uq_facility_dhpo_config', 'facility_code'),
        ('claims', 'claim_contract', 'NO CONSTRAINT', 'package_name')  -- Uses column-based ON CONFLICT
) AS expected(expected_schema, expected_table, expected_constraint, cols)
JOIN pg_namespace sch ON sch.nspname = expected.expected_schema
JOIN pg_class tab ON tab.relnamespace = sch.oid AND tab.relname = expected.expected_table
LEFT JOIN pg_constraint con ON con.conrelid = tab.oid AND con.conname = expected.expected_constraint
LEFT JOIN LATERAL (
    SELECT string_agg(a.attname, ', ' ORDER BY array_position(con.conkey, a.attnum)) as cols
    FROM pg_attribute a 
    WHERE a.attrelid = con.conrelid AND a.attnum = ANY(con.conkey)
) col_cols ON true
ORDER BY sch.nspname, tab.relname;

-- ==========================================================================================================
-- SECTION 5: TABLES WITH UNIQUE INDEXES ONLY (No Named Constraints)
-- ==========================================================================================================
-- These use column-based ON CONFLICT syntax in code

SELECT 
    '=== UNIQUE INDEXES (No Named Constraint) ===' as section,
    i.schemaname as schema_name,
    i.tablename as table_name,
    i.indexname as index_name,
    i.indexdef as index_definition,
    'Uses: ON CONFLICT (columns)' as conflict_syntax
FROM pg_indexes i
WHERE i.schemaname IN ('claims_ref', 'claims')
AND i.indexdef LIKE '%UNIQUE%'
AND i.indexname IN (
    'uq_diagnosis_claim_type_code',           -- Used in PersistService for diagnosis
    'uq_claim_event_activity_key',             -- Used in PersistService for claim_event_activity
    'uq_claim_attachment_key_event_file'       -- Used in PersistService for claim_attachment
)
ORDER BY i.schemaname, i.tablename, i.indexname;

-- ==========================================================================================================
-- END OF INSPECTION
-- ==========================================================================================================

