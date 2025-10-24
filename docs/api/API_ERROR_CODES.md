# API Error Codes

This document provides comprehensive documentation of all API error codes used in the Claims Backend system, including error descriptions, causes, and resolution steps.

## Overview

This document covers:
- **Error Code Categories**: Authentication, validation, business logic, and system errors
- **Error Response Format**: Standardized error response structure
- **Environment-Specific Errors**: Different error behaviors across environments
- **Troubleshooting**: Common error scenarios and solutions
- **Error Handling**: Best practices for error handling

---

## Error Response Format

### Standard Error Response

**Error Response Structure**:
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
    },
    "timestamp": "2025-01-15T10:30:00Z",
    "requestId": "req-12345"
  }
}
```

**Error Response Fields**:
- `success`: Always `false` for error responses
- `error.code`: Machine-readable error code
- `error.message`: Human-readable error message
- `error.details`: Additional error information
- `error.timestamp`: Timestamp when error occurred
- `error.requestId`: Unique request identifier

---

## Error Code Categories

### Authentication Errors (AUTH_*)

**AUTH_INVALID_TOKEN**
- **Description**: JWT token is invalid or malformed
- **HTTP Status**: 401 Unauthorized
- **Causes**: Malformed token, wrong signature, invalid format
- **Resolution**: Verify token format and signature

**AUTH_TOKEN_EXPIRED**
- **Description**: JWT token has expired
- **HTTP Status**: 401 Unauthorized
- **Causes**: Token past expiration time
- **Resolution**: Refresh token or obtain new token

**AUTH_TOKEN_MISSING**
- **Description**: JWT token is missing from request
- **HTTP Status**: 401 Unauthorized
- **Causes**: No Authorization header, missing Bearer token
- **Resolution**: Include valid JWT token in Authorization header

**AUTH_INVALID_ISSUER**
- **Description**: JWT token issuer is invalid
- **HTTP Status**: 401 Unauthorized
- **Causes**: Wrong issuer in token claims
- **Resolution**: Verify token issuer matches expected value

**AUTH_INVALID_AUDIENCE**
- **Description**: JWT token audience is invalid
- **HTTP Status**: 401 Unauthorized
- **Causes**: Wrong audience in token claims
- **Resolution**: Verify token audience matches expected value

**AUTH_INSUFFICIENT_PERMISSIONS**
- **Description**: User lacks required permissions
- **HTTP Status**: 403 Forbidden
- **Causes**: Insufficient role or permissions
- **Resolution**: Verify user has required role or permissions

### Validation Errors (VALIDATION_*)

**VALIDATION_REQUIRED_FIELD**
- **Description**: Required field is missing
- **HTTP Status**: 400 Bad Request
- **Causes**: Missing required field in request
- **Resolution**: Include all required fields in request

**VALIDATION_INVALID_FORMAT**
- **Description**: Field format is invalid
- **HTTP Status**: 400 Bad Request
- **Causes**: Field value doesn't match expected format
- **Resolution**: Verify field format matches requirements

**VALIDATION_OUT_OF_RANGE**
- **Description**: Field value is out of allowed range
- **HTTP Status**: 400 Bad Request
- **Causes**: Field value exceeds min/max limits
- **Resolution**: Ensure field value is within allowed range

**VALIDATION_INVALID_DATE_RANGE**
- **Description**: Date range is invalid
- **HTTP Status**: 400 Bad Request
- **Causes**: From date is after to date
- **Resolution**: Ensure from date is before to date

**VALIDATION_INVALID_ENUM_VALUE**
- **Description**: Enum field has invalid value
- **HTTP Status**: 400 Bad Request
- **Causes**: Field value not in allowed enum values
- **Resolution**: Use only allowed enum values

### Business Logic Errors (BUSINESS_*)

**BUSINESS_FACILITY_NOT_FOUND**
- **Description**: Specified facility not found
- **HTTP Status**: 404 Not Found
- **Causes**: Invalid facility code or facility doesn't exist
- **Resolution**: Verify facility code exists and is accessible

**BUSINESS_PAYER_NOT_FOUND**
- **Description**: Specified payer not found
- **HTTP Status**: 404 Not Found
- **Causes**: Invalid payer code or payer doesn't exist
- **Resolution**: Verify payer code exists and is accessible

**BUSINESS_NO_DATA_FOUND**
- **Description**: No data found for specified criteria
- **HTTP Status**: 404 Not Found
- **Causes**: No data matches search criteria
- **Resolution**: Adjust search criteria or verify data exists

**BUSINESS_ACCESS_DENIED**
- **Description**: Access denied to requested resource
- **HTTP Status**: 403 Forbidden
- **Causes**: User doesn't have access to resource
- **Resolution**: Verify user has access to requested resource

**BUSINESS_CROSS_FACILITY_ACCESS**
- **Description**: Cross-facility access denied
- **HTTP Status**: 403 Forbidden
- **Causes**: User trying to access data from different facility
- **Resolution**: Verify user has access to requested facility

### System Errors (SYSTEM_*)

**SYSTEM_DATABASE_ERROR**
- **Description**: Database operation failed
- **HTTP Status**: 500 Internal Server Error
- **Causes**: Database connection issues, query failures
- **Resolution**: Check database connectivity and query syntax

**SYSTEM_EXTERNAL_SERVICE_ERROR**
- **Description**: External service unavailable
- **HTTP Status**: 503 Service Unavailable
- **Causes**: External service down or unreachable
- **Resolution**: Check external service status and connectivity

**SYSTEM_MATERIALIZED_VIEW_ERROR**
- **Description**: Materialized view operation failed
- **HTTP Status**: 500 Internal Server Error
- **Causes**: MV refresh failure, MV corruption
- **Resolution**: Check materialized view status and refresh

**SYSTEM_CONFIGURATION_ERROR**
- **Description**: System configuration error
- **HTTP Status**: 500 Internal Server Error
- **Causes**: Invalid configuration, missing configuration
- **Resolution**: Verify system configuration is correct

**SYSTEM_MEMORY_ERROR**
- **Description**: Insufficient memory for operation
- **HTTP Status**: 507 Insufficient Storage
- **Causes**: High memory usage, memory leak
- **Resolution**: Check system memory usage and optimize queries

### Report Errors (REPORT_*)

**REPORT_EXECUTION_ERROR**
- **Description**: Report execution failed
- **HTTP Status**: 500 Internal Server Error
- **Causes**: Query execution failure, data processing error
- **Resolution**: Check report query and data availability

**REPORT_TIMEOUT_ERROR**
- **Description**: Report execution timed out
- **HTTP Status**: 504 Gateway Timeout
- **Causes**: Long-running query, system overload
- **Resolution**: Optimize query or increase timeout limits

**REPORT_DATA_ERROR**
- **Description**: Report data processing error
- **HTTP Status**: 500 Internal Server Error
- **Causes**: Data corruption, invalid data format
- **Resolution**: Check data integrity and format

**REPORT_EXPORT_ERROR**
- **Description**: Report export failed
- **HTTP Status**: 500 Internal Server Error
- **Causes**: Export format error, file generation failure
- **Resolution**: Check export format and file system access

---

## Environment-Specific Error Behavior

### Local Development Environment

**Error Behavior**:
- Detailed error messages
- Stack traces included
- Debug information provided
- No sensitive data masking
- Relaxed validation

**Example Error Response**:
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
      "stackTrace": "java.time.format.DateTimeParseException: ...",
      "timestamp": "2025-01-15T10:30:00Z"
    }
  }
}
```

