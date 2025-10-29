# Report Views Verification

**Generated:** 2025-10-25 18:57:21

## Summary

- **Source Files:** ../src/main/resources/db/reports_sql/
- **Docker File:** ../docker/db-init/06-report-views.sql
- **Total Objects Expected:** 61
- **Total Objects Found:** 2
- **Completeness:** 3.3%
- **Overall Accuracy:** 1.7%

## Objects Overview

| Object Name | Type | Status | Completeness | Accuracy | Notes |
|-------------|------|--------|--------------|----------|-------|
| claims_agg.monthly_resubmission_summary | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_claims_monthly_agg | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_remittances_resubmission_activity_level | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_rejected_claims_summary_tab | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.get_remittance_advice_report_params | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.v_claim_summary_payerwise | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| refresh_remittance_advice_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_rejected_claims_summary | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_claim_summary_encounterwise | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.v_remittance_advice_claim_wise | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.v_remittances_resubmission_activity_level | VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_balance_amount_overall | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.v_initial_not_remitted_balance | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| refresh_doctor_denial_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_balance_amount_resubmission | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.v_rejected_claims_receiver_payer | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.v_rejected_claims_claim_wise | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_claim_summary_payerwise | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_rejected_claims_by_year | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| refresh_payerwise_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.v_doctor_denial_detail | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_doctor_denial_summary | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_doctor_denial_high_denial | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_resubmission_cycles | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.v_rejected_claims_summary | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_balance_amount_summary | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_remittances_resubmission_claim_level | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.v_after_resubmission_not_remitted_balance | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_remittance_advice_summary | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| refresh_claim_details_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_claim_summary_monthwise | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims_agg.monthly_claim_details_summary | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.v_remittances_resubmission_claim_level | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_rejected_claims_receiver_payer | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.v_claim_summary_encounterwise | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| refresh_monthly_agg_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.get_balance_amount_to_be_received | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.v_balance_amount_to_be_received_base | VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| FUNCTION | COMMENT | ✓ | 100.0% | 40.1% | Perfect match |
| refresh_remittances_resubmission_activity_level_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_remittance_advice_header | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_doctor_denial_detail | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_rejected_claims_claim_wise | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| IF | INDEX | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_remittance_advice_claim_wise | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_balance_amount_initial | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| refresh_resubmission_cycles_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| MATERIALIZED | COMMENT | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.v_doctor_denial_summary | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims_agg.monthly_rejected_summary | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_remittance_advice_activity_wise | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims_agg.monthly_doctor_denial | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_claim_details_complete | MATERIALIZED_VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.v_remittance_advice_header | VIEW | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.v_remittance_advice_activity_wise | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| refresh_rejected_claims_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| refresh_encounterwise_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims_agg.monthly_balance_summary | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| VIEW | COMMENT | ✓ | 100.0% | 62.7% | Perfect match |
| claims_agg.monthly_remittance_summary | GRANT | ✗ | 0.0% | 0.0% | Missing from Docker |
| TABLE | COMMENT | ✗ | 0.0% | 0.0% | Missing from Docker |

## Missing Objects

