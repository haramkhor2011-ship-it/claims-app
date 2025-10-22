<!-- 22c77250-49bd-4901-9021-e7220ca81bc3 101312f1-de88-4c80-abaa-434ab1dcec2f -->
# Docker Deployment Setup Plan - UPDATED

## Overview

Set up Docker deployment with PostgreSQL and Spring Boot application. The setup uses persistent volumes for PostgreSQL to preserve data, views, materialized views, and functions across redeployments. Database initialization scripts run only once (idempotent design). Application runs with `docker,ingestion,prod,soap` profiles.

## Architecture

- **PostgreSQL Container**: With persistent volume for database data (preserves data, MVs, functions across redeployments)
- **Init Container**: Runs DDL scripts only on first deployment (idempotent with `IF NOT EXISTS`)
- **Application Container**: Spring Boot app with profiles `docker,ingestion,prod,soap`
- **Port 8080**: Application HTTP endpoint
- **Port 5432**: PostgreSQL direct access (for runtime queries and manual DB changes)
- **Data Persistence**: PostgreSQL data persisted via Docker volume
- **AME Encryption**: PKCS12 keystore volume mounted for DHPO credential encryption

## Key Components to Create

### 1. Dockerfile (Multi-stage Build)

Create `Dockerfile` using multi-stage build for optimized image size:

- **Stage 1 (builder)**: Maven build with Java 21, copy pom.xml and src/, run `mvn clean package -DskipTests`
- **Stage 2 (runtime)**: Eclipse Temurin JRE 21-alpine base
- **Working directory**: `/app`
- **Directory structure**: Create `data/ready`, `data/archive/done`, `data/archive/error`, `config/`, `logs/`
- **Copy artifacts**: JAR file, reference data CSVs from `src/main/resources/refdata/`
- **User**: Run as non-root user `claims` for security
- **Entrypoint**: `java -jar claims-backend.jar`

### 2. Docker Compose Configuration

Create `docker-compose.yml` with 3 services:

#### Service: postgres

- Image: `postgres:16-alpine`
- **Volume**: `postgres-data:/var/lib/postgresql/data` (PERSISTENT - preserves data across redeployments)
- Environment: `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` from .env
- **Ports**: `5432:5432` exposed for direct access from host
- Healthcheck: `pg_isready -U claims_user`
- Networks: `claims-network`

#### Service: db-init

- Build: `./docker/db-init`
- Depends on: `postgres` (healthcheck)
- Environment: Same DB credentials
- **Run once logic**: Check if schema exists, skip if already initialized
- Networks: `claims-network`
- **Idempotent**: All DDL uses `IF NOT EXISTS`, safe to re-run

#### Service: app

- Build: `.` (main Dockerfile)
- Depends on: `db-init` (completion marker)
- **Volumes**:
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - `./data/ready:/app/data/ready` - For adding XML files from host
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - `./config:/app/config` - For AME keystore and configuration files
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - `./logs:/app/logs` - For application logs
- **Ports**: `8080:8080`
- Environment: From .env file
- Networks: `claims-network`
- Restart: `unless-stopped`

#### Network

- Custom bridge network: `claims-network`

### 3. Database Initialization Scripts - AUDITED

Create `docker/db-init/` directory. **Analysis shows these are the ONLY required SQL files without duplication**:

#### `01-init-db.sql` - Database, Schemas, Extensions, Roles

Extract from `claims_unified_ddl_fresh.sql`:

- CREATE EXTENSION IF NOT EXISTS: `pg_trgm`, `citext`, `pgcrypto`
- CREATE SCHEMA IF NOT EXISTS: `claims`, `claims_ref`, `auth`
- CREATE ROLE IF NOT EXISTS: `claims_user` (with LOGIN)
- GRANT usage on schemas to `claims_user`

#### `02-core-tables.sql` - Main Claims Tables

From `src/main/resources/db/claims_unified_ddl_fresh.sql`:

