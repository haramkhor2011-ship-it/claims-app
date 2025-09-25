-- ==========================================================================================================
-- DROP SCRIPT FOR OLD BALANCE AMOUNT REPORT VIEWS AND FUNCTIONS
-- ==========================================================================================================
-- 
-- This script removes ALL old views and functions related to balance amount reports
-- Run this script in pgAdmin BEFORE applying the new balance_amount_report_implementation.sql
-- 
-- IMPORTANT: This will drop both old and new views to ensure a clean slate
-- ==========================================================================================================

-- ==========================================================================================================
-- DROP OLD VIEWS (if they exist)
-- ==========================================================================================================

-- Drop old base view
DROP VIEW IF EXISTS claims.v_balance_amount_base_enhanced CASCADE;

-- Drop old tab views
DROP VIEW IF EXISTS claims.v_balance_amount_tab_a_corrected CASCADE;
DROP VIEW IF EXISTS claims.v_balance_amount_tab_b_corrected CASCADE;
DROP VIEW IF EXISTS claims.v_balance_amount_tab_c_corrected CASCADE;

-- ==========================================================================================================
-- DROP NEW VIEWS (if they exist from previous runs)
-- ==========================================================================================================

-- Drop new views (in case they were created before)
DROP VIEW IF EXISTS claims.v_balance_amount_to_be_received_base CASCADE;
DROP VIEW IF EXISTS claims.v_balance_amount_to_be_received CASCADE;
DROP VIEW IF EXISTS claims.v_initial_not_remitted_balance CASCADE;
DROP VIEW IF EXISTS claims.v_after_resubmission_not_remitted_balance CASCADE;

-- ==========================================================================================================
-- DROP OLD FUNCTIONS (if they exist)
-- ==========================================================================================================

-- Drop old API function
DROP FUNCTION IF EXISTS claims.get_balance_amount_tab_a_corrected CASCADE;

-- Drop new function (in case it was created before)
DROP FUNCTION IF EXISTS claims.get_balance_amount_to_be_received CASCADE;

-- ==========================================================================================================
-- DROP STATUS MAPPING FUNCTION (if it exists)
-- ==========================================================================================================

-- Drop status mapping function (will be recreated)
DROP FUNCTION IF EXISTS claims.map_status_to_text CASCADE;

-- ==========================================================================================================
-- DROP INDEXES (if they exist)
-- ==========================================================================================================

-- Drop report-specific indexes
DROP INDEX IF EXISTS claims.idx_balance_amount_base_enhanced_encounter;
DROP INDEX IF EXISTS claims.idx_balance_amount_base_enhanced_remittance;
DROP INDEX IF EXISTS claims.idx_balance_amount_base_enhanced_resubmission;
DROP INDEX IF EXISTS claims.idx_balance_amount_base_enhanced_submission;
DROP INDEX IF EXISTS claims.idx_balance_amount_base_enhanced_status_timeline;
DROP INDEX IF EXISTS claims.idx_balance_amount_facility_payer_enhanced;
DROP INDEX IF EXISTS claims.idx_balance_amount_payment_status_enhanced;
DROP INDEX IF EXISTS claims.idx_balance_amount_remittance_activity_enhanced;

-- ==========================================================================================================
-- VERIFICATION QUERIES
-- ==========================================================================================================

-- Check if any balance-related views still exist
DO $$
DECLARE
    view_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO view_count
    FROM pg_views 
    WHERE schemaname = 'claims' 
    AND (viewname LIKE '%balance%' OR viewname LIKE '%tab_%');
    
    IF view_count > 0 THEN
        RAISE NOTICE 'WARNING: % balance-related views still exist. Check manually.', view_count;
    ELSE
        RAISE NOTICE 'SUCCESS: All balance-related views have been dropped.';
    END IF;
END$$;

-- Check if any balance-related functions still exist
DO $$
DECLARE
    func_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO func_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'claims' 
    AND (p.proname LIKE '%balance%' OR p.proname LIKE '%tab_%');
    
    IF func_count > 0 THEN
        RAISE NOTICE 'WARNING: % balance-related functions still exist. Check manually.', func_count;
    ELSE
        RAISE NOTICE 'SUCCESS: All balance-related functions have been dropped.';
    END IF;
END$$;

-- ==========================================================================================================
-- SUCCESS MESSAGE
-- ==========================================================================================================

DO $$
BEGIN
    RAISE NOTICE '================================================================================';
    RAISE NOTICE 'CLEANUP COMPLETED SUCCESSFULLY!';
    RAISE NOTICE '================================================================================';
    RAISE NOTICE 'All old balance amount report views and functions have been dropped.';
    RAISE NOTICE 'You can now safely run the new balance_amount_report_implementation.sql';
    RAISE NOTICE '================================================================================';
END$$;
