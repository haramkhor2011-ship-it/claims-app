# Rejected Claims Report Documentation
## Complete Implementation Guide - 2025-09-24

---

## 📋 Report Overview

### Basic Information
- **Report Name**: Rejected Claims Report
- **Business Purpose**: Comprehensive analysis and tracking of rejected healthcare claims to identify patterns, improve claim processing efficiency, and reduce denial rates
- **Target Audience**: Healthcare administrators, billing managers, quality assurance teams, and payer relations staff
- **Frequency**: Daily, weekly, monthly, or on-demand
- **Created By**: Claims Processing System Team
- **Created Date**: 2025-09-24
- **Last Updated**: 2025-09-24
- **Version**: 1.0

### Report Description
The Rejected Claims Report provides three complementary views for comprehensive analysis of rejected healthcare claims. It enables healthcare organizations to identify denial patterns, track rejection rates by facility and payer, analyze denial reasons, and monitor the effectiveness of resubmission efforts. The report supports both summary-level analysis for management reporting and detailed claim-level analysis for operational improvements.

---

## 🏗️ Technical Architecture

### Database Components
| Component Type | Name | Purpose |
|----------------|------|---------|
| Base View | `claims.v_rejected_claims_base` | Core data aggregation with comprehensive rejection analysis |
| Summary View | `claims.v_rejected_claims_summary` | Aggregated data for summary-level reporting |
| Tab View A | `claims.v_rejected_claims_tab_a` | Rejected Claims with expandable sub-data |
| Tab View B | `claims.v_rejected_claims_tab_b` | Receiver and Payer wise analysis |
| Tab View C | `claims.v_rejected_claims_tab_c` | Claim wise detailed view |
| API Function A | `claims.get_rejected_claims_tab_a()` | Parameterized function for Tab A |
| API Function B | `claims.get_rejected_claims_tab_b()` | Parameterized function for Tab B |
| API Function C | `claims.get_rejected_claims_tab_c()` | Parameterized function for Tab C |

### Data Sources
| Source Table | Schema | Purpose | Key Fields |
|--------------|--------|---------|------------|
| `claim_key` | `claims` | Canonical claim identifier | `id`, `claim_id` |
| `claim` | `claims` | Core claim data | `payer_id`, `provider_id`, `net`, `tx_at` |
| `encounter` | `claims` | Encounter information | `facility_id`, `start_at`, `patient_id` |
| `remittance_claim` | `claims` | Remittance claim data | `id_payer`, `denial_code`, `date_settlement` |
| `remittance_activity` | `claims` | Activity-level remittance | `payment_amount`, `denial_code`, `net` |
| `ingestion_file` | `claims` | File metadata | `sender_id`, `receiver_id`, `transaction_date` |
| `facility` | `claims_ref` | Facility reference data | `facility_code`, `name` |
| `payer` | `claims_ref` | Payer reference data | `payer_code`, `name` |
| `clinician` | `claims_ref` | Clinician reference data | `clinician_code`, `name` |
| `denial_code` | `claims_ref` | Denial code reference | `code`, `description` |

### Relationships
```
claim_key (1) ←→ (1) claim ←→ (1) encounter
claim_key (1) ←→ (0..n) remittance_claim ←→ (0..n) remittance_activity
claim ←→ (1) submission ←→ (1) ingestion_file
encounter.facility_id ←→ facility.facility_code
claim.payer_id ←→ payer.payer_code
remittance_activity.clinician ←→ clinician.clinician_code
remittance_activity.denial_code ←→ denial_code.code
```

---

## 📊 Report Structure

### Tabs/Sections
1. **Tab A - Rejected Claims**: Summary-level view with expandable sub-data showing facility, payer, and claim-level rejection information
2. **Tab B - Receiver and Payer wise**: Analysis by receiver and payer combinations with aggregated metrics and performance indicators
3. **Tab C - Claim wise**: Individual claim details with comprehensive rejection information, denial codes, and audit trails

