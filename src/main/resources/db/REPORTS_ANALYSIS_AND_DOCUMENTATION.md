# Claims Processing System - Reports Analysis and Documentation

## Overview

This document provides a comprehensive analysis of all report SQL files in the claims processing system. Each report is designed to provide specific business insights and operational metrics for healthcare claims management.

## Database Schema Reference

The reports are built on top of the `claims_unified_ddl_fresh.sql` schema, which includes:
- **Main Schema**: `claims` - Core business tables
- **Reference Schema**: `claims_ref` - Master data tables
- **Key Tables**: claim, submission, remittance, encounter, activity, diagnosis, etc.

---

## Report 1: Claim Details with Activity Report

### **File**: `01_claim_details_with_activity_report_corrected.sql`

### **Purpose**
Comprehensive view of claim details along with all related activities including submissions, remittances, events, and status changes.

### **Key Features**
- **Main View**: `v_claim_details_with_activity`
- **Summary View**: `v_claim_activity_summary` (monthly aggregations)
- **Timeline View**: `v_claim_activity_timeline` (chronological activities)
- **Performance View**: `v_provider_activity_performance` (provider metrics)

### **Core Data Points**
- **Claim Information**: ID, number, patient, provider, facility, type, status, amounts
- **Submission Tracking**: Type, status, submission/acknowledgment/processing dates
- **Remittance Data**: Type, status, amount, date, processing details
- **Event Tracking**: Event types, status, timing, descriptions
- **Activity Details**: Activity types, amounts, comments, timing
- **Provider/Facility/Patient Info**: Names, codes, specialties, contact details

### **Business Intelligence Fields**
- **Claim Lifecycle Status**: COMPLETED, IN_PROGRESS, FAILED, UNKNOWN
- **Payment Status**: OUTSTANDING, SETTLED, OVERPAID
- **Collection Priority**: HIGH_PRIORITY, MEDIUM_PRIORITY, LOW_PRIORITY
- **Claim Age Category**: AGED (>90 days), MATURE (30-90 days), FRESH (<30 days)

### **Key Metrics**
- Days since creation
- Days to process submission
- Days to process remittance
- Payment success rates
- Rejection rates
- Outstanding amounts

### **Usage Examples**
```sql
-- Get all claims with activities for a specific provider
SELECT * FROM claims.v_claim_details_with_activity 
WHERE provider_npi = '1234567890' 
ORDER BY claim_created_at DESC;

-- Get monthly summary for dashboard
SELECT * FROM claims.v_claim_activity_summary 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months');

-- Get high-priority outstanding claims
SELECT * FROM claims.v_claim_details_with_activity 
WHERE balance_amount > 0 
    AND collection_priority IN ('HIGH_PRIORITY', 'MEDIUM_PRIORITY');
```

---

## Report 2: Balance Amount to be Received Report

### **File**: `02_balance_amount_to_be_received_report_corrected.sql`

### **Purpose**
Tracks outstanding balance amounts across three distinct categories for comprehensive financial management.

### **Key Features**
- **Base View**: `v_balance_amount_base` (performance-optimized)
- **Tab A**: `v_balance_amount_tab_a_balance_to_be_received` (all pending amounts)
- **Tab B**: `v_balance_amount_tab_b_initial_not_remitted` (initial submissions only)
- **Tab C**: `v_balance_amount_tab_c_after_resubmission_not_remitted` (post-resubmission)

### **Core Data Points**
- **Claim Financials**: Initial gross, patient share, net amounts
- **Payment Tracking**: Total payment, denied, pending amounts
- **Resubmission Data**: Count, dates, comments, types
- **Encounter Details**: Facility, type, patient, start/end dates
- **File Tracking**: Submission files, receiver IDs, transaction dates

### **Business Logic**
- **Tab A**: All claims with any pending amount
- **Tab B**: Initial submissions with no remittance or denials
- **Tab C**: Claims that have been resubmitted but still have pending amounts

### **Key Metrics**
- Pending amount calculation
- Write-off amount calculation
- Remittance count and timing
- Resubmission count and effectiveness
- Claim status categorization

### **Usage Examples**
```sql
-- Get all pending claims for a specific facility
SELECT * FROM claims.v_balance_amount_tab_a_balance_to_be_received 
WHERE facility_id = 'FAC001' 
ORDER BY pending_amt DESC;

-- Get initial submissions without remittance
SELECT * FROM claims.v_balance_amount_tab_b_initial_not_remitted 
WHERE encounter_start >= '2024-01-01';

-- Get resubmitted claims still pending
SELECT * FROM claims.v_balance_amount_tab_c_after_resubmission_not_remitted 
WHERE resubmission_count > 0;
```

