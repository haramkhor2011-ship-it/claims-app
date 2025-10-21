# TRADITIONAL VIEWS vs MATERIALIZED VIEWS MAPPING ANALYSIS

## Overview
This document analyzes the relationship between traditional views and materialized views to ensure data consistency across all report tabs.

## Complete Mapping Analysis

### 1. **BALANCE AMOUNT REPORT**

#### Traditional Views (3 tabs):
- `v_balance_amount_to_be_received_base` (Base view)
- `v_balance_amount_to_be_received` (Tab A: Overall balances)
- `v_initial_not_remitted_balance` (Tab B: Initial not remitted)
- `v_after_resubmission_not_remitted_balance` (Tab C: After resubmission)

#### Materialized View:
- `mv_balance_amount_summary` (Single MV for all tabs)

#### **❌ POTENTIAL MISMATCH**: 
- **Traditional**: 3 separate views with different business logic
- **MV**: 1 consolidated view
- **Risk**: Functions using MV might not match specific tab requirements

### 2. **REMITTANCE ADVICE REPORT**

#### Traditional Views (3 tabs):
- `v_remittance_advice_header` (Tab A: Header summary)
- `v_remittance_advice_claim_wise` (Tab B: Claim-wise details)
- `v_remittance_advice_activity_wise` (Tab C: Activity-wise details)

#### Materialized View:
- `mv_remittance_advice_summary` (Single MV)

#### **❌ POTENTIAL MISMATCH**:
- **Traditional**: 3 views with different aggregation levels
- **MV**: 1 consolidated view
- **Risk**: Functions using MV might not match specific tab requirements

### 3. **CLAIM SUMMARY REPORT**

#### Traditional Views (3 tabs):
- `v_claim_summary_monthwise` (Tab A: Monthwise)
- `v_claim_summary_payerwise` (Tab B: Payerwise)
- `v_claim_summary_encounterwise` (Tab C: Encounterwise)

#### Materialized Views (2 MVs):
- `mv_claim_summary_payerwise` (Matches Tab B)
- `mv_claim_summary_encounterwise` (Matches Tab C)
- **❌ MISSING**: No MV for `v_claim_summary_monthwise` (Tab A)

#### **❌ POTENTIAL MISMATCH**:
- **Traditional**: 3 views with different grouping
- **MVs**: Only 2 MVs, missing monthwise
- **Risk**: Tab A functions might not have MV equivalent

### 4. **DOCTOR DENIAL REPORT**

#### Traditional Views (3 tabs):
- `v_doctor_denial_high_denial` (Tab A: High denial doctors)
- `v_doctor_denial_summary` (Tab B: Summary)
- `v_doctor_denial_detail` (Tab C: Detail)

#### Materialized View:
- `mv_doctor_denial_summary` (Single MV)

#### **❌ POTENTIAL MISMATCH**:
- **Traditional**: 3 views with different business logic
- **MV**: 1 consolidated view
- **Risk**: Functions using MV might not match specific tab requirements

### 5. **REJECTED CLAIMS REPORT**

#### Traditional Views (5 tabs):
- `v_rejected_claims_base` (Base view)
- `v_rejected_claims_summary_by_year` (Tab A: By year)
- `v_rejected_claims_summary` (Tab B: Summary)
- `v_rejected_claims_receiver_payer` (Tab C: Receiver/Payer)
- `v_rejected_claims_claim_wise` (Tab D: Claim-wise)

#### Materialized View:
- `mv_rejected_claims_summary` (Single MV)

#### **❌ POTENTIAL MISMATCH**:
- **Traditional**: 5 views with different business logic
- **MV**: 1 consolidated view
- **Risk**: Functions using MV might not match specific tab requirements

### 6. **RESUBMISSION REPORT**

#### Traditional Views (2 tabs):
- `v_remittances_resubmission_activity_level` (Tab A: Activity level)
- `v_remittances_resubmission_claim_level` (Tab B: Claim level)

#### Materialized Views (2 MVs):
- `mv_remittances_resubmission_activity_level` (Matches Tab A)
- `mv_resubmission_cycles` (Different from Tab B)

#### **❌ POTENTIAL MISMATCH**:
- **Traditional**: 2 views with different aggregation levels
- **MVs**: 2 MVs but `mv_resubmission_cycles` doesn't match `v_remittances_resubmission_claim_level`
- **Risk**: Tab B functions might not have correct MV equivalent

