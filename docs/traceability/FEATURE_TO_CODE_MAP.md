# Feature to Code Map - Claims Backend Application

> Traceability matrix mapping business features to their implementation in the codebase. Use this to understand where specific functionality is implemented and how features are connected.

## Overview

This document provides a comprehensive mapping between business features and their implementation in the claims-backend application. It helps developers understand where to find specific functionality and how features are interconnected.

---

## Core Business Features

### 1. XML File Ingestion

**Business Feature**: Process XML files containing claim submissions and remittance advice.

**Implementation**:
- **Main Entry Point**: `com.acme.claims.ingestion.Orchestrator`
- **Core Processing**: `com.acme.claims.ingestion.Pipeline`
- **XML Parsing**: `com.acme.claims.ingestion.parser.StageParser`
- **Data Persistence**: `com.acme.claims.ingestion.persist.PersistService`
- **Validation**: `Pipeline.validateSubmission()` and `Pipeline.validateRemittance()`
- **Verification**: `com.acme.claims.ingestion.verify.VerifyService`

**Key Classes**:
```java
// Main orchestration
Orchestrator.process()                    // Main processing loop
Orchestrator.drain()                      // Work queue processing
Orchestrator.processOne()                 // Single file processing

// Core pipeline
Pipeline.process(WorkItem)                // Main pipeline execution
Pipeline.insertStub()                     // File registration
Pipeline.updateIngestionFileHeader()      // Header updates

// Parsing
StageParser.parse(IngestionFile)          // XML to DTO conversion
ClaimXmlParserStax.parseSubmission()      // Submission parsing
ClaimXmlParserStax.parseRemittance()      // Remittance parsing

// Persistence
PersistService.persistSubmission()        // Submission persistence
PersistService.persistRemittance()        // Remittance persistence
```

**Database Tables**:
- `ingestion_file` - File metadata
- `submission` - Submission records
- `claim` - Claim records
- `encounter` - Encounter records
- `activity` - Activity records
- `remittance` - Remittance records

**Configuration**:
- `IngestionProperties` - Pipeline configuration
- `application.yml` - Base configuration
- `application-localfs.yml` - Local filesystem mode

---

### 2. SOAP Integration

**Business Feature**: Integrate with DHPO SOAP services for automated file fetching.

**Implementation**:
- **Main Coordinator**: `com.acme.claims.soap.fetch.DhpoFetchCoordinator`
- **SOAP Client**: `com.acme.claims.soap.client.DhpoSoapClient`
- **File Staging**: `com.acme.claims.soap.fetch.StagingService`
- **Credential Management**: `com.acme.claims.soap.crypto.CredentialDecryptor`
- **Transport Layer**: `com.acme.claims.soap.transport.HttpSoapCaller`

**Key Classes**:
```java
// Main coordination
DhpoFetchCoordinator.pollFacilities()    // Facility polling
DhpoFetchCoordinator.downloadFilesForFacility() // Per-facility processing

// SOAP communication
DhpoSoapClient.sendRequest()             // SOAP request sending
DhpoSoapClient.getInbox()                // Inbox retrieval
DhpoSoapClient.downloadFile()            // File download

// File management
StagingService.stageFile()               // File staging
StagingService.cleanupStagedFiles()      // Cleanup

// Security
CredentialDecryptor.decrypt()            // Credential decryption
FacilityCredentialService.getCredentials() // Credential retrieval
```

**Database Tables**:
- `facility_credential` - Encrypted credentials
- `facility` - Facility information
- `ingestion_file` - Staged files

**Configuration**:
- `SoapProperties` - SOAP configuration
- `application-soap.yml` - SOAP-specific settings

---

### 3. Report Generation

**Business Feature**: Generate various business intelligence reports for claims analysis.

**Implementation**:
- **Main Controller**: `com.acme.claims.controller.ReportDataController`
- **Report Services**: Various `*ReportService` classes
- **View Generation**: `com.acme.claims.util.ReportViewGenerator`
- **Security**: `com.acme.claims.security.aspect.ReportSecurityAspect`

**Key Classes**:
```java
// Main controller
ReportDataController.generateReport()     // Report generation endpoint

// Report services
BalanceAmountReportService.generateReport() // Balance amount reports
ClaimDetailsWithActivityReportService.generateReport() // Claim details
DoctorDenialReportService.generateReport() // Doctor denial reports
RejectedClaimsReportService.generateReport() // Rejected claims
RemittanceAdvicePayerwiseReportService.generateReport() // Remittance reports
RemittancesResubmissionReportService.generateReport() // Resubmission reports

// View management
ReportViewGenerationController.generateView() // Materialized view creation
ReportViewGenerationController.refreshView() // View refresh
```

**Database Tables**:
- Materialized views for performance
- Report-specific tables
- Reference data tables

**Configuration**:
- Report-specific SQL files
- Materialized view definitions
- Performance tuning parameters