### Key Metrics
| Metric Name | Description | Calculation | Business Impact |
|-------------|-------------|-------------|-----------------|
| Rejection Rate (Remittance) | Percentage of rejected claims among remitted claims | `(rejected_claims / remitted_claims) * 100` | Measures payer-specific rejection patterns |
| Rejection Rate (Submission) | Percentage of rejected claims among all submissions | `(rejected_claims / total_claims) * 100` | Overall rejection performance |
| Average Claim Value | Mean claim amount for rejected claims | `SUM(claim_amount) / COUNT(claims)` | Financial impact analysis |
| Collection Rate | Percentage of billed amount that was collected | `(remitted_amount / billed_amount) * 100` | Revenue recovery efficiency |
| Aging Days | Days between service date and current date | `CURRENT_DATE - service_date` | Identifies delayed processing |

---

## 🔍 Field Mappings

### Business Fields to Database Fields
| Business Field | Database Field | Source Table | Notes |
|----------------|----------------|--------------|-------|
| FacilityGroup | `facility_group_id` | `encounter.facility_id` or `claim.provider_id` | Uses facility_id preferred, provider_id fallback |
| HealthAuthority | `sender_id`/`receiver_id` | `ingestion_file` | Submission sender, remittance receiver |
| FacilityID | `facility_id` | `encounter` | Direct mapping to encounter facility |
| Facility_Name | `name` | `claims_ref.facility` | Lookup via facility_code |
| Receiver_Name | `name` | `claims_ref.payer` | Lookup via receiver_id |
| Payer_Name | `name` | `claims_ref.payer` | Lookup via payer_id |
| Clinician_Name | `name` | `claims_ref.clinician` | Lookup via clinician_code |
| RejectionType | `rejection_type` | Calculated | Derived from payment_amount vs net |
| DenialCode | `denial_code` | `remittance_activity` | Direct mapping from remittance |
| DenialType | `description` | `claims_ref.denial_code` | Lookup via denial_code |
| ClaimAmt | `initial_net_amount` | `claim` | Billed amount from submission |
| RemittedAmt | `payment_amount` | `remittance_activity` | Paid amount from remittance |
| RejectedAmt | `rejected_amount` | Calculated | `net - payment_amount` for rejected portions |

### Calculated Fields
| Field Name | Calculation | Business Logic |
|------------|-------------|----------------|
| RejectionType | `CASE WHEN payment_amount = 0 THEN 'Fully Rejected' WHEN payment_amount < net THEN 'Partially Rejected' WHEN payment_amount = net THEN 'Fully Paid' ELSE 'Unknown Status' END` | Determines rejection status based on payment amount |
| RejectedAmount | `CASE WHEN payment_amount = 0 THEN net WHEN payment_amount < net THEN net - payment_amount ELSE 0 END` | Calculates the rejected portion of the claim |
| RejectionPercentage | `(rejected_claims / total_claims) * 100` | Percentage of claims that were rejected |
| AgeingDays | `CURRENT_DATE - DATE(service_date)` | Days since service was provided |
| CollectionRate | `(remitted_amount / billed_amount) * 100` | Percentage of billed amount collected |

---

## 🧮 Business Logic

### Key Calculations
1. **Rejection Type Determination**:
   ```sql
   CASE 
     WHEN ra.payment_amount = 0 THEN 'Fully Rejected'
     WHEN ra.payment_amount < ra.net THEN 'Partially Rejected'
     WHEN ra.payment_amount = ra.net THEN 'Fully Paid'
     ELSE 'Unknown Status'
   END AS rejection_type
   ```
   - **Purpose**: Categorizes claims based on payment status
   - **Business Rules**: Zero payment = fully rejected, partial payment = partially rejected, full payment = fully paid

2. **Rejection Amount Calculation**:
   ```sql
   CASE 
     WHEN ra.payment_amount = 0 THEN ra.net
     WHEN ra.payment_amount < ra.net THEN ra.net - ra.payment_amount
     ELSE 0
   END AS rejected_amount
   ```
   - **Purpose**: Calculates the financial impact of rejections
   - **Business Rules**: For fully rejected claims, entire amount is rejected; for partial rejections, difference is rejected

3. **Rejection Percentage Calculation**:
   ```sql
   CASE 
     WHEN COUNT(DISTINCT CASE WHEN rcb.activity_payment_amount > 0 THEN rcb.claim_key_id END) > 0 
     THEN ROUND(
       (COUNT(DISTINCT CASE WHEN rcb.rejected_amount > 0 THEN rcb.claim_key_id END)::NUMERIC / 
        COUNT(DISTINCT CASE WHEN rcb.activity_payment_amount > 0 THEN rcb.claim_key_id END)) * 100, 2
     )
     ELSE 0 
   END AS rejected_percentage_based_on_remittance
   ```
   - **Purpose**: Calculates rejection rate as percentage of remitted claims
   - **Business Rules**: Only considers claims that have been processed (remitted)