### Staging Environment

**Error Behavior**:
- Standard error messages
- No stack traces
- Limited debug information
- Basic sensitive data masking
- Standard validation

**Example Error Response**:
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

### Production Environment

**Error Behavior**:
- Generic error messages
- No stack traces
- No debug information
- Full sensitive data masking
- Strict validation

**Example Error Response**:
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_INVALID_FORMAT",
    "message": "Invalid request format",
    "details": {
      "timestamp": "2025-01-15T10:30:00Z"
    }
  }
}
```

---

## Error Handling Implementation

### Global Exception Handler

**Exception Handler Implementation**:
```java
@ControllerAdvice
public class GlobalExceptionHandler {
    
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationException(MethodArgumentNotValidException e) {
        List<FieldError> fieldErrors = e.getBindingResult().getFieldErrors();
        Map<String, String> validationErrors = new HashMap<>();
        
        for (FieldError fieldError : fieldErrors) {
            validationErrors.put(fieldError.getField(), fieldError.getDefaultMessage());
        }
        
        ErrorResponse error = ErrorResponse.builder()
            .code("VALIDATION_ERROR")
            .message("Validation failed")
            .details(validationErrors)
            .timestamp(Instant.now().toString())
            .build();
        
        return ResponseEntity.badRequest().body(error);
    }
    
