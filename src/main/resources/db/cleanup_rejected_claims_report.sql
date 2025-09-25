-- ==========================================================================================================
-- CLEANUP SCRIPT FOR REJECTED CLAIMS REPORT
-- ==========================================================================================================
-- 
-- Date: 2025-09-24
-- Purpose: Clean up existing Rejected Claims Report objects before redeployment
-- 
-- This script drops all views, functions, and indexes related to the Rejected Claims Report
-- to ensure a clean redeployment.
--
-- ==========================================================================================================

-- Drop functions first (they depend on views)
DROP FUNCTION IF EXISTS claims.get_rejected_claims_summary(TEXT, TEXT[], TEXT[], TEXT[], TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, INTEGER, INTEGER, INTEGER, TEXT, TEXT);
DROP FUNCTION IF EXISTS claims.get_rejected_claims_receiver_payer(TEXT, TEXT[], TEXT[], TEXT[], TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, TEXT[], INTEGER, INTEGER, TEXT, TEXT);
DROP FUNCTION IF EXISTS claims.get_rejected_claims_claim_wise(TEXT, TEXT[], TEXT[], TEXT[], TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, TEXT[], INTEGER, INTEGER, TEXT, TEXT);

-- Drop views (in reverse dependency order)
DROP VIEW IF EXISTS claims.v_rejected_claims_claim_wise;
DROP VIEW IF EXISTS claims.v_rejected_claims_receiver_payer;
DROP VIEW IF EXISTS claims.v_rejected_claims_summary;
DROP VIEW IF EXISTS claims.v_rejected_claims_summary_by_year;
DROP VIEW IF EXISTS claims.v_rejected_claims_base;

-- Drop indexes (if they exist)
DROP INDEX IF EXISTS claims.idx_rejected_claims_base_claim_key_id;
DROP INDEX IF EXISTS claims.idx_rejected_claims_base_activity_id;
DROP INDEX IF EXISTS claims.idx_rejected_claims_base_facility_id;
DROP INDEX IF EXISTS claims.idx_rejected_claims_base_payer_id;
DROP INDEX IF EXISTS claims.idx_rejected_claims_base_rejection_type;
DROP INDEX IF EXISTS claims.idx_rejected_claims_base_denial_code;
DROP INDEX IF EXISTS claims.idx_rejected_claims_base_activity_start_date;
DROP INDEX IF EXISTS claims.idx_rejected_claims_base_ageing_days;

-- Display cleanup completion message
SELECT 'Rejected Claims Report cleanup completed successfully' as status;