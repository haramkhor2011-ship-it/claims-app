# Multi-Facility Ingestion Performance Plan

## Overview

This plan addresses the performance concerns and optimization strategies for handling multi-facility ingestion in the claims backend system. The current architecture polls multiple facilities every 30 minutes, which could potentially impact database performance and user experience.

## Current Architecture Concerns

### Performance Questions Raised
- **Question**: When ingestion runs for multiple facilities every 30 mins, will it lock/exhaust the database and affect UI users?
- **Impact**: Concurrent facility polling could create resource contention and performance bottlenecks

### Key Performance Concerns

1. **Connection Pool Sizing**
   - Current HikariCP pool may not be sized for concurrent facility polling
   - Risk of connection pool exhaustion during peak ingestion periods
   - Need to balance between ingestion throughput and API responsiveness

2. **Database Lock Contention**
   - Bulk inserts from multiple facilities could create table-level locks
   - Materialized view refreshes might block concurrent queries
   - Risk of deadlocks between ingestion and API operations

3. **Materialized View Refresh Strategy**
   - Current refresh approach (blocking vs concurrent) needs optimization
   - Impact on report performance during refresh operations
   - Need for intelligent refresh scheduling

4. **Query Performance Impact**
   - Bulk inserts could slow down existing queries
   - Index maintenance overhead during high-volume ingestion
   - Potential impact on report generation performance

5. **Resource Utilization**
   - CPU, memory, and I/O spikes during concurrent facility polling
   - Need for resource monitoring and throttling mechanisms
   - Backpressure handling if ingestion rate exceeds processing capacity

6. **Read/Write Separation**
   - Current single database handles both ingestion and API queries
   - Need for read replica strategy to separate concerns
   - Load balancing between read and write operations

## Recommended Optimization Strategy

### 1. Database Connection Optimization

#### Connection Pool Tuning
```yaml
# Enhanced HikariCP configuration for multi-facility
spring:
  datasource:
    hikari:
      maximum-pool-size: 50  # Increased from 20
      minimum-idle: 10       # Increased from 5
      connection-timeout: 30000
      idle-timeout: 300000
      max-lifetime: 1800000
      leak-detection-threshold: 60000
      pool-name: ClaimsHikariCP
```

#### Separate Connection Pools
- **Ingestion Pool**: Dedicated pool for SOAP fetcher and bulk operations
- **API Pool**: Separate pool for user-facing API operations
- **Report Pool**: Dedicated pool for materialized view operations

### 2. Materialized View Optimization

#### Concurrent Refresh Strategy
```sql
-- Use CONCURRENT refresh to avoid blocking
REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_balance_amount_summary;
REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_remittance_advice_summary;
REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_claim_summary_payerwise;
```

#### Intelligent Refresh Scheduling
- **Staggered Refresh**: Refresh MVs at different intervals to spread load
- **Conditional Refresh**: Only refresh if significant data changes detected
- **Background Refresh**: Use scheduled tasks for non-critical MVs

### 3. Database Architecture Enhancements

#### Read/Write Separation
```yaml
# Multi-datasource configuration
spring:
  datasource:
    primary:
      url: jdbc:postgresql://postgres-write:5432/claims
      # Write operations (ingestion, updates)
    secondary:
      url: jdbc:postgresql://postgres-read:5432/claims
      # Read operations (reports, API queries)
```

#### Connection Routing Strategy
- **Write Operations**: Ingestion, updates, MV refreshes → Primary DB
- **Read Operations**: Reports, API queries → Read replica
- **Transaction Management**: Proper routing based on operation type

### 4. Ingestion Performance Optimization

#### Facility Polling Strategy
```yaml
claims:
  soap:
    facility:
      polling:
        strategy: staggered  # vs concurrent
        stagger-interval-ms: 30000  # 30 seconds between facilities
        max-concurrent-facilities: 5
        timeout-per-facility-ms: 300000  # 5 minutes
```

#### Batch Processing Optimization
- **Batch Size Tuning**: Optimize batch sizes for bulk inserts
- **Parallel Processing**: Process multiple files concurrently within facility
- **Queue Management**: Implement backpressure for queue overflow

### 5. Monitoring and Alerting

#### Performance Metrics
```yaml
management:
  metrics:
    export:
      prometheus:
        enabled: true
  endpoint:
    metrics:
      enabled: true
```

#### Key Metrics to Monitor
- **Connection Pool Utilization**: Active/idle connections per pool
- **Database Lock Wait Times**: Monitor for contention
- **Query Performance**: Slow query detection and alerting
- **Ingestion Throughput**: Files processed per minute per facility
- **Resource Utilization**: CPU, memory, I/O during peak periods

### 6. Load Testing Strategy

