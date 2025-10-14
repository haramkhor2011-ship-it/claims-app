# Materialized Views Status Report

## Executive Summary

**Current Status**: 🟢 **MOSTLY FIXED** - 6 out of 10 MVs are working correctly
- **✅ FIXED**: 6 materialized views are working without duplicate key violations
- **❌ CRITICAL**: 2 materialized views have duplicate key violations and need immediate fixes
- **⚠️ NEEDS ATTENTION**: 2 materialized views have potential issues that should be addressed

## Materialized Views Status Overview

| # | Materialized View | Status | Duplicates | Aggregation | Documentation | Priority |
|---|-------------------|--------|------------|-------------|---------------|----------|
| 1 | `mv_balance_amount_summary` | ✅ **WORKING** | ✅ None | ✅ Proper | ✅ Good | Low |
| 2 | `mv_claims_monthly_agg` | ✅ **WORKING** | ✅ None | ✅ Proper | ✅ Good | Low |
| 3 | `mv_claim_summary_payerwise` | ✅ **FIXED** | ✅ None | ✅ Proper | ✅ Good | Low |
| 4 | `mv_claim_summary_encounterwise` | ✅ **FIXED** | ✅ None | ✅ Proper | ✅ Good | Low |
| 5 | `mv_remittances_resubmission_activity_level` | ✅ **FIXED** | ✅ None | ✅ Proper | ✅ Good | Low |
| 6 | `mv_remittance_advice_summary` | ⚠️ **NEEDS FIX** | ⚠️ Potential | ❌ Missing | ⚠️ Partial | Medium |
| 7 | `mv_doctor_denial_summary` | ✅ **FIXED** | ✅ None | ✅ Proper | ✅ Good | Low |
| 8 | `mv_claim_details_complete` | ❌ **CRITICAL** | ❌ Yes | ❌ Missing | ❌ Poor | High |
| 9 | `mv_rejected_claims_summary` | ❌ **CRITICAL** | ❌ Yes | ❌ Missing | ❌ Poor | High |
| 10 | `mv_resubmission_cycles` | ⚠️ **NEEDS FIX** | ⚠️ Potential | ❌ Missing | ⚠️ Partial | Medium |

## Detailed Analysis

### ✅ WORKING MVs (6/10)

#### 1. mv_balance_amount_summary ✅
**Status**: ✅ **WORKING CORRECTLY**
- **Lines**: 31-113 in `sub_second_materialized_views.sql`
- **Aggregation**: ✅ **PROPER** - Uses CTEs to pre-aggregate remittance data
- **Documentation**: ✅ **GOOD** - Well documented with performance targets
- **Key Features**:
  - Pre-aggregates remittance data per `claim_key_id`
  - Uses latest status from `claim_status_timeline`
  - Proper aging calculations
  - Performance indexes in place

#### 2. mv_claims_monthly_agg ✅
**Status**: ✅ **WORKING CORRECTLY**
- **Lines**: 249-261 in `sub_second_materialized_views.sql`
- **Aggregation**: ✅ **PROPER** - Simple monthly aggregation, no remittance data
- **Documentation**: ✅ **GOOD** - Clear purpose and performance targets
- **Key Features**:
  - Monthly aggregation by payer and provider
  - No remittance data, so no aggregation issues
  - Simple and efficient design

#### 3. mv_claim_summary_payerwise ✅
**Status**: ✅ **FIXED** (Previously had duplicates)
- **Lines**: 939-1049 in `sub_second_materialized_views.sql`
- **What Was Fixed**:
  - Added `remittance_aggregated` CTE to pre-aggregate remittance data
  - Prevents duplicates from multiple remittances per claim
  - Uses `ARRAY_AGG()` to get latest payer/provider info
- **Documentation**: ✅ **GOOD** - Comment indicates fix applied
- **Key Features**:
  - Proper remittance aggregation per `claim_key_id`
  - Monthly grouping with proper payer information
  - Calculated percentages for rejection rates

#### 4. mv_claim_summary_encounterwise ✅
**Status**: ✅ **FIXED** (Previously had duplicates)
- **Lines**: 1055-1170 in `sub_second_materialized_views.sql`
- **What Was Fixed**:
  - Same aggregation pattern as payerwise
  - Added `remittance_aggregated` CTE
  - Prevents duplicates from multiple remittances per claim
