# Postman Collection

## Collection Overview
This Postman collection provides comprehensive testing for the Claims Backend API endpoints, including authentication, report data queries, and error handling scenarios.

## Environment Setup

### Environment Variables
Create a Postman environment with the following variables:

```json
{
  "baseUrl": "http://localhost:8080",
  "authToken": "",
  "userId": "",
  "username": "admin",
  "password": "admin123",
  "facilityCode": "FAC001",
  "payerCode": "DHA",
  "receiverCode": "REC001",
  "fromDate": "2025-01-01T00:00:00",
  "toDate": "2025-12-31T23:59:59",
  "page": "0",
  "size": "50",
  "sortBy": "created_date",
  "sortDirection": "DESC"
}
```

## Collection Structure

### 1. Authentication
#### Login
```http
POST {{baseUrl}}/api/auth/login
Content-Type: application/json

{
  "username": "{{username}}",
  "password": "{{password}}"
}
```

**Tests:**
```javascript
if (pm.response.code === 200) {
    const response = pm.response.json();
    pm.environment.set("authToken", response.token);
    pm.environment.set("userId", response.userId);
}
```

#### Logout
```http
POST {{baseUrl}}/api/auth/logout
Authorization: Bearer {{authToken}}
```

### 2. Report Data Queries

#### Balance Amount Report
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "BALANCE_AMOUNT_REPORT",
  "tab": "overall",
  "facilityCodes": ["{{facilityCode}}"],
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}",
  "page": {{page}},
  "size": {{size}},
  "sortBy": "aging_days",
  "sortDirection": "DESC"
}
```

#### Rejected Claims Report - Summary
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "REJECTED_CLAIMS_REPORT",
  "tab": "summary",
  "facilityCodes": ["{{facilityCode}}"],
  "payerCodes": ["{{payerCode}}"],
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}",
  "page": {{page}},
  "size": {{size}}
}
```

#### Rejected Claims Report - Receiver Payer
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "REJECTED_CLAIMS_REPORT",
  "tab": "receiverPayer",
  "facilityCodes": ["{{facilityCode}}"],
  "payerCodes": ["{{payerCode}}"],
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}",
  "page": {{page}},
  "size": {{size}}
}
```

#### Rejected Claims Report - Claim Wise
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "REJECTED_CLAIMS_REPORT",
  "tab": "claimWise",
  "facilityCodes": ["{{facilityCode}}"],
  "payerCodes": ["{{payerCode}}"],
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}",
  "page": {{page}},
  "size": {{size}}
}
```

#### Claim Details with Activity
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "CLAIM_DETAILS_WITH_ACTIVITY",
  "facilityCode": "{{facilityCode}}",
  "payerCode": "{{payerCode}}",
  "receiverCode": "{{receiverCode}}",
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}",
  "page": {{page}},
  "size": {{size}},
  "sortBy": "{{sortBy}}",
  "sortDirection": "{{sortDirection}}"
}
```

#### Doctor Denial Report - High Denial
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "DOCTOR_DENIAL_REPORT",
  "tab": "high_denial",
  "facilityCode": "{{facilityCode}}",
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}",
  "page": {{page}},
  "size": {{size}}
}
```

#### Doctor Denial Report - Summary
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "DOCTOR_DENIAL_REPORT",
  "tab": "summary",
  "facilityCode": "{{facilityCode}}",
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}",
  "page": {{page}},
  "size": {{size}}
}
```

#### Remittances Resubmission - Activity Level
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "REMITTANCES_RESUBMISSION",
  "level": "activity",
  "facilityCode": "{{facilityCode}}",
  "payerCodes": ["{{payerCode}}"],
  "receiverIds": ["{{receiverCode}}"],
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}",
  "page": {{page}},
  "size": {{size}}
}
```

#### Remittances Resubmission - Claim Level
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "REMITTANCES_RESUBMISSION",
  "level": "claim",
  "facilityCode": "{{facilityCode}}",
  "payerCodes": ["{{payerCode}}"],
  "receiverIds": ["{{receiverCode}}"],
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}",
  "page": {{page}},
  "size": {{size}}
}
```

#### Remittance Advice Payerwise - Header
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "REMITTANCE_ADVICE_PAYERWISE",
  "tab": "header",
  "facilityCode": "{{facilityCode}}",
  "payerCode": "{{payerCode}}",
  "receiverCode": "{{receiverCode}}",
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}",
  "page": {{page}},
  "size": {{size}}
}
```

#### Remittance Advice Payerwise - Claim Wise
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "REMITTANCE_ADVICE_PAYERWISE",
  "tab": "claimWise",
  "facilityCode": "{{facilityCode}}",
  "payerCode": "{{payerCode}}",
  "receiverCode": "{{receiverCode}}",
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}",
  "page": {{page}},
  "size": {{size}}
}
```

#### Remittance Advice Payerwise - Activity Wise
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "REMITTANCE_ADVICE_PAYERWISE",
  "tab": "activityWise",
  "facilityCode": "{{facilityCode}}",
  "payerCode": "{{payerCode}}",
  "receiverCode": "{{receiverCode}}",
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}",
  "page": {{page}},
  "size": {{size}}
}
```

