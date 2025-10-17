# Operations & Deployment Guide
## Claims Processing System - Complete Operational Reference

---

## 📋 Overview

This document provides comprehensive operational guidance for deploying, monitoring, and maintaining the Claims Processing System in production environments.

---

## 🚀 Deployment Strategies

### **Docker Deployment (Recommended)**

#### **Quick Start**
```bash
# 1. Generate AME keystore
./docker/scripts/generate-ame-keystore.sh

# 2. Configure environment
cp .env.example .env
# Edit .env with your configuration

# 3. Deploy all services
./docker/scripts/deploy.sh

# 4. Verify deployment
docker-compose ps
curl http://localhost:8080/actuator/health
```

#### **Docker Compose Architecture**
```yaml
version: '3.8'
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: claims
      POSTGRES_USER: claims_user
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  db-init:
    image: claims-backend:latest
    profiles: ["init"]
    environment:
      SPRING_PROFILES_ACTIVE: docker,db-init
    depends_on:
      - postgres

  app:
    image: claims-backend:latest
    environment:
      SPRING_PROFILES_ACTIVE: docker,ingestion,prod,soap
      DHPO_SOAP_ENDPOINT: ${DHPO_SOAP_ENDPOINT}
      CLAIMS_AME_STORE_PASS: ${CLAIMS_AME_STORE_PASS}
    volumes:
      - ./config:/app/config
      - ./data/ready:/app/data/ready
      - ./logs:/app/logs
    ports:
      - "8080:8080"
    depends_on:
      - postgres
      - db-init
```

### **Production Deployment**

#### **Infrastructure Requirements**
- **CPU**: 4+ cores (8+ recommended)
- **Memory**: 8GB+ RAM (16GB+ recommended)
- **Storage**: 100GB+ SSD (500GB+ recommended)
- **Network**: High-bandwidth, low-latency
- **OS**: Linux (Ubuntu 20.04+ or RHEL 8+)

#### **Environment Configuration**
```bash
# Database Configuration
export POSTGRES_DB="claims"
export POSTGRES_USER="claims_user"
export POSTGRES_PASSWORD="secure_password_here"

# Application Configuration
export SPRING_PROFILES_ACTIVE="prod,ingestion,soap"
export DHPO_SOAP_ENDPOINT="https://production.eclaimlink.ae/dhpo/ValidateTransactions.asmx"

# Security Configuration
export JWT_SECRET="your-super-secure-256-bit-secret-key"
export CLAIMS_AME_STORE_PASS="your-ame-keystore-password"

# Monitoring Configuration
export LOG_LEVEL="INFO"
export METRICS_ENABLED="true"
```

### **Kubernetes Deployment**

#### **Deployment Manifests**
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
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: "k8s,ingestion,soap"
        - name: POSTGRES_HOST
          value: "postgres-service"
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
```

---

## 🔧 Configuration Management

### **Environment-Specific Configuration**

#### **Development Environment**
```yaml
# application-dev.yml
claims:
  security:
    enabled: false
  ingestion:
    batch-size: 100
    queue-capacity: 1000
  soap:
    timeout: 30000
    retry-attempts: 3

logging:
  level:
    com.acme.claims: DEBUG
```

#### **Production Environment**
```yaml
# application-prod.yml
claims:
  security:
    enabled: true
    jwt:
      secret: ${JWT_SECRET}
  ingestion:
    batch-size: 1000
    queue-capacity: 10000
  soap:
    timeout: 60000
    retry-attempts: 5

logging:
  level:
    com.acme.claims: INFO
    org.springframework: WARN
```

### **Secrets Management**

#### **Environment Variables**
```bash
# Database Secrets
export DB_PASSWORD="$(vault kv get -field=password secret/claims/database)"
export DB_USERNAME="$(vault kv get -field=username secret/claims/database)"

# JWT Secret
export JWT_SECRET="$(vault kv get -field=secret secret/claims/jwt)"

# AME Keystore Password
export CLAIMS_AME_STORE_PASS="$(vault kv get -field=password secret/claims/ame)"
```

#### **Kubernetes Secrets**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: claims-secrets
type: Opaque
data:
  db-password: <base64-encoded-password>
  jwt-secret: <base64-encoded-secret>
  ame-password: <base64-encoded-password>
```