---

## Report 3: Claim Payment Status Report

### **File**: `03_claim_payment_status_report_corrected.sql`

### **Purpose**
Detailed payment status information for claims including payment amounts, dates, methods, and status tracking.

### **Key Features**
- **Main View**: `v_claim_payment_status`
- **Summary View**: `v_payment_status_summary`
- **Method Analysis**: `v_payment_method_analysis`
- **Provider Performance**: `v_provider_payment_performance`
- **Monthly Trends**: `v_monthly_payment_trends`

### **Core Data Points**
- **Payment Information**: Method, status, amount, date, reference numbers
- **Processing Details**: Processed dates, transaction IDs, bank details
- **Remittance Data**: Type, status, amount, processing details
- **Provider/Facility/Patient Info**: Complete contact and identification details

### **Business Intelligence Fields**
- **Payment Status Category**: FULLY_PAID, PARTIALLY_PAID, PENDING_PAYMENT, PAYMENT_REJECTED, AWAITING_PROCESSING
- **Collection Priority**: HIGH_PRIORITY, MEDIUM_PRIORITY, LOW_PRIORITY, SETTLED
- **Payment Speed Category**: FAST (≤30 days), NORMAL (30-60 days), SLOW (>60 days), PENDING

### **Key Metrics**
- Days to payment
- Days to process payment
- Payment success rates
- Collection rates
- Processing efficiency

### **Usage Examples**
```sql
-- Get payment status for specific provider
SELECT * FROM claims.v_claim_payment_status 
WHERE provider_npi = '1234567890' 
ORDER BY payment_date DESC;

-- Get payment method analysis
SELECT * FROM claims.v_payment_method_analysis 
ORDER BY success_rate DESC;

-- Get high-priority outstanding payments
SELECT * FROM claims.v_claim_payment_status 
WHERE balance_amount > 0 
    AND collection_priority IN ('HIGH_PRIORITY', 'MEDIUM_PRIORITY');
```

---

## Report 4: Claim Summary Monthwise Report

### **File**: `04_claim_summary_monthwise_report_corrected.sql`

### **Purpose**
Monthly summaries of claims including counts, amounts, status distributions, and performance metrics.

### **Key Features**
- **Main View**: `v_claim_summary_monthwise`
- **Status Distribution**: `v_monthly_status_distribution`
- **Provider Performance**: `v_monthly_provider_performance`
- **Facility Performance**: `v_monthly_facility_performance`
- **Trends Analysis**: `v_monthly_trends_analysis`
- **Quarterly Summary**: `v_quarterly_summary`

### **Core Data Points**
- **Time Dimensions**: Month, year, month name
- **Claim Counts**: Total, paid, pending, rejected, submitted, partial
- **Financial Metrics**: Total, paid, balance amounts and averages
- **Entity Counts**: Unique providers, facilities, patients
- **Performance Metrics**: Success rates, collection rates, rejection rates

### **Business Intelligence Fields**
- **Volume Category**: HIGH_VOLUME (≥1000), MEDIUM_VOLUME (500-999), LOW_VOLUME (<500)
- **Outstanding Category**: HIGH_OUTSTANDING (>30%), MEDIUM_OUTSTANDING (10-30%), LOW_OUTSTANDING (<10%)

### **Key Metrics**
- Payment success rate
- Collection rate
- Rejection rate
- Average claim age
- Month-over-month changes
- Volume and outstanding trends

### **Usage Examples**
```sql
-- Get monthly summary for last 12 months
SELECT * FROM claims.v_claim_summary_monthwise 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY report_month DESC;

-- Get monthly trends with change analysis
SELECT * FROM claims.v_monthly_trends_analysis 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months');

-- Get provider performance by month
SELECT * FROM claims.v_monthly_provider_performance 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '3 months');
```

---

## Report 5: Doctor Denial Report

### **File**: `05_doctor_denial_report_corrected.sql`

### **Purpose**
Detailed analysis of claim denials by doctors/providers including denial reasons, patterns, and performance metrics.

### **Key Features**
- **Main View**: `v_doctor_denial_report`
- **Summary View**: `v_doctor_denial_summary`
- **Reason Analysis**: `v_denial_reason_analysis`
- **Provider Patterns**: `v_provider_denial_patterns`
- **Monthly Trends**: `v_monthly_denial_trends`
- **Prevention Recommendations**: `v_denial_prevention_recommendations`