- **claims_agg.monthly_resubmission_summary** (GRANT)
- **claims.mv_claims_monthly_agg** (MATERIALIZED_VIEW)
- **claims.mv_remittances_resubmission_activity_level** (MATERIALIZED_VIEW)
- **claims.mv_rejected_claims_summary_tab** (MATERIALIZED_VIEW)
- **claims.get_remittance_advice_report_params** (FUNCTION)
- **claims.v_claim_summary_payerwise** (GRANT)
- **refresh_remittance_advice_mv** (FUNCTION)
- **claims.mv_rejected_claims_summary** (MATERIALIZED_VIEW)
- **claims.mv_claim_summary_encounterwise** (MATERIALIZED_VIEW)
- **claims.v_remittance_advice_claim_wise** (GRANT)
- **claims.v_remittances_resubmission_activity_level** (VIEW)
- **claims.mv_balance_amount_overall** (MATERIALIZED_VIEW)
- **claims.v_initial_not_remitted_balance** (GRANT)
- **refresh_doctor_denial_mv** (FUNCTION)
- **claims.mv_balance_amount_resubmission** (MATERIALIZED_VIEW)
- **claims.v_rejected_claims_receiver_payer** (GRANT)
- **claims.v_rejected_claims_claim_wise** (GRANT)
- **claims.mv_claim_summary_payerwise** (MATERIALIZED_VIEW)
- **claims.mv_rejected_claims_by_year** (MATERIALIZED_VIEW)
- **refresh_payerwise_mv** (FUNCTION)
- **claims.v_doctor_denial_detail** (GRANT)
- **claims.mv_doctor_denial_summary** (MATERIALIZED_VIEW)
- **claims.mv_doctor_denial_high_denial** (MATERIALIZED_VIEW)
- **claims.mv_resubmission_cycles** (MATERIALIZED_VIEW)
- **claims.v_rejected_claims_summary** (GRANT)
- **claims.mv_balance_amount_summary** (MATERIALIZED_VIEW)
- **claims.mv_remittances_resubmission_claim_level** (MATERIALIZED_VIEW)
- **claims.v_after_resubmission_not_remitted_balance** (GRANT)
- **claims.mv_remittance_advice_summary** (MATERIALIZED_VIEW)
- **refresh_claim_details_mv** (FUNCTION)
- **claims.mv_claim_summary_monthwise** (MATERIALIZED_VIEW)
- **claims_agg.monthly_claim_details_summary** (GRANT)
- **claims.v_remittances_resubmission_claim_level** (GRANT)
- **claims.mv_rejected_claims_receiver_payer** (MATERIALIZED_VIEW)
- **claims.v_claim_summary_encounterwise** (GRANT)
- **refresh_monthly_agg_mv** (FUNCTION)
- **claims.get_balance_amount_to_be_received** (FUNCTION)
- **claims.v_balance_amount_to_be_received_base** (VIEW)
- **refresh_remittances_resubmission_activity_level_mv** (FUNCTION)
- **claims.mv_remittance_advice_header** (MATERIALIZED_VIEW)
- **claims.mv_doctor_denial_detail** (MATERIALIZED_VIEW)
- **claims.mv_rejected_claims_claim_wise** (MATERIALIZED_VIEW)
- **IF** (INDEX)
- **claims.mv_remittance_advice_claim_wise** (MATERIALIZED_VIEW)
- **claims.mv_balance_amount_initial** (MATERIALIZED_VIEW)
- **refresh_resubmission_cycles_mv** (FUNCTION)
- **MATERIALIZED** (COMMENT)
- **claims.v_doctor_denial_summary** (GRANT)
- **claims_agg.monthly_rejected_summary** (GRANT)
- **claims.mv_remittance_advice_activity_wise** (MATERIALIZED_VIEW)
- **claims_agg.monthly_doctor_denial** (GRANT)
- **claims.mv_claim_details_complete** (MATERIALIZED_VIEW)
- **claims.v_remittance_advice_header** (VIEW)
- **claims.v_remittance_advice_activity_wise** (GRANT)
- **refresh_rejected_claims_mv** (FUNCTION)
- **refresh_encounterwise_mv** (FUNCTION)
- **claims_agg.monthly_balance_summary** (GRANT)
- **claims_agg.monthly_remittance_summary** (GRANT)
- **TABLE** (COMMENT)

## Issues Found

### claims_agg.monthly_resubmission_summary

- Object 'claims_agg.monthly_resubmission_summary' exists in source but missing in Docker

### claims.mv_claims_monthly_agg

- Object 'claims.mv_claims_monthly_agg' exists in source but missing in Docker

### claims.mv_remittances_resubmission_activity_level

- Object 'claims.mv_remittances_resubmission_activity_level' exists in source but missing in Docker

### claims.mv_rejected_claims_summary_tab

- Object 'claims.mv_rejected_claims_summary_tab' exists in source but missing in Docker

### claims.get_remittance_advice_report_params

- Object 'claims.get_remittance_advice_report_params' exists in source but missing in Docker

### claims.v_claim_summary_payerwise

- Object 'claims.v_claim_summary_payerwise' exists in source but missing in Docker

### refresh_remittance_advice_mv

- Object 'refresh_remittance_advice_mv' exists in source but missing in Docker

### claims.mv_rejected_claims_summary

- Object 'claims.mv_rejected_claims_summary' exists in source but missing in Docker

### claims.mv_claim_summary_encounterwise

- Object 'claims.mv_claim_summary_encounterwise' exists in source but missing in Docker