- All claims schema tables: `ingestion_file`, `submission`, `claim`, `claim_key`, `encounter`, `diagnosis`, `activity`, `observation`, `remittance`, `remittance_claim`, `remittance_activity`, `claim_event`, `claim_event_activity`, `event_observation`, `claim_status_timeline`, `claim_attachment`, `claim_resubmission`, `claim_contract`
- Audit tables: `ingestion_run`, `ingestion_file_audit`, `ingestion_error`, `ingestion_batch_metric`
- Verification tables: `verification_rule`, `verification_run`, `verification_result`
- **NOTE**: This DDL already includes schemas/extensions at top, but init-db.sql runs first so safe

#### `03-ref-data-tables.sql` - Reference Data Schema

From `src/main/resources/db/claims_ref_ddl.sql`:

- Creates `claims_ref` schema (already in 01 but has IF NOT EXISTS)
- Reference tables: `facility`, `payer`, `provider`, `clinician`, `activity_code`, `diagnosis_code`, `denial_code`, `contract_package`
- **VERIFIED**: No duplication with 02-core-tables.sql

#### `04-dhpo-config.sql` - DHPO Integration Tables

From `src/main/resources/db/dhpo_config.sql`:

- Table: `claims.facility_dhpo_config` (encrypted credentials storage)
- Table: `claims.integration_toggle` (feature flags)
- Insert default toggles: `dhpo.search.enabled(true)`, `dhpo.setDownloaded.enabled(false), dhpo.new.enabled(true)`
- Grants to `claims_user`
- **AME READY**: Includes encrypted column definitions (`dhpo_username_enc`, `dhpo_password_enc`, `enc_meta_json`)

#### `05-user-management.sql` - Security Schema

From `src/main/resources/db/user_management_schema.sql`:

- Tables: `users`, `user_roles`, `user_facilities`, `user_report_permissions` 
- Security tables: `security_audit_log`, `refresh_tokens`
- SSO skeleton tables: `sso_providers`, `sso_user_mappings`
- Indexes for performance
- Grants to `claims_user`

#### `06-materialized-views.sql` - Pre-computed Report Views

From `src/main/resources/db/reports_sql/sub_second_materialized_views.sql`:

- All materialized views: `mv_balance_amount_summary`, `mv_remittance_advice_summary`, `mv_remittances_resubmission_summary`, `mv_doctor_denial_summary`, `mv_claim_details_with_activity`, `mv_claim_summary_monthwise`, `mv_rejected_claims_summary`, `mv_claim_summary_payerwise`, `mv_claim_summary_encounterwise`
- Unique indexes for each MV
- **PERFORMANCE CRITICAL**: These provide sub-second report performance

#### `07-report-views.sql` - Report SQL Views

Extract CREATE VIEW statements from:

- `balance_amount_report_implementation_final.sql`
- `claim_details_with_activity_final.sql`
- `claim_summary_monthwise_report_final.sql`
- `doctor_denial_report_final.sql`
- `rejected_claims_report_final.sql`
- `remittance_advice_payerwise_report_final.sql`
- `remittances_resubmission_report_final.sql`
- **NOTE**: Check if these are actually VIEWs or just query templates

#### `08-functions-procedures.sql` - Database Functions

Search `claims_unified_ddl_fresh.sql` for:

- CREATE OR REPLACE FUNCTION statements
- CREATE OR REPLACE PROCEDURE statements
- Triggers if any
- **TODO**: Verify if any PL/pgSQL functions exist in codebase

#### `99-verify-init.sql` - Initialization Verification

Quick checks:

- Count tables in each schema
- Check materialized views exist
- Check reference tables created
- Insert marker: `INSERT INTO claims.integration_toggle VALUES ('db.initialized', true, now()) ON CONFLICT DO NOTHING;`

#### `init.sh` - Initialization Script

Bash script that:

```bash
#!/bin/bash
set -e

# Wait for postgres
until pg_isready -h postgres -U claims_user; do
  echo "Waiting for postgres..."
  sleep 2
done

# Check if already initialized
if psql -h postgres -U claims_user -d claims -tAc "SELECT EXISTS(SELECT 1 FROM claims.integration_toggle WHERE code='db.initialized');" | grep -q 't'; then
  echo "Database already initialized, skipping..."
  exit 0
fi

echo "Initializing database..."
for sql in /docker-entrypoint-initdb.d/*.sql; do
  echo "Running $sql..."
  psql -h postgres -U claims_user -d claims -f "$sql"
done

echo "Database initialization complete!"
```

