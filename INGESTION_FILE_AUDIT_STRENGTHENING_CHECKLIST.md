# Ingestion File Audit Strengthening Checklist

## Current State Analysis

### ✅ **What's Currently Working**
- Basic audit structure exists with proper foreign keys
- Status tracking (0=ALREADY, 1=OK, 2=FAIL)
- Header information capture
- Parsed vs persisted entity counts
- Error logging capabilities
- Unique constraint prevents duplicate audits per run/file

### ❌ **Critical Gaps Identified**

## 1. **MISSING CORE FIELDS**

### 1.1 **Timing & Performance Metrics**
- ❌ **Processing Duration**: No start/end timestamps for individual file processing
- ❌ **Stage Timings**: No breakdown of time spent in parse/validate/persist/verify stages
- ❌ **File Size**: No record of XML file size (affects performance analysis)
- ❌ **Memory Usage**: No tracking of memory consumption during processing

### 1.2 **Processing Context**
- ❌ **Processing Mode**: MEM vs DISK staging not recorded
- ❌ **Worker Thread**: Which thread processed the file
- ❌ **Retry Count**: How many times file was retried
- ❌ **Source Path**: For disk-staged files, the actual file path

### 1.3 **Business Metrics**
- ❌ **Financial Amounts**: No gross/net/patient share amounts
- ❌ **Payer Distribution**: No breakdown by payer
- ❌ **Provider Distribution**: No breakdown by provider
- ❌ **Claim Types**: No categorization of claim types

## 2. **INCOMPLETE DATA POPULATION**

### 2.1 **Currently Missing in Code**
- ❌ **parsed_encounters**: Not populated
- ❌ **parsed_diagnoses**: Not populated  
- ❌ **parsed_observations**: Not populated
- ❌ **persisted_encounters**: Not populated
- ❌ **persisted_diagnoses**: Not populated
- ❌ **persisted_observations**: Not populated
- ❌ **projected_events**: Not populated
- ❌ **projected_status_rows**: Not populated
- ❌ **verification_failed_count**: Not populated
- ❌ **ack_attempted**: Not populated
- ❌ **ack_sent**: Not populated

### 2.2 **Inconsistent Population**
- ⚠️ **parsed_remit_activities**: Inconsistent population
- ⚠️ **persisted_remit_activities**: Missing from current DDL
- ⚠️ **verification_passed**: Field exists but not consistently used

## 3. **DATA QUALITY ISSUES**

### 3.1 **Validation Problems**
- ❌ **Header Validation**: No validation that header fields match actual data
- ❌ **Count Validation**: No validation that parsed counts match persisted counts
- ❌ **Business Rule Validation**: No tracking of business rule violations
- ❌ **Data Integrity Checks**: No validation of referential integrity

### 3.2 **Error Classification**
- ❌ **Error Categories**: No standardized error categorization
- ❌ **Retryable Flag**: No indication if error is retryable
- ❌ **Error Severity**: No severity level classification
- ❌ **Error Context**: Limited context for debugging

## 4. **MISSING OPERATIONAL FIELDS**

### 4.1 **Monitoring & Alerting**
- ❌ **Alert Thresholds**: No fields for alerting configuration
- ❌ **Processing Priority**: No priority classification
- ❌ **Resource Usage**: No CPU/memory/disk usage tracking
- ❌ **Network Metrics**: No network transfer metrics

### 4.2 **Compliance & Audit**
- ❌ **Data Classification**: No sensitivity/classification level
- ❌ **Compliance Flags**: No regulatory compliance indicators
- ❌ **Audit Trail**: No detailed audit trail of changes
- ❌ **Data Retention**: No retention policy indicators

## 5. **PERFORMANCE & SCALABILITY ISSUES**

### 5.1 **Indexing Gaps**
- ❌ **Missing Indexes**: No indexes on frequently queried fields
- ❌ **Composite Indexes**: No composite indexes for common query patterns
- ❌ **Partial Indexes**: No partial indexes for active records

### 5.2 **Partitioning & Archival**
- ❌ **No Partitioning**: Table not partitioned by date
- ❌ **No Archival Strategy**: No automatic archival of old records
- ❌ **No Compression**: No compression for historical data

## 6. **INTEGRATION GAPS**

### 6.1 **External System Integration**
- ❌ **SOAP Metrics**: No SOAP call metrics (latency, retries)
- ❌ **Database Metrics**: No database performance metrics
- ❌ **File System Metrics**: No file system operation metrics
- ❌ **Network Metrics**: No network transfer metrics

### 6.2 **Monitoring Integration**
- ❌ **Metrics Export**: No integration with monitoring systems
- ❌ **Alert Integration**: No integration with alerting systems
- ❌ **Dashboard Integration**: No integration with dashboards
- ❌ **Log Integration**: No structured log integration

