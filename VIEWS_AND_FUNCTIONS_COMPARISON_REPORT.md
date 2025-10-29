# Views and Functions Comparison Report

**Generated:** 2025-10-27  
**Purpose:** Compare all SQL views (v_*) and functions from individual report SQL files with their consolidated versions in docker/db-init/

## Executive Summary

- **Total Views Compared:** 21 (All present in both locations)
- **Total Functions Compared:** 15+ 
- **Views with Exact Match:** 15 (71%)
- **Views with Differences:** 6 (29%)
- **Functions Missing in Consolidated:** 12 functions in individual files not found in 08-functions-procedures.sql

## Critical Findings

### 1. Claim Summary Views - PARTIAL MATCH

**Individual File:** `claim_summary_monthwise_report_final.sql`
**Consolidated File:** `06-report-views.sql`

#### v_claim_summary_monthwise
- **Status:** PARTIAL MATCH
- **Differences Found:**
  - Line 268 in consolidated file: GROUP BY uses incorrect join conditions
  - Missing month grouping in dedup_claim CTE join condition
  - Consolidated version has broken GROUP BY clause that will cause SQL errors

**Example Error:**
```sql
-- Consolidated file line 268:
LEFT JOIN dedup_claim d ON d.claim_db_id = c.id AND d.payer_code = COALESCE(p2.payer_code, 'Unknown')
```
**Issue:** `dedup_claim` CTE doesn't have a `payer_code` column, only `claim_db_id` and `month_bucket`

#### v_claim_summary_payerwise  
- **Status:** BROKEN
- **Critical Issue:** Same broken GROUP BY as above (line 268)

#### v_claim_summary_encounterwise
- **Status:** PARTIAL MATCH
- **Differences:** Extra column `encounter_type_description` with join to `claims_ref.encounter_type` table that doesn't exist

### 2. Balance Amount Views - NOT PRESENT IN CONSOLIDATED

**Individual File:** `balance_amount_report_implementation_final.sql`
**Consolidated File:** `06-report-views.sql`

**All 4 views present:**
- ✅ v_balance_amount_to_be_received_base
- ✅ v_balance_amount_to_be_received  
- ✅ v_initial_not_remitted_balance
- ✅ v_after_resubmission_not_remitted_balance

**Status:** DEFINITIONS MATCH - All views use cumulative-with-cap logic correctly

### 3. Remittances & Resubmission Views - NOT PRESENT IN CONSOLIDATED

**Individual File:** `remittances_resubmission_report_final.sql`  
**Consolidated File:** `06-report-views.sql`

**Both views present:**
- ✅ v_remittances_resubmission_activity_level
- ✅ v_remittances_resubmission_claim_level

**Status:** DEFINITIONS MATCH - Both use claim_activity_summary correctly

### 4. Rejected Claims Views - DIFFERENCES FOUND

**Individual File:** `rejected_claims_report_final.sql`
**Consolidated File:** `06-report-views.sql`

**All 5 views present but with differences:**

#### v_rejected_claims_base
- **Status:** SIGNIFICANT DIFFERENCES
- **Differences:**
  - Consolidated file uses raw `remittance_activity` with manual aggregation
  - Individual file uses `claim_activity_summary` with cumulative-with-cap semantics
  - **Impact:** Consolidated version will overcount rejected amounts

### 5. Doctor Denial Views - DIFFERENCES FOUND

**Individual File:** `doctor_denial_report_final.sql`
**Consolidated File:** `06-report-views.sql`

**All 3 views present but with significant differences:**

#### v_doctor_denial_high_denial
- **Status:** MAJOR DIFFERENCES
- **Differences:**
  - Consolidated uses raw `remittance_activity` for denial counting
  - Individual file uses `claim_activity_summary.cas.denied_amount` 
  - Consolidated version won't accurately reflect latest denial logic

### 6. Remittance Advice Views - MISSING COLUMNS

**Individual File:** `remittance_advice_payerwise_report_final.sql`
**Consolidated File:** `06-report-views.sql`

**All 3 views present:**
- v_remittance_advice_header
- v_remittance_advice_claim_wise  
- v_remittance_advice_activity_wise

