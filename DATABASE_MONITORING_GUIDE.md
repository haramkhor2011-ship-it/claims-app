# Database Monitoring Implementation Guide

## Overview

This implementation provides comprehensive database monitoring for the claims-backend application with daily log files and REST endpoints for real-time monitoring.

## Features

### 🔍 **Comprehensive Metrics Collection**
- **Database Information**: Product name, version, driver details
- **Size Metrics**: Database size, schema size (both human-readable and bytes)
- **Connection Metrics**: Active connections, idle connections, connection pool stats
- **Lock Monitoring**: Total locks, exclusive locks, share locks
- **Query Performance**: Total calls, average query time, slow queries
- **Table Statistics**: Top 10 tables with insert/update/delete counts, live/dead tuples

### 📊 **Daily Log Files**
- **Dedicated Log File**: `logs/database-monitoring.log`
- **Daily Rotation**: Files rotated daily with 90-day retention
- **Structured Format**: Pipe-separated values for easy parsing
- **Size Management**: 50MB max file size, 5GB total cap

### 🌐 **REST API Endpoints**
- **GET** `/api/monitoring/database/stats` - Current monitoring statistics
- **POST** `/api/monitoring/database/health-check` - Manual health check
- **GET** `/api/monitoring/database/health` - Simple health status

## Configuration

### Application Properties

```yaml
claims:
  monitoring:
    database:
      enabled: true                            # Enable/disable monitoring
      interval: PT5M                           # Monitoring interval (5 minutes)
      log-daily: true                          # Enable daily log files
      collect-query-stats: true                # Collect query performance stats
      collect-table-stats: true                # Collect table statistics
```

### Logging Configuration

The monitoring uses a dedicated log appender in `logback-spring.xml`:

```xml
<!-- Database Monitoring File Appender -->
<appender name="DB_MONITORING_FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
    <file>logs/database-monitoring.log</file>
    <filter class="ch.qos.logback.core.filter.EvaluatorFilter">
        <evaluator class="ch.qos.logback.classic.boolex.OnMarkerEvaluator">
            <marker>DB_MONITORING</marker>
        </evaluator>
        <onMismatch>DENY</onMismatch>
        <onMatch>ACCEPT</onMatch>
    </filter>
    <rollingPolicy class="ch.qos.logback.core.rolling.SizeAndTimeBasedRollingPolicy">
        <fileNamePattern>logs/database-monitoring.%d{yyyy-MM-dd}.%i.log</fileNamePattern>
        <maxFileSize>50MB</maxFileSize>
        <maxHistory>90</maxHistory>
        <totalSizeCap>5GB</totalSizeCap>
    </rollingPolicy>
    <encoder>
        <pattern>%msg%n</pattern>
    </encoder>
</appender>
```

## Log Format

### Daily Log Structure

Each monitoring entry is logged in a structured format:

```
DB_MONITORING|2025-01-15 10:30:00.123|DB_INFO|product=PostgreSQL|version=15.4|driver=PostgreSQL JDBC Driver|driver_version=42.7.3|SIZE|db_size=2.5 GB|db_size_bytes=2684354560|schema_size=1.2 GB|schema_size_bytes=1288490188|CONNECTIONS|active=15|active_queries=3|idle=12|idle_in_transaction=0|pool_active=10|pool_idle=5|pool_total=15|LOCKS|total=25|exclusive=5|share=20|QUERY_PERF|total_calls=15420|total_time_ms=23456.78|avg_time_ms=1.52|slow_queries=12|TOP_TABLES|claims:live=50000,dead=1200,inserts=1500,updates=800,deletes=50;submissions:live=25000,dead=600,inserts=800,updates=400,deletes=25;|APP_METRICS|connection_count=15420|query_count=45678|error_count=3|
```

### Field Descriptions

| Section | Field | Description |
|---------|-------|-------------|
| **DB_INFO** | product | Database product name (e.g., PostgreSQL) |
| | version | Database version |
| | driver | JDBC driver name |
| | driver_version | JDBC driver version |
| **SIZE** | db_size | Human-readable database size |
| | db_size_bytes | Database size in bytes |
| | schema_size | Human-readable schema size |
| | schema_size_bytes | Schema size in bytes |
| **CONNECTIONS** | active | Total active connections |
| | active_queries | Connections with active queries |
| | idle | Idle connections |
| | idle_in_transaction | Connections idle in transaction |
| | pool_active | Connection pool active connections |
| | pool_idle | Connection pool idle connections |
| | pool_total | Connection pool total connections |
| **LOCKS** | total | Total database locks |
| | exclusive | Exclusive locks |
| | share | Share locks |
| **QUERY_PERF** | total_calls | Total query calls (if pg_stat_statements enabled) |
| | total_time_ms | Total query time in milliseconds |
| | avg_time_ms | Average query time in milliseconds |
| | slow_queries | Number of slow queries (>1000ms) |
| **TOP_TABLES** | table_name | Table statistics (live/dead tuples, operations) |
| **APP_METRICS** | connection_count | Application connection count |
| | query_count | Application query count |
| | error_count | Application error count |