---

### 4. Multi-Tenancy

**Business Feature**: Isolate data by facility/tenant for security and compliance.

**Implementation**:
- **Context Management**: `com.acme.claims.security.context.FacilityContext`
- **Security Service**: `com.acme.claims.security.service.SecurityContextService`
- **Multi-Tenant Aspect**: `com.acme.claims.security.aspect.MultiTenantAspect`
- **Facility Service**: `com.acme.claims.admin.FacilityAdminService`

**Key Classes**:
```java
// Context management
FacilityContext.setCurrentFacility()     // Set facility context
FacilityContext.getCurrentFacility()     // Get facility context
FacilityContext.clear()                  // Clear context

// Security
SecurityContextService.getCurrentFacilityId() // Get facility from token
SecurityContextService.validateAccess()  // Validate access

// Multi-tenancy
MultiTenantAspect.applyFacilityFilter()  // Apply facility filter
MultiTenantFilter.doFilter()             // Request filtering
```

**Database Tables**:
- `facility` - Facility information
- `facility_config` - Facility-specific configuration
- All business tables include `facility_id`

**Configuration**:
- `SecurityProperties` - Security configuration
- JWT token claims for facility ID
- Database row-level security

---

### 5. Reference Data Management

**Business Feature**: Manage reference data (codes, facilities, payers) with caching.

**Implementation**:
- **Bootstrap**: `com.acme.claims.refdata.RefdataBootstrapRunner`
- **CSV Loader**: `com.acme.claims.refdata.RefdataCsvLoader`
- **Code Resolver**: `com.acme.claims.refdata.RefCodeResolver`
- **Admin Service**: `com.acme.claims.service.ReferenceDataService`

**Key Classes**:
```java
// Bootstrap
RefdataBootstrapRunner.run()             // Application startup
RefdataBootstrapRunner.loadReferenceData() // Data loading

// CSV processing
RefdataCsvLoader.loadFromCsv()           // CSV file loading
RefdataCsvLoader.parseCsvFile()           // CSV parsing

// Code resolution
RefCodeResolver.resolveCode()             // Code lookup
RefCodeResolver.getDescription()           // Description retrieval

// Administration
ReferenceDataService.getAllActivityCodes() // Data retrieval
ReferenceDataService.updateReferenceData() // Data updates
```

**Database Tables**:
- `ref_lookup` - Reference data lookup
- `activity_code` - Activity codes
- `diagnosis_code` - Diagnosis codes
- `denial_code` - Denial codes
- `facility` - Facilities
- `payer` - Payers
- `clinician` - Clinicians

**Configuration**:
- CSV files in `src/main/resources/refdata/`
- Cache configuration
- Bootstrap configuration

---

### 6. Audit Trail

**Business Feature**: Track all system activities for compliance and debugging.

**Implementation**:
- **Ingestion Audit**: `com.acme.claims.ingestion.audit.IngestionAudit`
- **Error Logging**: `com.acme.claims.ingestion.audit.ErrorLogger`
- **Run Tracking**: `com.acme.claims.ingestion.audit.RunContext`
- **Event Recording**: `com.acme.claims.ingestion.persist.EventProjectorMapper`

**Key Classes**:
```java
// Audit tracking
IngestionAudit.startRun()                // Start audit run
IngestionAudit.endRun()                   // End audit run
IngestionAudit.fileProcessed()            // File processing audit

// Error logging
ErrorLogger.fileError()                   // File error logging
ErrorLogger.logError()                    // General error logging

// Event recording
EventProjectorMapper.toSubmissionEvent()  // Submission events
EventProjectorMapper.toRemittanceEvent()  // Remittance events
```

**Database Tables**:
- `ingestion_run` - Run tracking
- `ingestion_file_audit` - File audit
- `ingestion_error` - Error logging
- `claim_event` - Event tracking
- `claim_status_timeline` - Status timeline

**Configuration**:
- Audit configuration
- Error logging configuration
- Event tracking configuration

---

### 7. Security & Authentication

**Business Feature**: Secure access control with JWT authentication and role-based authorization.

**Implementation**:
- **Security Config**: `com.acme.claims.security.config.SecurityConfig`
- **JWT Filter**: `com.acme.claims.security.filter.JwtAuthenticationFilter`
- **Role Control**: `com.acme.claims.security.service.RoleBasedAccessControl`
- **Rate Limiting**: `com.acme.claims.ratelimit.RateLimitInterceptor`

**Key Classes**:
```java
// Security configuration
SecurityConfig.securityFilterChain()      // Security filter chain
SecurityConfig.jwtAuthenticationFilter() // JWT filter setup

// Authentication
JwtAuthenticationFilter.doFilter()        // JWT token processing
JwtTokenProvider.validateToken()         // Token validation

// Authorization
RoleBasedAccessControl.checkAccess()     // Role checking
SecurityContextService.getCurrentUserRoles() // Role retrieval

// Rate limiting
RateLimitInterceptor.preHandle()         // Request rate limiting
```