### 4. Application Configuration - application-docker.yml

Create `src/main/resources/application-docker.yml`:

```yaml
spring:
  profiles:
    include: ingestion,prod,soap
  datasource:
    url: jdbc:postgresql://postgres:5432/claims
    username: ${DB_USER:claims_user}
    password: ${DB_PASSWORD:securepass}
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      auto-commit: false
      connection-timeout: 30000
      leak-detection-threshold: 60000
  jpa:
    open-in-view: false
    hibernate:
      ddl-auto: none
  flyway:
    enabled: false  # We use init container instead

logging:
  level:
    com.acme.claims: INFO
    org.springframework.scheduling: INFO
  file:
    name: /app/logs/application.log
  pattern:
    console: "%d{ISO8601} %-5level [%thread] %logger{36} - %msg%n"

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus,loggers,env,threaddump

claims:
  ingestion:
    mode: soap  # SOAP fetcher active
    localfs:
      readyDir: /app/data/ready
      archiveOkDir: /app/data/archive/done
      archiveFailDir: /app/data/archive/error
    poll:
      fixedDelayMs: 10000  # 10 seconds
    queue:
      capacity: 512
    concurrency:
      parserWorkers: 8
    ack:
      enabled: true
  
  refdata:
    bootstrap:
      enabled: true
      strict: false
      location: classpath:refdata/
      batch-size: 500
    auto-insert: true
  
  soap:
    endpoint: ${DHPO_SOAP_ENDPOINT:https://qa.eclaimlink.ae/dhpo/ValidateTransactions.asmx}
    soap12: false
    connectTimeoutMs: 15000
    readTimeoutMs: 120000
    poll:
      fixedDelayMs: ${SOAP_POLL_INTERVAL_MS:1800000}  # 30 minutes default
    downloadConcurrency: 16
  
  security:
    ame:
      enabled: true
      keystore:
        type: PKCS12
        path: file:/app/config/claims.p12
        alias: claims-ame
        passwordEnv: CLAIMS_AME_STORE_PASS
      crypto:
        kekRotationAllowed: true
        gcmTagBits: 128
        keyId: claims-ame.v1

dhpo:
  client:
    getNewEnabled: false
    searchDaysBack: 100
    retriesOnMinus4: 3
    connectTimeoutMs: 6000
    readTimeoutMs: 15000
    downloadTimeoutMs: 120000
    stageToDiskThresholdMb: 25
```

### 5. Environment Variables

Create `.env.example`:

```bash
# Database Configuration
POSTGRES_DB=claims
POSTGRES_USER=claims_user
POSTGRES_PASSWORD=securepass_CHANGEME

DB_USER=claims_user
DB_PASSWORD=securepass_CHANGEME

# Application Profiles
SPRING_PROFILES_ACTIVE=docker,ingestion,prod,soap

# SOAP/DHPO Configuration
DHPO_SOAP_ENDPOINT=https://qa.eclaimlink.ae/dhpo/ValidateTransactions.asmx
SOAP_POLL_INTERVAL_MS=1800000

# AME Encryption
CLAIMS_AME_STORE_PASS=YourSecureKeystorePassword_CHANGEME

# Logging
LOG_LEVEL=INFO

# Optional: JWT for API security (if enabled)
JWT_SECRET=change-this-in-production-to-a-long-random-string

# Java Options
JAVA_OPTS=-Xms512m -Xmx2048m -XX:+UseG1GC
```

Create `.env` (gitignored) with actual values for local development.

### 6. Docker Ignore File

Create `.dockerignore`:

