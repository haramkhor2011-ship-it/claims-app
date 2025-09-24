-- ==========================================================================================================
-- CLEANUP SCRIPT FOR OLD BALANCE AMOUNT REPORT VIEWS AND FUNCTIONS
-- ==========================================================================================================
-- 
-- This script removes the old views and functions before running the new implementation
-- Run this script first, then run the new balance_amount_report_implementation.sql
-- ==========================================================================================================

-- Drop old views (if they exist)
DROP VIEW IF EXISTS claims.v_balance_amount_base_enhanced CASCADE;
DROP VIEW IF EXISTS claims.v_balance_amount_tab_a_corrected CASCADE;
DROP VIEW IF EXISTS claims.v_balance_amount_tab_b_corrected CASCADE;
DROP VIEW IF EXISTS claims.v_balance_amount_tab_c_corrected CASCADE;

-- Drop old functions (if they exist)
DROP FUNCTION IF EXISTS claims.get_balance_amount_tab_a_corrected CASCADE;

-- Note: We keep claims.map_status_to_text as it's still used in the new implementation

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'Old balance amount report views and functions cleaned up successfully!';
  RAISE NOTICE 'Ready to run the new balance_amount_report_implementation.sql';
END$$;
