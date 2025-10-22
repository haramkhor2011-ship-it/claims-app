# Debugging Guide - Claims Backend Application

> Comprehensive troubleshooting guide for the claims-backend application. This guide helps developers diagnose and resolve common issues, understand error patterns, and use debugging tools effectively.

## Overview

This guide provides systematic approaches to debugging issues in the claims-backend application:

- **Common issue patterns and solutions**
- **Debugging tools and techniques**
- **Log analysis and interpretation**
- **Performance troubleshooting**
- **Database debugging**
- **SOAP integration debugging**

---

## Debugging Methodology

### 1. Systematic Approach
1. **Reproduce the Issue** - Consistently reproduce the problem
2. **Gather Information** - Collect logs, metrics, and context
3. **Isolate the Problem** - Narrow down to specific components
4. **Analyze Root Cause** - Understand why the issue occurs
5. **Implement Fix** - Apply appropriate solution
6. **Verify Resolution** - Confirm the fix works
7. **Document Solution** - Record the solution for future reference

### 2. Information Gathering
- **Application Logs** - Check application logs for errors
- **Database Logs** - Check database logs for issues
- **System Metrics** - Monitor CPU, memory, disk usage
- **Network Logs** - Check network connectivity issues
- **Configuration** - Verify configuration settings
- **Environment** - Check environment variables and settings

---

## Common Issue Categories

### 1. Ingestion Failures

**Symptoms**:
- Files not being processed
- Processing errors in logs
- Database constraint violations
- Memory issues

**Debugging Steps**:

**Step 1: Check Orchestrator Status**
```bash
# Check orchestrator logs
tail -f logs/application.log | grep "Orchestrator"

# Check if orchestrator is running
curl -X GET http://localhost:8080/actuator/health
```

**Step 2: Check File Processing**
```bash
# Check ingestion file status
psql -d claims -c "SELECT file_id, root_type, created_at FROM claims.ingestion_file ORDER BY created_at DESC LIMIT 10;"

# Check for processing errors
psql -d claims -c "SELECT file_id, stage, error_code, error_message FROM claims.ingestion_error ORDER BY occurred_at DESC LIMIT 10;"
```

**Step 3: Check Pipeline Status**
```bash
# Check pipeline processing logs
tail -f logs/application.log | grep "PIPELINE"

# Check for validation errors
tail -f logs/application.log | grep "VALIDATION"
```

**Common Solutions**:
- **Memory Issues**: Increase JVM heap size or reduce batch size
- **Database Issues**: Check connection pool, add indexes
- **Validation Errors**: Check XML format, update validation rules
- **File Access Issues**: Check file permissions, disk space

---

### 2. SOAP Integration Issues

**Symptoms**:
- SOAP calls failing
- Authentication errors
- Network timeouts
- File download failures

**Debugging Steps**:

**Step 1: Check SOAP Service Status**
```bash
# Check SOAP service logs
tail -f logs/application.log | grep "SOAP"

# Check facility polling
tail -f logs/application.log | grep "pollFacilities"
```

**Step 2: Check Credentials**
```bash
# Check facility credentials
psql -d claims -c "SELECT facility_id, endpoint_url FROM facility_credential;"

# Test credential decryption
curl -X POST http://localhost:8080/admin/test-credentials -d '{"facilityId": "FACILITY_001"}'
```

**Step 3: Check Network Connectivity**
```bash
# Test SOAP endpoint connectivity
curl -v https://soap-endpoint.example.com/soap/inbox

# Check DNS resolution
nslookup soap-endpoint.example.com
```

**Common Solutions**:
- **Authentication Issues**: Rotate credentials, check encryption keys
- **Network Issues**: Check firewall rules, proxy settings
- **Timeout Issues**: Increase timeout values, check network latency
- **SSL Issues**: Update certificates, check SSL configuration

---

### 3. Report Generation Issues

**Symptoms**:
- Reports failing to generate
- Slow report performance
- Access denied errors
- Data inconsistencies

**Debugging Steps**:

**Step 1: Check Report Service Status**
```bash
# Check report generation logs
tail -f logs/application.log | grep "ReportService"

# Check report requests
curl -X GET http://localhost:8080/admin/reports/status
```

