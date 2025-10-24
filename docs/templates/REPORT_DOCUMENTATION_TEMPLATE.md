# Report Documentation Template

This document provides a standardized template for documenting reports in the Claims Backend system, ensuring consistency and completeness across all report documentation.

## Overview

This template covers:
- **Report Description**: Purpose, business value, and use cases
- **Technical Details**: Implementation, data sources, and performance
- **API Documentation**: Endpoints, parameters, and responses
- **Environment Behavior**: Local vs production differences
- **Testing Procedures**: Validation and testing steps

---

## Report Documentation Template

### 1. Report Overview

**Report Name**: [Report Name]
**Report Type**: [Report Type Enum]
**Purpose**: [Brief description of report purpose]
**Business Value**: [Business value and use cases]
**Target Users**: [Who uses this report]

### 2. Report Description

**Purpose**:
[Detailed description of what the report does and why it's needed]

**Business Use Cases**:
- [Use case 1]
- [Use case 2]
- [Use case 3]

**Key Features**:
- [Feature 1]
- [Feature 2]
- [Feature 3]

### 3. Technical Implementation

**Service Class**: `[Service Class Name]`
**Controller Method**: `[Controller Method Name]`
**SQL Function**: `[SQL Function Name]`
**Materialized View**: `[Materialized View Name]`

**Data Sources**:
- [Primary data source]
- [Secondary data sources]
- [Reference data sources]

**Key Tables**:
- `[Table 1]`: [Description]
- `[Table 2]`: [Description]
- `[Table 3]`: [Description]

### 4. API Documentation

**Endpoint**: `POST /api/reports/data/[report-endpoint]`
**Authentication**: Required
**Authorization**: [Required roles]

**Request DTO**: `[Request DTO Class]`
**Response DTO**: `[Response DTO Class]`

**Request Parameters**:
| Parameter | Type | Required | Description | Validation |
|-----------|------|----------|-------------|------------|
| `[param1]` | `[Type]` | [Yes/No] | [Description] | [Validation rules] |
| `[param2]` | `[Type]` | [Yes/No] | [Description] | [Validation rules] |

**Response Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `[field1]` | `[Type]` | [Description] |
| `[field2]` | `[Type]` | [Description] |

**Example Request**:
```json
{
  "reportType": "[REPORT_TYPE]",
  "[param1]": "[value1]",
  "[param2]": "[value2]"
}
```

**Example Response**:
```json
{
  "success": true,
  "data": {
    "reportType": "[REPORT_TYPE]",
    "records": [
      {
        "[field1]": "[value1]",
        "[field2]": "[value2]"
      }
    ],
    "pagination": {
      "page": 0,
      "size": 50,
      "totalRecords": 1000,
      "totalPages": 20
    }
  }
}
```

### 5. Environment-Specific Behavior

**Local Development Environment**:
- **Materialized Views**: Disabled
- **Performance**: Uses base queries
- **Security**: Relaxed
- **Logging**: Debug level
- **Response Time**: [Expected response time]

**Staging Environment**:
- **Materialized Views**: Enabled
- **Performance**: Uses materialized views
- **Security**: Production-like
- **Logging**: Info level
- **Response Time**: [Expected response time]

**Production Environment**:
- **Materialized Views**: Enabled
- **Performance**: Optimized with materialized views
- **Security**: Full enforcement
- **Logging**: Warn level
- **Response Time**: [Expected response time]

### 6. Performance Characteristics

**Base Query Performance**:
- **Response Time**: [Time range]
- **Memory Usage**: [Memory range]
- **CPU Usage**: [CPU range]
- **Database Load**: [Load level]

**Materialized View Performance**:
- **Response Time**: [Time range]
- **Memory Usage**: [Memory range]
- **CPU Usage**: [CPU range]
- **Database Load**: [Load level]
- **Refresh Time**: [Refresh time]

**Performance Optimization**:
- [Optimization 1]
- [Optimization 2]
- [Optimization 3]

### 7. Security Considerations

**Access Control**:
- **Required Roles**: [List of roles]
- **Facility Access**: [Facility-based access rules]
- **Data Filtering**: [Automatic data filtering]

**Multi-Tenancy**:
- **Data Isolation**: [Facility-based isolation]
- **Cross-Facility Access**: [Access rules]
- **Audit Logging**: [Audit requirements]

### 8. Testing Procedures

**Unit Testing**:
- [Test case 1]
- [Test case 2]
- [Test case 3]

**Integration Testing**:
- [Test case 1]
- [Test case 2]
- [Test case 3]

**Performance Testing**:
- [Test case 1]
- [Test case 2]
- [Test case 3]

**Security Testing**:
- [Test case 1]
- [Test case 2]
- [Test case 3]

### 9. Troubleshooting

**Common Issues**:
- **Issue 1**: [Description and resolution]
- **Issue 2**: [Description and resolution]
- **Issue 3**: [Description and resolution]

**Debugging Commands**:
```bash
# [Debug command 1]
# [Debug command 2]
# [Debug command 3]
```

### 10. Related Documentation

- [Link to related documentation 1]
- [Link to related documentation 2]
- [Link to related documentation 3]

---

## Template Usage Instructions

### 1. Fill in Report-Specific Information

Replace all bracketed placeholders with actual report information:
- `[Report Name]` → Actual report name
- `[Report Type]` → Actual report type enum
- `[Service Class Name]` → Actual service class name
- `[Controller Method Name]` → Actual controller method name
- `[SQL Function Name]` → Actual SQL function name
- `[Materialized View Name]` → Actual materialized view name

### 2. Customize Sections

Add or remove sections as needed for specific reports:
- Add additional technical details
- Include specific business requirements
- Add environment-specific configurations
- Include custom testing procedures

### 3. Update Cross-References

Ensure all cross-references are updated:
- Link to related reports
- Reference common patterns
- Include relevant documentation links
- Update API references

### 4. Review and Validate

Before finalizing documentation:
- Review all technical details
- Validate API examples
- Check environment-specific behavior
- Verify testing procedures

---

## Example Usage

### Example: Balance Amount Report

**Report Name**: Balance Amount Report
**Report Type**: BALANCE_AMOUNT_REPORT
**Purpose**: Track outstanding balance amounts by facility and payer
**Business Value**: Financial reporting and aging analysis
**Target Users**: Facility administrators, financial analysts

**Purpose**:
The Balance Amount Report provides a comprehensive view of outstanding balance amounts for claims, organized by facility and payer. It helps track aging of outstanding amounts and supports financial reporting requirements.

**Business Use Cases**:
- Track outstanding balance amounts by facility
- Analyze aging of outstanding amounts
- Generate financial reports for management
- Monitor payer performance

**Key Features**:
- Facility-based balance aggregation
- Payer-wise balance breakdown
- Aging analysis with date ranges
- Export functionality for financial reporting

**Service Class**: `BalanceAmountReportService`
**Controller Method**: `getBalanceAmountReport`
**SQL Function**: `get_balance_amount_to_be_received`
**Materialized View**: `mv_balance_amount_summary`

**Data Sources**:
- Primary: `claims.claim` table
- Secondary: `claims.claim_key` table
- Reference: `claims_ref.facility`, `claims_ref.payer`

**Key Tables**:
- `claims.claim`: Core claim data with amounts
- `claims.claim_key`: Claim key information
- `claims_ref.facility`: Facility reference data
- `claims_ref.payer`: Payer reference data

**Endpoint**: `POST /api/reports/data/balance-amount`
**Authentication**: Required
**Authorization**: SUPER_ADMIN, FACILITY_ADMIN, STAFF

**Request DTO**: `BalanceAmountRequest`
**Response DTO**: `ReportResponse`

**Request Parameters**:
| Parameter | Type | Required | Description | Validation |
|-----------|------|----------|-------------|------------|
| `reportType` | `ReportType` | Yes | Report type identifier | Must be BALANCE_AMOUNT_REPORT |
| `facilityCodes` | `List<String>` | No | Facility codes to filter | Max 100 items |
| `payerCodes` | `List<String>` | No | Payer codes to filter | Max 100 items |
| `fromDate` | `LocalDateTime` | No | Start date for filtering | Past or present |
| `toDate` | `LocalDateTime` | No | End date for filtering | Future or present |

**Response Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `claimKeyId` | `Long` | Unique claim key identifier |
| `facilityId` | `String` | Facility identifier |
| `payerId` | `String` | Payer identifier |
| `initialNet` | `BigDecimal` | Initial net amount |
| `totalPayment` | `BigDecimal` | Total payment amount |
| `pendingAmount` | `BigDecimal` | Pending amount |
| `agingDays` | `Integer` | Days since submission |

**Example Request**:
```json
{
  "reportType": "BALANCE_AMOUNT_REPORT",
  "facilityCodes": ["FAC001"],
  "payerCodes": ["DHA"],
  "fromDate": "2025-01-01T00:00:00",
  "toDate": "2025-12-31T23:59:59"
}
```

**Example Response**:
```json
{
  "success": true,
  "data": {
    "reportType": "BALANCE_AMOUNT_REPORT",
    "records": [
      {
        "claimKeyId": 12345,
        "facilityId": "FAC001",
        "payerId": "DHA",
        "initialNet": 1000.00,
        "totalPayment": 500.00,
        "pendingAmount": 500.00,
        "agingDays": 30
      }
    ],
    "pagination": {
      "page": 0,
      "size": 50,
      "totalRecords": 1000,
      "totalPages": 20
    }
  }
}
```

**Local Development Environment**:
- **Materialized Views**: Disabled
- **Performance**: Uses base queries
- **Security**: Relaxed
- **Logging**: Debug level
- **Response Time**: 5-10 seconds

**Staging Environment**:
- **Materialized Views**: Enabled
- **Performance**: Uses materialized views
- **Security**: Production-like
- **Logging**: Info level
- **Response Time**: 1-2 seconds

**Production Environment**:
- **Materialized Views**: Enabled
- **Performance**: Optimized with materialized views
- **Security**: Full enforcement
- **Logging**: Warn level
- **Response Time**: <500ms

**Base Query Performance**:
- **Response Time**: 5-10 seconds
- **Memory Usage**: 100-200MB
- **CPU Usage**: 50-80%
- **Database Load**: High

**Materialized View Performance**:
- **Response Time**: <500ms
- **Memory Usage**: 50-100MB
- **CPU Usage**: 20-40%
- **Database Load**: Low
- **Refresh Time**: 2-5 minutes

**Performance Optimization**:
- Materialized view pre-computation
- Index optimization on key columns
- Connection pooling for database access
- Caching of reference data

**Access Control**:
- **Required Roles**: SUPER_ADMIN, FACILITY_ADMIN, STAFF
- **Facility Access**: Automatic facility filtering for non-SUPER_ADMIN users
- **Data Filtering**: Facility-based data isolation

**Multi-Tenancy**:
- **Data Isolation**: Facility-based isolation
- **Cross-Facility Access**: Only SUPER_ADMIN can access multiple facilities
- **Audit Logging**: All access events logged

**Unit Testing**:
- Test report data retrieval with valid parameters
- Test facility filtering for different user roles
- Test materialized view usage based on toggles

**Integration Testing**:
- Test complete API endpoint functionality
- Test authentication and authorization
- Test error handling and validation

**Performance Testing**:
- Test response times under load
- Test materialized view refresh performance
- Test database query optimization

**Security Testing**:
- Test role-based access control
- Test facility-based data isolation
- Test cross-facility access prevention

**Common Issues**:
- **Issue 1**: No data returned - Check facility access and data availability
- **Issue 2**: Slow response times - Verify materialized view status and refresh
- **Issue 3**: Access denied - Verify user roles and facility assignments

**Debugging Commands**:
```bash
# Check materialized view status
SELECT matviewname, ispopulated FROM pg_matviews WHERE matviewname = 'mv_balance_amount_summary';

# Test SQL function
SELECT * FROM claims.get_balance_amount_to_be_received(false, 'user@company.com', ARRAY['FAC001'], NULL, NULL, NULL, 0, 10);

# Check toggle status
SELECT toggle_name, is_enabled FROM claims.toggle WHERE toggle_name LIKE '%mv%';
```

**Related Documentation**:
- [Report Catalog](REPORT_CATALOG.md)
- [API Reference](REPORT_API_REFERENCE.md)
- [Materialized Views Guide](MATERIALIZED_VIEWS_GUIDE.md)
- [Security Matrix](SECURITY_MATRIX.md)

---

## Best Practices

### Documentation Best Practices

1. **Consistency**: Use consistent formatting and structure
2. **Completeness**: Include all required sections
3. **Accuracy**: Ensure all technical details are accurate
4. **Clarity**: Use clear, concise language
5. **Examples**: Provide practical examples

### Environment-Specific Best Practices

**Local Development**:
- Include debug information
- Document relaxed security settings
- Note performance characteristics
- Include troubleshooting steps

**Staging Environment**:
- Document production-like behavior
- Include performance testing results
- Note security considerations
- Include validation procedures

**Production Environment**:
- Document optimized performance
- Include security requirements
- Note monitoring considerations
- Include rollback procedures

---

## Related Documentation

- [API Endpoint Template](API_ENDPOINT_TEMPLATE.md) - API documentation template
- [Report Catalog](REPORT_CATALOG.md) - Catalog of all reports
- [API Reference](REPORT_API_REFERENCE.md) - API documentation
- [Materialized Views Guide](MATERIALIZED_VIEWS_GUIDE.md) - MV implementation guide
- [Security Matrix](SECURITY_MATRIX.md) - Security implementation details