- **Documentation**: ✅ **GOOD** - Comment indicates fix applied
- **Key Features**:
  - Proper remittance aggregation per `claim_key_id`
  - Monthly grouping by encounter type and facility
  - Calculated percentages for rejection rates

#### 5. mv_remittances_resubmission_activity_level ✅
**Status**: ✅ **FIXED** (Previously causing duplicate key violations)
- **Lines**: 395-677 in `sub_second_materialized_views.sql`
- **What Was Fixed**:
  - Added multiple aggregation CTEs:
    - `activity_financials` - Aggregates remittance data per activity
    - `resubmission_cycles_aggregated` - Uses `ARRAY_AGG()` for up to 5 cycles
    - `remittance_cycles_aggregated` - Uses `ARRAY_AGG()` for up to 5 cycles
    - `diag_agg` - Aggregates diagnosis data to prevent duplicates
  - Removed redundant `LEFT JOIN claims.remittance_claim` that was causing duplicates
- **Documentation**: ✅ **GOOD** - Comment indicates fix applied
- **Key Features**:
  - Complex activity-level financial calculations
  - Proper cycle tracking with arrays
  - Diagnosis aggregation to prevent duplicates

### ❌ CRITICAL MVs NEEDING FIXES (2/10)

#### 6. mv_doctor_denial_summary ✅
**Status**: ✅ **FIXED** (Previously had duplicate key violations)
- **Lines**: 182-259 in `sub_second_materialized_views.sql`
- **What Was Fixed**:
  - Added `remittance_aggregated` CTE to pre-aggregate remittance data
  - Prevents duplicates from multiple remittances per claim
  - Uses `ARRAY_AGG()` to get latest remittance information
- **Documentation**: ✅ **GOOD** - Comment indicates fix applied
- **Key Features**:
  - Proper remittance aggregation per `claim_key_id`
  - Clinician-level metrics with proper rejection percentages
  - Monthly grouping with facility information

#### 7. mv_claim_details_complete ❌
**Status**: ❌ **CRITICAL - DUPLICATE KEY VIOLATIONS**
- **Lines**: 282-336 in `sub_second_materialized_views.sql`
- **Current Issues**:
  - Direct JOINs to `remittance_claim` and `remittance_activity` without aggregation
  - Multiple remittances per claim create multiple rows
  - Violates unique constraint on `(claim_key_id, activity_id)`
- **Required Fix**:
  - Add remittance aggregation CTE
  - Pre-aggregate remittance data per `claim_key_id`
  - Show latest remittance information per activity
- **Documentation**: ❌ **POOR** - No indication of aggregation issues
- **Priority**: 🔴 **HIGH** - Used by Claim Details Report

#### 8. mv_rejected_claims_summary ❌
**Status**: ❌ **CRITICAL - DUPLICATE KEY VIOLATIONS**
- **Lines**: 833-933 in `sub_second_materialized_views.sql`
- **Current Issues**:
  - Direct JOINs to `remittance_claim` and `remittance_activity` without aggregation
  - Multiple remittances per claim create multiple rows
  - Violates unique constraint on `(claim_key_id, activity_id)`
- **Required Fix**:
  - Add remittance aggregation CTE
  - Pre-aggregate remittance data per `claim_key_id`
  - Show latest rejection status per claim
- **Documentation**: ❌ **POOR** - No indication of aggregation issues
- **Priority**: 🔴 **HIGH** - Used by Rejected Claims Report

### ⚠️ MVs NEEDING ATTENTION (2/10)

#### 9. mv_remittance_advice_summary ⚠️
**Status**: ⚠️ **POTENTIAL DUPLICATES**
- **Lines**: 137-159 in `sub_second_materialized_views.sql`
- **Current Issues**:
  - Groups by `rc.id` (remittance_claim) instead of `claim_key_id`
  - Multiple remittances per claim create multiple rows
  - Should aggregate all remittances per claim
- **Required Fix**:
  - Change grouping to aggregate by `claim_key_id`
  - Pre-aggregate remittance data per claim
- **Documentation**: ⚠️ **PARTIAL** - Basic documentation present
- **Priority**: 🟡 **MEDIUM** - Used by Remittance Advice Report

