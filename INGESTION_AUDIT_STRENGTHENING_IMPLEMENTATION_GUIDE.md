# Ingestion File Audit Strengthening - Implementation Guide

## ✅ **COMPLETED IMPLEMENTATION**

### **1. Database Schema Enhancements**
- ✅ **SQL Script**: `strengthen_ingestion_file_audit.sql` - Adds all missing core fields
- ✅ **New Fields Added**:
  - Processing timing: `processing_started_at`, `processing_ended_at`, `processing_duration_ms`
  - File metrics: `file_size_bytes`, `processing_mode`, `worker_thread_name`, `retry_count`, `source_file_path`
  - Missing audit fields: `verification_passed`, `ack_attempted`, `ack_sent`, `verification_failed_count`, `projected_events`, `projected_status_rows`
  - Retry tracking: `retry_reasons[]`, `retry_error_codes[]`, `first_attempt_at`, `last_attempt_at`
  - Business metrics: `total_gross_amount`, `total_net_amount`, `total_patient_share`, `unique_payers`, `unique_providers`
- ✅ **Constraints Added**: Data quality constraints for duration, file size, retry count, processing mode
- ✅ **Indexes Added**: Performance indexes for frequently queried fields
- ✅ **Comments Added**: Comprehensive documentation for all new fields

### **2. Enhanced IngestionAudit Service**
- ✅ **New Methods Added**:
  - `fileOkEnhanced()` - Complete audit data with all metrics
  - `fileFailEnhanced()` - Enhanced failure tracking with retry information
  - `trackRetryAttempt()` - Track individual retry attempts
  - Safe versions: `fileOkEnhancedSafely()`, `fileFailEnhancedSafely()`, `trackRetryAttemptSafely()`
- ✅ **Backward Compatibility**: Original methods preserved, new methods are additive
- ✅ **Error Handling**: All new methods have safe versions that never throw exceptions

### **3. Processing Metrics Tracker**
- ✅ **New Class**: `ProcessingMetrics.java` - Comprehensive metrics collection
- ✅ **Features**:
  - Timing tracking for all processing stages
  - File and processing context tracking
  - Business metrics collection (amounts, payer/provider counts)
  - Retry tracking with reasons and error codes
  - Verification and ACK status tracking
  - Utility methods for success/failure/retry detection

## **NEXT STEPS FOR INTEGRATION**

### **Phase 1: Database Setup (Immediate)**
```sql
-- Run the database enhancement script
\i strengthen_ingestion_file_audit.sql
```

### **Phase 2: Code Integration (Week 1)**

#### **A. Update Pipeline.java**
```java
// Add ProcessingMetrics to Pipeline
private final ProcessingMetrics metrics = new ProcessingMetrics();

// In process() method, start tracking
metrics.startProcessing();
metrics.setFileSizeBytes(xmlBytes.length);
metrics.setProcessingMode(wi.sourcePath() != null ? "DISK" : "MEM");
metrics.setSourceFilePath(wi.sourcePath());

// Track parsing
metrics.startParse();
ParseOutcome out = parser.parse(fileRow);
metrics.setParsedClaims(out.getSubmission() != null ? out.getSubmission().claims().size() : 0);
metrics.setParsedActivities(countActs(out.getSubmission()));

// Track validation
metrics.startValidation();
validateSubmission(dto);

// Track persistence
metrics.startPersist();
var counts = persist.persistSubmission(filePk, dto, out.getAttachments());
metrics.setPersistedClaims(counts.claims());
metrics.setPersistedActivities(counts.acts());

// Track verification
metrics.startVerify();
var verification = verifyService.verifyFile(result.ingestionFileId(), fileId);
boolean verified = verification.passed();
metrics.setVerificationPassed(verified);
metrics.setVerificationFailedCount(verification.failedRuleCount());

// End processing
metrics.endProcessing();
```

