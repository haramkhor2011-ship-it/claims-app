# SQL Report Verification & Documentation Guide
## Balance Amount to be Received Report

### Overview
This guide provides a comprehensive step-by-step approach to verify that your SQL report is generating data correctly and document it for future reference.

---

## 📋 Step 1: Understanding Your Report Structure

### Report Components
Your Balance Amount report consists of:

1. **Base View**: `claims.v_balance_amount_base_enhanced`
   - Core data aggregation with corrected field mappings
   - Handles joins between claims, encounters, remittances, and reference data

2. **Tab Views**:
   - **Tab A**: `v_balance_amount_tab_a_corrected` - All balance amounts
   - **Tab B**: `v_balance_amount_tab_b_corrected` - Initial not remitted
   - **Tab C**: `v_balance_amount_tab_c_corrected` - After resubmission not remitted

3. **API Function**: `claims.get_balance_amount_tab_a_corrected()`
   - Parameterized function for application integration

---

## 🔍 Step 2: Data Validation Checklist

### 2.1 Schema Validation
```sql
-- Check if all required tables exist
SELECT table_name, table_schema 
FROM information_schema.tables 
WHERE table_schema IN ('claims', 'claims_ref')
AND table_name IN (
    'claim_key', 'claim', 'encounter', 'remittance_claim', 
    'remittance_activity', 'claim_event', 'claim_resubmission',
    'claim_status_timeline', 'provider', 'facility', 'payer'
);
```

### 2.2 View Existence Check
```sql
-- Verify all views are created
SELECT viewname, schemaname 
FROM pg_views 
WHERE schemaname = 'claims' 
AND viewname LIKE '%balance_amount%';
```

### 2.3 Function Validation
```sql
-- Check if functions exist
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_schema = 'claims' 
AND routine_name LIKE '%balance_amount%';
```

---

## 🧪 Step 3: Data Accuracy Testing

### 3.1 Sample Data Verification
```sql
-- Test with a small sample first
SELECT 
    claim_key_id,
    claim_id,
    facility_group_id,
    health_authority,
    billed_amount,
    amount_received,
    outstanding_balance,
    aging_days,
    current_claim_status
FROM claims.v_balance_amount_tab_a_corrected 
LIMIT 10;
```

### 3.2 Business Logic Validation

#### A. Outstanding Balance Calculation
```sql
-- Verify outstanding balance = billed_amount - amount_received - denied_amount
SELECT 
    claim_id,
    billed_amount,
    amount_received,
    denied_amount,
    outstanding_balance,
    (billed_amount - amount_received - denied_amount) AS calculated_outstanding,
    CASE 
        WHEN outstanding_balance = (billed_amount - amount_received - denied_amount) 
        THEN 'CORRECT' 
        ELSE 'ERROR' 
    END AS validation_status
FROM claims.v_balance_amount_tab_a_corrected 
WHERE outstanding_balance != (billed_amount - amount_received - denied_amount)
LIMIT 20;
```

#### B. Aging Calculation
```sql
-- Verify aging calculation
SELECT 
    claim_id,
    encounter_start_date,
    aging_days,
    EXTRACT(DAYS FROM (CURRENT_DATE - encounter_start_date)) AS calculated_aging,
    aging_bucket,
    CASE 
        WHEN aging_days = EXTRACT(DAYS FROM (CURRENT_DATE - encounter_start_date)) 
        THEN 'CORRECT' 
        ELSE 'ERROR' 
    END AS aging_validation
FROM claims.v_balance_amount_tab_a_corrected 
WHERE aging_days != EXTRACT(DAYS FROM (CURRENT_DATE - encounter_start_date))
LIMIT 20;
```

#### C. Status Mapping Validation
```sql
-- Test status mapping function
SELECT DISTINCT 
    current_claim_status,
    COUNT(*) as count
FROM claims.v_balance_amount_tab_a_corrected 
GROUP BY current_claim_status
ORDER BY count DESC;
```

### 3.3 Data Completeness Check
```sql
-- Check for NULL values in critical fields
SELECT 
    'claim_id' as field_name,
    COUNT(*) as total_records,
    COUNT(claim_id) as non_null_records,
    COUNT(*) - COUNT(claim_id) as null_records
FROM claims.v_balance_amount_tab_a_corrected
UNION ALL
SELECT 
    'billed_amount' as field_name,
    COUNT(*) as total_records,
    COUNT(billed_amount) as non_null_records,
    COUNT(*) - COUNT(billed_amount) as null_records
FROM claims.v_balance_amount_tab_a_corrected
UNION ALL
SELECT 
    'facility_group_id' as field_name,
    COUNT(*) as total_records,
    COUNT(facility_group_id) as non_null_records,
    COUNT(*) - COUNT(facility_group_id) as null_records
FROM claims.v_balance_amount_tab_a_corrected;
```