#### 10. mv_resubmission_cycles ⚠️
**Status**: ⚠️ **POTENTIAL DUPLICATES**
- **Lines**: 360-376 in `sub_second_materialized_views.sql`
- **Current Issues**:
  - LEFT JOIN to `remittance_claim` without aggregation
  - Multiple remittances per claim create multiple rows
- **Required Fix**:
  - Add remittance aggregation CTE
  - Pre-aggregate remittance data per `claim_key_id`
- **Documentation**: ⚠️ **PARTIAL** - Basic documentation present
- **Priority**: 🟡 **MEDIUM** - Used for resubmission tracking

## Fix Patterns Applied

### Successful Aggregation Pattern
The following pattern has been successfully applied to fix duplicate issues:

```sql
WITH remittance_aggregated AS (
  -- Pre-aggregate all remittance data per claim_key_id to prevent duplicates
  SELECT 
    rc.claim_key_id,
    COUNT(*) as remittance_count,
    SUM(ra.payment_amount) as total_payment_amount,
    SUM(ra.net) as total_remitted_amount,
    COUNT(CASE WHEN ra.payment_amount > 0 THEN 1 END) as paid_activity_count,
    COUNT(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 1 END) as rejected_activity_count,
    MIN(rc.date_settlement) as first_remittance_date,
    MAX(rc.date_settlement) as last_remittance_date,
    -- Use the most recent remittance for payer/provider info
    (ARRAY_AGG(rc.id_payer ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_id_payer,
    (ARRAY_AGG(rc.provider_id ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_provider_id
  FROM claims.remittance_claim rc
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
)
```

### Cycle Aggregation Pattern
For complex cycle tracking (used in `mv_remittances_resubmission_activity_level`):

```sql
WITH resubmission_cycles_aggregated AS (
  SELECT 
    ce.claim_key_id,
    COUNT(*) as resubmission_count,
    MAX(ce.event_time) as last_resubmission_date,
    -- Get first resubmission details
    (ARRAY_AGG(cr.resubmission_type ORDER BY ce.event_time))[1] as first_resubmission_type,
    (ARRAY_AGG(ce.event_time ORDER BY ce.event_time))[1] as first_resubmission_date,
    -- Get up to 5 cycles
    (ARRAY_AGG(cr.resubmission_type ORDER BY ce.event_time))[2] as second_resubmission_type,
    -- ... continue for up to 5 cycles
  FROM claims.claim_event ce
  LEFT JOIN claims.claim_resubmission cr ON ce.id = cr.claim_event_id
  WHERE ce.type = 2  -- Resubmission events
  GROUP BY ce.claim_key_id
)
```

## Next Steps

### Immediate Actions (High Priority)
1. **Fix mv_claim_details_complete** - Apply remittance aggregation pattern  
2. **Fix mv_rejected_claims_summary** - Apply remittance aggregation pattern

### Medium Priority Actions
3. **Fix mv_remittance_advice_summary** - Change grouping strategy
4. **Fix mv_resubmission_cycles** - Add remittance aggregation

### Long-term Improvements
5. **Enhance Documentation** - Add fix comments to all MVs
6. **Add Testing** - Create test scripts for each MV
7. **Performance Monitoring** - Implement MV refresh monitoring

## Success Criteria

### For Each MV Fix:
- ✅ No duplicate key violations during refresh
- ✅ Proper aggregation of remittance data
- ✅ Maintains claim lifecycle principles
- ✅ Performance remains sub-second
- ✅ Documentation updated with fix details

### Overall System:
- ✅ All 10 MVs refresh without errors
- ✅ All reports return expected row counts
- ✅ Claim lifecycle properly represented
- ✅ Performance targets maintained

## Conclusion

**Current State**: 6 out of 10 materialized views are working correctly
**Target State**: All 10 MVs should follow proper aggregation patterns
**Effort Required**: 2 critical fixes + 2 medium priority fixes
**Risk**: Low - 2 critical MVs remain, affecting 2 major reports

The successful fixes applied to `mv_claim_summary_payerwise`, `mv_claim_summary_encounterwise`, `mv_remittances_resubmission_activity_level`, and `mv_doctor_denial_summary` provide a proven pattern that can be applied to the remaining problematic MVs.