**Step 2: Check Database Queries**
```bash
# Check slow queries
psql -d claims -c "SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"

# Check materialized view status
psql -d claims -c "SELECT schemaname, matviewname, ispopulated FROM pg_matviews;"
```

**Step 3: Check Security Context**
```bash
# Check user roles
curl -X GET http://localhost:8080/admin/user/roles

# Check facility context
curl -X GET http://localhost:8080/admin/facility/context
```

**Common Solutions**:
- **Performance Issues**: Add indexes, optimize queries, use materialized views
- **Access Issues**: Check role assignments, facility context
- **Data Issues**: Refresh materialized views, check data integrity
- **Memory Issues**: Increase JVM heap size, optimize queries

---

### 4. Database Issues

**Symptoms**:
- Connection pool exhaustion
- Slow queries
- Deadlocks
- Constraint violations

**Debugging Steps**:

**Step 1: Check Connection Pool**
```bash
# Check connection pool status
curl -X GET http://localhost:8080/actuator/metrics/hikaricp.connections.active

# Check database connections
psql -d claims -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"
```

**Step 2: Check Query Performance**
```bash
# Check slow queries
psql -d claims -c "SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"

# Check query plans
psql -d claims -c "EXPLAIN ANALYZE SELECT * FROM claims.claim WHERE created_at > '2024-01-01';"
```

**Step 3: Check Database Locks**
```bash
# Check for locks
psql -d claims -c "SELECT pid, mode, locktype, relation::regclass FROM pg_locks WHERE NOT granted;"

# Check for deadlocks
tail -f /var/log/postgresql/postgresql.log | grep "deadlock"
```

**Common Solutions**:
- **Connection Issues**: Increase pool size, check connection leaks
- **Performance Issues**: Add indexes, optimize queries, update statistics
- **Lock Issues**: Optimize transaction boundaries, reduce lock duration
- **Constraint Issues**: Check data integrity, update constraints

---

## Log Analysis

### 1. Application Logs

**Log Levels**:
- **ERROR**: System errors, exceptions
- **WARN**: Warning conditions, recoverable errors
- **INFO**: General information, business events
- **DEBUG**: Detailed debugging information
- **TRACE**: Very detailed tracing information

**Key Log Patterns**:

**Ingestion Logs**:
```bash
# Pipeline processing
grep "PIPELINE_START\|PIPELINE_COMPLETE\|PIPELINE_FAIL" logs/application.log

# Validation errors
grep "VALIDATION_FAILED\|VALIDATION_SUCCESS" logs/application.log

# Persistence errors
grep "PERSIST\|PERSISTENCE" logs/application.log
```

**SOAP Logs**:
```bash
# SOAP calls
grep "SOAP_CALL\|SOAP_RESPONSE\|SOAP_ERROR" logs/application.log

# Facility polling
grep "pollFacilities\|downloadFiles" logs/application.log

# Authentication
grep "AUTHENTICATION\|CREDENTIAL" logs/application.log
```

**Report Logs**:
```bash
# Report generation
grep "REPORT_GENERATION\|REPORT_COMPLETE\|REPORT_FAIL" logs/application.log

# Security
grep "ACCESS_DENIED\|AUTHORIZATION" logs/application.log
```

### 2. Database Logs

**PostgreSQL Logs**:
```bash
# Check PostgreSQL logs
tail -f /var/log/postgresql/postgresql.log

# Check for errors
grep "ERROR\|FATAL" /var/log/postgresql/postgresql.log

# Check for slow queries
grep "slow query" /var/log/postgresql/postgresql.log
```

**Database Metrics**:
```sql
-- Check database size
SELECT pg_size_pretty(pg_database_size('claims'));

-- Check table sizes
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables WHERE schemaname = 'claims'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'claims'
ORDER BY idx_scan DESC;
```

---

## Performance Debugging

### 1. JVM Performance

**Memory Issues**:
```bash
# Check JVM memory usage
jstat -gc <pid> 1s

# Check heap dump
jmap -dump:format=b,file=heap.hprof <pid>

# Check memory leaks
jmap -histo <pid> | head -20
```

