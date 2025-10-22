# Config to Code Map - Claims Backend Application

> Traceability matrix mapping configuration properties to their usage in the codebase. Use this to understand how configuration affects system behavior and where to find configuration-related code.

## Overview

This document provides a comprehensive mapping between configuration properties and their implementation in the claims-backend application. It helps developers understand how configuration affects system behavior and where to find configuration-related code.

---

## Application Configuration Files

### Base Configuration (`application.yml`)

**Purpose**: Core application configuration and default values.

**Key Properties**:
```yaml
spring:
  application:
    name: claims-backend
  profiles:
    active: localfs
  datasource:
    url: jdbc:postgresql://localhost:5432/claims
    username: claims_user
    password: claims_password
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: http://localhost:8080/auth/realms/claims
```

**Code Usage**:
- **Spring Boot Auto-configuration**: Automatic configuration
- **DataSource**: Database connection management
- **JPA**: Entity management and persistence
- **Security**: JWT token validation

---

### Local Filesystem Mode (`application-localfs.yml`)

**Purpose**: Configuration for local filesystem-based file processing.

**Key Properties**:
```yaml
spring:
  config:
    activate:
      on-profile: localfs

claims:
  ingestion:
    readyDirectory: data/ready
    processedDirectory: data/processed
    batchSize: 1000
    maxRetries: 3
    timeout: PT5M
  ack:
    enabled: false
```

**Code Usage**:
- **IngestionProperties**: `com.acme.claims.ingestion.config.IngestionProperties`
- **LocalFsFetcher**: `com.acme.claims.ingestion.fetch.LocalFsFetcher`
- **NoopAcker**: `com.acme.claims.ingestion.ack.NoopAcker`

**Implementation**:
```java
@ConfigurationProperties(prefix = "claims.ingestion")
@Component
public class IngestionProperties {
    private String readyDirectory = "data/ready";
    private String processedDirectory = "data/processed";
    private int batchSize = 1000;
    private int maxRetries = 3;
    private Duration timeout = Duration.ofMinutes(5);
    
    // Getters and setters
}
```

---

### SOAP Integration Mode (`application-soap.yml`)

**Purpose**: Configuration for SOAP-based file fetching and processing.

**Key Properties**:
```yaml
spring:
  config:
    activate:
      on-profile: soap

claims:
  soap:
    polling:
      interval: PT1M
      enabled: true
    download:
      concurrency: 5
      timeout: PT30S
    staging:
      directory: /var/claims/staging
      cleanup:
        enabled: true
        interval: PT1H
        retention: PT24H
    retry:
      maxAttempts: 3
      backoff:
        delay: PT1S
        multiplier: 2
  ack:
    enabled: true
```

**Code Usage**:
- **SoapProperties**: `com.acme.claims.soap.SoapProperties`
- **DhpoFetchCoordinator**: `com.acme.claims.soap.fetch.DhpoFetchCoordinator`
- **StagingService**: `com.acme.claims.soap.fetch.StagingService`
- **SoapAckerAdapter**: `com.acme.claims.ingestion.ack.soap.SoapAckerAdapter`

**Implementation**:
```java
@ConfigurationProperties(prefix = "claims.soap")
@Component
public class SoapProperties {
    private Polling polling = new Polling();
    private Download download = new Download();
    private Staging staging = new Staging();
    private Retry retry = new Retry();
    
    public static class Polling {
        private Duration interval = Duration.ofMinutes(1);
        private boolean enabled = true;
        // Getters and setters
    }
    
    public static class Download {
        private int concurrency = 5;
        private Duration timeout = Duration.ofSeconds(30);
        // Getters and setters
    }
    
    public static class Staging {
        private String directory = "/var/claims/staging";
        private Cleanup cleanup = new Cleanup();
        // Getters and setters
    }
    
    public static class Retry {
        private int maxAttempts = 3;
        private Backoff backoff = new Backoff();
        // Getters and setters
    }
}
```

---

### Production Mode (`application-prod.yml`)

