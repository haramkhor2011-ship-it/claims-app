# Report Generation Flow - Claims Backend Application

> Detailed documentation of the report generation process, including request handling, security checks, SQL query construction, and result processing.

## Overview

The report generation system provides various business intelligence reports for claims analysis. It supports multi-tenancy, role-based access control, and performance optimization through materialized views.

**Flow**: `Request → Security → Validation → Query → Processing → Response`

---

## High-Level Flow Diagram

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Request   │───▶│   Security  │───▶│ Validation  │───▶│   Query     │
│             │    │             │    │             │    │             │
│ - REST API  │    │ - JWT Auth  │    │ - Parameters│    │ - SQL       │
│ - Parameters│    │ - RBAC      │    │ - Date Range│    │ - Materialized│
│ - Filters   │    │ - Multi-    │    │ - Business  │    │   Views     │
│             │    │   Tenant    │    │   Rules     │    │             │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                              │
┌─────────────┐    ┌─────────────┐    ┌─────────────┐       │
│  Response   │◀───│ Processing  │◀───│   Results   │◀──────┘
│             │    │             │    │             │
│ - JSON      │    │ - Formatting│    │ - Database  │
│ - CSV       │    │ - Aggregation│   │ - Caching   │
│ - Pagination│    │ - Sorting   │    │ - Performance│
└─────────────┘    └─────────────┘    └─────────────┘
```

---

## Detailed Step-by-Step Flow

### 1. Request Handling (ReportDataController)

**Purpose**: Main entry point for report generation requests.

**Key Methods**:
- `generateReport()` - Main report generation endpoint
- `validateRequest()` - Request validation
- `formatResponse()` - Response formatting

**Process**:
```java
@PostMapping("/reports/generate")
@PreAuthorize("hasRole('CLAIMS_RO') or hasRole('CLAIMS_OPS') or hasRole('CLAIMS_ADMIN')")
public ResponseEntity<ReportResponse> generateReport(
    @Valid @RequestBody ReportRequest request,
    HttpServletRequest httpRequest) {
    
    try {
        // 1. Extract security context
        String facilityId = securityContextService.getCurrentFacilityId();
        Set<String> userRoles = securityContextService.getCurrentUserRoles();
        
        // 2. Validate request
        ReportRequestValidator validator = new ReportRequestValidator();
        validator.validate(request, facilityId, userRoles);
        
        // 3. Generate report
        ReportService reportService = getReportService(request.getReportType());
        ReportResult result = reportService.generateReport(request, facilityId);
        
        // 4. Format response
        ReportResponse response = formatResponse(result, request);
        
        return ResponseEntity.ok(response);
        
    } catch (ValidationException e) {
        return ResponseEntity.badRequest()
            .body(ReportResponse.error("Validation failed: " + e.getMessage()));
    } catch (AccessDeniedException e) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
            .body(ReportResponse.error("Access denied: " + e.getMessage()));
    } catch (Exception e) {
        log.error("Report generation failed", e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(ReportResponse.error("Report generation failed"));
    }
}
```

**Security Features**:
- JWT token validation
- Role-based access control
- Multi-tenant data isolation
- Request validation

**Error Handling**:
- Validation errors → 400 Bad Request
- Access denied → 403 Forbidden
- System errors → 500 Internal Server Error

---

### 2. Security Context (SecurityContextService)

**Purpose**: Extract and validate security context from JWT tokens.

**Key Methods**:
- `getCurrentFacilityId()` - Get current facility ID
- `getCurrentUserRoles()` - Get current user roles
- `validateAccess()` - Validate access permissions

**Process**:
```java
@Service
public class SecurityContextService {
    
