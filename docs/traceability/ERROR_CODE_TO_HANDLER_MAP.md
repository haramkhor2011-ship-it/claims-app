# Error Code to Handler Map - Claims Backend Application

> Traceability matrix mapping error codes to their handling locations in the codebase. Use this to understand where errors are caught, how they're logged, and what recovery logic is implemented.

## Overview

This document provides a comprehensive mapping between error codes and their handling locations in the claims-backend application. It helps developers understand error handling patterns, recovery mechanisms, and debugging approaches.

---

## Error Categories

### 1. Parse Errors

**Error Codes**: `PARSE_*`

**Error Types**:
- `PARSE_XML_SYNTAX` - XML syntax errors
- `PARSE_XSD_VALIDATION` - XSD schema validation errors
- `PARSE_MEMORY` - Memory issues during parsing
- `PARSE_ENCODING` - Character encoding errors

**Handling Locations**:
- **Main Handler**: `com.acme.claims.ingestion.parser.ClaimXmlParserStax`
- **Error Logger**: `com.acme.claims.ingestion.audit.ErrorLogger`
- **Pipeline**: `com.acme.claims.ingestion.Pipeline`

**Implementation**:
```java
// ClaimXmlParserStax.parse()
public ParseOutcome parse(IngestionFile file) {
    try {
        XMLStreamReader reader = factory.createXMLStreamReader(
            new ByteArrayInputStream(file.getXmlBytes()));
        
        // Parse XML content
        return parseContent(reader, file);
        
    } catch (XMLStreamException e) {
        // Log parse error
        errorLogger.fileError(file.getId(), "PARSE", "PARSE_XML_SYNTAX",
            "XML syntax error: " + e.getMessage(), false);
        throw new ParseException("XML parsing failed", e);
    } catch (OutOfMemoryError e) {
        // Log memory error
        errorLogger.fileError(file.getId(), "PARSE", "PARSE_MEMORY",
            "Out of memory during parsing", false);
        throw new ParseException("Memory error during parsing", e);
    }
}
```

**Recovery Logic**:
- Parse errors → File marked as failed, processing continues
- Memory errors → JVM handles, application may restart
- Encoding errors → File skipped, error logged

**Database Storage**:
- `ingestion_error` table with error details
- `ingestion_file` table with status update

---

### 2. Validation Errors

**Error Codes**: `VALIDATE_*`

**Error Types**:
- `VALIDATE_HEADER_MISSING` - Missing required header fields
- `VALIDATE_CLAIM_MISSING` - Missing required claim fields
- `VALIDATE_BUSINESS_RULES` - Business rule violations
- `VALIDATE_DATA_FORMAT` - Data format errors

**Handling Locations**:
- **Main Handler**: `com.acme.claims.ingestion.Pipeline`
- **Validation Methods**: `Pipeline.validateSubmission()`, `Pipeline.validateRemittance()`
- **Error Logger**: `com.acme.claims.ingestion.audit.ErrorLogger`

**Implementation**:
```java
// Pipeline.validateSubmission()
private static void validateSubmission(SubmissionDTO dto) {
    try {
        req(dto.header(), "Header");
        req(dto.header().senderId(), "Header.SenderID");
        req(dto.header().receiverId(), "Header.ReceiverID");
        req(dto.header().transactionDate(), "Header.TransactionDate");
        req(dto.header().dispositionFlag(), "Header.DispositionFlag");
        
        if (dto.claims() == null || dto.claims().isEmpty()) {
            throw new IllegalArgumentException("No claims in submission");
        }
        
        for (var c : dto.claims()) {
            req(c.id(), "Claim.ID");
            req(c.payerId(), "Claim.PayerID");
            req(c.providerId(), "Claim.ProviderID");
            req(c.emiratesIdNumber(), "Claim.EmiratesIDNumber");
        }
        
    } catch (IllegalArgumentException e) {
        // Log validation error
        errorLogger.fileError(fileId, "VALIDATE", "VALIDATE_BUSINESS_RULES",
            e.getMessage(), false);
        throw e;
    }
}
```

