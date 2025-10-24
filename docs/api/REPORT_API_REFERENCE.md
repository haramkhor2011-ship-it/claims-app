# Report API Reference

This document provides comprehensive API documentation for all report endpoints in the Claims Backend system, including request/response formats, authentication requirements, and environment-specific behavior.

## Base URL

### Environment-Specific URLs

| Environment | Base URL | Port | Protocol |
|-------------|----------|------|----------|
| **Local Development** | `http://localhost` | `8080` | HTTP |
| **Development** | `http://dev-claims.internal` | `8080` | HTTP |
| **Staging** | `https://staging-claims.company.com` | `443` | HTTPS |
| **Production** | `https://claims.company.com` | `443` | HTTPS |

### API Base Path
All report endpoints are prefixed with `/api/reports/data`

---

## Authentication

### JWT Token Requirements
All report endpoints require JWT authentication with the following claims:

```json
{
  "sub": "user@company.com",
  "roles": ["SUPER_ADMIN", "FACILITY_ADMIN", "STAFF"],
  "facilityId": "FAC001",
  "facilityRefId": 123,
  "iat": 1640995200,
  "exp": 1641081600
}
```

### Environment-Specific Authentication

#### Local Development
- **JWT Validation**: May be disabled or simplified for testing
- **Security Bypass**: Some security checks may be bypassed
- **Token Format**: Simplified JWT or test tokens
- **Example Token**: `Bearer test-token-local-dev`

#### Production Environment
- **JWT Validation**: Full validation with OAuth2 integration
- **Security Enforcement**: Complete role-based access control
- **Token Format**: Standard JWT with OAuth2 claims
- **Token Source**: OAuth2 provider (e.g., Auth0, Keycloak)

### Required Headers
```http
Authorization: Bearer <jwt-token>
Content-Type: application/json
Accept: application/json
```

---

## Common Response Format

All report endpoints return responses in the following format:

### Success Response
```json
{
  "success": true,
  "data": {
    "reportType": "BALANCE_AMOUNT_REPORT",
    "tab": "overall",
    "records": [...],
    "pagination": {
      "page": 0,
      "size": 50,
      "totalRecords": 1250,
      "totalPages": 25
    },
    "filters": {
      "applied": {...},
      "available": {...}
    },
    "metadata": {
      "generatedAt": "2025-01-15T10:30:00Z",
      "executionTimeMs": 245,
      "materializedViewUsed": true
    }
  }
}
```

### Error Response
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid date range provided",
    "details": {
      "field": "fromDate",
      "value": "2026-01-01T00:00:00",
      "constraint": "Date cannot be in the future"
    },
    "timestamp": "2025-01-15T10:30:00Z"
  }
}
```

---

## Report Endpoints

### 1. Get Available Reports

**Endpoint**: `GET /api/reports/data/available`

**Purpose**: Retrieve list of available reports for the authenticated user

**Security**: `@PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")`

**Request**: No body required

**Response**:
```json
{
  "success": true,
  "data": {
    "reports": [
      {
        "type": "BALANCE_AMOUNT_REPORT",
        "name": "Balance Amount Report",
        "description": "Track outstanding balance amounts to be received",
        "tabs": ["overall", "initial_not_remitted", "post_resubmission"],
        "availableTabs": ["overall", "initial_not_remitted", "post_resubmission"],
        "filters": {
          "facilityCodes": true,
          "payerCodes": true,
          "dateRange": true,
          "yearMonth": true
        }
      },
      {
        "type": "REJECTED_CLAIMS_REPORT",
        "name": "Rejected Claims Report",
        "description": "Analysis of rejected claims with reasons and patterns",
        "tabs": ["summary", "details"],
        "availableTabs": ["summary", "details"],
        "filters": {
          "facilityCodes": true,
          "payerCodes": true,
          "dateRange": true,
          "denialCodes": true
        }
      }
    ],
    "userPermissions": {
      "roles": ["FACILITY_ADMIN"],
      "facilityId": "FAC001",
      "multiTenancyEnabled": true
    }
  }
}
```

**Environment Differences**:
- **Local**: May return all reports regardless of user role
- **Production**: Returns only reports accessible to user's role and facility

---

### 2. Balance Amount Report

**Endpoint**: `POST /api/reports/data/balance-amount`

