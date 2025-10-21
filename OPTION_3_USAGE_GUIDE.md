# OPTION 3 USAGE GUIDE - HYBRID APPROACH WITH DB TOGGLE

## Overview
This guide explains how to use Option 3 (Hybrid Approach) with DB toggle for switching between traditional views and MVs.

## Configuration

### **Application Properties**
```yaml
# Enable Option 3
claims:
  reports:
    use-materialized-views: false  # Global toggle
    default-tabs:
      balance-amount: overall
      claim-details: details
      claim-summary: monthwise
      doctor-denial: high_denial
      rejected-claims: summary
      remittance-advice: header
      resubmission: activity_level

option3:
  enabled: true
  performance:
    sub-second-mode: false
```

## Function Usage

### **Function Signature Pattern**
All functions now support Option 3 parameters:
```sql
CREATE OR REPLACE FUNCTION claims.get_[report_name](
    p_use_mv BOOLEAN DEFAULT FALSE,
    p_tab_name TEXT DEFAULT 'default',
    -- ... existing parameters
) RETURNS TABLE(...) AS $$
```

### **Function Call Examples**

#### **1. Balance Amount Report**
```sql
-- Use traditional views (default)
SELECT * FROM claims.get_balance_amount_to_be_received(
    p_use_mv := FALSE,
    p_tab_name := 'overall',
    p_user_id := 'USER001',
    p_facility_codes := ARRAY['FAC001', 'FAC002']
);

-- Use MVs for sub-second performance
SELECT * FROM claims.get_balance_amount_to_be_received(
    p_use_mv := TRUE,
    p_tab_name := 'overall',
    p_user_id := 'USER001',
    p_facility_codes := ARRAY['FAC001', 'FAC002']
);

-- Use specific tab with MVs
SELECT * FROM claims.get_balance_amount_to_be_received(
    p_use_mv := TRUE,
    p_tab_name := 'initial',
    p_user_id := 'USER001'
);
```

#### **2. Claim Details Report**
```sql
-- Use traditional views
SELECT * FROM claims.get_claim_details_with_activity(
    p_use_mv := FALSE,
    p_tab_name := 'details',
    p_facility_code := 'FAC001'
);

-- Use MVs
SELECT * FROM claims.get_claim_details_with_activity(
    p_use_mv := TRUE,
    p_tab_name := 'details',
    p_facility_code := 'FAC001'
);
```

#### **3. Doctor Denial Report**
```sql
-- Use traditional views
SELECT * FROM claims.get_doctor_denial_report(
    p_use_mv := FALSE,
    p_tab_name := 'high_denial',
    p_facility_code := 'FAC001'
);

-- Use MVs with different tabs
SELECT * FROM claims.get_doctor_denial_report(
    p_use_mv := TRUE,
    p_tab_name := 'summary',
    p_facility_code := 'FAC001'
);

SELECT * FROM claims.get_doctor_denial_report(
    p_use_mv := TRUE,
    p_tab_name := 'detail',
    p_facility_code := 'FAC001'
);
```

## Java Integration

### **Using Option3ReportService**
```java
@Autowired
private Option3ReportService option3Service;

// Get parameters for Balance Amount Report
Option3ReportService.BalanceAmountReportParams params = 
    option3Service.getBalanceAmountReportParams(useMv, tabName);

// Use parameters in function call
boolean useMv = params.isUseMv();
String tabName = params.getTabName();
```

### **REST API Usage**
```bash
# Get Balance Amount Report with traditional views
GET /api/v1/reports/option3/balance-amount?use_mv=false&tab_name=overall

# Get Balance Amount Report with MVs
GET /api/v1/reports/option3/balance-amount?use_mv=true&tab_name=overall

# Get Doctor Denial Report with different tabs
GET /api/v1/reports/option3/doctor-denial?use_mv=true&tab_name=high_denial
GET /api/v1/reports/option3/doctor-denial?use_mv=true&tab_name=summary
GET /api/v1/reports/option3/doctor-denial?use_mv=true&tab_name=detail
```

## Available Tabs

### **Balance Amount Report**
- `overall` - Overall balances
- `initial` - Initial not remitted
- `resubmission` - After resubmission

### **Claim Details Report**
- `details` - Comprehensive view

### **Claim Summary Report**
- `monthwise` - Monthwise summary
- `payerwise` - Payerwise summary
- `encounterwise` - Encounterwise summary

### **Doctor Denial Report**
- `high_denial` - High denial doctors
- `summary` - Summary view
- `detail` - Detail view

### **Rejected Claims Report**
- `by_year` - Summary by year
- `summary` - Summary view
- `receiver_payer` - Receiver/Payer view
- `claim_wise` - Claim-wise view

### **Remittance Advice Report**
- `header` - Header summary
- `claim_wise` - Claim-wise details
- `activity_wise` - Activity-wise details

### **Resubmission Report**
- `activity_level` - Activity level
- `claim_level` - Claim level

## Performance Comparison

### **Traditional Views**
- **Response Time**: 2-5 seconds
- **Data Freshness**: Real-time
- **Resource Usage**: High CPU/Memory
- **Scalability**: Limited

### **Materialized Views**
- **Response Time**: 0.2-2 seconds
- **Data Freshness**: Refresh required
- **Resource Usage**: Low CPU/Memory
- **Scalability**: High

## Best Practices

### **When to Use Traditional Views**
- Real-time data requirements
- Frequent data updates
- Small dataset queries
- Development/testing

### **When to Use MVs**
- Performance-critical reports
- Large dataset queries
- Dashboard applications
- Production environments

### **Configuration Recommendations**
```yaml
# Development
claims:
  reports:
    use-materialized-views: false

# Production
claims:
  reports:
    use-materialized-views: true
    performance:
      sub-second-mode: true
```

## Monitoring

### **Performance Metrics**
- Query execution time
- MV refresh duration
- Data consistency checks
- Resource utilization

### **Health Checks**
- MV refresh status
- Data consistency validation
- Function availability
- Configuration validation

## Troubleshooting

### **Common Issues**
1. **MV not refreshed**: Check refresh schedule
2. **Data inconsistency**: Run consistency checks
3. **Performance issues**: Verify MV indexes
4. **Function errors**: Check parameter validation

### **Debugging**
```sql
-- Check MV refresh status
SELECT schemaname, matviewname, ispopulated 
FROM pg_matviews 
WHERE schemaname = 'claims';

-- Check function parameters
SELECT proname, proargnames, proargtypes 
FROM pg_proc 
WHERE proname LIKE 'get_%';
```

## Conclusion

Option 3 provides maximum flexibility for switching between traditional views and MVs based on performance requirements and data freshness needs. Use traditional views for real-time data and MVs for sub-second performance.