## 7. **RECOMMENDED ENHANCEMENTS**

### 7.1 **Immediate Fixes (High Priority)**

#### A. Add Missing Core Fields
```sql
ALTER TABLE claims.ingestion_file_audit ADD COLUMN IF NOT EXISTS
  processing_started_at        TIMESTAMPTZ,
  processing_ended_at          TIMESTAMPTZ,
  processing_duration_ms       INTEGER,
  file_size_bytes              BIGINT,
  processing_mode              TEXT, -- 'MEM' or 'DISK'
  worker_thread_name           TEXT,
  retry_count                  INTEGER DEFAULT 0,
  source_file_path             TEXT,
  verification_passed          BOOLEAN DEFAULT FALSE,
  ack_attempted                BOOLEAN DEFAULT FALSE,
  ack_sent                     BOOLEAN DEFAULT FALSE,
  verification_failed_count    INTEGER DEFAULT 0,
  projected_events             INTEGER DEFAULT 0,
  projected_status_rows        INTEGER DEFAULT 0;
```

#### B. Add Business Metrics
```sql
ALTER TABLE claims.ingestion_file_audit ADD COLUMN IF NOT EXISTS
  total_gross_amount           NUMERIC(15,2) DEFAULT 0,
  total_net_amount             NUMERIC(15,2) DEFAULT 0,
  total_patient_share          NUMERIC(15,2) DEFAULT 0,
  unique_payers                INTEGER DEFAULT 0,
  unique_providers             INTEGER DEFAULT 0,
  claim_types                  TEXT[], -- Array of claim types
  error_categories             TEXT[], -- Array of error categories
  retryable_errors             INTEGER DEFAULT 0,
  non_retryable_errors         INTEGER DEFAULT 0;
```

#### C. Add Performance Metrics
```sql
ALTER TABLE claims.ingestion_file_audit ADD COLUMN IF NOT EXISTS
  parse_duration_ms            INTEGER,
  validation_duration_ms       INTEGER,
  persist_duration_ms          INTEGER,
  verify_duration_ms           INTEGER,
  memory_used_mb               INTEGER,
  cpu_time_ms                  INTEGER,
  disk_io_operations           INTEGER,
  network_transfer_bytes       BIGINT;
```

### 7.2 **Code Enhancements (Medium Priority)**

#### A. Update IngestionAudit Methods
```java
// Enhanced fileOk method with all metrics
public void fileOk(long runId, long ingestionFileId, boolean verified, 
                   int parsedClaims, int persistedClaims, int parsedActs, int persistedActs,
                   int parsedEncounters, int persistedEncounters,
                   int parsedDiagnoses, int persistedDiagnoses,
                   int parsedObservations, int persistedObservations,
                   int projectedEvents, int projectedStatusRows,
                   long processingDurationMs, long fileSizeBytes,
                   String processingMode, String workerThread,
                   BigDecimal totalGross, BigDecimal totalNet, BigDecimal totalPatientShare,
                   int uniquePayers, int uniqueProviders, String[] claimTypes,
                   boolean ackAttempted, boolean ackSent);
```

#### B. Add Stage Timing Tracking
```java
public class ProcessingMetrics {
    private long parseStartTime;
    private long validationStartTime;
    private long persistStartTime;
    private long verifyStartTime;
    private long memoryStartUsage;
    // ... timing and resource tracking methods
}
```

### 7.3 **Database Enhancements (Medium Priority)**

#### A. Add Missing Indexes
```sql
CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_processing_time 
ON claims.ingestion_file_audit(processing_started_at);

CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_duration 
ON claims.ingestion_file_audit(processing_duration_ms);

CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_file_size 
ON claims.ingestion_file_audit(file_size_bytes);

CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_status_created 
ON claims.ingestion_file_audit(status, created_at);

CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_verification 
ON claims.ingestion_file_audit(verification_passed, validation_ok);
```

#### B. Add Constraints
```sql
ALTER TABLE claims.ingestion_file_audit ADD CONSTRAINT 
ck_processing_duration CHECK (processing_duration_ms >= 0);

ALTER TABLE claims.ingestion_file_audit ADD CONSTRAINT 
ck_file_size CHECK (file_size_bytes >= 0);

ALTER TABLE claims.ingestion_file_audit ADD CONSTRAINT 
ck_retry_count CHECK (retry_count >= 0);
```

### 7.4 **Advanced Features (Low Priority)**

#### A. Partitioning Strategy
```sql
-- Partition by month for better performance
CREATE TABLE claims.ingestion_file_audit_partitioned (
    LIKE claims.ingestion_file_audit INCLUDING ALL
) PARTITION BY RANGE (created_at);

-- Create monthly partitions
CREATE TABLE claims.ingestion_file_audit_2024_01 
PARTITION OF claims.ingestion_file_audit_partitioned
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

#### B. Archival Strategy
```sql
-- Create archival table for old records
CREATE TABLE claims.ingestion_file_audit_archive (
    LIKE claims.ingestion_file_audit INCLUDING ALL
);

