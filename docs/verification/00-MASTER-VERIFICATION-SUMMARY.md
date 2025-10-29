# Master Verification Summary

**Generated:** 2025-10-25 18:57:22

## Overall Statistics

- **Total Objects:** 155
- **Matching Objects:** 44 (28.4%)
- **Different Objects:** 20 (12.9%)
- **Missing Objects:** 81 (52.3%)
- **Extra Objects:** 10 (6.5%)
- **Average Completeness:** 36.7%
- **Average Accuracy:** 27.3%

## Summary by Object Type

| Type | Total | Matching | Different | Missing | Extra | Avg Completeness | Avg Accuracy |
|------|-------|----------|-----------|---------|-------|------------------|-------------|
| TRIGGER | 26 | 18 | 0 | 3 | 5 | 69.2% | 69.2% |
| GRANT | 30 | 8 | 0 | 21 | 1 | 26.7% | 25.3% |
| COMMENT | 21 | 11 | 0 | 8 | 2 | 52.4% | 31.7% |
| INDEX | 7 | 3 | 0 | 2 | 2 | 42.9% | 30.5% |
| MATERIALIZED_VIEW | 48 | 4 | 20 | 24 | 0 | 35.0% | 16.5% |
| FUNCTION | 20 | 0 | 0 | 20 | 0 | 0.0% | 0.0% |
| VIEW | 3 | 0 | 0 | 3 | 0 | 0.0% | 0.0% |

## Critical Issues (Completeness < 80%)

