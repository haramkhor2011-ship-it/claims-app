# Claims Backend - Docker Deployment Guide

## Overview

This guide provides instructions for deploying the Claims Backend application using Docker and Docker Compose. The deployment includes PostgreSQL database, database initialization, and the Spring Boot application with SOAP ingestion capabilities.

## Prerequisites

- **Docker**: 20.10+ installed and running
- **Docker Compose**: 2.0+ installed
- **System Resources**: Minimum 4GB RAM, 20GB disk space
- **Network**: Ports 8080 and 5432 available
- **Java Keytool**: For AME keystore generation (included in JDK)

## Quick Start

### 1. Generate AME Keystore

```bash
# Generate PKCS12 keystore for DHPO credential encryption
./docker/scripts/generate-ame-keystore.sh
```

### 2. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit configuration
nano .env  # or your preferred editor
```

### 3. Deploy Application

```bash
# Deploy all services
./docker/scripts/deploy.sh
```

### 4. Verify Deployment

```bash
# Check service status
docker-compose ps

# Test application health
curl http://localhost:8080/actuator/health

# View application logs
./docker/scripts/logs.sh app
```

## Architecture

The deployment consists of three main services:

### Services

- **postgres**: PostgreSQL 16 database with persistent volume
- **db-init**: One-time database initialization container
- **app**: Spring Boot application with ingestion and API capabilities

### Network

- **claims-network**: Custom bridge network for service communication
- **Port 8080**: Application HTTP API endpoint
- **Port 5432**: PostgreSQL direct access (for database operations)

### Volumes

- **postgres-data**: PostgreSQL data persistence (survives container restarts)
- **./config**: AME keystore and configuration files (mounted from host)
- **./data/ready**: XML files for ingestion (mounted from host)
- **./logs**: Application logs (mounted from host)

## Configuration

### Environment Variables

Key environment variables in `.env`:

```bash
# Database
POSTGRES_DB=claims
POSTGRES_USER=claims_user
POSTGRES_PASSWORD=securepass_CHANGEME

# Application
SPRING_PROFILES_ACTIVE=docker,ingestion,prod,soap
DHPO_SOAP_ENDPOINT=https://qa.eclaimlink.ae/dhpo/ValidateTransactions.asmx

# AME Encryption
CLAIMS_AME_STORE_PASS=YourSecureKeystorePassword_CHANGEME

# JWT Security
JWT_SECRET=change-this-in-production-to-a-long-random-string
```

### Application Profiles

- **docker**: Docker-specific configuration
- **ingestion**: Ingestion orchestrator and file processing
- **prod**: Production optimizations and monitoring
- **soap**: SOAP fetcher for DHPO integration

## Database Initialization

### First Deployment

On first run, the `db-init` container:

1. **Creates Schemas**: `claims`, `claims_ref`, `auth`
2. **Installs Extensions**: `pg_trgm`, `citext`, `pgcrypto`
3. **Creates Tables**: All core claims processing tables
4. **Creates Reference Tables**: Facilities, payers, providers, etc.
5. **Creates Materialized Views**: Pre-computed report views for performance
6. **Creates User Management**: Authentication and authorization tables
7. **Initializes DHPO Config**: Integration toggles and facility configuration
8. **Marks as Initialized**: Prevents re-initialization on restart

### Subsequent Deployments

- Database initialization is **skipped** (idempotent design)
- Existing data is **preserved** in the PostgreSQL volume
- Only application container is restarted

## AME Encryption

### Purpose

AME (Application-Managed Encryption) secures DHPO facility credentials:

- **Encrypts**: DHPO usernames and passwords in database
- **Uses**: AES-256-GCM encryption with PKCS12 keystore
- **Stores**: Encrypted credentials in `claims.facility_dhpo_config`

### Setup

1. **Generate Keystore**: `./docker/scripts/generate-ame-keystore.sh`
2. **Configure Password**: Add `CLAIMS_AME_STORE_PASS` to `.env`
3. **Add Facilities**: Use Admin API to configure DHPO facilities
4. **Credentials Encrypted**: Automatically encrypted when added

## Operations

### Starting Services

```bash
# Start all services
docker-compose up -d

# Start specific service
docker-compose up -d app
```

### Stopping Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (WARNING: deletes data)
docker-compose down -v
```

### Viewing Logs

```bash
# All services
./docker/scripts/logs.sh

# Specific service
./docker/scripts/logs.sh app
./docker/scripts/logs.sh postgres
```

### Database Access

```bash
# Interactive shell
./docker/scripts/db-shell.sh

# Execute SQL file
psql -h localhost -p 5432 -U claims_user -d claims -f my-script.sql
```

### Application Health

```bash
# Health check
curl http://localhost:8080/actuator/health

# Metrics
curl http://localhost:8080/actuator/metrics

# Environment info
curl http://localhost:8080/actuator/env
```