```
# Build artifacts
target/
*.jar
*.war

# Git
.git/
.gitignore

# IDEs
.idea/
.vscode/
*.iml
.project
.classpath
.settings/

# Documentation
*.md
docs/
*.txt
*.pdf

# Logs
logs/
*.log

# Data (except refdata)
data/archive/
data/ready/*.xml

# Tests
src/test/

# OS files
.DS_Store
Thumbs.db

# SQL scripts (included in db-init separately)
*.sql

# Temporary files
temp/
tmp/
```

### 7. Init Container Dockerfile

Create `docker/db-init/Dockerfile`:

```dockerfile
FROM postgres:16-alpine

# Copy initialization scripts
COPY *.sql /docker-entrypoint-initdb.d/
COPY init.sh /docker-entrypoint-initdb.d/

# Make init script executable
RUN chmod +x /docker-entrypoint-initdb.d/init.sh

# Set working directory
WORKDIR /docker-entrypoint-initdb.d

# Healthcheck
HEALTHCHECK --interval=5s --timeout=3s --retries=3 \
  CMD pg_isready -h postgres -U claims_user || exit 1
```

### 8. AME Encryption Setup

#### `docker/scripts/generate-ame-keystore.sh`

Script to generate AME PKCS12 keystore:

```bash
#!/bin/bash
set -e

KEYSTORE_DIR="./config"
KEYSTORE_FILE="$KEYSTORE_DIR/claims.p12"
ALIAS="claims-ame"
PASSWORD="${CLAIMS_AME_STORE_PASS:-DefaultPassword123}"

mkdir -p "$KEYSTORE_DIR"

if [ -f "$KEYSTORE_FILE" ]; then
  echo "Keystore already exists at $KEYSTORE_FILE"
  read -p "Regenerate? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
  fi
  rm "$KEYSTORE_FILE"
fi

echo "Generating PKCS12 keystore for AME encryption..."
keytool -genseckey \
  -alias "$ALIAS" \
  -keyalg AES \
  -keysize 256 \
  -storetype PKCS12 \
  -keystore "$KEYSTORE_FILE" \
  -storepass "$PASSWORD"

chmod 600 "$KEYSTORE_FILE"

echo "Keystore generated successfully at $KEYSTORE_FILE"
echo "Add to .env: CLAIMS_AME_STORE_PASS=$PASSWORD"
```

### 9. Documentation Files

#### `docker/README.md` - Deployment Guide

```markdown
# Claims Backend - Docker Deployment Guide

## Prerequisites
- Docker 20.10+
- Docker Compose 2.0+
- Minimum 4GB RAM, 20GB disk space
- Ports 8080 and 5432 available

## Quick Start
1. Generate AME keystore: `./docker/scripts/generate-ame-keystore.sh`
2. Copy environment template: `cp .env.example .env`
3. Edit `.env` with your configuration
4. Start services: `docker-compose up -d`
5. Check logs: `docker-compose logs -f app`
6. Verify health: `curl http://localhost:8080/actuator/health`

## Architecture
- **postgres**: PostgreSQL 16 with persistent volume
- **db-init**: One-time database initialization
- **app**: Spring Boot application (ingestion + API)

## Ports
- 8080: Application HTTP API
- 5432: PostgreSQL (for direct database access)

## Volumes
- `postgres-data`: PostgreSQL data (persistent)
- `./config`: AME keystore and config files (mounted)
- `./data/ready`: XML files for ingestion (mounted)
- `./logs`: Application logs (mounted)

## First Deployment
On first run, db-init container:
1. Creates schemas, extensions, roles
2. Creates all tables (claims, reference data, audit)
3. Creates materialized views for reports
4. Creates user management schema
5. Initializes DHPO configuration
6. Marks database as initialized

Subsequent deployments skip initialization (idempotent).

## Adding Facilities
Use Admin API to add DHPO facility configurations with encrypted credentials.

## See Also
- OPERATIONS.md - Day-to-day operations
- TESTING.md - Testing guide
```

#### `docker/OPERATIONS.md` - Operations Manual

````markdown
# Claims Backend - Operations Manual

## Starting the Stack
```bash
docker-compose up -d
````

## Stopping the Stack

```bash
docker-compose down
```

## Viewing Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f app
docker-compose logs -f postgres

