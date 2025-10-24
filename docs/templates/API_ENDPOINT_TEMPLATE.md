# API Endpoint Template

This document provides a standardized template for documenting API endpoints in the Claims Backend system, ensuring consistency and completeness across all API documentation.

## Overview

This template covers:
- **Endpoint Information**: URL, method, authentication, and authorization
- **Request Documentation**: Parameters, validation, and examples
- **Response Documentation**: Response format, fields, and examples
- **Error Handling**: Error codes, messages, and resolution
- **Environment Behavior**: Local vs production differences

---

## API Endpoint Documentation Template

### 1. Endpoint Overview

**Endpoint**: `[HTTP_METHOD] /api/[endpoint-path]`
**Authentication**: [Required/Optional]
**Authorization**: [Required roles]
**Rate Limiting**: [Rate limit if applicable]
**Content Type**: [Content type]

### 2. Endpoint Description

**Purpose**:
[Brief description of what the endpoint does]

**Business Use Cases**:
- [Use case 1]
- [Use case 2]
- [Use case 3]

**Key Features**:
- [Feature 1]
- [Feature 2]
- [Feature 3]

### 3. Request Documentation

**Request DTO**: `[Request DTO Class Name]`
**Content Type**: `application/json`
**Content Length**: [Maximum content length]

**Request Parameters**:
| Parameter | Type | Required | Description | Validation | Example |
|-----------|------|----------|-------------|------------|---------|
| `[param1]` | `[Type]` | [Yes/No] | [Description] | [Validation rules] | `[example]` |
| `[param2]` | `[Type]` | [Yes/No] | [Description] | [Validation rules] | `[example]` |

**Request Headers**:
| Header | Required | Description | Example |
|--------|----------|-------------|---------|
| `Authorization` | [Yes/No] | JWT token for authentication | `Bearer <jwt-token>` |
| `Content-Type` | [Yes/No] | Request content type | `application/json` |

**Request Body Example**:
```json
{
  "[param1]": "[value1]",
  "[param2]": "[value2]",
  "[param3]": "[value3]"
}
```

**Request Validation**:
- [Validation rule 1]
- [Validation rule 2]
- [Validation rule 3]

### 4. Response Documentation

**Response DTO**: `[Response DTO Class Name]`
**Content Type**: `application/json`

**Response Fields**:
| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `[field1]` | `[Type]` | [Description] | `[example]` |
| `[field2]` | `[Type]` | [Description] | `[example]` |

**Success Response Example**:
```json
{
  "success": true,
  "data": {
    "[field1]": "[value1]",
    "[field2]": "[value2]"
  },
  "metadata": {
    "timestamp": "2025-01-15T10:30:00Z",
    "executionTimeMs": 245
  }
}
```

**Error Response Example**:
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Error message",
    "details": {
      "field": "fieldName",
      "value": "fieldValue",
      "constraint": "validation constraint"
    },
    "timestamp": "2025-01-15T10:30:00Z"
  }
}
```

### 5. HTTP Status Codes

| Status Code | Description | When Returned |
|-------------|-------------|---------------|
| `200` | OK | Request successful |
| `400` | Bad Request | Invalid request parameters |
| `401` | Unauthorized | Authentication required |
| `403` | Forbidden | Insufficient permissions |
| `404` | Not Found | Resource not found |
| `500` | Internal Server Error | Server error |

### 6. Error Handling

**Common Error Codes**:
| Error Code | HTTP Status | Description | Resolution |
|------------|-------------|-------------|------------|
| `[ERROR_CODE_1]` | `[Status]` | [Description] | [Resolution] |
| `[ERROR_CODE_2]` | `[Status]` | [Description] | [Resolution] |
| `[ERROR_CODE_3]` | `[Status]` | [Description] | [Resolution] |

**Error Response Format**:
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {
      "field": "fieldName",
      "value": "fieldValue",
      "constraint": "validation constraint",
      "timestamp": "2025-01-15T10:30:00Z"
    }
  }
}
```

### 7. Environment-Specific Behavior

