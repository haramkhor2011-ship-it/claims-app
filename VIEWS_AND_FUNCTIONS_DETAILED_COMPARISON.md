# Detailed Views and Functions Comparison Report

**Generated:** 2025-10-27  
**Purpose:** Compare working views/functions from individual files with consolidated Docker files  
**Status:** Working versions exist in individual files; need to sync to consolidated files

## Summary

- **Total Views:** 21 views exist in both locations
- **Total Functions:** 15 functions in individual files, 3 currently in consolidated file
- **Action Required:** Copy 12 additional functions from individual files to consolidated 08-functions-procedures.sql

## Views Comparison

All 21 views exist in both `06-report-views.sql` and individual report files. Key views verified:

### 1. Claim Summary Views (3 views)
- ✅ `v_claim_summary_monthwise`
- ✅ `v_claim_summary_payerwise`
- ✅ `v_claim_summary_encounterwise`

### 2. Balance Amount Views (4 views)
- ✅ `v_balance_amount_to_be_received_base`
- ✅ `v_balance_amount_to_be_received`
- ✅ `v_initial_not_remitted_balance`
- ✅ `v_after_resubmission_not_remitted_balance`

### 3. Remittance Views (2 views)
- ✅ `v_remittances_resubmission_activity_level`
- ✅ `v_remittances_resubmission_claim_level`

### 4. Claim Details View (1 view)
- ✅ `v_claim_details_with_activity`

### 5. Rejected Claims Views (5 views)
- ✅ `v_rejected_claims_base`
- ✅ `v_rejected_claims_summary_by_year`
- ✅ `v_rejected_claims_summary`
- ✅ `v_rejected_claims_receiver_payer`
- ✅ `v_rejected_claims_claim_wise`

### 6. Doctor Denial Views (3 views)
- ✅ `v_doctor_denial_high_denial`
- ✅ `v_doctor_denial_summary`
- ✅ `v_doctor_denial_detail`

### 7. Remittance Advice Views (3 views)
- ✅ `v_remittance_advice_header`
- ✅ `v_remittance_advice_claim_wise`
- ✅ `v_remittance_advice_activity_wise`

## Functions Comparison

### Already in 08-functions-procedures.sql (Section 7 - Lines 849-1054)

1. **get_balance_amount_summary** (Line 855)
   - Exists in consolidated file
   - Source: balance_amount_report_implementation_final.sql (Line 496)
   - Status: ⚠️ Check if definitions match

2. **get_claim_summary_monthwise** (Line 918)
   - Exists in consolidated file
   - Source: claim_summary_monthwise_report_final.sql (Line 468)
   - Status: ⚠️ Check if definitions match

3. **get_rejected_claims_summary** (Line 990)
   - Exists in consolidated file
   - Source: rejected_claims_report_final.sql (Line 406)
   - Status: ⚠️ Check if definitions match

### Missing from 08-functions-procedures.sql (Need to Add)

**From claim_summary_monthwise_report_final.sql:**
- ❌ `get_claim_summary_monthwise_params` (Line 468)
- ❌ `get_claim_summary_report_params` (Line 561)

**From balance_amount_report_implementation_final.sql:**
- ❌ `map_status_to_text` (Line 58) - Note: This exists in 06-report-views.sql at line 403
- ❌ `get_balance_amount_to_be_received` (Line 496) - Note: Different from get_balance_amount_summary

**From remittances_resubmission_report_final.sql:**
- ❌ `get_remittances_resubmission_activity_level` (Line 560)
- ❌ `get_remittances_resubmission_claim_level` (Line 856)

**From claim_details_with_activity_final.sql:**
- ❌ `get_claim_details_with_activity` (Line 235)
- ❌ `get_claim_details_summary` (Line 729)
- ❌ `get_claim_details_filter_options` (Line 983)

**From rejected_claims_report_final.sql:**
- ❌ `get_rejected_claims_receiver_payer` (Line 641)
- ❌ `get_rejected_claims_claim_wise` (Line 816)

**From doctor_denial_report_final.sql:**
- ❌ `get_doctor_denial_report` (Line 374)
- ❌ `get_doctor_denial_summary` (Line 895)

**From remittance_advice_payerwise_report_final.sql:**
- ❌ `get_remittance_advice_report_params` (Line 312)

## Key Differences to Verify

Since your individual files ran successfully, we should verify:

### Views Differences
1. All views use `claim_activity_summary` correctly
2. All aggregations use cumulative-with-cap semantics
3. GROUP BY clauses are complete
4. Column outputs match expectations

### Functions Differences
The consolidated file has simplified versions of 3 functions. The individual files have more comprehensive functions with additional parameters and features.

## Recommended Action Plan

Since your working versions are in individual files:

### Option 1: Complete Copy (Recommended)
1. Copy all 21 views from individual files to replace 06-report-views.sql
2. Add all 12 missing functions to 08-functions-procedures.sql Section 7
3. Keep the 3 existing functions but verify they match

### Option 2: Selective Copy
1. Compare each view/function line-by-line
2. Only copy if differences are found
3. Keep consolidated versions where they match

### Option 3: Manual Review
1. Provide detailed diff for each view/function
2. You review and decide what to copy
3. Manually update consolidated files

## Next Steps

Would you like me to:
A) Extract all working views and create a replacement 06-report-views.sql file?
B) Extract all working functions and create additions for 08-functions-procedures.sql?
C) Create a detailed line-by-line comparison for your review?
D) Just verify the current consolidated files are using working versions?






