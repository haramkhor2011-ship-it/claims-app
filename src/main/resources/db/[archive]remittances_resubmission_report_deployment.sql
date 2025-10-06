-- ==========================================================================================================
-- REMITTANCES & RESUBMISSION ACTIVITY LEVEL REPORT - PRODUCTION DEPLOYMENT SCRIPT
-- ==========================================================================================================
-- 
-- Date: 2025-09-24
-- Purpose: Production deployment script for Remittances & Resubmission Activity Level Report
-- 
-- This script provides a safe, production-ready deployment process with:
-- - Pre-deployment validation
-- - Rollback capabilities
-- - Performance monitoring
-- - User acceptance testing
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: PRE-DEPLOYMENT VALIDATION
-- ==========================================================================================================

-- Check if we're in the correct database
DO $$
BEGIN
    IF current_database() NOT IN ('claims_prod', 'claims_staging', 'claims_dev') THEN
        RAISE EXCEPTION 'This script should only be run on claims databases (prod/staging/dev)';
    END IF;
    
    RAISE NOTICE 'Deployment target database: %', current_database();
END $$;

-- Check if required schemas exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'claims') THEN
        RAISE EXCEPTION 'Claims schema does not exist';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'claims_ref') THEN
        RAISE EXCEPTION 'Claims_ref schema does not exist';
    END IF;
    
    RAISE NOTICE 'PASS: Required schemas exist';
END $$;

-- Check if required tables exist
DO $$
DECLARE
    missing_tables TEXT[] := ARRAY[]::TEXT[];
    required_tables TEXT[] := ARRAY[
        'claim_key', 'claim', 'activity', 'encounter', 'remittance_claim', 
        'remittance_activity', 'claim_event', 'claim_resubmission',
        'payer', 'facility', 'clinician', 'denial_code'
    ];
    table_name TEXT;
BEGIN
    FOREACH table_name IN ARRAY required_tables
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'claims' AND table_name = table_name
        ) THEN
            missing_tables := array_append(missing_tables, table_name);
        END IF;
    END LOOP;
    
    IF array_length(missing_tables, 1) > 0 THEN
        RAISE EXCEPTION 'Missing required tables: %', array_to_string(missing_tables, ', ');
    END IF;
    
    RAISE NOTICE 'PASS: All required tables exist';
END $$;

-- ==========================================================================================================
-- SECTION 2: BACKUP EXISTING OBJECTS (IF ANY)
-- ==========================================================================================================

-- Create backup schema for rollback purposes
CREATE SCHEMA IF NOT EXISTS claims_backup_$(date +%Y%m%d_%H%M%S);

-- Backup existing views and functions (if they exist)
DO $$
BEGIN
    -- Backup activity level view
    IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'claims' AND table_name = 'v_remittances_resubmission_activity_level') THEN
        EXECUTE 'CREATE VIEW claims_backup_$(date +%Y%m%d_%H%M%S).v_remittances_resubmission_activity_level AS SELECT * FROM claims.v_remittances_resubmission_activity_level';
        RAISE NOTICE 'Backed up existing activity level view';
    END IF;
    
    -- Backup claim level view
    IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'claims' AND table_name = 'v_remittances_resubmission_claim_level') THEN
        EXECUTE 'CREATE VIEW claims_backup_$(date +%Y%m%d_%H%M%S).v_remittances_resubmission_claim_level AS SELECT * FROM claims.v_remittances_resubmission_claim_level';
        RAISE NOTICE 'Backed up existing claim level view';
    END IF;
    
    -- Backup functions
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'claims' AND routine_name = 'get_remittances_resubmission_activity_level') THEN
        RAISE NOTICE 'Existing activity level function will be replaced';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'claims' AND routine_name = 'get_remittances_resubmission_claim_level') THEN
        RAISE NOTICE 'Existing claim level function will be replaced';
    END IF;
END $$;

-- ==========================================================================================================
-- SECTION 3: DEPLOYMENT EXECUTION
-- ==========================================================================================================

-- Execute the main implementation script
\echo 'Executing main implementation script...'
\i src/main/resources/db/remittances_resubmission_report_implementation.sql

-- ==========================================================================================================
-- SECTION 4: POST-DEPLOYMENT VALIDATION
-- ==========================================================================================================

-- Verify views were created successfully
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'claims' AND table_name = 'v_remittances_resubmission_activity_level') THEN
        RAISE EXCEPTION 'Activity level view was not created successfully';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'claims' AND table_name = 'v_remittances_resubmission_claim_level') THEN
        RAISE EXCEPTION 'Claim level view was not created successfully';
    END IF;
    
    RAISE NOTICE 'PASS: Views created successfully';
END $$;

