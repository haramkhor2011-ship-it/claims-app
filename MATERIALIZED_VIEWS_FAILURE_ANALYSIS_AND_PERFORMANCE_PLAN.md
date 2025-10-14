# Materialized Views Failure Analysis & Performance Optimization Plan

**Date**: 2025-01-03  
**Scope**: Comprehensive plan to address failure scenarios, edge cases, and performance issues  
**Based on**: MATERIALIZED_VIEWS_ANALYSIS_REPORT.md analysis

---

## Executive Summary

This plan addresses critical issues identified in the materialized views analysis:
1. **Failure Scenarios**: Data exclusion, complex business logic, data inconsistencies
2. **Critical Edge Cases**: Future-dated claims, cycle limitations, hardcoded values
3. **Performance Issues**: Long refresh times, storage optimization, indexing strategies

---

## 1. FAILURE SCENARIOS ANALYSIS & REMEDIATION

### 1.1 Data Exclusion Issues

#### **Problem**: Several MVs exclude records with missing data
**Affected MVs:**
- `mv_remittance_advice_summary`: Excludes claims with no remittance data
- `mv_doctor_denial_summary`: Excludes claims with missing clinician/facility data
- `mv_rejected_claims_summary`: Excludes claims with no rejection data
- `mv_claim_summary_payerwise`: Excludes claims with NULL month_bucket
- `mv_claim_summary_encounterwise`: Excludes claims with NULL month_bucket

#### **Impact Assessment**
```sql
-- Query to assess data exclusion impact
SELECT 
  'mv_remittance_advice_summary' as mv_name,
  COUNT(*) as total_claims,
  COUNT(CASE WHEN rc.claim_key_id IS NOT NULL THEN 1 END) as included_claims,
  COUNT(CASE WHEN rc.claim_key_id IS NULL THEN 1 END) as excluded_claims,
  ROUND((COUNT(CASE WHEN rc.claim_key_id IS NULL THEN 1 END) * 100.0) / COUNT(*), 2) as exclusion_percentage
FROM claims.claim_key ck
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id;
```

#### **Remediation Plan**
1. **Create Inclusive Versions**: Develop alternative MVs that include all claims
2. **Data Quality Monitoring**: Implement alerts for high exclusion rates
3. **Business Rule Documentation**: Document why exclusions are necessary
4. **Fallback Strategies**: Provide alternative reporting for excluded data

### 1.2 Complex Business Logic Issues

#### **Problem**: Complex logic may not cover all edge cases
**Affected Areas:**
- Payment status calculations
- Rejection type logic
- Collection rate calculations
- Aging calculations

#### **Edge Case Analysis**
```sql
-- Payment Status Logic Edge Cases
SELECT 
  a.activity_id,
  a.net as submitted_amount,
  COALESCE(SUM(ra.payment_amount), 0) as total_payment,
  MAX(ra.denial_code) as latest_denial_code,
  -- Current logic
  CASE 
    WHEN MAX(ra.denial_code) IS NOT NULL AND COALESCE(SUM(ra.payment_amount), 0) = 0 THEN 'Fully Rejected'
    WHEN COALESCE(SUM(ra.payment_amount), 0) > 0 AND COALESCE(SUM(ra.payment_amount), 0) < a.net THEN 'Partially Rejected'
    WHEN COALESCE(SUM(ra.payment_amount), 0) = a.net THEN 'Fully Paid'
    ELSE 'Pending'
  END as current_status,
  -- Edge cases to consider
  CASE 
    WHEN COALESCE(SUM(ra.payment_amount), 0) > a.net THEN 'Overpaid'
    WHEN COALESCE(SUM(ra.payment_amount), 0) < 0 THEN 'Taken Back'
    WHEN a.net = 0 THEN 'Zero Amount'
    ELSE 'Standard'
  END as edge_case_type
FROM claims.activity a
LEFT JOIN claims.remittance_activity ra ON ra.activity_id = a.activity_id
GROUP BY a.activity_id, a.net
HAVING COUNT(*) > 1 OR COALESCE(SUM(ra.payment_amount), 0) != a.net;
```

