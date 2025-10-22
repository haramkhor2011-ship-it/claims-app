# Class Index - Claims Backend Application

> Quick reference for all important classes in the claims-backend application. Use Ctrl+F to search for specific classes.

## A

### ActivityCode
- **Package**: `com.acme.claims.entity`
- **Purpose**: Reference data entity for activity codes
- **Primary Responsibility**: Maps activity codes to descriptions
- **Key Methods**: Standard JPA entity methods
- **Used By**: Report services, validation logic

### ApplicationHealthMetrics
- **Package**: `com.acme.claims.monitoring`
- **Purpose**: Collects and exposes application health metrics
- **Primary Responsibility**: Micrometer metrics integration
- **Key Methods**: `recordMetric()`, `getHealthStatus()`
- **Used By**: Monitoring dashboard, health checks

### AsyncConfig
- **Package**: `com.acme.claims.config`
- **Purpose**: Configures async processing for ingestion pipeline
- **Primary Responsibility**: Thread pool configuration
- **Key Methods**: `taskExecutor()`, `asyncExecutor()`
- **Used By**: Orchestrator, Pipeline

## B

### BalanceAmountReportService
- **Package**: `com.acme.claims.service`
- **Purpose**: Generates balance amount reports
- **Primary Responsibility**: SQL query execution and result formatting
- **Key Methods**: `generateReport()`, `validateParameters()`
- **Used By**: ReportDataController

## C

### CacheConfig
- **Package**: `com.acme.claims.config`
- **Purpose**: Configures caching for reference data
- **Primary Responsibility**: Cache manager setup
- **Key Methods**: `cacheManager()`, `cacheConfiguration()`
- **Used By**: Reference data services

### ClaimDetailsWithActivityReportService
- **Package**: `com.acme.claims.service`
- **Purpose**: Generates detailed claim reports with activity breakdown
- **Primary Responsibility**: Complex SQL joins and data aggregation
- **Key Methods**: `generateReport()`, `buildQuery()`
- **Used By**: ReportDataController

### ClaimSummaryMonthwiseReportService
- **Package**: `com.acme.claims.service`
- **Purpose**: Generates monthly claim summary reports
- **Primary Responsibility**: Time-based aggregation and grouping
- **Key Methods**: `generateReport()`, `aggregateByMonth()`
- **Used By**: ReportDataController

### ClaimsBackendApplication
- **Package**: `com.acme.claims`
- **Purpose**: Main Spring Boot application entry point
- **Primary Responsibility**: Application bootstrap and configuration
- **Key Methods**: `main()`, Spring Boot auto-configuration
- **Used By**: Application startup

### Clinician
- **Package**: `com.acme.claims.entity`
- **Purpose**: Reference data entity for clinicians
- **Primary Responsibility**: Clinician information storage
- **Key Methods**: Standard JPA entity methods
- **Used By**: Activity validation, report services

### CorrelationIdFilter
- **Package**: `com.acme.claims.filter`
- **Purpose**: Adds correlation IDs to requests for tracing
- **Primary Responsibility**: Request/response correlation
- **Key Methods**: `doFilter()`, `generateCorrelationId()`
- **Used By**: All HTTP requests

## D

### DatabaseConnectionInterceptor
- **Package**: `com.acme.claims.monitoring`
- **Purpose**: Monitors database connection health
- **Primary Responsibility**: Connection pool monitoring
- **Key Methods**: `intercept()`, `checkConnectionHealth()`
- **Used By**: Database monitoring service

### DatabaseHealthMetrics
- **Package**: `com.acme.claims.monitoring`
- **Purpose**: Collects database performance metrics
- **Primary Responsibility**: Query performance tracking
- **Key Methods**: `recordQueryTime()`, `getConnectionStats()`
- **Used By**: Monitoring dashboard