---

## 📊 Monitoring & Observability

### **Application Monitoring**

#### **Health Checks**
```bash
# Application Health
curl http://localhost:8080/actuator/health

# Detailed Health
curl http://localhost:8080/actuator/health/liveness
curl http://localhost:8080/actuator/health/readiness

# Custom Health Endpoints
curl http://localhost:8080/actuator/health/db
curl http://localhost:8080/actuator/health/soap
```

#### **Metrics Collection**
```bash
# Prometheus Metrics
curl http://localhost:8080/actuator/prometheus

# Custom Metrics
curl http://localhost:8080/actuator/metrics/claims.ingestion.files.processed
curl http://localhost:8080/actuator/metrics/claims.ingestion.claims.parsed
curl http://localhost:8080/actuator/metrics/claims.ingestion.errors.count
```

### **Database Monitoring**

#### **Performance Metrics**
```sql
-- Connection Pool Status
SELECT * FROM pg_stat_activity WHERE state = 'active';

-- Database Size
SELECT pg_size_pretty(pg_database_size('claims'));

-- Table Sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'claims'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Index Usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes 
WHERE schemaname = 'claims'
ORDER BY idx_scan DESC;
```

#### **Ingestion KPIs**
```sql
-- Ingestion Performance
SELECT * FROM claims.v_ingestion_kpis 
ORDER BY hour_bucket DESC 
LIMIT 24;

-- File Processing Status
SELECT 
    DATE(created_at) as date,
    COUNT(*) as total_files,
    SUM(CASE WHEN verified = true THEN 1 ELSE 0 END) as verified_files,
    SUM(CASE WHEN verified = false THEN 1 ELSE 0 END) as failed_files
FROM claims.ingestion_file_audit 
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

### **Log Monitoring**

#### **Log Analysis**
```bash
# Application Logs
tail -f logs/application.log

# Error Logs
grep "ERROR" logs/application.log | tail -20

# Ingestion Logs
grep "INGESTION" logs/application.log | tail -20

# Security Logs
grep "SECURITY" logs/application.log | tail -20
```

#### **Log Aggregation**
```yaml
# ELK Stack Configuration
version: '3.8'
services:
  elasticsearch:
    image: elasticsearch:8.5.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ports:
      - "9200:9200"

  logstash:
    image: logstash:8.5.0
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    ports:
      - "5044:5044"

  kibana:
    image: kibana:8.5.0
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    ports:
      - "5601:5601"
```

---

## 🔄 Backup & Recovery

### **Database Backup Strategy**

#### **Automated Backups**
```bash
#!/bin/bash
# backup-database.sh

BACKUP_DIR="/var/backups/claims"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="claims_backup_${DATE}.sql"

# Create backup directory
mkdir -p $BACKUP_DIR

# Perform backup
pg_dump -h localhost -U claims_user -d claims > $BACKUP_DIR/$BACKUP_FILE

# Compress backup
gzip $BACKUP_DIR/$BACKUP_FILE

# Remove backups older than 30 days
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete

# Verify backup
if [ -f "$BACKUP_DIR/${BACKUP_FILE}.gz" ]; then
    echo "Backup completed successfully: $BACKUP_FILE.gz"
else
    echo "Backup failed!"
    exit 1
fi
```

#### **Recovery Procedures**
```bash
# Restore from backup
gunzip claims_backup_20250115_120000.sql.gz
psql -h localhost -U claims_user -d claims < claims_backup_20250115_120000.sql

# Verify restoration
psql -h localhost -U claims_user -d claims -c "SELECT COUNT(*) FROM claims.claim;"
```

### **File System Backup**

#### **Application Data Backup**
```bash
#!/bin/bash
# backup-application.sh

BACKUP_DIR="/var/backups/claims"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup configuration
tar -czf $BACKUP_DIR/config_${DATE}.tar.gz /app/config/

# Backup logs
tar -czf $BACKUP_DIR/logs_${DATE}.tar.gz /app/logs/

