# FUNCTIONS ANALYSIS REPORT - TRADITIONAL VIEWS vs MVs

## Overview
This report analyzes all functions in the reports_sql folder to determine their current usage of traditional views (v_*) vs materialized views (mv_*) and provides a strategy for implementing Option 3 (hybrid approach with DB toggle).

## Current Function Analysis

### 1. **BALANCE AMOUNT REPORT**

#### **Functions**:
- `get_balance_amount_to_be_received()`

#### **Current Usage**:
- **✅ Uses Traditional Views**: `v_balance_amount_to_be_received_base`
- **❌ Does NOT use MVs**: No MV usage found

#### **Tab Structure**:
- **Tab A**: `v_balance_amount_to_be_received` (Overall balances)
- **Tab B**: `v_initial_not_remitted_balance` (Initial not remitted)
- **Tab C**: `v_after_resubmission_not_remitted_balance` (After resubmission)

#### **MV Equivalent**:
- **❌ MISSING**: No tab-specific MVs exist
- **⚠️ ISSUE**: `mv_balance_amount_summary` is consolidated (not tab-specific)

### 2. **CLAIM DETAILS REPORT**

#### **Functions**:
- `get_claim_details_with_activity()`
- `get_claim_details_summary()`
- `get_claim_details_filter_options()`

#### **Current Usage**:
- **✅ Uses Traditional Views**: `v_claim_details_with_activity`
- **✅ Uses MVs**: `mv_claim_details_complete` (in some functions)

#### **Tab Structure**:
- **Single View**: `v_claim_details_with_activity` (Comprehensive view)

#### **MV Equivalent**:
- **✅ EXISTS**: `mv_claim_details_complete` (matches traditional view)

### 3. **CLAIM SUMMARY REPORT**

#### **Functions**:
- `get_claim_summary_monthwise_params()`
- `get_claim_summary_report_params()`

#### **Current Usage**:
- **✅ Uses Traditional Views**: `v_claim_summary_monthwise`, `v_claim_summary_payerwise`, `v_claim_summary_encounterwise`
- **✅ Uses MVs**: `mv_claim_summary_payerwise`, `mv_claim_summary_encounterwise` (in some functions)

#### **Tab Structure**:
- **Tab A**: `v_claim_summary_monthwise` (Monthwise)
- **Tab B**: `v_claim_summary_payerwise` (Payerwise)
- **Tab C**: `v_claim_summary_encounterwise` (Encounterwise)

#### **MV Equivalent**:
- **❌ MISSING**: No MV for `v_claim_summary_monthwise` (Tab A)
- **✅ EXISTS**: `mv_claim_summary_payerwise` (Tab B)
- **✅ EXISTS**: `mv_claim_summary_encounterwise` (Tab C)

### 4. **DOCTOR DENIAL REPORT**

#### **Functions**:
- `get_doctor_denial_report()`
- `get_doctor_denial_summary()`

#### **Current Usage**:
- **✅ Uses Traditional Views**: `v_doctor_denial_high_denial`, `v_doctor_denial_summary`, `v_doctor_denial_detail`
- **✅ Uses MVs**: `mv_doctor_denial_summary` (in some functions)

#### **Tab Structure**:
- **Tab A**: `v_doctor_denial_high_denial` (High denial doctors)
- **Tab B**: `v_doctor_denial_summary` (Summary)
- **Tab C**: `v_doctor_denial_detail` (Detail)

#### **MV Equivalent**:
- **❌ MISSING**: No MV for `v_doctor_denial_high_denial` (Tab A)
- **❌ MISSING**: No MV for `v_doctor_denial_detail` (Tab C)
- **✅ EXISTS**: `mv_doctor_denial_summary` (Tab B - but consolidated)

### 5. **REJECTED CLAIMS REPORT**

#### **Functions**:
- `get_rejected_claims_summary()`
- `get_rejected_claims_receiver_payer()`
- `get_rejected_claims_claim_wise()`

#### **Current Usage**:
- **✅ Uses Traditional Views**: `v_rejected_claims_base` (for filtering)
- **✅ Uses MVs**: `mv_rejected_claims_summary` (in some functions)

#### **Tab Structure**:
- **Tab A**: `v_rejected_claims_summary_by_year` (By year)
- **Tab B**: `v_rejected_claims_summary` (Summary)
- **Tab C**: `v_rejected_claims_receiver_payer` (Receiver/Payer)
- **Tab D**: `v_rejected_claims_claim_wise` (Claim-wise)

#### **MV Equivalent**:
- **❌ MISSING**: No tab-specific MVs exist
- **⚠️ ISSUE**: `mv_rejected_claims_summary` is consolidated (not tab-specific)

### 6. **REMITTANCE ADVICE REPORT**

#### **Functions**:
- `get_remittance_advice_report_params()`

#### **Current Usage**:
- **✅ Uses Traditional Views**: `v_remittance_advice_header`, `v_remittance_advice_claim_wise`, `v_remittance_advice_activity_wise`
- **✅ Uses MVs**: `mv_remittance_advice_summary` (in some functions)