#### Claim Summary Monthwise - Monthwise
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "CLAIM_SUMMARY_MONTHWISE",
  "tab": "monthwise",
  "facilityCode": "{{facilityCode}}",
  "payerCode": "{{payerCode}}",
  "receiverCode": "{{receiverCode}}",
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}",
  "page": {{page}},
  "size": {{size}}
}
```

#### Claim Summary Monthwise - Payerwise
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "CLAIM_SUMMARY_MONTHWISE",
  "tab": "payerwise",
  "facilityCode": "{{facilityCode}}",
  "payerCode": "{{payerCode}}",
  "receiverCode": "{{receiverCode}}",
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}",
  "page": {{page}},
  "size": {{size}}
}
```

#### Claim Summary Monthwise - Encounterwise
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "CLAIM_SUMMARY_MONTHWISE",
  "tab": "encounterwise",
  "facilityCode": "{{facilityCode}}",
  "payerCode": "{{payerCode}}",
  "receiverCode": "{{receiverCode}}",
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}",
  "page": {{page}},
  "size": {{size}}
}
```

### 3. Error Scenarios

#### Invalid Report Type
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "INVALID_REPORT_TYPE",
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}"
}
```

#### Missing Required Parameters
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}"
}
```

#### Invalid Date Range
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer {{authToken}}

{
  "reportType": "BALANCE_AMOUNT_REPORT",
  "fromDate": "2025-12-31T23:59:59",
  "toDate": "2025-01-01T00:00:00"
}
```

#### Unauthorized Access (No Token)
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json

{
  "reportType": "BALANCE_AMOUNT_REPORT",
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}"
}
```

#### Invalid Token
```http
POST {{baseUrl}}/api/reports/data/query
Content-Type: application/json
Authorization: Bearer invalid-token

{
  "reportType": "BALANCE_AMOUNT_REPORT",
  "fromDate": "{{fromDate}}",
  "toDate": "{{toDate}}"
}
```

### 4. Health Checks

#### Application Health
```http
GET {{baseUrl}}/actuator/health
```

#### Database Health
```http
GET {{baseUrl}}/actuator/health/db
```

#### Custom Health Check
```http
GET {{baseUrl}}/api/health
```

## Test Scripts

### Common Test Script
Add this to the "Tests" tab of each request:

```javascript
// Status code validation
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});

// Response time validation
pm.test("Response time is less than 5000ms", function () {
    pm.expect(pm.response.responseTime).to.be.below(5000);
});

// Content type validation
pm.test("Content-Type is application/json", function () {
    pm.expect(pm.response.headers.get("Content-Type")).to.include("application/json");
});

// Response structure validation
pm.test("Response has required fields", function () {
    const response = pm.response.json();
    pm.expect(response).to.have.property("reportType");
    pm.expect(response).to.have.property("data");
    pm.expect(response).to.have.property("timestamp");
});

// Data validation
pm.test("Data is an array", function () {
    const response = pm.response.json();
    pm.expect(response.data).to.be.an("array");
});

// Pagination validation
pm.test("Pagination works correctly", function () {
    const response = pm.response.json();
    if (response.data && response.data.length > 0) {
        pm.expect(response.data.length).to.be.at.most(parseInt(pm.environment.get("size")));
    }
});
```

### Error Test Script
Add this to error scenario requests:

```javascript
// Error status code validation
pm.test("Status code indicates error", function () {
    pm.expect(pm.response.code).to.be.oneOf([400, 401, 403, 404, 500]);
});

// Error response structure
pm.test("Error response has error field", function () {
    const response = pm.response.json();
    pm.expect(response).to.have.property("error");
});

// Error message validation
pm.test("Error message is descriptive", function () {
    const response = pm.response.json();
    pm.expect(response.error).to.be.a("string");
    pm.expect(response.error.length).to.be.above(0);
});
```

## Collection Runner

### Test Scenarios
1. **Happy Path Testing**
   - Run all report queries with valid parameters
   - Verify data accuracy and response structure

2. **Error Handling Testing**
   - Run error scenarios
   - Verify proper error responses

3. **Performance Testing**
   - Run with large page sizes
   - Monitor response times

4. **Security Testing**
   - Test without authentication
   - Test with invalid tokens
   - Test role-based access

### Environment Variables for Testing
```json
{
  "testMode": "true",
  "maxResponseTime": "5000",
  "expectedDataFields": ["reportType", "data", "timestamp"],
  "paginationTestSize": "100"
}
```

## Export Instructions

1. **Export Collection**
   - File → Export → Collection v2.1
   - Save as `claims-backend-api.postman_collection.json`

2. **Export Environment**
   - File → Export → Environment
   - Save as `claims-backend-env.postman_environment.json`

3. **Share with Team**
   - Upload to Postman workspace
   - Share collection and environment
   - Document usage instructions