### **Core Data Points**
- **Denial Information**: Reason, code, date, amount, category, description
- **Provider Details**: Name, NPI, specialty, license, contact info
- **Claim Context**: Type, status, amounts, creation/update dates
- **Patient/Facility Info**: Complete identification and contact details

### **Business Intelligence Fields**
- **Denial Severity**: HIGH_DENIAL (>80%), MEDIUM_DENIAL (50-80%), LOW_DENIAL (<50%), NO_DENIAL
- **Denial Type Category**: MEDICAL, AUTHORIZATION, CODING, ELIGIBILITY, COVERAGE, DUPLICATE, OTHER
- **Prevention Category**: PREVENTABLE, TRAINABLE, CLINICAL_REVIEW, COMPLEX
- **Risk Category**: HIGH_RISK (>20%), MEDIUM_RISK (10-20%), LOW_RISK (<10%)

### **Key Metrics**
- Days to denial
- Denial rates by provider
- Denial amount percentages
- Prevention potential percentages
- Improvement recommendations

### **Usage Examples**
```sql
-- Get doctor denial report for specific provider
SELECT * FROM claims.v_doctor_denial_report 
WHERE provider_npi = '1234567890' 
ORDER BY denial_amount DESC;

-- Get high-risk providers
SELECT * FROM claims.v_doctor_denial_summary 
WHERE denial_rate > 15 
ORDER BY denial_rate DESC;

-- Get denial reason analysis
SELECT * FROM claims.v_denial_reason_analysis 
WHERE denial_count >= 10
ORDER BY total_denial_amount DESC;
```

---

## Report 6: Rejected Claims Report

### **File**: `06_rejected_claims_report_corrected.sql`

### **Purpose**
Comprehensive analysis of rejected claims including rejection reasons, patterns, and recovery opportunities.

### **Key Features**
- **Main View**: `v_rejected_claims_report`
- **Summary View**: `v_rejected_claims_summary`
- **Provider Analysis**: `v_provider_rejection_analysis`
- **Reason Analysis**: `v_rejection_reason_analysis`
- **Monthly Trends**: `v_monthly_rejection_trends`
- **Recovery Opportunities**: `v_recovery_opportunities`
- **Prevention Strategies**: `v_rejection_prevention_strategies`

### **Core Data Points**
- **Rejection Information**: Reason, code, date, amount, category, description
- **Provider Details**: Name, NPI, specialty, contact information
- **Claim Context**: Type, status, amounts, creation/update dates
- **Patient/Facility Info**: Complete identification and contact details

### **Business Intelligence Fields**
- **Rejection Severity**: HIGH_REJECTION (>80%), MEDIUM_REJECTION (50-80%), LOW_REJECTION (<50%), NO_REJECTION
- **Rejection Type Category**: MEDICAL, AUTHORIZATION, CODING, ELIGIBILITY, COVERAGE, DUPLICATE, TIMELY_FILING, OTHER
- **Recovery Potential**: HIGH_RECOVERY, MEDIUM_RECOVERY, LOW_RECOVERY, NO_RECOVERY
- **Prevention Category**: PREVENTABLE, TRAINABLE, VERIFIABLE, CLINICAL_REVIEW, COMPLEX

### **Key Metrics**
- Days to rejection
- Recovery potential percentages
- Prevention potential percentages
- Expected recovery amounts
- Recovery action recommendations

### **Usage Examples**
```sql
-- Get rejected claims for specific provider
SELECT * FROM claims.v_rejected_claims_report 
WHERE provider_npi = '1234567890' 
ORDER BY rejection_amount DESC;

-- Get high-priority recovery opportunities
SELECT * FROM claims.v_recovery_opportunities 
WHERE recovery_probability IN ('HIGH', 'MEDIUM')
    AND expected_recovery_amount > 1000
ORDER BY recovery_priority, expected_recovery_amount DESC;

-- Get rejection prevention strategies
SELECT * FROM claims.v_rejection_prevention_strategies 
ORDER BY potential_savings_estimate DESC;
```

---

## Report 7: Remittance Advice Payerwise Report

### **File**: `07_remittance_advice_payerwise_report_corrected.sql`

### **Purpose**
Detailed analysis of remittance advice by payer including payment amounts, adjustments, and performance metrics.

### **Key Features**
- **Main View**: `v_remittance_advice_payerwise`
- **Payer Performance**: `v_payer_performance_summary`
- **Monthly Trends**: `v_monthly_payer_trends`
- **Provider-Payer Performance**: `v_provider_payer_performance`
- **Contract Analysis**: `v_payer_contract_analysis`
- **Efficiency Analysis**: `v_payment_efficiency_analysis`