    @ExceptionHandler(JwtException.class)
    public ResponseEntity<ErrorResponse> handleJwtException(JwtException e) {
        ErrorResponse error = ErrorResponse.builder()
            .code("AUTH_INVALID_TOKEN")
            .message("Invalid JWT token")
            .details(Map.of("error", e.getMessage()))
            .timestamp(Instant.now().toString())
            .build();
        
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(error);
    }
    
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ErrorResponse> handleAccessDeniedException(AccessDeniedException e) {
        ErrorResponse error = ErrorResponse.builder()
            .code("AUTH_INSUFFICIENT_PERMISSIONS")
            .message("Insufficient permissions")
            .details(Map.of("error", e.getMessage()))
            .timestamp(Instant.now().toString())
            .build();
        
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(error);
    }
    
    @ExceptionHandler(ReportExecutionException.class)
    public ResponseEntity<ErrorResponse> handleReportExecutionException(ReportExecutionException e) {
        ErrorResponse error = ErrorResponse.builder()
            .code("REPORT_EXECUTION_ERROR")
            .message("Report execution failed")
            .details(Map.of("error", e.getMessage()))
            .timestamp(Instant.now().toString())
            .build();
        
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
    }
    
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGenericException(Exception e) {
        ErrorResponse error = ErrorResponse.builder()
            .code("SYSTEM_ERROR")
            .message("Internal server error")
            .details(Map.of("error", e.getMessage()))
            .timestamp(Instant.now().toString())
            .build();
        
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
    }
}
```

### Custom Exception Classes

**Report Execution Exception**:
```java
public class ReportExecutionException extends RuntimeException {
    private final String errorCode;
    private final Map<String, Object> details;
    
    public ReportExecutionException(String message, String errorCode) {
        super(message);
        this.errorCode = errorCode;
        this.details = new HashMap<>();
    }
    
    public ReportExecutionException(String message, String errorCode, Map<String, Object> details) {
        super(message);
        this.errorCode = errorCode;
        this.details = details;
    }
    
    public String getErrorCode() {
        return errorCode;
    }
    
    public Map<String, Object> getDetails() {
        return details;
    }
}
```

**Validation Exception**:
```java
public class ValidationException extends RuntimeException {
    private final String field;
    private final String value;
    private final String constraint;
    
    public ValidationException(String message, String field, String value, String constraint) {
        super(message);
        this.field = field;
        this.value = value;
        this.constraint = constraint;
    }
    
    public String getField() {
        return field;
    }
    
    public String getValue() {
        return value;
    }
    
