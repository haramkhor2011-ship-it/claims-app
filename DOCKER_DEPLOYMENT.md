# Docker Deployment Guide - Claims Backend

This guide provides instructions for deploying the Claims Backend application using Docker Compose.

## Prerequisites

- Docker Desktop (Windows/Mac) or Docker Engine + Docker Compose (Linux)
- At least 4GB RAM available for Docker
- Ports 8080, 5432, and 6379 available (or modify docker-compose.yml)

## Quick Start

1. **Set Environment Variables** (optional - defaults are provided)

   Create a `.env` file in the project root with the following variables:

   ```bash
   # PostgreSQL Configuration
   POSTGRES_DB=claims
   POSTGRES_USER=claims_user
   POSTGRES_PASSWORD=securepass  # CHANGE IN PRODUCTION!

   # Application Database Credentials (can be same as POSTGRES_*)
   DB_USER=claims_user
   DB_PASSWORD=securepass

   # JWT Secret (REQUIRED IN PRODUCTION!)
   JWT_SECRET=change-this-in-production-use-strong-random-string

   # DHPO SOAP Endpoint
   DHPO_SOAP_ENDPOINT=https://qa.eclaimlink.ae/dhpo/ValidateTransactions.asmx

   # SOAP Poll Interval (milliseconds) - default 30 minutes
   SOAP_POLL_INTERVAL_MS=1800000

   # AME Keystore Password (if using AME security)
   CLAIMS_AME_STORE_PASS=your-keystore-password

   # Logging Level
   LOG_LEVEL=INFO

   # JVM Options (optional)
   JAVA_OPTS=-Xms512m -Xmx2048m -XX:+UseG1GC --enable-preview
   ```

2. **Build and Start Services**

   ```bash
   docker-compose up -d
   ```

   This will:
   - Build the application Docker image
   - Start PostgreSQL database
   - Start Redis cache
   - Initialize the database schema
   - Start the Claims Backend application

3. **Check Status**

   ```bash
   docker-compose ps
   ```

4. **View Logs**

   ```bash
   # All services
   docker-compose logs -f

   # Specific service
   docker-compose logs -f app
   docker-compose logs -f postgres
   docker-compose logs -f db-init
   ```

5. **Verify Application Health**

   ```bash
   curl http://localhost:8080/actuator/health
   ```

## Service Details

### Services Overview

| Service | Container Name | Port | Description |
|---------|---------------|------|-------------|
| postgres | claims-postgres | 5432 | PostgreSQL 16 database |
| redis | claims-redis | 6379 | Redis 7 cache |
| db-init | claims-db-init | - | Database initialization (runs once) |
| app | claims-app | 8080 | Claims Backend application |

### Application Service

- **Build**: Multi-stage Docker build with Maven
- **Base Image**: Eclipse Temurin 21 JRE (Alpine)
- **Profiles**: docker, ingestion, prod, soap
- **Health Check**: `/actuator/health` endpoint
- **Volumes**:
  - `./data/ready` → `/app/data/ready` (ingestion files)
  - `./config` → `/app/config` (configuration files)
  - `./logs` → `/app/logs` (application logs)

### Database Initialization

The `db-init` service runs once to:
1. Wait for PostgreSQL to be ready
2. Check if database is already initialized (idempotent)
3. Execute SQL scripts in order:
   - `01-init-db.sql` - Database and schema creation
   - `02-core-tables.sql` - Core tables
   - `03-ref-data-tables.sql` - Reference data tables
   - `04-dhpo-config.sql` - DHPO configuration
   - `05-user-management.sql` - User management
   - `06-report-views.sql` - Report views
   - `07-materialized-views.sql` - Materialized views
   - `08-functions-procedures.sql` - Functions and procedures
4. Skip files with `.skip` extension

## Common Operations

### Stop Services

```bash
docker-compose stop
```

### Start Services

```bash
docker-compose start
```

### Restart a Service

```bash
docker-compose restart app
```

### Rebuild and Restart

```bash
docker-compose up -d --build
```

### View Application Logs