**Purpose**: Retrieve balance amount data with aging analysis

**Security**: `@PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")`

**Request Body**:
```json
{
  "reportType": "BALANCE_AMOUNT_REPORT",
  "tab": "overall",
  "facilityCodes": ["FAC001", "FAC002"],
  "payerCodes": ["DHA", "ADNOC"],
  "receiverIds": ["PROV001"],
  "fromDate": "2025-01-01T00:00:00",
  "toDate": "2025-12-31T23:59:59",
  "year": 2025,
  "month": 6,
  "basedOnInitialNet": true,
  "sortBy": "aging_days",
  "sortDirection": "DESC",
  "page": 0,
  "size": 50,
  "facilityRefIds": [123, 124],
  "payerRefIds": [456, 457]
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "reportType": "BALANCE_AMOUNT_REPORT",
    "tab": "overall",
    "records": [
      {
        "claimKeyId": 12345,
        "claimId": "CLM123456",
        "facilityGroupId": "FG001",
        "healthAuthority": "DHA",
        "facilityId": "FAC001",
        "facilityName": "Dubai Hospital",
        "claimNumber": "CN789012",
        "encounterStartDate": "2025-01-15T00:00:00Z",
        "encounterEndDate": "2025-01-17T00:00:00Z",
        "encounterStartYear": 2025,
        "encounterStartMonth": 1,
        "idPayer": "DHA",
        "patientId": "PAT789",
        "memberId": "MEM123",
        "emiratesIdNumber": "784-1234-5678901-2",
        "billedAmount": 1500.00,
        "amountReceived": 1200.00,
        "deniedAmount": 100.00,
        "outstandingBalance": 200.00,
        "submissionDate": "2025-01-20T10:30:00Z",
        "submissionReferenceFile": "submission_20250120.xml",
        "claimStatus": "SUBMITTED",
        "remittanceCount": 1,
        "resubmissionCount": 0,
        "agingDays": 25,
        "agingBucket": "30-60 days",
        "currentClaimStatus": "PENDING",
        "lastStatusDate": "2025-01-20T10:30:00Z",
        "totalRecords": 1250
      }
    ],
    "pagination": {
      "page": 0,
      "size": 50,
      "totalRecords": 1250,
      "totalPages": 25
    },
    "metadata": {
      "generatedAt": "2025-01-15T10:30:00Z",
      "executionTimeMs": 245,
      "materializedViewUsed": true,
      "queryOptimized": true
    }
  }
}
```

**Environment Differences**:
- **Local**: `materializedViewUsed: false`, `executionTimeMs: 5000-10000`
- **Production**: `materializedViewUsed: true`, `executionTimeMs: <500`

---

### 3. Claim Details with Activity Report

**Endpoint**: `POST /api/reports/data/claim-details-with-activity`

**Purpose**: Detailed view of claims with associated activities

**Security**: `@PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")`

**Request Body**:
```json
{
  "reportType": "CLAIM_DETAILS_WITH_ACTIVITY",
  "level": "activity",
  "facilityCodes": ["FAC001"],
  "payerCodes": ["DHA"],
  "receiverId": "PROV001",
  "clinician": "DR001",
  "memberId": "MEM123",
  "resubType": "CORRECTED",
  "claimStatus": "SUBMITTED",
  "paymentStatus": "PENDING",
  "cptCode": "99213",
  "patientId": "PAT789",
  "encounterType": "OUTPATIENT",
  "denialCode": "CO-4",
  "fromDate": "2025-01-01T00:00:00",
  "toDate": "2025-12-31T23:59:59",
  "sortBy": "submission_date",
  "sortDirection": "DESC",
  "page": 0,
  "size": 50
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "reportType": "CLAIM_DETAILS_WITH_ACTIVITY",
    "level": "activity",
    "records": [
      {
        "activityId": "ACT123456",
        "claimId": "CLM123456",
        "facilityId": "FAC001",
        "facilityName": "Dubai Hospital",
        "payerId": "DHA",
        "payerName": "Dubai Health Authority",
        "providerId": "PROV001",
        "providerName": "Dr. Smith",
        "clinicianId": "DR001",
        "clinicianName": "Dr. John Smith",
        "patientId": "PAT789",
        "memberId": "MEM123",
        "cptCode": "99213",
        "cptDescription": "Office visit, established patient",
        "activityDate": "2025-01-15T00:00:00Z",
        "submissionDate": "2025-01-20T10:30:00Z",
        "activityStatus": "SUBMITTED",
        "claimStatus": "PENDING",
        "billedAmount": 150.00,
        "allowedAmount": 120.00,
        "paidAmount": 0.00,
        "deniedAmount": 0.00,
        "totalRecords": 500
      }
    ],
    "pagination": {
      "page": 0,
      "size": 50,
      "totalRecords": 500,
      "totalPages": 10
    },
    "metadata": {
      "generatedAt": "2025-01-15T10:30:00Z",
      "executionTimeMs": 180,
      "materializedViewUsed": true
    }
  }
}
```