### 7. **CLAIM DETAILS REPORT**

#### Traditional Views (1 view):
- `v_claim_details_with_activity` (Single comprehensive view)

#### Materialized View:
- `mv_claim_details_complete` (Single MV)

#### **✅ GOOD MATCH**:
- **Traditional**: 1 comprehensive view
- **MV**: 1 comprehensive MV
- **Status**: Should match well

### 8. **MONTHLY AGGREGATES**

#### Traditional Views:
- Various monthly aggregation views

#### Materialized View:
- `mv_claims_monthly_agg` (Single MV)

#### **✅ GOOD MATCH**:
- **Traditional**: Monthly aggregations
- **MV**: Monthly aggregations
- **Status**: Should match well

## Critical Issues Identified

### 🚨 **MAJOR CONCERN: Tab-Specific Logic Missing**

**Problem**: Most reports have **multiple tabs** with **different business logic**, but the MVs are **consolidated into single views**.

**Examples**:
1. **Balance Amount Report**: 3 tabs → 1 MV
2. **Remittance Advice**: 3 tabs → 1 MV  
3. **Doctor Denial**: 3 tabs → 1 MV
4. **Rejected Claims**: 5 tabs → 1 MV

### 🚨 **MISSING MV COVERAGE**

**Problem**: Some traditional views don't have MV equivalents:
1. `v_claim_summary_monthwise` (Tab A) - No MV equivalent
2. `v_remittances_resubmission_claim_level` (Tab B) - Wrong MV equivalent

### 🚨 **BUSINESS LOGIC DIFFERENCES**

**Problem**: Traditional views have **tab-specific filtering and aggregation** that MVs might not replicate:

**Examples**:
- **Balance Amount Tab B**: "Initial not remitted" (no payments yet)
- **Balance Amount Tab C**: "After resubmission" (resubmitted but still pending)
- **Remittance Advice Tab A**: Header summary vs Tab C: Activity-wise details

## Recommendations

### 1. **IMMEDIATE ACTION REQUIRED**

**Audit Function Usage**: Check which functions are using which views/MVs:

```sql
-- Find all functions that reference traditional views
SELECT routine_name, routine_definition 
FROM information_schema.routines 
WHERE routine_definition LIKE '%v_balance_amount%'
   OR routine_definition LIKE '%v_remittance_advice%'
   OR routine_definition LIKE '%v_claim_summary%'
   OR routine_definition LIKE '%v_doctor_denial%'
   OR routine_definition LIKE '%v_rejected_claims%';
```

### 2. **CREATE MISSING MVs**

**Priority 1**: Create missing MVs for complete coverage:
- `mv_claim_summary_monthwise` (for Tab A)
- `mv_remittances_resubmission_claim_level` (for Tab B)

### 3. **VALIDATE DATA CONSISTENCY**

**Priority 2**: Compare traditional view vs MV outputs:

```sql
-- Example: Compare Balance Amount Tab A
SELECT COUNT(*) FROM claims.v_balance_amount_to_be_received;
SELECT COUNT(*) FROM claims.mv_balance_amount_summary;

-- Compare key metrics
SELECT 
  SUM(pending_amount) as traditional_pending,
  COUNT(*) as traditional_count
FROM claims.v_balance_amount_to_be_received;

SELECT 
  SUM(pending_amount) as mv_pending,
  COUNT(*) as mv_count  
FROM claims.mv_balance_amount_summary;
```

### 4. **UPDATE FUNCTIONS CAREFULLY**

**Priority 3**: Before switching functions to use MVs:
1. **Test each tab individually**
2. **Compare outputs side-by-side**
3. **Validate business logic matches**
4. **Update functions one at a time**

## Conclusion

**❌ CRITICAL ISSUE**: The current MV implementation may **NOT** return the same data as traditional views for **most report tabs**.

**Root Cause**: MVs are **consolidated** while traditional views are **tab-specific** with different business logic.

**Risk**: Switching functions to use MVs could result in **incorrect data** being displayed in UI tabs.

**Recommendation**: **DO NOT** switch functions to use MVs until:
1. Missing MVs are created
2. Data consistency is validated
3. Tab-specific business logic is preserved