# Backup data files
tar -czf $BACKUP_DIR/data_${DATE}.tar.gz /app/data/
```

---

## 🚨 Incident Response

### **Common Issues & Solutions**

#### **Application Won't Start**
```bash
# Check logs
docker-compose logs app

# Check configuration
docker-compose config

# Check resources
docker stats

# Restart services
docker-compose restart app
```

#### **Database Connection Issues**
```bash
# Check database status
docker-compose logs postgres

# Check network connectivity
docker-compose exec app ping postgres

# Check credentials
docker-compose exec app env | grep POSTGRES

# Restart database
docker-compose restart postgres
```

#### **SOAP Integration Issues**
```bash
# Check SOAP endpoint
curl -I $DHPO_SOAP_ENDPOINT

# Check credentials
docker-compose exec app cat /app/config/ame-keystore.p12

# Check logs
grep "SOAP" logs/application.log | tail -20
```

### **Performance Issues**

#### **High Memory Usage**
```bash
# Check memory usage
docker stats

# Check JVM heap
curl http://localhost:8080/actuator/metrics/jvm.memory.used

# Restart with more memory
docker-compose up -d --scale app=0
docker-compose up -d --scale app=1
```

#### **Slow Database Queries**
```sql
-- Check active queries
SELECT pid, now() - pg_stat_activity.query_start AS duration, query 
FROM pg_stat_activity 
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';

-- Check slow queries
SELECT query, mean_time, calls, total_time
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;
```

---

## 🔧 Maintenance Procedures

### **Regular Maintenance Tasks**

#### **Daily Tasks**
```bash
# Check application health
curl http://localhost:8080/actuator/health

# Check disk space
df -h