---

### 4. Claim Summary Monthwise Report

**Endpoint**: `POST /api/reports/data/claim-summary-monthwise`

**Purpose**: Monthly aggregation of claim statistics

**Security**: `@PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")`

**Request Body**:
```json
{
  "reportType": "CLAIM_SUMMARY_MONTHWISE",
  "facilityCodes": ["FAC001"],
  "payerCodes": ["DHA"],
  "fromDate": "2025-01-01T00:00:00",
  "toDate": "2025-12-31T23:59:59",
  "year": 2025,
  "month": 6,
  "page": 0,
  "size": 50
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "reportType": "CLAIM_SUMMARY_MONTHWISE",
    "records": [
      {
        "year": 2025,
        "month": 6,
        "monthName": "June",
        "facilityId": "FAC001",
        "facilityName": "Dubai Hospital",
        "payerId": "DHA",
        "payerName": "Dubai Health Authority",
        "totalClaims": 1250,
        "submittedClaims": 1200,
        "paidClaims": 1100,
        "rejectedClaims": 100,
        "pendingClaims": 50,
        "totalBilledAmount": 150000.00,
        "totalPaidAmount": 135000.00,
        "totalDeniedAmount": 10000.00,
        "averageProcessingDays": 15.5,
        "successRate": 91.67,
        "totalRecords": 12
      }
    ],
    "pagination": {
      "page": 0,
      "size": 50,
      "totalRecords": 12,
      "totalPages": 1
    },
    "metadata": {
      "generatedAt": "2025-01-15T10:30:00Z",
      "executionTimeMs": 120,
      "materializedViewUsed": true
    }
  }
}
```

---

### 5. Doctor Denial Report

**Endpoint**: `POST /api/reports/data/doctor-denial`

**Purpose**: Analysis of claim denials by doctor/clinician

**Security**: `@PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")`

**Request Body**:
```json
{
  "reportType": "DOCTOR_DENIAL_REPORT",
  "tab": "summary",
  "facilityCodes": ["FAC001"],
  "payerCodes": ["DHA"],
  "clinicianIds": ["DR001", "DR002"],
  "fromDate": "2025-01-01T00:00:00",
  "toDate": "2025-12-31T23:59:59",
  "denialCodes": ["CO-4", "CO-16"],
  "page": 0,
  "size": 50
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "reportType": "DOCTOR_DENIAL_REPORT",
    "tab": "summary",
    "records": [
      {
        "clinicianId": "DR001",
        "clinicianName": "Dr. John Smith",
        "facilityId": "FAC001",
        "facilityName": "Dubai Hospital",
        "payerId": "DHA",
        "payerName": "Dubai Health Authority",
        "totalClaims": 500,
        "deniedClaims": 50,
        "denialRate": 10.0,
        "totalBilledAmount": 75000.00,
        "deniedAmount": 7500.00,
        "topDenialReason": "CO-4",
        "topDenialDescription": "Procedure not covered",
        "denialReasons": [
          {
            "code": "CO-4",
            "description": "Procedure not covered",
            "count": 25,
            "amount": 3750.00
          },
          {
            "code": "CO-16",
            "description": "Claim lacks information",
            "count": 15,
            "amount": 2250.00
          }
        ],
        "totalRecords": 25
      }
    ],
    "pagination": {
      "page": 0,
      "size": 50,
      "totalRecords": 25,
      "totalPages": 1
    },
    "metadata": {
      "generatedAt": "2025-01-15T10:30:00Z",
      "executionTimeMs": 320,
      "materializedViewUsed": true
    }
  }
}
```