### DatabaseMonitoringService
- **Package**: `com.acme.claims.monitoring`
- **Purpose**: Central database monitoring coordinator
- **Primary Responsibility**: Health checks and metrics collection
- **Key Methods**: `performHealthCheck()`, `collectMetrics()`
- **Used By**: Health endpoints, monitoring controllers

### DenialCode
- **Package**: `com.acme.claims.entity`
- **Purpose**: Reference data entity for denial codes
- **Primary Responsibility**: Maps denial codes to descriptions
- **Key Methods**: Standard JPA entity methods
- **Used By**: Remittance processing, report services

### DiagnosisCode
- **Package**: `com.acme.claims.entity`
- **Purpose**: Reference data entity for diagnosis codes
- **Primary Responsibility**: Maps diagnosis codes to descriptions
- **Key Methods**: Standard JPA entity methods
- **Used By**: Encounter validation, report services

### DhpoFetchCoordinator
- **Package**: `com.acme.claims.soap.fetch`
- **Purpose**: Coordinates SOAP-based file fetching from DHPO
- **Primary Responsibility**: Multi-facility polling and file retrieval
- **Key Methods**: `pollFacilities()`, `downloadFiles()`, `stageFiles()`
- **Used By**: Orchestrator (SOAP mode)

### DhpoMetrics
- **Package**: `com.acme.claims.metrics`
- **Purpose**: Records DHPO-specific metrics
- **Primary Responsibility**: SOAP operation metrics
- **Key Methods**: `recordIngestion()`, `recordSoapCall()`
- **Used By**: Pipeline, SOAP services

### DhpoSoapClient
- **Package**: `com.acme.claims.soap.client`
- **Purpose**: Low-level SOAP client for DHPO communication
- **Primary Responsibility**: SOAP envelope construction and HTTP calls
- **Key Methods**: `sendRequest()`, `buildEnvelope()`
- **Used By**: DhpoFetchCoordinator, SoapAckerAdapter

### DoctorDenialReportService
- **Package**: `com.acme.claims.service`
- **Purpose**: Generates doctor-specific denial reports
- **Primary Responsibility**: Clinician-based denial analysis
- **Key Methods**: `generateReport()`, `aggregateByDoctor()`
- **Used By**: ReportDataController

## E

### ErrorLogger
- **Package**: `com.acme.claims.ingestion.audit`
- **Purpose**: Centralized error logging for ingestion pipeline
- **Primary Responsibility**: Error categorization and persistence
- **Key Methods**: `fileError()`, `logError()`
- **Used By**: Pipeline, Parser, PersistService

## F

### Facility
- **Package**: `com.acme.claims.entity`
- **Purpose**: Reference data entity for healthcare facilities
- **Primary Responsibility**: Facility information storage
- **Key Methods**: Standard JPA entity methods
- **Used By**: Multi-tenancy, report filtering

### FacilityAdminController
- **Package**: `com.acme.claims.admin`
- **Purpose**: Administrative operations for facilities
- **Primary Responsibility**: Facility management endpoints
- **Key Methods**: `createFacility()`, `updateFacility()`, `listFacilities()`
- **Used By**: Admin users, facility management

### FacilityAdminService
- **Package**: `com.acme.claims.admin`
- **Purpose**: Business logic for facility administration
- **Primary Responsibility**: Facility CRUD operations
- **Key Methods**: `saveFacility()`, `validateFacility()`
- **Used By**: FacilityAdminController

## G

### GlobalExceptionHandler
- **Package**: `com.acme.claims.controller`
- **Purpose**: Centralized exception handling for REST endpoints
- **Primary Responsibility**: Error response formatting
- **Key Methods**: `handleException()`, `formatErrorResponse()`
- **Used By**: All REST controllers

## H

### HttpSoapCaller
- **Package**: `com.acme.claims.soap.transport`
- **Purpose**: HTTP transport layer for SOAP calls
- **Primary Responsibility**: HTTP request/response handling
- **Key Methods**: `call()`, `buildHttpRequest()`
- **Used By**: DhpoSoapClient