**Recovery Logic**:
- Validation errors → File processing stops, error logged
- Business rule violations → File rejected, processing continues
- Data format errors → File skipped, error logged

**Database Storage**:
- `ingestion_error` table with validation details
- `ingestion_file` table with status update

---

### 3. Database Errors

**Error Codes**: `DB_*`

**Error Types**:
- `DB_CONSTRAINT_VIOLATION` - Database constraint violations
- `DB_CONNECTION_FAILED` - Database connection failures
- `DB_TRANSACTION_FAILED` - Transaction failures
- `DB_QUERY_TIMEOUT` - Query timeout errors

**Handling Locations**:
- **Main Handler**: `com.acme.claims.ingestion.persist.PersistService`
- **Transaction Management**: `@Transactional` annotations
- **Error Logger**: `com.acme.claims.ingestion.audit.ErrorLogger`
- **Global Handler**: `com.acme.claims.controller.GlobalExceptionHandler`

**Implementation**:
```java
// PersistService.persistSubmission()
@Transactional(propagation = Propagation.REQUIRES_NEW)
public PersistCounts persistSubmission(Long ingestionFileId, 
                                     SubmissionDTO dto, 
                                     List<AttachmentDto> attachments) {
    try {
        // Persist submission data
        Submission submission = submissionMapper.toEntity(dto);
        submission.setIngestionFileId(ingestionFileId);
        submission = submissionRepository.save(submission);
        
        // Process claims
        int claimCount = 0;
        for (SubmissionClaimDto claimDto : dto.claims()) {
            Claim claim = claimMapper.toEntity(claimDto);
            claim.setSubmissionId(submission.getId());
            claim = claimRepository.save(claim);
            claimCount++;
        }
        
        return new PersistCounts(claimCount, 0);
        
    } catch (DataIntegrityViolationException e) {
        // Log constraint violation
        errorLogger.fileError(ingestionFileId, "PERSIST", "DB_CONSTRAINT_VIOLATION",
            "Database constraint violation: " + e.getMessage(), false);
        throw new PersistenceException("Database constraint violation", e);
    } catch (DataAccessException e) {
        // Log database error
        errorLogger.fileError(ingestionFileId, "PERSIST", "DB_CONNECTION_FAILED",
            "Database error: " + e.getMessage(), false);
        throw new PersistenceException("Database error", e);
    }
}
```

**Recovery Logic**:
- Constraint violations → Transaction rollback, error logged
- Connection failures → Retry logic, circuit breaker
- Transaction failures → Rollback, error logged
- Query timeouts → Retry with exponential backoff

**Database Storage**:
- `ingestion_error` table with database error details
- Transaction rollback for failed operations

---

### 4. SOAP Errors

**Error Codes**: `SOAP_*`

**Error Types**:
- `SOAP_AUTHENTICATION_FAILED` - Authentication failures
- `SOAP_NETWORK_ERROR` - Network connectivity issues
- `SOAP_TIMEOUT` - SOAP call timeouts
- `SOAP_FAULT` - SOAP fault responses

**Handling Locations**:
- **Main Handler**: `com.acme.claims.soap.client.DhpoSoapClient`
- **Fetch Coordinator**: `com.acme.claims.soap.fetch.DhpoFetchCoordinator`
- **Error Logger**: `com.acme.claims.ingestion.audit.ErrorLogger`
- **Circuit Breaker**: `com.acme.claims.monitoring.CircuitBreakerService`

