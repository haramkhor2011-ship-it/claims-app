-- ==========================================================================================================
-- DATABASE INITIALIZATION VERIFICATION
-- ==========================================================================================================
-- 
-- Purpose: Verify database initialization and mark as complete
-- Version: 1.0
-- Date: 2025-01-15
-- 
-- This script performs verification checks and marks the database as initialized.
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: VERIFICATION CHECKS
-- ==========================================================================================================

-- Check schemas exist
DO $$
DECLARE
  schema_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO schema_count
  FROM information_schema.schemata
  WHERE schema_name IN ('claims', 'claims_ref', 'auth');
  
  IF schema_count < 3 THEN
    RAISE EXCEPTION 'Missing schemas. Expected 3, found %', schema_count;
  END IF;
  
  RAISE NOTICE 'Schemas verification: PASSED (found % schemas)', schema_count;
END$$;

-- Check core tables exist
DO $$
DECLARE
  table_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO table_count
  FROM information_schema.tables
  WHERE table_schema = 'claims'
  AND table_name IN (
    'ingestion_file', 'claim_key', 'submission', 'claim', 'encounter', 
    'diagnosis', 'activity', 'observation', 'remittance', 'remittance_claim',
    'remittance_activity', 'claim_event', 'claim_status_timeline'
  );
  
  IF table_count < 13 THEN
    RAISE EXCEPTION 'Missing core tables. Expected 13, found %', table_count;
  END IF;
  
  RAISE NOTICE 'Core tables verification: PASSED (found % tables)', table_count;
END$$;

-- Check reference tables exist
DO $$
DECLARE
  ref_table_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO ref_table_count
  FROM information_schema.tables
  WHERE table_schema = 'claims_ref'
  AND table_name IN (
    'facility', 'payer', 'provider', 'clinician', 'activity_code',
    'diagnosis_code', 'denial_code', 'contract_package'
  );
  
  IF ref_table_count < 8 THEN
    RAISE EXCEPTION 'Missing reference tables. Expected 8, found %', ref_table_count;
  END IF;
  
  RAISE NOTICE 'Reference tables verification: PASSED (found % tables)', ref_table_count;
END$$;

-- Check materialized views exist
DO $$
DECLARE
  mv_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO mv_count
  FROM pg_matviews
  WHERE schemaname = 'claims';
  
  IF mv_count < 9 THEN
    RAISE EXCEPTION 'Missing materialized views. Expected 9, found %', mv_count;
  END IF;
  
  RAISE NOTICE 'Materialized views verification: PASSED (found % MVs)', mv_count;
END$$;

-- Check DHPO configuration tables exist
DO $$
DECLARE
  dhpo_table_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO dhpo_table_count
  FROM information_schema.tables
  WHERE table_schema = 'claims'
  AND table_name IN ('facility_dhpo_config', 'integration_toggle');
  
  IF dhpo_table_count < 2 THEN
    RAISE EXCEPTION 'Missing DHPO configuration tables. Expected 2, found %', dhpo_table_count;
  END IF;
  
  RAISE NOTICE 'DHPO configuration tables verification: PASSED (found % tables)', dhpo_table_count;
END$$;

-- Check user management tables exist
DO $$
DECLARE
  user_table_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO user_table_count
  FROM information_schema.tables
  WHERE table_schema = 'claims'
  AND table_name IN ('users', 'user_roles', 'user_facilities', 'security_audit_log', 'refresh_tokens');
  
  IF user_table_count < 5 THEN
    RAISE EXCEPTION 'Missing user management tables. Expected 5, found %', user_table_count;
  END IF;
  
  RAISE NOTICE 'User management tables verification: PASSED (found % tables)', user_table_count;
END$$;

-- Check extensions are installed
DO $$
DECLARE
  ext_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO ext_count
  FROM pg_extension
  WHERE extname IN ('pg_trgm', 'citext', 'pgcrypto');
  
  IF ext_count < 3 THEN
    RAISE EXCEPTION 'Missing extensions. Expected 3, found %', ext_count;
  END IF;
  
  RAISE NOTICE 'Extensions verification: PASSED (found % extensions)', ext_count;
END$$;

-- Check claims_user role exists
DO $$
DECLARE
  role_exists BOOLEAN;
BEGIN
  SELECT EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'claims_user') INTO role_exists;
  
  IF NOT role_exists THEN
    RAISE EXCEPTION 'claims_user role does not exist';
  END IF;
  
  RAISE NOTICE 'Claims user role verification: PASSED';
END$$;

-- ==========================================================================================================
-- SECTION 2: MARK DATABASE AS INITIALIZED
-- ==========================================================================================================

-- Mark database as initialized
INSERT INTO claims.integration_toggle(code, enabled, updated_at) 
VALUES ('db.initialized', true, NOW())
ON CONFLICT (code) DO UPDATE SET 
  enabled = true, 
  updated_at = NOW();

-- ==========================================================================================================
-- SECTION 3: FINAL VERIFICATION SUMMARY
-- ==========================================================================================================

DO $$
DECLARE
  total_tables INTEGER;
  total_views INTEGER;
  total_functions INTEGER;
BEGIN
  -- Count total tables
  SELECT COUNT(*) INTO total_tables
  FROM information_schema.tables
  WHERE table_schema IN ('claims', 'claims_ref', 'auth');
  
  -- Count total materialized views
  SELECT COUNT(*) INTO total_views
  FROM pg_matviews
  WHERE schemaname = 'claims';
  
  -- Count total functions
  SELECT COUNT(*) INTO total_functions
  FROM information_schema.routines
  WHERE routine_schema = 'claims';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'DATABASE INITIALIZATION COMPLETE';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Total tables created: %', total_tables;
  RAISE NOTICE 'Total materialized views created: %', total_views;
  RAISE NOTICE 'Total functions created: %', total_functions;
  RAISE NOTICE 'Database marked as initialized: true';
  RAISE NOTICE '========================================';
END$$;