## I

### IngestionAudit
- **Package**: `com.acme.claims.ingestion.audit`
- **Purpose**: Audits ingestion pipeline execution
- **Primary Responsibility**: Run tracking and file audit
- **Key Methods**: `startRun()`, `endRun()`, `fileProcessed()`
- **Used By**: Orchestrator, Pipeline

### IngestionErrorRecorder
- **Package**: `com.acme.claims.error`
- **Purpose**: Records ingestion errors for analysis
- **Primary Responsibility**: Error persistence and categorization
- **Key Methods**: `recordError()`, `categorizeError()`
- **Used By**: ErrorLogger

### IngestionProperties
- **Package**: `com.acme.claims.ingestion.config`
- **Purpose**: Configuration properties for ingestion pipeline
- **Primary Responsibility**: Pipeline tuning parameters
- **Key Methods**: Getters for all configuration properties
- **Used By**: Orchestrator, Pipeline, Fetchers

## L

### LocalFsFetcher
- **Package**: `com.acme.claims.ingestion.fetch`
- **Purpose**: Fetches files from local filesystem
- **Primary Responsibility**: File system monitoring and file retrieval
- **Key Methods**: `fetch()`, `watchDirectory()`
- **Used By**: Orchestrator (localfs mode)

## M

### MapStructCentralConfig
- **Package**: `com.acme.claims.mapper`
- **Purpose**: Central configuration for MapStruct mappers
- **Primary Responsibility**: Mapper configuration and customization
- **Key Methods**: Configuration methods for mapping strategies
- **Used By**: All MapStruct mappers

### MaterializedViewFixRunner
- **Package**: `com.acme.claims`
- **Purpose**: Utility for fixing materialized view issues
- **Primary Responsibility**: MV refresh and repair
- **Key Methods**: `fixMaterializedViews()`, `refreshViews()`
- **Used By**: Database maintenance scripts

## N

### NoopAcker
- **Package**: `com.acme.claims.ingestion.ack`
- **Purpose**: No-operation acknowledgment implementation
- **Primary Responsibility**: Placeholder for disabled ACK functionality
- **Key Methods**: `acknowledge()` (no-op)
- **Used By**: Pipeline (when ACK disabled)

## O

### OpenApiConfig
- **Package**: `com.acme.claims.config`
- **Purpose**: OpenAPI/Swagger documentation configuration
- **Primary Responsibility**: API documentation setup
- **Key Methods**: `openApi()`, `apiInfo()`
- **Used By**: Swagger UI, API documentation

### Orchestrator
- **Package**: `com.acme.claims.ingestion`
- **Purpose**: Main coordination engine for ingestion pipeline
- **Primary Responsibility**: Work item processing and flow control
- **Key Methods**: `process()`, `drain()`, `processOne()`
- **Used By**: Application startup, scheduled processing

## P

### Payer
- **Package**: `com.acme.claims.entity`
- **Purpose**: Reference data entity for payers
- **Primary Responsibility**: Payer information storage
- **Key Methods**: Standard JPA entity methods
- **Used By**: Claim validation, report services

### PersistService
- **Package**: `com.acme.claims.ingestion.persist`
- **Purpose**: Persists parsed data to database
- **Primary Responsibility**: Database transaction management
- **Key Methods**: `persistSubmission()`, `persistRemittance()`
- **Used By**: Pipeline

### Pipeline
- **Package**: `com.acme.claims.ingestion`
- **Purpose**: Core ingestion pipeline processor
- **Primary Responsibility**: Parse → Validate → Persist flow
- **Key Methods**: `process()`, `insertStub()`, `updateIngestionFileHeader()`
- **Used By**: Orchestrator