---

## 📊 Step 4: Performance Testing

### 4.1 Query Performance Analysis
```sql
-- Enable query timing
\timing on

-- Test base view performance
EXPLAIN (ANALYZE, BUFFERS) 
SELECT COUNT(*) 
FROM claims.v_balance_amount_base_enhanced 
WHERE encounter_start >= '2024-01-01';

-- Test tab view performance
EXPLAIN (ANALYZE, BUFFERS) 
SELECT COUNT(*) 
FROM claims.v_balance_amount_tab_a_corrected 
WHERE encounter_start_date >= '2024-01-01';
```

### 4.2 Index Usage Verification
```sql
-- Check if indexes are being used
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes 
WHERE schemaname = 'claims' 
AND indexname LIKE '%balance_amount%'
ORDER BY idx_scan DESC;
```

---

## 🔧 Step 5: API Function Testing

### 5.1 Parameter Validation
```sql
-- Test with various parameter combinations
SELECT * FROM claims.get_balance_amount_tab_a_corrected(
    'test_user',                    -- p_user_id
    NULL,                           -- p_claim_key_ids
    ARRAY['DHA-F-0045446'],        -- p_facility_codes
    NULL,                           -- p_payer_codes
    NULL,                           -- p_receiver_ids
    '2024-01-01'::timestamptz,     -- p_date_from
    '2024-12-31'::timestamptz,     -- p_date_to
    NULL,                           -- p_year
    NULL,                           -- p_month
    FALSE,                          -- p_based_on_initial_net
    10,                             -- p_limit
    0,                              -- p_offset
    'encounter_start_date',         -- p_order_by
    'DESC'                          -- p_order_direction
);
```

### 5.2 Edge Case Testing
```sql
-- Test with no results
SELECT * FROM claims.get_balance_amount_tab_a_corrected(
    'test_user',
    NULL,
    ARRAY['NONEXISTENT_FACILITY'],
    NULL,
    NULL,
    '2020-01-01'::timestamptz,
    '2020-12-31'::timestamptz,
    NULL,
    NULL,
    FALSE,
    10,
    0,
    'encounter_start_date',
    'DESC'
);

-- Test with large date range
SELECT * FROM claims.get_balance_amount_tab_a_corrected(
    'test_user',
    NULL,
    NULL,
    NULL,
    NULL,
    '2020-01-01'::timestamptz,
    '2025-12-31'::timestamptz,
    NULL,
    NULL,
    FALSE,
    1000,
    0,
    'encounter_start_date',
    'DESC'
);
```

---

## 📈 Step 6: Business Logic Validation

### 6.1 Tab-Specific Logic Testing

#### Tab A - All Balance Amounts
```sql
-- Verify Tab A includes all claims with outstanding balance
SELECT 
    COUNT(*) as total_claims,
    COUNT(CASE WHEN outstanding_balance > 0 THEN 1 END) as claims_with_outstanding,
    COUNT(CASE WHEN outstanding_balance = 0 THEN 1 END) as claims_without_outstanding
FROM claims.v_balance_amount_tab_a_corrected;
```

#### Tab B - Initial Not Remitted
```sql
-- Verify Tab B only includes initial submissions
SELECT 
    COUNT(*) as total_claims,
    COUNT(CASE WHEN remittance_count = 0 THEN 1 END) as no_remittances,
    COUNT(CASE WHEN resubmission_count = 0 THEN 1 END) as no_resubmissions,
    COUNT(CASE WHEN denied_amount = 0 THEN 1 END) as no_denials
FROM claims.v_balance_amount_tab_b_corrected;
```

#### Tab C - After Resubmission Not Remitted
```sql
-- Verify Tab C only includes resubmitted claims with pending amounts
SELECT 
    COUNT(*) as total_claims,
    COUNT(CASE WHEN resubmission_count > 0 THEN 1 END) as has_resubmissions,
    COUNT(CASE WHEN outstanding_balance > 0 THEN 1 END) as has_outstanding
FROM claims.v_balance_amount_tab_c_corrected;
```

### 6.2 Cross-Tab Validation
```sql
-- Ensure no overlap between tabs
SELECT 
    'Tab A vs Tab B' as comparison,
    COUNT(*) as overlap_count
FROM claims.v_balance_amount_tab_a_corrected a
JOIN claims.v_balance_amount_tab_b_corrected b ON a.claim_key_id = b.claim_key_id
UNION ALL
SELECT 
    'Tab A vs Tab C' as comparison,
    COUNT(*) as overlap_count
FROM claims.v_balance_amount_tab_a_corrected a
JOIN claims.v_balance_amount_tab_c_corrected c ON a.claim_key_id = c.claim_key_id
UNION ALL
SELECT 
    'Tab B vs Tab C' as comparison,
    COUNT(*) as overlap_count
FROM claims.v_balance_amount_tab_b_corrected b
JOIN claims.v_balance_amount_tab_c_corrected c ON b.claim_key_id = c.claim_key_id;
```