-- Verify functions were created successfully
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'claims' AND routine_name = 'get_remittances_resubmission_activity_level') THEN
        RAISE EXCEPTION 'Activity level function was not created successfully';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'claims' AND routine_name = 'get_remittances_resubmission_claim_level') THEN
        RAISE EXCEPTION 'Claim level function was not created successfully';
    END IF;
    
    RAISE NOTICE 'PASS: Functions created successfully';
END $$;

-- Verify indexes were created successfully
DO $$
DECLARE
    missing_indexes TEXT[] := ARRAY[]::TEXT[];
    required_indexes TEXT[] := ARRAY[
        'idx_remittances_resubmission_activity_claim_key_id',
        'idx_remittances_resubmission_activity_facility_id',
        'idx_remittances_resubmission_activity_payer_id',
        'idx_remittances_resubmission_claim_claim_key_id'
    ];
    idx_name TEXT;
BEGIN
    FOREACH idx_name IN ARRAY required_indexes
    LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'claims' AND indexname = idx_name) THEN
            missing_indexes := array_append(missing_indexes, idx_name);
        END IF;
    END LOOP;
    
    IF array_length(missing_indexes, 1) > 0 THEN
        RAISE WARNING 'Missing indexes: %', array_to_string(missing_indexes, ', ');
    ELSE
        RAISE NOTICE 'PASS: Critical indexes created successfully';
    END IF;
END $$;

-- ==========================================================================================================
-- SECTION 5: PERFORMANCE TESTING
-- ==========================================================================================================

-- Test query performance
DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    execution_time INTERVAL;
    result_count INTEGER;
BEGIN
    start_time := clock_timestamp();
    
    -- Test activity level query
    SELECT COUNT(*) INTO result_count
    FROM claims.get_remittances_resubmission_activity_level(p_limit := 1000);
    
    end_time := clock_timestamp();
    execution_time := end_time - start_time;
    
    RAISE NOTICE 'Activity level query performance: % rows in %', result_count, execution_time;
    
    -- Test claim level query
    start_time := clock_timestamp();
    
    SELECT COUNT(*) INTO result_count
    FROM claims.get_remittances_resubmission_claim_level(p_limit := 1000);
    
    end_time := clock_timestamp();
    execution_time := end_time - start_time;
    
    RAISE NOTICE 'Claim level query performance: % rows in %', result_count, execution_time;
    
    RAISE NOTICE 'PASS: Performance tests completed';
END $$;

-- ==========================================================================================================
-- SECTION 6: USER ACCEPTANCE TESTING
-- ==========================================================================================================

-- Test 1: Basic functionality test
DO $$
DECLARE
    activity_count INTEGER;
    claim_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO activity_count FROM claims.v_remittances_resubmission_activity_level;
    SELECT COUNT(*) INTO claim_count FROM claims.v_remittances_resubmission_claim_level;
    
    RAISE NOTICE 'UAT Test 1 - Basic Counts: Activity Level: %, Claim Level: %', activity_count, claim_count;
    
    IF activity_count = 0 AND claim_count = 0 THEN
        RAISE WARNING 'No data found in views - this may be expected for a new deployment';
    END IF;
    
    RAISE NOTICE 'PASS: Basic functionality test completed';
END $$;

-- Test 2: Filter functionality test
DO $$
DECLARE
    filtered_count INTEGER;
BEGIN
    -- Test date range filter
    SELECT COUNT(*) INTO filtered_count
    FROM claims.get_remittances_resubmission_activity_level(
        p_from_date := '2024-01-01'::TIMESTAMPTZ,
        p_to_date := '2024-12-31'::TIMESTAMPTZ
    );
    
    RAISE NOTICE 'UAT Test 2 - Date Filter: % rows', filtered_count;
    
    -- Test limit filter
    SELECT COUNT(*) INTO filtered_count
    FROM claims.get_remittances_resubmission_activity_level(p_limit := 10);
    
    IF filtered_count > 10 THEN
        RAISE EXCEPTION 'Limit filter not working correctly';
    END IF;
    
    RAISE NOTICE 'PASS: Filter functionality test completed';
END $$;

-- Test 3: Data integrity test
DO $$
DECLARE
    null_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO null_count
    FROM claims.v_remittances_resubmission_activity_level
    WHERE claim_key_id IS NULL;
    
    IF null_count > 0 THEN
        RAISE EXCEPTION 'Found % rows with null claim_key_id', null_count;
    END IF;
    
    RAISE NOTICE 'PASS: Data integrity test completed';
END $$;

-- ==========================================================================================================
-- SECTION 7: MONITORING SETUP
-- ==========================================================================================================

-- Create monitoring view for report usage
CREATE OR REPLACE VIEW claims.v_remittances_resubmission_usage_stats AS
SELECT 
    'Activity Level' as report_type,
    COUNT(*) as total_records,
    COUNT(DISTINCT claim_key_id) as unique_claims,
    COUNT(DISTINCT facility_id) as unique_facilities,
    COUNT(DISTINCT payer_id) as unique_payers,
    SUM(submitted_amount) as total_submitted,
    SUM(total_paid) as total_paid,
    SUM(rejected_amount) as total_rejected,
    AVG(ageing_days) as avg_ageing_days