## Usage Examples

### 1. Check Current Monitoring Stats

```bash
curl -X GET http://localhost:8080/api/monitoring/database/stats
```

Response:
```json
{
  "connectionCount": 15420,
  "queryCount": 45678,
  "errorCount": 3,
  "monitoringEnabled": true,
  "monitoringInterval": "PT5M"
}
```

### 2. Perform Manual Health Check

```bash
curl -X POST http://localhost:8080/api/monitoring/database/health-check
```

Response:
```json
{
  "timestamp": "2025-01-15T10:30:00.123",
  "database": "PostgreSQL",
  "version": "15.4",
  "databaseSize": "2.5 GB",
  "schemaSize": "1.2 GB",
  "activeConnections": 15,
  "activeQueries": 3,
  "totalLocks": 25,
  "totalQueryCalls": 15420,
  "avgQueryTimeMs": 1.52,
  "slowQueries": 12
}
```

### 3. Check Health Status

```bash
curl -X GET http://localhost:8080/api/monitoring/database/health
```

Response:
```json
{
  "status": "UP",
  "message": "Database is healthy",
  "timestamp": "2025-01-15T10:30:00.123"
}
```

## Monitoring Alerts

The system automatically detects potential issues:

- **High Connections**: >100 active connections → WARNING
- **High Locks**: >50 total locks → WARNING  
- **Slow Queries**: >1000ms average query time → WARNING
- **Database Errors**: Any database connection/query errors → ERROR

## Log Analysis

### Parse Daily Logs

```bash
# Extract database size trends
grep "SIZE|" logs/database-monitoring.log | cut -d'|' -f4,5

# Find slow query periods
grep "QUERY_PERF|" logs/database-monitoring.log | grep "slow_queries=[1-9]"

# Monitor connection spikes
grep "CONNECTIONS|" logs/database-monitoring.log | grep "active=[5-9][0-9]"
```

### Generate Reports

```bash
# Daily summary
echo "=== Database Monitoring Summary for $(date) ==="
echo "Total log entries: $(wc -l logs/database-monitoring.log)"
echo "Database size: $(grep "SIZE|" logs/database-monitoring.log | tail -1 | cut -d'|' -f4)"
echo "Active connections: $(grep "CONNECTIONS|" logs/database-monitoring.log | tail -1 | cut -d'|' -f4)"
echo "Slow queries: $(grep "QUERY_PERF|" logs/database-monitoring.log | tail -1 | cut -d'|' -f4)"
```

## Performance Impact

### Minimal Overhead
- **Monitoring Interval**: 5 minutes (configurable)
- **Query Overhead**: ~10-15 additional queries per monitoring cycle
- **Memory Usage**: <1MB for metrics collection
- **Log I/O**: Asynchronous logging with minimal impact

### Optimization Features
- **Async Logging**: Non-blocking log writes
- **Connection Pooling**: Reuses existing connections
- **Error Handling**: Graceful degradation on monitoring failures
- **Configurable Intervals**: Adjustable monitoring frequency

## Troubleshooting

### Common Issues

1. **Monitoring Not Starting**
   - Check `claims.monitoring.database.enabled=true`
   - Verify database connectivity
   - Check application logs for initialization errors

2. **Missing Query Statistics**
   - Ensure `pg_stat_statements` extension is enabled
   - Check PostgreSQL configuration for query statistics

3. **High Log Volume**
   - Adjust monitoring interval: `claims.monitoring.database.interval=PT10M`
   - Disable specific metrics collection
   - Increase log file size limits

4. **Connection Pool Metrics Missing**
   - HikariCP metrics require additional configuration
   - Connection pool wrapper may need adjustment

### Debug Mode

Enable debug logging for monitoring:

```yaml
logging:
  level:
    com.acme.claims.monitoring: DEBUG
```

## Integration with Monitoring Tools

### Prometheus Integration
The REST endpoints can be scraped by Prometheus:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'claims-database-monitoring'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/api/monitoring/database/stats'
    scrape_interval: 30s
```

### Grafana Dashboard
Create dashboards using the REST API endpoints or parse the daily log files for historical data visualization.

## Security Considerations

- **Endpoint Security**: Consider adding authentication to monitoring endpoints in production
- **Log Security**: Ensure log files have appropriate permissions
- **Data Sensitivity**: Database connection strings are logged - review log access controls

## Future Enhancements

- **Alert Integration**: Email/Slack notifications for critical issues
- **Historical Analysis**: Long-term trend analysis and capacity planning
- **Custom Metrics**: Application-specific database metrics
- **Performance Baselines**: Automatic baseline establishment and deviation detection
