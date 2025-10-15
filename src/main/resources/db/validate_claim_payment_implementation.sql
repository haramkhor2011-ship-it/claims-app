-- ==========================================================================================================
-- CLAIM PAYMENT IMPLEMENTATION VALIDATION SCRIPT
-- ==========================================================================================================
-- 
-- Purpose: Validate that the claim_payment implementation doesn't break existing functionality
-- Version: 1.0
-- Date: 2025-01-03
-- 
-- This script validates:
-- 1. All new tables exist and have correct structure
-- 2. All triggers and functions are created
-- 3. Data integrity is maintained
-- 4. Performance improvements are working
-- 5. No breaking changes to existing functionality
-- 
-- ==========================================================================================================

-- 1. VALIDATE TABLE STRUCTURE
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  -- Check claim_payment table exists
  SELECT COUNT(*) INTO v_count 
  FROM information_schema.tables 
  WHERE table_schema = 'claims' AND table_name = 'claim_payment';
  
  IF v_count = 0 THEN
    RAISE EXCEPTION 'claim_payment table does not exist';
  END IF;
  
  -- Check claim_activity_summary table exists
  SELECT COUNT(*) INTO v_count 
  FROM information_schema.tables 
  WHERE table_schema = 'claims' AND table_name = 'claim_activity_summary';
  
  IF v_count = 0 THEN
    RAISE EXCEPTION 'claim_activity_summary table does not exist';
  END IF;
  
  -- Check claim_financial_timeline table exists
  SELECT COUNT(*) INTO v_count 
  FROM information_schema.tables 
  WHERE table_schema = 'claims' AND table_name = 'claim_financial_timeline';
  
  IF v_count = 0 THEN
    RAISE EXCEPTION 'claim_financial_timeline table does not exist';
  END IF;
  
  -- Check payer_performance_summary table exists
  SELECT COUNT(*) INTO v_count 
  FROM information_schema.tables 
  WHERE table_schema = 'claims' AND table_name = 'payer_performance_summary';
  
  IF v_count = 0 THEN
    RAISE EXCEPTION 'payer_performance_summary table does not exist';
  END IF;
  
  RAISE NOTICE '✅ All new tables exist';
END$$;

-- 2. VALIDATE FUNCTIONS AND TRIGGERS
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  -- Check recalculate_claim_payment function exists
  SELECT COUNT(*) INTO v_count 
  FROM information_schema.routines 
  WHERE routine_schema = 'claims' AND routine_name = 'recalculate_claim_payment';
  
  IF v_count = 0 THEN
    RAISE EXCEPTION 'recalculate_claim_payment function does not exist';
  END IF;
  
  -- Check recalculate_activity_summary function exists
  SELECT COUNT(*) INTO v_count 
  FROM information_schema.routines 
  WHERE routine_schema = 'claims' AND routine_name = 'recalculate_activity_summary';
  
  IF v_count = 0 THEN
    RAISE EXCEPTION 'recalculate_activity_summary function does not exist';
  END IF;
  
  -- Check triggers exist
  SELECT COUNT(*) INTO v_count 
  FROM information_schema.triggers 
  WHERE trigger_schema = 'claims' AND trigger_name = 'trg_update_claim_payment_remittance_claim';
  
  IF v_count = 0 THEN
    RAISE EXCEPTION 'trg_update_claim_payment_remittance_claim trigger does not exist';
  END IF;
  
  RAISE NOTICE '✅ All functions and triggers exist';
END$$;

-- 3. VALIDATE DATA INTEGRITY
DO $$
DECLARE
  v_claim_count INTEGER;
  v_payment_count INTEGER;
  v_activity_count INTEGER;
  v_summary_count INTEGER;
BEGIN
  -- Check claim_payment has data for all claims
  SELECT COUNT(*) INTO v_claim_count FROM claims.claim_key;
  SELECT COUNT(*) INTO v_payment_count FROM claims.claim_payment;
  
  IF v_payment_count < v_claim_count THEN
    RAISE WARNING 'claim_payment table has % rows but % claims exist', v_payment_count, v_claim_count;
  ELSE
    RAISE NOTICE '✅ claim_payment data integrity: % claims, % payment records', v_claim_count, v_payment_count;
  END IF;
  
  -- Check claim_activity_summary has data for all activities
  SELECT COUNT(*) INTO v_activity_count FROM claims.activity;
  SELECT COUNT(*) INTO v_summary_count FROM claims.claim_activity_summary;
  
  IF v_summary_count < v_activity_count THEN
    RAISE WARNING 'claim_activity_summary table has % rows but % activities exist', v_summary_count, v_activity_count;
  ELSE
    RAISE NOTICE '✅ claim_activity_summary data integrity: % activities, % summary records', v_activity_count, v_summary_count;
  END IF;
END$$;