### Filtering Logic
| Filter | Logic | Purpose |
|--------|-------|---------|
| Rejection Filter | `WHERE (ra.denial_code IS NOT NULL OR (ra.payment_amount IS NOT NULL AND ra.payment_amount < ra.net) OR (ra.payment_amount IS NOT NULL AND ra.payment_amount = 0))` | Only includes claims with some form of rejection |
| Date Range Filter | `WHERE activity_start_date >= p_date_from AND activity_start_date <= p_date_to` | Limits data to specified date range |
| Facility Filter | `WHERE facility_id = ANY(p_facility_codes)` | Filters by specific facilities |
| Payer Filter | `WHERE payer_id = ANY(p_payer_codes)` | Filters by specific payers |

### Status Mappings
| Status Code | Status Text | Description |
|-------------|-------------|-------------|
| 1 | Submitted | Claim has been submitted but not yet processed |
| 2 | Resubmitted | Claim has been resubmitted after initial rejection |
| 3 | Remitted | Claim has been processed and remittance received |
| 4 | Partially Paid | Claim has been partially paid |
| 5 | Fully Rejected | Claim has been completely rejected |
| 6 | Partially Rejected | Claim has been partially rejected |

---

## 🚀 Usage Instructions

### API Function Parameters
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `p_user_id` | TEXT | Yes | - | User ID for access control |
| `p_facility_codes` | TEXT[] | No | NULL | Filter by facility codes |
| `p_payer_codes` | TEXT[] | No | NULL | Filter by payer codes |
| `p_receiver_ids` | TEXT[] | No | NULL | Filter by receiver IDs |
| `p_date_from` | TIMESTAMPTZ | No | 3 years ago | Start date filter |
| `p_date_to` | TIMESTAMPTZ | No | Now | End date filter |
| `p_year` | INTEGER | No | NULL | Filter by specific year |
| `p_month` | INTEGER | No | NULL | Filter by specific month |
| `p_limit` | INTEGER | No | 100 | Maximum records to return |
| `p_offset` | INTEGER | No | 0 | Records to skip |
| `p_order_by` | TEXT | No | 'facility_name' | Field to sort by |
| `p_order_direction` | TEXT | No | 'ASC' | Sort direction (ASC/DESC) |

### Example Usage
```sql
-- Basic usage for Tab A
SELECT * FROM claims.get_rejected_claims_tab_a(
    'user123',                    -- p_user_id
    ARRAY['FACILITY-001'],        -- p_facility_codes
    NULL,                         -- p_payer_codes
    NULL,                         -- p_receiver_ids
    '2024-01-01'::timestamptz,   -- p_date_from
    '2024-12-31'::timestamptz,   -- p_date_to
    2024,                         -- p_year
    NULL,                         -- p_month
    100,                          -- p_limit
    0,                            -- p_offset
    'facility_name',              -- p_order_by
    'ASC'                         -- p_order_direction
);

-- Tab B - Receiver and Payer analysis
SELECT * FROM claims.get_rejected_claims_tab_b(
    'user123',
    NULL,
    ARRAY['PAYER-001', 'PAYER-002'],
    NULL,
    '2024-01-01'::timestamptz,
    '2024-12-31'::timestamptz,
    NULL,
    NULL,
    50,
    0,
    'rejected_amt',
    'DESC'
);

-- Tab C - Detailed claim analysis
SELECT * FROM claims.get_rejected_claims_tab_c(
    'user123',
    NULL,
    NULL,
    NULL,
    '2024-01-01'::timestamptz,
    '2024-12-31'::timestamptz,
    2024,
    6,  -- June
    200,
    0,
    'service_date',
    'DESC'
);
```

