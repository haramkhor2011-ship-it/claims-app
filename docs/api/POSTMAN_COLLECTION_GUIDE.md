# Postman Collection Guide

## Overview

This guide provides comprehensive instructions for using the Postman collection to test and interact with the reports API. It covers environment setup, authentication configuration, and testing scenarios for both local development and production environments.

## Collection Structure

### Environment Variables

#### Local Development Environment
```json
{
  "name": "Claims API - Local",
  "values": [
    {
      "key": "base_url",
      "value": "http://localhost:8080",
      "enabled": true
    },
    {
      "key": "auth_url",
      "value": "http://localhost:8080/api/auth",
      "enabled": true
    },
    {
      "key": "reports_url",
      "value": "http://localhost:8080/api/reports",
      "enabled": true
    },
    {
      "key": "username",
      "value": "admin",
      "enabled": true
    },
    {
      "key": "password",
      "value": "admin123",
      "enabled": true
    },
    {
      "key": "facility_code",
      "value": "FAC001",
      "enabled": true
    },
    {
      "key": "payer_code",
      "value": "PAYER001",
      "enabled": true
    }
  ]
}
```

#### Staging Environment
```json
{
  "name": "Claims API - Staging",
  "values": [
    {
      "key": "base_url",
      "value": "https://staging-api.claims.com",
      "enabled": true
    },
    {
      "key": "auth_url",
      "value": "https://staging-api.claims.com/api/auth",
      "enabled": true
    },
    {
      "key": "reports_url",
      "value": "https://staging-api.claims.com/api/reports",
      "enabled": true
    },
    {
      "key": "username",
      "value": "{{staging_username}}",
      "enabled": true
    },
    {
      "key": "password",
      "value": "{{staging_password}}",
      "enabled": true
    },
    {
      "key": "facility_code",
      "value": "FAC001",
      "enabled": true
    },
    {
      "key": "payer_code",
      "value": "PAYER001",
      "enabled": true
    }
  ]
}
```

#### Production Environment
```json
{
  "name": "Claims API - Production",
  "values": [
    {
      "key": "base_url",
      "value": "https://api.claims.com",
      "enabled": true
    },
    {
      "key": "auth_url",
      "value": "https://api.claims.com/api/auth",
      "enabled": true
    },
    {
      "key": "reports_url",
      "value": "https://api.claims.com/api/reports",
      "enabled": true
    },
    {
      "key": "username",
      "value": "{{prod_username}}",
      "enabled": true
    },
    {
      "key": "password",
      "value": "{{prod_password}}",
      "enabled": true
    },
    {
      "key": "facility_code",
      "value": "FAC001",
      "enabled": true
    },
    {
      "key": "payer_code",
      "value": "PAYER001",
      "enabled": true
    }
  ]
}
```

## Authentication Setup

### Login Request

#### Request Configuration
```json
{
  "name": "Login",
  "request": {
    "method": "POST",
    "header": [
      {
        "key": "Content-Type",
        "value": "application/json"
      }
    ],
    "body": {
      "mode": "raw",
      "raw": "{\n  \"username\": \"{{username}}\",\n  \"password\": \"{{password}}\"\n}"
    },
    "url": {
      "raw": "{{auth_url}}/login",
      "host": ["{{auth_url}}"],
      "path": ["login"]
    }
  },
  "event": [
    {
      "listen": "test",
      "script": {
        "exec": [
          "if (pm.response.code === 200) {",
          "    const response = pm.response.json();",
          "    pm.environment.set('access_token', response.access_token);",
          "    pm.environment.set('token_type', response.token_type);",
          "    pm.environment.set('expires_in', response.expires_in);",
          "    console.log('Authentication successful');",
          "} else {",
          "    console.log('Authentication failed:', pm.response.text());",
          "}"
        ]
      }
    }
  ]
}
```

### Token Refresh Request
```json
{
  "name": "Refresh Token",
  "request": {
    "method": "POST",
    "header": [
      {
        "key": "Authorization",
        "value": "Bearer {{access_token}}"
      }
    ],
    "url": {
      "raw": "{{auth_url}}/refresh",
      "host": ["{{auth_url}}"],
      "path": ["refresh"]
    }
  },
  "event": [
    {
      "listen": "test",
      "script": {
        "exec": [
          "if (pm.response.code === 200) {",
          "    const response = pm.response.json();",
          "    pm.environment.set('access_token', response.access_token);",
          "    console.log('Token refreshed successfully');",
          "} else {",
          "    console.log('Token refresh failed:', pm.response.text());",
          "}"
        ]
      }
    }
  ]
}
```