#### **Remediation Plan**
1. **Comprehensive Test Cases**: Create test data covering all edge cases
2. **Business Logic Validation**: Review with business stakeholders
3. **Error Handling**: Add explicit handling for edge cases
4. **Monitoring**: Alert on unexpected status combinations

### 1.3 Data Inconsistencies

#### **Problem**: Different MVs use different date fields for bucketing
**Inconsistencies:**
- Some use `remittance_date`, others use `submission_date`
- Some use `encounter_start`, others use `claim_tx_at`
- Some use `event_time`, others use `settlement_date`

#### **Impact Assessment**
```sql
-- Date Inconsistency Analysis
SELECT 
  ck.claim_id,
  c.tx_at as submission_date,
  e.start_at as encounter_date,
  MAX(rc.date_settlement) as latest_remittance_date,
  MAX(ce.event_time) as latest_event_date,
  -- Month bucket differences
  DATE_TRUNC('month', c.tx_at) as submission_month,
  DATE_TRUNC('month', e.start_at) as encounter_month,
  DATE_TRUNC('month', MAX(rc.date_settlement)) as remittance_month,
  -- Identify inconsistencies
  CASE 
    WHEN DATE_TRUNC('month', c.tx_at) != DATE_TRUNC('month', e.start_at) THEN 'Submission vs Encounter'
    WHEN DATE_TRUNC('month', c.tx_at) != DATE_TRUNC('month', MAX(rc.date_settlement)) THEN 'Submission vs Remittance'
    ELSE 'Consistent'
  END as date_consistency
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.claim_event ce ON ce.claim_key_id = ck.id
GROUP BY ck.claim_id, c.tx_at, e.start_at;
```

#### **Remediation Plan**
1. **Standardize Date Fields**: Establish consistent date field usage across MVs
2. **Date Hierarchy**: Define priority order for date fields
3. **Validation Rules**: Implement date consistency checks
4. **Documentation**: Document date field usage for each MV

---

## 2. CRITICAL EDGE CASES ANALYSIS

### 2.1 Future-Dated Claims

#### **What are Future-Dated Claims?**
Future-dated claims are claims with transaction dates, encounter dates, or settlement dates that are in the future relative to the current system date.

#### **Examples:**
- Claims submitted with `tx_at` date in the future
- Encounters with `start_at` date in the future
- Remittances with `date_settlement` in the future

#### **Impact Analysis**
```sql
-- Future-dated claims analysis
SELECT 
  'Future Submission Dates' as category,
  COUNT(*) as count,
  MIN(c.tx_at) as earliest_future_date,
  MAX(c.tx_at) as latest_future_date
FROM claims.claim c
WHERE c.tx_at > CURRENT_DATE
UNION ALL
SELECT 
  'Future Encounter Dates' as category,
  COUNT(*) as count,
  MIN(e.start_at) as earliest_future_date,
  MAX(e.start_at) as latest_future_date
FROM claims.encounter e
WHERE e.start_at > CURRENT_DATE
UNION ALL
SELECT 
  'Future Remittance Dates' as category,
  COUNT(*) as count,
  MIN(rc.date_settlement) as earliest_future_date,
  MAX(rc.date_settlement) as latest_future_date
FROM claims.remittance_claim rc
WHERE rc.date_settlement > CURRENT_DATE;
```

#### **Business Impact**
1. **Reporting Distortion**: Future-dated claims appear in future month buckets
2. **Aging Calculations**: Negative aging days for future encounters
3. **Performance Issues**: MVs may not optimize correctly for future data
4. **Business Logic**: Collection rates and other metrics may be skewed

#### **Remediation Plan**
1. **Data Validation**: Implement checks to prevent future-dated claims
2. **Business Rules**: Define acceptable date ranges for each field
3. **MV Logic**: Add date range filters to exclude unreasonable future dates
4. **Monitoring**: Alert on future-dated claims above threshold