#### **B. Update Orchestrator.java**
```java
// In processOne() method, use enhanced audit methods
if (currentRunId != null && ingestionFileId != null) {
    if (success) {
        audit.fileOkEnhancedSafely(currentRunId, ingestionFileId, 
            metrics.isVerificationPassed(),
            metrics.getParsedClaims(), metrics.getPersistedClaims(),
            metrics.getParsedActivities(), metrics.getPersistedActivities(),
            metrics.getParsedEncounters(), metrics.getPersistedEncounters(),
            metrics.getParsedDiagnoses(), metrics.getPersistedDiagnoses(),
            metrics.getParsedObservations(), metrics.getPersistedObservations(),
            metrics.getProjectedEvents(), metrics.getProjectedStatusRows(),
            metrics.getProcessingDurationMs(), metrics.getFileSizeBytes(),
            metrics.getProcessingMode(), metrics.getWorkerThreadName(),
            metrics.getTotalGrossAmount(), metrics.getTotalNetAmount(),
            metrics.getTotalPatientShare(),
            metrics.getUniquePayers(), metrics.getUniqueProviders(),
            metrics.isAckAttempted(), metrics.isAckSent(),
            metrics.getVerificationFailedCount());
    } else {
        audit.fileFailEnhancedSafely(currentRunId, ingestionFileId,
            ex.getClass().getSimpleName(), ex.getMessage(),
            metrics.getProcessingDurationMs(), metrics.getFileSizeBytes(),
            metrics.getProcessingMode(), metrics.getWorkerThreadName(),
            metrics.getRetryCount(), metrics.getRetryReasons(), metrics.getRetryErrorCodes(),
            metrics.getFirstAttemptAt(), metrics.getLastAttemptAt());
    }
}
```

### **Phase 3: Retry Integration (Week 2)**

#### **A. Add Retry Tracking to Error Handling**
```java
// In Pipeline.java, when errors occur
catch (Exception ex) {
    metrics.setError(ex.getClass().getSimpleName(), ex.getMessage());
    metrics.incrementRetryCount();
    metrics.addRetryReason("PIPELINE_ERROR");
    metrics.addRetryErrorCode("PIPELINE_FAIL");
    
    // Track retry attempt in audit
    audit.trackRetryAttemptSafely(filePk, "PIPELINE_ERROR", "PIPELINE_FAIL");
    
    throw ex;
}
```

#### **B. Add Retry Logic to Orchestrator**
```java
// In processOne() method, implement retry logic
private void processOne(WorkItem wi) {
    final String fileId = wi.fileId();
    final Long currentRunId = RunContext.getCurrentRunId();
    
    // Check if this is a retry
    int retryCount = getRetryCountForFile(fileId);
    ProcessingMetrics metrics = new ProcessingMetrics();
    
    if (retryCount > 0) {
        metrics.incrementRetryCount();
        metrics.addRetryReason("ORCHESTRATOR_RETRY");
        metrics.addRetryErrorCode("PREVIOUS_FAILURE");
    }
    
    // ... existing processing logic with metrics tracking
}
```

### **Phase 4: Business Metrics Collection (Week 3)**

#### **A. Add Business Metrics to PersistService**
```java
// In persistSubmission() method
for (SubmissionClaimDTO c : file.claims()) {
    // Track business metrics
    metrics.addGrossAmount(c.gross());
    metrics.addNetAmount(c.net());
    metrics.addPatientShare(c.patientShare());
    metrics.addPayer(c.payerId());
    metrics.addProvider(c.providerId());
    
    // ... existing persistence logic
}
```

#### **B. Add Event Projection Tracking**
```java
// After event projection
int projectedEvents = countProjectedEvents(filePk);
int projectedStatusRows = countProjectedStatusRows(filePk);
metrics.setProjectedEvents(projectedEvents);
metrics.setProjectedStatusRows(projectedStatusRows);
```

## **VALIDATION AND TESTING**

