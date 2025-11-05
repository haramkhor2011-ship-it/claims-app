# Claims Backend - Testing Guide

## Overview

This guide provides comprehensive testing procedures for the Claims Backend Docker deployment, including end-to-end ingestion testing, report validation, performance testing, and troubleshooting procedures.

## Prerequisites

- Docker deployment running and healthy
- Access to test XML files
- Database access via `./docker/scripts/db-shell.sh`
- Basic SQL knowledge for verification queries

## E2E Ingestion Testing

### 1. Verify Services Running

```bash
# Check all services are up
docker-compose ps

# Expected output:
# claims-postgres    Up (healthy)
# claims-db-init     Exit 0
# claims-app         Up (healthy)
```

### 2. Verify Application Health

```bash
# Check application health
curl http://localhost:8080/actuator/health

# Expected response:
# {"status":"UP","components":{"db":{"status":"UP"},"diskSpace":{"status":"UP"}}}
```

### 3. Add XML Test File

```bash
# Copy test file from resources
cp src/main/resources/xml/submission_min_ok.xml data/ready/

# Or copy any XML file
docker cp your-file.xml claims-app:/app/data/ready/

# Verify file is in place
ls -la data/ready/
```

### 4. Watch Ingestion Processing

```bash
# Monitor ingestion logs
./docker/scripts/logs.sh app | grep -i ingestion

# Look for these log messages:
# - "Starting ingestion cycle"
# - "Processing file: [filename]"
# - "File processed successfully"
# - "Ingestion cycle completed"
```

### 5. Verify Ingestion Success

```bash
# Connect to database
./docker/scripts/db-shell.sh
```

```sql
-- Check file was processed
SELECT 
  file_id, 
  sender_id, 
  record_count, 
  status, 
  created_at 
FROM claims.ingestion_file 
ORDER BY created_at DESC 
LIMIT 5;

-- Expected: status = 1 (PROCESSED), record_count > 0

-- Check claims were ingested
SELECT 
  ck.claim_id, 
  c.payer_id, 
  c.provider_id, 
  c.gross, 
  c.net,
  c.created_at
FROM claims.claim c
JOIN claims.claim_key ck ON ck.id = c.claim_key_id
ORDER BY c.created_at DESC 
LIMIT 10;

-- Check encounters
SELECT 
  e.facility_id, 
  e.patient_id, 
  e.start_at,
  e.type
FROM claims.encounter e
ORDER BY e.created_at DESC 
LIMIT 10;

-- Check activities
SELECT 
  a.code, 
  a.type, 
  a.quantity, 
  a.net,
  a.clinician
FROM claims.activity a
ORDER BY a.created_at DESC 
LIMIT 10;

-- Check observations
SELECT 
  o.obs_type,
  o.obs_code,
  o.value_text
FROM claims.observation o
ORDER BY o.created_at DESC 
LIMIT 10;
```

### 6. Verify Reference Data Resolution

```sql
-- Check reference data was resolved
SELECT 
  c.payer_id,
  c.payer_ref_id,
  p.name as payer_name
FROM claims.claim c
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
WHERE c.payer_ref_id IS NOT NULL
LIMIT 10;

-- Check facility resolution
SELECT 
  e.facility_id,
  e.facility_ref_id,
  f.name as facility_name
FROM claims.encounter e
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
WHERE e.facility_ref_id IS NOT NULL
LIMIT 10;
```

## Report Testing

### 1. Test Materialized Views

```sql
-- Check MV row counts
SELECT 
  'mv_balance_amount_summary' as mv_name, 
  COUNT(*) as row_count 
FROM claims.mv_balance_amount_summary
UNION ALL
SELECT 
  'mv_remittance_advice_summary', 
  COUNT(*) 
FROM claims.mv_remittance_advice_summary
UNION ALL
SELECT 
  'mv_claim_summary_payerwise', 
  COUNT(*) 
FROM claims.mv_claim_summary_payerwise
UNION ALL
SELECT 
  'mv_claim_summary_encounterwise', 
  COUNT(*) 
FROM claims.mv_claim_summary_encounterwise;

-- Test MV query performance
\timing on
SELECT * FROM claims.mv_balance_amount_summary LIMIT 100;
\timing off
```

### 2. Test Report APIs

```bash
# Health check
curl http://localhost:8080/actuator/health

# Metrics endpoint
curl http://localhost:8080/actuator/metrics

# Environment info
curl http://localhost:8080/actuator/env

# Note: Report APIs may require authentication in production
# Test with appropriate headers if JWT is enabled
```

### 3. Test Report Queries

