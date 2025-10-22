# Common Patterns - Claims Backend Application

> Documentation of recurring patterns and architectural decisions in the claims-backend application. Use this to understand the codebase structure and maintain consistency when adding new features.

## Table of Contents

- [Service Layer Patterns](#service-layer-patterns)
- [Data Access Patterns](#data-access-patterns)
- [Error Handling Patterns](#error-handling-patterns)
- [Configuration Patterns](#configuration-patterns)
- [Security Patterns](#security-patterns)
- [Transaction Patterns](#transaction-patterns)
- [Validation Patterns](#validation-patterns)
- [Integration Patterns](#integration-patterns)
- [Monitoring Patterns](#monitoring-patterns)

---

## Service Layer Patterns

### Service → Repository → Entity Pattern

**Purpose**: Clean separation of business logic, data access, and data representation.

**Structure**:
```java
@Service
public class ClaimService {
    private final ClaimRepository repository;
    
    public Claim findById(Long id) {
        return repository.findById(id)
            .orElseThrow(() -> new ClaimNotFoundException(id));
    }
}

@Repository
public interface ClaimRepository extends JpaRepository<Claim, Long> {
    // Custom query methods
}

@Entity
@Table(name = "claim")
public class Claim {
    // JPA entity definition
}
```

**Examples in Codebase**:
- `BalanceAmountReportService` → `ClaimRepository` → `Claim`
- `ReferenceDataService` → `ActivityCodeRepository` → `ActivityCode`
- `FacilityAdminService` → `FacilityRepository` → `Facility`

**When to Use**: All business operations that need data persistence.

### DTO → Mapper → Entity Pattern

**Purpose**: Clean data transformation between layers.

**Structure**:
```java
// DTO for API/External communication
public record ClaimDto(Long id, String payerId, BigDecimal amount) {}

// MapStruct mapper
@Mapper
public interface ClaimMapper {
    ClaimDto toDto(Claim entity);
    Claim toEntity(ClaimDto dto);
}

// Service uses mapper
@Service
public class ClaimService {
    private final ClaimMapper mapper;
    
    public ClaimDto getClaim(Long id) {
        Claim entity = findById(id);
        return mapper.toDto(entity);
    }
}
```

**Examples in Codebase**:
- `SubmissionDTO` → `SubmissionGraphMapper` → `Submission` entity
- `RemittanceAdviceDTO` → `RemittanceGraphMapper` → `Remittance` entity
- Report DTOs → Report mappers → Database entities

**When to Use**: When you need to transform data between different representations.

---

## Data Access Patterns

### Repository Pattern with Custom Queries

**Purpose**: Encapsulate data access logic with custom SQL when needed.

**Structure**:
```java
@Repository
public interface ClaimRepository extends JpaRepository<Claim, Long> {
    
    // Custom query methods
    @Query("SELECT c FROM Claim c WHERE c.payerId = :payerId")
    List<Claim> findByPayerId(@Param("payerId") String payerId);
    
    // Native SQL for complex queries
    @Query(value = "SELECT * FROM claims.claim WHERE created_at > :date", 
           nativeQuery = true)
    List<Claim> findRecentClaims(@Param("date") LocalDateTime date);
}
```

**Examples in Codebase**:
- `IngestionFileRepository` with custom queries for file processing
- `ClaimRepository` with complex report queries
- `RemittanceRepository` with payment analysis queries

**When to Use**: When JPA methods are insufficient for complex queries.

### Batch Processing Pattern

**Purpose**: Efficient processing of large datasets.

**Structure**:
```java
@Service
public class BatchProcessor {
    
    @Transactional
    public void processBatch(List<Item> items) {
        int batchSize = 1000;
        for (int i = 0; i < items.size(); i += batchSize) {
            List<Item> batch = items.subList(i, 
                Math.min(i + batchSize, items.size()));
            processBatchChunk(batch);
        }
    }
    
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    private void processBatchChunk(List<Item> batch) {
        // Process chunk in separate transaction
    }
}
```

**Examples in Codebase**:
- `PersistService` for large file processing
- `RefdataCsvLoader` for reference data loading
- `Orchestrator` for work item processing

**When to Use**: When processing large datasets that could cause memory or transaction issues.

---

## Error Handling Patterns

### Centralized Error Logging Pattern

**Purpose**: Consistent error logging and categorization.

**Structure**:
```java
@Component
public class ErrorLogger {
    
    public void fileError(Long fileId, String stage, String errorCode, 
                         String message, boolean isRetryable) {
        // Log to database
        jdbc.update("INSERT INTO ingestion_error ...", 
                   fileId, stage, errorCode, message, isRetryable);
        
        // Log to application logs
        log.error("File processing error: fileId={} stage={} code={} message={}", 
                 fileId, stage, errorCode, message);
    }
}
```

**Examples in Codebase**:
- `ErrorLogger` for ingestion errors
- `IngestionErrorRecorder` for error persistence
- `GlobalExceptionHandler` for REST API errors

**When to Use**: All error scenarios that need tracking and analysis.

### Exception Translation Pattern

**Purpose**: Convert technical exceptions to business exceptions.

**Structure**:
```java
@Service
public class ClaimService {
    
    public Claim findById(Long id) {
        try {
            return repository.findById(id)
                .orElseThrow(() -> new ClaimNotFoundException(id));
        } catch (DataAccessException e) {
            throw new ClaimServiceException("Database error accessing claim", e);
        }
    }
}
```

**Examples in Codebase**:
- Database exceptions → Business exceptions in services
- SOAP exceptions → Ingestion exceptions
- Parse exceptions → Validation exceptions

**When to Use**: When you need to hide technical details from callers.

---

## Configuration Patterns

### Properties-Based Configuration Pattern

**Purpose**: Externalize configuration for different environments.

**Structure**:
```java
@ConfigurationProperties(prefix = "claims.ingestion")
@Component
public class IngestionProperties {
    private int batchSize = 1000;
    private int maxRetries = 3;
    private Duration timeout = Duration.ofMinutes(5);
    
    // Getters and setters
}

@Service
public class IngestionService {
    private final IngestionProperties properties;
    
    public void process() {
        int batchSize = properties.getBatchSize();
        // Use configuration
    }
}
```

**Examples in Codebase**:
- `IngestionProperties` for pipeline configuration
- `SoapProperties` for SOAP integration
- `SecurityProperties` for security settings

**When to Use**: All configurable behavior that varies by environment.

### Profile-Based Configuration Pattern

**Purpose**: Different configurations for different deployment scenarios.

**Structure**:
```yaml
# application.yml (base)
spring:
  profiles:
    active: localfs

# application-soap.yml
spring:
  config:
    activate:
      on-profile: soap

claims:
  soap:
    enabled: true
    polling:
      interval: PT1M
```

**Examples in Codebase**:
- `localfs` profile for local file system processing
- `soap` profile for SOAP integration
- `prod` profile for production settings

**When to Use**: When you need different behavior in different environments.

---

## Security Patterns

### Role-Based Access Control Pattern

**Purpose**: Control access based on user roles.

**Structure**:
```java
@RestController
@PreAuthorize("hasRole('CLAIMS_ADMIN')")
public class AdminController {
    
    @GetMapping("/admin/facilities")
    @PreAuthorize("hasRole('CLAIMS_ADMIN') or hasRole('CLAIMS_OPS')")
    public List<Facility> getFacilities() {
        // Implementation
    }
}
```

**Examples in Codebase**:
- `@PreAuthorize` annotations on controllers
- `SecurityContextService` for role checking
- `Role` enum for role definitions

**When to Use**: All endpoints that need access control.

### Multi-Tenant Context Pattern

**Purpose**: Isolate data by facility/tenant.

**Structure**:
```java
@Component
public class FacilityContext {
    private static final ThreadLocal<String> currentFacility = new ThreadLocal<>();
    
    public static void setCurrentFacility(String facilityId) {
        currentFacility.set(facilityId);
    }
    
    public static String getCurrentFacility() {
        return currentFacility.get();
    }
    
    public static void clear() {
        currentFacility.remove();
    }
}
```

**Examples in Codebase**:
- `FacilityContext` for thread-local facility storage
- `MultiTenantAspect` for automatic facility filtering
- `FacilitySecurityService` for facility-based security

**When to Use**: When you need to isolate data by tenant/facility.

---

## Transaction Patterns

### REQUIRES_NEW Transaction Pattern

**Purpose**: Ensure operations complete even if outer transaction fails.

**Structure**:
```java
@Service
public class Pipeline {
    
    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    public Result process(WorkItem wi) {
        // Non-transactional orchestration
        Long fileId = self.insertStub(wi); // REQUIRES_NEW
        // ... other operations
    }
    
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public Long insertStub(WorkItem wi) {
        // Always commits, even if outer transaction fails
        return jdbc.queryForObject("INSERT INTO ingestion_file ...", Long.class);
    }
}
```

**Examples in Codebase**:
- `Pipeline.insertStub()` for file registration
- `Pipeline.updateIngestionFileHeader()` for header updates
- `ErrorLogger.fileError()` for error persistence

**When to Use**: When you need operations to persist even if the main transaction fails.

### Transaction Boundary Pattern

**Purpose**: Clear transaction boundaries for complex operations.

**Structure**:
```java
@Service
public class ComplexService {
    
    @Transactional
    public void processComplexOperation() {
        // Read operations
        List<Data> data = repository.findAll();
        
        // Business logic
        List<ProcessedData> processed = processData(data);
        
        // Write operations
        repository.saveAll(processed);
    }
    
    private List<ProcessedData> processData(List<Data> data) {
        // Non-transactional business logic
        return data.stream()
            .map(this::transform)
            .collect(toList());
    }
}
```

**Examples in Codebase**:
- `PersistService` for data persistence
- `Orchestrator` for work item processing
- Report services for data processing

**When to Use**: When you need clear transaction boundaries for complex operations.

---

## Validation Patterns

### DTO Validation Pattern

**Purpose**: Validate data at API boundaries.

**Structure**:
```java
public record ClaimRequest(
    @NotBlank(message = "Claim ID is required")
    String claimId,
    
    @NotNull(message = "Amount is required")
    @Positive(message = "Amount must be positive")
    BigDecimal amount,
    
    @Pattern(regexp = "^[A-Z0-9]+$", message = "Invalid payer ID format")
    String payerId
) {}

@RestController
public class ClaimController {
    
    @PostMapping("/claims")
    public ResponseEntity<Claim> createClaim(@Valid @RequestBody ClaimRequest request) {
        // Validation happens automatically
    }
}
```

**Examples in Codebase**:
- Request DTOs with validation annotations
- `GlobalExceptionHandler` for validation error handling
- `DtoValidator` for custom validation logic

**When to Use**: All API endpoints that accept user input.

### Business Rule Validation Pattern

**Purpose**: Validate business rules beyond basic data validation.

**Structure**:
```java
@Service
public class ClaimValidator {
    
    public void validateClaim(Claim claim) {
        // Business rule validations
        if (claim.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new ValidationException("Claim amount must be positive");
        }
        
        if (!isValidPayer(claim.getPayerId())) {
            throw new ValidationException("Invalid payer ID");
        }
    }
    
    private boolean isValidPayer(String payerId) {
        // Complex business logic
        return payerRepository.existsById(payerId);
    }
}
```

**Examples in Codebase**:
- `Pipeline.validateSubmission()` for submission validation
- `Pipeline.validateRemittance()` for remittance validation
- `ClaimValidationUtil` for reusable validation logic

**When to Use**: When you need complex business rule validation.

---

## Integration Patterns

### Adapter Pattern for External Services

**Purpose**: Abstract external service integration.

**Structure**:
```java
public interface ExternalServiceAdapter {
    Response callService(Request request);
}

@Component
public class SoapServiceAdapter implements ExternalServiceAdapter {
    
    @Override
    public Response callService(Request request) {
        // SOAP-specific implementation
        return soapClient.send(request);
    }
}

@Component
public class RestServiceAdapter implements ExternalServiceAdapter {
    
    @Override
    public Response callService(Request request) {
        // REST-specific implementation
        return restTemplate.postForObject(url, request, Response.class);
    }
}
```

**Examples in Codebase**:
- `SoapFetcherAdapter` for SOAP file fetching
- `SoapAckerAdapter` for SOAP acknowledgments
- `NoopAcker` for disabled ACK functionality

**When to Use**: When you need to support multiple integration protocols.

### Circuit Breaker Pattern

**Purpose**: Prevent cascading failures in external service calls.

**Structure**:
```java
@Service
public class ExternalServiceClient {
    
    @CircuitBreaker(name = "external-service", fallbackMethod = "fallback")
    public Response callExternalService(Request request) {
        return externalService.call(request);
    }
    
    public Response fallback(Request request, Exception ex) {
        // Fallback behavior
        return Response.defaultResponse();
    }
}
```

**Examples in Codebase**:
- `CircuitBreakerService` for SOAP calls
- `DatabaseMonitoringService` for database health checks
- Retry logic in `DhpoFetchCoordinator`

**When to Use**: When calling external services that might fail.

---

## Monitoring Patterns

### Metrics Collection Pattern

**Purpose**: Collect application metrics for monitoring.

**Structure**:
```java
@Component
public class ApplicationMetrics {
    
    private final MeterRegistry meterRegistry;
    private final Counter successCounter;
    private final Timer processingTimer;
    
    public ApplicationMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
        this.successCounter = Counter.builder("app.operations.success")
            .register(meterRegistry);
        this.processingTimer = Timer.builder("app.operations.duration")
            .register(meterRegistry);
    }
    
    public void recordSuccess() {
        successCounter.increment();
    }
    
    public void recordProcessingTime(Duration duration) {
        processingTimer.record(duration);
    }
}
```

**Examples in Codebase**:
- `DhpoMetrics` for ingestion metrics
- `DatabaseHealthMetrics` for database metrics
- `ApplicationHealthMetrics` for application health

**When to Use**: All operations that need monitoring and alerting.

### Health Check Pattern

**Purpose**: Provide health status for external monitoring.

**Structure**:
```java
@Component
public class CustomHealthIndicator implements HealthIndicator {
    
    @Override
    public Health health() {
        try {
            // Check external dependencies
            boolean dbHealthy = checkDatabase();
            boolean externalServiceHealthy = checkExternalService();
            
            if (dbHealthy && externalServiceHealthy) {
                return Health.up()
                    .withDetail("database", "available")
                    .withDetail("external-service", "available")
                    .build();
            } else {
                return Health.down()
                    .withDetail("database", dbHealthy ? "available" : "unavailable")
                    .withDetail("external-service", externalServiceHealthy ? "available" : "unavailable")
                    .build();
            }
        } catch (Exception e) {
            return Health.down(e).build();
        }
    }
}
```

**Examples in Codebase**:
- `DatabaseMonitoringService` for database health
- `ProductionMonitoringController` for health endpoints
- `ApplicationHealthMetrics` for application health

**When to Use**: When you need to expose health status for monitoring systems.

---

## Best Practices

### When to Use Each Pattern

1. **Service Layer Patterns**: Always use for business logic
2. **Data Access Patterns**: Use for all database operations
3. **Error Handling Patterns**: Use for all error scenarios
4. **Configuration Patterns**: Use for all configurable behavior
5. **Security Patterns**: Use for all access control
6. **Transaction Patterns**: Use for all data persistence
7. **Validation Patterns**: Use for all user input
8. **Integration Patterns**: Use for all external service calls
9. **Monitoring Patterns**: Use for all critical operations

### Pattern Consistency

- Follow existing patterns when adding new features
- Document new patterns when they emerge
- Refactor code to follow established patterns
- Use code reviews to ensure pattern consistency

### Anti-Patterns to Avoid

- **God Classes**: Classes that do too much
- **Anemic Domain Models**: Entities with no business logic
- **Tight Coupling**: Direct dependencies between unrelated components
- **Inconsistent Error Handling**: Different error handling approaches
- **Configuration Scattered**: Configuration spread across multiple files

---

## Related Documentation

- [Class Index](CLASS_INDEX.md) - Complete list of all classes
- [Finding Code Guide](FINDING_CODE_GUIDE.md) - How to find specific functionality
- [Component Map](../architecture/COMPONENT_MAP.md) - High-level architecture
- [Ingestion Flow](../flows/INGESTION_FLOW_DETAILED.md) - Detailed ingestion process
