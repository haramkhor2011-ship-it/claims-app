# Ingestion Performance Report: 1000 Days Historical Data

## System Configuration
- **Machine**: [Laptop/Server - Dell XPS/AWS EC2/etc]
- **CPU**: [cores/threads]
- **RAM**: [GB]
- **Database**: PostgreSQL [version], pool size: [50]
- **JVM**: -Xmx[4G] -Xms[2G], GC: [G1GC/ZGC]
- **Workers**: parser-workers=[16], executor threads=[32]

## Data Volume
- **Total Files**: [X]
- **Total Claims (Submission)**: [X]
- **Total Claims (Remittance)**: [X]
- **Total Activities**: [X]
- **Date Range**: [YYYY-MM-DD] to [YYYY-MM-DD]
- **Total Data Size**: [GB]

## Performance Metrics
- **Total Duration**: [X] hours [Y] minutes
- **Throughput**: [X] files/minute, [Y] claims/second
- **Average Processing Time**: [X] ms/file
- **Peak Processing Time**: [X] ms/file
- **Slowest File**: [filename], [duration]ms

## Data Quality Metrics
- **Parse Success Rate**: [X]% ([successful]/[total])
- **Persistence Success Rate**: [X]% 
- **Verification Pass Rate**: [X]%
- **Parsed vs Persisted Match**: [X]% (claims), [Y]% (activities)

## Verification Results
- **Total Verified**: [X] files
- **Passed**: [X] files
- **Failed**: [X] files
- **Common Failure Reasons**:
  - [Reason 1]: [count]
  - [Reason 2]: [count]

## Issues Encountered
1. [Issue description] - [impact] - [resolution]
2. ...

## System Behavior
- **Memory Usage**: Peak [X]GB, Average [Y]GB
- **CPU Usage**: Peak [X]%, Average [Y]%
- **Database Connections**: Peak [X], Average [Y]
- **Queue Backlog**: Max size [X], times saturated [Y]

## Recommendations
1. [Recommendation based on findings]
2. ...

## Run Query
```sql
-- Use monitor_ingestion_performance.sql to generate these metrics
```