**Purpose**: Production-specific configuration with security and performance optimizations.

**Key Properties**:
```yaml
spring:
  config:
    activate:
      on-profile: prod

logging:
  level:
    com.acme.claims: INFO
    org.springframework.security: WARN
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n"

management:
  endpoints:
    web:
      exposure:
        include: health,metrics,info
  endpoint:
    health:
      show-details: when-authorized

claims:
  security:
    multiTenancy:
      enabled: true
    jwt:
      validation:
        strict: true
  monitoring:
    database:
      enabled: true
      interval: PT1M
    metrics:
      enabled: true
      export:
        prometheus: true
```

**Code Usage**:
- **SecurityProperties**: `com.acme.claims.security.config.SecurityProperties`
- **DatabaseMonitoringService**: `com.acme.claims.monitoring.DatabaseMonitoringService`
- **ApplicationHealthMetrics**: `com.acme.claims.monitoring.ApplicationHealthMetrics`

---

### Admin Jobs Mode (`application-adminjobs.yml`)

**Purpose**: Configuration for administrative jobs and verification tasks.

**Key Properties**:
```yaml
spring:
  config:
    activate:
      on-profile: adminjobs

claims:
  admin:
    verification:
      enabled: true
      interval: PT24H
      export:
        directory: /var/claims/verify
        format: CSV
    reports:
      generation:
        enabled: true
        schedule: "0 0 2 * * ?"  # 2 AM daily
    cleanup:
      enabled: true
      interval: PT1W
      retention: PT90D
```

**Code Usage**:
- **VerificationService**: `com.acme.claims.ingestion.verify.VerifyService`
- **ReportViewGenerator**: `com.acme.claims.util.ReportViewGenerator`
- **BackupService**: `com.acme.claims.monitoring.BackupService`

---

## Configuration Properties Mapping

### Ingestion Configuration (`claims.ingestion.*`)

**Properties**:
```yaml
claims:
  ingestion:
    readyDirectory: data/ready
    processedDirectory: data/processed
    batchSize: 1000
    maxRetries: 3
    timeout: PT5M
    workers: 3
    burstSize: 10
    queueCapacity: 100
```

**Code Usage**:
- **IngestionProperties**: `com.acme.claims.ingestion.config.IngestionProperties`
- **Orchestrator**: `com.acme.claims.ingestion.Orchestrator`
- **Pipeline**: `com.acme.claims.ingestion.Pipeline`
- **LocalFsFetcher**: `com.acme.claims.ingestion.fetch.LocalFsFetcher`

**Implementation**:
```java
@ConfigurationProperties(prefix = "claims.ingestion")
@Component
public class IngestionProperties {
    private String readyDirectory = "data/ready";
    private String processedDirectory = "data/processed";
    private int batchSize = 1000;
    private int maxRetries = 3;
    private Duration timeout = Duration.ofMinutes(5);
    private int workers = 3;
    private int burstSize = 10;
    private int queueCapacity = 100;
    
    // Getters and setters
}
```

---

### SOAP Configuration (`claims.soap.*`)

**Properties**:
```yaml
claims:
  soap:
    polling:
      interval: PT1M
      enabled: true
    download:
      concurrency: 5
      timeout: PT30S
    staging:
      directory: /var/claims/staging
      cleanup:
        enabled: true
        interval: PT1H
        retention: PT24H
    retry:
      maxAttempts: 3
      backoff:
        delay: PT1S
        multiplier: 2
    endpoints:
      inbox: /soap/inbox
      download: /soap/download
      ack: /soap/ack
```

**Code Usage**:
- **SoapProperties**: `com.acme.claims.soap.SoapProperties`
- **DhpoFetchCoordinator**: `com.acme.claims.soap.fetch.DhpoFetchCoordinator`
- **DhpoSoapClient**: `com.acme.claims.soap.client.DhpoSoapClient`
- **StagingService**: `com.acme.claims.soap.fetch.StagingService`

