-- ==========================================================================================================
-- CREATE MISSING TAB-SPECIFIC MATERIALIZED VIEWS
-- ==========================================================================================================
-- 
-- Purpose: Create tab-specific MVs to match traditional views exactly
-- Version: 1.0 - Tab-Specific Implementation
-- Date: 2025-01-03
-- 
-- This script creates 15 missing tab-specific materialized views to ensure
-- complete parity between traditional views and MVs for Option 3 implementation.
--
-- ==========================================================================================================

-- ==========================================================================================================
-- BALANCE AMOUNT REPORT - TAB-SPECIFIC MVs
-- ==========================================================================================================

-- Tab A: Overall balances
DROP MATERIALIZED VIEW IF EXISTS claims.mv_balance_amount_overall CASCADE;
CREATE MATERIALIZED VIEW claims.mv_balance_amount_overall AS
SELECT * FROM claims.v_balance_amount_to_be_received;

-- Tab B: Initial not remitted
DROP MATERIALIZED VIEW IF EXISTS claims.mv_balance_amount_initial CASCADE;
CREATE MATERIALIZED VIEW claims.mv_balance_amount_initial AS
SELECT * FROM claims.v_initial_not_remitted_balance;

-- Tab C: After resubmission
DROP MATERIALIZED VIEW IF EXISTS claims.mv_balance_amount_resubmission CASCADE;
CREATE MATERIALIZED VIEW claims.mv_balance_amount_resubmission AS
SELECT * FROM claims.v_after_resubmission_not_remitted_balance;

-- ==========================================================================================================
-- REMITTANCE ADVICE REPORT - TAB-SPECIFIC MVs
-- ==========================================================================================================

-- Tab A: Header summary
DROP MATERIALIZED VIEW IF EXISTS claims.mv_remittance_advice_header CASCADE;
CREATE MATERIALIZED VIEW claims.mv_remittance_advice_header AS
SELECT * FROM claims.v_remittance_advice_header;

-- Tab B: Claim-wise details
DROP MATERIALIZED VIEW IF EXISTS claims.mv_remittance_advice_claim_wise CASCADE;
CREATE MATERIALIZED VIEW claims.mv_remittance_advice_claim_wise AS
SELECT * FROM claims.v_remittance_advice_claim_wise;

-- Tab C: Activity-wise details
DROP MATERIALIZED VIEW IF EXISTS claims.mv_remittance_advice_activity_wise CASCADE;
CREATE MATERIALIZED VIEW claims.mv_remittance_advice_activity_wise AS
SELECT * FROM claims.v_remittance_advice_activity_wise;

-- ==========================================================================================================
-- DOCTOR DENIAL REPORT - TAB-SPECIFIC MVs
-- ==========================================================================================================

-- Tab A: High denial doctors
DROP MATERIALIZED VIEW IF EXISTS claims.mv_doctor_denial_high_denial CASCADE;
CREATE MATERIALIZED VIEW claims.mv_doctor_denial_high_denial AS
SELECT * FROM claims.v_doctor_denial_high_denial;

-- Tab C: Detail view
DROP MATERIALIZED VIEW IF EXISTS claims.mv_doctor_denial_detail CASCADE;
CREATE MATERIALIZED VIEW claims.mv_doctor_denial_detail AS
SELECT * FROM claims.v_doctor_denial_detail;

-- ==========================================================================================================
-- REJECTED CLAIMS REPORT - TAB-SPECIFIC MVs
-- ==========================================================================================================

-- Tab A: Summary by year
DROP MATERIALIZED VIEW IF EXISTS claims.mv_rejected_claims_by_year CASCADE;
CREATE MATERIALIZED VIEW claims.mv_rejected_claims_by_year AS
SELECT * FROM claims.v_rejected_claims_summary_by_year;

-- Tab B: Summary view
DROP MATERIALIZED VIEW IF EXISTS claims.mv_rejected_claims_summary CASCADE;
CREATE MATERIALIZED VIEW claims.mv_rejected_claims_summary AS
SELECT * FROM claims.v_rejected_claims_summary;

-- Tab C: Receiver/Payer view
DROP MATERIALIZED VIEW IF EXISTS claims.mv_rejected_claims_receiver_payer CASCADE;
CREATE MATERIALIZED VIEW claims.mv_rejected_claims_receiver_payer AS
SELECT * FROM claims.v_rejected_claims_receiver_payer;

-- Tab D: Claim-wise view
DROP MATERIALIZED VIEW IF EXISTS claims.mv_rejected_claims_claim_wise CASCADE;
CREATE MATERIALIZED VIEW claims.mv_rejected_claims_claim_wise AS
SELECT * FROM claims.v_rejected_claims_claim_wise;

-- ==========================================================================================================
-- CLAIM SUMMARY REPORT - TAB-SPECIFIC MVs
-- ==========================================================================================================

-- Tab A: Monthwise (missing MV)
DROP MATERIALIZED VIEW IF EXISTS claims.mv_claim_summary_monthwise CASCADE;
CREATE MATERIALIZED VIEW claims.mv_claim_summary_monthwise AS
SELECT * FROM claims.v_claim_summary_monthwise;

-- ==========================================================================================================
-- RESUBMISSION REPORT - TAB-SPECIFIC MVs
-- ==========================================================================================================

-- Tab B: Claim level (missing MV)
DROP MATERIALIZED VIEW IF EXISTS claims.mv_remittances_resubmission_claim_level CASCADE;
CREATE MATERIALIZED VIEW claims.mv_remittances_resubmission_claim_level AS
SELECT * FROM claims.v_remittances_resubmission_claim_level;