**Database Tables**:
- `user` - User information
- `role` - Role definitions
- `user_role` - User-role mappings

**Configuration**:
- JWT configuration
- Security properties
- Rate limiting configuration

---

### 8. Monitoring & Health Checks

**Business Feature**: Monitor system health and performance metrics.

**Implementation**:
- **Database Monitoring**: `com.acme.claims.monitoring.DatabaseMonitoringService`
- **Health Metrics**: `com.acme.claims.monitoring.ApplicationHealthMetrics`
- **DHPO Metrics**: `com.acme.claims.metrics.DhpoMetrics`
- **Production Controller**: `com.acme.claims.monitoring.ProductionMonitoringController`

**Key Classes**:
```java
// Database monitoring
DatabaseMonitoringService.performHealthCheck() // Health checks
DatabaseHealthMetrics.recordQueryTime()        // Query metrics
DatabaseConnectionInterceptor.intercept()       // Connection monitoring

// Application health
ApplicationHealthMetrics.getHealthStatus()     // Health status
ProductionMonitoringController.health()        // Health endpoint

// DHPO metrics
DhpoMetrics.recordIngestion()                  // Ingestion metrics
DhpoMetrics.recordSoapCall()                  // SOAP metrics
```

**Database Tables**:
- `ingestion_batch_metric` - Performance metrics
- `verification_result` - Verification results

**Configuration**:
- Monitoring configuration
- Metrics configuration
- Health check configuration

---

## Feature Dependencies

### Ingestion Dependencies
```
XML Ingestion
├── Reference Data (for validation)
├── Security Context (for multi-tenancy)
├── Audit Trail (for tracking)
└── Database (for persistence)
```

### SOAP Integration Dependencies
```
SOAP Integration
├── Security Context (for facility access)
├── Credential Management (for authentication)
├── File Staging (for temporary storage)
└── Ingestion Pipeline (for processing)
```

### Report Generation Dependencies
```
Report Generation
├── Security Context (for access control)
├── Multi-Tenancy (for data isolation)
├── Reference Data (for code resolution)
└── Database (for data retrieval)
```

### Multi-Tenancy Dependencies
```
Multi-Tenancy
├── Security Context (for facility identification)
├── Database (for facility data)
├── JWT Tokens (for facility claims)
└── All Business Features (for data isolation)
```

---

## Feature Implementation Patterns

### Service Layer Pattern
```java
// All business features follow this pattern
@Service
public class FeatureService {
    private final FeatureRepository repository;
    private final FeatureMapper mapper;
    
    public FeatureResult processFeature(FeatureRequest request) {
        // 1. Validate request
        // 2. Process business logic
        // 3. Persist data
        // 4. Return result
    }
}
```

### Controller Pattern
```java
// All REST endpoints follow this pattern
@RestController
@RequestMapping("/api/feature")
@PreAuthorize("hasRole('REQUIRED_ROLE')")
public class FeatureController {
    
    @PostMapping("/process")
    public ResponseEntity<FeatureResponse> processFeature(
        @Valid @RequestBody FeatureRequest request) {
        // 1. Extract security context
        // 2. Validate request
        // 3. Call service
        // 4. Format response
    }
}
```

### Repository Pattern
```java
// All data access follows this pattern
@Repository
public interface FeatureRepository extends JpaRepository<Feature, Long> {
    
    @Query("SELECT f FROM Feature f WHERE f.facilityId = :facilityId")
    List<Feature> findByFacilityId(@Param("facilityId") String facilityId);
}
```

---

## Feature Testing Patterns

### Unit Testing
```java
@ExtendWith(MockitoExtension.class)
class FeatureServiceTest {
    @Mock
    private FeatureRepository repository;
    
    @InjectMocks
    private FeatureService service;
    
    @Test
    void shouldProcessFeature() {
        // Test implementation
    }
}
```

### Integration Testing
```java
@SpringBootTest
@Testcontainers
class FeatureServiceIntegrationTest {
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");
    
    @Autowired
    private FeatureService service;
    
    @Test
    void shouldProcessFeatureWithDatabase() {
        // Test implementation
    }
}
```

---

## Related Documentation

- [Class Index](../quick-ref/CLASS_INDEX.md) - Complete list of all classes
- [Finding Code Guide](../quick-ref/FINDING_CODE_GUIDE.md) - How to find specific functionality
- [Common Patterns](../quick-ref/COMMON_PATTERNS.md) - Recurring patterns in codebase
- [Component Map](../architecture/COMPONENT_MAP.md) - High-level architecture overview
- [Config to Code Map](CONFIG_TO_CODE_MAP.md) - Configuration mapping
- [Error Code to Handler Map](ERROR_CODE_TO_HANDLER_MAP.md) - Error handling mapping
