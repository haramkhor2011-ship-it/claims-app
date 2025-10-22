# SOAP Fetch Flow - Claims Backend Application

> Detailed documentation of the SOAP-based file fetching process, including credential management, facility polling, file download, and error handling.

## Overview

The SOAP fetch flow integrates with DHPO (Dubai Health Payment Organization) services to automatically fetch XML files from multiple healthcare facilities. It uses structured concurrency with virtual threads for efficient parallel processing.

**Flow**: `Facility Polling → Credential Decryption → File Download → Staging → Orchestrator`

---

## High-Level Flow Diagram

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Scheduler │───▶│   Facility  │───▶│   Credential│───▶│   File      │
│             │    │   Polling   │    │   Decryption│    │   Download  │
│ - Interval  │    │             │    │             │    │             │
│ - Reentrancy│    │ - Multi-    │    │ - Per-      │    │ - Parallel  │
│ - Guards    │    │   Facility  │    │   Facility  │    │ - Staging   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                              │
┌─────────────┐    ┌─────────────┐    ┌─────────────┐       │
│   Cleanup   │◀───│   Staging   │◀───│   Error     │◀──────┘
│             │    │   Service   │    │   Handling  │
│ - Archive   │    │             │    │             │
│ - Cleanup   │    │ - File      │    │ - Retry     │
│ - Space     │    │   Storage   │    │ - Circuit   │
│   Management│    │ - Metadata  │    │ - Logging   │
└─────────────┘    └─────────────┘    └─────────────┘
```

---

## Detailed Step-by-Step Flow

### 1. Scheduler Coordination (DhpoFetchCoordinator)

**Purpose**: Coordinates the entire SOAP fetch process with reentrancy guards and structured concurrency.

**Key Methods**:
- `pollFacilities()` - Main coordination method
- `downloadFilesForFacility()` - Per-facility processing
- `stageFile()` - File staging

**Process**:
```java
@Scheduled(fixedDelayString = "${claims.soap.polling.interval:PT1M}")
public void pollFacilities() {
    if (!reentrancyGuard.tryAcquire()) {
        log.debug("Previous polling cycle still running, skipping");
        return;
    }
    
    try {
        log.info("Starting facility polling cycle");
        
        // Get active facilities
        List<Facility> facilities = facilityRepository.findActiveFacilities();
        
        // Use structured concurrency for parallel processing
        try (var scope = StructuredTaskScope.ShutdownOnFailure()) {
            List<CompletableFuture<List<WorkItem>>> futures = facilities.stream()
                .map(facility -> scope.fork(() -> downloadFilesForFacility(facility)))
                .collect(toList());
            
            // Wait for all facilities to complete
            scope.join();
            
            // Collect results
            List<WorkItem> allWorkItems = futures.stream()
                .map(CompletableFuture::resultNow)
                .flatMap(List::stream)
                .collect(toList());
            
            log.info("Polling cycle completed: {} files fetched from {} facilities", 
                allWorkItems.size(), facilities.size());
            
        } catch (Exception e) {
            log.error("Polling cycle failed", e);
        }
        
    } finally {
        reentrancyGuard.release();
    }
}
```

**Reentrancy Guards**:
- Prevents overlapping scheduler runs
- Uses semaphore for concurrency control
- Logs skipped cycles for monitoring

**Error Handling**:
- Individual facility failures don't stop other facilities
- Comprehensive error logging
- Graceful degradation

---

### 2. Facility Polling (DhpoFetchCoordinator.downloadFilesForFacility)

**Purpose**: Process files for a single facility with credential management and download concurrency control.

**Process**:
```java
private List<WorkItem> downloadFilesForFacility(Facility facility) {
    try {
        log.debug("Processing facility: {}", facility.getId());
        
        // 1. Decrypt credentials
        FacilityCredentials credentials = credentialService.decryptCredentials(facility);
        
        // 2. Get inbox
        List<InboxItem> inboxItems = getInbox(facility, credentials);
        
        if (inboxItems.isEmpty()) {
            log.debug("No files in inbox for facility: {}", facility.getId());
            return Collections.emptyList();
        }
        
        // 3. Download files with concurrency control
        Semaphore downloadSemaphore = new Semaphore(soapProperties.getDownloadConcurrency());
        List<CompletableFuture<WorkItem>> downloadFutures = inboxItems.stream()
            .map(item -> CompletableFuture.supplyAsync(() -> {
                try {
                    downloadSemaphore.acquire();
                    return downloadFile(facility, credentials, item);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    throw new RuntimeException("Download interrupted", e);
                } finally {
                    downloadSemaphore.release();
                }
            }, downloadExecutor))
            .collect(toList());
        
        // 4. Wait for all downloads to complete
        CompletableFuture.allOf(downloadFutures.toArray(new CompletableFuture[0]))
            .join();
        
        // 5. Collect results
        List<WorkItem> workItems = downloadFutures.stream()
            .map(CompletableFuture::resultNow)
            .filter(Objects::nonNull)
            .collect(toList());
        
        log.info("Downloaded {} files for facility: {}", workItems.size(), facility.getId());
        return workItems;
        
    } catch (Exception e) {
        log.error("Failed to process facility: {}", facility.getId(), e);
        return Collections.emptyList();
    }
}
```

**Concurrency Control**:
- Per-facility download concurrency bounded by semaphore
- Configurable via `claims.soap.downloadConcurrency`
- Prevents overwhelming external services

**Error Handling**:
- Facility-level errors are logged and isolated
- Individual file download failures don't stop other files
- Graceful degradation with partial success

---

### 3. Credential Management (FacilityCredentialService)

**Purpose**: Securely manage and decrypt facility credentials for SOAP authentication.

**Key Methods**:
- `decryptCredentials()` - Decrypt credentials for a facility
- `encryptCredentials()` - Encrypt credentials for storage
- `rotateCredentials()` - Rotate credentials

**Process**:
```java
public FacilityCredentials decryptCredentials(Facility facility) {
    try {
        // Get encrypted credentials from database
        FacilityCredential credential = credentialRepository
            .findByFacilityId(facility.getId())
            .orElseThrow(() -> new CredentialNotFoundException(facility.getId()));
        
        // Decrypt using facility-specific key
        String decryptedUsername = credentialDecryptor.decrypt(
            credential.getEncryptedUsername(), facility.getEncryptionKey());
        String decryptedPassword = credentialDecryptor.decrypt(
            credential.getEncryptedPassword(), facility.getEncryptionKey());
        
        return new FacilityCredentials(
            facility.getId(),
            decryptedUsername,
            decryptedPassword,
            credential.getEndpointUrl()
        );
        
    } catch (Exception e) {
        log.error("Failed to decrypt credentials for facility: {}", facility.getId(), e);
        throw new CredentialDecryptionException("Failed to decrypt credentials", e);
    }
}
```

**Security Features**:
- Credentials encrypted at rest
- Facility-specific encryption keys
- Credential rotation support
- Audit logging for credential access

**Error Handling**:
- Credential not found → CredentialNotFoundException
- Decryption failures → CredentialDecryptionException
- Invalid credentials → AuthenticationException

---

### 4. Inbox Retrieval (DhpoSoapClient.getInbox)

**Purpose**: Retrieve list of available files from DHPO inbox for a facility.

**Process**:
```java
public List<InboxItem> getInbox(Facility facility, FacilityCredentials credentials) {
    try {
        // Build SOAP request
        String soapRequest = buildGetInboxRequest(credentials);
        
        // Send SOAP call
        String soapResponse = soapClient.sendRequest(
            credentials.getEndpointUrl(), 
            soapRequest,
            credentials.getUsername(),
            credentials.getPassword()
        );
        
        // Parse response
        List<InboxItem> inboxItems = parseInboxResponse(soapResponse);
        
        log.debug("Retrieved {} files from inbox for facility: {}", 
            inboxItems.size(), facility.getId());
        
        return inboxItems;
        
    } catch (SoapException e) {
        log.error("SOAP call failed for facility: {}", facility.getId(), e);
        throw new InboxRetrievalException("Failed to retrieve inbox", e);
    }
}