### **Core Data Points**
- **Remittance Information**: Type, status, date, amount, processing details
- **Payer Details**: Name, code, type, contact information
- **Claim Context**: Type, status, amounts, creation dates
- **Provider/Facility/Patient Info**: Complete identification and contact details

### **Business Intelligence Fields**
- **Payment Level**: HIGH_PAYMENT (>80%), MEDIUM_PAYMENT (50-80%), LOW_PAYMENT (<50%), NO_PAYMENT
- **Payment Status**: FULL_PAYMENT, PARTIAL_PAYMENT, NO_PAYMENT
- **Payment Speed Category**: FAST (≤30 days), NORMAL (30-60 days), SLOW (>60 days), PENDING
- **Contract Performance**: EXCELLENT (≥95%), GOOD (85-95%), FAIR (70-85%), POOR (<70%), NO_PAYMENT

### **Key Metrics**
- Days to remittance
- Payment rates by payer
- Contract performance rates
- Processing efficiency
- Risk assessment

### **Usage Examples**
```sql
-- Get remittance advice for specific payer
SELECT * FROM claims.v_remittance_advice_payerwise 
WHERE payer_code = 'PAYER001' 
ORDER BY remittance_date DESC;

-- Get payer performance summary
SELECT * FROM claims.v_payer_performance_summary 
ORDER BY payment_rate DESC, fast_payment_rate DESC;

-- Get contract analysis with recommendations
SELECT * FROM claims.v_payer_contract_analysis 
ORDER BY poor_performance_loss DESC;
```

---

## Report 8: Remittances Resubmission Activity Level Report

### **File**: `08_remittances_resubmission_activity_level_report_corrected.sql`

### **Purpose**
Detailed analysis of remittances and resubmission activities including activity levels, patterns, and performance metrics.

### **Key Features**
- **Main View**: `v_remittances_resubmission_activity`
- **Activity Summary**: `v_resubmission_activity_summary`
- **Provider Analysis**: `v_provider_resubmission_analysis`
- **Reason Analysis**: `v_resubmission_reason_analysis`
- **Monthly Trends**: `v_monthly_resubmission_trends`
- **Efficiency Analysis**: `v_resubmission_efficiency_analysis`
- **Improvement Opportunities**: `v_resubmission_improvement_opportunities`

### **Core Data Points**
- **Resubmission Information**: Type, status, date, reason, amount
- **Remittance Context**: Type, status, date, amount, processing details
- **Claim Details**: Type, status, amounts, creation dates
- **Provider/Facility/Patient Info**: Complete identification and contact details

### **Business Intelligence Fields**
- **Resubmission Level**: HIGH_RESUBMISSION (>80%), MEDIUM_RESUBMISSION (50-80%), LOW_RESUBMISSION (<50%), NO_RESUBMISSION
- **Resubmission Speed Category**: FAST (≤7 days), NORMAL (7-30 days), SLOW (>30 days), PENDING
- **Activity Level**: ACTIVE, PENDING, NO_ACTIVITY, UNKNOWN
- **Success Status**: SUCCESSFUL, IN_PROGRESS, FAILED, NO_RESUBMISSION, UNKNOWN

### **Key Metrics**
- Days to resubmission
- Days between remittance and resubmission
- Resubmission success rates
- Processing efficiency
- Improvement opportunities

### **Usage Examples**
```sql
-- Get resubmission activity for specific provider
SELECT * FROM claims.v_remittances_resubmission_activity 
WHERE provider_npi = '1234567890' 
ORDER BY remittance_date DESC;

-- Get resubmission efficiency analysis
SELECT * FROM claims.v_resubmission_efficiency_analysis 
ORDER BY avg_days_between_remittance_resubmission ASC;

-- Get high-priority improvement opportunities
SELECT * FROM claims.v_resubmission_improvement_opportunities 
WHERE improvement_priority IN ('PRIORITY_1', 'PRIORITY_2')
    AND expected_improvement_impact > 1000
ORDER BY improvement_priority, expected_improvement_impact DESC;
```

---

## Report 9: Claim Details with Activity Report (Comprehensive)

### **File**: `claim_details_with_activity_final.sql`

### **Purpose**
The most comprehensive implementation of the claim details report with all required fields and advanced filtering capabilities.

### **Key Features**
- **Main View**: `v_claim_details_with_activity` (comprehensive)
- **Filtering Function**: `get_claim_details_with_activity()` (complex filtering)
- **Summary Function**: `get_claim_details_summary()` (dashboard metrics)
- **Filter Options**: `get_claim_details_filter_options()` (UI support)