```sql
-- Balance Amount Report
SELECT 
  claim_id,
  payer_name,
  provider_name,
  initial_net,
  total_payment,
  pending_amount,
  current_status
FROM claims.mv_balance_amount_summary
LIMIT 10;

-- Remittance Advice Report
SELECT 
  claim_id,
  payment_reference,
  date_settlement,
  total_payment,
  activity_count,
  payer_name
FROM claims.mv_remittance_advice_summary
LIMIT 10;

-- Claim Summary Payerwise
SELECT 
  payer_id,
  payer_name,
  claim_count,
  total_net,
  total_payment,
  payment_percentage
FROM claims.mv_claim_summary_payerwise
ORDER BY total_net DESC
LIMIT 10;
```

## Reference Data Bootstrap Testing

### 1. Verify Reference Data Loaded

```sql
-- Check reference data counts
SELECT 
  'payer' as table_name, 
  COUNT(*) as count 
FROM claims_ref.payer
UNION ALL
SELECT 
  'provider', 
  COUNT(*) 
FROM claims_ref.provider
UNION ALL
SELECT 
  'facility', 
  COUNT(*) 
FROM claims_ref.facility
UNION ALL
SELECT 
  'clinician', 
  COUNT(*) 
FROM claims_ref.clinician
UNION ALL
SELECT 
  'activity_code', 
  COUNT(*) 
FROM claims_ref.activity_code
UNION ALL
SELECT 
  'diagnosis_code', 
  COUNT(*) 
FROM claims_ref.diagnosis_code;

-- Expected: All counts > 0 (loaded from CSV files)
```

### 2. Test Reference Data Quality

```sql
-- Check for duplicate codes
SELECT 
  payer_code, 
  COUNT(*) 
FROM claims_ref.payer 
GROUP BY payer_code 
HAVING COUNT(*) > 1;

-- Should return no rows

-- Check for missing descriptions
SELECT 
  code, 
  description 
FROM claims_ref.activity_code 
WHERE description IS NULL OR description = ''
LIMIT 10;
```

## Performance Testing

### 1. Generate Load with Multiple XML Files

```bash
# Create multiple test files
for i in {1..10}; do
  cp src/main/resources/xml/submission_multi_ok.xml data/ready/test_$i.xml
done

# Monitor processing
docker stats claims-app

# Watch ingestion logs
./docker/scripts/logs.sh app | grep "persistSubmission"
```

### 2. Monitor Database Performance

```sql
-- Check active connections
SELECT 
  count(*) as active_connections,
  state
FROM pg_stat_activity 
WHERE datname = 'claims'
GROUP BY state;

-- Check slow queries
SELECT 
  query,
  mean_time,
  calls,
  total_time
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;

-- Check table sizes
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'claims'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### 3. Test Materialized View Refresh Performance

```sql
-- Test concurrent refresh
\timing on
REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_balance_amount_summary;
\timing off

-- Check refresh time
SELECT 
  schemaname,
  matviewname,
  last_refresh
FROM pg_stat_user_tables 
WHERE schemaname = 'claims' 
AND relname LIKE 'mv_%';
```

## AME Encryption Testing

### 1. Verify AME Keystore

```bash
# Check keystore exists
ls -la config/claims.p12

# Check keystore permissions (should be 600)
docker exec claims-app ls -la /app/config/claims.p12

# Test keystore access
docker exec claims-app keytool -list -keystore /app/config/claims.p12 -storepass $CLAIMS_AME_STORE_PASS
```

### 2. Test Facility Configuration

```sql
-- Check facility configuration table
SELECT 
  facility_code,
  facility_name,
  active,
  dhpo_username_enc IS NOT NULL as has_encrypted_username,
  dhpo_password_enc IS NOT NULL as has_encrypted_password
FROM claims.facility_dhpo_config;

-- Add test facility (if needed)
INSERT INTO claims.facility_dhpo_config (
  facility_code,
  facility_name,
  endpoint_url,
  dhpo_username_enc,
  dhpo_password_enc,
  enc_meta_json
) VALUES (
  'TEST-FACILITY',
  'Test Facility',
  'https://test.dhpo.endpoint',
  '\x0123456789abcdef', -- Encrypted username (example)
  '\xfedcba9876543210', -- Encrypted password (example)
  '{"kek_version":1,"alg":"AES/GCM","iv":"base64iv","tagBits":128}'
);
```

## SOAP Integration Testing

### 1. Test SOAP Configuration

```bash
# Check SOAP endpoint configuration
curl http://localhost:8080/actuator/env | jq '.propertySources[].properties | to_entries[] | select(.key | contains("soap"))'