    public String getCurrentFacilityId() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication instanceof JwtAuthenticationToken)) {
            throw new AuthenticationException("No valid authentication found");
        }
        
        JwtAuthenticationToken jwtToken = (JwtAuthenticationToken) authentication;
        String facilityId = jwtToken.getToken().getClaimAsString("facility_id");
        
        if (facilityId == null || facilityId.isBlank()) {
            throw new AuthenticationException("No facility ID in token");
        }
        
        return facilityId;
    }
    
    public Set<String> getCurrentUserRoles() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null) {
            return Collections.emptySet();
        }
        
        return authentication.getAuthorities().stream()
            .map(GrantedAuthority::getAuthority)
            .map(authority -> authority.replace("ROLE_", ""))
            .collect(Collectors.toSet());
    }
    
    public void validateAccess(String reportType, Set<String> userRoles) {
        if (!hasReportAccess(reportType, userRoles)) {
            throw new AccessDeniedException("Insufficient permissions for report: " + reportType);
        }
    }
    
    private boolean hasReportAccess(String reportType, Set<String> userRoles) {
        // Define report access matrix
        Map<String, Set<String>> reportAccess = Map.of(
            "BALANCE_AMOUNT", Set.of("CLAIMS_RO", "CLAIMS_OPS", "CLAIMS_ADMIN"),
            "CLAIM_DETAILS", Set.of("CLAIMS_RO", "CLAIMS_OPS", "CLAIMS_ADMIN"),
            "DOCTOR_DENIAL", Set.of("CLAIMS_OPS", "CLAIMS_ADMIN"),
            "REJECTED_CLAIMS", Set.of("CLAIMS_OPS", "CLAIMS_ADMIN"),
            "REMITTANCE_ADVICE", Set.of("CLAIMS_RO", "CLAIMS_OPS", "CLAIMS_ADMIN"),
            "RESUBMISSION_CYCLES", Set.of("CLAIMS_OPS", "CLAIMS_ADMIN")
        );
        
        Set<String> requiredRoles = reportAccess.get(reportType);
        if (requiredRoles == null) {
            return false;
        }
        
        return userRoles.stream().anyMatch(requiredRoles::contains);
    }
}
```

**Security Features**:
- JWT token validation
- Role-based access control
- Facility-based data isolation
- Permission matrix

**Error Handling**:
- Invalid tokens → AuthenticationException
- Missing facility ID → AuthenticationException
- Insufficient permissions → AccessDeniedException

---

### 3. Request Validation (ReportRequestValidator)

**Purpose**: Validate report requests for business rules and data integrity.

**Key Methods**:
- `validate()` - Main validation method
- `validateDateRange()` - Date range validation
- `validateParameters()` - Parameter validation

**Process**:
```java
@Component
public class ReportRequestValidator {
    
    public void validate(ReportRequest request, String facilityId, Set<String> userRoles) {
        // 1. Basic validation
        if (request.getReportType() == null || request.getReportType().isBlank()) {
            throw new ValidationException("Report type is required");
        }
        
        // 2. Date range validation
        validateDateRange(request.getStartDate(), request.getEndDate());
        
        // 3. Parameter validation
        validateParameters(request);
        
        // 4. Business rule validation
        validateBusinessRules(request, facilityId, userRoles);
        
        // 5. Data access validation
        validateDataAccess(request, facilityId);
    }
    
    private void validateDateRange(LocalDate startDate, LocalDate endDate) {
        if (startDate == null || endDate == null) {
            throw new ValidationException("Start date and end date are required");
        }
        
        if (startDate.isAfter(endDate)) {
            throw new ValidationException("Start date cannot be after end date");
        }
        
        if (startDate.isBefore(LocalDate.now().minusYears(2))) {
            throw new ValidationException("Start date cannot be more than 2 years ago");
        }
        
        if (endDate.isAfter(LocalDate.now())) {
            throw new ValidationException("End date cannot be in the future");
        }
        
        if (ChronoUnit.DAYS.between(startDate, endDate) > 365) {
            throw new ValidationException("Date range cannot exceed 365 days");
        }
    }
    
    private void validateParameters(ReportRequest request) {
        // Validate report-specific parameters
        switch (request.getReportType()) {
            case "BALANCE_AMOUNT" -> {
                if (request.getPayerId() == null || request.getPayerId().isBlank()) {
                    throw new ValidationException("Payer ID is required for balance amount report");
                }
            }
            case "DOCTOR_DENIAL" -> {
                if (request.getClinicianId() == null || request.getClinicianId().isBlank()) {
                    throw new ValidationException("Clinician ID is required for doctor denial report");
                }
            }
            case "CLAIM_DETAILS" -> {
                if (request.getClaimId() == null || request.getClaimId().isBlank()) {
                    throw new ValidationException("Claim ID is required for claim details report");
                }
            }
        }
    }
    
