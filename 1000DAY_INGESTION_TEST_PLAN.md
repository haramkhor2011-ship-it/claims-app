# 1000-DAY INGESTION TEST - EXECUTION PLAN

## 🎯 OBJECTIVE
Test the ingestion system with 1000 days of data to verify:
- System performance under high load
- Verification service functionality
- Database integrity and consistency
- Error handling and recovery

## 📋 PREPARATION CHECKLIST

### ✅ Step 1: Database Cleanup
```powershell
# Run the comprehensive cleanup script
.\execute_cleanup_1000day.ps1
```

**What it does:**
- Backs up recent data (optional)
- Cleans all core tables (submissions, claims, events, etc.)
- Cleans ingestion tracking tables
- Resets database statistics
- Verifies cleanup completion

### ✅ Step 2: Configuration Verification
- ✅ Created `application-prod-1000day.yml` with optimized settings
- ✅ Database connection pool: 20 max connections
- ✅ Thread pool: 8 core, 16 max workers
- ✅ Queue capacity: 2000 files
- ✅ SOAP timeout: 45 seconds
- ✅ Search days: 1000 days

### ✅ Step 3: Monitoring Setup
- ✅ Created monitoring SQL script
- ✅ Created PowerShell monitoring script
- ✅ Real-time progress tracking
- ✅ Performance metrics collection

## 🚀 EXECUTION STEPS

### Step 1: Start Database
```powershell
docker-compose up -d
```

### Step 2: Run Cleanup
```powershell
.\execute_cleanup_1000day.ps1
```
**Expected Output:**
- All tables cleaned
- Verification shows 0 records
- Database ready for fresh ingestion

### Step 3: Start Ingestion
```powershell
mvn spring-boot:run -Dspring-boot.run.profiles=prod-1000day
```

### Step 4: Monitor Progress
```powershell
# Single monitoring run
.\monitor_1000day_ingestion.ps1

# Continuous monitoring (every 30 seconds)
.\monitor_1000day_ingestion.ps1 -Continuous

# Custom interval (every 60 seconds)
.\monitor_1000day_ingestion.ps1 -Continuous -IntervalSeconds 60
```

## 📊 EXPECTED METRICS

### Performance Targets
- **Files per minute**: 50-100 files/minute
- **Average processing time**: 2-5 seconds per file
- **Success rate**: >95%
- **Verification success rate**: >98%

### Resource Usage
- **Memory**: 4-6GB (out of 8GB available)
- **CPU**: 60-80% utilization
- **Database connections**: 10-15 active

## 🔍 MONITORING CHECKPOINTS

### Every 30 Minutes
1. **Overall Status**
   - Files processed vs total
   - Success rate
   - Error rate

2. **Performance Metrics**
   - Average processing time
   - Files per minute
   - Memory usage

3. **Data Integrity**
   - Verification success rate
   - Orphaned records check
   - Referential integrity

### Every 2 Hours
1. **Error Analysis**
   - Top error reasons
   - Failed file patterns
   - Recovery actions needed

2. **Resource Monitoring**
   - Database connection usage
   - Thread pool utilization
   - Queue capacity

## 🚨 TROUBLESHOOTING

### Common Issues

#### Issue: High Memory Usage
**Symptoms:** Application slows down, OutOfMemoryError
**Solutions:**
- Reduce `max-pool-size` to 12
- Reduce `queue-capacity` to 1000
- Increase `fixedDelayMs` to 2000

#### Issue: Database Connection Exhaustion
**Symptoms:** Connection timeout errors
**Solutions:**
- Reduce `maximum-pool-size` to 15
- Increase `connection-timeout` to 60000
- Check for connection leaks

#### Issue: Verification Failures
**Symptoms:** Files moving to error directory
**Solutions:**
- Check transaction isolation settings
- Verify database constraints
- Review verification logs

#### Issue: SOAP API Timeouts
**Symptoms:** Download failures, network errors
**Solutions:**
- Increase `read-timeout-ms` to 60000
- Reduce `downloadConcurrency` to 12
- Check network connectivity

## 📈 SUCCESS CRITERIA

### Primary Goals
- ✅ **Complete 1000-day ingestion** without manual intervention
- ✅ **Maintain >95% success rate** throughout the process
- ✅ **Verification passes** for all successfully processed files
- ✅ **No data corruption** or orphaned records

### Secondary Goals
- ✅ **Performance within targets** (50-100 files/minute)
- ✅ **Resource usage stable** (no memory leaks)
- ✅ **Error recovery** works automatically
- ✅ **Monitoring provides** real-time insights

## 📝 POST-TEST ANALYSIS

### Data Verification
```sql
-- Run comprehensive verification
SELECT 
    COUNT(*) as total_files,
    COUNT(CASE WHEN status = 1 THEN 1 END) as successful,
    COUNT(CASE WHEN status = 3 THEN 1 END) as failed,
    ROUND(COUNT(CASE WHEN status = 1 THEN 1 END) * 100.0 / COUNT(*), 2) as success_rate
FROM claims.ingestion_file_audit;
```

### Performance Analysis
```sql
-- Analyze processing times
SELECT 
    AVG(duration_ms) as avg_duration,
    MIN(duration_ms) as min_duration,
    MAX(duration_ms) as max_duration,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95_duration
FROM claims.ingestion_file_audit
WHERE status = 1 AND duration_ms IS NOT NULL;
```

### Data Volume Analysis
```sql
-- Check total data ingested
SELECT 
    COUNT(DISTINCT s.id) as submissions,
    COUNT(DISTINCT c.id) as claims,
    COUNT(DISTINCT ce.id) as claim_events,
    COUNT(DISTINCT r.id) as remittances
FROM claims.submission s
LEFT JOIN claims.claim c ON s.id = c.submission_id
LEFT JOIN claims.claim_event ce ON c.claim_key_id = ce.claim_key_id
LEFT JOIN claims.remittance r ON s.ingestion_file_id = r.ingestion_file_id;
```

## 🎉 COMPLETION CHECKLIST

- [ ] All 1000 days of data ingested
- [ ] Success rate >95%
- [ ] Verification success rate >98%
- [ ] No critical errors in logs
- [ ] Database integrity verified
- [ ] Performance metrics within targets
- [ ] Resource usage stable
- [ ] Monitoring data collected
- [ ] Post-test analysis completed

---

**Ready to execute the 1000-day ingestion test!** 🚀