**Implementation**:
```java
@ConfigurationProperties(prefix = "claims.soap")
@Component
public class SoapProperties {
    private Polling polling = new Polling();
    private Download download = new Download();
    private Staging staging = new Staging();
    private Retry retry = new Retry();
    private Endpoints endpoints = new Endpoints();
    
    // Nested configuration classes
    public static class Polling {
        private Duration interval = Duration.ofMinutes(1);
        private boolean enabled = true;
    }
    
    public static class Download {
        private int concurrency = 5;
        private Duration timeout = Duration.ofSeconds(30);
    }
    
    public static class Staging {
        private String directory = "/var/claims/staging";
        private Cleanup cleanup = new Cleanup();
    }
    
    public static class Retry {
        private int maxAttempts = 3;
        private Backoff backoff = new Backoff();
    }
    
    public static class Endpoints {
        private String inbox = "/soap/inbox";
        private String download = "/soap/download";
        private String ack = "/soap/ack";
    }
}
```

---

### Security Configuration (`claims.security.*`)

**Properties**:
```yaml
claims:
  security:
    multiTenancy:
      enabled: true
      defaultFacility: DEFAULT
    jwt:
      validation:
        strict: true
        clockSkew: PT5M
    roles:
      admin: CLAIMS_ADMIN
      ops: CLAIMS_OPS
      ro: CLAIMS_RO
    rateLimit:
      enabled: true
      requestsPerMinute: 100
      burstCapacity: 200
```

**Code Usage**:
- **SecurityProperties**: `com.acme.claims.security.config.SecurityProperties`
- **SecurityConfig**: `com.acme.claims.security.config.SecurityConfig`
- **JwtAuthenticationFilter**: `com.acme.claims.security.filter.JwtAuthenticationFilter`
- **RateLimitInterceptor**: `com.acme.claims.ratelimit.RateLimitInterceptor`

**Implementation**:
```java
@ConfigurationProperties(prefix = "claims.security")
@Component
public class SecurityProperties {
    private MultiTenancy multiTenancy = new MultiTenancy();
    private Jwt jwt = new Jwt();
    private Roles roles = new Roles();
    private RateLimit rateLimit = new RateLimit();
    
    public static class MultiTenancy {
        private boolean enabled = true;
        private String defaultFacility = "DEFAULT";
    }
    
    public static class Jwt {
        private Validation validation = new Validation();
        
        public static class Validation {
            private boolean strict = true;
            private Duration clockSkew = Duration.ofMinutes(5);
        }
    }
    
    public static class Roles {
        private String admin = "CLAIMS_ADMIN";
        private String ops = "CLAIMS_OPS";
        private String ro = "CLAIMS_RO";
    }
    
    public static class RateLimit {
        private boolean enabled = true;
        private int requestsPerMinute = 100;
        private int burstCapacity = 200;
    }
}
```

---

### Monitoring Configuration (`claims.monitoring.*`)

**Properties**:
```yaml
claims:
  monitoring:
    database:
      enabled: true
      interval: PT1M
      connectionPool:
        enabled: true
        warningThreshold: 80
        criticalThreshold: 95
    metrics:
      enabled: true
      export:
        prometheus: true
        jmx: false
    health:
      enabled: true
      interval: PT30S
      timeout: PT10S
```

**Code Usage**:
- **DatabaseMonitoringService**: `com.acme.claims.monitoring.DatabaseMonitoringService`
- **DatabaseHealthMetrics**: `com.acme.claims.monitoring.DatabaseHealthMetrics`
- **ApplicationHealthMetrics**: `com.acme.claims.monitoring.ApplicationHealthMetrics`