## Report API Requests

### Available Reports Request
```json
{
  "name": "Get Available Reports",
  "request": {
    "method": "GET",
    "header": [
      {
        "key": "Authorization",
        "value": "Bearer {{access_token}}"
      }
    ],
    "url": {
      "raw": "{{reports_url}}/data/available",
      "host": ["{{reports_url}}"],
      "path": ["data", "available"]
    }
  },
  "event": [
    {
      "listen": "test",
      "script": {
        "exec": [
          "pm.test('Status code is 200', function () {",
          "    pm.response.to.have.status(200);",
          "});",
          "",
          "pm.test('Response contains available reports', function () {",
          "    const response = pm.response.json();",
          "    pm.expect(response).to.have.property('reports');",
          "    pm.expect(response.reports).to.be.an('array');",
          "});"
        ]
      }
    }
  ]
}
```

### Balance Amount Report Request
```json
{
  "name": "Balance Amount Report - Tab A",
  "request": {
    "method": "POST",
    "header": [
      {
        "key": "Authorization",
        "value": "Bearer {{access_token}}"
      },
      {
        "key": "Content-Type",
        "value": "application/json"
      }
    ],
    "body": {
      "mode": "raw",
      "raw": "{\n  \"reportType\": \"BALANCE_AMOUNT\",\n  \"tab\": \"A\",\n  \"facilityCode\": \"{{facility_code}}\",\n  \"payerCodes\": [\"{{payer_code}}\"],\n  \"fromDate\": \"2024-01-01T00:00:00Z\",\n  \"toDate\": \"2024-12-31T23:59:59Z\",\n  \"page\": 0,\n  \"size\": 100\n}"
    },
    "url": {
      "raw": "{{reports_url}}/data/balance-amount",
      "host": ["{{reports_url}}"],
      "path": ["data", "balance-amount"]
    }
  },
  "event": [
    {
      "listen": "test",
      "script": {
        "exec": [
          "pm.test('Status code is 200', function () {",
          "    pm.response.to.have.status(200);",
          "});",
          "",
          "pm.test('Response contains report data', function () {",
          "    const response = pm.response.json();",
          "    pm.expect(response).to.have.property('data');",
          "    pm.expect(response).to.have.property('totalElements');",
          "    pm.expect(response).to.have.property('totalPages');",
          "});",
          "",
          "pm.test('Report data structure is correct', function () {",
          "    const response = pm.response.json();",
          "    if (response.data && response.data.length > 0) {",
          "        const firstItem = response.data[0];",
          "        pm.expect(firstItem).to.have.property('facilityCode');",
          "        pm.expect(firstItem).to.have.property('claimId');",
          "        pm.expect(firstItem).to.have.property('billedAmount');",
          "        pm.expect(firstItem).to.have.property('pendingAmount');",
          "    }",
          "});"
        ]
      }
    }
  ]
}
```

### Rejected Claims Report Request
```json
{
  "name": "Rejected Claims Report - Tab A",
  "request": {
    "method": "POST",
    "header": [
      {
        "key": "Authorization",
        "value": "Bearer {{access_token}}"
      },
      {
        "key": "Content-Type",
        "value": "application/json"
      }
    ],
    "body": {
      "mode": "raw",
      "raw": "{\n  \"reportType\": \"REJECTED_CLAIMS\",\n  \"tab\": \"A\",\n  \"facilityCode\": \"{{facility_code}}\",\n  \"payerCodes\": [\"{{payer_code}}\"],\n  \"fromDate\": \"2024-01-01T00:00:00Z\",\n  \"toDate\": \"2024-12-31T23:59:59Z\",\n  \"page\": 0,\n  \"size\": 100\n}"
    },
    "url": {
      "raw": "{{reports_url}}/data/rejected-claims",
      "host": ["{{reports_url}}"],
      "path": ["data", "rejected-claims"]
    }
  },
  "event": [
    {
      "listen": "test",
      "script": {
        "exec": [
          "pm.test('Status code is 200', function () {",
          "    pm.response.to.have.status(200);",
          "});",
          "",
          "pm.test('Response contains rejection data', function () {",
          "    const response = pm.response.json();",
          "    pm.expect(response).to.have.property('data');",
          "    pm.expect(response).to.have.property('totalElements');",
          "});"
        ]
      }
    }
  ]
}
```