### 2.2 Cycle Limitations

#### **Why Cycle Limitations Exist**
The MVs are limited to tracking up to 5 resubmission/remittance cycles due to:
1. **Performance Considerations**: Unlimited cycles would create massive Cartesian products
2. **Storage Constraints**: More cycles = exponentially more storage
3. **Business Requirements**: Most claims don't exceed 5 cycles
4. **Query Complexity**: Unlimited cycles would make queries extremely complex

#### **Impact Analysis**
```sql
-- Cycle limitation impact analysis
WITH cycle_counts AS (
  SELECT 
    ce.claim_key_id,
    COUNT(*) as resubmission_count,
    COUNT(DISTINCT rc.id) as remittance_count
  FROM claims.claim_event ce
  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ce.claim_key_id
  WHERE ce.type = 2  -- Resubmission events
  GROUP BY ce.claim_key_id
)
SELECT 
  CASE 
    WHEN resubmission_count <= 5 THEN 'Within Limit'
    ELSE 'Exceeds Limit'
  END as limit_status,
  COUNT(*) as claim_count,
  MAX(resubmission_count) as max_cycles,
  AVG(resubmission_count) as avg_cycles
FROM cycle_counts
GROUP BY CASE WHEN resubmission_count <= 5 THEN 'Within Limit' ELSE 'Exceeds Limit' END;
```

#### **Business Impact**
1. **Data Loss**: Claims with >5 cycles lose historical tracking
2. **Reporting Gaps**: Incomplete resubmission/remittance history
3. **Business Intelligence**: Limited insights into complex claim lifecycles

#### **Remediation Plan**
1. **Dynamic Cycle Tracking**: Implement configurable cycle limits
2. **Summary Aggregation**: Track total cycles beyond the limit
3. **Alternative Reporting**: Create separate reports for high-cycle claims
4. **Business Rules**: Define maximum acceptable cycles per claim type

### 2.3 Hardcoded Values

#### **Problem**: Hardcoded checks limit flexibility
**Examples:**
- `payer_id = 'Self-Paid'` checks
- `type = 2` for resubmission events
- `type = 1` for submission events

#### **Impact Analysis**
```sql
-- Hardcoded value impact analysis
SELECT 
  'Self-Pay Detection' as category,
  COUNT(*) as total_claims,
  COUNT(CASE WHEN c.payer_id = 'Self-Paid' THEN 1 END) as self_pay_claims,
  COUNT(CASE WHEN c.payer_id != 'Self-Paid' AND c.payer_id IS NOT NULL THEN 1 END) as other_payer_claims,
  COUNT(CASE WHEN c.payer_id IS NULL THEN 1 END) as null_payer_claims
FROM claims.claim c;
```

#### **Remediation Plan**
1. **Configuration Tables**: Move hardcoded values to configuration tables
2. **Reference Data**: Use reference tables for all coded values
3. **Flexible Logic**: Implement parameterized business rules
4. **Documentation**: Document all hardcoded values and their business meaning

---

## 3. PERFORMANCE OPTIMIZATION PLAN

### 3.1 Refresh Time Analysis

#### **Current Refresh Times (Ranked by Duration)**
1. **mv_remittances_resubmission_activity_level**: 10-30 minutes ⚠️
2. **mv_claim_details_complete**: 5-15 minutes ⚠️
3. **mv_doctor_denial_summary**: 3-8 minutes ⚠️
4. **mv_rejected_claims_summary**: 3-8 minutes ⚠️
5. **mv_balance_amount_summary**: 2-5 minutes ✅
6. **mv_resubmission_cycles**: 2-5 minutes ✅
7. **mv_claim_summary_payerwise**: 2-5 minutes ✅
8. **mv_claim_summary_encounterwise**: 2-5 minutes ✅
9. **mv_remittance_advice_summary**: 1-3 minutes ✅
10. **mv_claims_monthly_agg**: 30 seconds - 2 minutes ✅