**Local Development Environment**:
- **Base URL**: `http://localhost:8080`
- **Authentication**: [Disabled/Simplified/Full]
- **Validation**: [Relaxed/Standard/Strict]
- **Error Details**: [Full/Partial/Minimal]
- **Logging**: [Debug/Info/Warn]

**Staging Environment**:
- **Base URL**: `https://staging-api.company.com`
- **Authentication**: [Required]
- **Validation**: [Standard]
- **Error Details**: [Partial]
- **Logging**: [Info]

**Production Environment**:
- **Base URL**: `https://api.company.com`
- **Authentication**: [Required]
- **Validation**: [Strict]
- **Error Details**: [Minimal]
- **Logging**: [Warn]

### 8. Performance Characteristics

**Response Time**:
- **Local**: [Time range]
- **Staging**: [Time range]
- **Production**: [Time range]

**Throughput**:
- **Local**: [Requests per second]
- **Staging**: [Requests per second]
- **Production**: [Requests per second]

**Resource Usage**:
- **Memory**: [Memory range]
- **CPU**: [CPU range]
- **Database**: [Database load]

### 9. Security Considerations

**Authentication**:
- [Authentication method]
- [Token requirements]
- [Token validation]

**Authorization**:
- [Required roles]
- [Permission checks]
- [Access control]

**Data Protection**:
- [Data encryption]
- [Data masking]
- [Audit logging]

### 10. Testing Procedures

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

### 11. Example Usage

**cURL Example**:
```bash
curl -X POST https://api.company.com/api/[endpoint-path] \
  -H "Authorization: Bearer <jwt-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "[param1]": "[value1]",
    "[param2]": "[value2]"
  }'
```

**JavaScript Example**:
```javascript
const response = await fetch('https://api.company.com/api/[endpoint-path]', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer <jwt-token>',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    param1: 'value1',
    param2: 'value2'
  })
});

const data = await response.json();
console.log(data);
```

**Python Example**:
```python
import requests

url = 'https://api.company.com/api/[endpoint-path]'
headers = {
    'Authorization': 'Bearer <jwt-token>',
    'Content-Type': 'application/json'
}
data = {
    'param1': 'value1',
    'param2': 'value2'
}

response = requests.post(url, headers=headers, json=data)
result = response.json()
print(result)
```

### 12. Troubleshooting

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

**Log Analysis**:
```bash
# Check endpoint logs
tail -f logs/application.log | grep "[endpoint-path]"

# Check authentication logs
tail -f logs/application.log | grep "AUTHENTICATION"

# Check error logs
tail -f logs/application.log | grep "ERROR"
```

### 13. Related Documentation

- [Link to related documentation 1]
- [Link to related documentation 2]
- [Link to related documentation 3]

---

## Template Usage Instructions

### 1. Fill in Endpoint-Specific Information

Replace all bracketed placeholders with actual endpoint information:
- `[HTTP_METHOD]` → Actual HTTP method (GET, POST, PUT, DELETE)
- `[endpoint-path]` → Actual endpoint path
- `[Request DTO Class Name]` → Actual request DTO class
- `[Response DTO Class Name]` → Actual response DTO class
- `[param1]`, `[param2]` → Actual parameter names
- `[field1]`, `[field2]` → Actual response field names

### 2. Customize Sections

Add or remove sections as needed for specific endpoints:
- Add additional request parameters
- Include specific validation rules
- Add environment-specific configurations
- Include custom error handling

### 3. Update Examples

Ensure all examples are accurate and functional:
- Test all example requests
- Verify response examples
- Update code examples
- Validate error examples

### 4. Review and Validate

Before finalizing documentation:
- Review all technical details
- Validate API examples
- Check environment-specific behavior
- Verify testing procedures

---

## Example Usage

### Example: Balance Amount Report Endpoint

**Endpoint**: `POST /api/reports/data/balance-amount`
**Authentication**: Required
**Authorization**: SUPER_ADMIN, FACILITY_ADMIN, STAFF
**Rate Limiting**: 100 requests per minute
**Content Type**: application/json

**Purpose**:
Retrieve balance amount report data with filtering and pagination options.