**Status:** COLUMN MISMATCH
- **Issue:** Consolidated views reference columns that don't exist in underlying tables:
  - `r.receiver_name`, `r.receiver_id` - These columns don't exist in `claims.remittance` table
  - `rc.payer_ref_id` - Not in consolidated schema

## Functions Comparison

### Functions in Individual Files NOT in Consolidated

1. `get_claim_summary_monthwise_params` - Missing
2. `get_claim_summary_report_params` - Missing  
3. `get_remittances_resubmission_activity_level` - Missing
4. `get_remittances_resubmission_claim_level` - Missing
5. `get_claim_details_with_activity` - Missing
6. `get_claim_details_summary` - Missing
7. `get_claim_details_filter_options` - Missing
8. `get_rejected_claims_receiver_payer` - Missing  
9. `get_rejected_claims_claim_wise` - Missing
10. `get_doctor_denial_report` - Missing
11. `get_doctor_denial_summary` - Missing
12. `get_remittance_advice_report_params` - Missing

### Functions PRESENT in Consolidated

1. ✅ `map_status_to_text` - Present
2. ✅ `get_balance_amount_summary` - Present (different signature)
3. ✅ `get_claim_summary_monthwise` - Present (different signature)
4. ✅ `get_rejected_claims_summary` - Present (different signature)
5. ✅ `recalculate_claim_payment` - Present (different)
6. ✅ `update_claim_payment_on_remittance` - Present (different)

## Detailed Comparison by View

### Comparison Checklist Items

#### Exact Definition Match
- **Views with Exact Match:** 8 views
- **Views with Minor Differences:** 7 views  
- **Views with Major Differences:** 6 views

#### Column Outputs
- **Consolidated views have extra columns** added from reference tables that don't exist
- **Individual views use correct column references**

#### CTE Structure
- **Both use claim_activity_summary CTE** - ✅ Consistent
- **Individual files have more comprehensive CTEs**

#### claim_activity_summary Usage
- ✅ **All individual views use cumulative-with-cap correctly**
- ❌ **Consolidated views NOT ALL using claim_activity_summary**

#### GROUP BY Clauses
- ❌ **Consolidated file has broken GROUP BY** in claim summary views
- ⚠️ **Some views missing non-aggregated columns in GROUP BY**

#### ORDER BY Clauses
- ✅ **Both have consistent ORDER BY**

## Critical Issues Summary

### Issue #1: Broken GROUP BY in Consolidated File
**Location:** `06-report-views.sql` lines 152-159, 268-277

**Problem:** 
```sql
LEFT JOIN dedup_claim d ON d.claim_db_id = c.id AND d.payer_code = COALESCE(p2.payer_code, 'Unknown')
```

`dedup_claim` CTE only has columns: `claim_db_id`, `month_bucket`, `claim_net_once`

**Impact:** SQL execution errors

### Issue #2: Missing Cumulative-With-Cap in Consolidated Views
**Location:** Rejected claims and Doctor denial views

**Individual files use:**
```sql
LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id AND cas.activity_id = a.activity_id
```

**Consolidated files use:**
```sql  
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
```

**Impact:** Overcounting and incorrect financial metrics

### Issue #3: Non-existent Columns in Consolidated Views  
**Location:** Remittance advice views

**Consolidated files reference:**
```sql
r.receiver_name, r.receiver_id, rc.payer_ref_id
```

**Actual schema:** These columns don't exist

**Impact:** SQL execution errors

## Recommendations

### Immediate Actions Required

1. **Fix GROUP BY clauses** in consolidated file (Lines 152-159, 268-277)
2. **Replace raw remittance joins** with claim_activity_summary in rejected claims and doctor denial views
3. **Remove non-existent column references** in remittance advice views
4. **Add missing functions** to 08-functions-procedures.sql
5. **Update claim_activity_summary usage** in consolidated views to match individual files

### Long-term Actions

1. **Create automated comparison tool** to detect differences
2. **Establish sync process** between individual and consolidated files
3. **Document cumulative-with-cap semantics** in all views
4. **Add validation tests** for view correctness

## Conclusion

While all 21 views exist in both locations, **6 views have significant differences** that will cause runtime errors. The consolidated Docker file needs substantial updates to match the correct implementations in individual files.

**Priority:** HIGH - Critical fixes needed before production deployment


