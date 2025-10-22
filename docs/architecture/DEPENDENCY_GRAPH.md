# Dependency Graph - Claims Backend Application

> Visual representation of component dependencies and relationships in the claims-backend application.

## Layered Architecture Dependencies

```
┌─────────────────────────────────────────────────────────────────┐
│                        Presentation Layer                       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │   REST API   │ │   Admin UI  │ │   Reports   │ │   Health    │ │
│  │ Controllers  │ │ Controllers  │ │ Controllers │ │ Endpoints  │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
│           │               │               │               │       │
│           └───────────────┼───────────────┼───────────────┘       │
│                           │               │                       │
└───────────────────────────┼───────────────┼───────────────────────┘
                             │               │
┌───────────────────────────┼───────────────┼───────────────────────┐
│                         Security Layer                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │   JWT Auth  │ │   RBAC      │ │ Multi-Tenant│ │   Rate     │ │
│  │   Filter    │ │   Control   │ │   Context   │ │  Limiting  │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
│           │               │               │               │       │
│           └───────────────┼───────────────┼───────────────┘       │
│                           │               │                       │
└───────────────────────────┼───────────────┼───────────────────────┘
                             │               │
┌───────────────────────────┼───────────────┼───────────────────────┐
│                        Business Layer                           │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │ Ingestion   │ │   SOAP      │ │   Reports   │ │ Reference  │ │
│  │  Services   │ │ Integration │ │  Services   │ │   Data     │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
│           │               │               │               │       │
│           └───────────────┼───────────────┼───────────────┘       │
│                           │               │                       │
└───────────────────────────┼───────────────┼───────────────────────┘
                             │               │
┌───────────────────────────┼───────────────┼───────────────────────┐
│                        Data Access Layer                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │   JPA       │ │  MapStruct  │ │   JDBC      │ │   Cache     │ │
│  │ Repositories│ │   Mappers   │ │  Templates  │ │  Manager    │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
│           │               │               │               │       │
│           └───────────────┼───────────────┼───────────────┘       │
│                           │               │                       │
└───────────────────────────┼───────────────┼───────────────────────┘
                             │               │
┌───────────────────────────┼───────────────┼───────────────────────┐
│                        Infrastructure Layer                     │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │ PostgreSQL  │ │   File      │ │   SOAP      │ │ Monitoring │ │
│  │  Database   │ │   System    │ │  Services   │ │   & Logs   │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Spring Bean Dependency Tree

### Core Ingestion Components
```
Orchestrator
├── IngestionProperties
├── Fetcher (LocalFsFetcher | SoapFetcherAdapter)
├── Pipeline
│   ├── StageParser
│   │   └── ClaimXmlParserStax
│   ├── PersistService
│   │   ├── SubmissionGraphMapper
│   │   ├── RemittanceGraphMapper
│   │   └── EventProjectorMapper
│   ├── VerifyService
│   ├── ErrorLogger
│   ├── IngestionAudit
│   └── DhpoMetrics
├── Acker (NoopAcker | SoapAckerAdapter)
└── AsyncConfig (TaskExecutor)
```

### SOAP Integration Components
```
DhpoFetchCoordinator
├── SoapProperties
├── DhpoSoapClient
│   ├── HttpSoapCaller
│   └── WsSoapCaller
├── StagingService
├── FacilityCredentialService
│   └── CredentialDecryptor
└── SecretsManager
```

### Report Generation Components
```
ReportDataController
├── SecurityContextService
├── FacilityContext
├── ReportRequestValidator
└── Report Services
    ├── BalanceAmountReportService
    ├── ClaimDetailsWithActivityReportService
    ├── ClaimSummaryMonthwiseReportService
    ├── DoctorDenialReportService
    ├── RejectedClaimsReportService
    ├── RemittanceAdvicePayerwiseReportService
    └── RemittancesResubmissionReportService
```

### Security Components
```
SecurityConfig
├── JwtAuthenticationFilter
│   └── JwtTokenProvider
├── SecurityContextService
├── FacilityContext
├── MultiTenantAspect
├── RoleBasedAccessControl
└── ReportSecurityAspect
```

### Reference Data Components
```
RefdataBootstrapRunner
├── RefdataCsvLoader
├── RefCodeResolver
├── CacheConfig
└── Reference Data Repositories
    ├── ActivityCodeRepository
    ├── DiagnosisCodeRepository
    ├── DenialCodeRepository
    ├── FacilityRepository
    ├── PayerRepository
    └── ClinicianRepository
```

### Monitoring Components
```
DatabaseMonitoringService
├── DatabaseHealthMetrics
├── DatabaseConnectionInterceptor
├── ApplicationHealthMetrics
├── ProductionMonitoringController
└── DhpoMetrics
```

---

## Database Schema Relationships

### Core Ingestion Tables
```
ingestion_file
├── submission
│   ├── claim
│   │   ├── encounter
│   │   │   └── diagnosis
│   │   ├── activity
│   │   │   └── observation
│   │   ├── claim_resubmission
│   │   └── claim_contract
│   └── claim_attachment
└── remittance
    └── remittance_claim
        └── remittance_activity