# Check DHPO client configuration
curl http://localhost:8080/actuator/env | jq '.propertySources[].properties | to_entries[] | select(.key | contains("dhpo"))'
```

### 2. Test SOAP Polling

```sql
-- Check integration toggles
SELECT 
  code,
  enabled
FROM claims.integration_toggle
WHERE code LIKE 'dhpo%';

-- Check facility polling status (if available)
SELECT 
  facility_code,
  last_poll_time,
  status
FROM claims.facility_dhpo_config
WHERE active = true;
```

## Error Handling Testing

### 1. Test Invalid XML Files

```bash
# Create invalid XML file
echo "<?xml version='1.0'?><invalid>content</invalid>" > data/ready/invalid.xml

# Watch error handling
./docker/scripts/logs.sh app | grep -i error

# Check error was logged
./docker/scripts/db-shell.sh
```

```sql
-- Check ingestion errors
SELECT 
  stage,
  error_code,
  error_message,
  created_at
FROM claims.ingestion_error
ORDER BY created_at DESC
LIMIT 10;
```

### 2. Test Database Constraints

```sql
-- Test duplicate claim handling
-- This should be handled gracefully by the application
INSERT INTO claims.claim_key (claim_id) VALUES ('DUPLICATE-TEST');

-- Test foreign key constraints
-- This should fail gracefully
INSERT INTO claims.claim (claim_key_id, submission_id, payer_id, provider_id, emirates_id_number, gross, patient_share, net)
VALUES (999999, 999999, 'TEST', 'TEST', 'TEST', 100.00, 10.00, 90.00);
```

## Security Testing

### 1. Test Authentication (if enabled)

```bash
# Test protected endpoints
curl http://localhost:8080/actuator/env

# Test with invalid token
curl -H "Authorization: Bearer invalid-token" http://localhost:8080/api/reports/balance-amount

# Test with valid token (if available)
curl -H "Authorization: Bearer $VALID_JWT_TOKEN" http://localhost:8080/api/reports/balance-amount
```

### 2. Test Input Validation

```bash
# Test SQL injection protection
curl "http://localhost:8080/api/reports/balance-amount?startDate='; DROP TABLE claims.claim; --"

# Test XSS protection
curl "http://localhost:8080/api/reports/balance-amount?startDate=<script>alert('xss')</script>"
```

## Load Testing

### 1. Concurrent File Processing

```bash
# Create multiple files simultaneously
for i in {1..50}; do
  cp src/main/resources/xml/submission_multi_ok.xml data/ready/load_test_$i.xml &
done
wait

# Monitor processing
./docker/scripts/logs.sh app | grep -E "(processed|error|failed)"
```

### 2. Database Connection Stress Test

```sql
-- Test connection pool limits
-- Run multiple concurrent queries
SELECT pg_sleep(10); -- In multiple sessions

-- Check connection usage
SELECT 
  count(*) as total_connections,
  state
FROM pg_stat_activity 
WHERE datname = 'claims'
GROUP BY state;
```

## Troubleshooting Tests

### 1. Network Connectivity

```bash
# Test internal network
docker exec claims-app ping postgres

# Test external connectivity
docker exec claims-app ping google.com

# Test port accessibility
docker exec claims-app nc -zv postgres 5432
```

### 2. Resource Usage

```bash
# Check container resource usage
docker stats claims-app claims-postgres

# Check disk space
df -h
docker system df

# Check memory usage
docker exec claims-app free -h
```

### 3. Log Analysis

```bash
# Check for common error patterns
./docker/scripts/logs.sh app | grep -E "(ERROR|WARN|Exception|Failed)"

# Check for performance issues
./docker/scripts/logs.sh app | grep -E "(slow|timeout|performance)"

# Check for database issues
./docker/scripts/logs.sh app | grep -E "(connection|database|sql)"
```

## Test Data Management

### 1. Create Test Data Sets

```bash
# Create test data directory
mkdir -p test-data