# Last 100 lines
docker-compose logs --tail=100 app
```

## Redeploying Application (Preserves Database)

```bash
# Rebuild and restart app only
docker-compose up -d --build app

# Or full stack
docker-compose down
docker-compose up --build -d
```

## Fresh Database (Nuclear Option)

```bash
docker-compose down -v  # REMOVES ALL DATA
docker-compose up -d
```

## Database Access

### Option 1: psql from Host

```bash
psql -h localhost -p 5432 -U claims_user -d claims
```

### Option 2: psql in Container

```bash
docker exec -it claims-postgres psql -U claims_user -d claims
```

### Option 3: Execute SQL File

```bash
# From host
psql -h localhost -p 5432 -U claims_user -d claims -f my-changes.sql

# Via container
docker cp my-changes.sql claims-postgres:/tmp/
docker exec -it claims-postgres psql -U claims_user -d claims -f /tmp/my-changes.sql
```

## Making Runtime Database Changes

For small changes during development:

1. Connect to database (see above)
2. Run your DDL/DML:
   ```sql
   ALTER TABLE claims.claim ADD COLUMN new_field TEXT;
   CREATE INDEX idx_new ON claims.claim(new_field);
   ```

3. Changes persist in the volume

**For permanent changes**: Add SQL to appropriate script in `docker/db-init/` for next fresh deployment.

## Refreshing Materialized Views

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_balance_amount_summary;
REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_remittance_advice_summary;
-- etc.
```

## Checking Application Status

```bash
# Health check
curl http://localhost:8080/actuator/health

# Metrics
curl http://localhost:8080/actuator/metrics

# Environment
curl http://localhost:8080/actuator/env
```

## Ingestion Monitoring

```sql
-- Check ingestion runs
SELECT * FROM claims.ingestion_run ORDER BY started_at DESC LIMIT 10;

-- Check processed files
SELECT * FROM claims.ingestion_file ORDER BY created_at DESC LIMIT 10;

-- Check errors
SELECT * FROM claims.ingestion_error ORDER BY created_at DESC LIMIT 20;

-- Check claim counts
SELECT COUNT(*) FROM claims.claim;
SELECT COUNT(*) FROM claims.remittance_claim;
```

## Container Management

```bash
# Restart service
docker-compose restart app

# Enter container shell
docker exec -it claims-app bash

# Check resource usage
docker stats

# Clean up stopped containers
docker system prune
```

## Backup Database

```bash
docker exec claims-postgres pg_dump -U claims_user -d claims > backup_$(date +%Y%m%d).sql
```

## Restore Database

```bash
cat backup_20250114.sql | docker exec -i claims-postgres psql -U claims_user -d claims
```



`````

#### `docker/TESTING.md` - Testing Guide

````markdown
# Claims Backend - Testing Guide

## E2E Ingestion Testing

### 1. Verify Services Running
```bash
docker-compose ps
# All services should be "Up" and healthy
````

### 2. Add XML Test File

```bash
# Copy test file from resources
cp src/main/resources/xml/submission_min_ok.xml data/ready/

# Or copy any XML file
docker cp your-file.xml claims-app:/app/data/ready/
`````

### 3. Watch Ingestion Logs

```bash
docker-compose logs -f app | grep -i ingestion
```

### 4. Verify Ingestion Success

```bash
psql -h localhost -p 5432 -U claims_user -d claims
```



```sql
-- Check file processed
SELECT file_id, sender_id, record_count, status, created_at 
FROM claims.ingestion_file 
ORDER BY created_at DESC LIMIT 5;

-- Check claims ingested
SELECT ck.claim_id, c.payer_id, c.provider_id, c.gross, c.net
FROM claims.claim c
JOIN claims.claim_key ck ON ck.id = c.claim_key_id
ORDER BY c.created_at DESC LIMIT 10;

-- Check encounters
SELECT e.facility_id, e.patient_id, e.start_at
FROM claims.encounter e
ORDER BY e.created_at DESC LIMIT 10;

-- Check activities
SELECT a.code, a.type, a.quantity, a.net
FROM claims.activity a
ORDER BY a.created_at DESC LIMIT 10;
```