#### **Tab Structure**:
- **Tab A**: `v_remittance_advice_header` (Header summary)
- **Tab B**: `v_remittance_advice_claim_wise` (Claim-wise details)
- **Tab C**: `v_remittance_advice_activity_wise` (Activity-wise details)

#### **MV Equivalent**:
- **❌ MISSING**: No tab-specific MVs exist
- **⚠️ ISSUE**: `mv_remittance_advice_summary` is consolidated (not tab-specific)

### 7. **RESUBMISSION REPORT**

#### **Functions**:
- `get_remittances_resubmission_activity_level()`
- `get_remittances_resubmission_claim_level()`

#### **Current Usage**:
- **✅ Uses Traditional Views**: `v_remittances_resubmission_activity_level`, `v_remittances_resubmission_claim_level`
- **✅ Uses MVs**: `mv_remittances_resubmission_activity_level` (in some functions)

#### **Tab Structure**:
- **Tab A**: `v_remittances_resubmission_activity_level` (Activity level)
- **Tab B**: `v_remittances_resubmission_claim_level` (Claim level)

#### **MV Equivalent**:
- **✅ EXISTS**: `mv_remittances_resubmission_activity_level` (Tab A)
- **❌ MISSING**: No MV for `v_remittances_resubmission_claim_level` (Tab B)

## Critical Issues Identified

### 🚨 **MAJOR PROBLEM: Tab-Specific MVs Missing**

**Issue**: Most reports have **multiple tabs** with **different business logic**, but MVs are **consolidated into single views**.

**Examples**:
1. **Balance Amount**: 3 tabs → 1 consolidated MV
2. **Remittance Advice**: 3 tabs → 1 consolidated MV
3. **Doctor Denial**: 3 tabs → 1 consolidated MV
4. **Rejected Claims**: 4 tabs → 1 consolidated MV
5. **Claim Summary**: 3 tabs → 2 MVs (missing Tab A)

### 🚨 **FUNCTION INCONSISTENCY**

**Issue**: Functions are **inconsistent** in their usage:
- Some use **traditional views only**
- Some use **MVs only**
- Some use **both** (hybrid approach already exists)

## Required MV Creation Strategy

### **Phase 1: Create Missing Tab-Specific MVs**

#### **1. Balance Amount Report**:
```sql
-- Create tab-specific MVs
CREATE MATERIALIZED VIEW claims.mv_balance_amount_overall AS
SELECT * FROM claims.v_balance_amount_to_be_received;

CREATE MATERIALIZED VIEW claims.mv_balance_amount_initial AS
SELECT * FROM claims.v_initial_not_remitted_balance;

CREATE MATERIALIZED VIEW claims.mv_balance_amount_resubmission AS
SELECT * FROM claims.v_after_resubmission_not_remitted_balance;
```

#### **2. Remittance Advice Report**:
```sql
-- Create tab-specific MVs
CREATE MATERIALIZED VIEW claims.mv_remittance_advice_header AS
SELECT * FROM claims.v_remittance_advice_header;

CREATE MATERIALIZED VIEW claims.mv_remittance_advice_claim_wise AS
SELECT * FROM claims.v_remittance_advice_claim_wise;

CREATE MATERIALIZED VIEW claims.mv_remittance_advice_activity_wise AS
SELECT * FROM claims.v_remittance_advice_activity_wise;
```

#### **3. Doctor Denial Report**:
```sql
-- Create tab-specific MVs
CREATE MATERIALIZED VIEW claims.mv_doctor_denial_high_denial AS
SELECT * FROM claims.v_doctor_denial_high_denial;

CREATE MATERIALIZED VIEW claims.mv_doctor_denial_detail AS
SELECT * FROM claims.v_doctor_denial_detail;
```

#### **4. Rejected Claims Report**:
```sql
-- Create tab-specific MVs
CREATE MATERIALIZED VIEW claims.mv_rejected_claims_by_year AS
SELECT * FROM claims.v_rejected_claims_summary_by_year;

CREATE MATERIALIZED VIEW claims.mv_rejected_claims_summary AS
SELECT * FROM claims.v_rejected_claims_summary;

CREATE MATERIALIZED VIEW claims.mv_rejected_claims_receiver_payer AS
SELECT * FROM claims.v_rejected_claims_receiver_payer;

CREATE MATERIALIZED VIEW claims.mv_rejected_claims_claim_wise AS
SELECT * FROM claims.v_rejected_claims_claim_wise;
```

#### **5. Claim Summary Report**:
```sql
-- Create missing MV
CREATE MATERIALIZED VIEW claims.mv_claim_summary_monthwise AS
SELECT * FROM claims.v_claim_summary_monthwise;
```

#### **6. Resubmission Report**:
```sql
-- Create missing MV
CREATE MATERIALIZED VIEW claims.mv_remittances_resubmission_claim_level AS
SELECT * FROM claims.v_remittances_resubmission_claim_level;
```

