<!-- 1d88906f-843b-460e-b0b3-0e537c9dab9f 3b3b3f15-f714-47d7-9bd8-d8176b8f2d36 -->
# Claims Reporting Layer Verification & Analysis Plan

## Overview

Perform a systematic analysis of all 7 canonical reports plus materialized views to verify:

1. Naming convention compliance (v_*, mv_*, get_*, indexes)
2. Data flow correctness from ingestion → persistence → reporting
3. Cumulative-with-cap logic implementation using claim_activity_summary
4. Business logic alignment with requirements
5. Java API integration patterns

**NOTE: This is ANALYSIS ONLY - NO CODE CHANGES will be made**

## Reports to Analyze

### Report A: Balance Amount Report

- **File**: `balance_amount_report_implementation_final.sql`
- **Tabs**: Tab A (Overall), Tab B (Initial Not Remitted), Tab C (Post-Resubmission)
- **Views**: `v_balance_amount_to_be_received_base`, tab views
- **Functions**: `get_balance_amount_*` functions
- **MV**: `mv_balance_amount_summary`

### Report B: Claim Details With Activity

- **File**: `claim_details_with_activity_final.sql`
- **Main View**: `v_claim_details_with_activity`
- **Functions**: `get_claim_details_with_activity`, `get_claim_details_summary`
- **MV**: `mv_claim_details_complete`

### Report C: Claim Summary Monthwise

- **File**: `claim_summary_monthwise_report_final.sql`
- **Tabs**: Tab A (Monthwise), Tab B (Payerwise), Tab C (Encounterwise)
- **Views**: `v_claim_summary_monthwise`, `v_claim_summary_payerwise`, `v_claim_summary_encounterwise`
- **Functions**: `get_claim_summary_monthwise_params`, `get_claim_summary_report_params`
- **MVs**: `mv_claims_monthly_agg`, `mv_claim_summary_payerwise`, `mv_claim_summary_encounterwise`

### Report D: Doctor Denial Report

- **File**: `doctor_denial_report_final.sql`
- **Tabs**: Tab A (High Denial), Tab B (Summary), Tab C (Detail)
- **Views**: `v_doctor_denial_high_denial`, `v_doctor_denial_summary`, `v_doctor_denial_detail`
- **Functions**: `get_doctor_denial_report`, `get_doctor_denial_summary`
- **MV**: `mv_doctor_denial_summary`

### Report E: Rejected Claims Report

- **File**: `rejected_claims_report_final.sql`
- **Views**: `v_rejected_claims_base`, `v_rejected_claims_summary`, etc.
- **Functions**: `get_rejected_claims_summary`, `get_rejected_claims_receiver_payer`, `get_rejected_claims_claim_wise`
- **MV**: `mv_rejected_claims_summary`

### Report F: Remittance Advice Payerwise

- **File**: `remittance_advice_payerwise_report_final.sql`
- **Tabs**: Tab A (Header), Tab B (Claim Wise), Tab C (Activity Wise)
- **Views**: `v_remittance_advice_header`, `v_remittance_advice_claim_wise`, `v_remittance_advice_activity_wise`
- **MV**: `mv_remittance_advice_summary`

### Report G: Remittances & Resubmission

- **File**: `remittances_resubmission_report_final.sql`
- **Levels**: Activity Level, Claim Level
- **Views**: `v_remittances_resubmission_activity_level`, `v_remittances_resubmission_claim_level`
- **Functions**: `get_remittances_resubmission_activity_level`, `get_remittances_resubmission_claim_level`
- **MVs**: `mv_remittances_resubmission_activity_level`, `mv_resubmission_cycles`

### Section H: Materialized Views Infrastructure

- **File**: `sub_second_materialized_views.sql`
- **Count**: 20+ materialized views (to be confirmed during analysis)
- **Purpose**: Sub-second performance optimization

## Key Clarifications

### "Latest Denial Semantics" Explanation

When a claim activity is resubmitted multiple times and receives denials across cycles:

- **WRONG**: Aggregating ALL denial codes from all remittance cycles (causes confusion, shows outdated denials)
- **CORRECT**: Using ONLY the most recent denial code from the latest remittance cycle
- **Implementation**: In `claim_activity_summary`, the `denial_codes` array is ordered, and reports should use `(denial_codes)[1]` for latest
- **Business Rationale**: Only the current/latest denial status matters for operational decisions; historical denials are tracked in audit trail but not in active reports

Example:

```
Activity A123:
- Remittance 1 (Jan): Denial Code "D001" (rejected)
- Resubmission (Feb): No denial, but partial payment
- Remittance 2 (Mar): Denial Code "D002" (different rejection reason)

Report should show: D002 (latest), NOT both D001 and D002
```

## Analysis Methodology

### Step 1: Data Flow Verification

Trace complete flow: ClaimXmlParserStax → PersistService → claim_payment_functions → Views/MVs → Java Services → REST API

### Step 2: Naming Convention Audit

Verify: v_*, mv_*, get_*, idx_* patterns

### Step 3: Cumulative-With-Cap Logic Verification

Check usage of `claim_activity_summary` and avoidance of raw `remittance_activity` aggregations

### Step 4: Business Logic Verification

Validate joins, aggregations, calculations, filters against requirements

### Step 5: Java Integration Verification

Cross-reference SQL functions with Java service classes and controller endpoints

## Deliverables

1. **Comprehensive Analysis Document** - Full report per A-G + H
2. **Summary Table** - Tabular comparison of all reports
3. **Critical Issues List** - Prioritized by Severity 1-4
4. **Verification Script Recommendations** - SQL queries for validation

### To-dos

- [ ] Count and list all materialized views in sub_second_materialized_views.sql to confirm 20+ count
- [ ] Analyze Report A (Balance Amount): document objects, data flow, cumulative-with-cap usage, naming, Java integration
- [ ] Analyze Report B (Claim Details With Activity): document objects, data flow, cumulative-with-cap usage, naming, Java integration
- [ ] Analyze Report C (Claim Summary Monthwise): document objects, data flow, cumulative-with-cap usage, naming, Java integration
- [ ] Analyze Report D (Doctor Denial): document objects, data flow, cumulative-with-cap usage, naming, Java integration
- [ ] Analyze Report E (Rejected Claims): document objects, data flow, cumulative-with-cap usage, naming, Java integration
- [ ] Analyze Report F (Remittance Advice Payerwise): document objects, data flow, cumulative-with-cap usage, naming, Java integration
- [ ] Analyze Report G (Remittances & Resubmission): document objects, data flow, cumulative-with-cap usage, naming, Java integration
- [ ] Analyze Section H (Materialized Views Infrastructure): document all MVs, indexes, refresh patterns, performance characteristics
- [ ] Create summary table with columns: Report Name, Underlying Objects, Business Meaning, Matches Expected Output, Uses Cumulative-With-Cap, Naming Compliant, Notes/Fixes
- [ ] Compile critical issues list prioritized by Severity 1 (Critical) to 4 (Low) with specific findings from all reports
- [ ] Generate verification script recommendations: correctness queries, cumulative-with-cap tests, edge case scenarios