**Implementation**:
```java
@ConfigurationProperties(prefix = "claims.monitoring")
@Component
public class MonitoringProperties {
    private Database database = new Database();
    private Metrics metrics = new Metrics();
    private Health health = new Health();
    
    public static class Database {
        private boolean enabled = true;
        private Duration interval = Duration.ofMinutes(1);
        private ConnectionPool connectionPool = new ConnectionPool();
        
        public static class ConnectionPool {
            private boolean enabled = true;
            private int warningThreshold = 80;
            private int criticalThreshold = 95;
        }
    }
    
    public static class Metrics {
        private boolean enabled = true;
        private Export export = new Export();
        
        public static class Export {
            private boolean prometheus = true;
            private boolean jmx = false;
        }
    }
    
    public static class Health {
        private boolean enabled = true;
        private Duration interval = Duration.ofSeconds(30);
        private Duration timeout = Duration.ofSeconds(10);
    }
}
```

---

### Report Configuration (`claims.reports.*`)

**Properties**:
```yaml
claims:
  reports:
    generation:
      enabled: true
      timeout: PT5M
      maxRecords: 10000
    caching:
      enabled: true
      ttl: PT1H
      maxSize: 1000
    export:
      formats:
        - JSON
        - CSV
      directory: /var/claims/exports
    materializedViews:
      enabled: true
      refresh:
        interval: PT1H
        strategy: CONCURRENT
```

**Code Usage**:
- **ReportDataController**: `com.acme.claims.controller.ReportDataController`
- **ReportViewGenerationController**: `com.acme.claims.controller.ReportViewGenerationController`
- **CacheConfig**: `com.acme.claims.config.CacheConfig`

---

## Environment-Specific Configuration

### Development Environment
```yaml
# application-dev.yml
spring:
  config:
    activate:
      on-profile: dev

logging:
  level:
    com.acme.claims: DEBUG
    org.springframework.security: DEBUG

claims:
  ingestion:
    batchSize: 100
    workers: 1
  soap:
    polling:
      interval: PT10S
  security:
    multiTenancy:
      enabled: false
```

### Testing Environment
```yaml
# application-test.yml
spring:
  config:
    activate:
      on-profile: test

spring:
  datasource:
    url: jdbc:h2:mem:testdb
    driver-class-name: org.h2.Driver

claims:
  ingestion:
    readyDirectory: target/test-data/ready
    processedDirectory: target/test-data/processed
  ack:
    enabled: false
```

### Staging Environment
```yaml
# application-staging.yml
spring:
  config:
    activate:
      on-profile: staging

claims:
  security:
    multiTenancy:
      enabled: true
  monitoring:
    database:
      enabled: true
  reports:
    generation:
      enabled: true
```

---

## Configuration Validation

### Property Validation
```java
@ConfigurationProperties(prefix = "claims.ingestion")
@Validated
@Component
public class IngestionProperties {
    
    @NotBlank
    private String readyDirectory;
    
    @Min(1)
    @Max(10000)
    private int batchSize;
    
    @Min(1)
    @Max(10)
    private int maxRetries;
    
    @NotNull
    private Duration timeout;
    
    // Getters and setters
}
```

### Configuration Validation
```java
@Configuration
@EnableConfigurationProperties(IngestionProperties.class)
public class IngestionConfiguration {
    
    @Bean
    @ConditionalOnProperty(name = "claims.ingestion.enabled", havingValue = "true")
    public IngestionService ingestionService(IngestionProperties properties) {
        return new IngestionService(properties);
    }
}
```

---

## Configuration Testing

### Property Testing
```java
@SpringBootTest
@TestPropertySource(properties = {
    "claims.ingestion.batchSize=500",
    "claims.ingestion.maxRetries=5"
})
class IngestionPropertiesTest {
    
    @Autowired
    private IngestionProperties properties;
    
    @Test
    void shouldLoadProperties() {
        assertThat(properties.getBatchSize()).isEqualTo(500);
        assertThat(properties.getMaxRetries()).isEqualTo(5);
    }
}
```

### Configuration Testing
```java
@SpringBootTest
@ActiveProfiles("test")
class IngestionConfigurationTest {
    
    @Autowired
    private IngestionService ingestionService;
    
    @Test
    void shouldCreateIngestionService() {
        assertThat(ingestionService).isNotNull();
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
- [Error Code to Handler Map](ERROR_CODE_TO_HANDLER_MAP.md) - Error handling mapping
