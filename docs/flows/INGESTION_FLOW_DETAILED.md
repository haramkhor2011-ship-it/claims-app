# Ingestion Flow Detailed - Claims Backend Application

> Comprehensive documentation of the ingestion pipeline flow, including step-by-step processing, decision points, error handling, and transaction boundaries.

## Overview

The ingestion pipeline processes XML files (both Claim.Submission and Remittance.Advice formats) through a complete flow from file detection to database persistence and verification.

**Flow**: `Fetcher → Parser → Validate → Persist → Events/Timeline → Verify → Audit → (optional ACK)`

---

## High-Level Flow Diagram

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Fetcher   │───▶│  Orchestrator│───▶│   Pipeline  │───▶│ PersistService│
│             │    │             │    │             │    │             │
│ - LocalFS   │    │ - WorkQueue │    │ - Parse     │    │ - Batch     │
│ - SOAP      │    │ - Backpressure│   │ - Validate  │    │ - Transaction│
│ - Manual    │    │ - ErrorRecovery│  │ - Persist   │    │ - Events    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                              │
┌─────────────┐    ┌─────────────┐    ┌─────────────┐       │
│    ACK      │◀───│   Verify    │◀───│   Audit     │◀──────┘
│             │    │             │    │             │
│ - SOAP      │    │ - Integrity │    │ - FileAudit │
│ - Noop      │    │ - Duplicates│    │ - RunAudit  │
│ - Optional  │    │ - Orphans   │    │ - Metrics   │
└─────────────┘    └─────────────┘    └─────────────┘
```

---

## Detailed Step-by-Step Flow

### 1. File Fetching (Fetcher)

**Purpose**: Collect XML files from various sources.

**Components**:
- `LocalFsFetcher` (localfs mode)
- `SoapFetcherAdapter` (SOAP mode)
- Manual file submission (API)

**Process**:
```java
// LocalFsFetcher
public List<WorkItem> fetch() {
    Path readyDir = Paths.get(props.getReadyDirectory());
    return Files.list(readyDir)
        .filter(this::isXmlFile)
        .map(this::createWorkItem)
        .collect(toList());
}

// SoapFetcherAdapter
public List<WorkItem> fetch() {
    return coordinator.pollFacilities()
        .stream()
        .flatMap(this::downloadFiles)
        .collect(toList());
}
```

**WorkItem Structure**:
```java
public record WorkItem(
    String fileId,           // Unique identifier
    String fileName,         // Original filename
    String source,          // Source system
    byte[] xmlBytes,        // File content (or null)
    Path sourcePath         // File path (for disk files)
) {}
```

**Error Handling**:
- File read errors → Logged, file skipped
- SOAP errors → Retry with exponential backoff
- Network errors → Circuit breaker pattern

---

### 2. Orchestration (Orchestrator)

**Purpose**: Coordinate the processing pipeline with backpressure management.

**Key Methods**:
- `process()` - Main processing loop
- `drain()` - Process work queue
- `processOne()` - Process single work item

**Process**:
```java
@Scheduled(fixedDelay = 1000)
public void process() {
    if (isPaused()) return;
    
    List<WorkItem> items = fetcher.fetch();
    if (items.isEmpty()) return;
    
    // Check queue capacity
    if (workQueue.remainingCapacity() < items.size()) {
        pauseFetcher();
        return;
    }
    
    // Add to queue
    items.forEach(workQueue::offer);
    
    // Process in bursts
    drain();
}