### Claim Details with Activity Report Request
```json
{
  "name": "Claim Details with Activity Report",
  "request": {
    "method": "POST",
    "header": [
      {
        "key": "Authorization",
        "value": "Bearer {{access_token}}"
      },
      {
        "key": "Content-Type",
        "value": "application/json"
      }
    ],
    "body": {
      "mode": "raw",
      "raw": "{\n  \"reportType\": \"CLAIM_DETAILS_WITH_ACTIVITY\",\n  \"tab\": \"A\",\n  \"level\": \"activity\",\n  \"facilityCode\": \"{{facility_code}}\",\n  \"payerCodes\": [\"{{payer_code}}\"],\n  \"fromDate\": \"2024-01-01T00:00:00Z\",\n  \"toDate\": \"2024-12-31T23:59:59Z\",\n  \"page\": 0,\n  \"size\": 100\n}"
    },
    "url": {
      "raw": "{{reports_url}}/data/claim-details-with-activity",
      "host": ["{{reports_url}}"],
      "path": ["data", "claim-details-with-activity"]
    }
  }
}
```

### Doctor Denial Report Request
```json
{
  "name": "Doctor Denial Report - Tab A",
  "request": {
    "method": "POST",
    "header": [
      {
        "key": "Authorization",
        "value": "Bearer {{access_token}}"
      },
      {
        "key": "Content-Type",
        "value": "application/json"
      }
    ],
    "body": {
      "mode": "raw",
      "raw": "{\n  \"reportType\": \"DOCTOR_DENIAL\",\n  \"tab\": \"A\",\n  \"facilityCode\": \"{{facility_code}}\",\n  \"payerCodes\": [\"{{payer_code}}\"],\n  \"fromDate\": \"2024-01-01T00:00:00Z\",\n  \"toDate\": \"2024-12-31T23:59:59Z\",\n  \"denialThreshold\": 15.0,\n  \"page\": 0,\n  \"size\": 100\n}"
    },
    "url": {
      "raw": "{{reports_url}}/data/doctor-denial",
      "host": ["{{reports_url}}"],
      "path": ["data", "doctor-denial"]
    }
  }
}
```

### Claim Summary Monthwise Report Request
```json
{
  "name": "Claim Summary Monthwise Report - Tab A",
  "request": {
    "method": "POST",
    "header": [
      {
        "key": "Authorization",
        "value": "Bearer {{access_token}}"
      },
      {
        "key": "Content-Type",
        "value": "application/json"
      }
    ],
    "body": {
      "mode": "raw",
      "raw": "{\n  \"reportType\": \"CLAIM_SUMMARY_MONTHWISE\",\n  \"tab\": \"A\",\n  \"facilityCode\": \"{{facility_code}}\",\n  \"payerCodes\": [\"{{payer_code}}\"],\n  \"fromDate\": \"2024-01-01T00:00:00Z\",\n  \"toDate\": \"2024-12-31T23:59:59Z\",\n  \"page\": 0,\n  \"size\": 100\n}"
    },
    "url": {
      "raw": "{{reports_url}}/data/claim-summary-monthwise",
      "host": ["{{reports_url}}"],
      "path": ["data", "claim-summary-monthwise"]
    }
  }
}
```

### Remittance Advice Payerwise Report Request
```json
{
  "name": "Remittance Advice Payerwise Report - Tab A",
  "request": {
    "method": "POST",
    "header": [
      {
        "key": "Authorization",
        "value": "Bearer {{access_token}}"
      },
      {
        "key": "Content-Type",
        "value": "application/json"
      }
    ],
    "body": {
      "mode": "raw",
      "raw": "{\n  \"reportType\": \"REMITTANCE_ADVICE_PAYERWISE\",\n  \"tab\": \"A\",\n  \"facilityCode\": \"{{facility_code}}\",\n  \"payerCodes\": [\"{{payer_code}}\"],\n  \"fromDate\": \"2024-01-01T00:00:00Z\",\n  \"toDate\": \"2024-12-31T23:59:59Z\",\n  \"page\": 0,\n  \"size\": 100\n}"
    },
    "url": {
      "raw": "{{reports_url}}/data/remittance-advice-payerwise",
      "host": ["{{reports_url}}"],
      "path": ["data", "remittance-advice-payerwise"]
    }
  }
}
```

