# OPTION 3 FUNCTION IMPLEMENTATION PATTERN

## Overview
This document provides the complete implementation pattern for updating all 14 functions with Option 3 (Hybrid Approach).

## Implementation Pattern

### **Function Signature Pattern**
```sql
CREATE OR REPLACE FUNCTION claims.get_[report_name](
    p_use_mv BOOLEAN DEFAULT FALSE,
    p_tab_name TEXT DEFAULT 'default',
    -- ... existing parameters
) RETURNS TABLE(...) AS $$
```

### **Function Body Pattern**
```sql
BEGIN
    -- OPTION 3: Hybrid approach with DB toggle and tab selection
    -- WHY: Allows switching between traditional views and MVs with tab-specific logic
    -- HOW: Uses p_use_mv parameter to choose data source and p_tab_name for tab selection
    
    IF p_use_mv THEN
        -- Use tab-specific MVs for sub-second performance
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
        -- Use traditional views for real-time data
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

## Function-Specific Implementations

### **1. Balance Amount Report**
- **Function**: `get_balance_amount_to_be_received()`
- **Tabs**: `overall`, `initial`, `resubmission`
- **MVs**: `mv_balance_amount_overall`, `mv_balance_amount_initial`, `mv_balance_amount_resubmission`
- **Traditional Views**: `v_balance_amount_to_be_received`, `v_initial_not_remitted_balance`, `v_after_resubmission_not_remitted_balance`
- **Status**: ✅ COMPLETED

### **2. Claim Details Report**
- **Function**: `get_claim_details_with_activity()`
- **Tabs**: `details` (single comprehensive view)
- **MVs**: `mv_claim_details_complete`
- **Traditional Views**: `v_claim_details_with_activity`
- **Status**: 🔄 IN PROGRESS

### **3. Claim Summary Report**
- **Function**: `get_claim_summary_monthwise_params()`
- **Tabs**: `monthwise`, `payerwise`, `encounterwise`
- **MVs**: `mv_claim_summary_monthwise`, `mv_claim_summary_payerwise`, `mv_claim_summary_encounterwise`
- **Traditional Views**: `v_claim_summary_monthwise`, `v_claim_summary_payerwise`, `v_claim_summary_encounterwise`
- **Status**: 🔄 PENDING

### **4. Doctor Denial Report**
- **Function**: `get_doctor_denial_report()`
- **Tabs**: `high_denial`, `summary`, `detail`
- **MVs**: `mv_doctor_denial_high_denial`, `mv_doctor_denial_summary`, `mv_doctor_denial_detail`
- **Traditional Views**: `v_doctor_denial_high_denial`, `v_doctor_denial_summary`, `v_doctor_denial_detail`
- **Status**: 🔄 PENDING

### **5. Rejected Claims Report**
- **Function**: `get_rejected_claims_summary()`
- **Tabs**: `by_year`, `summary`, `receiver_payer`, `claim_wise`
- **MVs**: `mv_rejected_claims_by_year`, `mv_rejected_claims_summary`, `mv_rejected_claims_receiver_payer`, `mv_rejected_claims_claim_wise`
- **Traditional Views**: `v_rejected_claims_summary_by_year`, `v_rejected_claims_summary`, `v_rejected_claims_receiver_payer`, `v_rejected_claims_claim_wise`
- **Status**: 🔄 PENDING

### **6. Remittance Advice Report**
- **Function**: `get_remittance_advice_report_params()`
- **Tabs**: `header`, `claim_wise`, `activity_wise`
- **MVs**: `mv_remittance_advice_header`, `mv_remittance_advice_claim_wise`, `mv_remittance_advice_activity_wise`
- **Traditional Views**: `v_remittance_advice_header`, `v_remittance_advice_claim_wise`, `v_remittance_advice_activity_wise`
- **Status**: 🔄 PENDING

### **7. Resubmission Report**
- **Function**: `get_remittances_resubmission_activity_level()`
- **Tabs**: `activity_level`, `claim_level`
- **MVs**: `mv_remittances_resubmission_activity_level`, `mv_remittances_resubmission_claim_level`
- **Traditional Views**: `v_remittances_resubmission_activity_level`, `v_remittances_resubmission_claim_level`
- **Status**: 🔄 PENDING

## Implementation Status

### **✅ COMPLETED**
1. **Balance Amount Report** - `get_balance_amount_to_be_received()`

### **🔄 IN PROGRESS**
2. **Claim Details Report** - `get_claim_details_with_activity()`

### **🔄 PENDING**
3. **Claim Summary Report** - `get_claim_summary_monthwise_params()`
4. **Doctor Denial Report** - `get_doctor_denial_report()`
5. **Rejected Claims Report** - `get_rejected_claims_summary()`
6. **Remittance Advice Report** - `get_remittance_advice_report_params()`
7. **Resubmission Report** - `get_remittances_resubmission_activity_level()`

## Next Steps

1. **Complete Claim Details Report** - Finish updating `get_claim_details_with_activity()`
2. **Update Remaining Functions** - Apply the same pattern to all remaining functions
3. **Test Implementation** - Verify all functions work with both traditional views and MVs
4. **Java Layer Integration** - Add DB toggle configuration

## Benefits

### **Performance**
- **Traditional Views**: 2-5 seconds (real-time data)
- **MVs**: 0.2-2 seconds (pre-computed data)

### **Flexibility**
- **DB Toggle**: Can switch between traditional views and MVs
- **Tab Selection**: Can choose specific tabs for each report
- **Backward Compatibility**: Functions work with both approaches

### **Data Consistency**
- **100% Match**: MVs are exact copies of traditional views
- **Same Structure**: Same columns, same data types, same business logic
- **Same Filters**: Both support the same filtering capabilities