**Implementation**:
```java
// DhpoSoapClient.sendRequest()
public String sendRequest(String endpoint, String request, String username, String password) {
    try {
        // Build SOAP request
        String soapRequest = buildSoapRequest(request, username, password);
        
        // Send HTTP request
        HttpResponse<String> response = httpClient.send(
            HttpRequest.newBuilder()
                .uri(URI.create(endpoint))
                .header("Content-Type", "text/xml")
                .POST(HttpRequest.BodyPublishers.ofString(soapRequest))
                .timeout(Duration.ofSeconds(30))
                .build(),
            HttpResponse.BodyHandlers.ofString()
        );
        
        // Check response status
        if (response.statusCode() != 200) {
            throw new SoapException("HTTP error: " + response.statusCode());
        }
        
        return response.body();
        
    } catch (HttpTimeoutException e) {
        // Log timeout error
        errorLogger.logError("SOAP", "SOAP_TIMEOUT",
            "SOAP call timeout: " + e.getMessage(), false);
        throw new SoapException("SOAP call timeout", e);
    } catch (IOException e) {
        // Log network error
        errorLogger.logError("SOAP", "SOAP_NETWORK_ERROR",
            "Network error: " + e.getMessage(), false);
        throw new SoapException("Network error", e);
    } catch (SoapException e) {
        // Log SOAP fault
        errorLogger.logError("SOAP", "SOAP_FAULT",
            "SOAP fault: " + e.getMessage(), false);
        throw e;
    }
}
```

**Recovery Logic**:
- Authentication failures → Credential rotation, retry
- Network errors → Retry with exponential backoff
- Timeouts → Retry with increased timeout
- SOAP faults → Error logged, processing continues

**Database Storage**:
- `ingestion_error` table with SOAP error details
- `facility_credential` table for credential management

---

### 5. Security Errors

**Error Codes**: `SECURITY_*`

**Error Types**:
- `SECURITY_JWT_INVALID` - Invalid JWT tokens
- `SECURITY_ACCESS_DENIED` - Access denied errors
- `SECURITY_FACILITY_MISMATCH` - Facility context mismatches
- `SECURITY_RATE_LIMIT_EXCEEDED` - Rate limit exceeded

**Handling Locations**:
- **Main Handler**: `com.acme.claims.security.filter.JwtAuthenticationFilter`
- **Security Service**: `com.acme.claims.security.service.SecurityContextService`
- **Rate Limiter**: `com.acme.claims.ratelimit.RateLimitInterceptor`
- **Global Handler**: `com.acme.claims.controller.GlobalExceptionHandler`

**Implementation**:
```java
// JwtAuthenticationFilter.doFilter()
public void doFilter(ServletRequest request, ServletResponse response, 
                    FilterChain filterChain) throws IOException, ServletException {
    try {
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        String token = extractToken(httpRequest);
        
        if (token != null) {
            // Validate JWT token
            Claims claims = jwtTokenProvider.validateToken(token);
            
            // Set authentication context
            Authentication authentication = new JwtAuthenticationToken(claims);
            SecurityContextHolder.getContext().setAuthentication(authentication);
        }
        
        filterChain.doFilter(request, response);
        
    } catch (JwtException e) {
        // Log JWT error
        log.error("JWT validation failed", e);
        ((HttpServletResponse) response).setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        return;
    } catch (Exception e) {
        // Log security error
        log.error("Security filter error", e);
        ((HttpServletResponse) response).setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
        return;
    }
}
```

**Recovery Logic**:
- Invalid JWT → 401 Unauthorized, token refresh required
- Access denied → 403 Forbidden, role upgrade required
- Facility mismatch → 403 Forbidden, facility context correction
- Rate limit exceeded → 429 Too Many Requests, retry after delay

**Database Storage**:
- Security errors logged to application logs
- No database storage for security errors

---

### 6. Report Generation Errors

**Error Codes**: `REPORT_*`

**Error Types**:
- `REPORT_VALIDATION_FAILED` - Report parameter validation failures
- `REPORT_QUERY_FAILED` - SQL query failures
- `REPORT_TIMEOUT` - Report generation timeouts
- `REPORT_ACCESS_DENIED` - Report access denied