```

### Event and Timeline Tables
```
claim_key
├── claim_event
│   ├── claim_event_activity
│   └── event_observation
└── claim_status_timeline
```

### Audit and Monitoring Tables
```
ingestion_run
├── ingestion_file_audit
├── ingestion_error
├── ingestion_batch_metric
└── verification_rule
    └── verification_result
```

### Reference Data Tables
```
ref_lookup
├── activity_code
├── diagnosis_code
├── denial_code
├── facility
├── payer
└── clinician
```

---

## External Service Dependencies

### DHPO SOAP Services
```
DhpoFetchCoordinator
├── Facility Polling
│   ├── GetInbox (per facility)
│   └── DownloadFile (per file)
└── Acknowledgment
    └── SendAck (per processed file)
```

### Database Connections
```
PostgreSQL Database
├── Primary Connection Pool
│   ├── Ingestion Operations
│   ├── Report Generation
│   └── Admin Operations
├── Read-Only Connection Pool
│   ├── Report Queries
│   └── Health Checks
└── Admin Connection Pool
    ├── Schema Changes
    └── Maintenance Operations
```

### File System Dependencies
```
File System
├── Local File System (localfs mode)
│   ├── data/ready/ (input)
│   └── data/processed/ (output)
└── Staging Directory (SOAP mode)
    ├── temp/ (staging)
    └── archive/ (processed)
```

---

## Configuration Dependencies

### Application Properties
```
application.yml (base)
├── application-localfs.yml
├── application-soap.yml
├── application-prod.yml
└── application-adminjobs.yml
```

### Configuration Classes
```
@ConfigurationProperties
├── IngestionProperties
│   ├── batchSize
│   ├── maxRetries
│   └── timeout
├── SoapProperties
│   ├── endpoints
│   ├── credentials
│   └── polling
└── SecurityProperties
    ├── jwt
    ├── roles
    └── multiTenancy
```

---

## Dependency Injection Patterns

### Constructor Injection (Preferred)
```java
@Service
public class ClaimService {
    private final ClaimRepository repository;
    private final ClaimMapper mapper;
    
    public ClaimService(ClaimRepository repository, ClaimMapper mapper) {
        this.repository = repository;
        this.mapper = mapper;
    }
}
```

### Field Injection (Avoid)
```java
@Service
public class ClaimService {
    @Autowired
    private ClaimRepository repository;
    
    @Autowired
    private ClaimMapper mapper;
}
```

### Method Injection (Special Cases)
```java
@Service
public class Pipeline {
    @Autowired
    @Lazy
    private Pipeline self; // For self-injection
}
```

---

## Circular Dependencies

### Avoided Patterns
```java
// BAD: Circular dependency
@Service
public class ServiceA {
    private final ServiceB serviceB;
}

@Service
public class ServiceB {
    private final ServiceA serviceA;
}
```

### Resolved Patterns
```java
// GOOD: Use events or callbacks
@Service
public class ServiceA {
    private final ApplicationEventPublisher eventPublisher;
    
    public void doSomething() {
        eventPublisher.publishEvent(new SomeEvent());
    }
}

@Service
public class ServiceB {
    @EventListener
    public void handleEvent(SomeEvent event) {
        // Handle event
    }
}
```

---

## Dependency Management

### Spring Boot Starters
```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-security</artifactId>
    </dependency>
</dependencies>
```

### Custom Dependencies
```xml
<dependencies>
    <dependency>
        <groupId>org.mapstruct</groupId>
        <artifactId>mapstruct</artifactId>
    </dependency>
    <dependency>
        <groupId>io.jsonwebtoken</groupId>
        <artifactId>jjwt-api</artifactId>
    </dependency>
</dependencies>
```

---

## Dependency Testing

### Unit Testing
```java
@ExtendWith(MockitoExtension.class)
class ClaimServiceTest {
    @Mock
    private ClaimRepository repository;
    
    @Mock
    private ClaimMapper mapper;
    
    @InjectMocks
    private ClaimService service;
    
    @Test
    void shouldFindClaimById() {
        // Test implementation
    }
}
```

### Integration Testing
```java
@SpringBootTest
@Testcontainers
class ClaimServiceIntegrationTest {
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");
    
    @Autowired
    private ClaimService service;
    
    @Test
    void shouldPersistClaim() {
        // Test implementation
    }
}
```

---

## Related Documentation

- [Component Map](COMPONENT_MAP.md) - High-level architecture overview
- [Class Index](../quick-ref/CLASS_INDEX.md) - Complete list of all classes
- [Finding Code Guide](../quick-ref/FINDING_CODE_GUIDE.md) - How to find specific functionality
- [Common Patterns](../quick-ref/COMMON_PATTERNS.md) - Recurring patterns in codebase
- [Ingestion Flow](../flows/INGESTION_FLOW_DETAILED.md) - Detailed ingestion process
