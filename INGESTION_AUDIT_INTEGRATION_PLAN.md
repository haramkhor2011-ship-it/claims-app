# Ingestion Audit Integration Plan

## Executive Summary

This plan integrates the existing but unused `IngestionAudit` service into the ingestion pipeline to provide comprehensive tracking of ingestion runs and file processing outcomes. The integration will enable the `v_ingestion_kpis` view to function properly and provide complete auditability.

## Current State Analysis

### ✅ What's Working
- **Database Tables**: `ingestion_run`, `ingestion_file_audit`, `ingestion_error` tables exist with proper structure
- **Error Logging**: `ErrorLogger` service properly logs errors to `ingestion_error` table
- **KPI View**: `v_ingestion_kpis` view is defined and ready to consume audit data
- **IngestionAudit Service**: Complete service with all necessary methods exists

### ❌ What's Missing
- **No Run Tracking**: No ingestion run records are created
- **No File Audit**: No file processing outcomes are tracked
- **No KPI Data**: `v_ingestion_kpis` view returns empty results
- **No Integration**: `IngestionAudit` service is never called

## Integration Strategy

### 1. Run-Level Tracking
**Integration Point**: `Orchestrator.drain()` method
- **Start Run**: Create ingestion run record at the beginning of each drain cycle
- **End Run**: Update run record when drain cycle completes
- **Error Handling**: Ensure run is closed even if drain cycle fails

### 2. File-Level Tracking  
**Integration Point**: `Orchestrator.processOne()` method
- **File Success**: Call `fileOk()` after successful processing
- **File Failure**: Call `fileFail()` when processing fails
- **File Already Processed**: Call `fileAlready()` for duplicate files

### 3. Error Isolation Strategy
- **Non-Blocking**: Audit failures should never stop ingestion
- **Graceful Degradation**: Continue processing even if audit logging fails
- **Comprehensive Logging**: Log all audit failures for debugging

## Detailed Implementation Plan

### Phase 1: Enhanced IngestionAudit Service

#### 1.1 Add Error Handling to IngestionAudit
```java
@Service
public class IngestionAudit {
    private static final Logger log = LoggerFactory.getLogger(IngestionAudit.class);
    
    // Add try-catch blocks to all methods
    // Log errors but don't throw exceptions
    // Return success/failure status
}
```

#### 1.2 Add Run State Management
```java
// Add methods for run state tracking
public boolean startRunSafely(String profile, String fetcher, String acker, String reason)
public boolean endRunSafely(long runId)
public boolean fileOkSafely(long runId, long ingestionFileId, ...)
```

### Phase 2: Orchestrator Integration

#### 2.1 Add IngestionAudit Dependency
```java
@Component
@Profile("ingestion")
public class Orchestrator {
    private final IngestionAudit audit;
    
    public Orchestrator(..., IngestionAudit audit) {
        this.audit = audit;
    }
}
```

#### 2.2 Modify drain() Method
```java
@Scheduled(initialDelayString = "0", fixedDelayString = "${claims.ingestion.poll.fixedDelayMs}")
public void drain() {
    Long runId = null;
    try {
        // Start ingestion run
        runId = audit.startRunSafely(
            props.getProfile(), 
            fetcher.getClass().getSimpleName(),
            acker != null ? acker.getClass().getSimpleName() : "NoopAcker",
            "SCHEDULED_DRAIN"
        );
        
        // Existing drain logic...
        
    } finally {
        // Always end the run
        if (runId != null) {
            audit.endRunSafely(runId);
        }
    }
}
```

#### 2.3 Modify processOne() Method
```java
private void processOne(WorkItem wi) {
    final String fileId = wi.fileId();
    Long currentRunId = getCurrentRunId(); // Thread-local or context
    
    // Existing duplicate check...
    
    boolean success = false;
    long t0 = System.nanoTime();
    try {
        // Existing processing logic...
        var result = pipeline.process(wi);
        var verification = verifyService.verifyFile(result.ingestionFileId(), fileId);
        boolean verified = verification.passed();
        success = verified;
        
        // Audit successful processing
        if (currentRunId != null) {
            audit.fileOkSafely(currentRunId, result.ingestionFileId(), 
                verified, result.parsedClaims(), result.persistedClaims(),
                result.parsedActivities(), result.persistedActivities());
        }
        
    } catch (Exception ex) {
        // Audit failed processing
        if (currentRunId != null && filePk != null) {
            audit.fileFailSafely(currentRunId, filePk, 
                ex.getClass().getSimpleName(), ex.getMessage());
        }
        throw ex;
    } finally {
        // Existing cleanup...
    }
}
```

### Phase 3: Run Context Management

#### 3.1 Thread-Local Run Context
```java
public class RunContext {
    private static final ThreadLocal<Long> currentRunId = new ThreadLocal<>();
    
    public static void setCurrentRunId(Long runId) {
        currentRunId.set(runId);
    }
    
    public static Long getCurrentRunId() {
        return currentRunId.get();
    }
    
    public static void clear() {
        currentRunId.remove();
    }
}
```

#### 3.2 Integration with drain() Method
```java
public void drain() {
    Long runId = null;
    try {
        runId = audit.startRunSafely(...);
        RunContext.setCurrentRunId(runId);
        
        // Process files...
        
    } finally {
        RunContext.clear();
        if (runId != null) {
            audit.endRunSafely(runId);
        }
    }
}
```

### Phase 4: Enhanced Error Handling