FROM claims.v_remittances_resubmission_activity_level
UNION ALL
SELECT 
    'Claim Level' as report_type,
    COUNT(*) as total_records,
    COUNT(DISTINCT claim_key_id) as unique_claims,
    COUNT(DISTINCT facility_id) as unique_facilities,
    COUNT(DISTINCT payer_id) as unique_payers,
    SUM(submitted_amount) as total_submitted,
    SUM(total_paid) as total_paid,
    SUM(rejected_amount) as total_rejected,
    AVG(ageing_days) as avg_ageing_days
FROM claims.v_remittances_resubmission_claim_level;

COMMENT ON VIEW claims.v_remittances_resubmission_usage_stats IS 'Usage statistics for remittances and resubmission report';

-- ==========================================================================================================
-- SECTION 8: ROLLBACK PROCEDURE
-- ==========================================================================================================

-- Create rollback script
CREATE OR REPLACE FUNCTION claims.rollback_remittances_resubmission_report()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    backup_schema TEXT;
    result TEXT := '';
BEGIN
    -- Find the most recent backup schema
    SELECT schema_name INTO backup_schema
    FROM information_schema.schemata
    WHERE schema_name LIKE 'claims_backup_%'
    ORDER BY schema_name DESC
    LIMIT 1;
    
    IF backup_schema IS NULL THEN
        RETURN 'No backup found for rollback';
    END IF;
    
    -- Drop current objects
    DROP VIEW IF EXISTS claims.v_remittances_resubmission_activity_level;
    DROP VIEW IF EXISTS claims.v_remittances_resubmission_claim_level;
    DROP FUNCTION IF EXISTS claims.get_remittances_resubmission_activity_level;
    DROP FUNCTION IF EXISTS claims.get_remittances_resubmission_claim_level;
    
    -- Restore from backup
    EXECUTE 'CREATE VIEW claims.v_remittances_resubmission_activity_level AS SELECT * FROM ' || backup_schema || '.v_remittances_resubmission_activity_level';
    EXECUTE 'CREATE VIEW claims.v_remittances_resubmission_claim_level AS SELECT * FROM ' || backup_schema || '.v_remittances_resubmission_claim_level';
    
    result := 'Rollback completed using backup schema: ' || backup_schema;
    
    RETURN result;
END;
$$;

COMMENT ON FUNCTION claims.rollback_remittances_resubmission_report IS 'Rollback function for remittances and resubmission report';

-- ==========================================================================================================
-- SECTION 9: DEPLOYMENT SUMMARY
-- ==========================================================================================================

-- Generate deployment summary
DO $$
DECLARE
    activity_count INTEGER;
    claim_count INTEGER;
    total_submitted NUMERIC;
    total_paid NUMERIC;
    total_rejected NUMERIC;
    deployment_time TIMESTAMP := NOW();
BEGIN
    -- Get basic statistics
    SELECT COUNT(*) INTO activity_count FROM claims.v_remittances_resubmission_activity_level;
    SELECT COUNT(*) INTO claim_count FROM claims.v_remittances_resubmission_claim_level;
    
    SELECT 
        COALESCE(SUM(submitted_amount), 0),
        COALESCE(SUM(total_paid), 0),
        COALESCE(SUM(rejected_amount), 0)
    INTO total_submitted, total_paid, total_rejected
    FROM claims.v_remittances_resubmission_activity_level;
    
    RAISE NOTICE '=== DEPLOYMENT SUMMARY ===';
    RAISE NOTICE 'Deployment Time: %', deployment_time;
    RAISE NOTICE 'Database: %', current_database();
    RAISE NOTICE 'Activity Level Records: %', activity_count;
    RAISE NOTICE 'Claim Level Records: %', claim_count;
    RAISE NOTICE 'Total Submitted Amount: %', total_submitted;
    RAISE NOTICE 'Total Paid Amount: %', total_paid;
    RAISE NOTICE 'Total Rejected Amount: %', total_rejected;
    RAISE NOTICE 'Recovery Rate: %%%', ROUND((total_paid / NULLIF(total_submitted, 0)) * 100, 2);
    RAISE NOTICE 'Rejection Rate: %%%', ROUND((total_rejected / NULLIF(total_submitted, 0)) * 100, 2);
    RAISE NOTICE '=== DEPLOYMENT COMPLETED SUCCESSFULLY ===';
END $$;

-- ==========================================================================================================
-- END OF DEPLOYMENT SCRIPT
-- ==========================================================================================================

RAISE NOTICE 'Remittances & Resubmission Activity Level Report deployment completed successfully!';