private String buildGetInboxRequest(FacilityCredentials credentials) {
    return String.format("""
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
            <soap:Header>
                <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
                    <wsse:UsernameToken>
                        <wsse:Username>%s</wsse:Username>
                        <wsse:Password>%s</wsse:Password>
                    </wsse:UsernameToken>
                </wsse:Security>
            </soap:Header>
            <soap:Body>
                <dhpo:GetInbox xmlns:dhpo="http://dhpo.ae/soap/">
                    <dhpo:FacilityId>%s</dhpo:FacilityId>
                </dhpo:GetInbox>
            </soap:Body>
        </soap:Envelope>
        """, credentials.getUsername(), credentials.getPassword(), credentials.getFacilityId());
}
```

**SOAP Features**:
- WS-Security authentication
- Facility-specific endpoints
- Structured error handling
- Response parsing

**Error Handling**:
- SOAP faults → SoapException
- Network errors → NetworkException
- Authentication failures → AuthenticationException

---

### 5. File Download (DhpoSoapClient.downloadFile)

**Purpose**: Download individual files from DHPO with proper staging and error handling.

**Process**:
```java
public WorkItem downloadFile(Facility facility, FacilityCredentials credentials, InboxItem item) {
    try {
        // Build download request
        String soapRequest = buildDownloadRequest(credentials, item);
        
        // Send SOAP call
        String soapResponse = soapClient.sendRequest(
            credentials.getEndpointUrl(),
            soapRequest,
            credentials.getUsername(),
            credentials.getPassword()
        );
        
        // Parse response and extract file content
        byte[] fileContent = parseDownloadResponse(soapResponse);
        
        // Stage file
        Path stagedFile = stagingService.stageFile(
            facility.getId(),
            item.getFileName(),
            fileContent
        );
        
        // Create work item
        WorkItem workItem = new WorkItem(
            item.getFileId(),
            item.getFileName(),
            "SOAP",
            fileContent,
            stagedFile
        );
        
        log.debug("Downloaded file: {} for facility: {}", item.getFileName(), facility.getId());
        return workItem;
        
    } catch (Exception e) {
        log.error("Failed to download file: {} for facility: {}", 
            item.getFileName(), facility.getId(), e);
        return null; // Individual file failures don't stop processing
    }
}