private void drain() {
    int burstSize = Math.min(props.getBurstSize(), workQueue.size());
    List<CompletableFuture<Result>> futures = new ArrayList<>();
    
    for (int i = 0; i < burstSize; i++) {
        WorkItem item = workQueue.poll();
        if (item != null) {
            futures.add(CompletableFuture.supplyAsync(() -> 
                processOne(item), executor));
        }
    }
    
    // Wait for completion
    CompletableFuture.allOf(futures.toArray(new CompletableFuture[0]))
        .join();
}
```

**Backpressure Management**:
- Queue capacity monitoring
- Fetcher pause/resume
- Executor saturation handling
- Burst processing limits

**Error Handling**:
- Individual file failures don't stop processing
- Failed items are logged and skipped
- System continues processing other files

---

### 3. Pipeline Processing (Pipeline)

**Purpose**: Core processing engine that orchestrates parse → validate → persist flow.

**Key Methods**:
- `process(WorkItem)` - Main processing method
- `insertStub()` - Create ingestion file record
- `updateIngestionFileHeader()` - Update file metadata

**Process**:
```java
@Transactional(propagation = Propagation.NOT_SUPPORTED)
public Result process(WorkItem wi) {
    Long filePk = null;
    boolean success = false;
    
    try {
        // 1. Root detection
        RootDetector.RootKind sniffed = RootDetector.detect(xmlBytes);
        short rootType = switch (sniffed) {
            case SUBMISSION -> ROOT_SUBMISSION;
            case REMITTANCE -> ROOT_REMITTANCE;
        };
        
        // 2. Insert stub record
        filePk = self.insertStub(wi, rootType, xmlBytes);
        
        // 3. Check for duplicates
        if (alreadyProjected(filePk)) {
            return new Result(filePk, rootType, 0, 0, 0, 0, null);
        }
        
        // 4. Parse XML
        ParseOutcome out = parser.parse(fileRow);
        
        // 5. Branch by root type
        switch (out.getRootType()) {
            case SUBMISSION -> {
                SubmissionDTO dto = out.getSubmission();
                
                // Header pre-check
                if (!isValidSubmissionHeader(dto)) {
                    throw new RuntimeException("Header validation failed");
                }
                
                // Update header
                self.updateIngestionFileHeader(filePk, ROOT_SUBMISSION,
                    dto.header().senderId(), dto.header().receiverId(),
                    dto.header().transactionDate(), dto.header().recordCount(),
                    dto.header().dispositionFlag());
                
                // Business validation
                validateSubmission(dto);
                
                // Persist
                var counts = persist.persistSubmission(filePk, dto, out.getAttachments());
                return new Result(filePk, 1, dto.claims().size(), counts.claims(),
                    countActs(dto), counts.acts(), dto.header().transactionDate());
            }
            
            case REMITTANCE -> {
                RemittanceAdviceDTO dto = out.getRemittance();
                
                // Similar process for remittance
                // ... (omitted for brevity)
            }
        }
    } catch (Exception ex) {
        if (filePk != null) {
            errors.fileError(filePk, "PIPELINE", "PIPELINE_FAIL",
                "fileId=" + wi.fileId() + " msg=" + ex.getMessage(), false);
        }
        throw ex;
    } finally {
        // Record metrics
        dhpoMetrics.recordIngestion(wi.source(), mode, success, duration);
    }
}
```

**Transaction Boundaries**:
- `insertStub()` - REQUIRES_NEW (always commits)
- `updateIngestionFileHeader()` - REQUIRES_NEW (always commits)
- `persistSubmission()` - REQUIRES_NEW (main persistence)
- `persistRemittance()` - REQUIRES_NEW (main persistence)

**Error Handling**:
- Parse errors → Logged to `ingestion_error` table
- Validation errors → Logged, processing stops
- Persistence errors → Transaction rollback, error logged
- System errors → Comprehensive error logging

---

### 4. XML Parsing (StageParser)

**Purpose**: Convert XML files to DTOs using StAX parsing.

**Implementation**: `ClaimXmlParserStax`

**Process**:
```java
public ParseOutcome parse(IngestionFile file) {
    try {
        XMLStreamReader reader = factory.createXMLStreamReader(
            new ByteArrayInputStream(file.getXmlBytes()));
        
        // Detect root element
        while (reader.hasNext()) {
            int eventType = reader.next();
            if (eventType == XMLStreamReader.START_ELEMENT) {
                String localName = reader.getLocalName();
                if ("Claim.Submission".equals(localName)) {
                    return parseSubmission(reader, file);
                } else if ("Remittance.Advice".equals(localName)) {
                    return parseRemittance(reader, file);
                }
            }
        }
        
        throw new ParseException("Unknown root element");
    } catch (XMLStreamException e) {
        throw new ParseException("XML parsing failed", e);
    }
}
```

**DTO Structure**:
```java
// Submission DTO
public record SubmissionDTO(
    HeaderDto header,
    List<SubmissionClaimDto> claims
) {}

