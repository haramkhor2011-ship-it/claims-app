# Component Map - Claims Backend Application

> High-level architecture overview showing all major subsystems, their relationships, and key responsibilities.

## Architecture Overview

The Claims Backend Application follows a layered architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────────┐
│                        Presentation Layer                       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │   REST API   │ │   Admin UI  │ │   Reports   │ │   Health    │ │
│  │ Controllers  │ │ Controllers  │ │ Controllers │ │ Endpoints  │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│                         Security Layer                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │   JWT Auth  │ │   RBAC      │ │ Multi-Tenant│ │   Rate     │ │
│  │   Filter    │ │   Control   │ │   Context   │ │  Limiting  │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│                        Business Layer                           │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │ Ingestion   │ │   SOAP      │ │   Reports   │ │ Reference  │ │
│  │  Services   │ │ Integration │ │  Services   │ │   Data     │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│                        Data Access Layer                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │   JPA       │ │  MapStruct  │ │   JDBC      │ │   Cache     │ │
│  │ Repositories│ │   Mappers   │ │  Templates  │ │  Manager    │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│                        Infrastructure Layer                     │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │ PostgreSQL  │ │   File      │ │   SOAP      │ │ Monitoring │ │
│  │  Database   │ │   System    │ │  Services   │ │   & Logs   │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Major Components

### 1. Ingestion Pipeline System

**Purpose**: Processes XML files (submissions and remittances) through a complete pipeline.

**Key Components**:
- **Orchestrator** (`com.acme.claims.ingestion.Orchestrator`)
  - Coordinates the entire ingestion process
  - Manages work queue and backpressure
  - Handles error recovery and retry logic

- **Pipeline** (`com.acme.claims.ingestion.Pipeline`)
  - Core processing engine
  - Parse → Validate → Persist → Verify flow
  - Transaction management and error handling

- **StageParser** (`com.acme.claims.ingestion.parser.StageParser`)
  - XML parsing using StAX
  - Converts XML to DTOs
  - Handles both Submission and Remittance formats

- **PersistService** (`com.acme.claims.ingestion.persist.PersistService`)
  - Database persistence logic
  - Batch processing for performance
  - Transaction boundary management

- **VerifyService** (`com.acme.claims.ingestion.verify.VerifyService`)
  - Post-persistence validation
  - Data integrity checks
  - Error detection and reporting

**Dependencies**:
- Database (PostgreSQL)
- File system (for localfs mode)
- Configuration (IngestionProperties)

**Used By**:
- Orchestrator coordinates the pipeline
- Admin endpoints for manual processing
- Monitoring for health checks

---

### 2. SOAP Integration System

**Purpose**: Integrates with DHPO SOAP services for file fetching and acknowledgments.

**Key Components**:
- **DhpoFetchCoordinator** (`com.acme.claims.soap.fetch.DhpoFetchCoordinator`)
  - Multi-facility polling coordination
  - Structured concurrency with virtual threads
  - Download concurrency management

- **DhpoSoapClient** (`com.acme.claims.soap.client.DhpoSoapClient`)
  - Low-level SOAP communication
  - Envelope construction and HTTP calls
  - Error handling and retry logic

- **SoapFetcherAdapter** (`com.acme.claims.ingestion.fetch.soap.SoapFetcherAdapter`)
  - Adapter for SOAP-based file fetching
  - Integrates with Orchestrator
  - File staging and cleanup

- **SoapAckerAdapter** (`com.acme.claims.ingestion.ack.soap.SoapAckerAdapter`)
  - SOAP-based acknowledgment sending
  - ACK message construction
  - Error handling for ACK failures

- **StagingService** (`com.acme.claims.soap.fetch.StagingService`)
  - File staging management
  - Cleanup of staged files
  - Disk space management

**Dependencies**:
- DHPO SOAP services
- File system (for staging)
- Database (for credentials)
- Configuration (SoapProperties)

**Used By**:
- Orchestrator (SOAP mode)
- Pipeline (for ACK sending)
- Admin endpoints (for manual operations)

---

### 3. Reporting System

**Purpose**: Generates various reports for claims analysis and business intelligence.

**Key Components**:
- **ReportDataController** (`com.acme.claims.controller.ReportDataController`)
  - Main report generation endpoint
  - Request validation and response formatting
  - Security and multi-tenancy enforcement

- **Report Services** (`com.acme.claims.service.*ReportService`)
  - `BalanceAmountReportService`
  - `ClaimDetailsWithActivityReportService`
  - `ClaimSummaryMonthwiseReportService`
  - `DoctorDenialReportService`
  - `RejectedClaimsReportService`
  - `RemittanceAdvicePayerwiseReportService`
  - `RemittancesResubmissionReportService`