### Direct View Access
```sql
-- Access specific tab directly
SELECT * FROM claims.v_rejected_claims_tab_a 
WHERE facility_name = 'Dubai London Clinic'
  AND claim_year = 2024
ORDER BY rejected_amt DESC
LIMIT 100;

-- Access base view for custom analysis
SELECT 
    facility_name,
    payer_name,
    COUNT(*) as rejected_claims,
    SUM(rejected_amount) as total_rejected_amount
FROM claims.v_rejected_claims_base
WHERE encounter_start >= '2024-01-01'
GROUP BY facility_name, payer_name
ORDER BY total_rejected_amount DESC;
```

---

## 🔧 Performance Considerations

### Indexes
| Index Name | Table | Columns | Purpose |
|------------|-------|---------|---------|
| `idx_remittance_activity_denial_code` | `remittance_activity` | `denial_code` | Fast lookup of denied activities |
| `idx_remittance_activity_payment_amount` | `remittance_activity` | `payment_amount` | Filtering by payment status |
| `idx_remittance_activity_rejection` | `remittance_activity` | `remittance_claim_id` | Rejection analysis |
| `idx_encounter_facility_id` | `encounter` | `facility_id` | Facility-based filtering |
| `idx_claim_payer_id` | `claim` | `payer_id` | Payer-based filtering |
| `idx_ingestion_file_receiver_id` | `ingestion_file` | `receiver_id` | Receiver-based filtering |
| `idx_encounter_start_at` | `encounter` | `start_at` | Date-based filtering |
| `idx_remittance_claim_date_settlement` | `remittance_claim` | `date_settlement` | Settlement date filtering |

### Performance Tips
1. **Date Filtering**: Always use date filters to limit data volume
2. **Facility Filtering**: Use facility codes when possible for better performance
3. **Pagination**: Use LIMIT and OFFSET for large result sets
4. **Index Usage**: Monitor index usage with `pg_stat_user_indexes`
5. **Denial Code Filtering**: Use specific denial codes when analyzing rejection reasons

### Expected Performance
- **Small Dataset** (< 1K records): < 1 second
- **Medium Dataset** (1K-10K records): 1-5 seconds
- **Large Dataset** (10K-100K records): 5-15 seconds
- **Very Large Dataset** (> 100K records): 15-30 seconds

---

## 🧪 Testing & Validation

### Test Queries
```sql
-- Basic health check
SELECT COUNT(*) FROM claims.v_rejected_claims_base;
SELECT COUNT(*) FROM claims.v_rejected_claims_tab_a;
SELECT COUNT(*) FROM claims.v_rejected_claims_tab_b;
SELECT COUNT(*) FROM claims.v_rejected_claims_tab_c;

-- Data quality check
SELECT 
    COUNT(*) as total_records,
    COUNT(CASE WHEN rejection_type IS NULL THEN 1 END) as null_rejection_type,
    COUNT(CASE WHEN rejected_amount < 0 THEN 1 END) as negative_rejected_amount
FROM claims.v_rejected_claims_base;

-- Business logic validation
SELECT 
    rejection_type,
    COUNT(*) as claim_count,
    SUM(rejected_amount) as total_rejected_amount
FROM claims.v_rejected_claims_base
GROUP BY rejection_type
ORDER BY total_rejected_amount DESC;

-- Cross-validation with source data
SELECT 
    'Base View' as source,
    COUNT(*) as record_count
FROM claims.v_rejected_claims_base
UNION ALL
SELECT 
    'Tab A' as source,
    COUNT(*) as record_count
FROM claims.v_rejected_claims_tab_a
UNION ALL
SELECT 
    'Tab B' as source,
    COUNT(*) as record_count
FROM claims.v_rejected_claims_tab_b
UNION ALL
SELECT 
    'Tab C' as source,
    COUNT(*) as record_count
FROM claims.v_rejected_claims_tab_c;
```

### Validation Checklist
- [x] All views created successfully
- [x] All functions created successfully
- [x] Sample data returns expected results
- [x] Business logic calculations are correct
- [x] No NULL values in critical fields
- [x] Performance is acceptable
- [x] Indexes are being used effectively
- [x] API function handles all parameter combinations
- [x] Tab logic is correct (no overlaps, proper filtering)
- [x] Cross-validation with source data passes

---

## 📈 Monitoring & Maintenance