### **Phase 2: Implement Option 3 (Hybrid Approach)**

#### **Function Template**:
```sql
CREATE OR REPLACE FUNCTION claims.get_[report_name](
    p_use_mv BOOLEAN DEFAULT FALSE,
    p_tab_name TEXT DEFAULT 'default',
    -- ... other parameters
) RETURNS TABLE(...) AS $$
BEGIN
    IF p_use_mv THEN
        CASE p_tab_name
            WHEN 'tab_a' THEN
                RETURN QUERY SELECT * FROM claims.mv_[report_name]_tab_a WHERE ...;
            WHEN 'tab_b' THEN
                RETURN QUERY SELECT * FROM claims.mv_[report_name]_tab_b WHERE ...;
            WHEN 'tab_c' THEN
                RETURN QUERY SELECT * FROM claims.mv_[report_name]_tab_c WHERE ...;
            ELSE
                RETURN QUERY SELECT * FROM claims.mv_[report_name]_default WHERE ...;
        END CASE;
    ELSE
        CASE p_tab_name
            WHEN 'tab_a' THEN
                RETURN QUERY SELECT * FROM claims.v_[report_name]_tab_a WHERE ...;
            WHEN 'tab_b' THEN
                RETURN QUERY SELECT * FROM claims.v_[report_name]_tab_b WHERE ...;
            WHEN 'tab_c' THEN
                RETURN QUERY SELECT * FROM claims.v_[report_name]_tab_c WHERE ...;
            ELSE
                RETURN QUERY SELECT * FROM claims.v_[report_name]_default WHERE ...;
        END CASE;
    END IF;
END;
$$;
```

## Implementation Plan

### **Step 1: Create Missing MVs (2-3 hours)**
1. Create 15+ tab-specific MVs
2. Ensure they match traditional views exactly
3. Add proper indexes for performance

### **Step 2: Update Functions (1-2 hours)**
1. Add `p_use_mv BOOLEAN DEFAULT FALSE` parameter
2. Add `p_tab_name TEXT DEFAULT 'default'` parameter
3. Implement CASE statements for tab selection
4. Maintain backward compatibility

### **Step 3: Java Layer Integration (1 hour)**
1. Add DB toggle configuration
2. Update function calls to pass `p_use_mv` parameter
3. Add tab name parameter to function calls

### **Step 4: Testing & Validation (1 hour)**
1. Test all functions with both traditional views and MVs
2. Validate data consistency
3. Performance testing

## Current Function Status Summary

### **✅ FUNCTIONS USING TRADITIONAL VIEWS**:
- `get_balance_amount_to_be_received()` - Uses `v_balance_amount_to_be_received_base`
- `get_claim_details_with_activity()` - Uses `v_claim_details_with_activity`
- `get_claim_summary_monthwise_params()` - Uses `v_claim_summary_*`
- `get_doctor_denial_report()` - Uses `v_doctor_denial_*`
- `get_rejected_claims_*()` - Uses `v_rejected_claims_base`
- `get_remittance_advice_report_params()` - Uses `v_remittance_advice_*`
- `get_remittances_resubmission_*()` - Uses `v_remittances_resubmission_*`

### **✅ FUNCTIONS USING MVs**:
- Some functions in `claim_details_with_activity_final.sql` - Use `mv_claim_details_complete`
- Some functions in `claim_summary_monthwise_report_final.sql` - Use `mv_claim_summary_*`
- Some functions in `doctor_denial_report_final.sql` - Use `mv_doctor_denial_summary`
- Some functions in `rejected_claims_report_final.sql` - Use `mv_rejected_claims_summary`
- Some functions in `remittances_resubmission_report_final.sql` - Use `mv_remittances_resubmission_activity_level`

### **⚠️ INCONSISTENT USAGE**:
- Functions are **mixed** - some use traditional views, some use MVs
- **No standardization** across reports
- **Tab-specific logic** not preserved in MVs

## Recommendations

### **✅ IMMEDIATE ACTION REQUIRED**

1. **Create Missing MVs**: 15+ tab-specific MVs needed
2. **Standardize Functions**: All functions should support both traditional views and MVs
3. **Implement Option 3**: Add DB toggle with tab selection
4. **Maintain Compatibility**: Ensure backward compatibility

### **🎯 SUCCESS CRITERIA**

1. **All functions** support both traditional views and MVs
2. **All tabs** have corresponding MVs
3. **Data consistency** between traditional views and MVs
4. **Performance improvement** with MVs (sub-second response)
5. **Flexibility** to switch between traditional views and MVs

### **🚀 READY FOR IMPLEMENTATION**

**Phase 1**: Create missing MVs (2-3 hours)
**Phase 2**: Update functions with Option 3 (1-2 hours)
**Phase 3**: Java layer integration (1 hour)
**Phase 4**: Testing & validation (1 hour)

**Total Time**: 5-7 hours for complete implementation