#### Multi-Facility Simulation
```bash
# Load testing scenarios
- 10 facilities polling simultaneously
- 50 facilities with staggered polling
- Peak load: 100+ facilities with concurrent operations
- Stress test: Ingestion + API load + MV refresh
```

#### Performance Benchmarks
- **Target**: <2 second API response times during ingestion
- **Target**: <30 second MV refresh times
- **Target**: <5% connection pool utilization during normal operations
- **Target**: Zero deadlocks during concurrent operations

## Implementation Phases

### Phase 1: Connection Pool Optimization (Week 1-2)
- [ ] Implement separate connection pools for ingestion/API
- [ ] Tune HikariCP settings for multi-facility scenarios
- [ ] Add connection pool monitoring and metrics
- [ ] Load test with current facility count

### Phase 2: Materialized View Optimization (Week 3-4)
- [ ] Implement CONCURRENT refresh strategy
- [ ] Add intelligent refresh scheduling
- [ ] Create MV refresh monitoring dashboard
- [ ] Test MV performance during concurrent ingestion

### Phase 3: Database Architecture (Week 5-8)
- [ ] Implement read/write separation
- [ ] Set up read replica configuration
- [ ] Add connection routing logic
- [ ] Test failover and load balancing

### Phase 4: Advanced Optimization (Week 9-12)
- [ ] Implement facility polling staggering
- [ ] Add batch processing optimization
- [ ] Create comprehensive monitoring dashboard
- [ ] Conduct full-scale load testing

## Future Enhancements (From Original Plan)

### Infrastructure Enhancements
- **Container Separation**: Separate API and ingestion containers for independent scaling
- **Orchestration**: Docker Swarm/Kubernetes deployment manifests
- **Auto-scaling**: Dynamic scaling based on ingestion load
- **Load Balancing**: Intelligent load distribution across instances

### Monitoring and Observability
- **Prometheus/Grafana**: Comprehensive metrics and alerting
- **ELK/Loki Stack**: Centralized log aggregation and analysis
- **APM Integration**: Application performance monitoring
- **Custom Dashboards**: Real-time ingestion and performance metrics

### Security and Compliance
- **SSL/TLS Configuration**: Let's Encrypt integration
- **Network Security**: VPC and security group optimization
- **Audit Logging**: Enhanced security audit trails
- **Compliance Monitoring**: Automated compliance checks

### DevOps and Automation
- **CI/CD Pipeline**: Automated testing and deployment
- **Infrastructure as Code**: Terraform/CloudFormation templates
- **Automated Backups**: Retention policies and disaster recovery
- **Blue-Green Deployments**: Zero-downtime deployment strategy

### Performance Optimization
- **Database Partitioning**: Large table partitioning strategy
- **Caching Layer**: Redis/Memcached for frequently accessed data
- **CDN Integration**: Static asset optimization
- **Query Optimization**: Advanced indexing and query tuning

### Operational Excellence
- **Automated Testing**: Comprehensive test suites
- **Performance Regression Testing**: Automated performance validation
- **Disaster Recovery**: Automated failover and recovery procedures
- **Capacity Planning**: Predictive scaling based on usage patterns

## Success Criteria

### Performance Targets
- **API Response Time**: <2 seconds during peak ingestion
- **Ingestion Throughput**: >1000 claims/minute across all facilities
- **Database Availability**: >99.9% uptime during ingestion operations
- **Resource Utilization**: <80% CPU/memory during normal operations

### Scalability Targets
- **Facility Support**: 100+ facilities without performance degradation
- **Concurrent Users**: 50+ simultaneous API users during ingestion
- **Data Volume**: 1M+ claims processed daily without issues
- **Geographic Distribution**: Multi-region deployment capability

### Monitoring Targets
- **Alert Response**: <5 minutes for critical performance issues
- **Dashboard Availability**: Real-time metrics with <30 second latency
- **Historical Analysis**: 90+ days of performance trend data
- **Proactive Detection**: Automated anomaly detection and alerting

## Risk Mitigation

### Technical Risks
- **Database Lock Contention**: Implement connection pooling and query optimization
- **Resource Exhaustion**: Add monitoring and auto-scaling capabilities
- **Data Consistency**: Implement proper transaction management and rollback strategies
- **Performance Degradation**: Continuous monitoring and performance regression testing

### Operational Risks
- **Deployment Issues**: Blue-green deployment strategy and automated rollback
- **Monitoring Gaps**: Comprehensive monitoring and alerting coverage
- **Capacity Planning**: Predictive scaling and resource planning
- **Disaster Recovery**: Automated backup and recovery procedures

This plan provides a comprehensive approach to optimizing multi-facility ingestion performance while maintaining system reliability and user experience.