    public String getConstraint() {
        return constraint;
    }
}
```

---

## Error Code Reference

### Complete Error Code List

| Error Code | HTTP Status | Description | Category |
|------------|-------------|-------------|----------|
| `AUTH_INVALID_TOKEN` | 401 | Invalid JWT token | Authentication |
| `AUTH_TOKEN_EXPIRED` | 401 | JWT token expired | Authentication |
| `AUTH_TOKEN_MISSING` | 401 | JWT token missing | Authentication |
| `AUTH_INVALID_ISSUER` | 401 | Invalid token issuer | Authentication |
| `AUTH_INVALID_AUDIENCE` | 401 | Invalid token audience | Authentication |
| `AUTH_INSUFFICIENT_PERMISSIONS` | 403 | Insufficient permissions | Authentication |
| `VALIDATION_REQUIRED_FIELD` | 400 | Required field missing | Validation |
| `VALIDATION_INVALID_FORMAT` | 400 | Invalid field format | Validation |
| `VALIDATION_OUT_OF_RANGE` | 400 | Field value out of range | Validation |
| `VALIDATION_INVALID_DATE_RANGE` | 400 | Invalid date range | Validation |
| `VALIDATION_INVALID_ENUM_VALUE` | 400 | Invalid enum value | Validation |
| `BUSINESS_FACILITY_NOT_FOUND` | 404 | Facility not found | Business Logic |
| `BUSINESS_PAYER_NOT_FOUND` | 404 | Payer not found | Business Logic |
| `BUSINESS_NO_DATA_FOUND` | 404 | No data found | Business Logic |
| `BUSINESS_ACCESS_DENIED` | 403 | Access denied | Business Logic |
| `BUSINESS_CROSS_FACILITY_ACCESS` | 403 | Cross-facility access denied | Business Logic |
| `SYSTEM_DATABASE_ERROR` | 500 | Database operation failed | System |
| `SYSTEM_EXTERNAL_SERVICE_ERROR` | 503 | External service unavailable | System |
| `SYSTEM_MATERIALIZED_VIEW_ERROR` | 500 | Materialized view error | System |
| `SYSTEM_CONFIGURATION_ERROR` | 500 | Configuration error | System |
| `SYSTEM_MEMORY_ERROR` | 507 | Insufficient memory | System |
| `REPORT_EXECUTION_ERROR` | 500 | Report execution failed | Report |
| `REPORT_TIMEOUT_ERROR` | 504 | Report execution timeout | Report |
| `REPORT_DATA_ERROR` | 500 | Report data processing error | Report |
| `REPORT_EXPORT_ERROR` | 500 | Report export failed | Report |

---

## Troubleshooting

### Common Error Scenarios

**Scenario 1: Authentication Failures**
**Symptoms**: 401 Unauthorized errors
**Common Causes**: Invalid token, expired token, missing token
**Resolution Steps**:
1. Check token format and validity
2. Verify token expiration
3. Ensure token is included in Authorization header
4. Verify token issuer and audience

**Scenario 2: Validation Failures**
**Symptoms**: 400 Bad Request errors
**Common Causes**: Missing required fields, invalid field formats
**Resolution Steps**:
1. Check request payload structure
2. Verify all required fields are present
3. Validate field formats and values
4. Check field constraints and limits

**Scenario 3: Business Logic Failures**
**Symptoms**: 403 Forbidden or 404 Not Found errors
**Common Causes**: Insufficient permissions, resource not found
**Resolution Steps**:
1. Verify user permissions and roles
2. Check resource existence and accessibility
3. Validate facility access rights
4. Ensure proper data filtering

**Scenario 4: System Failures**
**Symptoms**: 500 Internal Server Error
**Common Causes**: Database issues, external service failures
**Resolution Steps**:
1. Check database connectivity and status
2. Verify external service availability
3. Check system configuration
4. Monitor system resources

### Error Debugging Commands

**Check Authentication Status**:
```bash
# Test authentication endpoint
curl -H "Authorization: Bearer <token>" \
     http://localhost:8080/api/reports/data/available

# Check authentication logs
tail -f logs/application.log | grep "AUTHENTICATION"
```

**Check Validation Errors**:
```bash
# Test validation endpoint
curl -X POST http://localhost:8080/api/reports/data/balance-amount \
  -H "Content-Type: application/json" \
  -d '{"reportType":"BALANCE_AMOUNT_REPORT"}'

# Check validation logs
tail -f logs/application.log | grep "VALIDATION"
```

**Check System Status**:
```bash
# Check application health
curl http://localhost:8080/actuator/health

# Check database health
curl http://localhost:8080/actuator/health/db

# Check system metrics
curl http://localhost:8080/actuator/metrics
```

---

## Best Practices

### Error Handling Best Practices

1. **Consistent Error Format**: Use standardized error response format
2. **Meaningful Error Codes**: Use descriptive, machine-readable error codes
3. **User-Friendly Messages**: Provide clear, actionable error messages
4. **Appropriate HTTP Status**: Use correct HTTP status codes
5. **Error Logging**: Log all errors for debugging and monitoring

### Environment-Specific Best Practices

**Local Development**:
- Provide detailed error information
- Include stack traces for debugging
- Enable debug logging
- Use relaxed validation

**Staging Environment**:
- Use standard error messages
- Include limited debug information
- Enable standard logging
- Use standard validation

**Production Environment**:
- Use generic error messages
- Mask sensitive information
- Enable comprehensive logging
- Use strict validation

---

## Related Documentation

- [API Authentication Guide](API_AUTHENTICATION_GUIDE.md) - Authentication implementation
- [Security Matrix](SECURITY_MATRIX.md) - Security error handling
- [Environment Behavior Guide](ENVIRONMENT_BEHAVIOR_GUIDE.md) - Environment-specific behavior
- [Testing Guide](TESTING_GUIDE.md) - Error testing procedures
- [Validation Checklist](VALIDATION_CHECKLIST.md) - Validation procedures