    private void validateBusinessRules(ReportRequest request, String facilityId, Set<String> userRoles) {
        // Check if user has access to requested data
        if (request.getFacilityId() != null && !request.getFacilityId().equals(facilityId)) {
            if (!userRoles.contains("CLAIMS_ADMIN")) {
                throw new ValidationException("Cannot access data for other facilities");
            }
        }
        
        // Check if report type is allowed for user role
        if (!hasReportAccess(request.getReportType(), userRoles)) {
            throw new ValidationException("Insufficient permissions for report type: " + request.getReportType());
        }
    }
    
    private void validateDataAccess(ReportRequest request, String facilityId) {
        // Check if facility has data for the requested date range
        Long count = jdbcTemplate.queryForObject("""
            SELECT COUNT(*) FROM claims.ingestion_file 
            WHERE facility_id = ? AND created_at BETWEEN ? AND ?
            """, Long.class, facilityId, request.getStartDate(), request.getEndDate());
        
        if (count == 0) {
            throw new ValidationException("No data available for the specified date range");
        }
    }
}
```

**Validation Features**:
- Date range validation
- Parameter validation
- Business rule validation
- Data access validation

**Error Handling**:
- Validation failures → ValidationException
- Business rule violations → ValidationException
- Data access issues → ValidationException

---

### 4. Report Service Selection (ReportServiceFactory)

**Purpose**: Select appropriate report service based on report type.

**Process**:
```java
@Component
public class ReportServiceFactory {
    
    private final Map<String, ReportService> reportServices;
    
    public ReportServiceFactory(List<ReportService> services) {
        this.reportServices = services.stream()
            .collect(Collectors.toMap(
                ReportService::getReportType,
                Function.identity()
            ));
    }
    
    public ReportService getReportService(String reportType) {
        ReportService service = reportServices.get(reportType);
        if (service == null) {
            throw new IllegalArgumentException("Unknown report type: " + reportType);
        }
        return service;
    }
}
```

**Report Services**:
- `BalanceAmountReportService`
- `ClaimDetailsWithActivityReportService`
- `ClaimSummaryMonthwiseReportService`
- `DoctorDenialReportService`
- `RejectedClaimsReportService`
- `RemittanceAdvicePayerwiseReportService`
- `RemittancesResubmissionReportService`

---

### 5. SQL Query Construction (Report Services)

**Purpose**: Build and execute SQL queries for report generation.

**Example**: BalanceAmountReportService
```java
@Service
public class BalanceAmountReportService implements ReportService {
    
    @Override
    public String getReportType() {
        return "BALANCE_AMOUNT";
    }
    
    @Override
    public ReportResult generateReport(ReportRequest request, String facilityId) {
        try {
            // 1. Build query
            String sql = buildQuery(request, facilityId);
            
            // 2. Execute query
            List<Map<String, Object>> results = jdbcTemplate.queryForList(sql, 
                request.getStartDate(), request.getEndDate(), request.getPayerId(), facilityId);
            
            // 3. Process results
            List<BalanceAmountReportRow> reportRows = results.stream()
                .map(this::mapToReportRow)
                .collect(Collectors.toList());
            
            // 4. Calculate totals
            BalanceAmountReportTotals totals = calculateTotals(reportRows);
            
            return new ReportResult(reportRows, totals, results.size());
            
        } catch (Exception e) {
            log.error("Failed to generate balance amount report", e);
            throw new ReportGenerationException("Failed to generate report", e);
        }
    }
    
    private String buildQuery(ReportRequest request, String facilityId) {
        return """
            SELECT 
                c.claim_id,
                c.payer_id,
                c.provider_id,
                c.gross_amount,
                c.patient_share,
                c.net_amount,
                c.created_at,
                s.sender_id,
                s.receiver_id
            FROM claims.claim c
            JOIN claims.submission s ON c.submission_id = s.id
            JOIN claims.ingestion_file f ON s.ingestion_file_id = f.id
            WHERE f.facility_id = ?
                AND c.created_at BETWEEN ? AND ?
                AND c.payer_id = ?
            ORDER BY c.created_at DESC
            """;
    }
    
