# Remittances & Resubmission Activity Level Report - Production Documentation

## 📋 **Report Overview**

The **Remittances & Resubmission Activity Level Report** is a comprehensive business intelligence tool that tracks the complete claim lifecycle from initial submission through multiple remittance and resubmission cycles. This report provides visibility into claim recovery, denial handling, and resubmission outcomes at both activity and claim levels.

### **Key Features**
- **Activity Level Tracking**: Line-item detail for each CPT code and activity
- **Claim Level Aggregation**: Summary view by claim, payer, and facility
- **Resubmission Cycles**: Track up to 5 resubmission cycles per claim
- **Remittance Tracking**: Monitor payment cycles and amounts
- **Financial Metrics**: Calculate recovery rates, rejection rates, and outstanding balances
- **Aging Analysis**: Track claim aging and processing timelines

## 🎯 **Business Purpose**

### **Primary Use Cases**
1. **Revenue Cycle Management**: Monitor claim recovery and identify bottlenecks
2. **Denial Management**: Track denial patterns and resubmission success rates
3. **Performance Analytics**: Analyze facility, payer, and clinician performance
4. **Financial Reporting**: Calculate recovery rates and outstanding balances
5. **Process Optimization**: Identify opportunities for workflow improvements

### **Target Users**
- **Revenue Cycle Managers**: Monitor overall claim performance
- **Denial Management Teams**: Track and resolve claim denials
- **Facility Administrators**: Analyze facility-specific performance
- **Financial Analysts**: Calculate recovery metrics and trends
- **Clinical Teams**: Monitor clinician and service performance

## 🗂️ **Report Structure**

### **Tab 1: Activity Level**
- **Purpose**: Detailed line-item analysis of each activity/CPT code
- **Key Fields**: Activity ID, CPT Code, Clinician, Financial amounts, Resubmission cycles
- **Use Case**: Drill-down analysis of specific services and denials

### **Tab 2: Claim Level**
- **Purpose**: Aggregated view by claim, payer, and facility
- **Key Fields**: Claim ID, Patient info, Total amounts, Summary metrics
- **Use Case**: High-level performance monitoring and trend analysis

## 📊 **Data Sources**

### **Primary Tables**
- `claims.claim` - Core claim information
- `claims.activity` - Activity/CPT code details
- `claims.encounter` - Encounter information
- `claims.remittance_claim` - Remittance processing
- `claims.remittance_activity` - Activity-level payments
- `claims.claim_event` - Event tracking
- `claims.claim_resubmission` - Resubmission details

### **Reference Data**
- `claims_ref.payer` - Payer master data
- `claims_ref.facility` - Facility master data
- `claims_ref.clinician` - Clinician master data
- `claims_ref.denial_code` - Denial code dictionary

## 🔧 **Technical Implementation**

### **Database Objects**

#### **Views**
- `claims.v_remittances_resubmission_activity_level` - Activity level data
- `claims.v_remittances_resubmission_claim_level` - Claim level data
- `claims.v_remittances_resubmission_usage_stats` - Usage statistics

#### **Functions**
- `claims.get_remittances_resubmission_activity_level()` - Activity level API
- `claims.get_remittances_resubmission_claim_level()` - Claim level API
- `claims.rollback_remittances_resubmission_report()` - Rollback function

#### **Indexes**
- Performance indexes on key lookup fields
- Composite indexes for common query patterns
- Partial indexes for active records

### **Performance Optimizations**
- **Strategic Indexing**: 8+ indexes for common query patterns
- **Query Optimization**: Efficient joins and aggregations
- **Pagination Support**: Built-in limit/offset functionality
- **Filtering**: Comprehensive filter support for all major fields

## 📈 **Key Metrics**

### **Financial Metrics**
- **Submitted Amount**: Total amount billed per activity/claim
- **Paid Amount**: Total amount received
- **Rejected Amount**: Outstanding balance
- **Recovery Rate**: Percentage of submitted amount recovered
- **Rejection Rate**: Percentage of submitted amount rejected

### **Process Metrics**
- **Resubmission Count**: Number of resubmission cycles
- **Remittance Count**: Number of payment cycles
- **Aging Days**: Days since encounter start
- **Processing Time**: Time from submission to resolution

### **Quality Metrics**
- **Denial Codes**: Specific denial reasons
- **Resubmission Success**: Success rate of resubmissions
- **Facility Performance**: Performance by facility
- **Payer Performance**: Performance by payer

## 🔍 **Filtering Options**

### **Date Filters**
- **From Date/To Date**: Date range for encounter start
- **Year/Month**: Predefined time periods
- **Transaction Date**: Based on submission/remittance dates

### **Entity Filters**
- **Facility**: Single or multiple facility selection
- **Payer**: Single or multiple payer selection
- **Receiver**: Single or multiple receiver selection
- **Clinician**: Single or multiple clinician selection