### 3.2 Performance Bottleneck Analysis

#### **mv_remittances_resubmission_activity_level (10-30 minutes)**
**Bottlenecks:**
- Complex CTEs with multiple aggregations
- Large Cartesian products from multiple JOINs
- Extensive reference data lookups
- Multiple cycle tracking (up to 5 cycles)

**Optimization Strategies:**
```sql
-- 1. Partition by date ranges
CREATE TABLE claims.activity_partitioned (
  LIKE claims.activity INCLUDING ALL
) PARTITION BY RANGE (start_at);

-- 2. Pre-aggregate reference data
CREATE MATERIALIZED VIEW claims.mv_reference_data_agg AS
SELECT 
  p.id as payer_id, p.name as payer_name,
  pr.id as provider_id, pr.name as provider_name,
  f.id as facility_id, f.name as facility_name,
  cl.id as clinician_id, cl.name as clinician_name
FROM claims_ref.payer p
CROSS JOIN claims_ref.provider pr
CROSS JOIN claims_ref.facility f
CROSS JOIN claims_ref.clinician cl;

-- 3. Use parallel processing
SET max_parallel_workers_per_gather = 4;
SET parallel_tuple_cost = 0.1;
SET parallel_setup_cost = 1000;
```

#### **mv_claim_details_complete (5-15 minutes)**
**Bottlenecks:**
- Activity-level remittance aggregation
- Multiple reference data JOINs
- Complex payment status calculations

**Optimization Strategies:**
```sql
-- 1. Create covering indexes
CREATE INDEX CONCURRENTLY idx_activity_covering 
ON claims.activity(claim_id, activity_id) 
INCLUDE (net, clinician, start_at, type, code, quantity);

-- 2. Pre-compute payment status
CREATE MATERIALIZED VIEW claims.mv_activity_payment_status AS
SELECT 
  a.activity_id,
  a.claim_id,
  a.net as submitted_amount,
  COALESCE(SUM(ra.payment_amount), 0) as total_payment,
  MAX(ra.denial_code) as latest_denial_code,
  CASE 
    WHEN MAX(ra.denial_code) IS NOT NULL AND COALESCE(SUM(ra.payment_amount), 0) = 0 THEN 'Fully Rejected'
    WHEN COALESCE(SUM(ra.payment_amount), 0) > 0 AND COALESCE(SUM(ra.payment_amount), 0) < a.net THEN 'Partially Rejected'
    WHEN COALESCE(SUM(ra.payment_amount), 0) = a.net THEN 'Fully Paid'
    ELSE 'Pending'
  END as payment_status
FROM claims.activity a
LEFT JOIN claims.remittance_activity ra ON ra.activity_id = a.activity_id
GROUP BY a.activity_id, a.claim_id, a.net;
```

### 3.3 Storage Optimization

#### **Current Storage Requirements**
1. **mv_remittances_resubmission_activity_level**: 2GB-5GB
2. **mv_claim_details_complete**: 1GB-3GB
3. **mv_balance_amount_summary**: 500MB-1GB
4. **mv_remittance_advice_summary**: 300MB-800MB
5. **mv_rejected_claims_summary**: 300MB-800MB
6. **mv_doctor_denial_summary**: 200MB-500MB
7. **mv_claim_summary_payerwise**: 100MB-300MB
8. **mv_claim_summary_encounterwise**: 100MB-300MB
9. **mv_resubmission_cycles**: 100MB-300MB
10. **mv_claims_monthly_agg**: 50MB-200MB

#### **Storage Optimization Strategies**
```sql
-- 1. Column compression
ALTER TABLE claims.mv_remittances_resubmission_activity_level 
SET (fillfactor = 90, autovacuum_vacuum_scale_factor = 0.1);

-- 2. Partitioning by date
CREATE TABLE claims.mv_claim_details_partitioned (
  LIKE claims.mv_claim_details_complete INCLUDING ALL
) PARTITION BY RANGE (submission_date);

-- 3. Archive old data
CREATE TABLE claims.mv_claim_details_archive (
  LIKE claims.mv_claim_details_complete INCLUDING ALL
);

-- 4. Use TOAST for large text fields
ALTER TABLE claims.mv_remittances_resubmission_activity_level 
ALTER COLUMN all_denial_codes SET STORAGE EXTENDED;
```