- **ReportViewGenerationController** (`com.acme.claims.controller.ReportViewGenerationController`)
  - Materialized view management
  - View creation and refresh
  - Performance optimization

- **ReportViewGenerator** (`com.acme.claims.util.ReportViewGenerator`)
  - Utility for view generation
  - SQL execution and management
  - Error handling

**Dependencies**:
- Database (PostgreSQL)
- Materialized views
- Reference data
- Security context

**Used By**:
- Frontend applications
- Business intelligence tools
- Admin users

---

### 4. Security & Authentication System

**Purpose**: Provides authentication, authorization, and multi-tenancy support.

**Key Components**:
- **SecurityConfig** (`com.acme.claims.security.config.SecurityConfig`)
  - Spring Security configuration
  - JWT token validation
  - Security filter chain setup

- **JwtAuthenticationFilter** (`com.acme.claims.security.filter.JwtAuthenticationFilter`)
  - JWT token processing
  - Authentication context setup
  - Token validation

- **SecurityContextService** (`com.acme.claims.security.service.SecurityContextService`)
  - Security context management
  - Role-based access control
  - User information extraction

- **FacilityContext** (`com.acme.claims.security.context.FacilityContext`)
  - Multi-tenant context management
  - Thread-local facility storage
  - Context propagation

- **MultiTenantAspect** (`com.acme.claims.security.aspect.MultiTenantAspect`)
  - Automatic multi-tenant filtering
  - Data isolation enforcement
  - Context-aware operations

**Dependencies**:
- JWT tokens
- Database (for user/role data)
- Configuration (SecurityProperties)

**Used By**:
- All REST endpoints
- Report generation
- Admin operations

---

### 5. Reference Data Management System

**Purpose**: Manages reference data (codes, facilities, payers, etc.) with caching.

**Key Components**:
- **RefdataBootstrapRunner** (`com.acme.claims.refdata.RefdataBootstrapRunner`)
  - Application startup data loading
  - CSV file processing
  - Initial data population

- **RefdataCsvLoader** (`com.acme.claims.refdata.RefdataCsvLoader`)
  - CSV file parsing and loading
  - Data validation and transformation
  - Error handling

- **RefCodeResolver** (`com.acme.claims.refdata.RefCodeResolver`)
  - Code lookup and resolution
  - Caching management
  - Performance optimization

- **Reference Data Services** (`com.acme.claims.service.ReferenceDataService`)
  - Business logic for reference data
  - CRUD operations
  - Cache management

**Dependencies**:
- CSV files (in resources)
- Database (for persistence)
- Cache (for performance)

**Used By**:
- Report generation
- Validation logic
- Admin operations

---

### 6. Monitoring & Observability System

**Purpose**: Provides health checks, metrics, and monitoring capabilities.

**Key Components**:
- **DatabaseMonitoringService** (`com.acme.claims.monitoring.DatabaseMonitoringService`)
  - Database health monitoring
  - Connection pool monitoring
  - Query performance tracking

- **ApplicationHealthMetrics** (`com.acme.claims.monitoring.ApplicationHealthMetrics`)
  - Application health indicators
  - Dependency health checks
  - Health status aggregation

- **DhpoMetrics** (`com.acme.claims.metrics.DhpoMetrics`)
  - DHPO-specific metrics
  - Ingestion performance metrics
  - SOAP operation metrics

- **ProductionMonitoringController** (`com.acme.claims.monitoring.ProductionMonitoringController`)
  - Health endpoint exposure
  - Metrics endpoint exposure
  - Status information

**Dependencies**:
- Micrometer (for metrics)
- Database (for health checks)
- External services (for dependency checks)

**Used By**:
- Load balancers (for health checks)
- Monitoring systems (for metrics)
- Operations teams (for status)

---

### 7. Configuration Management System

**Purpose**: Manages application configuration across different environments.

**Key Components**:
- **IngestionProperties** (`com.acme.claims.ingestion.config.IngestionProperties`)
  - Ingestion pipeline configuration
  - Performance tuning parameters
  - Feature flags

- **SoapProperties** (`com.acme.claims.soap.SoapProperties`)
  - SOAP integration configuration
  - Endpoint settings
  - Timeout and retry settings

- **SecurityProperties** (`com.acme.claims.security.config.SecurityProperties`)
  - Security configuration
  - Multi-tenancy settings
  - Role definitions

- **Profile-Based Configuration** (`application*.yml`)
  - Environment-specific settings
  - Feature toggles
  - External service configurations