**Business Use Cases**:
- Track outstanding balance amounts by facility
- Analyze aging of outstanding amounts
- Generate financial reports for management

**Key Features**:
- Facility-based balance aggregation
- Payer-wise balance breakdown
- Aging analysis with date ranges
- Export functionality for financial reporting

**Request DTO**: `BalanceAmountRequest`
**Content Type**: `application/json`
**Content Length**: 10KB

**Request Parameters**:
| Parameter | Type | Required | Description | Validation | Example |
|-----------|------|----------|-------------|------------|---------|
| `reportType` | `ReportType` | Yes | Report type identifier | Must be BALANCE_AMOUNT_REPORT | `"BALANCE_AMOUNT_REPORT"` |
| `facilityCodes` | `List<String>` | No | Facility codes to filter | Max 100 items | `["FAC001", "FAC002"]` |
| `payerCodes` | `List<String>` | No | Payer codes to filter | Max 100 items | `["DHA", "ADNOC"]` |
| `fromDate` | `LocalDateTime` | No | Start date for filtering | Past or present | `"2025-01-01T00:00:00"` |
| `toDate` | `LocalDateTime` | No | End date for filtering | Future or present | `"2025-12-31T23:59:59"` |
| `page` | `Integer` | No | Page number (0-based) | Min 0 | `0` |
| `size` | `Integer` | No | Page size | Min 1, Max 1000 | `50` |

**Request Headers**:
| Header | Required | Description | Example |
|--------|----------|-------------|---------|
| `Authorization` | Yes | JWT token for authentication | `Bearer <jwt-token>` |
| `Content-Type` | Yes | Request content type | `application/json` |

**Request Body Example**:
```json
{
  "reportType": "BALANCE_AMOUNT_REPORT",
  "facilityCodes": ["FAC001"],
  "payerCodes": ["DHA"],
  "fromDate": "2025-01-01T00:00:00",
  "toDate": "2025-12-31T23:59:59",
  "page": 0,
  "size": 50
}
```

**Request Validation**:
- reportType must be BALANCE_AMOUNT_REPORT
- facilityCodes must contain valid facility codes
- payerCodes must contain valid payer codes
- fromDate must be before toDate
- page must be 0 or greater
- size must be between 1 and 1000

**Response DTO**: `ReportResponse`
**Content Type**: `application/json`

**Response Fields**:
| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `success` | `Boolean` | Request success status | `true` |
| `data` | `ReportData` | Report data and metadata | `{...}` |
| `error` | `ErrorResponse` | Error information (if failed) | `null` |

**Success Response Example**:
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
    },
    "metadata": {
      "generatedAt": "2025-01-15T10:30:00Z",
      "executionTimeMs": 245,
      "materializedViewUsed": true
    }
  }
}
```

**Error Response Example**:
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_INVALID_FORMAT",
    "message": "Invalid date format",
    "details": {
      "field": "fromDate",
      "value": "2025-01-01",
      "constraint": "Must be in ISO 8601 format",
      "timestamp": "2025-01-15T10:30:00Z"
    }
  }
}
```

**HTTP Status Codes**:
| Status Code | Description | When Returned |
|-------------|-------------|---------------|
| `200` | OK | Report data retrieved successfully |
| `400` | Bad Request | Invalid request parameters |
| `401` | Unauthorized | Authentication required |
| `403` | Forbidden | Insufficient permissions |
| `500` | Internal Server Error | Report execution failed |

**Common Error Codes**:
| Error Code | HTTP Status | Description | Resolution |
|------------|-------------|-------------|------------|
| `VALIDATION_INVALID_FORMAT` | `400` | Invalid date format | Use ISO 8601 format |
| `AUTH_INVALID_TOKEN` | `401` | Invalid JWT token | Verify token validity |
| `AUTH_INSUFFICIENT_PERMISSIONS` | `403` | Insufficient permissions | Verify user roles |
| `REPORT_EXECUTION_ERROR` | `500` | Report execution failed | Check system logs |