### ProductionMonitoringController
- **Package**: `com.acme.claims.monitoring`
- **Purpose**: Production monitoring endpoints
- **Primary Responsibility**: Health and metrics exposure
- **Key Methods**: `health()`, `metrics()`, `status()`
- **Used By**: Monitoring tools, load balancers

## R

### RateLimitInterceptor
- **Package**: `com.acme.claims.ratelimit`
- **Purpose**: Implements rate limiting for API endpoints
- **Primary Responsibility**: Request throttling
- **Key Methods**: `preHandle()`, `checkRateLimit()`
- **Used By**: All REST controllers

### RefCodeResolver
- **Package**: `com.acme.claims.refdata`
- **Purpose**: Resolves reference codes to descriptions
- **Primary Responsibility**: Code lookup and caching
- **Key Methods**: `resolveCode()`, `getDescription()`
- **Used By**: Report services, validation

### RefdataBootstrapRunner
- **Package**: `com.acme.claims.refdata`
- **Purpose**: Bootstraps reference data on application startup
- **Primary Responsibility**: Initial data loading
- **Key Methods**: `run()`, `loadReferenceData()`
- **Used By**: Application startup

### RefdataCsvLoader
- **Package**: `com.acme.claims.refdata`
- **Purpose**: Loads reference data from CSV files
- **Primary Responsibility**: CSV parsing and data import
- **Key Methods**: `loadFromCsv()`, `parseCsvFile()`
- **Used By**: RefdataBootstrapRunner

### ReferenceDataAdminController
- **Package**: `com.acme.claims.controller`
- **Purpose**: Administrative operations for reference data
- **Primary Responsibility**: Reference data management endpoints
- **Key Methods**: `updateReferenceData()`, `refreshCache()`
- **Used By**: Admin users

### ReferenceDataController
- **Package**: `com.acme.claims.controller`
- **Purpose**: Read-only reference data endpoints
- **Primary Responsibility**: Reference data lookup
- **Key Methods**: `getActivityCodes()`, `getDiagnosisCodes()`
- **Used By**: Frontend applications

### ReferenceDataService
- **Package**: `com.acme.claims.service`
- **Purpose**: Business logic for reference data operations
- **Primary Responsibility**: Reference data retrieval and caching
- **Key Methods**: `getAllActivityCodes()`, `getCodeDescription()`
- **Used By**: Reference data controllers

### RejectedClaimsReportService
- **Package**: `com.acme.claims.service`
- **Purpose**: Generates rejected claims reports
- **Primary Responsibility**: Denial analysis and reporting
- **Key Methods**: `generateReport()`, `analyzeRejections()`
- **Used By**: ReportDataController

### RemittanceAdvicePayerwiseReportService
- **Package**: `com.acme.claims.service`
- **Purpose**: Generates payer-wise remittance reports
- **Primary Responsibility**: Payer-based remittance analysis
- **Key Methods**: `generateReport()`, `aggregateByPayer()`
- **Used By**: ReportDataController

### RemittancesResubmissionReportService
- **Package**: `com.acme.claims.service`
- **Purpose**: Generates resubmission cycle reports
- **Primary Responsibility**: Resubmission tracking and analysis
- **Key Methods**: `generateReport()`, `trackResubmissions()`
- **Used By**: ReportDataController

### ReportDataController
- **Package**: `com.acme.claims.controller`
- **Purpose**: Main controller for report generation
- **Primary Responsibility**: Report request handling and response formatting
- **Key Methods**: `generateReport()`, `validateRequest()`
- **Used By**: Report clients

### ReportViewGenerationController
- **Package**: `com.acme.claims.controller`
- **Purpose**: Generates materialized views for reports
- **Primary Responsibility**: View creation and refresh
- **Key Methods**: `generateView()`, `refreshView()`
- **Used By**: Admin users, report optimization

### RootDetector
- **Package**: `com.acme.claims.ingestion.util`
- **Purpose**: Detects XML root type (Submission vs Remittance)
- **Primary Responsibility**: XML root element identification
- **Key Methods**: `detect()`, `isSubmission()`, `isRemittance()`
- **Used By**: Pipeline