### 5. Test Report APIs

```bash
# Health check
curl http://localhost:8080/actuator/health

# Balance Amount Report (requires auth in prod)
curl http://localhost:8080/api/reports/balance-amount?startDate=2025-01-01&endDate=2025-12-31

# Claim Details Report
curl http://localhost:8080/api/reports/claim-details?claimId=CLAIM123
```

## Testing Materialized Views

```sql
-- Check MV row counts
SELECT 'mv_balance_amount_summary' as mv, COUNT(*) FROM claims.mv_balance_amount_summary
UNION ALL
SELECT 'mv_remittance_advice_summary', COUNT(*) FROM claims.mv_remittance_advice_summary
UNION ALL
SELECT 'mv_claim_summary_payerwise', COUNT(*) FROM claims.mv_claim_summary_payerwise;

-- Test MV query performance
\timing on
SELECT * FROM claims.mv_balance_amount_summary LIMIT 100;
```

## Testing Reference Data Bootstrap

```sql
-- Check reference data loaded
SELECT COUNT(*) FROM claims_ref.payer;
SELECT COUNT(*) FROM claims_ref.provider;
SELECT COUNT(*) FROM claims_ref.facility;
SELECT COUNT(*) FROM claims_ref.clinician;
SELECT COUNT(*) FROM claims_ref.activity_code;
SELECT COUNT(*) FROM claims_ref.diagnosis_code;
```

## Performance Testing

```bash
# Generate load with multiple XML files
for i in {1..10}; do
  cp src/main/resources/xml/submission_multi_ok.xml data/ready/test_$i.xml
done

# Monitor processing
docker stats claims-app
docker-compose logs -f app | grep "persistSubmission"
```

## Troubleshooting

- Check logs: `docker-compose logs app`
- Check DB connection: `docker exec claims-app nc -zv postgres 5432`
- Check disk space: `docker system df`
- Check errors: `SELECT * FROM claims.ingestion_error ORDER BY created_at DESC;`
````

### 10. Helper Scripts

#### `docker/scripts/build.sh`
```bash
#!/bin/bash
set -e
echo "Building Docker images..."
docker-compose build --no-cache
echo "Build complete!"
docker images | grep claims
````


#### `docker/scripts/deploy.sh`

```bash
#!/bin/bash
set -e

echo "Stopping existing containers..."
docker-compose down

echo "Building images..."
docker-compose build

echo "Starting services..."
docker-compose up -d

echo "Waiting for services to be healthy..."
sleep 10

echo "Service status:"
docker-compose ps

echo "Application logs:"
docker-compose logs --tail=50 app

echo "Deployment complete! Access application at http://localhost:8080"
```

#### `docker/scripts/logs.sh`

```bash
#!/bin/bash
SERVICE=${1:-}
if [ -z "$SERVICE" ]; then
  docker-compose logs -f
else
  docker-compose logs -f "$SERVICE"
fi
```

#### `docker/scripts/db-shell.sh`

```bash
#!/bin/bash
docker exec -it claims-postgres psql -U claims_user -d claims
```

#### `docker/scripts/clean.sh`

```bash
#!/bin/bash
echo "WARNING: This will remove all containers and images!"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 0
fi

echo "Stopping containers..."
docker-compose down

echo "Removing images..."
docker rmi $(docker images -q 'claims*')

echo "Cleaning build artifacts..."
rm -rf target/

echo "Clean complete!"
```

## Database Initialization Flow

```
1. docker-compose up
2. postgres container starts → mounts persistent volume, data preserved
3. db-init container starts → checks if db initialized
4. IF NOT initialized:
   - Executes 01-init-db.sql (schemas, extensions, roles)
   - Executes 02-core-tables.sql (all claims tables)
   - Executes 03-ref-data-tables.sql (reference tables)
   - Executes 04-dhpo-config.sql (DHPO + AME encryption tables)
   - Executes 05-user-management.sql (auth tables)
   - Executes 06-materialized-views.sql (MVs for reports)
   - Executes 07-report-views.sql (report views)
   - Executes 08-functions-procedures.sql (stored functions)
   - Executes 99-verify-init.sql (verification + marker)
   - Marks DB as initialized