**Handling Locations**:
- **Main Handler**: `com.acme.claims.controller.ReportDataController`
- **Report Services**: Various `*ReportService` classes
- **Validator**: `com.acme.claims.validation.ReportRequestValidator`
- **Global Handler**: `com.acme.claims.controller.GlobalExceptionHandler`

**Implementation**:
```java
// ReportDataController.generateReport()
@PostMapping("/reports/generate")
public ResponseEntity<ReportResponse> generateReport(
    @Valid @RequestBody ReportRequest request,
    HttpServletRequest httpRequest) {
    
    try {
        // Validate request
        ReportRequestValidator validator = new ReportRequestValidator();
        validator.validate(request, facilityId, userRoles);
        
        // Generate report
        ReportService reportService = getReportService(request.getReportType());
        ReportResult result = reportService.generateReport(request, facilityId);
        
        // Format response
        ReportResponse response = formatResponse(result, request);
        return ResponseEntity.ok(response);
        
    } catch (ValidationException e) {
        // Log validation error
        log.error("Report validation failed", e);
        return ResponseEntity.badRequest()
            .body(ReportResponse.error("Validation failed: " + e.getMessage()));
    } catch (AccessDeniedException e) {
        // Log access denied error
        log.error("Report access denied", e);
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
            .body(ReportResponse.error("Access denied: " + e.getMessage()));
    } catch (Exception e) {
        // Log system error
        log.error("Report generation failed", e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(ReportResponse.error("Report generation failed"));
    }
}
```

**Recovery Logic**:
- Validation failures → 400 Bad Request, parameter correction required
- Query failures → 500 Internal Server Error, database investigation
- Timeouts → 500 Internal Server Error, query optimization
- Access denied → 403 Forbidden, permission upgrade required

**Database Storage**:
- Report errors logged to application logs
- No database storage for report errors

---

## Error Handling Patterns

### 1. Centralized Error Logging

**Pattern**: All errors are logged through a central error logger.

**Implementation**:
```java
@Component
public class ErrorLogger {
    
    public void fileError(Long fileId, String stage, String errorCode, 
                         String message, boolean isRetryable) {
        // Log to database
        jdbcTemplate.update("""
            INSERT INTO ingestion_error 
            (ingestion_file_id, stage, error_code, message, is_retryable, created_at)
            VALUES (?, ?, ?, ?, ?, now())
            """, fileId, stage, errorCode, message, isRetryable);
        
        // Log to application logs
        log.error("File processing error: fileId={} stage={} code={} message={}", 
                 fileId, stage, errorCode, message);
    }
    
    public void logError(String component, String errorCode, 
                        String message, boolean isRetryable) {
        // Log to application logs
        log.error("Component error: component={} code={} message={}", 
                 component, errorCode, message);
    }
}
```

### 2. Transaction Boundary Error Handling

**Pattern**: Errors at transaction boundaries are handled with proper rollback.

**Implementation**:
```java
@Transactional(propagation = Propagation.REQUIRES_NEW)
public void persistData(Data data) {
    try {
        // Persist data
        repository.save(data);
        
    } catch (DataAccessException e) {
        // Transaction will rollback automatically
        errorLogger.logError("PERSIST", "DB_ERROR", e.getMessage(), false);
        throw new PersistenceException("Database error", e);
    }
}
```

### 3. Retry Logic with Exponential Backoff

**Pattern**: Transient errors are retried with exponential backoff.

**Implementation**:
```java
@Retryable(
    value = {SoapException.class, NetworkException.class},
    maxAttempts = 3,
    backoff = @Backoff(delay = 1000, multiplier = 2)
)
public String callExternalService(String request) {
    try {
        return externalService.call(request);
    } catch (SoapException e) {
        errorLogger.logError("SOAP", "SOAP_ERROR", e.getMessage(), true);
        throw e;
    }
}
```

### 4. Circuit Breaker Pattern