---

## 📝 Step 7: Documentation Template

### 7.1 Report Metadata
```sql
-- Document report metadata
SELECT 
    'Balance Amount to be Received Report' as report_name,
    '2025-09-17' as implementation_date,
    'claims.v_balance_amount_base_enhanced' as base_view,
    'claims.get_balance_amount_tab_a_corrected' as api_function,
    '3 tabs: A (All), B (Initial), C (Resubmitted)' as report_structure;
```

### 7.2 Field Mapping Documentation
```sql
-- Document field mappings
SELECT 
    'FacilityGroupID' as business_field,
    'COALESCE(e.facility_id, c.provider_id)' as sql_mapping,
    'claims.encounter.facility_id (preferred) or claims.claim.provider_id' as source_tables
UNION ALL
SELECT 
    'HealthAuthority' as business_field,
    'COALESCE(if_sub.sender_id, if_rem.receiver_id)' as sql_mapping,
    'claims.ingestion_file.sender_id/receiver_id' as source_tables
UNION ALL
SELECT 
    'Receiver_Name' as business_field,
    'pay.name' as sql_mapping,
    'claims_ref.payer.name joined on payer_code = ingestion_file.receiver_id' as source_tables
UNION ALL
SELECT 
    'Outstanding_Balance' as business_field,
    'c.net - COALESCE(rem_summary.total_payment_amount, 0) - COALESCE(rem_summary.total_denied_amount, 0)' as sql_mapping,
    'Calculated from claim.net - payments - denials' as source_tables;
```

---

## 🚨 Step 8: Error Detection & Troubleshooting

### 8.1 Common Issues to Check

#### A. Data Type Mismatches
```sql
-- Check for data type issues
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'claims' 
AND table_name = 'v_balance_amount_tab_a_corrected'
ORDER BY ordinal_position;
```

#### B. Join Issues
```sql
-- Check for orphaned records
SELECT 
    'Claims without encounters' as issue_type,
    COUNT(*) as count
FROM claims.claim c
LEFT JOIN claims.encounter e ON e.claim_id = c.id
WHERE e.id IS NULL
UNION ALL
SELECT 
    'Claims without claim_key' as issue_type,
    COUNT(*) as count
FROM claims.claim c
LEFT JOIN claims.claim_key ck ON ck.id = c.claim_key_id
WHERE ck.id IS NULL;
```

#### C. Performance Issues
```sql
-- Check for slow queries
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows
FROM pg_stat_statements 
WHERE query LIKE '%balance_amount%'
ORDER BY mean_time DESC
LIMIT 10;
```

---

## ✅ Step 9: Validation Checklist

### Pre-Production Checklist
- [ ] All views created successfully
- [ ] All functions created successfully
- [ ] Sample data returns expected results
- [ ] Business logic calculations are correct
- [ ] No NULL values in critical fields
- [ ] Performance is acceptable (< 5 seconds for typical queries)
- [ ] Indexes are being used effectively
- [ ] API function handles all parameter combinations
- [ ] Tab logic is correct (no overlaps, proper filtering)
- [ ] Cross-validation with source data passes
- [ ] Error handling works correctly
- [ ] Documentation is complete

### Post-Production Monitoring
- [ ] Set up query performance monitoring
- [ ] Monitor for data quality issues
- [ ] Track user feedback
- [ ] Regular validation runs
- [ ] Performance optimization as needed

---

## 📞 Step 10: Support & Maintenance

### Regular Maintenance Tasks
1. **Weekly**: Run validation queries to check data quality
2. **Monthly**: Review performance metrics and optimize if needed
3. **Quarterly**: Update documentation and test with new data patterns
4. **Annually**: Review business logic and field mappings

### Contact Information
- **Database Team**: [Your DB team contact]
- **Business Analyst**: [Your BA contact]
- **Development Team**: [Your dev team contact]

---

## 🎯 Quick Start Commands

### Run Basic Validation
```sql
-- Quick health check
SELECT 
    'Views' as component,
    COUNT(*) as count
FROM pg_views 
WHERE schemaname = 'claims' 
AND viewname LIKE '%balance_amount%'
UNION ALL
SELECT 
    'Functions' as component,
    COUNT(*) as count
FROM information_schema.routines 
WHERE routine_schema = 'claims' 
AND routine_name LIKE '%balance_amount%';
```

### Test with Sample Data
```sql
-- Quick sample test
SELECT 
    claim_id,
    facility_name,
    billed_amount,
    outstanding_balance,
    aging_bucket
FROM claims.v_balance_amount_tab_a_corrected 
WHERE encounter_start_date >= '2024-01-01'
LIMIT 5;
```

---

*This guide should be updated whenever the report structure or business logic changes.*