# Copy various XML files
cp src/main/resources/xml/*.xml test-data/

# Create test scenarios
echo "Test scenario 1: Single claim submission" > test-data/scenario1.txt
echo "Test scenario 2: Multiple claims with remittance" > test-data/scenario2.txt
```

### 2. Clean Up Test Data

```bash
# Remove test files
rm -f data/ready/test_*.xml
rm -f data/ready/load_test_*.xml
rm -f data/ready/invalid.xml

# Clean up database test data
./docker/scripts/db-shell.sh
```

```sql
-- Remove test data
DELETE FROM claims.ingestion_file WHERE file_id LIKE 'test_%';
DELETE FROM claims.claim_key WHERE claim_id LIKE 'TEST-%';
DELETE FROM claims.facility_dhpo_config WHERE facility_code = 'TEST-FACILITY';
```

## Automated Testing

### 1. Health Check Script

```bash
#!/bin/bash
# health-check.sh

echo "Running health checks..."

# Check services
if ! docker-compose ps | grep -q "Up (healthy)"; then
  echo "ERROR: Services not healthy"
  exit 1
fi

# Check application health
if ! curl -s http://localhost:8080/actuator/health | grep -q '"status":"UP"'; then
  echo "ERROR: Application not healthy"
  exit 1
fi

# Check database connectivity
if ! docker exec claims-postgres pg_isready -U claims_user -d claims > /dev/null; then
  echo "ERROR: Database not ready"
  exit 1
fi

echo "All health checks passed!"
```

### 2. Ingestion Test Script

```bash
#!/bin/bash
# ingestion-test.sh

echo "Running ingestion test..."

# Copy test file
cp src/main/resources/xml/submission_min_ok.xml data/ready/test_$(date +%s).xml

# Wait for processing
sleep 30

# Check results
./docker/scripts/db-shell.sh -c "
SELECT COUNT(*) as processed_files 
FROM claims.ingestion_file 
WHERE file_id LIKE 'test_%' AND status = 1;
"

echo "Ingestion test completed!"
```

## Test Reporting

### 1. Generate Test Report

```bash
#!/bin/bash
# generate-test-report.sh

echo "Generating test report..."

# Create report file
REPORT_FILE="test-report-$(date +%Y%m%d_%H%M%S).txt"

echo "Claims Backend Test Report" > $REPORT_FILE
echo "Generated: $(date)" >> $REPORT_FILE
echo "========================================" >> $REPORT_FILE

# Service status
echo "Service Status:" >> $REPORT_FILE
docker-compose ps >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Application health
echo "Application Health:" >> $REPORT_FILE
curl -s http://localhost:8080/actuator/health >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Database stats
echo "Database Statistics:" >> $REPORT_FILE
./docker/scripts/db-shell.sh -c "SELECT claims.get_database_stats();" >> $REPORT_FILE

echo "Test report generated: $REPORT_FILE"
```

### 2. Performance Metrics

```sql
-- Generate performance report
SELECT 
  'Ingestion Performance' as metric_category,
  COUNT(*) as total_runs,
  AVG(EXTRACT(EPOCH FROM (ended_at - started_at))) as avg_duration_seconds,
  MAX(EXTRACT(EPOCH FROM (ended_at - started_at))) as max_duration_seconds,
  SUM(files_processed) as total_files_processed,
  SUM(claims_processed) as total_claims_processed
FROM claims.ingestion_run
WHERE ended_at IS NOT NULL
AND started_at >= NOW() - INTERVAL '24 hours';
```

## Best Practices

### 1. Test Environment Setup

- Use separate test environment for comprehensive testing
- Maintain test data sets for consistent testing
- Document test scenarios and expected outcomes
- Automate repetitive tests where possible

### 2. Test Data Management

- Use realistic but anonymized test data
- Clean up test data after each test run
- Maintain test data version control
- Document test data sources and purposes

### 3. Performance Testing

- Test with realistic data volumes
- Monitor resource usage during tests
- Test both normal and peak load scenarios
- Document performance baselines and thresholds

### 4. Security Testing

- Test authentication and authorization
- Validate input sanitization
- Test error handling and information disclosure
- Verify encryption and data protection

### 5. Continuous Testing

- Integrate tests into CI/CD pipeline
- Run health checks regularly
- Monitor system metrics continuously
- Set up automated alerts for failures

## Support and Troubleshooting

### Common Test Failures

**Ingestion not processing files**:
- Check file permissions in `data/ready/`
- Verify application is running with correct profiles
- Check database connectivity
- Review application logs for errors

**Database connection issues**:
- Verify PostgreSQL container is healthy
- Check database credentials in `.env`
- Test network connectivity between containers
- Review PostgreSQL logs

**Performance issues**:
- Check system resources (CPU, memory, disk)
- Monitor database connection pool usage
- Review slow query logs
- Check materialized view refresh times

### Getting Help

1. **Check Logs**: Always start with application and database logs
2. **Verify Configuration**: Ensure all environment variables are correct
3. **Test Connectivity**: Verify network connectivity and port availability
4. **Review Documentation**: Check this guide and application documentation
5. **Escalate**: Contact system administrator if issues persist