# Check log file sizes
du -sh logs/*

# Check database size
psql -h localhost -U claims_user -d claims -c "SELECT pg_size_pretty(pg_database_size('claims'));"
```

#### **Weekly Tasks**
```bash
# Refresh materialized views
psql -h localhost -U claims_user -d claims -c "REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_balance_amount_summary;"

# Clean up old logs
find logs/ -name "*.log" -mtime +7 -delete

# Update statistics
psql -h localhost -U claims_user -d claims -c "ANALYZE;"

# Check backup status
ls -la /var/backups/claims/
```

#### **Monthly Tasks**
```bash
# Full database backup
./backup-database.sh

# Update application
docker-compose pull
docker-compose up -d

# Security audit
grep "SECURITY" logs/application.log | grep -i "failed\|error"

# Performance review
psql -h localhost -U claims_user -d claims -c "SELECT * FROM claims.v_ingestion_kpis ORDER BY hour_bucket DESC LIMIT 720;"
```

### **Update Procedures**

#### **Application Updates**
```bash
# 1. Backup current state
./backup-database.sh
./backup-application.sh

# 2. Pull new image
docker-compose pull

# 3. Stop application
docker-compose stop app

# 4. Start with new image
docker-compose up -d app

# 5. Verify deployment
curl http://localhost:8080/actuator/health

# 6. Monitor for issues
docker-compose logs -f app
```

#### **Database Updates**
```bash
# 1. Backup database
./backup-database.sh

# 2. Run migration scripts
psql -h localhost -U claims_user -d claims -f migration.sql

# 3. Verify migration
psql -h localhost -U claims_user -d claims -c "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1;"

# 4. Update application if needed
docker-compose up -d app
```

---

## 📈 Performance Tuning

### **Application Tuning**

#### **JVM Tuning**
```bash
# Production JVM settings
export JAVA_OPTS="-Xms2g -Xmx4g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+UseStringDeduplication"

# Docker configuration
environment:
  - JAVA_OPTS=${JAVA_OPTS}
```

#### **Database Tuning**
```sql
-- Connection pool settings
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;

-- Reload configuration
SELECT pg_reload_conf();
```

### **Monitoring Tuning**

#### **Metrics Collection**
```yaml
# application.yml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  metrics:
    export:
      prometheus:
        enabled: true
    distribution:
      percentiles-histogram:
        http.server.requests: true
```

#### **Log Level Tuning**
```yaml
# Production logging
logging:
  level:
    com.acme.claims: INFO
    org.springframework: WARN
    org.hibernate: WARN
    org.postgresql: WARN
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n"
```

---

## 🔒 Security Operations

### **Security Monitoring**

#### **Authentication Monitoring**
```bash
# Check failed login attempts
grep "Authentication failed" logs/application.log | tail -20

# Check account lockouts
grep "Account locked" logs/application.log | tail -20

# Check security events
grep "SECURITY" logs/application.log | tail -20
```

#### **Access Monitoring**
```sql
-- Check user access patterns
SELECT 
    user_id,
    action,
    COUNT(*) as access_count,
    MAX(timestamp) as last_access
FROM claims.security_audit_log 
WHERE timestamp >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY user_id, action
ORDER BY access_count DESC;
```

### **Security Maintenance**

#### **Password Rotation**
```bash
# Rotate JWT secret
export JWT_SECRET="new-secret-key"
docker-compose restart app

# Rotate AME keystore password
./docker/scripts/generate-ame-keystore.sh
docker-compose restart app
```

#### **User Management**
```bash
# List users
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/users

# Lock user
curl -X POST -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/users/123/lock?locked=true

# Unlock user
curl -X POST -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/admin/unlock-account/123
```

---

## 📚 Troubleshooting Guide

### **Common Error Messages**

#### **Database Errors**
```
ERROR: duplicate key value violates unique constraint
SOLUTION: Check for duplicate data, verify idempotency logic

ERROR: connection to server at "localhost" (127.0.0.1), port 5432 failed
SOLUTION: Check database service, verify connection string

ERROR: relation "claims.claim" does not exist
SOLUTION: Run database initialization, check schema
```

#### **Application Errors**
```
ERROR: Could not resolve placeholder 'jwt.secret' in value "${jwt.secret}"
SOLUTION: Set JWT_SECRET environment variable

ERROR: Failed to load keystore
SOLUTION: Generate AME keystore, check file permissions

ERROR: SOAP connection timeout
SOLUTION: Check network connectivity, verify SOAP endpoint
```

### **Debug Procedures**

#### **Enable Debug Logging**
```yaml
# application-debug.yml
logging:
  level:
    com.acme.claims: DEBUG
    org.springframework: DEBUG
    org.hibernate.SQL: DEBUG
    org.hibernate.type.descriptor.sql.BasicBinder: TRACE
```

#### **Database Debugging**
```sql
-- Enable query logging
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_min_duration_statement = 1000;
SELECT pg_reload_conf();

-- Check active connections
SELECT * FROM pg_stat_activity WHERE state = 'active';

-- Check locks
SELECT * FROM pg_locks WHERE NOT granted;
```

---

## 📋 Operational Checklists

### **Pre-Deployment Checklist**
- [ ] Database backup completed
- [ ] Configuration validated
- [ ] Security settings verified
- [ ] Monitoring configured
- [ ] Rollback plan prepared
- [ ] Team notified

### **Post-Deployment Checklist**
- [ ] Health checks passing
- [ ] Metrics collection active
- [ ] Logs being generated
- [ ] Performance within limits
- [ ] Security monitoring active
- [ ] Documentation updated

### **Daily Operations Checklist**
- [ ] Application health check
- [ ] Database performance check
- [ ] Log file review
- [ ] Backup verification
- [ ] Security event review
- [ ] Performance metrics review

---

## 📞 Support & Escalation

### **Support Contacts**
- **Level 1**: Operations Team
- **Level 2**: Development Team
- **Level 3**: Architecture Team
- **Emergency**: On-call Engineer

### **Escalation Procedures**
1. **Level 1**: Basic troubleshooting, restart services
2. **Level 2**: Configuration changes, code fixes
3. **Level 3**: Architecture changes, major issues
4. **Emergency**: Critical production issues

### **Documentation Updates**
- Update this guide when procedures change
- Document new issues and solutions
- Maintain runbook accuracy
- Regular review and updates

---

*This document serves as the complete operational reference for the Claims Processing System. It should be updated whenever operational procedures change or new issues are discovered.*