---

### 6. Rejected Claims Report

**Endpoint**: `POST /api/reports/data/rejected-claims`

**Purpose**: Comprehensive analysis of rejected claims

**Security**: `@PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")`

**Request Body**:
```json
{
  "reportType": "REJECTED_CLAIMS_REPORT",
  "tab": "summary",
  "facilityCodes": ["FAC001"],
  "payerCodes": ["DHA"],
  "fromDate": "2025-01-01T00:00:00",
  "toDate": "2025-12-31T23:59:59",
  "denialCodes": ["CO-4", "CO-16"],
  "denialFilter": "rejected",
  "page": 0,
  "size": 50
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "reportType": "REJECTED_CLAIMS_REPORT",
    "tab": "summary",
    "records": [
      {
        "facilityId": "FAC001",
        "facilityName": "Dubai Hospital",
        "payerId": "DHA",
        "payerName": "Dubai Health Authority",
        "totalClaims": 2000,
        "rejectedClaims": 200,
        "rejectionRate": 10.0,
        "totalBilledAmount": 300000.00,
        "rejectedAmount": 30000.00,
        "topRejectionReason": "CO-4",
        "topRejectionDescription": "Procedure not covered",
        "rejectionReasons": [
          {
            "code": "CO-4",
            "description": "Procedure not covered",
            "count": 100,
            "amount": 15000.00,
            "percentage": 50.0
          },
          {
            "code": "CO-16",
            "description": "Claim lacks information",
            "count": 60,
            "amount": 9000.00,
            "percentage": 30.0
          }
        ],
        "resubmissionStats": {
          "resubmittedClaims": 150,
          "resubmissionSuccessRate": 75.0,
          "averageResubmissionCycles": 1.5
        },
        "totalRecords": 5
      }
    ],
    "pagination": {
      "page": 0,
      "size": 50,
      "totalRecords": 5,
      "totalPages": 1
    },
    "metadata": {
      "generatedAt": "2025-01-15T10:30:00Z",
      "executionTimeMs": 450,
      "materializedViewUsed": true
    }
  }
}
```

---

### 7. Remittance Advice Payerwise Report

**Endpoint**: `POST /api/reports/data/remittance-advice-payerwise`

**Purpose**: Analysis of remittance advice by payer

**Security**: `@PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")`

**Request Body**:
```json
{
  "reportType": "REMITTANCE_ADVICE_PAYERWISE",
  "facilityCodes": ["FAC001"],
  "payerCodes": ["DHA"],
  "fromDate": "2025-01-01T00:00:00",
  "toDate": "2025-12-31T23:59:59",
  "page": 0,
  "size": 50
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "reportType": "REMITTANCE_ADVICE_PAYERWISE",
    "records": [
      {
        "payerId": "DHA",
        "payerName": "Dubai Health Authority",
        "facilityId": "FAC001",
        "facilityName": "Dubai Hospital",
        "totalRemittances": 100,
        "totalClaims": 5000,
        "totalBilledAmount": 750000.00,
        "totalPaidAmount": 675000.00,
        "totalDeniedAmount": 50000.00,
        "totalAdjustmentAmount": 25000.00,
        "averageProcessingDays": 12.5,
        "paymentTimeliness": 95.0,
        "remittanceBreakdown": [
          {
            "remittanceType": "PAYMENT",
            "count": 80,
            "amount": 675000.00
          },
          {
            "remittanceType": "DENIAL",
            "count": 15,
            "amount": 50000.00
          },
          {
            "remittanceType": "ADJUSTMENT",
            "count": 5,
            "amount": 25000.00
          }
        ],
        "totalRecords": 3
      }
    ],
    "pagination": {
      "page": 0,
      "size": 50,
      "totalRecords": 3,
      "totalPages": 1
    },
    "metadata": {
      "generatedAt": "2025-01-15T10:30:00Z",
      "executionTimeMs": 280,
      "materializedViewUsed": true
    }
  }
}
```

---

### 8. Remittances Resubmission Report

**Endpoint**: `POST /api/reports/data/remittances-resubmission`

**Purpose**: Track resubmission cycles and outcomes

**Security**: `@PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")`