// Remittance DTO
public record RemittanceAdviceDTO(
    HeaderDto header,
    List<RemittanceClaimDto> claims
) {}
```

**Error Handling**:
- XML syntax errors → ParseException
- Schema validation errors → ValidationException
- Memory issues → OutOfMemoryError (handled by JVM)

---

### 5. Validation (Pipeline.validateSubmission/validateRemittance)

**Purpose**: Validate business rules and data integrity.

**Submission Validation**:
```java
private static void validateSubmission(SubmissionDTO f) {
    req(f.header(), "Header");
    req(f.header().senderId(), "Header.SenderID");
    req(f.header().receiverId(), "Header.ReceiverID");
    req(f.header().transactionDate(), "Header.TransactionDate");
    req(f.header().dispositionFlag(), "Header.DispositionFlag");
    
    if (f.claims() == null || f.claims().isEmpty()) {
        throw new IllegalArgumentException("No claims in submission");
    }
    
    for (var c : f.claims()) {
        req(c.id(), "Claim.ID");
        req(c.payerId(), "Claim.PayerID");
        req(c.providerId(), "Claim.ProviderID");
        req(c.emiratesIdNumber(), "Claim.EmiratesIDNumber");
    }
}
```

**Remittance Validation**:
```java
private static void validateRemittance(RemittanceAdviceDTO f) {
    req(f.header(), "Header");
    req(f.header().senderId(), "Header.SenderID");
    req(f.header().receiverId(), "Header.ReceiverID");
    req(f.header().transactionDate(), "Header.TransactionDate");
    req(f.header().dispositionFlag(), "Header.DispositionFlag");
    
    if (f.claims() == null || f.claims().isEmpty()) {
        throw new IllegalArgumentException("No claims in remittance");
    }
    
    for (var c : f.claims()) {
        req(c.id(), "Claim.ID");
        req(c.idPayer(), "Claim.IDPayer");
        req(c.paymentReference(), "Claim.PaymentReference");
    }
}
```

**Error Handling**:
- Validation failures → IllegalArgumentException
- Errors logged to `ingestion_error` table
- Processing stops for invalid files

---

### 6. Data Persistence (PersistService)

**Purpose**: Persist parsed data to database with proper transaction management.

**Key Methods**:
- `persistSubmission()` - Persist submission data
- `persistRemittance()` - Persist remittance data

**Process**:
```java
@Transactional(propagation = Propagation.REQUIRES_NEW)
public PersistCounts persistSubmission(Long ingestionFileId, 
                                     SubmissionDTO dto, 
                                     List<AttachmentDto> attachments) {
    // 1. Create submission record
    Submission submission = submissionMapper.toEntity(dto);
    submission.setIngestionFileId(ingestionFileId);
    submission = submissionRepository.save(submission);
    
    // 2. Process claims
    int claimCount = 0;
    int activityCount = 0;
    
    for (SubmissionClaimDto claimDto : dto.claims()) {
        // Create claim
        Claim claim = claimMapper.toEntity(claimDto);
        claim.setSubmissionId(submission.getId());
        claim = claimRepository.save(claim);
        claimCount++;
        
        // Process encounters
        for (EncounterDto encounterDto : claimDto.encounters()) {
            Encounter encounter = encounterMapper.toEntity(encounterDto);
            encounter.setClaimId(claim.getId());
            encounter = encounterRepository.save(encounter);
            
            // Process diagnoses
            for (DiagnosisDto diagnosisDto : encounterDto.diagnoses()) {
                Diagnosis diagnosis = diagnosisMapper.toEntity(diagnosisDto);
                diagnosis.setEncounterId(encounter.getId());
                diagnosisRepository.save(diagnosis);
            }
        }
        
        // Process activities
        for (ActivityDto activityDto : claimDto.activities()) {
            Activity activity = activityMapper.toEntity(activityDto);
            activity.setClaimId(claim.getId());
            activity = activityRepository.save(activity);
            activityCount++;
            
            // Process observations
            for (ObservationDto obsDto : activityDto.observations()) {
                Observation observation = observationMapper.toEntity(obsDto);
                observation.setActivityId(activity.getId());
                observationRepository.save(observation);
            }
        }
        
        // Process resubmission
        if (claimDto.resubmission() != null) {
            ClaimResubmission resubmission = resubmissionMapper.toEntity(claimDto.resubmission());
            resubmission.setClaimId(claim.getId());
            resubmissionRepository.save(resubmission);
        }
        
        // Process contract
        if (claimDto.contract() != null) {
            ClaimContract contract = contractMapper.toEntity(claimDto.contract());
            contract.setClaimId(claim.getId());
            contractRepository.save(contract);
        }
    }
    
    // 3. Process attachments
    for (AttachmentDto attachmentDto : attachments) {
        ClaimAttachment attachment = attachmentMapper.toEntity(attachmentDto);
        attachment.setIngestionFileId(ingestionFileId);
        attachmentRepository.save(attachment);
    }
    
    return new PersistCounts(claimCount, activityCount);
}
```

**Transaction Management**:
- Each persistence operation uses REQUIRES_NEW
- Ensures data is committed even if outer transaction fails
- Proper rollback on errors

**Error Handling**:
- Constraint violations → DataAccessException
- Database errors → Transaction rollback
- Errors logged to `ingestion_error` table

---

### 7. Event Projection (EventProjectorMapper)

**Purpose**: Create event records for claim lifecycle tracking.

**Process**:
```java
@Mapper
public interface EventProjectorMapper {
    
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "claimKeyId", source = "claimKey.id")
    @Mapping(target = "type", constant = "SUBMISSION")
    @Mapping(target = "eventTime", source = "submission.createdAt")
    ClaimEvent toSubmissionEvent(Submission submission, ClaimKey claimKey);
    
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "claimKeyId", source = "claimKey.id")
    @Mapping(target = "type", constant = "REMITTANCE")
    @Mapping(target = "eventTime", source = "remittance.createdAt")
    ClaimEvent toRemittanceEvent(Remittance remittance, ClaimKey claimKey);
}
```

**Event Types**:
- SUBMISSION → SUBMITTED
- RESUBMISSION → RESUBMITTED
- REMITTANCE + payment → PAID/PARTIALLY_PAID
- REMITTANCE + denial only → REJECTED
- Else → UNKNOWN

---

### 8. Verification (VerifyService)

**Purpose**: Post-persistence validation and integrity checks.

**Key Methods**:
- `verifyFile()` - Verify single file
- `checkIntegrity()` - Check data integrity

**Process**:
```java
public VerificationResult verifyFile(Long ingestionFileId) {
    List<VerificationRule> rules = getVerificationRules();
    List<VerificationResult> results = new ArrayList<>();
    
    for (VerificationRule rule : rules) {
        try {
            boolean passed = jdbcTemplate.queryForObject(rule.getSql(), Boolean.class, ingestionFileId);
            results.add(new VerificationResult(rule.getId(), passed, null));
        } catch (Exception e) {
            results.add(new VerificationResult(rule.getId(), false, e.getMessage()));
        }
    }
    
    return new VerificationResult(results);
}
```

**Verification Rules**:
- Parsed claim count matches header RecordCount
- No orphan rows (claims without submission, activities without claims)
- Unique indexes hold (no duplicate claims/activities/observations/remittances)
- Required fields are non-null

**Error Handling**:
- Verification failures → File marked FAIL
- Errors logged to `ingestion_error` table
- No ACK sent for failed verification

---

### 9. Audit (IngestionAudit)

**Purpose**: Track ingestion runs and file processing statistics.

**Key Methods**:
- `startRun()` - Start ingestion run
- `endRun()` - End ingestion run
- `fileProcessed()` - Record file processing

**Process**:
```java
public Long startRun(String source) {
    return jdbcTemplate.queryForObject("""
        INSERT INTO ingestion_run (source, started_at, status)
        VALUES (?, now(), 'RUNNING')
        RETURNING id
        """, Long.class, source);
}

