# Claims Backend - Operations Manual

## Overview

This manual provides day-to-day operational procedures for managing the Claims Backend Docker deployment, including service management, database operations, monitoring, and troubleshooting.

## Service Management

### Starting the Stack

```bash
# Start all services
docker-compose up -d

# Start with logs visible
docker-compose up

# Start specific service only
docker-compose up -d app
```

### Stopping the Stack

```bash
# Stop all services (preserves data)
docker-compose down

# Stop and remove containers
docker-compose down --remove-orphans

# Stop and remove volumes (WARNING: deletes all data)
docker-compose down -v
```

### Restarting Services

```bash
# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart app

# Restart with rebuild
docker-compose up -d --build app
```

### Service Status

```bash
# Check service status
docker-compose ps

# Check service health
docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# Check resource usage
docker stats
```

## Log Management

### Viewing Logs

```bash
# All services (follow mode)
./docker/scripts/logs.sh

# Specific service
./docker/scripts/logs.sh app
./docker/scripts/logs.sh postgres
./docker/scripts/logs.sh db-init

# Last N lines
docker-compose logs --tail=100 app

# Since timestamp
docker-compose logs --since="2025-01-15T10:00:00" app

# With timestamps
docker-compose logs -t app
```

### Log Filtering

```bash
# Filter by keyword
docker-compose logs app | grep -i error

# Filter by time range
docker-compose logs --since="1h" app

# Multiple filters
docker-compose logs app | grep -E "(ERROR|WARN|ingestion)"
```

### Log Locations

- **Application Logs**: `./logs/application.log` (mounted volume)
- **Container Logs**: `docker-compose logs [service]`
- **PostgreSQL Logs**: `docker-compose logs postgres`

## Database Operations

### Database Access

```bash
# Interactive shell
./docker/scripts/db-shell.sh

# Execute single command
docker exec claims-postgres psql -U claims_user -d claims -c "SELECT version();"

# Execute SQL file
psql -h localhost -p 5432 -U claims_user -d claims -f my-script.sql

# Copy file to container and execute
docker cp my-script.sql claims-postgres:/tmp/
docker exec claims-postgres psql -U claims_user -d claims -f /tmp/my-script.sql
```

### Database Information

```bash
# Database version
docker exec claims-postgres psql -U claims_user -d claims -c "SELECT version();"

# Database size
docker exec claims-postgres psql -U claims_user -d claims -c "SELECT pg_size_pretty(pg_database_size('claims'));"

# Table counts
docker exec claims-postgres psql -U claims_user -d claims -c "SELECT schemaname, tablename, n_tup_ins FROM pg_stat_user_tables ORDER BY n_tup_ins DESC;"

# Connection info
docker exec claims-postgres psql -U claims_user -d claims -c "SELECT * FROM pg_stat_activity WHERE datname = 'claims';"
```

### Making Runtime Database Changes

For small changes during development:

```sql
-- Add column
ALTER TABLE claims.claim ADD COLUMN IF NOT EXISTS new_field TEXT;

-- Create index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_claim_new ON claims.claim(new_field);

-- Update data
UPDATE claims_ref.payer SET status = 'ACTIVE' WHERE payer_code = 'INS123';

-- Refresh materialized view
REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_balance_amount_summary;
```

**Important**: These changes persist in the PostgreSQL volume but are NOT in init scripts. For permanent changes, add SQL to appropriate `docker/db-init/*.sql` file.

### Permanent Changes (For Fresh Deployments)

1. Edit appropriate file in `docker/db-init/`:
   - Schema changes → `02-core-tables.sql`
   - Reference tables → `03-ref-data-tables.sql`
   - Functions → `08-functions-procedures.sql`
   - etc.

2. Use `IF NOT EXISTS` or `CREATE OR REPLACE` for idempotency

3. Test with: `docker-compose down -v && docker-compose up`

## Application Monitoring

### Health Checks

```bash
# Application health
curl http://localhost:8080/actuator/health

# Detailed health info
curl http://localhost:8080/actuator/health | jq

# Database health
curl http://localhost:8080/actuator/health/db
```

### Metrics

```bash
# Application metrics
curl http://localhost:8080/actuator/metrics

# Specific metric
curl http://localhost:8080/actuator/metrics/jvm.memory.used

# Prometheus format
curl http://localhost:8080/actuator/prometheus
```

### Environment Information

```bash
# Application environment
curl http://localhost:8080/actuator/env

# Configuration properties
curl http://localhost:8080/actuator/configprops

# Thread dump
curl http://localhost:8080/actuator/threaddump
```

## Ingestion Monitoring

### Ingestion Status

```sql
-- Check ingestion runs
SELECT * FROM claims.ingestion_run ORDER BY started_at DESC LIMIT 10;

-- Check processed files
SELECT file_id, sender_id, record_count, status, created_at 
FROM claims.ingestion_file 
ORDER BY created_at DESC LIMIT 10;

-- Check errors
SELECT * FROM claims.ingestion_error ORDER BY created_at DESC LIMIT 20;

-- Check claim counts
SELECT COUNT(*) as total_claims FROM claims.claim;
SELECT COUNT(*) as total_remittances FROM claims.remittance_claim;
```