private String buildDownloadRequest(FacilityCredentials credentials, InboxItem item) {
    return String.format("""
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
            <soap:Header>
                <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
                    <wsse:UsernameToken>
                        <wsse:Username>%s</wsse:Username>
                        <wsse:Password>%s</wsse:Password>
                    </wsse:UsernameToken>
                </wsse:Security>
            </soap:Header>
            <soap:Body>
                <dhpo:DownloadFile xmlns:dhpo="http://dhpo.ae/soap/">
                    <dhpo:FacilityId>%s</dhpo:FacilityId>
                    <dhpo:FileId>%s</dhpo:FileId>
                </dhpo:DownloadFile>
            </soap:Body>
        </soap:Envelope>
        """, credentials.getUsername(), credentials.getPassword(), 
             credentials.getFacilityId(), item.getFileId());
}
```

**Download Features**:
- Individual file download
- Proper staging
- Error isolation
- Progress logging

**Error Handling**:
- Download failures → Individual file skipped
- Staging failures → Error logged
- Network timeouts → Retry logic

---

### 6. File Staging (StagingService)

**Purpose**: Manage file staging with proper cleanup and space management.

**Key Methods**:
- `stageFile()` - Stage downloaded file
- `cleanupStagedFiles()` - Clean up processed files
- `getStagingDirectory()` - Get staging directory

**Process**:
```java
public Path stageFile(String facilityId, String fileName, byte[] content) {
    try {
        // Create staging directory
        Path stagingDir = getStagingDirectory(facilityId);
        Files.createDirectories(stagingDir);
        
        // Create unique filename
        String timestamp = Instant.now().toString().replace(":", "-");
        String stagedFileName = String.format("%s_%s_%s", facilityId, timestamp, fileName);
        Path stagedFile = stagingDir.resolve(stagedFileName);
        
        // Write file
        Files.write(stagedFile, content);
        
        // Set permissions
        Files.setPosixFilePermissions(stagedFile, 
            Set.of(PosixFilePermission.OWNER_READ, PosixFilePermission.OWNER_WRITE));
        
        log.debug("Staged file: {} to: {}", fileName, stagedFile);
        return stagedFile;
        
    } catch (IOException e) {
        log.error("Failed to stage file: {}", fileName, e);
        throw new StagingException("Failed to stage file", e);
    }
}

public void cleanupStagedFiles(String facilityId) {
    try {
        Path stagingDir = getStagingDirectory(facilityId);
        if (!Files.exists(stagingDir)) {
            return;
        }
        
        // Find old files (older than 24 hours)
        Instant cutoff = Instant.now().minus(24, ChronoUnit.HOURS);
        Files.list(stagingDir)
            .filter(path -> {
                try {
                    return Files.getLastModifiedTime(path).toInstant().isBefore(cutoff);
                } catch (IOException e) {
                    return false;
                }
            })
            .forEach(path -> {
                try {
                    Files.delete(path);
                    log.debug("Cleaned up staged file: {}", path);
                } catch (IOException e) {
                    log.warn("Failed to clean up staged file: {}", path, e);
                }
            });
        
    } catch (IOException e) {
        log.error("Failed to cleanup staged files for facility: {}", facilityId, e);
    }
}
```

**Staging Features**:
- Facility-specific directories
- Unique filename generation
- Proper file permissions
- Automatic cleanup

**Error Handling**:
- Staging failures → StagingException
- Cleanup failures → Logged warnings
- Disk space issues → Monitored

---

### 7. Error Handling and Recovery

**Purpose**: Comprehensive error handling with retry logic and circuit breaker patterns.

**Error Categories**:

1. **Network Errors**
   - Connection timeouts
   - DNS resolution failures
   - SSL/TLS errors

2. **Authentication Errors**
   - Invalid credentials
   - Expired tokens
   - Permission denied

3. **SOAP Errors**
   - SOAP faults
   - Invalid XML
   - Schema validation errors

4. **System Errors**
   - Out of memory
   - Disk space issues
   - Database connection failures

**Retry Logic**:
```java
@Retryable(
    value = {SoapException.class, NetworkException.class},
    maxAttempts = 3,
    backoff = @Backoff(delay = 1000, multiplier = 2)
)
public String sendRequest(String endpoint, String request, String username, String password) {
    // SOAP request implementation
}
```

**Circuit Breaker**:
```java
@Component
public class SoapCircuitBreaker {
    private final CircuitBreaker circuitBreaker;
    