    private BalanceAmountReportRow mapToReportRow(Map<String, Object> row) {
        return new BalanceAmountReportRow(
            (String) row.get("claim_id"),
            (String) row.get("payer_id"),
            (String) row.get("provider_id"),
            (BigDecimal) row.get("gross_amount"),
            (BigDecimal) row.get("patient_share"),
            (BigDecimal) row.get("net_amount"),
            (LocalDateTime) row.get("created_at"),
            (String) row.get("sender_id"),
            (String) row.get("receiver_id")
        );
    }
    
    private BalanceAmountReportTotals calculateTotals(List<BalanceAmountReportRow> rows) {
        BigDecimal totalGross = rows.stream()
            .map(BalanceAmountReportRow::getGrossAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        
        BigDecimal totalPatientShare = rows.stream()
            .map(BalanceAmountReportRow::getPatientShare)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        
        BigDecimal totalNet = rows.stream()
            .map(BalanceAmountReportRow::getNetAmount)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        
        return new BalanceAmountReportTotals(totalGross, totalPatientShare, totalNet, rows.size());
    }
}
```

**Query Features**:
- Parameterized queries
- SQL injection prevention
- Performance optimization
- Error handling

**Error Handling**:
- SQL errors → DataAccessException
- Mapping errors → ReportGenerationException
- Calculation errors → ReportGenerationException

---

### 6. Materialized View Usage (ReportViewGenerationController)

**Purpose**: Manage materialized views for report performance optimization.

**Key Methods**:
- `generateView()` - Create materialized view
- `refreshView()` - Refresh materialized view
- `getViewStatus()` - Get view status

**Process**:
```java
@RestController
@RequestMapping("/admin/reports/views")
@PreAuthorize("hasRole('CLAIMS_ADMIN')")
public class ReportViewGenerationController {
    
    @PostMapping("/generate")
    public ResponseEntity<ViewGenerationResponse> generateView(
        @RequestBody ViewGenerationRequest request) {
        
        try {
            // 1. Validate request
            validateViewRequest(request);
            
            // 2. Generate view
            ReportViewGenerator generator = new ReportViewGenerator();
            String viewName = generator.generateView(request.getReportType(), request.getParameters());
            
            // 3. Return response
            return ResponseEntity.ok(new ViewGenerationResponse(viewName, "SUCCESS"));
            
        } catch (Exception e) {
            log.error("Failed to generate view", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ViewGenerationResponse(null, "FAILED: " + e.getMessage()));
        }
    }
    
    @PostMapping("/refresh")
    public ResponseEntity<ViewRefreshResponse> refreshView(
        @RequestBody ViewRefreshRequest request) {
        
        try {
            // 1. Validate request
            validateRefreshRequest(request);
            
            // 2. Refresh view
            ReportViewGenerator generator = new ReportViewGenerator();
            generator.refreshView(request.getViewName());
            
            // 3. Return response
            return ResponseEntity.ok(new ViewRefreshResponse("SUCCESS"));
            
        } catch (Exception e) {
            log.error("Failed to refresh view", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ViewRefreshResponse("FAILED: " + e.getMessage()));
        }
    }
}
```

**View Features**:
- Automatic view creation
- Scheduled refresh
- Performance monitoring
- Error handling

---

### 7. Result Processing and Formatting

**Purpose**: Process query results and format response.

**Process**:
```java
@Component
public class ReportResponseFormatter {
    
    public ReportResponse formatResponse(ReportResult result, ReportRequest request) {
        try {
            // 1. Format data
            List<Map<String, Object>> formattedData = formatData(result.getData());
            
            // 2. Add metadata
            ReportMetadata metadata = createMetadata(result, request);
            
            // 3. Create response
            return ReportResponse.builder()
                .data(formattedData)
                .metadata(metadata)
                .status("SUCCESS")
                .build();
                
        } catch (Exception e) {
            log.error("Failed to format response", e);
            return ReportResponse.error("Failed to format response: " + e.getMessage());
        }
    }
    