**Dependencies**:
- Spring Boot configuration
- Environment variables
- External configuration sources

**Used By**:
- All application components
- Service initialization
- Feature toggling

---

## Component Interactions

### Ingestion Flow
```
Orchestrator → Pipeline → StageParser → PersistService → VerifyService
     ↓              ↓           ↓            ↓             ↓
  WorkQueue    Transaction   DTOs      Database      Audit
     ↓              ↓           ↓            ↓             ↓
  Fetcher      ErrorLogger   Validation   Events      Metrics
```

### SOAP Integration Flow
```
DhpoFetchCoordinator → DhpoSoapClient → StagingService → Orchestrator
         ↓                    ↓              ↓              ↓
    Facility Polling      SOAP Calls    File Staging   Work Queue
         ↓                    ↓              ↓              ↓
    Credentials         HTTP Transport   Disk Storage   Pipeline
```

### Report Generation Flow
```
ReportDataController → ReportService → Database → MaterializedView
         ↓                ↓             ↓             ↓
    Security Check    Business Logic   SQL Query   Performance
         ↓                ↓             ↓             ↓
    Multi-Tenant      Validation      Results      Caching
```

### Security Flow
```
JwtAuthenticationFilter → SecurityContextService → FacilityContext
         ↓                        ↓                    ↓
    Token Validation         Role Checking        Multi-Tenant
         ↓                        ↓                    ↓
    Authentication         Authorization         Data Isolation
```

---

## External Dependencies

### Database (PostgreSQL)
- **Purpose**: Primary data storage
- **Usage**: All persistent data, materialized views, functions
- **Connection**: JPA/Hibernate + JDBC templates
- **Monitoring**: Connection pool, query performance

### DHPO SOAP Services
- **Purpose**: External file fetching and acknowledgments
- **Usage**: SOAP integration system
- **Authentication**: Encrypted credentials per facility
- **Monitoring**: Call success rates, response times

### File System
- **Purpose**: File staging and local processing
- **Usage**: SOAP file staging, localfs mode
- **Monitoring**: Disk space, file operations
- **Security**: File permissions, cleanup

### JWT Token Provider
- **Purpose**: Authentication token validation
- **Usage**: Security system
- **Configuration**: Public key, token validation
- **Monitoring**: Token validation success rates

---

## Deployment Profiles

### localfs Profile
- **Purpose**: Local file system processing
- **Components**: LocalFsFetcher, NoopAcker
- **Use Case**: Development, testing, small-scale processing

### soap Profile
- **Purpose**: SOAP-based file fetching
- **Components**: DhpoFetchCoordinator, SoapAckerAdapter
- **Use Case**: Production integration with DHPO

### api Profile
- **Purpose**: REST API server only
- **Components**: Controllers, security, reports
- **Use Case**: API-only deployment, read-only operations

### adminjobs Profile
- **Purpose**: Administrative jobs and verification
- **Components**: Verification services, report generation
- **Use Case**: Nightly jobs, maintenance operations

---

## Performance Characteristics

### Ingestion Pipeline
- **Throughput**: Configurable batch sizes (default 1000)
- **Concurrency**: Configurable worker threads (default 3)
- **Memory**: Streaming XML parsing (StAX)
- **Transactions**: Per-file or per-chunk boundaries

### SOAP Integration
- **Concurrency**: Structured concurrency with virtual threads
- **Polling**: Configurable intervals (default 1 minute)
- **Retry**: Exponential backoff with max retries
- **Staging**: Configurable staging directory

### Report Generation
- **Caching**: Materialized views for performance
- **Concurrency**: Configurable query timeouts
- **Memory**: Streaming result processing
- **Optimization**: Indexed queries, query optimization

### Database Operations
- **Connection Pool**: Configurable pool size
- **Batch Processing**: Batch inserts for performance
- **Transactions**: Appropriate isolation levels
- **Monitoring**: Query performance tracking

---

## Related Documentation

- [Class Index](../quick-ref/CLASS_INDEX.md) - Complete list of all classes
- [Finding Code Guide](../quick-ref/FINDING_CODE_GUIDE.md) - How to find specific functionality
- [Common Patterns](../quick-ref/COMMON_PATTERNS.md) - Recurring patterns in codebase
- [Ingestion Flow](../flows/INGESTION_FLOW_DETAILED.md) - Detailed ingestion process
- [SOAP Flow](../flows/SOAP_FETCH_FLOW.md) - SOAP integration process
- [Report Flow](../flows/REPORT_GENERATION_FLOW.md) - Report generation process