**CPU Issues**:
```bash
# Check CPU usage
top -p <pid>

# Check thread dumps
jstack <pid> > thread_dump.txt

# Check method profiling
jcmd <pid> JFR.start duration=60s filename=profile.jfr
```

### 2. Database Performance

**Query Performance**:
```sql
-- Check query performance
SELECT query, mean_time, calls, total_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;

-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read
FROM pg_stat_user_indexes
WHERE schemaname = 'claims'
ORDER BY idx_scan DESC;

-- Check table statistics
SELECT schemaname, tablename, n_tup_ins, n_tup_upd, n_tup_del
FROM pg_stat_user_tables
WHERE schemaname = 'claims'
ORDER BY n_tup_ins DESC;
```

**Connection Performance**:
```sql
-- Check connection pool
SELECT count(*) as active_connections
FROM pg_stat_activity
WHERE state = 'active';

-- Check connection details
SELECT pid, usename, application_name, client_addr, state, query
FROM pg_stat_activity
WHERE state = 'active';
```

---

## Debugging Tools

### 1. Application Debugging

**Spring Boot Actuator**:
```bash
# Health check
curl -X GET http://localhost:8080/actuator/health

# Metrics
curl -X GET http://localhost:8080/actuator/metrics

# Thread dump
curl -X GET http://localhost:8080/actuator/threaddump

# Heap dump
curl -X GET http://localhost:8080/actuator/heapdump
```

**JVM Tools**:
```bash
# JVisualVM
jvisualvm

# JConsole
jconsole

# JProfiler
jprofiler
```

### 2. Database Debugging

**PostgreSQL Tools**:
```bash
# psql
psql -d claims

# pgAdmin
pgAdmin4

# pg_stat_statements
psql -d claims -c "SELECT * FROM pg_stat_statements;"
```

**Query Analysis**:
```sql
-- Explain analyze
EXPLAIN ANALYZE SELECT * FROM claims.claim WHERE created_at > '2024-01-01';

-- Check query plan
EXPLAIN (FORMAT JSON) SELECT * FROM claims.claim WHERE created_at > '2024-01-01';
```

### 3. Network Debugging

**Network Tools**:
```bash
# Test connectivity
ping soap-endpoint.example.com

# Test ports
telnet soap-endpoint.example.com 443

# Check DNS
nslookup soap-endpoint.example.com

# Trace route
traceroute soap-endpoint.example.com
```

**HTTP Debugging**:
```bash
# Test HTTP endpoints
curl -v https://soap-endpoint.example.com/soap/inbox

# Test with authentication
curl -v -u username:password https://soap-endpoint.example.com/soap/inbox
```

---

## Error Code Reference

### 1. Ingestion Error Codes

**Parse Errors**:
- `PARSE_XML_SYNTAX` - XML syntax errors
- `PARSE_XSD_VALIDATION` - XSD validation errors
- `PARSE_MEMORY` - Memory issues during parsing
- `PARSE_ENCODING` - Character encoding errors

**Validation Errors**:
- `VALIDATE_HEADER_MISSING` - Missing required header fields
- `VALIDATE_CLAIM_MISSING` - Missing required claim fields
- `VALIDATE_BUSINESS_RULES` - Business rule violations
- `VALIDATE_DATA_FORMAT` - Data format errors

**Database Errors**:
- `DB_CONSTRAINT_VIOLATION` - Database constraint violations
- `DB_CONNECTION_FAILED` - Database connection failures
- `DB_TRANSACTION_FAILED` - Transaction failures
- `DB_QUERY_TIMEOUT` - Query timeout errors

### 2. SOAP Error Codes

**Authentication Errors**:
- `SOAP_AUTHENTICATION_FAILED` - Authentication failures
- `SOAP_CREDENTIAL_INVALID` - Invalid credentials
- `SOAP_TOKEN_EXPIRED` - Token expiration

**Network Errors**:
- `SOAP_NETWORK_ERROR` - Network connectivity issues
- `SOAP_TIMEOUT` - SOAP call timeouts
- `SOAP_SSL_ERROR` - SSL/TLS errors

**SOAP Errors**:
- `SOAP_FAULT` - SOAP fault responses
- `SOAP_INVALID_XML` - Invalid XML responses
- `SOAP_SCHEMA_ERROR` - Schema validation errors