### Remittances Resubmission Report Request
```json
{
  "name": "Remittances Resubmission Report - Tab A",
  "request": {
    "method": "POST",
    "header": [
      {
        "key": "Authorization",
        "value": "Bearer {{access_token}}"
      },
      {
        "key": "Content-Type",
        "value": "application/json"
      }
    ],
    "body": {
      "mode": "raw",
      "raw": "{\n  \"reportType\": \"REMITTANCES_RESUBMISSION\",\n  \"tab\": \"A\",\n  \"facilityCode\": \"{{facility_code}}\",\n  \"payerCodes\": [\"{{payer_code}}\"],\n  \"fromDate\": \"2024-01-01T00:00:00Z\",\n  \"toDate\": \"2024-12-31T23:59:59Z\",\n  \"page\": 0,\n  \"size\": 100\n}"
    },
    "url": {
      "raw": "{{reports_url}}/data/remittances-resubmission",
      "host": ["{{reports_url}}"],
      "path": ["data", "remittances-resubmission"]
    }
  }
}
```

## Testing Scenarios

### Scenario 1: Basic Report Testing
```javascript
// Pre-request script for basic testing
pm.environment.set('test_start_time', Date.now());

// Test script for basic testing
pm.test('Response time is acceptable', function () {
    const responseTime = Date.now() - pm.environment.get('test_start_time');
    pm.expect(responseTime).to.be.below(5000); // 5 seconds max
});

pm.test('Response has correct content type', function () {
    pm.expect(pm.response.headers.get('Content-Type')).to.include('application/json');
});
```

### Scenario 2: Error Handling Testing
```javascript
// Test script for error handling
pm.test('Handles invalid facility code', function () {
    if (pm.response.code === 400) {
        const response = pm.response.json();
        pm.expect(response).to.have.property('message');
        pm.expect(response.message).to.include('facility');
    }
});

pm.test('Handles unauthorized access', function () {
    if (pm.response.code === 401) {
        pm.expect(pm.response.text()).to.include('unauthorized');
    }
});

pm.test('Handles forbidden access', function () {
    if (pm.response.code === 403) {
        pm.expect(pm.response.text()).to.include('forbidden');
    }
});
```

### Scenario 3: Performance Testing
```javascript
// Test script for performance testing
pm.test('Response time is within acceptable range', function () {
    const responseTime = pm.response.responseTime;
    
    // Different thresholds for different environments
    const maxResponseTime = pm.environment.get('base_url').includes('localhost') ? 10000 : 2000;
    
    pm.expect(responseTime).to.be.below(maxResponseTime);
});

pm.test('Response size is reasonable', function () {
    const responseSize = pm.response.responseSize;
    pm.expect(responseSize).to.be.below(1024 * 1024); // 1MB max
});
```

### Scenario 4: Data Validation Testing
```javascript
// Test script for data validation
pm.test('Report data structure is valid', function () {
    const response = pm.response.json();
    
    // Check required fields
    pm.expect(response).to.have.property('data');
    pm.expect(response).to.have.property('totalElements');
    pm.expect(response).to.have.property('totalPages');
    pm.expect(response).to.have.property('page');
    pm.expect(response).to.have.property('size');
    
    // Check data types
    pm.expect(response.data).to.be.an('array');
    pm.expect(response.totalElements).to.be.a('number');
    pm.expect(response.totalPages).to.be.a('number');
    pm.expect(response.page).to.be.a('number');
    pm.expect(response.size).to.be.a('number');
});

pm.test('Pagination data is consistent', function () {
    const response = pm.response.json();
    
    if (response.totalElements > 0) {
        pm.expect(response.totalPages).to.be.at.least(1);
        pm.expect(response.page).to.be.at.least(0);
        pm.expect(response.size).to.be.at.least(1);
        pm.expect(response.data.length).to.be.at.most(response.size);
    }
});
```

## Collection Runner

### Test Collection Configuration
```json
{
  "name": "Reports API Test Suite",
  "item": [
    {
      "name": "Authentication",
      "item": [
        {
          "name": "Login"
        },
        {
          "name": "Refresh Token"
        }
      ]
    },
    {
      "name": "Reports",
      "item": [
        {
          "name": "Get Available Reports"
        },
        {
          "name": "Balance Amount Report - Tab A"
        },
        {
          "name": "Rejected Claims Report - Tab A"
        },
        {
          "name": "Claim Details with Activity Report"
        },
        {
          "name": "Doctor Denial Report - Tab A"
        },
        {
          "name": "Claim Summary Monthwise Report - Tab A"
        },
        {
          "name": "Remittance Advice Payerwise Report - Tab A"
        },
        {
          "name": "Remittances Resubmission Report - Tab A"
        }
      ]
    }
  ],
  "event": [
    {
      "listen": "prerequest",
      "script": {
        "type": "text/javascript",
        "exec": [
          "// Global pre-request script",
          "console.log('Starting test run at:', new Date().toISOString());"
        ]
      }
    },
    {
      "listen": "test",
      "script": {
        "type": "text/javascript",
        "exec": [
          "// Global test script",
          "pm.test('Global test passed', function () {",
          "    pm.expect(true).to.be.true;",
          "});"
        ]
      }
    }
  ]
}
```