- **SCHEMA** (GRANT): 0.0% complete
- **VIEW** (COMMENT): 0.0% complete
- **trg_facility_dhpo_config_updated_at** (TRIGGER): 0.0% complete
- **FUNCTION** (GRANT): 0.0% complete
- **trg_integration_toggle_updated_at** (TRIGGER): 0.0% complete
- **table** (COMMENT): 0.0% complete
- **column** (COMMENT): 0.0% complete
- **if** (INDEX): 0.0% complete
- **table** (COMMENT): 0.0% complete
- **all** (GRANT): 0.0% complete
- **column** (COMMENT): 0.0% complete
- **claims_agg.monthly_resubmission_summary** (GRANT): 0.0% complete
- **claims.mv_claims_monthly_agg** (MATERIALIZED_VIEW): 0.0% complete
- **claims.mv_remittances_resubmission_activity_level** (MATERIALIZED_VIEW): 0.0% complete
- **claims.mv_rejected_claims_summary_tab** (MATERIALIZED_VIEW): 0.0% complete
- **claims.get_remittance_advice_report_params** (FUNCTION): 0.0% complete
- **claims.v_claim_summary_payerwise** (GRANT): 0.0% complete
- **refresh_remittance_advice_mv** (FUNCTION): 0.0% complete
- **claims.mv_rejected_claims_summary** (MATERIALIZED_VIEW): 0.0% complete
- **claims.mv_claim_summary_encounterwise** (MATERIALIZED_VIEW): 0.0% complete
- **claims.v_remittance_advice_claim_wise** (GRANT): 0.0% complete
- **claims.v_remittances_resubmission_activity_level** (VIEW): 0.0% complete
- **claims.mv_balance_amount_overall** (MATERIALIZED_VIEW): 0.0% complete
- **claims.v_initial_not_remitted_balance** (GRANT): 0.0% complete
- **refresh_doctor_denial_mv** (FUNCTION): 0.0% complete
- **claims.mv_balance_amount_resubmission** (MATERIALIZED_VIEW): 0.0% complete
- **claims.v_rejected_claims_receiver_payer** (GRANT): 0.0% complete
- **claims.v_rejected_claims_claim_wise** (GRANT): 0.0% complete
- **claims.mv_claim_summary_payerwise** (MATERIALIZED_VIEW): 0.0% complete
- **claims.mv_rejected_claims_by_year** (MATERIALIZED_VIEW): 0.0% complete
- **refresh_payerwise_mv** (FUNCTION): 0.0% complete
- **claims.v_doctor_denial_detail** (GRANT): 0.0% complete
- **claims.mv_doctor_denial_summary** (MATERIALIZED_VIEW): 0.0% complete
- **claims.mv_doctor_denial_high_denial** (MATERIALIZED_VIEW): 0.0% complete
- **claims.mv_resubmission_cycles** (MATERIALIZED_VIEW): 0.0% complete
- **claims.v_rejected_claims_summary** (GRANT): 0.0% complete
- **claims.mv_balance_amount_summary** (MATERIALIZED_VIEW): 0.0% complete
- **claims.mv_remittances_resubmission_claim_level** (MATERIALIZED_VIEW): 0.0% complete
- **claims.v_after_resubmission_not_remitted_balance** (GRANT): 0.0% complete
- **claims.mv_remittance_advice_summary** (MATERIALIZED_VIEW): 0.0% complete
- **refresh_claim_details_mv** (FUNCTION): 0.0% complete
- **claims.mv_claim_summary_monthwise** (MATERIALIZED_VIEW): 0.0% complete
- **claims_agg.monthly_claim_details_summary** (GRANT): 0.0% complete
- **claims.v_remittances_resubmission_claim_level** (GRANT): 0.0% complete
- **claims.mv_rejected_claims_receiver_payer** (MATERIALIZED_VIEW): 0.0% complete
- **claims.v_claim_summary_encounterwise** (GRANT): 0.0% complete
- **refresh_monthly_agg_mv** (FUNCTION): 0.0% complete
- **claims.get_balance_amount_to_be_received** (FUNCTION): 0.0% complete
- **claims.v_balance_amount_to_be_received_base** (VIEW): 0.0% complete
- **refresh_remittances_resubmission_activity_level_mv** (FUNCTION): 0.0% complete
- **claims.mv_remittance_advice_header** (MATERIALIZED_VIEW): 0.0% complete
- **claims.mv_doctor_denial_detail** (MATERIALIZED_VIEW): 0.0% complete
- **claims.mv_rejected_claims_claim_wise** (MATERIALIZED_VIEW): 0.0% complete
- **IF** (INDEX): 0.0% complete
- **claims.mv_remittance_advice_claim_wise** (MATERIALIZED_VIEW): 0.0% complete
- **claims.mv_balance_amount_initial** (MATERIALIZED_VIEW): 0.0% complete
- **refresh_resubmission_cycles_mv** (FUNCTION): 0.0% complete
- **MATERIALIZED** (COMMENT): 0.0% complete
- **claims.v_doctor_denial_summary** (GRANT): 0.0% complete
- **claims_agg.monthly_rejected_summary** (GRANT): 0.0% complete
- **claims.mv_remittance_advice_activity_wise** (MATERIALIZED_VIEW): 0.0% complete
- **claims_agg.monthly_doctor_denial** (GRANT): 0.0% complete
- **claims.mv_claim_details_complete** (MATERIALIZED_VIEW): 0.0% complete
- **claims.v_remittance_advice_header** (VIEW): 0.0% complete
- **claims.v_remittance_advice_activity_wise** (GRANT): 0.0% complete
- **refresh_rejected_claims_mv** (FUNCTION): 0.0% complete
- **refresh_encounterwise_mv** (FUNCTION): 0.0% complete
- **claims_agg.monthly_balance_summary** (GRANT): 0.0% complete
- **claims_agg.monthly_remittance_summary** (GRANT): 0.0% complete
- **TABLE** (COMMENT): 0.0% complete
- **claims.mv_claims_monthly_agg** (MATERIALIZED_VIEW): 10.0% complete
- **claims.mv_remittances_resubmission_activity_level** (MATERIALIZED_VIEW): 5.9% complete
- **refresh_remittance_advice_mv** (FUNCTION): 0.0% complete
- **claims.mv_rejected_claims_summary** (MATERIALIZED_VIEW): 14.3% complete
- **claims.mv_claim_summary_encounterwise** (MATERIALIZED_VIEW): 17.6% complete
- **refresh_doctor_denial_mv** (FUNCTION): 0.0% complete
- **claims.mv_claim_summary_payerwise** (MATERIALIZED_VIEW): 17.6% complete
- **refresh_payerwise_mv** (FUNCTION): 0.0% complete
- **claims.mv_doctor_denial_summary** (MATERIALIZED_VIEW): 0.0% complete
- **claims.mv_resubmission_cycles** (MATERIALIZED_VIEW): 25.0% complete
- **refresh_claim_details_mv** (FUNCTION): 0.0% complete
- **refresh_monthly_agg_mv** (FUNCTION): 0.0% complete
- **FUNCTION** (COMMENT): 0.0% complete
- **refresh_remittances_resubmission_activity_level_mv** (FUNCTION): 0.0% complete
- **refresh_resubmission_cycles_mv** (FUNCTION): 0.0% complete
- **claims.mv_claim_details_complete** (MATERIALIZED_VIEW): 12.5% complete
- **refresh_rejected_claims_mv** (FUNCTION): 0.0% complete
- **refresh_encounterwise_mv** (FUNCTION): 0.0% complete
- **trg_update_claim_payment_remittance_activity** (TRIGGER): 0.0% complete

## Recommendations

- **81 objects** are missing from Docker files and need to be added
- **20 objects** have differences and need to be reviewed/corrected
- **10 objects** exist in Docker but not in source (verify if intentional)
- Overall completeness is 36.7% - aim for 95%+
- Overall accuracy is 27.3% - aim for 95%+