### claims.v_remittance_advice_claim_wise

- Object 'claims.v_remittance_advice_claim_wise' exists in source but missing in Docker

### claims.v_remittances_resubmission_activity_level

- Object 'claims.v_remittances_resubmission_activity_level' exists in source but missing in Docker

### claims.mv_balance_amount_overall

- Object 'claims.mv_balance_amount_overall' exists in source but missing in Docker

### claims.v_initial_not_remitted_balance

- Object 'claims.v_initial_not_remitted_balance' exists in source but missing in Docker

### refresh_doctor_denial_mv

- Object 'refresh_doctor_denial_mv' exists in source but missing in Docker

### claims.mv_balance_amount_resubmission

- Object 'claims.mv_balance_amount_resubmission' exists in source but missing in Docker

### claims.v_rejected_claims_receiver_payer

- Object 'claims.v_rejected_claims_receiver_payer' exists in source but missing in Docker

### claims.v_rejected_claims_claim_wise

- Object 'claims.v_rejected_claims_claim_wise' exists in source but missing in Docker

### claims.mv_claim_summary_payerwise

- Object 'claims.mv_claim_summary_payerwise' exists in source but missing in Docker

### claims.mv_rejected_claims_by_year

- Object 'claims.mv_rejected_claims_by_year' exists in source but missing in Docker

### refresh_payerwise_mv

- Object 'refresh_payerwise_mv' exists in source but missing in Docker

### claims.v_doctor_denial_detail

- Object 'claims.v_doctor_denial_detail' exists in source but missing in Docker

### claims.mv_doctor_denial_summary

- Object 'claims.mv_doctor_denial_summary' exists in source but missing in Docker

### claims.mv_doctor_denial_high_denial

- Object 'claims.mv_doctor_denial_high_denial' exists in source but missing in Docker

### claims.mv_resubmission_cycles

- Object 'claims.mv_resubmission_cycles' exists in source but missing in Docker

### claims.v_rejected_claims_summary

- Object 'claims.v_rejected_claims_summary' exists in source but missing in Docker

### claims.mv_balance_amount_summary

- Object 'claims.mv_balance_amount_summary' exists in source but missing in Docker

### claims.mv_remittances_resubmission_claim_level

- Object 'claims.mv_remittances_resubmission_claim_level' exists in source but missing in Docker

### claims.v_after_resubmission_not_remitted_balance

- Object 'claims.v_after_resubmission_not_remitted_balance' exists in source but missing in Docker

### claims.mv_remittance_advice_summary

- Object 'claims.mv_remittance_advice_summary' exists in source but missing in Docker

### refresh_claim_details_mv

- Object 'refresh_claim_details_mv' exists in source but missing in Docker

### claims.mv_claim_summary_monthwise

- Object 'claims.mv_claim_summary_monthwise' exists in source but missing in Docker

### claims_agg.monthly_claim_details_summary

- Object 'claims_agg.monthly_claim_details_summary' exists in source but missing in Docker

### claims.v_remittances_resubmission_claim_level

- Object 'claims.v_remittances_resubmission_claim_level' exists in source but missing in Docker

### claims.mv_rejected_claims_receiver_payer

- Object 'claims.mv_rejected_claims_receiver_payer' exists in source but missing in Docker

### claims.v_claim_summary_encounterwise

- Object 'claims.v_claim_summary_encounterwise' exists in source but missing in Docker

### refresh_monthly_agg_mv

- Object 'refresh_monthly_agg_mv' exists in source but missing in Docker

### claims.get_balance_amount_to_be_received

- Object 'claims.get_balance_amount_to_be_received' exists in source but missing in Docker

### claims.v_balance_amount_to_be_received_base

- Object 'claims.v_balance_amount_to_be_received_base' exists in source but missing in Docker

### refresh_remittances_resubmission_activity_level_mv

- Object 'refresh_remittances_resubmission_activity_level_mv' exists in source but missing in Docker

### claims.mv_remittance_advice_header

- Object 'claims.mv_remittance_advice_header' exists in source but missing in Docker

### claims.mv_doctor_denial_detail

- Object 'claims.mv_doctor_denial_detail' exists in source but missing in Docker

### claims.mv_rejected_claims_claim_wise

- Object 'claims.mv_rejected_claims_claim_wise' exists in source but missing in Docker

### IF