### 3.4 Indexing Optimization

#### **Current Index Strategy Issues**
1. **Missing Covering Indexes**: Some queries still require table lookups
2. **Inefficient Composite Indexes**: Some indexes don't match query patterns
3. **Index Bloat**: Large indexes with low selectivity

#### **Optimization Plan**
```sql
-- 1. Add covering indexes for common queries
CREATE INDEX CONCURRENTLY idx_mv_balance_covering_enhanced 
ON claims.mv_balance_amount_summary(claim_key_id, payer_id, provider_id) 
INCLUDE (pending_amount, aging_days, current_status, total_payment, total_denied);

-- 2. Create partial indexes for filtered queries
CREATE INDEX CONCURRENTLY idx_mv_rejected_claims_recent 
ON claims.mv_rejected_claims_summary(claim_key_id, activity_id) 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months');

-- 3. Add expression indexes for calculated fields
CREATE INDEX CONCURRENTLY idx_mv_claim_details_aging 
ON claims.mv_claim_details_complete(EXTRACT(DAYS FROM (CURRENT_DATE - DATE_TRUNC('day', encounter_start))));

-- 4. Create GIN indexes for text search
CREATE INDEX CONCURRENTLY idx_mv_claim_details_denial_gin 
ON claims.mv_claim_details_complete USING GIN(to_tsvector('english', denial_code));
```

---

## 4. IMPLEMENTATION ROADMAP

### Phase 1: Critical Issues (Week 1-2)
1. **Data Exclusion Monitoring**: Implement alerts for high exclusion rates
2. **Future-Dated Claims**: Add validation and filtering
3. **Hardcoded Values**: Document and create configuration tables
4. **Performance Monitoring**: Set up refresh time monitoring

### Phase 2: Performance Optimization (Week 3-4)
1. **Index Optimization**: Implement covering and partial indexes
2. **Query Optimization**: Optimize slowest MVs (mv_remittances_resubmission_activity_level)
3. **Storage Optimization**: Implement partitioning and compression
4. **Parallel Processing**: Enable parallel query execution

### Phase 3: Advanced Features (Week 5-6)
1. **Dynamic Cycle Tracking**: Implement configurable cycle limits
2. **Alternative Reporting**: Create reports for excluded data
3. **Business Logic Validation**: Comprehensive test cases
4. **Documentation**: Complete business logic documentation

### Phase 4: Monitoring & Maintenance (Week 7-8)
1. **Automated Monitoring**: Set up comprehensive monitoring
2. **Performance Baselines**: Establish performance benchmarks
3. **Maintenance Procedures**: Document maintenance procedures
4. **Disaster Recovery**: Implement backup and recovery procedures

---

## 5. SUCCESS METRICS

### Performance Metrics
- **Refresh Time Target**: All MVs < 5 minutes
- **Storage Growth**: < 10% monthly growth
- **Query Performance**: < 1 second for all reports
- **Index Efficiency**: > 95% index hit ratio

### Quality Metrics
- **Data Exclusion Rate**: < 5% for all MVs
- **Future-Dated Claims**: < 1% of total claims
- **Cycle Limitation Impact**: < 2% of claims exceed limits
- **Business Logic Coverage**: 100% of edge cases handled

### Operational Metrics
- **MV Refresh Success Rate**: > 99%
- **Monitoring Alert Response**: < 15 minutes
- **Documentation Coverage**: 100% of business logic documented
- **Test Coverage**: > 95% of code paths tested

---

**Plan Generated**: 2025-01-03  
**Next Review**: 2025-01-10  
**Owner**: Claims Team  
**Stakeholders**: Database Team, Business Analysts, Operations Team