**Request Body**:
```json
{
  "reportType": "REMITTANCES_RESUBMISSION",
  "facilityIds": ["FAC001"],
  "payerIds": ["DHA"],
  "receiverIds": ["PROV001"],
  "clinicianIds": ["DR001"],
  "claimNumber": "CLM123456",
  "cptCode": "99213",
  "denialFilter": "rejected",
  "encounterType": "OUTPATIENT",
  "level": "activity",
  "fromDate": "2025-01-01T00:00:00",
  "toDate": "2025-12-31T23:59:59",
  "orderBy": "encounter_start",
  "page": 0,
  "size": 50,
  "facilityRefIds": [123],
  "payerRefIds": [456],
  "clinicianRefIds": [789]
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "reportType": "REMITTANCES_RESUBMISSION",
    "records": [
      {
        "claimId": "CLM123456",
        "facilityId": "FAC001",
        "facilityName": "Dubai Hospital",
        "payerId": "DHA",
        "payerName": "Dubai Health Authority",
        "providerId": "PROV001",
        "providerName": "Dr. Smith",
        "clinicianId": "DR001",
        "clinicianName": "Dr. John Smith",
        "encounterStartDate": "2025-01-15T00:00:00Z",
        "encounterEndDate": "2025-01-17T00:00:00Z",
        "submissionDate": "2025-01-20T10:30:00Z",
        "resubmissionCount": 2,
        "resubmissionCycles": [
          {
            "cycle": 1,
            "submissionDate": "2025-01-20T10:30:00Z",
            "status": "REJECTED",
            "denialReason": "CO-4",
            "denialDescription": "Procedure not covered"
          },
          {
            "cycle": 2,
            "submissionDate": "2025-01-25T14:20:00Z",
            "status": "REJECTED",
            "denialReason": "CO-16",
            "denialDescription": "Claim lacks information"
          },
          {
            "cycle": 3,
            "submissionDate": "2025-01-30T09:15:00Z",
            "status": "PENDING",
            "denialReason": null,
            "denialDescription": null
          }
        ],
        "currentStatus": "PENDING",
        "totalBilledAmount": 1500.00,
        "totalPaidAmount": 0.00,
        "totalDeniedAmount": 0.00,
        "totalRecords": 150
      }
    ],
    "pagination": {
      "page": 0,
      "size": 50,
      "totalRecords": 150,
      "totalPages": 3
    },
    "metadata": {
      "generatedAt": "2025-01-15T10:30:00Z",
      "executionTimeMs": 380,
      "materializedViewUsed": true
    }
  }
}
```

---

## Error Codes

### HTTP Status Codes

| Code | Description | Common Scenarios |
|------|-------------|------------------|
| `200` | Success | Report data retrieved successfully |
| `400` | Bad Request | Invalid request parameters, validation errors |
| `401` | Unauthorized | Missing or invalid JWT token |
| `403` | Forbidden | Insufficient permissions for report access |
| `404` | Not Found | Report type not found or endpoint not available |
| `500` | Internal Server Error | Database errors, system failures |

### Application Error Codes

| Error Code | Description | Resolution |
|------------|-------------|------------|
| `VALIDATION_ERROR` | Request validation failed | Check request parameters and constraints |
| `AUTHENTICATION_ERROR` | JWT token invalid or expired | Refresh token or re-authenticate |
| `AUTHORIZATION_ERROR` | Insufficient permissions | Contact administrator for role assignment |
| `REPORT_NOT_FOUND` | Report type not available | Check available reports endpoint |
| `DATABASE_ERROR` | Database query failed | Check system logs, contact support |
| `MATERIALIZED_VIEW_ERROR` | MV refresh or query failed | Check MV status, contact DBA |
| `FACILITY_ACCESS_ERROR` | Facility access denied | Verify facility permissions |
| `PAYER_ACCESS_ERROR` | Payer access denied | Verify payer permissions |

---

## Rate Limiting

### Environment-Specific Rate Limits

| Environment | Requests per Minute | Burst Limit | Window |
|-------------|---------------------|-------------|---------|
| **Local** | No limit | No limit | N/A |
| **Development** | 1000 | 100 | 1 minute |
| **Staging** | 500 | 50 | 1 minute |
| **Production** | 200 | 20 | 1 minute |

