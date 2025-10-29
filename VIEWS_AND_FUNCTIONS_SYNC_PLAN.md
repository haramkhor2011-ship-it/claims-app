# Views and Functions Sync Plan

## Overview
Your working views and functions in `src/main/resources/db/reports_sql/` need to be synced with the consolidated Docker files `docker/db-init/06-report-views.sql` and `08-functions-procedures.sql`.

## Status Summary

### Views (21 Total)
**Status:** All 21 views exist in both locations
- 06-report-views.sql contains all views
- Individual files contain the same 21 views
- **Action Required:** Verify definitions match exactly

### Functions Status

#### Already in 08-functions-procedures.sql:
1. ✅ `get_balance_amount_summary` (line 855)
2. ✅ `get_claim_summary_monthwise` (line 918)
3. ✅ `get_rejected_claims_summary` (line 990)

#### Potentially Missing Functions (Need Verification):
Based on individual files, these functions exist but may not be in consolidated file:

From `claim_summary_monthwise_report_final.sql`:
1. ⚠️ `get_claim_summary_monthwise_params`
2. ⚠️ `get_claim_summary_report_params`

From `balance_amount_report_implementation_final.sql`:
3. ⚠️ `map_status_to_text` (already in 06-report-views.sql at line 403, but should be in 08 file)
4. ⚠️ `get_balance_amount_to_be_received`

From `remittances_resubmission_report_final.sql`:
5. ⚠️ `get_remittances_resubmission_activity_level`
6. ⚠️ `get_remittances_resubmission_claim_level`

From `claim_details_with_activity_final.sql`:
7. ⚠️ `get_claim_details_with_activity`
8. ⚠️ `get_claim_details_summary`
9. ⚠️ `get_claim_details_filter_options`

From `rejected_claims_report_final.sql`:
10. ⚠️ `get_rejected_claims_receiver_payer`
11. ⚠️ `get_rejected_claims_claim_wise`

From `doctor_denial_report_final.sql`:
12. ⚠️ `get_doctor_denial_report`
13. ⚠️ `get_doctor_denial_summary`

From `remittance_advice_payerwise_report_final.sql`:
14. ⚠️ `get_remittance_advice_report_params`

## Detailed Comparison Required

### Step 1: Extract Working Definitions
Extract all view and function definitions from individual files for comparison.

### Step 2: Compare Line-by-Line
For each view and function:
- Compare exact SQL text
- Check CTE structures
- Verify column outputs
- Validate aggregations using `claim_activity_summary`
- Confirm GROUP BY and ORDER BY clauses
- Check all JOIN structures

### Step 3: Document Differences
Create a detailed diff showing:
- Exact matches (no action)
- Minor differences (whitespace, comments)
- Major differences (logic, columns, aggregations)
- Missing objects

### Step 4: Sync Working Versions
Copy the working versions from individual files to consolidated files.

## Recommended Approach

Since your individual files have been tested and work correctly:

1. **Backup consolidated files**
2. **Extract all working views/functions from individual files**
3. **Replace consolidated file contents with working versions**
4. **Verify no syntax errors**
5. **Test critical paths**

Would you like me to:
A) Create a detailed line-by-line comparison document?
B) Extract all working views/functions and prepare replacement files?
C) Provide a side-by-side diff showing differences?