-- ==========================================================================================================
-- PERFORMANCE INDEXES
-- ==========================================================================================================

-- Balance Amount MVs
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_balance_amount_overall_unique 
ON claims.mv_balance_amount_overall(claim_key_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_balance_amount_initial_unique 
ON claims.mv_balance_amount_initial(claim_key_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_balance_amount_resubmission_unique 
ON claims.mv_balance_amount_resubmission(claim_key_id);

-- Remittance Advice MVs
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_remittance_advice_header_unique 
ON claims.mv_remittance_advice_header(claim_key_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_remittance_advice_claim_wise_unique 
ON claims.mv_remittance_advice_claim_wise(claim_key_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_remittance_advice_activity_wise_unique 
ON claims.mv_remittance_advice_activity_wise(claim_key_id, activity_id);

-- Doctor Denial MVs
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_doctor_denial_high_denial_unique 
ON claims.mv_doctor_denial_high_denial(clinician_id, facility_id, report_month);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_doctor_denial_detail_unique 
ON claims.mv_doctor_denial_detail(claim_key_id, activity_id);

-- Rejected Claims MVs
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_rejected_claims_by_year_unique 
ON claims.mv_rejected_claims_by_year(claim_year, facility_id, payer_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_rejected_claims_summary_unique 
ON claims.mv_rejected_claims_summary(facility_id, payer_id, report_month);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_rejected_claims_receiver_payer_unique 
ON claims.mv_rejected_claims_receiver_payer(facility_id, payer_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_rejected_claims_claim_wise_unique 
ON claims.mv_rejected_claims_claim_wise(claim_key_id, activity_id);

-- Claim Summary MVs
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_claim_summary_monthwise_unique 
ON claims.mv_claim_summary_monthwise(month_bucket, facility_id, payer_id, encounter_type);

-- Resubmission MVs
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_remittances_resubmission_claim_level_unique 
ON claims.mv_remittances_resubmission_claim_level(claim_key_id);

-- ==========================================================================================================
-- COMMENTS
-- ==========================================================================================================

COMMENT ON MATERIALIZED VIEW claims.mv_balance_amount_overall IS 'Tab A: Overall balances - matches v_balance_amount_to_be_received';
COMMENT ON MATERIALIZED VIEW claims.mv_balance_amount_initial IS 'Tab B: Initial not remitted - matches v_initial_not_remitted_balance';
COMMENT ON MATERIALIZED VIEW claims.mv_balance_amount_resubmission IS 'Tab C: After resubmission - matches v_after_resubmission_not_remitted_balance';

COMMENT ON MATERIALIZED VIEW claims.mv_remittance_advice_header IS 'Tab A: Header summary - matches v_remittance_advice_header';
COMMENT ON MATERIALIZED VIEW claims.mv_remittance_advice_claim_wise IS 'Tab B: Claim-wise details - matches v_remittance_advice_claim_wise';
COMMENT ON MATERIALIZED VIEW claims.mv_remittance_advice_activity_wise IS 'Tab C: Activity-wise details - matches v_remittance_advice_activity_wise';

COMMENT ON MATERIALIZED VIEW claims.mv_doctor_denial_high_denial IS 'Tab A: High denial doctors - matches v_doctor_denial_high_denial';
COMMENT ON MATERIALIZED VIEW claims.mv_doctor_denial_detail IS 'Tab C: Detail view - matches v_doctor_denial_detail';

COMMENT ON MATERIALIZED VIEW claims.mv_rejected_claims_by_year IS 'Tab A: Summary by year - matches v_rejected_claims_summary_by_year';
COMMENT ON MATERIALIZED VIEW claims.mv_rejected_claims_summary IS 'Tab B: Summary view - matches v_rejected_claims_summary';
COMMENT ON MATERIALIZED VIEW claims.mv_rejected_claims_receiver_payer IS 'Tab C: Receiver/Payer view - matches v_rejected_claims_receiver_payer';
COMMENT ON MATERIALIZED VIEW claims.mv_rejected_claims_claim_wise IS 'Tab D: Claim-wise view - matches v_rejected_claims_claim_wise';

COMMENT ON MATERIALIZED VIEW claims.mv_claim_summary_monthwise IS 'Tab A: Monthwise - matches v_claim_summary_monthwise';

COMMENT ON MATERIALIZED VIEW claims.mv_remittances_resubmission_claim_level IS 'Tab B: Claim level - matches v_remittances_resubmission_claim_level';

-- ==========================================================================================================
-- REFRESH FUNCTIONS
-- ==========================================================================================================

CREATE OR REPLACE FUNCTION refresh_tab_specific_mvs() RETURNS VOID AS $$
BEGIN
  -- Refresh all tab-specific MVs
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_balance_amount_overall;
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_balance_amount_initial;
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_balance_amount_resubmission;
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_remittance_advice_header;
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_remittance_advice_claim_wise;
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_remittance_advice_activity_wise;
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_doctor_denial_high_denial;
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_doctor_denial_detail;
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_rejected_claims_by_year;
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_rejected_claims_summary;
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_rejected_claims_receiver_payer;
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_rejected_claims_claim_wise;
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_claim_summary_monthwise;
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_remittances_resubmission_claim_level;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION refresh_tab_specific_mvs() IS 'Refreshes all tab-specific materialized views for Option 3 implementation';
