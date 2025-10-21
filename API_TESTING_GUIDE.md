# API Testing Guide

## Overview
This guide provides comprehensive testing instructions for the Claims Backend API endpoints, including security, validation, and functionality testing.

## Prerequisites
- Java 17+
- Maven 3.6+
- PostgreSQL database with required functions
- Postman or similar API testing tool

## Security Configuration

### Current State (Security Disabled)
The application is currently configured with security disabled in `application.yml`:
```yaml
security:
  enabled: false
```

### Enabling Security
To enable security, update `application.yml`:
```yaml
security:
  enabled: true
  jwt:
    secret: your-secret-key-here
    expiration: 86400000 # 24 hours
  default-admin:
    username: admin
    password: admin123
    email: admin@acme.com
```

## API Endpoints Testing

### 1. Authentication (When Security Enabled)
```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "admin123"
}
```

### 2. Report Data Query Endpoint
```http
POST /api/reports/data/query
Content-Type: application/json
Authorization: Bearer <token> (when security enabled)

{
  "reportType": "BALANCE_AMOUNT_REPORT",
  "tab": "overall",
  "facilityCodes": ["FAC001", "FAC002"],
  "fromDate": "2025-01-01T00:00:00",
  "toDate": "2025-12-31T23:59:59",
  "page": 0,
  "size": 50,
  "sortBy": "aging_days",
  "sortDirection": "DESC"
}
```

## Test Scenarios

### 1. Valid Request Testing
- Test each report type with valid parameters
- Verify response structure and data accuracy
- Check pagination functionality
- Validate sorting parameters

### 2. Error Handling Testing
- Invalid report type
- Missing required parameters
- Invalid date ranges
- Unauthorized access (when security enabled)
- Invalid pagination parameters

### 3. Security Testing (When Enabled)
- Test without authentication token
- Test with invalid token
- Test role-based access control
- Test facility-based data filtering

### 4. Performance Testing
- Large dataset queries
- Concurrent request handling
- Response time validation
- Memory usage monitoring

## Postman Collection

### Environment Variables
Create a Postman environment with:
- `baseUrl`: http://localhost:8080
- `authToken`: (set after login)
- `userId`: (set after login)

### Collection Structure
1. **Authentication**
   - Login
   - Logout
   - Token Refresh

2. **Report Data**
   - Balance Amount Report
   - Rejected Claims Report
   - Claim Details with Activity
   - Doctor Denial Report
   - Remittances Resubmission
   - Remittance Advice Payerwise
   - Claim Summary Monthwise

3. **Error Scenarios**
   - Invalid Requests
   - Unauthorized Access
   - Server Errors

## Database Function Verification

### Verify Function Calls
Ensure service classes correctly call database functions:

1. **Balance Amount Report**
   - Function: `claims.get_balance_amount_to_be_received`
   - Parameters: `p_limit`, `p_offset` (not `p_page`, `p_size`)

2. **Rejected Claims Report**
   - Function: `claims.get_rejected_claims_report`
   - Parameters: `p_limit`, `p_offset`

3. **Claim Details with Activity**
   - Function: `claims.get_claim_details_with_activity`
   - Parameters: `p_limit`, `p_offset`

4. **Doctor Denial Report**
   - Function: `claims.get_doctor_denial_report`
   - Parameters: `p_limit`, `p_offset`

5. **Remittances Resubmission**
   - Function: `claims.get_remittances_resubmission_report`
   - Parameters: `p_limit`, `p_offset`

## Monitoring and Logging

### Log Levels
- `DEBUG`: Detailed request/response logging
- `INFO`: General application flow
- `WARN`: Non-critical issues
- `ERROR`: Critical errors

### Key Log Messages
- User authentication attempts
- Report access requests
- Database query execution
- Error occurrences
- Performance metrics

## Troubleshooting

### Common Issues
1. **Database Connection**
   - Verify PostgreSQL is running
   - Check connection parameters
   - Ensure required functions exist

2. **Security Issues**
   - Verify JWT secret configuration
   - Check user roles and permissions
   - Validate facility assignments

3. **Performance Issues**
   - Monitor database query execution
   - Check materialized view refresh
   - Verify pagination implementation

### Debug Mode
Enable debug logging in `application.yml`:
```yaml
logging:
  level:
    com.acme.claims: DEBUG
    org.springframework.security: DEBUG
```

## Success Criteria
- All endpoints respond correctly
- Error handling works as expected
- Security controls function properly
- Performance meets requirements
- Logging provides adequate audit trail