### **1. Database Validation**
```sql
-- Verify all new fields exist
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_schema = 'claims' 
  AND table_name = 'ingestion_file_audit'
  AND column_name IN (
    'processing_started_at', 'processing_ended_at', 'processing_duration_ms',
    'file_size_bytes', 'processing_mode', 'worker_thread_name', 'retry_count',
    'verification_passed', 'ack_attempted', 'ack_sent',
    'total_gross_amount', 'total_net_amount', 'total_patient_share'
  );

-- Check data population
SELECT 
    COUNT(*) as total_audits,
    COUNT(processing_duration_ms) as has_duration,
    COUNT(file_size_bytes) as has_file_size,
    COUNT(verification_passed) as has_verification,
    COUNT(retry_count) as has_retry_count,
    AVG(processing_duration_ms) as avg_duration_ms
FROM claims.ingestion_file_audit 
WHERE created_at > NOW() - INTERVAL '24 hours';
```

### **2. Performance Validation**
```sql
-- Check processing performance
SELECT 
    processing_mode,
    AVG(processing_duration_ms) as avg_duration_ms,
    AVG(file_size_bytes) as avg_file_size_bytes,
    COUNT(*) as file_count
FROM claims.ingestion_file_audit 
WHERE processing_duration_ms IS NOT NULL 
  AND created_at > NOW() - INTERVAL '24 hours'
GROUP BY processing_mode;
```

### **3. Retry Analysis**
```sql
-- Analyze retry patterns
SELECT 
    retry_count,
    COUNT(*) as file_count,
    AVG(processing_duration_ms) as avg_duration_ms,
    array_agg(DISTINCT unnest(retry_reasons)) as common_reasons
FROM claims.ingestion_file_audit 
WHERE retry_count > 0
  AND created_at > NOW() - INTERVAL '24 hours'
GROUP BY retry_count
ORDER BY retry_count;
```

## **MONITORING AND ALERTING**

### **1. Key Metrics to Monitor**
- Processing duration trends (should be < 5 seconds average)
- File size trends (identify unusually large files)
- Retry rate (should be < 1%)
- Verification pass rate (should be > 99%)
- ACK success rate (should be > 95%)

### **2. Alert Conditions**
- Processing duration > 60 seconds
- Retry count > 3 for any file
- Verification pass rate < 95%
- Missing audit records for processed files
- File size > 100MB (configurable threshold)

### **3. Dashboard Queries**
```sql
-- Processing performance dashboard
SELECT 
    date_trunc('hour', created_at) as hour_bucket,
    COUNT(*) as files_processed,
    AVG(processing_duration_ms) as avg_duration_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY processing_duration_ms) as p95_duration_ms,
    AVG(file_size_bytes) as avg_file_size_bytes,
    SUM(retry_count) as total_retries,
    COUNT(CASE WHEN verification_passed THEN 1 END) as verified_files,
    COUNT(CASE WHEN ack_sent THEN 1 END) as acked_files
FROM claims.ingestion_file_audit 
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY hour_bucket
ORDER BY hour_bucket DESC;
```

## **ROLLBACK PLAN**

### **Immediate Rollback**
```sql
-- Disable enhanced audit methods by setting feature flag
UPDATE claims.integration_toggle 
SET enabled = false 
WHERE code = 'ingestion.audit.enhanced';
```

### **Code Rollback**
- Revert to original `fileOk()`, `fileFail()`, `fileAlready()` methods
- Remove `ProcessingMetrics` usage
- Keep database schema changes (they're additive and don't break existing functionality)

### **Database Rollback**
- Use the rollback script in `strengthen_ingestion_file_audit.sql`
- All changes are additive, so rollback is safe

## **SUCCESS CRITERIA**

### **Functional Requirements**
- ✅ All new fields populated in `ingestion_file_audit`
- ✅ Retry tracking working for failed files
- ✅ Business metrics collected (amounts, payer/provider counts)
- ✅ Processing timing captured accurately
- ✅ Verification and ACK status tracked

### **Performance Requirements**
- ✅ No performance degradation in ingestion processing
- ✅ Audit operations complete in < 100ms
- ✅ Database queries optimized with proper indexes

### **Data Quality Requirements**
- ✅ 100% of processed files have audit records
- ✅ 95% of audit records have complete data
- ✅ Zero orphaned or inconsistent audit records
- ✅ Retry tracking accurate and complete

This implementation provides a comprehensive audit trail while maintaining backward compatibility and ensuring no disruption to existing ingestion processing.