```bash
# Follow logs
docker-compose logs -f app

# Last 100 lines
docker-compose logs --tail=100 app

# Logs with timestamps
docker-compose logs -f --timestamps app
```

### Execute Commands in Container

```bash
# Access application container shell
docker exec -it claims-app sh

# Access database
docker exec -it claims-postgres psql -U claims_user -d claims

# Run Maven commands in builder container
docker run --rm -v ${PWD}:/app -w /app eclipse-temurin:21-jdk-alpine mvn clean package
```

### Clean Up

```bash
# Stop and remove containers
docker-compose down

# Remove volumes (WARNING: deletes database data!)
docker-compose down -v

# Remove images
docker-compose down --rmi all

# Full cleanup (containers, volumes, images)
docker-compose down -v --rmi all
```

## Troubleshooting

### Application Won't Start

1. **Check logs**:
   ```bash
   docker-compose logs app
   ```

2. **Verify database is ready**:
   ```bash
   docker-compose logs db-init
   ```

3. **Check health status**:
   ```bash
   curl http://localhost:8080/actuator/health
   ```

### Database Connection Issues

1. **Verify PostgreSQL is running**:
   ```bash
   docker-compose ps postgres
   ```

2. **Check database logs**:
   ```bash
   docker-compose logs postgres
   ```

3. **Test connection**:
   ```bash
   docker exec -it claims-postgres psql -U claims_user -d claims -c "SELECT 1;"
   ```

### Port Already in Use

If ports 8080, 5432, or 6379 are already in use:

1. Stop conflicting services
2. Or modify ports in `docker-compose.yml`:
   ```yaml
   ports:
     - "8081:8080"  # Change external port
   ```

### Database Initialization Failed

1. **Check db-init logs**:
   ```bash
   docker-compose logs db-init
   ```

2. **Re-run initialization**:
   ```bash
   # Remove the initialization marker (if needed)
   docker exec -it claims-postgres psql -U claims_user -d claims -c "DELETE FROM claims.integration_toggle WHERE code='db.initialized';"
   
   # Restart db-init service
   docker-compose restart db-init
   ```

### JAR Not Found During Build

The Dockerfile expects the JAR to be named `claims-backend.jar`. This is set in `pom.xml`:
```xml
<finalName>${project.artifactId}</finalName>
```

Spring Boot Maven plugin repackages it as `${finalName}.jar`. Verify the build:
```bash
mvn clean package
ls -la target/claims-backend.jar
```

## Production Deployment Considerations

### Security

1. **Change all default passwords**:
   - `POSTGRES_PASSWORD`
   - `DB_PASSWORD`
   - `JWT_SECRET` (use strong random string, min 32 characters)

2. **Use secrets management**:
   - Consider Docker secrets
   - Use environment variable injection from secure vaults
   - Never commit `.env` files with real credentials

3. **Network security**:
   - Do not expose database/redis ports publicly
   - Use firewall rules
   - Consider using Docker networks without port mapping

4. **Image security**:
   - Regularly update base images
   - Scan images for vulnerabilities
   - Use non-root user (already implemented)

### Performance

1. **JVM Options**:
   - Adjust `JAVA_OPTS` based on container resources
   - Monitor memory usage: `docker stats claims-app`

2. **Database**:
   - Consider persistent volumes for production
   - Configure PostgreSQL for production workloads
   - Set up regular backups

3. **Redis**:
   - Configure persistence if needed
   - Set appropriate memory limits

### Monitoring

1. **Health Checks**:
   - Use `/actuator/health` for container orchestration
   - Monitor application metrics at `/actuator/metrics`

2. **Logging**:
   - Logs are available in `./logs` directory
   - Consider centralized logging (ELK, Splunk, etc.)
   - Rotate logs to prevent disk fill

3. **Metrics**:
   - Prometheus metrics available at `/actuator/prometheus`
   - Set up monitoring dashboards

## Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Spring Boot Docker Guide](https://spring.io/guides/gs/spring-boot-docker/)
- Application documentation in `/docs` directory

