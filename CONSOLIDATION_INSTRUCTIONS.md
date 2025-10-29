# Consolidation Instructions: Copy Working Files to Docker Init

## Overview
Your working views, functions, and materialized views in `src/main/resources/db/reports_sql/` need to be copied to the consolidated Docker initialization files:
- Views → `docker/db-init/06-report-views.sql`
- Functions → `docker/db-init/08-functions-procedures.sql`
- Materialized Views → Already in `07-materialized-views.sql`

## Summary of Working Files

### Total Content:
- **Views:** 21 views across 7 individual files
- **Functions:** 15+ functions across 7 individual files
- **Materialized Views:** Already in `07-materialized-views.sql` (11 active MVs confirmed)

## Exact File Structure

### 1. claim_summary_monthwise_report_final.sql (669 lines)
**Views (Lines 47-463):**
- v_claim_summary_monthwise (47-180)
- v_claim_summary_payerwise (185-324)
- v_claim_summary_encounterwise (329-463)

**Functions (Lines 468-595):**
- get_claim_summary_monthwise_params (468-556)
- get_claim_summary_report_params (561-594)

**Indexes (Lines 600-616):**
- Various performance indexes

### 2. balance_amount_report_implementation_final.sql (1,459 lines)
**Views (Lines 96-465):**
- v_balance_amount_to_be_received_base (96-263)
- v_balance_amount_to_be_received (287-342)
- v_initial_not_remitted_balance (353-405)
- v_after_resubmission_not_remitted_balance (416-465)

**Functions:**
- map_status_to_text (58-76) - Utility function
- get_balance_amount_to_be_received (496-1148)

### 3. remittances_resubmission_report_final.sql (1,105 lines)
**Views (Lines 134-534):**
- v_remittances_resubmission_activity_level (134-418)
- v_remittances_resubmission_claim_level (425-534)

**Functions:**
- get_remittances_resubmission_activity_level (560-853)
- get_remittances_resubmission_claim_level (856-1089)

### 4. claim_details_with_activity_final.sql (1,182 lines)
**Views (Lines 54-230):**
- v_claim_details_with_activity (54-230)

**Functions:**
- get_claim_details_with_activity (235-721)
- get_claim_details_summary (729-978)
- get_claim_details_filter_options (983-1082)

### 5. rejected_claims_report_final.sql (1,068 lines)
**Views (Lines 64-400):**
- v_rejected_claims_base (64-169)
- v_rejected_claims_summary_by_year (175-221)
- v_rejected_claims_summary (227-305)
- v_rejected_claims_receiver_payer (311-350)
- v_rejected_claims_claim_wise (356-400)

**Functions:**
- get_rejected_claims_summary (406-635)
- get_rejected_claims_receiver_payer (641-810)
- get_rejected_claims_claim_wise (816-1020)

### 6. doctor_denial_report_final.sql (1,112 lines)
**Views (Lines 53-369):**
- v_doctor_denial_high_denial (53-160)
- v_doctor_denial_summary (165-281)
- v_doctor_denial_detail (286-369)

**Functions:**
- get_doctor_denial_report (374-890)
- get_doctor_denial_summary (895-1034)

### 7. remittance_advice_payerwise_report_final.sql (456 lines)
**Views (Lines 40-296):**
- v_remittance_advice_header (40-122)
- v_remittance_advice_claim_wise (129-215)
- v_remittance_advice_activity_wise (222-296)

**Functions:**
- get_remittance_advice_report_params (302-361)

## Current Docker Files Status

### docker/db-init/06-report-views.sql
- Contains: 21 views (all present)
- Line count: ~1,827 lines
- Status: Needs to be updated with exact working definitions

### docker/db-init/08-functions-procedures.sql
- Contains: Core payment functions + 3 report-specific functions
- Missing: ~12 functions from individual files
- Status: Needs additional functions added

## Recommendation

Given the complexity and size of these files (6,669 total lines across 7 individual files), the most reliable approach is to:

**Option 1: Replace entire file contents** (Recommended)
- Copy ALL content from each individual `*_final.sql` file into corresponding sections of the Docker init files
- Ensures 100% accuracy since you've confirmed these work

**Option 2: Manual section-by-section copy**
- Use the line ranges provided above to copy each view/function individually
- More tedious but allows incremental testing

## Next Steps

Would you like me to:
1. **Create new consolidated 06-report-views.sql** by combining all view definitions from the 7 individual files?
2. **Update existing 08-functions-procedures.sql** by adding the missing functions from individual files?
3. **Create a backup** of the current Docker files before making changes?

Please confirm which approach you prefer, and I'll execute the consolidation.