**Local Development Environment**:
- **Base URL**: `http://localhost:8080`
- **Authentication**: Disabled
- **Validation**: Relaxed
- **Error Details**: Full
- **Logging**: Debug

**Staging Environment**:
- **Base URL**: `https://staging-api.company.com`
- **Authentication**: Required
- **Validation**: Standard
- **Error Details**: Partial
- **Logging**: Info

**Production Environment**:
- **Base URL**: `https://api.company.com`
- **Authentication**: Required
- **Validation**: Strict
- **Error Details**: Minimal
- **Logging**: Warn

**Response Time**:
- **Local**: 5-10 seconds
- **Staging**: 1-2 seconds
- **Production**: <500ms

**Throughput**:
- **Local**: 10 requests per second
- **Staging**: 50 requests per second
- **Production**: 100 requests per second

**Resource Usage**:
- **Memory**: 50-200MB
- **CPU**: 20-80%
- **Database**: Low to High

**Authentication**:
- JWT token required
- Token validation against OAuth2 provider
- Role-based access control

**Authorization**:
- SUPER_ADMIN: Full access
- FACILITY_ADMIN: Facility-scoped access
- STAFF: Read-only facility access

**Data Protection**:
- Data encrypted in transit
- Sensitive data masked in logs
- Comprehensive audit logging

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

**cURL Example**:
```bash
curl -X POST https://api.company.com/api/reports/data/balance-amount \
  -H "Authorization: Bearer <jwt-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "reportType": "BALANCE_AMOUNT_REPORT",
    "facilityCodes": ["FAC001"],
    "payerCodes": ["DHA"],
    "fromDate": "2025-01-01T00:00:00",
    "toDate": "2025-12-31T23:59:59",
    "page": 0,
    "size": 50
  }'
```

**JavaScript Example**:
```javascript
const response = await fetch('https://api.company.com/api/reports/data/balance-amount', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer <jwt-token>',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    reportType: 'BALANCE_AMOUNT_REPORT',
    facilityCodes: ['FAC001'],
    payerCodes: ['DHA'],
    fromDate: '2025-01-01T00:00:00',
    toDate: '2025-12-31T23:59:59',
    page: 0,
    size: 50
  })
});

const data = await response.json();
console.log(data);
```

**Python Example**:
```python
import requests

url = 'https://api.company.com/api/reports/data/balance-amount'
headers = {
    'Authorization': 'Bearer <jwt-token>',
    'Content-Type': 'application/json'
}
data = {
    'reportType': 'BALANCE_AMOUNT_REPORT',
    'facilityCodes': ['FAC001'],
    'payerCodes': ['DHA'],
    'fromDate': '2025-01-01T00:00:00',
    'toDate': '2025-12-31T23:59:59',
    'page': 0,
    'size': 50
}

response = requests.post(url, headers=headers, json=data)
result = response.json()
print(result)
```

**Common Issues**:
- **Issue 1**: No data returned - Check facility access and data availability
- **Issue 2**: Slow response times - Verify materialized view status and refresh
- **Issue 3**: Access denied - Verify user roles and facility assignments

**Debugging Commands**:
```bash
# Check endpoint logs
tail -f logs/application.log | grep "balance-amount"

# Check authentication logs
tail -f logs/application.log | grep "AUTHENTICATION"

# Check error logs
tail -f logs/application.log | grep "ERROR"
```

**Related Documentation**:
- [Report Documentation Template](REPORT_DOCUMENTATION_TEMPLATE.md)
- [API Reference](REPORT_API_REFERENCE.md)
- [API Authentication Guide](API_AUTHENTICATION_GUIDE.md)
- [API Error Codes](API_ERROR_CODES.md)

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

- [Report Documentation Template](REPORT_DOCUMENTATION_TEMPLATE.md) - Report documentation template
- [API Reference](REPORT_API_REFERENCE.md) - API documentation
- [API Authentication Guide](API_AUTHENTICATION_GUIDE.md) - Authentication implementation
- [API Error Codes](API_ERROR_CODES.md) - Error code documentation
- [Security Matrix](SECURITY_MATRIX.md) - Security implementation details
