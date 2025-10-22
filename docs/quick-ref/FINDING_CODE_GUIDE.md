# Finding Code Guide - Claims Backend Application

> Quick guide to finding code for common scenarios. Use this when you need to locate specific functionality or understand how to implement new features.

## Table of Contents

- [Authentication & Security](#authentication--security)
- [Data Ingestion](#data-ingestion)
- [SOAP Integration](#soap-integration)
- [Report Generation](#report-generation)
- [Database Operations](#database-operations)
- [Error Handling](#error-handling)
- [Configuration](#configuration)
- [Monitoring & Metrics](#monitoring--metrics)
- [Reference Data](#reference-data)
- [Multi-tenancy](#multi-tenancy)

---

## Authentication & Security

### Where is JWT token validation implemented?
- **Location**: `com.acme.claims.security.config.SecurityConfig`
- **Key Classes**: `JwtAuthenticationFilter`, `JwtTokenProvider`
- **Configuration**: `application.yml` → `spring.security.oauth2.resourceserver.jwt`

### Where are security roles defined?
- **Location**: `com.acme.claims.security.Role` (enum)
- **Key Classes**: `SecurityContextService`, `RoleBasedAccessControl`
- **Usage**: Controllers use `@PreAuthorize` annotations

### Where is facility-based access control implemented?
- **Location**: `com.acme.claims.security.context.FacilityContext`
- **Key Classes**: `FacilitySecurityService`, `MultiTenantFilter`
- **Configuration**: `claims.security.multiTenancy.enabled`

---

## Data Ingestion

### Where is the main ingestion pipeline implemented?
- **Location**: `com.acme.claims.ingestion.Pipeline`
- **Entry Point**: `process(WorkItem)` method
- **Flow**: Parse → Validate → Persist → Verify → Audit

### Where is XML parsing handled?
- **Location**: `com.acme.claims.ingestion.parser.StageParser`
- **Implementation**: `ClaimXmlParserStax` (StAX-based)
- **Configuration**: Parser workers count in `IngestionProperties`

### Where are validation rules defined?
- **Location**: `Pipeline.validateSubmission()` and `Pipeline.validateRemittance()`
- **Additional**: `com.acme.claims.validation.ClaimValidationUtil`
- **Database**: Constraints in `claims_unified_ddl_fresh.sql`

### Where is data persistence handled?
- **Location**: `com.acme.claims.ingestion.persist.PersistService`
- **Key Methods**: `persistSubmission()`, `persistRemittance()`
- **Mappers**: MapStruct mappers in `com.acme.claims.mapper`

### Where is the orchestrator that coordinates everything?
- **Location**: `com.acme.claims.ingestion.Orchestrator`
- **Key Methods**: `process()`, `drain()`, `processOne()`
- **Configuration**: `IngestionProperties` for tuning

---

## SOAP Integration

### Where is SOAP client configuration?
- **Location**: `com.acme.claims.soap.config.HttpClientConfig`
- **Key Classes**: `DhpoSoapClient`, `SoapConfig`
- **Configuration**: `application-soap.yml`

### Where is facility polling implemented?
- **Location**: `com.acme.claims.soap.fetch.DhpoFetchCoordinator`
- **Key Methods**: `pollFacilities()`, `downloadFiles()`
- **Configuration**: `claims.soap.polling.*` properties

### Where are SOAP credentials managed?
- **Location**: `com.acme.claims.soap.crypto.CredentialDecryptor`
- **Key Classes**: `FacilityCredentialService`, `SecretsManager`
- **Storage**: Encrypted in database, decrypted per request

### Where is file staging handled?
- **Location**: `com.acme.claims.soap.fetch.StagingService`
- **Key Methods**: `stageFile()`, `cleanupStagedFiles()`
- **Configuration**: `claims.soap.staging.*` properties

### Where are SOAP acknowledgments sent?
- **Location**: `com.acme.claims.ingestion.ack.soap.SoapAckerAdapter`
- **Key Methods**: `acknowledge()`, `buildAckMessage()`
- **Configuration**: `claims.ack.enabled` property

---

## Report Generation

### Where are report services implemented?
- **Location**: `com.acme.claims.service.*ReportService`
- **Key Services**: 
  - `BalanceAmountReportService`
  - `ClaimDetailsWithActivityReportService`
  - `DoctorDenialReportService`
  - `RejectedClaimsReportService`
  - `RemittanceAdvicePayerwiseReportService`
  - `RemittancesResubmissionReportService`

### Where is the main report controller?
- **Location**: `com.acme.claims.controller.ReportDataController`
- **Key Methods**: `generateReport()`, `validateRequest()`
- **Security**: Role-based access control

### Where are SQL queries for reports defined?
- **Location**: `src/main/resources/db/reports_sql/`
- **Key Files**: 
  - `balance_amount_report_implementation_final.sql`
  - `claim_details_with_activity_final.sql`
  - `doctor_denial_report_final.sql`
  - etc.

### Where are materialized views for reports?
- **Location**: `src/main/resources/db/reports_sql/sub_second_materialized_views.sql`
- **Management**: `com.acme.claims.util.ReportViewGenerator`
- **Refresh**: `ReportViewGenerationController`

### Where is report security implemented?
- **Location**: `com.acme.claims.security.aspect.ReportSecurityAspect`
- **Key Classes**: `ReportAccessControl`, `MultiTenantReportFilter`
- **Configuration**: Role-based access in controllers

---

## Database Operations

### Where are JPA entities defined?
- **Location**: `com.acme.claims.domain.model.entity.*`
- **Key Entities**: 
  - `IngestionFile`, `Submission`, `Claim`, `Encounter`
  - `Activity`, `Observation`, `Remittance`, `RemittanceClaim`
- **Mappings**: JPA annotations, MapStruct mappers

### Where are repositories defined?
- **Location**: `com.acme.claims.domain.repo.*`
- **Key Repositories**: 
  - `IngestionFileRepository`, `ClaimRepository`
  - `ActivityRepository`, `RemittanceRepository`
- **Usage**: Injected into services

### Where are database functions defined?
- **Location**: `src/main/resources/db/claim_payment_functions.sql`
- **Key Functions**: 
  - `calculate_claim_payment()`
  - `get_claim_status_timeline()`
- **Usage**: Called from Java via `@Query` annotations

### Where is database monitoring implemented?
- **Location**: `com.acme.claims.monitoring.DatabaseMonitoringService`
- **Key Classes**: `DatabaseHealthMetrics`, `DatabaseConnectionInterceptor`
- **Configuration**: `DatabaseMonitoringConfiguration`

---

## Error Handling

### Where are ingestion errors logged?
- **Location**: `com.acme.claims.ingestion.audit.ErrorLogger`
- **Key Methods**: `fileError()`, `logError()`
- **Storage**: `ingestion_error` table

### Where is global exception handling?
- **Location**: `com.acme.claims.controller.GlobalExceptionHandler`
- **Key Methods**: `handleException()`, `formatErrorResponse()`
- **Usage**: All REST controllers

### Where are parse errors handled?
- **Location**: `com.acme.claims.ingestion.parser.ClaimXmlParserStax`
- **Error Types**: `ParseException`, `ValidationException`
- **Recovery**: Error logged, processing continues

### Where are database errors handled?
- **Location**: Transaction boundaries in `PersistService`
- **Error Types**: `DataAccessException`, `ConstraintViolationException`
- **Recovery**: Transaction rollback, error logging

---

## Configuration

### Where are application properties defined?
- **Location**: `src/main/resources/application*.yml`
- **Key Files**: 
  - `application.yml` (base)
  - `application-soap.yml` (SOAP config)
  - `application-prod.yml` (production)
  - `application-localfs.yml` (local filesystem)

### Where are Spring configurations?
- **Location**: `com.acme.claims.config.*`
- **Key Classes**: 
  - `AsyncConfig` (async processing)
  - `CacheConfig` (caching)
  - `OpenApiConfig` (API docs)
  - `SecurityConfig` (security)

### Where are SOAP-specific configurations?
- **Location**: `com.acme.claims.soap.SoapProperties`
- **Configuration**: `claims.soap.*` properties
- **Usage**: Injected into SOAP services

---

## Monitoring & Metrics

### Where are application metrics collected?
- **Location**: `com.acme.claims.metrics.DhpoMetrics`
- **Key Methods**: `recordIngestion()`, `recordSoapCall()`
- **Integration**: Micrometer, Prometheus

### Where is health monitoring implemented?
- **Location**: `com.acme.claims.monitoring.ApplicationHealthMetrics`
- **Key Classes**: `ProductionMonitoringController`
- **Endpoints**: `/actuator/health`, `/monitoring/status`

### Where are performance metrics tracked?
- **Location**: `com.acme.claims.monitoring.DatabaseHealthMetrics`
- **Key Metrics**: Query time, connection pool status
- **Storage**: Micrometer metrics registry

---

## Reference Data

### Where is reference data loaded?
- **Location**: `com.acme.claims.refdata.RefdataBootstrapRunner`
- **Key Classes**: `RefdataCsvLoader`
- **Data Source**: CSV files in `src/main/resources/refdata/`

### Where is reference data cached?
- **Location**: `com.acme.claims.refdata.RefCodeResolver`
- **Configuration**: `CacheConfig`
- **Cache Keys**: Code type + code value

### Where are reference data entities defined?
- **Location**: `com.acme.claims.entity.*`
- **Key Entities**: 
  - `ActivityCode`, `DiagnosisCode`, `DenialCode`
  - `Facility`, `Payer`, `Clinician`

---

## Multi-tenancy

### Where is facility context managed?
- **Location**: `com.acme.claims.security.context.FacilityContext`
- **Key Classes**: `FacilitySecurityService`
- **Usage**: Thread-local storage for current facility

### Where is multi-tenant filtering implemented?
- **Location**: `com.acme.claims.security.aspect.MultiTenantAspect`
- **Key Classes**: `MultiTenantFilter`
- **Configuration**: `claims.security.multiTenancy.enabled`

### Where are facility-specific configurations?
- **Location**: Database table `facility_config`
- **Management**: `FacilityAdminService`
- **Usage**: SOAP credentials, report settings

---

## Common Scenarios

### How do I add a new report?
1. **Create Service**: Extend `*ReportService` pattern
2. **Add Controller Method**: In `ReportDataController`
3. **Create SQL**: In `src/main/resources/db/reports_sql/`
4. **Add Security**: Role-based access control
5. **Test**: Validation and integration tests

### How do I add a new validation rule?
1. **Add to Pipeline**: `validateSubmission()` or `validateRemittance()`
2. **Create Utility**: In `ClaimValidationUtil` if reusable
3. **Add Error Handling**: In `ErrorLogger`
4. **Test**: Unit tests with valid/invalid data

### How do I modify the ingestion pipeline?
1. **Understand Flow**: `Orchestrator` → `Pipeline` → `PersistService`
2. **Identify Stage**: Parse, Validate, Persist, Verify
3. **Modify Logic**: In appropriate service class
4. **Update Tests**: Integration tests
5. **Check Impact**: Transaction boundaries, error handling

### How do I add a new SOAP operation?
1. **Extend Client**: `DhpoSoapClient` for new operations
2. **Add Configuration**: In `SoapProperties`
3. **Create Service**: Business logic wrapper
4. **Add Error Handling**: SOAP-specific error handling
5. **Test**: Mock SOAP responses

### How do I add a new reference data type?
1. **Create Entity**: In `com.acme.claims.entity`
2. **Create Repository**: In `com.acme.claims.domain.repo`
3. **Add CSV Loader**: In `RefdataCsvLoader`
4. **Add to Bootstrap**: In `RefdataBootstrapRunner`
5. **Update Cache**: In `RefCodeResolver`

---

## Quick Navigation Tips

### Use IDE Features
- **Ctrl+Shift+N**: Find class by name
- **Ctrl+Shift+F**: Find text in all files
- **Ctrl+Alt+H**: Find usages of method/class
- **Ctrl+B**: Go to declaration

### Use Git Features
- **git log --oneline --grep="keyword"**: Find commits by keyword
- **git blame filename**: See who changed what and when
- **git log -p filename**: See change history for file

### Use Documentation
- **JavaDoc**: Inline documentation in classes
- **README.md**: High-level system overview
- **API Documentation**: Swagger UI at `/swagger-ui.html`

---

## Related Documentation

- [Class Index](CLASS_INDEX.md) - Complete list of all classes
- [Common Patterns](COMMON_PATTERNS.md) - Recurring patterns in codebase
- [Component Map](../architecture/COMPONENT_MAP.md) - High-level architecture
- [Ingestion Flow](../flows/INGESTION_FLOW_DETAILED.md) - Detailed ingestion process