## Testing

### E2E Ingestion Test

1. **Add XML File**:
   ```bash
   cp src/main/resources/xml/submission_min_ok.xml data/ready/
   ```

2. **Watch Processing**:
   ```bash
   ./docker/scripts/logs.sh app | grep -i ingestion
   ```

3. **Verify Results**:
   ```bash
   ./docker/scripts/db-shell.sh
   # Then: SELECT * FROM claims.ingestion_file ORDER BY created_at DESC LIMIT 5;
   ```

### Report Testing

```bash
# Test materialized views
./docker/scripts/db-shell.sh
# Then: SELECT COUNT(*) FROM claims.mv_balance_amount_summary;
```

## Troubleshooting

### Common Issues

**Application won't start**:
- Check logs: `./docker/scripts/logs.sh app`
- Verify database connection
- Check AME keystore exists

**Database connection failed**:
- Wait for postgres to be ready: `docker-compose logs postgres`
- Check credentials in `.env`
- Verify port 5432 is available

**AME encryption errors**:
- Generate keystore: `./docker/scripts/generate-ame-keystore.sh`
- Check keystore password in `.env`
- Verify keystore file permissions

**Ingestion not working**:
- Check SOAP endpoint configuration
- Verify facility credentials in database
- Check network connectivity to DHPO

### Log Locations

- **Application**: `./logs/application.log` (mounted volume)
- **PostgreSQL**: `docker-compose logs postgres`
- **Database Init**: `docker-compose logs db-init`

### Performance Tuning

**Memory Settings**:
```bash
# In .env
JAVA_OPTS=-Xms1g -Xmx4g -XX:+UseG1GC
```

**Database Connections**:
```bash
# In application-docker.yml
spring.datasource.hikari.maximum-pool-size: 30
```

## Security Considerations

### Production Deployment

1. **Change Default Passwords**: Update all passwords in `.env`
2. **Use Strong Secrets**: Generate secure JWT secrets and keystore passwords
3. **Network Security**: Configure firewall rules
4. **HTTPS**: Use HTTPS endpoints for DHPO integration
5. **Secrets Management**: Consider Docker secrets or external secret management
6. **Regular Updates**: Keep Docker images and base images updated

### AME Keystore Security

- **File Permissions**: Keystore has 600 permissions (owner read/write only)
- **Password Storage**: Keystore password in environment variable, not source code
- **Key Rotation**: Change `keyId` in config to rotate encryption keys
- **Backup**: Securely backup keystore file

## Monitoring

### Health Checks

- **Application**: `http://localhost:8080/actuator/health`
- **Database**: Built-in PostgreSQL health check
- **Container Health**: `docker-compose ps`

### Metrics

- **Application Metrics**: `http://localhost:8080/actuator/metrics`
- **Prometheus**: `http://localhost:8080/actuator/prometheus`
- **Database Stats**: Use `claims.get_database_stats()` function

### Logging

- **Structured Logs**: JSON format with correlation IDs
- **Log Levels**: Configurable via `LOG_LEVEL` environment variable
- **Log Rotation**: Configured in application-docker.yml

## Backup and Recovery

### Database Backup

```bash
# Create backup
docker exec claims-postgres pg_dump -U claims_user -d claims > backup_$(date +%Y%m%d).sql

# Restore backup
cat backup_20250115.sql | docker exec -i claims-postgres psql -U claims_user -d claims
```

### Volume Backup

```bash
# Backup PostgreSQL volume
docker run --rm -v claims-backend-full_postgres-data:/data -v $(pwd):/backup alpine tar czf /backup/postgres-backup.tar.gz -C /data .
```

## Scaling Considerations

### Resource Limits

For production, consider adding resource limits to `docker-compose.yml`:

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
```

### Multi-Facility Performance

When running ingestion for multiple facilities:

- **Connection Pooling**: Tune HikariCP pool sizes
- **Concurrent Processing**: Adjust `downloadConcurrency` setting
- **Database Locks**: Monitor lock contention during bulk operations
- **Materialized Views**: Use `REFRESH MATERIALIZED VIEW CONCURRENTLY`

## Support

### Documentation

- **Operations Manual**: `docker/OPERATIONS.md`
- **Testing Guide**: `docker/TESTING.md`
- **Application Docs**: `src/main/resources/docs/`

### Getting Help

1. **Check Logs**: Always start with application and database logs
2. **Verify Configuration**: Ensure all environment variables are set correctly
3. **Test Connectivity**: Verify network connectivity and port availability
4. **Review Documentation**: Check this guide and application documentation

## See Also

- [Operations Manual](OPERATIONS.md) - Day-to-day operations
- [Testing Guide](TESTING.md) - Testing procedures and validation
- [Application Documentation](../src/main/resources/docs/) - Application-specific documentation