### 3. Report Error Codes

**Validation Errors**:
- `REPORT_VALIDATION_FAILED` - Report parameter validation failures
- `REPORT_DATE_RANGE_INVALID` - Invalid date range
- `REPORT_PARAMETER_MISSING` - Missing required parameters

**Query Errors**:
- `REPORT_QUERY_FAILED` - SQL query failures
- `REPORT_TIMEOUT` - Report generation timeouts
- `REPORT_DATA_NOT_FOUND` - No data found for report

**Access Errors**:
- `REPORT_ACCESS_DENIED` - Report access denied
- `REPORT_FACILITY_MISMATCH` - Facility context mismatch
- `REPORT_ROLE_INSUFFICIENT` - Insufficient role permissions

---

## Troubleshooting Checklists

### 1. Ingestion Issues Checklist

- [ ] **Check Orchestrator Status**: Is orchestrator running?
- [ ] **Check File Queue**: Are files in the queue?
- [ ] **Check Pipeline Status**: Is pipeline processing files?
- [ ] **Check Database**: Are database connections working?
- [ ] **Check Memory**: Is there enough memory available?
- [ ] **Check Disk Space**: Is there enough disk space?
- [ ] **Check Logs**: Are there any error messages?
- [ ] **Check Configuration**: Are configuration settings correct?

### 2. SOAP Issues Checklist

- [ ] **Check Network**: Is network connectivity working?
- [ ] **Check Credentials**: Are credentials valid?
- [ ] **Check Endpoints**: Are SOAP endpoints accessible?
- [ ] **Check SSL**: Are SSL certificates valid?
- [ ] **Check Timeouts**: Are timeout settings appropriate?
- [ ] **Check Firewall**: Are firewall rules correct?
- [ ] **Check Proxy**: Are proxy settings correct?
- [ ] **Check Logs**: Are there any SOAP error messages?

### 3. Report Issues Checklist

- [ ] **Check Service**: Is report service running?
- [ ] **Check Database**: Are database queries working?
- [ ] **Check Security**: Are security settings correct?
- [ ] **Check Performance**: Are queries optimized?
- [ ] **Check Data**: Is data available for reports?
- [ ] **Check Materialized Views**: Are views refreshed?
- [ ] **Check Indexes**: Are indexes present and used?
- [ ] **Check Logs**: Are there any report error messages?

---

## Emergency Procedures

### 1. System Down

**Immediate Actions**:
1. **Check System Status**: Verify system is actually down
2. **Check Logs**: Look for fatal errors
3. **Check Resources**: Check CPU, memory, disk space
4. **Check Database**: Verify database connectivity
5. **Restart Services**: Restart application services
6. **Monitor Recovery**: Monitor system recovery

**Escalation**:
- Notify operations team
- Notify development team
- Notify management if critical

### 2. Data Corruption

**Immediate Actions**:
1. **Stop Processing**: Stop all data processing
2. **Assess Damage**: Determine scope of corruption
3. **Backup Current State**: Backup current database state
4. **Restore from Backup**: Restore from last known good backup
5. **Verify Data**: Verify data integrity
6. **Resume Processing**: Resume processing with monitoring

**Escalation**:
- Notify database administrator
- Notify development team
- Notify management

### 3. Security Breach

**Immediate Actions**:
1. **Isolate System**: Isolate affected systems
2. **Preserve Evidence**: Preserve logs and evidence
3. **Assess Damage**: Determine scope of breach
4. **Change Credentials**: Change all credentials
5. **Update Security**: Update security measures
6. **Monitor System**: Monitor for further breaches

**Escalation**:
- Notify security team
- Notify management
- Notify legal team if required

---

## Related Documentation

- [Modification Guide](MODIFICATION_GUIDE.md) - Modification procedures
- [Class Index](../quick-ref/CLASS_INDEX.md) - Complete list of all classes
- [Finding Code Guide](../quick-ref/FINDING_CODE_GUIDE.md) - How to find specific functionality
- [Common Patterns](../quick-ref/COMMON_PATTERNS.md) - Recurring patterns in codebase
- [Component Map](../architecture/COMPONENT_MAP.md) - High-level architecture overview