#### 4.1 Safe Audit Methods
```java
@Service
public class IngestionAudit {
    
    public Long startRunSafely(String profile, String fetcher, String acker, String reason) {
        try {
            return startRun(profile, fetcher, acker, reason);
        } catch (Exception e) {
            log.error("Failed to start ingestion run: profile={}, fetcher={}, acker={}, reason={}", 
                profile, fetcher, acker, reason, e);
            return null;
        }
    }
    
    public boolean endRunSafely(Long runId) {
        if (runId == null) return false;
        try {
            endRun(runId);
            return true;
        } catch (Exception e) {
            log.error("Failed to end ingestion run: runId={}", runId, e);
            return false;
        }
    }
    
    public boolean fileOkSafely(Long runId, Long ingestionFileId, boolean verified, 
                               int parsedClaims, int persistedClaims, 
                               int parsedActs, int persistedActs) {
        if (runId == null || ingestionFileId == null) return false;
        try {
            fileOk(runId, ingestionFileId, verified, parsedClaims, persistedClaims, 
                   parsedActs, persistedActs);
            return true;
        } catch (Exception e) {
            log.error("Failed to audit file success: runId={}, fileId={}", 
                runId, ingestionFileId, e);
            return false;
        }
    }
    
    public boolean fileFailSafely(Long runId, Long ingestionFileId, String errorClass, String message) {
        if (runId == null || ingestionFileId == null) return false;
        try {
            fileFail(runId, ingestionFileId, errorClass, message);
            return true;
        } catch (Exception e) {
            log.error("Failed to audit file failure: runId={}, fileId={}", 
                runId, ingestionFileId, e);
            return false;
        }
    }
}
```

### Phase 5: Configuration and Profiles

#### 5.1 Add Audit Configuration
```yaml
claims:
  ingestion:
    audit:
      enabled: true
      run-tracking: true
      file-tracking: true
      error-isolation: true
```

#### 5.2 Profile-Specific Behavior
- **`ingestion` profile**: Full audit tracking enabled
- **`api` profile**: No audit tracking (read-only)
- **`adminjobs` profile**: No audit tracking (batch operations)

## Error Handling Strategy

### 1. Non-Blocking Design
- Audit failures never stop ingestion processing
- All audit operations wrapped in try-catch blocks
- Graceful degradation when audit service is unavailable

### 2. Comprehensive Logging
- All audit failures logged with full context
- Structured logging for easy debugging
- Error metrics for monitoring audit service health

### 3. Fallback Mechanisms
- Default values when audit data is unavailable
- KPI view handles missing audit data gracefully
- Manual audit data correction capabilities

## Testing Strategy

### 1. Unit Tests
- Test all audit methods with success and failure scenarios
- Test error isolation and graceful degradation
- Test thread-local context management

### 2. Integration Tests
- Test complete ingestion flow with audit tracking
- Test KPI view with real audit data
- Test error scenarios and recovery

### 3. Performance Tests
- Measure impact of audit operations on ingestion performance
- Test under high load conditions
- Validate no performance degradation

## Monitoring and Observability

### 1. Metrics
- Audit operation success/failure rates
- Ingestion run duration and file counts
- KPI view data freshness and completeness

### 2. Alerts
- Audit service failures
- Missing ingestion run data
- KPI view returning empty results

### 3. Dashboards
- Ingestion run metrics
- File processing success rates
- Audit service health

## Rollback Plan

### 1. Feature Toggle
- Add configuration flag to disable audit tracking
- Immediate rollback capability without code changes
- Gradual rollout with monitoring

### 2. Database Rollback
- Audit tables are additive (no existing data affected)
- Can disable audit without data loss
- KPI view remains functional with existing data

### 3. Code Rollback
- Minimal changes to existing ingestion flow
- Easy to revert if issues arise
- Backward compatibility maintained

## Success Criteria

### 1. Functional Requirements
- ✅ All ingestion runs tracked in `ingestion_run` table
- ✅ All file processing outcomes tracked in `ingestion_file_audit` table
- ✅ `v_ingestion_kpis` view returns meaningful data
- ✅ Error logging continues to work in `ingestion_error` table

### 2. Non-Functional Requirements
- ✅ No performance degradation in ingestion processing
- ✅ Audit failures don't stop ingestion
- ✅ Comprehensive error handling and logging
- ✅ Thread-safe operation in concurrent environment

### 3. Monitoring Requirements
- ✅ Audit operation success rates > 99%
- ✅ KPI view data freshness < 5 minutes
- ✅ No increase in ingestion processing time
- ✅ Complete audit trail for compliance

## Implementation Timeline

### Week 1: Foundation
- Enhance IngestionAudit service with error handling
- Add configuration and feature toggles
- Implement unit tests

### Week 2: Integration
- Integrate audit tracking into Orchestrator
- Implement thread-local context management
- Add integration tests

### Week 3: Testing & Validation
- Performance testing and optimization
- End-to-end testing with real data
- KPI view validation

### Week 4: Deployment & Monitoring
- Production deployment with feature toggle
- Monitor audit service health
- Validate KPI view functionality

## Risk Mitigation

### 1. Performance Impact
- **Risk**: Audit operations slow down ingestion
- **Mitigation**: Async audit operations, performance testing, monitoring

### 2. Data Consistency
- **Risk**: Audit data doesn't match actual processing
- **Mitigation**: Comprehensive testing, validation queries, monitoring

### 3. Service Availability
- **Risk**: Audit service failures affect ingestion
- **Mitigation**: Error isolation, graceful degradation, fallback mechanisms

### 4. Thread Safety
- **Risk**: Concurrent access issues in audit tracking
- **Mitigation**: Thread-local context, proper synchronization, testing

## Conclusion

This plan provides a comprehensive approach to integrating ingestion audit tracking while maintaining system reliability and performance. The phased implementation approach ensures minimal risk and allows for gradual rollout with proper monitoring and validation.