    private List<Map<String, Object>> formatData(List<?> data) {
        return data.stream()
            .map(this::formatRow)
            .collect(Collectors.toList());
    }
    
    private Map<String, Object> formatRow(Object row) {
        // Convert row to Map<String, Object>
        // Handle different data types
        // Format dates, numbers, etc.
        return objectMapper.convertValue(row, Map.class);
    }
    
    private ReportMetadata createMetadata(ReportResult result, ReportRequest request) {
        return ReportMetadata.builder()
            .reportType(request.getReportType())
            .startDate(request.getStartDate())
            .endDate(request.getEndDate())
            .totalRecords(result.getTotalRecords())
            .generatedAt(LocalDateTime.now())
            .facilityId(request.getFacilityId())
            .build();
    }
}
```

**Formatting Features**:
- Data type conversion
- Date formatting
- Number formatting
- Metadata inclusion

---

## Performance Optimization

### Materialized Views
```sql
-- Example: Balance Amount Report Materialized View
CREATE MATERIALIZED VIEW claims.mv_balance_amount_report AS
SELECT 
    c.claim_id,
    c.payer_id,
    c.provider_id,
    c.gross_amount,
    c.patient_share,
    c.net_amount,
    c.created_at,
    s.sender_id,
    s.receiver_id,
    f.facility_id
FROM claims.claim c
JOIN claims.submission s ON c.submission_id = s.id
JOIN claims.ingestion_file f ON s.ingestion_file_id = f.id
WHERE c.created_at >= CURRENT_DATE - INTERVAL '2 years';

-- Create index for performance
CREATE INDEX idx_mv_balance_amount_facility_date 
ON claims.mv_balance_amount_report (facility_id, created_at);

-- Refresh view
REFRESH MATERIALIZED VIEW claims.mv_balance_amount_report;
```

### Query Optimization
- **Indexes**: Proper indexing on frequently queried columns
- **Partitioning**: Date-based partitioning for large tables
- **Caching**: Result caching for frequently accessed reports
- **Connection Pooling**: Efficient database connection management

---

## Security Implementation

### Multi-Tenancy
```java
@Component
public class MultiTenantReportFilter {
    
    public void applyFacilityFilter(String sql, String facilityId) {
        // Add facility_id filter to all queries
        if (!sql.contains("facility_id")) {
            sql += " AND facility_id = ?";
        }
    }
}
```

### Role-Based Access
```java
@Aspect
@Component
public class ReportSecurityAspect {
    
    @Before("@annotation(PreAuthorize)")
    public void checkReportAccess(JoinPoint joinPoint) {
        // Check if user has access to requested report
        // Validate facility access
        // Log access attempts
    }
}
```

---

## Error Handling Strategy

### Error Categories
1. **Validation Errors**: Invalid parameters, date ranges
2. **Security Errors**: Access denied, authentication failures
3. **Data Errors**: No data available, SQL errors
4. **System Errors**: Database connection, memory issues

### Error Recovery
- **Retry Logic**: For transient database errors
- **Fallback**: Use cached results when available
- **Graceful Degradation**: Return partial results when possible

---

## Monitoring and Metrics

### Key Metrics
- **Report Generation Time**: Time per report
- **Query Performance**: SQL execution time
- **Error Rates**: Success/failure ratios
- **Cache Hit Rates**: Materialized view usage

### Health Checks
- **Database Health**: Connection pool status
- **View Health**: Materialized view status
- **Performance**: Query performance monitoring

---

## Related Documentation

- [Component Map](../architecture/COMPONENT_MAP.md) - High-level architecture overview
- [Class Index](../quick-ref/CLASS_INDEX.md) - Complete list of all classes
- [Finding Code Guide](../quick-ref/FINDING_CODE_GUIDE.md) - How to find specific functionality
- [Common Patterns](../quick-ref/COMMON_PATTERNS.md) - Recurring patterns in codebase
- [Ingestion Flow](INGESTION_FLOW_DETAILED.md) - Detailed ingestion process
- [SOAP Flow](SOAP_FETCH_FLOW.md) - SOAP integration process