### Environment-Specific Test Runs

#### Local Development Test Run
```json
{
  "name": "Local Development Test Run",
  "environment": "Claims API - Local",
  "data": [
    {
      "facility_code": "FAC001",
      "payer_code": "PAYER001",
      "from_date": "2024-01-01T00:00:00Z",
      "to_date": "2024-12-31T23:59:59Z"
    }
  ],
  "options": {
    "delay": {
      "item": 1000
    },
    "iterationCount": 1,
    "stopOnError": false
  }
}
```

#### Production Test Run
```json
{
  "name": "Production Test Run",
  "environment": "Claims API - Production",
  "data": [
    {
      "facility_code": "FAC001",
      "payer_code": "PAYER001",
      "from_date": "2024-01-01T00:00:00Z",
      "to_date": "2024-12-31T23:59:59Z"
    }
  ],
  "options": {
    "delay": {
      "item": 2000
    },
    "iterationCount": 1,
    "stopOnError": true
  }
}
```

## Troubleshooting

### Common Issues

#### 1. Authentication Failures
**Symptoms**: 401 Unauthorized errors
**Solutions**:
- Check username and password in environment variables
- Verify token expiration
- Use refresh token request
- Check authentication endpoint URL

#### 2. Environment Variable Issues
**Symptoms**: Requests fail with undefined variables
**Solutions**:
- Verify environment is selected
- Check variable names match exactly
- Ensure variables are enabled
- Use double curly braces: `{{variable_name}}`

#### 3. Request Timeout Issues
**Symptoms**: Requests timeout or fail
**Solutions**:
- Increase timeout in Postman settings
- Check network connectivity
- Verify API endpoint URLs
- Check server status

#### 4. Data Validation Failures
**Symptoms**: Tests fail on data structure
**Solutions**:
- Check response format matches expectations
- Verify field names and types
- Check for null or undefined values
- Update test assertions

### Debugging Tips

#### Enable Console Logging
```javascript
// Add to pre-request or test scripts
console.log('Environment:', pm.environment.name);
console.log('Base URL:', pm.environment.get('base_url'));
console.log('Request URL:', pm.request.url.toString());
console.log('Request Headers:', pm.request.headers);
```

#### Response Debugging
```javascript
// Add to test scripts
console.log('Response Status:', pm.response.code);
console.log('Response Headers:', pm.response.headers);
console.log('Response Time:', pm.response.responseTime);
console.log('Response Size:', pm.response.responseSize);
console.log('Response Body:', pm.response.text());
```

#### Variable Debugging
```javascript
// Check all environment variables
pm.environment.each(function(key, value) {
    console.log(key + ': ' + value);
});
```

## Best Practices

### Collection Organization
1. **Group Related Requests**: Organize requests by functionality
2. **Use Descriptive Names**: Clear, descriptive request names
3. **Add Documentation**: Document each request and its purpose
4. **Use Folders**: Organize requests in logical folders
5. **Version Control**: Keep collections in version control

### Environment Management
1. **Separate Environments**: Use different environments for different stages
2. **Secure Credentials**: Use environment variables for sensitive data
3. **Document Variables**: Document what each variable is for
4. **Test Environments**: Test in staging before production
5. **Backup Environments**: Keep backup copies of environment configurations

### Testing Strategy
1. **Start with Authentication**: Always test authentication first
2. **Test Error Cases**: Test both success and error scenarios
3. **Validate Responses**: Check response structure and data types
4. **Test Performance**: Monitor response times and sizes
5. **Automate Testing**: Use collection runner for automated testing

### Security Considerations
1. **Secure Credentials**: Never hardcode credentials in requests
2. **Use Environment Variables**: Store sensitive data in environment variables
3. **Rotate Tokens**: Regularly rotate authentication tokens
4. **Test Security**: Test authentication and authorization
5. **Monitor Access**: Monitor API access and usage

## Related Documentation
- [API Reference](./REPORT_API_REFERENCE.md)
- [API Authentication Guide](./API_AUTHENTICATION_GUIDE.md)
- [API Error Codes](./API_ERROR_CODES.md)
- [Frontend Integration Guide](./FRONTEND_INTEGRATION_GUIDE.md)
- [Environment Behavior Guide](../reports/ENVIRONMENT_BEHAVIOR_GUIDE.md)