- Object 'IF' exists in source but missing in Docker

### claims.mv_remittance_advice_claim_wise

- Object 'claims.mv_remittance_advice_claim_wise' exists in source but missing in Docker

### claims.mv_balance_amount_initial

- Object 'claims.mv_balance_amount_initial' exists in source but missing in Docker

### refresh_resubmission_cycles_mv

- Object 'refresh_resubmission_cycles_mv' exists in source but missing in Docker

### MATERIALIZED

- Object 'MATERIALIZED' exists in source but missing in Docker

### claims.v_doctor_denial_summary

- Object 'claims.v_doctor_denial_summary' exists in source but missing in Docker

### claims_agg.monthly_rejected_summary

- Object 'claims_agg.monthly_rejected_summary' exists in source but missing in Docker

### claims.mv_remittance_advice_activity_wise

- Object 'claims.mv_remittance_advice_activity_wise' exists in source but missing in Docker

### claims_agg.monthly_doctor_denial

- Object 'claims_agg.monthly_doctor_denial' exists in source but missing in Docker

### claims.mv_claim_details_complete

- Object 'claims.mv_claim_details_complete' exists in source but missing in Docker

### claims.v_remittance_advice_header

- Object 'claims.v_remittance_advice_header' exists in source but missing in Docker

### claims.v_remittance_advice_activity_wise

- Object 'claims.v_remittance_advice_activity_wise' exists in source but missing in Docker

### refresh_rejected_claims_mv

- Object 'refresh_rejected_claims_mv' exists in source but missing in Docker

### refresh_encounterwise_mv

- Object 'refresh_encounterwise_mv' exists in source but missing in Docker

### claims_agg.monthly_balance_summary

- Object 'claims_agg.monthly_balance_summary' exists in source but missing in Docker

### claims_agg.monthly_remittance_summary

- Object 'claims_agg.monthly_remittance_summary' exists in source but missing in Docker

### TABLE

- Object 'TABLE' exists in source but missing in Docker

## Detailed Comparisons

### claims_agg.monthly_resubmission_summary

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_claims_monthly_agg

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_remittances_resubmission_activity_level

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_rejected_claims_summary_tab

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.get_remittance_advice_report_params

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.v_claim_summary_payerwise

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### refresh_remittance_advice_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_rejected_claims_summary

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_claim_summary_encounterwise

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.v_remittance_advice_claim_wise

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.v_remittances_resubmission_activity_level

**Type:** VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_balance_amount_overall

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.v_initial_not_remitted_balance

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### refresh_doctor_denial_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_balance_amount_resubmission

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.v_rejected_claims_receiver_payer

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.v_rejected_claims_claim_wise

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_claim_summary_payerwise

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_rejected_claims_by_year

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### refresh_payerwise_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.v_doctor_denial_detail

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_doctor_denial_summary

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_doctor_denial_high_denial

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_resubmission_cycles

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.v_rejected_claims_summary

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_balance_amount_summary

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_remittances_resubmission_claim_level

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.v_after_resubmission_not_remitted_balance

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_remittance_advice_summary

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### refresh_claim_details_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_claim_summary_monthwise

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims_agg.monthly_claim_details_summary

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.v_remittances_resubmission_claim_level

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_rejected_claims_receiver_payer

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.v_claim_summary_encounterwise

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### refresh_monthly_agg_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.get_balance_amount_to_be_received

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.v_balance_amount_to_be_received_base

**Type:** VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### refresh_remittances_resubmission_activity_level_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_remittance_advice_header

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_doctor_denial_detail

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_rejected_claims_claim_wise

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### IF

**Type:** INDEX
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_remittance_advice_claim_wise

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_balance_amount_initial

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### refresh_resubmission_cycles_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### MATERIALIZED

**Type:** COMMENT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.v_doctor_denial_summary

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims_agg.monthly_rejected_summary

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_remittance_advice_activity_wise

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims_agg.monthly_doctor_denial

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_claim_details_complete

**Type:** MATERIALIZED_VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.v_remittance_advice_header

**Type:** VIEW
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.v_remittance_advice_activity_wise

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### refresh_rejected_claims_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### refresh_encounterwise_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims_agg.monthly_balance_summary

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims_agg.monthly_remittance_summary

**Type:** GRANT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### TABLE

**Type:** COMMENT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