### Ingestion Performance

```sql
-- Processing times
SELECT 
  started_at,
  ended_at,
  files_processed,
  claims_processed,
  EXTRACT(EPOCH FROM (ended_at - started_at)) as duration_seconds
FROM claims.ingestion_run 
ORDER BY started_at DESC LIMIT 10;

-- Batch performance
SELECT 
  batch_number,
  batch_size,
  processing_time_ms,
  ROUND(processing_time_ms::DECIMAL / batch_size, 2) as ms_per_record
FROM claims.ingestion_batch_metric 
ORDER BY created_at DESC LIMIT 20;
```

### Materialized View Status

```sql
-- Check MV row counts
SELECT 
  schemaname,
  matviewname,
  hasindexes,
  ispopulated
FROM pg_matviews 
WHERE schemaname = 'claims'
ORDER BY matviewname;

-- Check MV sizes
SELECT 
  schemaname,
  matviewname,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||matviewname)) as size
FROM pg_matviews 
WHERE schemaname = 'claims'
ORDER BY pg_total_relation_size(schemaname||'.'||matviewname) DESC;
```

## Container Management

### Container Operations

```bash
# List containers
docker ps -a

# Container details
docker inspect claims-app

# Container resource usage
docker stats claims-app

# Execute command in container
docker exec claims-app ls -la /app/

# Access container shell
docker exec -it claims-app bash
```

### Container Logs

```bash
# Container logs
docker logs claims-app

# Follow logs
docker logs -f claims-app

# Logs with timestamps
docker logs -t claims-app

# Last N lines
docker logs --tail=100 claims-app
```

### Container Cleanup

```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune

# Remove unused volumes
docker volume prune

# Full system cleanup
docker system prune -a
```

## Backup and Recovery

### Database Backup

```bash
# Create backup
docker exec claims-postgres pg_dump -U claims_user -d claims > backup_$(date +%Y%m%d_%H%M%S).sql

# Create compressed backup
docker exec claims-postgres pg_dump -U claims_user -d claims | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz

# Backup specific schema
docker exec claims-postgres pg_dump -U claims_user -d claims -n claims > backup_claims_$(date +%Y%m%d).sql
```

### Database Restore

```bash
# Restore from backup
cat backup_20250115.sql | docker exec -i claims-postgres psql -U claims_user -d claims

# Restore from compressed backup
gunzip -c backup_20250115.sql.gz | docker exec -i claims-postgres psql -U claims_user -d claims

# Restore specific schema
cat backup_claims_20250115.sql | docker exec -i claims-postgres psql -U claims_user -d claims
```

### Volume Backup

```bash
# Backup PostgreSQL volume
docker run --rm \
  -v claims-backend-full_postgres-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/postgres-backup-$(date +%Y%m%d).tar.gz -C /data .

# Restore PostgreSQL volume
docker run --rm \
  -v claims-backend-full_postgres-data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/postgres-backup-20250115.tar.gz -C /data
```

## Performance Tuning

### Application Tuning

```bash
# Increase memory (in .env)
JAVA_OPTS=-Xms1g -Xmx4g -XX:+UseG1GC

# Increase database connections (in application-docker.yml)
spring.datasource.hikari.maximum-pool-size: 30
```

### Database Tuning

```sql
-- Check database configuration
SHOW shared_buffers;
SHOW effective_cache_size;
SHOW work_mem;
SHOW maintenance_work_mem;

-- Check slow queries
SELECT query, mean_time, calls 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;
```

### Materialized View Refresh

```sql
-- Refresh all MVs
SELECT claims.refresh_all_materialized_views();

-- Refresh specific MV
REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_balance_amount_summary;

-- Check refresh status
SELECT 
  schemaname,
  matviewname,
  last_refresh
FROM pg_stat_user_tables 
WHERE schemaname = 'claims' 
AND relname LIKE 'mv_%';
```

## Troubleshooting

### Common Issues

**Application won't start**:
```bash
# Check logs
./docker/scripts/logs.sh app

# Check database connection
docker exec claims-app nc -zv postgres 5432

# Check environment variables
docker exec claims-app env | grep -E "(DB_|SPRING_)"
```

**Database connection failed**:
```bash
# Check postgres status
docker-compose ps postgres

# Check postgres logs
./docker/scripts/logs.sh postgres

# Test connection
docker exec claims-postgres pg_isready -U claims_user
```

**AME encryption errors**:
```bash
# Check keystore exists
ls -la config/claims.p12

# Check keystore permissions
docker exec claims-app ls -la /app/config/claims.p12

# Regenerate keystore
./docker/scripts/generate-ame-keystore.sh
```