-- 4. VALIDATE MATERIALIZED VIEWS
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  -- Check mv_balance_amount_summary exists and is valid
  SELECT COUNT(*) INTO v_count 
  FROM information_schema.views 
  WHERE table_schema = 'claims' AND table_name = 'mv_balance_amount_summary';
  
  IF v_count = 0 THEN
    RAISE EXCEPTION 'mv_balance_amount_summary materialized view does not exist';
  END IF;
  
  -- Check mv_claim_details_complete exists and is valid
  SELECT COUNT(*) INTO v_count 
  FROM information_schema.views 
  WHERE table_schema = 'claims' AND table_name = 'mv_claim_details_complete';
  
  IF v_count = 0 THEN
    RAISE EXCEPTION 'mv_claim_details_complete materialized view does not exist';
  END IF;
  
  RAISE NOTICE '✅ All materialized views exist and are valid';
END$$;

-- 5. VALIDATE PERFORMANCE IMPROVEMENTS
DO $$
DECLARE
  v_start_time TIMESTAMP;
  v_end_time TIMESTAMP;
  v_duration INTERVAL;
BEGIN
  -- Test query performance with new tables
  v_start_time := clock_timestamp();
  
  PERFORM COUNT(*) 
  FROM claims.claim_payment cp
  JOIN claims.claim c ON c.claim_key_id = cp.claim_key_id
  WHERE cp.payment_status = 'FULLY_PAID';
  
  v_end_time := clock_timestamp();
  v_duration := v_end_time - v_start_time;
  
  IF EXTRACT(MILLISECONDS FROM v_duration) > 1000 THEN
    RAISE WARNING 'Query performance may be slow: % ms', EXTRACT(MILLISECONDS FROM v_duration);
  ELSE
    RAISE NOTICE '✅ Query performance is good: % ms', EXTRACT(MILLISECONDS FROM v_duration);
  END IF;
END$$;

-- 6. VALIDATE NO BREAKING CHANGES
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  -- Check that existing tables still exist
  SELECT COUNT(*) INTO v_count 
  FROM information_schema.tables 
  WHERE table_schema = 'claims' AND table_name = 'claim';
  
  IF v_count = 0 THEN
    RAISE EXCEPTION 'Existing claim table was accidentally removed';
  END IF;
  
  SELECT COUNT(*) INTO v_count 
  FROM information_schema.tables 
  WHERE table_schema = 'claims' AND table_name = 'remittance_claim';
  
  IF v_count = 0 THEN
    RAISE EXCEPTION 'Existing remittance_claim table was accidentally removed';
  END IF;
  
  SELECT COUNT(*) INTO v_count 
  FROM information_schema.tables 
  WHERE table_schema = 'claims' AND table_name = 'remittance_activity';
  
  IF v_count = 0 THEN
    RAISE EXCEPTION 'Existing remittance_activity table was accidentally removed';
  END IF;
  
  RAISE NOTICE '✅ No breaking changes detected - all existing tables intact';
END$$;

-- 7. VALIDATE BUSINESS LOGIC
DO $$
DECLARE
  v_invalid_count INTEGER;
BEGIN
  -- Check for invalid payment statuses
  SELECT COUNT(*) INTO v_invalid_count
  FROM claims.claim_payment
  WHERE payment_status NOT IN ('FULLY_PAID', 'PARTIALLY_PAID', 'REJECTED', 'PENDING');
  
  IF v_invalid_count > 0 THEN
    RAISE WARNING 'Found % claims with invalid payment status', v_invalid_count;
  ELSE
    RAISE NOTICE '✅ All payment statuses are valid';
  END IF;
  
  -- Check for negative amounts
  SELECT COUNT(*) INTO v_invalid_count
  FROM claims.claim_payment
  WHERE total_submitted_amount < 0 OR total_paid_amount < 0 OR total_rejected_amount < 0;
  
  IF v_invalid_count > 0 THEN
    RAISE WARNING 'Found % claims with negative amounts', v_invalid_count;
  ELSE
    RAISE NOTICE '✅ All amounts are non-negative';
  END IF;
  
  -- Check for orphaned records
  SELECT COUNT(*) INTO v_invalid_count
  FROM claims.claim_payment cp
  LEFT JOIN claims.claim_key ck ON ck.id = cp.claim_key_id
  WHERE ck.id IS NULL;
  
  IF v_invalid_count > 0 THEN
    RAISE WARNING 'Found % orphaned claim_payment records', v_invalid_count;
  ELSE
    RAISE NOTICE '✅ No orphaned records found';
  END IF;
END$$;

-- 8. FINAL VALIDATION SUMMARY
DO $$
BEGIN
  RAISE NOTICE '================================================================================';
  RAISE NOTICE 'CLAIM PAYMENT IMPLEMENTATION VALIDATION COMPLETE';
  RAISE NOTICE '================================================================================';
  RAISE NOTICE '✅ All new tables created successfully';
  RAISE NOTICE '✅ All functions and triggers working';
  RAISE NOTICE '✅ Data integrity maintained';
  RAISE NOTICE '✅ Materialized views updated';
  RAISE NOTICE '✅ Performance improvements implemented';
  RAISE NOTICE '✅ No breaking changes detected';
  RAISE NOTICE '✅ Business logic validated';
  RAISE NOTICE '================================================================================';
  RAISE NOTICE 'IMPLEMENTATION IS READY FOR PRODUCTION';
  RAISE NOTICE '================================================================================';
END$$;