### **Clinical Filters**
- **Encounter Type**: Inpatient/Outpatient
- **CPT Code**: Specific procedure codes
- **Diagnosis**: Primary/Secondary diagnosis codes

### **Status Filters**
- **Denial Status**: Has denial/No denial/Rejected not resubmitted
- **Payment Status**: Paid/Partially paid/Unpaid
- **Resubmission Status**: Has resubmissions/No resubmissions

## 📋 **Field Mappings**

### **Core Identifiers**
| Report Field | Database Field | Description |
|--------------|----------------|-------------|
| Claim ID | `claim.claim_id` | Unique claim identifier |
| Activity ID | `activity.activity_id` | Unique activity identifier |
| Member ID | `claim.member_id` | Patient member ID |
| Patient ID | `claim.emirates_id_number` | Emirates ID number |

### **Financial Fields**
| Report Field | Database Field | Description |
|--------------|----------------|-------------|
| Submitted Amount | `activity.net` | Amount submitted per activity |
| Total Paid | `SUM(remittance_activity.payment_amount)` | Total payments received |
| Rejected Amount | `submitted_amount - total_paid` | Outstanding balance |
| Recovery Rate | `(total_paid / submitted_amount) * 100` | Percentage recovered |

### **Process Fields**
| Report Field | Database Field | Description |
|--------------|----------------|-------------|
| Resubmission Count | `COUNT(claim_event WHERE type=2)` | Number of resubmissions |
| Remittance Count | `COUNT(remittance_claim)` | Number of payments |
| Aging Days | `CURRENT_DATE - encounter.start_at` | Days since encounter |
| CPT Status | Derived from payment/denial status | Processing status |

## 🚀 **Deployment Process**

### **Pre-Deployment Checklist**
- [ ] Database schema validation
- [ ] Required tables verification
- [ ] Backup existing objects
- [ ] Performance baseline establishment

### **Deployment Steps**
1. **Execute Implementation Script**: `remittances_resubmission_report_implementation.sql`
2. **Run Validation Tests**: `remittances_resubmission_report_validation_tests.sql`
3. **Execute Deployment Script**: `remittances_resubmission_report_deployment.sql`
4. **User Acceptance Testing**: Verify functionality and performance
5. **Go-Live**: Enable for production use

### **Post-Deployment Monitoring**
- Monitor query performance
- Track usage statistics
- Validate data accuracy
- Monitor system resources

## 🔄 **Rollback Procedure**

### **Automatic Rollback**
```sql
SELECT claims.rollback_remittances_resubmission_report();
```

### **Manual Rollback**
1. Drop current objects
2. Restore from backup schema
3. Verify functionality
4. Update documentation

## 📊 **Usage Examples**

### **Basic Activity Level Query**
```sql
SELECT * FROM claims.get_remittances_resubmission_activity_level(
    p_facility_id := 'FACILITY001',
    p_from_date := '2024-01-01'::TIMESTAMPTZ,
    p_to_date := '2024-12-31'::TIMESTAMPTZ,
    p_limit := 1000
);
```

### **Claim Level with Filters**
```sql
SELECT * FROM claims.get_remittances_resubmission_claim_level(
    p_facility_ids := ARRAY['FACILITY001', 'FACILITY002'],
    p_payer_ids := ARRAY['PAYER001'],
    p_encounter_type := 'INPATIENT',
    p_denial_filter := 'HAS_DENIAL',
    p_limit := 500
);
```

### **Performance Monitoring**
```sql
SELECT * FROM claims.v_remittances_resubmission_usage_stats;
```

## 🛠️ **Maintenance**

### **Regular Maintenance Tasks**
- **Index Maintenance**: Monitor and rebuild indexes as needed
- **Statistics Update**: Keep table statistics current
- **Performance Monitoring**: Track query performance and optimize
- **Data Validation**: Regular data quality checks

### **Troubleshooting**
- **Performance Issues**: Check indexes and query plans
- **Data Issues**: Validate source data integrity
- **Access Issues**: Verify permissions and grants
- **Function Issues**: Check function parameters and logic

## 📚 **Additional Resources**

### **Related Documentation**
- `claims_unified_ddl_fresh.sql` - Database schema
- `xml fields mappings.csv` - Field mapping reference
- `balance_amount_report_implementation.sql` - Similar report pattern
- `rejected_claims_report_implementation.sql` - Related report pattern

### **Support Contacts**
- **Database Team**: For technical issues
- **Business Analysts**: For business logic questions
- **Report Users**: For usage and training

## 📝 **Version History**

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-09-24 | Initial production implementation |
| | | - Activity level view with resubmission tracking |
| | | - Claim level aggregated view |
| | | - API functions with filtering |
| | | - Performance indexes |
| | | - Validation tests |
| | | - Deployment scripts |

---

**Document Status**: Production Ready  
**Last Updated**: 2025-09-24  
**Next Review**: 2025-10-24