### **Core Data Points**
- **Submission & Remittance Tracking**: Complete lifecycle tracking
- **Claim Financials**: Gross, patient share, net, payment amounts
- **Denial & Resubmission Info**: Codes, comments, types, effectiveness
- **Patient & Payer Info**: Complete identification and contact details
- **Encounter & Activity Details**: Facility, type, dates, codes, clinicians
- **Calculated Metrics**: Collection rates, denial rates, turnaround times

### **Advanced Features**
- **Complex Filtering**: 20+ filter parameters
- **Pagination Support**: Limit and offset parameters
- **Ordering Options**: Multiple sort criteria
- **Performance Optimized**: Comprehensive indexing strategy
- **Business Intelligence**: Advanced calculated fields

### **Key Metrics**
- Net collection rate
- Denial rate
- Turnaround time (days)
- Resubmission effectiveness
- Payment status categorization

### **Usage Examples**
```sql
-- Get comprehensive claim details with filtering
SELECT * FROM claims.get_claim_details_with_activity(
    'FAC001', -- facility_code
    NULL, -- receiver_id
    'DHA', -- payer_code
    NULL, -- clinician
    NULL, -- claim_id
    NULL, -- patient_id
    '99213', -- cpt_code
    NULL, -- claim_status
    'Fully Paid', -- payment_status
    'OUTPATIENT', -- encounter_type
    NULL, -- resub_type
    NULL, -- denial_code
    NULL, -- member_id
    NULL, -- payer_ref_id
    NULL, -- provider_ref_id
    NULL, -- facility_ref_id
    NULL, -- clinician_ref_id
    NULL, -- activity_code_ref_id
    NULL, -- denial_code_ref_id
    CURRENT_DATE - INTERVAL '90 days', -- from_date
    CURRENT_DATE, -- to_date
    500, -- limit
    0 -- offset
);

-- Get summary metrics for dashboard
SELECT * FROM claims.get_claim_details_summary(
    'FAC001', -- facility_code
    NULL, -- receiver_id
    NULL, -- payer_code
    CURRENT_DATE - INTERVAL '30 days', -- from_date
    CURRENT_DATE -- to_date
);
```

---

## Common Features Across All Reports

### **Performance Optimizations**
- **Comprehensive Indexing**: Each report includes performance-optimized indexes
- **Composite Indexes**: Common query pattern optimization
- **Partial Indexes**: Active record filtering
- **Date Range Indexes**: Time-based query optimization

### **Security Features**
- **Access Control**: `check_user_facility_access()` function
- **Scoped Views**: User-specific data filtering
- **Parameter Validation**: Input sanitization and validation

### **Business Intelligence**
- **Calculated Fields**: Advanced business logic
- **Trend Analysis**: Month-over-month comparisons
- **Risk Assessment**: Categorization and prioritization
- **Performance Metrics**: Success rates, efficiency measures

### **Data Quality**
- **NULL Handling**: Comprehensive COALESCE usage
- **Data Validation**: Constraint checking and validation
- **Error Handling**: Graceful failure management

### **Documentation**
- **Comprehensive Comments**: Table and column documentation
- **Usage Examples**: Practical query examples
- **Business Context**: Purpose and application descriptions

---

## Implementation Notes

### **Schema Alignment**
All reports have been corrected to align with the actual database schema from `claims_unified_ddl_fresh.sql`:
- Fixed column name mismatches (e.g., `start_at` vs `start`)
- Corrected join conditions
- Updated table references
- Aligned data types

### **Performance Considerations**
- Reports are optimized for 3+ years of data
- Indexes are designed for common query patterns
- Views use efficient join strategies
- Pagination support for large datasets

### **Maintenance**
- All reports use `CREATE OR REPLACE` for easy updates
- Comprehensive error handling
- Safe re-runnable scripts
- Version tracking and documentation

---

## Conclusion

This comprehensive reporting system provides healthcare organizations with detailed insights into their claims processing operations. Each report serves specific business needs while maintaining consistency in design, performance, and usability. The reports are production-ready and optimized for real-world healthcare data volumes and query patterns.

The system supports:
- **Operational Management**: Daily operations and monitoring
- **Financial Analysis**: Revenue and payment tracking
- **Performance Monitoring**: Provider and payer performance
- **Quality Improvement**: Denial and rejection analysis
- **Strategic Planning**: Trend analysis and forecasting

All reports are designed to work together as a cohesive business intelligence platform for healthcare claims management.