public void endRun(Long runId, String status, int filesProcessed, int filesFailed) {
    jdbcTemplate.update("""
        UPDATE ingestion_run 
        SET ended_at = now(), status = ?, files_processed = ?, files_failed = ?
        WHERE id = ?
        """, status, filesProcessed, filesFailed, runId);
}

public void fileProcessed(Long runId, Long fileId, int claimsParsed, int claimsPersisted) {
    jdbcTemplate.update("""
        INSERT INTO ingestion_file_audit 
        (run_id, ingestion_file_id, claims_parsed, claims_persisted, status)
        VALUES (?, ?, ?, ?, 'SUCCESS')
        """, runId, fileId, claimsParsed, claimsPersisted);
}
```

---

### 10. Acknowledgment (Acker)

**Purpose**: Send acknowledgments to external systems (optional).

**Implementations**:
- `NoopAcker` - No operation (default)
- `SoapAckerAdapter` - SOAP-based ACK

**Process**:
```java
// SoapAckerAdapter
public void acknowledge(Long ingestionFileId, boolean success) {
    try {
        IngestionFile file = ingestionFileRepository.findById(ingestionFileId)
            .orElseThrow(() -> new FileNotFoundException(ingestionFileId));
        
        String ackMessage = buildAckMessage(file, success);
        soapClient.sendAck(ackMessage);
        
        log.info("ACK sent for fileId={} success={}", file.getFileId(), success);
    } catch (Exception e) {
        log.error("ACK failed for fileId={}", ingestionFileId, e);
        // Don't fail the main process
    }
}
```

**Error Handling**:
- ACK failures don't fail the main process
- Errors logged for monitoring
- Retry logic for transient failures

---

## Error Handling Strategy

### Error Categories

1. **Parse Errors**
   - XML syntax errors
   - Schema validation errors
   - Memory issues

2. **Validation Errors**
   - Business rule violations
   - Required field missing
   - Data format errors

3. **Persistence Errors**
   - Database constraint violations
   - Transaction failures
   - Connection issues

4. **System Errors**
   - Out of memory
   - Disk space issues
   - Network problems

### Error Recovery

1. **File-Level Recovery**
   - Individual file failures don't stop processing
   - Errors logged to `ingestion_error` table
   - Failed files can be reprocessed

2. **System-Level Recovery**
   - Application restart recovery
   - Database connection recovery
   - Resource cleanup

3. **Retry Logic**
   - Transient errors are retried
   - Exponential backoff for retries
   - Circuit breaker for external services

---

## Performance Characteristics

### Throughput
- **Batch Size**: Configurable (default 1000)
- **Concurrency**: Configurable worker threads (default 3)
- **Queue Size**: Configurable buffer capacity

### Memory Usage
- **Streaming Parsing**: StAX for memory efficiency
- **Batch Processing**: Configurable batch sizes
- **Garbage Collection**: Optimized for large file processing

### Transaction Management
- **Per-File Transactions**: Each file processed independently
- **Per-Chunk Transactions**: Large files split into chunks
- **REQUIRES_NEW**: Critical operations always commit

---

## Monitoring and Metrics

### Key Metrics
- **Processing Duration**: Time per file
- **Throughput**: Files per minute
- **Error Rates**: Success/failure ratios
- **Queue Utilization**: Queue size and capacity

### Health Checks
- **Database Health**: Connection pool status
- **File System Health**: Disk space and permissions
- **External Services**: SOAP service availability

### Logging
- **Structured Logging**: Consistent log format
- **Correlation IDs**: Request tracing
- **Error Context**: Detailed error information

---

## Related Documentation

- [Component Map](../architecture/COMPONENT_MAP.md) - High-level architecture overview
- [Class Index](../quick-ref/CLASS_INDEX.md) - Complete list of all classes
- [Finding Code Guide](../quick-ref/FINDING_CODE_GUIDE.md) - How to find specific functionality
- [Common Patterns](../quick-ref/COMMON_PATTERNS.md) - Recurring patterns in codebase
- [SOAP Flow](SOAP_FETCH_FLOW.md) - SOAP integration process
- [Report Flow](REPORT_GENERATION_FLOW.md) - Report generation process