-- Archival procedure
CREATE OR REPLACE FUNCTION archive_old_audit_records()
RETURNS void AS $$
BEGIN
    INSERT INTO claims.ingestion_file_audit_archive
    SELECT * FROM claims.ingestion_file_audit
    WHERE created_at < NOW() - INTERVAL '6 months';
    
    DELETE FROM claims.ingestion_file_audit
    WHERE created_at < NOW() - INTERVAL '6 months';
END;
$$ LANGUAGE plpgsql;
```

## 8. **IMPLEMENTATION PRIORITY MATRIX**

### **Phase 1: Critical Fixes (Week 1)**
1. ✅ Add missing core fields (timing, file size, processing mode)
2. ✅ Populate all existing parsed/persisted counters
3. ✅ Add verification and ACK tracking
4. ✅ Add basic performance metrics

### **Phase 2: Data Quality (Week 2)**
1. ✅ Add business metrics (amounts, payer/provider counts)
2. ✅ Add error categorization and retry tracking
3. ✅ Add validation and integrity checks
4. ✅ Add missing indexes

### **Phase 3: Advanced Features (Week 3-4)**
1. ✅ Add detailed stage timing
2. ✅ Add resource usage tracking
3. ✅ Add partitioning strategy
4. ✅ Add archival procedures

### **Phase 4: Integration (Week 5-6)**
1. ✅ Add monitoring integration
2. ✅ Add alerting integration
3. ✅ Add dashboard integration
4. ✅ Add compliance features

## 9. **VALIDATION QUERIES**

### **Data Completeness Check**
```sql
-- Check for missing data in recent audits
SELECT 
    COUNT(*) as total_audits,
    COUNT(processing_started_at) as has_start_time,
    COUNT(processing_ended_at) as has_end_time,
    COUNT(processing_duration_ms) as has_duration,
    COUNT(file_size_bytes) as has_file_size,
    COUNT(verification_passed) as has_verification,
    COUNT(ack_attempted) as has_ack_attempted,
    COUNT(ack_sent) as has_ack_sent
FROM claims.ingestion_file_audit 
WHERE created_at > NOW() - INTERVAL '24 hours';
```

### **Performance Analysis**
```sql
-- Analyze processing performance
SELECT 
    AVG(processing_duration_ms) as avg_duration_ms,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY processing_duration_ms) as median_duration_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY processing_duration_ms) as p95_duration_ms,
    AVG(file_size_bytes) as avg_file_size_bytes,
    COUNT(*) as total_files
FROM claims.ingestion_file_audit 
WHERE processing_duration_ms IS NOT NULL 
  AND created_at > NOW() - INTERVAL '24 hours';
```

### **Error Analysis**
```sql
-- Analyze error patterns
SELECT 
    error_class,
    COUNT(*) as error_count,
    AVG(retry_count) as avg_retries,
    COUNT(CASE WHEN retryable_errors > 0 THEN 1 END) as retryable_count,
    COUNT(CASE WHEN non_retryable_errors > 0 THEN 1 END) as non_retryable_count
FROM claims.ingestion_file_audit 
WHERE status = 2 -- FAIL
  AND created_at > NOW() - INTERVAL '24 hours'
GROUP BY error_class
ORDER BY error_count DESC;
```

## 10. **SUCCESS CRITERIA**

### **Completeness Metrics**
- ✅ 100% of files have processing timestamps
- ✅ 100% of files have file size recorded
- ✅ 100% of files have verification status
- ✅ 100% of files have ACK status
- ✅ 95% of files have complete parsed/persisted counts

### **Performance Metrics**
- ✅ Average processing time < 5 seconds
- ✅ 95th percentile processing time < 30 seconds
- ✅ Error rate < 1%
- ✅ Verification pass rate > 99%

### **Data Quality Metrics**
- ✅ Zero orphaned audit records
- ✅ Zero inconsistent count data
- ✅ Zero missing required fields
- ✅ 100% referential integrity

## 11. **MONITORING & ALERTING**

### **Key Metrics to Monitor**
- Processing duration trends
- Error rate trends
- File size trends
- Verification pass rate
- ACK success rate
- Resource usage trends

### **Alert Conditions**
- Processing duration > 60 seconds
- Error rate > 5%
- Verification pass rate < 95%
- ACK success rate < 90%
- Missing audit records for processed files

This comprehensive checklist provides a roadmap for strengthening the `ingestion_file_audit` table to provide complete visibility into the ingestion process while maintaining performance and data quality.