5. IF ALREADY initialized: Skip all DDL (fast restart)
6. app container starts → connects to postgres
7. app bootstrap loads CSV reference data (payers, providers, etc.)
8. app starts SOAP fetcher (polls DHPO every 30 mins)
9. Ready for E2E testing
```

## Profile-Based Behavior

### `docker` profile (application-docker.yml)

- Database connection to postgres container
- Paths mapped to container filesystem
- Bootstrap enabled for reference data
- Logging to console + file

### `ingestion` profile (application-ingestion.yml)

- Security disabled for ingestion tasks
- Ingestion orchestrator active
- File watching enabled

### `prod` profile (application-prod.yml)

- Production optimizations
- Connection pooling tuned
- Monitoring enabled
- Flyway enabled (but we override to false in docker profile)
- AME encryption ENABLED

### `soap` profile (application-soap.yml)

- SOAP fetcher active
- DHPO client configured
- Facility polling enabled (30 min intervals)
- Download concurrency: 16
- Credentials from encrypted DB (via AME)

## AME Encryption Details

### Configuration

- **Type**: PKCS12 keystore
- **Path**: `/app/config/claims.p12` (mounted from host `./config` directory)
- **Password**: From environment variable `CLAIMS_AME_STORE_PASS`
- **Alias**: `claims-ame`
- **Key ID**: `claims-ame.v1`
- **Algorithm**: AES-256-GCM with 128-bit auth tag

### What Gets Encrypted

- DHPO facility usernames (`dhpo_username_enc` in `facility_dhpo_config`)
- DHPO facility passwords (`dhpo_password_enc` in `facility_dhpo_config`)
- Encryption metadata stored in `enc_meta_json` (key version, algorithm, IV)

### Setup Steps

1. Run `docker/scripts/generate-ame-keystore.sh` to create keystore
2. Add keystore password to `.env` as `CLAIMS_AME_STORE_PASS`
3. On first run, app reads keystore and initializes AME service
4. When facilities are added via Admin API, credentials are encrypted using AME
5. On SOAP poll, app decrypts credentials in-memory for DHPO calls

### Security Notes

- Keystore file has 600 permissions (owner read/write only)
- Password passed via environment variable (not in source code)
- Credentials never logged or exposed in plaintext
- Encryption key can be rotated by changing `keyId` in config

## Making Manual Database Changes

### During Runtime (Temporary Changes)

For quick testing or small fixes:

```bash
# Option 1: psql from host
psql -h localhost -p 5432 -U claims_user -d claims
# Then run your SQL

# Option 2: psql in container
docker exec -it claims-postgres psql -U claims_user -d claims

# Option 3: Execute SQL file from host
psql -h localhost -p 5432 -U claims_user -d claims -f my-changes.sql

# Option 4: Copy file to container and execute
docker cp my-changes.sql claims-postgres:/tmp/
docker exec -it claims-postgres psql -U claims_user -d claims -f /tmp/my-changes.sql
```

### Example Runtime Changes

```sql
-- Add column
ALTER TABLE claims.claim ADD COLUMN IF NOT EXISTS new_field TEXT;

-- Create index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_claim_new ON claims.claim(new_field);

-- Refresh materialized view
REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_balance_amount_summary;

-- Update data
UPDATE claims_ref.payer SET status = 'ACTIVE' WHERE payer_code = 'INS123';
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

## Testing the Deployment

### Quick Verification Checklist