### Regular Checks
| Frequency | Check | Query |
|-----------|-------|-------|
| Daily | Data freshness | `SELECT MAX(encounter_start) FROM claims.v_rejected_claims_base` |
| Weekly | Data quality | `SELECT COUNT(*) FROM claims.v_rejected_claims_base WHERE rejection_type IS NULL` |
| Monthly | Performance | `SELECT * FROM pg_stat_user_indexes WHERE indexname LIKE '%rejected%'` |
| Quarterly | Business logic | `SELECT rejection_type, COUNT(*) FROM claims.v_rejected_claims_base GROUP BY rejection_type` |

### Performance Monitoring
```sql
-- Check query performance
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows
FROM pg_stat_statements 
WHERE query LIKE '%rejected_claims%'
ORDER BY mean_time DESC;

-- Check index usage
SELECT 
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes 
WHERE indexname LIKE '%rejected%'
ORDER BY idx_scan DESC;
```

### Maintenance Tasks
1. **Weekly**: Run validation queries
2. **Monthly**: Review performance metrics
3. **Quarterly**: Update documentation
4. **Annually**: Review business logic

---

## 🚨 Troubleshooting

### Common Issues
| Issue | Symptoms | Solution |
|-------|----------|----------|
| Slow Performance | Queries taking > 30 seconds | Check indexes, add date filters |
| Missing Data | NULL values in expected fields | Check joins, verify source data |
| Incorrect Calculations | Business logic errors | Review calculation formulas |
| Access Denied | Permission errors | Check user grants and facility access |

### Error Messages
| Error | Cause | Solution |
|-------|-------|----------|
| `relation "claims.v_rejected_claims_base" does not exist` | View not created | Run the implementation SQL script |
| `permission denied for schema claims` | Insufficient permissions | Grant SELECT permissions to user |
| `function claims.get_rejected_claims_tab_a() does not exist` | Function not created | Run the implementation SQL script |

### Debug Queries
```sql
-- Check for data issues
SELECT 
    rejection_type,
    COUNT(*) as count
FROM claims.v_rejected_claims_base
GROUP BY rejection_type
ORDER BY count DESC;

-- Check join issues
SELECT 
    COUNT(*) as total_records,
    COUNT(facility_name) as facility_records
FROM claims.v_rejected_claims_base;

-- Check denial code distribution
SELECT 
    denial_code,
    denial_type,
    COUNT(*) as count
FROM claims.v_rejected_claims_base
WHERE denial_code IS NOT NULL
GROUP BY denial_code, denial_type
ORDER BY count DESC;
```

---

## 📞 Support Information

### Contacts
- **Database Team**: claims-db-team@company.com
- **Business Analyst**: claims-ba@company.com
- **Development Team**: claims-dev@company.com

### Resources
- **Database Documentation**: [Internal Wiki Link]
- **Business Requirements**: [Requirements Document Link]
- **Change Management**: [Change Management Process Link]

### Change History
| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-09-24 | 1.0 | Initial implementation | Claims Processing Team |

---

## 📋 Appendix

### SQL Code
The complete SQL implementation is available in:
- `src/main/resources/db/rejected_claims_report_implementation.sql`

### Sample Output
```sql
-- Sample output from Tab A
facility_group_id | health_authority | facility_name | claim_year | total_claim | rejected_claim | rejected_amt
FACILITY-001      | DHA              | Dubai London Clinic | 2024 | 150 | 25 | 125000.00
FACILITY-002      | DHA              | City Hospital | 2024 | 200 | 30 | 180000.00

-- Sample output from Tab B
receiver_name | payer_name | total_claim | rejected_claim | rejected_percentage_remittance
DHA           | Insurance Co A | 100 | 15 | 15.00
DHA           | Insurance Co B | 150 | 20 | 13.33

-- Sample output from Tab C
claim_number | payer_name | rejection_type | denied_amount | denial_code | denial_type
CLM-001      | Insurance Co A | Fully Rejected | 5000.00 | MNEC-003 | Not clinically indicated
CLM-002      | Insurance Co B | Partially Rejected | 2500.00 | MNEC-005 | Prior authorization required
```

### Related Reports
- [Balance Amount to be Received Report](balance_amount_report_documentation.md)
- [Claim Details With Activity Report](claim_details_activity_report_documentation.md)
- [Doctor Denial Report](doctor_denial_report_documentation.md)

---

*This documentation should be updated whenever the report structure or business logic changes.*