### Rate Limit Headers
```http
X-RateLimit-Limit: 200
X-RateLimit-Remaining: 195
X-RateLimit-Reset: 1640995260
```

### Rate Limit Exceeded Response
```json
{
  "success": false,
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded. Try again in 60 seconds.",
    "details": {
      "limit": 200,
      "remaining": 0,
      "resetTime": "2025-01-15T10:31:00Z"
    }
  }
}
```

---

## Environment-Specific Behavior

### Local Development
- **Authentication**: Simplified or disabled for testing
- **Rate Limiting**: Disabled
- **Materialized Views**: Disabled by default
- **Performance**: Slower execution acceptable
- **Error Details**: Full stack traces in responses
- **Caching**: Disabled or minimal

### Production Environment
- **Authentication**: Full JWT validation with OAuth2
- **Rate Limiting**: Strict enforcement
- **Materialized Views**: Enabled for performance
- **Performance**: Sub-second response times required
- **Error Details**: Generic messages, detailed logs
- **Caching**: Enabled for reference data and queries

---

## Example Usage

### cURL Examples

#### Local Development
```bash
# Get available reports
curl -X GET "http://localhost:8080/api/reports/data/available" \
  -H "Authorization: Bearer test-token-local" \
  -H "Content-Type: application/json"

# Get balance amount report
curl -X POST "http://localhost:8080/api/reports/data/balance-amount" \
  -H "Authorization: Bearer test-token-local" \
  -H "Content-Type: application/json" \
  -d '{
    "reportType": "BALANCE_AMOUNT_REPORT",
    "tab": "overall",
    "facilityCodes": ["FAC001"],
    "fromDate": "2025-01-01T00:00:00",
    "toDate": "2025-12-31T23:59:59",
    "page": 0,
    "size": 50
  }'
```

#### Production Environment
```bash
# Get available reports
curl -X GET "https://claims.company.com/api/reports/data/available" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json"

# Get balance amount report
curl -X POST "https://claims.company.com/api/reports/data/balance-amount" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "reportType": "BALANCE_AMOUNT_REPORT",
    "tab": "overall",
    "facilityCodes": ["FAC001"],
    "fromDate": "2025-01-01T00:00:00",
    "toDate": "2025-12-31T23:59:59",
    "page": 0,
    "size": 50
  }'
```

### JavaScript/TypeScript Examples

#### Local Development
```typescript
const API_BASE_URL = 'http://localhost:8080/api/reports/data';
const AUTH_TOKEN = 'test-token-local';

// Get available reports
const availableReports = await fetch(`${API_BASE_URL}/available`, {
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${AUTH_TOKEN}`,
    'Content-Type': 'application/json'
  }
});

// Get balance amount report
const balanceReport = await fetch(`${API_BASE_URL}/balance-amount`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${AUTH_TOKEN}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    reportType: 'BALANCE_AMOUNT_REPORT',
    tab: 'overall',
    facilityCodes: ['FAC001'],
    fromDate: '2025-01-01T00:00:00',
    toDate: '2025-12-31T23:59:59',
    page: 0,
    size: 50
  })
});
```

#### Production Environment
```typescript
const API_BASE_URL = 'https://claims.company.com/api/reports/data';
const AUTH_TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';

// Get available reports
const availableReports = await fetch(`${API_BASE_URL}/available`, {
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${AUTH_TOKEN}`,
    'Content-Type': 'application/json'
  }
});

// Get balance amount report
const balanceReport = await fetch(`${API_BASE_URL}/balance-amount`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${AUTH_TOKEN}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    reportType: 'BALANCE_AMOUNT_REPORT',
    tab: 'overall',
    facilityCodes: ['FAC001'],
    fromDate: '2025-01-01T00:00:00',
    toDate: '2025-12-31T23:59:59',
    page: 0,
    size: 50
  })
});
```

---

## Related Documentation

- [Report Catalog](REPORT_CATALOG.md) - Complete report details
- [API Authentication Guide](API_AUTHENTICATION_GUIDE.md) - Authentication setup
- [API Error Codes](API_ERROR_CODES.md) - Complete error reference
- [Environment Behavior Guide](ENVIRONMENT_BEHAVIOR_GUIDE.md) - Environment differences
- [Security Matrix](SECURITY_MATRIX.md) - Access control details
