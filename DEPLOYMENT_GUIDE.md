# Deployment Guide

## Overview
This guide provides step-by-step instructions for deploying the Claims Backend application to various environments.

## Prerequisites
- Java 17+
- Maven 3.6+
- PostgreSQL 12+
- Docker (optional)
- Kubernetes (optional)

## Environment Configuration

### Development Environment
```yaml
# application-dev.yml
spring:
  profiles:
    active: dev
  datasource:
    url: jdbc:postgresql://localhost:5432/claims_dev
    username: claims_user
    password: claims_pass
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: true

security:
  enabled: false
  multi-tenancy:
    enabled: false

logging:
  level:
    com.acme.claims: DEBUG
```

### Staging Environment
```yaml
# application-staging.yml
spring:
  profiles:
    active: staging
  datasource:
    url: jdbc:postgresql://staging-db:5432/claims_staging
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false

security:
  enabled: true
  jwt:
    secret: ${JWT_SECRET}
    expiration: 86400000
  multi-tenancy:
    enabled: true

logging:
  level:
    com.acme.claims: INFO
```

### Production Environment
```yaml
# application-prod.yml
spring:
  profiles:
    active: prod
  datasource:
    url: jdbc:postgresql://prod-db:5432/claims_prod
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false

security:
  enabled: true
  jwt:
    secret: ${JWT_SECRET}
    expiration: 86400000
  multi-tenancy:
    enabled: true

logging:
  level:
    com.acme.claims: WARN
    root: WARN
```

## Database Setup

### 1. Create Database
```sql
CREATE DATABASE claims_dev;
CREATE DATABASE claims_staging;
CREATE DATABASE claims_prod;
```

### 2. Create User
```sql
CREATE USER claims_user WITH PASSWORD 'claims_pass';
GRANT ALL PRIVILEGES ON DATABASE claims_dev TO claims_user;
GRANT ALL PRIVILEGES ON DATABASE claims_staging TO claims_user;
GRANT ALL PRIVILEGES ON DATABASE claims_prod TO claims_user;
```

### 3. Run Database Scripts
```bash
# Run in order:
psql -d claims_dev -f src/main/resources/db/reports_sql/claims_agg_monthly_ddl.sql
psql -d claims_dev -f src/main/resources/db/reports_sql/sub_second_materialized_views.sql
psql -d claims_dev -f src/main/resources/db/reports_sql/balance_amount_report_implementation_final.sql
psql -d claims_dev -f src/main/resources/db/reports_sql/rejected_claims_report_final.sql
psql -d claims_dev -f src/main/resources/db/reports_sql/claim_details_with_activity_final.sql
psql -d claims_dev -f src/main/resources/db/reports_sql/doctor_denial_report_final.sql
psql -d claims_dev -f src/main/resources/db/reports_sql/remittances_resubmission_report_final.sql
psql -d claims_dev -f src/main/resources/db/reports_sql/remittance_advice_payerwise_report_final.sql
psql -d claims_dev -f src/main/resources/db/reports_sql/claim_summary_monthwise_report_final.sql
```

## Build and Deploy

### 1. Build Application
```bash
mvn clean package -DskipTests
```

### 2. Run Application
```bash
# Development
java -jar target/claims-backend-1.0.0.jar --spring.profiles.active=dev

# Staging
java -jar target/claims-backend-1.0.0.jar --spring.profiles.active=staging

# Production
java -jar target/claims-backend-1.0.0.jar --spring.profiles.active=prod
```

## Docker Deployment

### 1. Create Dockerfile
```dockerfile
FROM openjdk:17-jdk-slim

WORKDIR /app

COPY target/claims-backend-1.0.0.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
```

### 2. Build Docker Image
```bash
docker build -t claims-backend:latest .
```

### 3. Run Container
```bash
docker run -d \
  --name claims-backend \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=prod \
  -e DB_USERNAME=claims_user \
  -e DB_PASSWORD=claims_pass \
  -e JWT_SECRET=your-secret-key \
  claims-backend:latest
```

## Kubernetes Deployment

### 1. Create ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: claims-backend-config
data:
  application.yml: |
    spring:
      profiles:
        active: prod
      datasource:
        url: jdbc:postgresql://postgres:5432/claims_prod
        username: ${DB_USERNAME}
        password: ${DB_PASSWORD}
    security:
      enabled: true
      jwt:
        secret: ${JWT_SECRET}
        expiration: 86400000
```

### 2. Create Secret
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: claims-backend-secrets
type: Opaque
data:
  DB_USERNAME: Y2xhaW1zX3VzZXI=  # base64 encoded
  DB_PASSWORD: Y2xhaW1zX3Bhc3M=  # base64 encoded
  JWT_SECRET: eW91ci1zZWNyZXQta2V5  # base64 encoded
```

### 3. Create Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: claims-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: claims-backend
  template:
    metadata:
      labels:
        app: claims-backend
    spec:
      containers:
      - name: claims-backend
        image: claims-backend:latest
        ports:
        - containerPort: 8080
        envFrom:
        - secretRef:
            name: claims-backend-secrets
        volumeMounts:
        - name: config
          mountPath: /app/config
      volumes:
      - name: config
        configMap:
          name: claims-backend-config
```

### 4. Create Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: claims-backend-service
spec:
  selector:
    app: claims-backend
  ports:
  - port: 80
    targetPort: 8080
  type: LoadBalancer
```

## Health Checks

### 1. Application Health
```http
GET /actuator/health
```

### 2. Database Health
```http
GET /actuator/health/db
```

### 3. Custom Health Check
```http
GET /api/health
```

## Monitoring

### 1. Application Metrics
- Enable Micrometer metrics
- Configure Prometheus endpoint
- Set up Grafana dashboards

### 2. Log Aggregation
- Configure ELK stack
- Set up log shipping
- Create log-based alerts

### 3. Performance Monitoring
- Monitor JVM metrics
- Track database performance
- Set up alerting thresholds

## Security Considerations

### 1. Network Security
- Use HTTPS in production
- Configure firewall rules
- Implement network segmentation

### 2. Application Security
- Enable security features
- Configure proper CORS
- Implement rate limiting

### 3. Data Security
- Encrypt sensitive data
- Use secure connections
- Implement data masking

## Backup and Recovery

### 1. Database Backup
```bash
# Full backup
pg_dump -h localhost -U claims_user claims_prod > backup_$(date +%Y%m%d_%H%M%S).sql

# Incremental backup
pg_dump -h localhost -U claims_user --schema-only claims_prod > schema_backup.sql
```

### 2. Application Backup
- Backup configuration files
- Backup JAR files
- Backup Docker images

### 3. Recovery Procedures
- Document recovery steps
- Test recovery procedures
- Maintain recovery documentation

## Troubleshooting

### 1. Common Issues
- Database connection failures
- Memory issues
- Performance problems
- Security configuration errors

### 2. Debug Mode
- Enable debug logging
- Use remote debugging
- Monitor system resources

### 3. Support Contacts
- Database administrator
- System administrator
- Development team
- Security team