**Ingestion not working**:
```bash
# Check SOAP configuration
curl http://localhost:8080/actuator/env | jq '.propertySources[].properties | to_entries[] | select(.key | contains("soap"))'

# Check facility configuration
./docker/scripts/db-shell.sh
# Then: SELECT * FROM claims.facility_dhpo_config;
```

### Debug Mode

```bash
# Enable debug logging (in .env)
LOG_LEVEL=DEBUG

# Restart application
docker-compose restart app

# Watch debug logs
./docker/scripts/logs.sh app | grep -i debug
```

### Network Issues

```bash
# Check network connectivity
docker exec claims-app ping postgres

# Check port availability
netstat -tulpn | grep -E "(8080|5432)"

# Check DNS resolution
docker exec claims-app nslookup postgres
```

## Maintenance Tasks

### Daily Tasks

```bash
# Check service health
curl http://localhost:8080/actuator/health

# Check disk space
df -h
docker system df

# Check logs for errors
./docker/scripts/logs.sh app | grep -i error | tail -20
```

### Weekly Tasks

```bash
# Refresh materialized views
./docker/scripts/db-shell.sh
# Then: SELECT claims.refresh_all_materialized_views();

# Clean up old logs
find ./logs -name "*.log" -mtime +7 -delete

# Check database size
docker exec claims-postgres psql -U claims_user -d claims -c "SELECT pg_size_pretty(pg_database_size('claims'));"
```

### Monthly Tasks

```bash
# Create full backup
docker exec claims-postgres pg_dump -U claims_user -d claims | gzip > backup_monthly_$(date +%Y%m).sql.gz

# Update Docker images
docker-compose pull
docker-compose up -d --build

# Review and rotate logs
logrotate /etc/logrotate.d/claims-backend
```

## Security Operations

### Password Rotation

```bash
# Update database password
# 1. Update .env file
# 2. Restart services
docker-compose restart

# Update AME keystore password
# 1. Generate new keystore
./docker/scripts/generate-ame-keystore.sh
# 2. Update .env file
# 3. Restart application
docker-compose restart app
```

### Access Control

```bash
# Check user access
./docker/scripts/db-shell.sh
# Then: SELECT * FROM claims.users WHERE enabled = true;

# Check role assignments
# Then: SELECT u.username, ur.role FROM claims.users u JOIN claims.user_roles ur ON u.id = ur.user_id;
```

### Audit Logs

```sql
-- Check security audit logs
SELECT * FROM claims.security_audit_log 
ORDER BY timestamp DESC 
LIMIT 50;

-- Check failed login attempts
SELECT * FROM claims.security_audit_log 
WHERE action = 'LOGIN' AND success = false
ORDER BY timestamp DESC;
```

## Emergency Procedures

### Service Recovery

```bash
# Restart all services
docker-compose restart

# Restart with fresh build
docker-compose down
docker-compose up -d --build

# Nuclear option - fresh start (loses data)
docker-compose down -v
docker-compose up -d
```

### Data Recovery

```bash
# Restore from backup
cat backup_20250115.sql | docker exec -i claims-postgres psql -U claims_user -d claims

# Point-in-time recovery (if configured)
# Contact DBA for assistance
```

### Rollback Procedure

```bash
# Stop current deployment
docker-compose down

# Restore previous version
git checkout previous-tag
docker-compose up -d --build

# Restore database if needed
cat backup_before_update.sql | docker exec -i claims-postgres psql -U claims_user -d claims
```

## Monitoring and Alerting

### Key Metrics to Monitor

- **Application Health**: HTTP 200 on `/actuator/health`
- **Database Connections**: Active connection count
- **Ingestion Rate**: Files processed per hour
- **Error Rate**: Error count in logs
- **Response Time**: API response times
- **Disk Space**: Available disk space
- **Memory Usage**: JVM heap usage

### Alert Thresholds

- **Health Check**: Down for > 5 minutes
- **Error Rate**: > 10 errors per minute
- **Response Time**: > 5 seconds average
- **Disk Space**: < 10% free
- **Memory Usage**: > 80% heap usage

### Log Monitoring

```bash
# Monitor for errors
tail -f ./logs/application.log | grep -i error

# Monitor ingestion
tail -f ./logs/application.log | grep -i ingestion

# Monitor performance
tail -f ./logs/application.log | grep -E "(slow|timeout|performance)"
```

## Support and Escalation

### First Level Support

1. **Check Service Status**: `docker-compose ps`
2. **Check Application Health**: `curl http://localhost:8080/actuator/health`
3. **Check Recent Logs**: `./docker/scripts/logs.sh app | tail -50`
4. **Check Database**: `./docker/scripts/db-shell.sh`

### Escalation Criteria

- **Service Down**: Application or database unavailable
- **Data Loss**: Missing or corrupted data
- **Security Incident**: Unauthorized access or data breach
- **Performance Degradation**: Response times > 10 seconds
- **High Error Rate**: > 50 errors per minute

### Contact Information

- **System Administrator**: [Contact Info]
- **Database Administrator**: [Contact Info]
- **Application Support**: [Contact Info]
- **Emergency Contact**: [Contact Info]