    public SoapCircuitBreaker() {
        this.circuitBreaker = CircuitBreaker.ofDefaults("soap-service")
            .toBuilder()
            .failureRateThreshold(50)
            .waitDurationInOpenState(Duration.ofMinutes(1))
            .build();
    }
    
    public String callWithCircuitBreaker(Supplier<String> operation) {
        return circuitBreaker.executeSupplier(operation);
    }
}
```

**Error Recovery**:
- Transient errors → Retry with exponential backoff
- Persistent errors → Circuit breaker activation
- System errors → Graceful degradation

---

## Performance Characteristics

### Concurrency
- **Structured Concurrency**: Virtual threads for parallel processing
- **Download Concurrency**: Configurable per-facility limits
- **Reentrancy Guards**: Prevents overlapping scheduler runs

### Throughput
- **Polling Interval**: Configurable (default 1 minute)
- **Batch Processing**: Multiple facilities processed in parallel
- **File Processing**: Individual files processed concurrently

### Resource Management
- **Memory Usage**: Streaming file processing
- **Disk Space**: Automatic cleanup of staged files
- **Network**: Connection pooling and timeout management

---

## Monitoring and Metrics

### Key Metrics
- **Polling Cycles**: Success/failure rates
- **File Downloads**: Files per facility per cycle
- **Error Rates**: By error type and facility
- **Performance**: Download times and throughput

### Health Checks
- **SOAP Service Health**: Endpoint availability
- **Credential Health**: Authentication success rates
- **Staging Health**: Disk space and file operations

### Logging
- **Structured Logging**: Consistent log format
- **Facility Context**: Facility ID in all logs
- **Error Context**: Detailed error information

---

## Configuration

### SOAP Properties
```yaml
claims:
  soap:
    polling:
      interval: PT1M
      enabled: true
    download:
      concurrency: 5
      timeout: PT30S
    staging:
      directory: /var/claims/staging
      cleanup:
        enabled: true
        interval: PT1H
        retention: PT24H
    retry:
      maxAttempts: 3
      backoff:
        delay: PT1S
        multiplier: 2
```

### Facility Configuration
```sql
-- Facility credentials table
CREATE TABLE facility_credential (
    id BIGSERIAL PRIMARY KEY,
    facility_id VARCHAR(50) NOT NULL,
    encrypted_username BYTEA NOT NULL,
    encrypted_password BYTEA NOT NULL,
    endpoint_url VARCHAR(255) NOT NULL,
    encryption_key VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

---

## Security Considerations

### Credential Management
- **Encryption at Rest**: Credentials encrypted in database
- **Facility-Specific Keys**: Each facility has unique encryption key
- **Credential Rotation**: Support for credential updates
- **Audit Logging**: All credential access logged

### Network Security
- **TLS/SSL**: All SOAP calls use HTTPS
- **Certificate Validation**: Proper certificate chain validation
- **Timeout Management**: Prevents hanging connections

### Data Protection
- **File Permissions**: Staged files have restricted permissions
- **Automatic Cleanup**: Files cleaned up after processing
- **Access Control**: Facility-based data isolation

---

## Related Documentation

- [Component Map](../architecture/COMPONENT_MAP.md) - High-level architecture overview
- [Class Index](../quick-ref/CLASS_INDEX.md) - Complete list of all classes
- [Finding Code Guide](../quick-ref/FINDING_CODE_GUIDE.md) - How to find specific functionality
- [Common Patterns](../quick-ref/COMMON_PATTERNS.md) - Recurring patterns in codebase
- [Ingestion Flow](INGESTION_FLOW_DETAILED.md) - Detailed ingestion process
- [Report Flow](REPORT_GENERATION_FLOW.md) - Report generation process