```bash
# 1. All containers running
docker-compose ps
# Expected: postgres (healthy), app (up)

# 2. Application health
curl http://localhost:8080/actuator/health
# Expected: {"status":"UP"}

# 3. Database accessible
psql -h localhost -p 5432 -U claims_user -d claims -c "SELECT version();"

# 4. Schemas created
psql -h localhost -p 5432 -U claims_user -d claims -c "\dn"
# Expected: claims, claims_ref, auth

# 5. Tables created
psql -h localhost -p 5432 -U claims_user -d claims -c "\dt claims.*" | wc -l
# Expected: ~30+ tables

# 6. Materialized views created
psql -h localhost -p 5432 -U claims_user -d claims -c "\dm claims.*" | wc -l
# Expected: 9 MVs

# 7. Reference data loaded
psql -h localhost -p 5432 -U claims_user -d claims -c "SELECT COUNT(*) FROM claims_ref.payer;"
# Expected: >0 (from CSV bootstrap)

# 8. AME keystore accessible
docker exec claims-app ls -la /app/config/claims.p12
# Expected: File exists with 600 permissions
```

### E2E Ingestion Test

See `docker/TESTING.md` for detailed testing procedures.

## Production Deployment Considerations

### Resource Limits (Future TODO)

```yaml
# Add to docker-compose.yml
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

### Multi-Facility Ingestion Performance (Separate Plan Required)

**Question raised**: When ingestion runs for multiple facilities every 30 mins, will it lock/exhaust the database and affect UI users?

**Concerns to address in separate plan**:

1. Connection pool sizing for concurrent facility polling
2. Database lock contention between ingestion and API queries
3. Materialized view refresh strategy (blocking vs concurrent)
4. Query performance impact during bulk inserts
5. Resource utilization (CPU, memory, I/O) during peak ingestion
6. Backpressure handling if ingestion rate exceeds processing capacity
7. Read replica strategy for API queries vs write-heavy ingestion

**Recommended approach** (future plan):

- Separate read/write database connections
- Tune HikariCP pool sizes based on facility count
- Use CONCURRENT refresh for MVs
- Implement query timeout policies
- Monitor lock wait times and connection pool exhaustion
- Consider partitioning strategy for large tables
- Load testing with realistic multi-facility scenarios

## Implementation Checklist

- [ ] Create main Dockerfile with multi-stage build
- [ ] Create docker-compose.yml with postgres, db-init, app services
- [ ] Audit and extract required SQL to 01-99 init scripts (no duplication)
- [ ] Create init.sh with idempotency check
- [ ] Create db-init Dockerfile
- [ ] Create application-docker.yml configuration
- [ ] Create .env.example with all variables including AME settings
- [ ] Create .dockerignore file
- [ ] Create generate-ame-keystore.sh script
- [ ] Create docker/README.md documentation
- [ ] Create docker/OPERATIONS.md manual
- [ ] Create docker/TESTING.md guide
- [ ] Create helper scripts (build.sh, deploy.sh, logs.sh, db-shell.sh, clean.sh)
- [ ] Verify report SQL files (views vs queries)
- [ ] Check for PL/pgSQL functions in DDL
- [ ] Test complete deployment end-to-end
- [ ] Verify materialized views work correctly
- [ ] Test AME encryption with facility config
- [ ] Build application with Maven (verify no compilation errors)

## Future Enhancements (Not in This Plan)

- Multi-facility ingestion performance optimization plan
- YML configuration cleanup and restructuring
- Separate API and ingestion containers for independent scaling
- Docker Swarm/Kubernetes deployment manifests
- Automated backups with retention policies
- Monitoring with Prometheus/Grafana
- Log aggregation with ELK/Loki
- SSL/TLS configuration with Let's Encrypt
- CI/CD pipeline integration
- Database connection pooling optimization for concurrent facilities

### To-dos

- [ ] Create main Dockerfile and db-init Dockerfile with proper multi-stage builds
- [ ] Create docker-compose.yml with postgres, db-init, and app services
- [ ] Create ordered SQL initialization scripts (01-99) in docker/db-init/
- [ ] Create application-docker.yml with Docker-specific configuration
- [ ] Create .env.example and .dockerignore files
- [ ] Create docker/README.md, OPERATIONS.md, and TESTING.md documentation
- [ ] Create helper scripts (build.sh, deploy.sh, logs.sh, db-shell.sh, clean.sh)
- [ ] Test complete deployment, verify database init, test ingestion, and verify reports
- [ ] Build application with Maven and verify no compilation errors