## S

### SoapAckerAdapter
- **Package**: `com.acme.claims.ingestion.ack.soap`
- **Purpose**: SOAP-based acknowledgment sender
- **Primary Responsibility**: ACK message construction and sending
- **Key Methods**: `acknowledge()`, `buildAckMessage()`
- **Used By**: Pipeline (SOAP mode with ACK enabled)

### SoapConfig
- **Package**: `com.acme.claims.soap`
- **Purpose**: SOAP integration configuration
- **Primary Responsibility**: SOAP client setup and configuration
- **Key Methods**: `soapClient()`, `httpClientConfig()`
- **Used By**: SOAP services

### SoapFetcherAdapter
- **Package**: `com.acme.claims.ingestion.fetch.soap`
- **Purpose**: Adapter for SOAP-based file fetching
- **Primary Responsibility**: SOAP fetch coordination
- **Key Methods**: `fetch()`, `coordinateFetch()`
- **Used By**: Orchestrator (SOAP mode)

### SoapGateway
- **Package**: `com.acme.claims.soap`
- **Purpose**: High-level SOAP gateway for DHPO integration
- **Primary Responsibility**: SOAP operation coordination
- **Key Methods**: `fetchFiles()`, `sendAck()`
- **Used By**: DhpoFetchCoordinator, SoapAckerAdapter

### SoapProperties
- **Package**: `com.acme.claims.soap`
- **Purpose**: Configuration properties for SOAP integration
- **Primary Responsibility**: SOAP-specific settings
- **Key Methods**: Getters for SOAP configuration
- **Used By**: SOAP services

### StageParser
- **Package**: `com.acme.claims.ingestion.parser`
- **Purpose**: Parses XML files into DTOs
- **Primary Responsibility**: XML → DTO transformation
- **Key Methods**: `parse()`, `parseSubmission()`, `parseRemittance()`
- **Used By**: Pipeline

### StagingService
- **Package**: `com.acme.claims.soap.fetch`
- **Purpose**: Manages file staging for SOAP downloads
- **Primary Responsibility**: File staging and cleanup
- **Key Methods**: `stageFile()`, `cleanupStagedFiles()`
- **Used By**: DhpoFetchCoordinator

## V

### VerifyService
- **Package**: `com.acme.claims.ingestion.verify`
- **Purpose**: Verifies ingestion correctness
- **Primary Responsibility**: Post-persistence validation
- **Key Methods**: `verifyFile()`, `checkIntegrity()`
- **Used By**: Pipeline, Orchestrator

## W

### WorkItem
- **Package**: `com.acme.claims.ingestion.fetch`
- **Purpose**: Represents a file to be processed
- **Primary Responsibility**: File metadata container
- **Key Methods**: Getters for file properties
- **Used By**: Orchestrator, Pipeline

### WsSoapCaller
- **Package**: `com.acme.claims.soap.transport`
- **Purpose**: Web service SOAP caller implementation
- **Primary Responsibility**: SOAP envelope handling
- **Key Methods**: `call()`, `buildSoapEnvelope()`
- **Used By**: DhpoSoapClient

---

## How to Use This Index

1. **Find a class**: Use Ctrl+F to search for the class name
2. **Understand purpose**: Read the Purpose and Primary Responsibility
3. **Find usage**: Check the "Used By" section to see where it's used
4. **Navigate to code**: Use your IDE to navigate to the package/class
5. **Get detailed info**: Check the class's JavaDoc for detailed documentation

## Related Documentation

- [Finding Code Guide](FINDING_CODE_GUIDE.md) - How to find code for specific scenarios
- [Common Patterns](COMMON_PATTERNS.md) - Recurring patterns in the codebase
- [Component Map](../architecture/COMPONENT_MAP.md) - High-level architecture overview