**Pattern**: Circuit breaker prevents cascading failures.

**Implementation**:
```java
@Component
public class CircuitBreakerService {
    
    private final CircuitBreaker circuitBreaker;
    
    public CircuitBreakerService() {
        this.circuitBreaker = CircuitBreaker.ofDefaults("external-service")
            .toBuilder()
            .failureRateThreshold(50)
            .waitDurationInOpenState(Duration.ofMinutes(1))
            .build();
    }
    
    public String callWithCircuitBreaker(Supplier<String> operation) {
        return circuitBreaker.executeSupplier(operation);
    }
}
```

---

## Error Recovery Strategies

### 1. File-Level Recovery

**Strategy**: Individual file failures don't stop processing of other files.

**Implementation**:
```java
public void processFiles(List<WorkItem> files) {
    for (WorkItem file : files) {
        try {
            processFile(file);
        } catch (Exception e) {
            // Log error but continue processing
            errorLogger.fileError(file.getId(), "PROCESS", "FILE_ERROR", 
                e.getMessage(), false);
        }
    }
}
```

### 2. System-Level Recovery

**Strategy**: Application restart recovery and resource cleanup.

**Implementation**:
```java
@Component
public class SystemRecoveryService {
    
    @EventListener
    public void handleApplicationReady(ApplicationReadyEvent event) {
        // Clean up any incomplete processing
        cleanupIncompleteProcessing();
        
        // Restart failed operations
        restartFailedOperations();
    }
    
    private void cleanupIncompleteProcessing() {
        // Clean up incomplete transactions
        // Reset failed file statuses
        // Clear temporary data
    }
}
```

### 3. Data Recovery

**Strategy**: Data integrity recovery and orphan cleanup.

**Implementation**:
```java
@Service
public class DataRecoveryService {
    
    public void recoverDataIntegrity() {
        // Clean up orphaned records
        cleanupOrphanedRecords();
        
        // Fix data inconsistencies
        fixDataInconsistencies();
        
        // Rebuild indexes
        rebuildIndexes();
    }
}
```

---

## Error Monitoring and Alerting

### 1. Error Metrics

**Metrics**: Error rates, error types, recovery times.

**Implementation**:
```java
@Component
public class ErrorMetrics {
    
    private final MeterRegistry meterRegistry;
    private final Counter errorCounter;
    private final Timer recoveryTimer;
    
    public ErrorMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
        this.errorCounter = Counter.builder("app.errors.total")
            .register(meterRegistry);
        this.recoveryTimer = Timer.builder("app.errors.recovery.time")
            .register(meterRegistry);
    }
    
    public void recordError(String errorType) {
        errorCounter.increment(Tags.of("type", errorType));
    }
    
    public void recordRecoveryTime(Duration duration) {
        recoveryTimer.record(duration);
    }
}
```

### 2. Error Alerting

**Alerts**: Critical error thresholds, error rate increases.

**Implementation**:
```java
@Component
public class ErrorAlertingService {
    
    public void checkErrorThresholds() {
        // Check error rates
        if (getErrorRate() > ERROR_THRESHOLD) {
            sendAlert("High error rate detected");
        }
        
        // Check critical errors
        if (getCriticalErrorCount() > 0) {
            sendAlert("Critical errors detected");
        }
    }
}
```

---

## Related Documentation

- [Class Index](../quick-ref/CLASS_INDEX.md) - Complete list of all classes
- [Finding Code Guide](../quick-ref/FINDING_CODE_GUIDE.md) - How to find specific functionality
- [Common Patterns](../quick-ref/COMMON_PATTERNS.md) - Recurring patterns in codebase
- [Component Map](../architecture/COMPONENT_MAP.md) - High-level architecture overview
- [Feature to Code Map](FEATURE_TO_CODE_MAP.md) - Feature implementation mapping
- [Config to Code Map](CONFIG_TO_CODE_MAP.md) - Configuration mapping
