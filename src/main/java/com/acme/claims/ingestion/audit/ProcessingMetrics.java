package com.acme.claims.ingestion.audit;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.HashSet;

/**
 * Processing metrics tracker for comprehensive audit data collection.
 * 
 * This class tracks all the metrics needed for the enhanced ingestion_file_audit
 * including timing, file metrics, business data, and retry information.
 */
public class ProcessingMetrics {
    
    // Timing metrics
    private long processingStartTime;
    private long processingEndTime;
    private long parseStartTime;
    private long validationStartTime;
    private long persistStartTime;
    private long verifyStartTime;
    
    // File metrics
    private long fileSizeBytes;
    private String processingMode; // "MEM" or "DISK"
    private String workerThreadName;
    private String sourceFilePath;
    
    // Processing counts
    private int parsedClaims = 0;
    private int persistedClaims = 0;
    private int parsedActivities = 0;
    private int persistedActivities = 0;
    private int parsedEncounters = 0;
    private int persistedEncounters = 0;
    private int parsedDiagnoses = 0;
    private int persistedDiagnoses = 0;
    private int parsedObservations = 0;
    private int persistedObservations = 0;
    private int projectedEvents = 0;
    private int projectedStatusRows = 0;
    
    // Business metrics
    private BigDecimal totalGrossAmount = BigDecimal.ZERO;
    private BigDecimal totalNetAmount = BigDecimal.ZERO;
    private BigDecimal totalPatientShare = BigDecimal.ZERO;
    private Set<String> uniquePayers = new HashSet<>();
    private Set<String> uniqueProviders = new HashSet<>();
    
    // Verification and ACK
    private boolean verificationPassed = false;
    private int verificationFailedCount = 0;
    private boolean ackAttempted = false;
    private boolean ackSent = false;
    
    // Retry tracking
    private int retryCount = 0;
    private List<String> retryReasons = new ArrayList<>();
    private List<String> retryErrorCodes = new ArrayList<>();
    private OffsetDateTime firstAttemptAt;
    private OffsetDateTime lastAttemptAt;
    
    // Error tracking
    private String errorClass;
    private String errorMessage;
    
    public ProcessingMetrics() {
        this.processingStartTime = System.nanoTime();
        this.firstAttemptAt = OffsetDateTime.now();
        this.lastAttemptAt = OffsetDateTime.now();
        this.workerThreadName = Thread.currentThread().getName();
    }
    
    // ========== TIMING METHODS ==========
    
    public void startProcessing() {
        this.processingStartTime = System.nanoTime();
    }
    
    public void endProcessing() {
        this.processingEndTime = System.nanoTime();
    }
    
    public void startParse() {
        this.parseStartTime = System.nanoTime();
    }
    
    public void startValidation() {
        this.validationStartTime = System.nanoTime();
    }
    
    public void startPersist() {
        this.persistStartTime = System.nanoTime();
    }
    
    public void startVerify() {
        this.verifyStartTime = System.nanoTime();
    }
    
    public long getProcessingDurationMs() {
        if (processingEndTime == 0) {
            return (System.nanoTime() - processingStartTime) / 1_000_000L;
        }
        return (processingEndTime - processingStartTime) / 1_000_000L;
    }
    
    // ========== FILE METRICS METHODS ==========
    
    public void setFileSizeBytes(long fileSizeBytes) {
        this.fileSizeBytes = fileSizeBytes;
    }
    
    public void setProcessingMode(String processingMode) {
        this.processingMode = processingMode;
    }
    
    public void setSourceFilePath(String sourceFilePath) {
        this.sourceFilePath = sourceFilePath;
    }
    
    // ========== COUNT METHODS ==========
    
    public void setParsedClaims(int parsedClaims) {
        this.parsedClaims = parsedClaims;
    }
    
    public void setPersistedClaims(int persistedClaims) {
        this.persistedClaims = persistedClaims;
    }
    
    public void setParsedActivities(int parsedActivities) {
        this.parsedActivities = parsedActivities;
    }
    
    public void setPersistedActivities(int persistedActivities) {
        this.persistedActivities = persistedActivities;
    }
    
    public void setParsedEncounters(int parsedEncounters) {
        this.parsedEncounters = parsedEncounters;
    }
    
    public void setPersistedEncounters(int persistedEncounters) {
        this.persistedEncounters = persistedEncounters;
    }
    
    public void setParsedDiagnoses(int parsedDiagnoses) {
        this.parsedDiagnoses = parsedDiagnoses;
    }
    
    public void setPersistedDiagnoses(int persistedDiagnoses) {
        this.persistedDiagnoses = persistedDiagnoses;
    }
    
    public void setParsedObservations(int parsedObservations) {
        this.parsedObservations = parsedObservations;
    }
    
    public void setPersistedObservations(int persistedObservations) {
        this.persistedObservations = persistedObservations;
    }
    
    public void setProjectedEvents(int projectedEvents) {
        this.projectedEvents = projectedEvents;
    }
    
    public void setProjectedStatusRows(int projectedStatusRows) {
        this.projectedStatusRows = projectedStatusRows;
    }
    
    // ========== BUSINESS METRICS METHODS ==========
    
    public void addGrossAmount(BigDecimal amount) {
        if (amount != null) {
            this.totalGrossAmount = this.totalGrossAmount.add(amount);
        }
    }
    
    public void addNetAmount(BigDecimal amount) {
        if (amount != null) {
            this.totalNetAmount = this.totalNetAmount.add(amount);
        }
    }
    
    public void addPatientShare(BigDecimal amount) {
        if (amount != null) {
            this.totalPatientShare = this.totalPatientShare.add(amount);
        }
    }
    
    public void addPayer(String payerId) {
        if (payerId != null && !payerId.isBlank()) {
            this.uniquePayers.add(payerId);
        }
    }
    
    public void addProvider(String providerId) {
        if (providerId != null && !providerId.isBlank()) {
            this.uniqueProviders.add(providerId);
        }
    }
    
    // ========== VERIFICATION AND ACK METHODS ==========
    
    public void setVerificationPassed(boolean verificationPassed) {
        this.verificationPassed = verificationPassed;
    }
    
    public void setVerificationFailedCount(int verificationFailedCount) {
        this.verificationFailedCount = verificationFailedCount;
    }
    
    public void setAckAttempted(boolean ackAttempted) {
        this.ackAttempted = ackAttempted;
    }
    
    public void setAckSent(boolean ackSent) {
        this.ackSent = ackSent;
    }
    
    // ========== RETRY TRACKING METHODS ==========
    
    public void incrementRetryCount() {
        this.retryCount++;
        this.lastAttemptAt = OffsetDateTime.now();
    }
    
    public void addRetryReason(String reason) {
        if (reason != null && !reason.isBlank()) {
            this.retryReasons.add(reason);
        }
    }
    
    public void addRetryErrorCode(String errorCode) {
        if (errorCode != null && !errorCode.isBlank()) {
            this.retryErrorCodes.add(errorCode);
        }
    }
    
    // ========== ERROR TRACKING METHODS ==========
    
    public void setError(String errorClass, String errorMessage) {
        this.errorClass = errorClass;
        this.errorMessage = errorMessage;
    }
    
    // ========== GETTER METHODS ==========
    
    public long getFileSizeBytes() { return fileSizeBytes; }
    public String getProcessingMode() { return processingMode; }
    public String getWorkerThreadName() { return workerThreadName; }
    public String getSourceFilePath() { return sourceFilePath; }
    
    public int getParsedClaims() { return parsedClaims; }
    public int getPersistedClaims() { return persistedClaims; }
    public int getParsedActivities() { return parsedActivities; }
    public int getPersistedActivities() { return persistedActivities; }
    public int getParsedEncounters() { return parsedEncounters; }
    public int getPersistedEncounters() { return persistedEncounters; }
    public int getParsedDiagnoses() { return parsedDiagnoses; }
    public int getPersistedDiagnoses() { return persistedDiagnoses; }
    public int getParsedObservations() { return parsedObservations; }
    public int getPersistedObservations() { return persistedObservations; }
    public int getProjectedEvents() { return projectedEvents; }
    public int getProjectedStatusRows() { return projectedStatusRows; }
    
    public BigDecimal getTotalGrossAmount() { return totalGrossAmount; }
    public BigDecimal getTotalNetAmount() { return totalNetAmount; }
    public BigDecimal getTotalPatientShare() { return totalPatientShare; }
    public int getUniquePayers() { return uniquePayers.size(); }
    public int getUniqueProviders() { return uniqueProviders.size(); }
    
    public boolean isVerificationPassed() { return verificationPassed; }
    public int getVerificationFailedCount() { return verificationFailedCount; }
    public boolean isAckAttempted() { return ackAttempted; }
    public boolean isAckSent() { return ackSent; }
    
    public int getRetryCount() { return retryCount; }
    public String[] getRetryReasons() { return retryReasons.toArray(new String[0]); }
    public String[] getRetryErrorCodes() { return retryErrorCodes.toArray(new String[0]); }
    public OffsetDateTime getFirstAttemptAt() { return firstAttemptAt; }
    public OffsetDateTime getLastAttemptAt() { return lastAttemptAt; }
    
    public String getErrorClass() { return errorClass; }
    public String getErrorMessage() { return errorMessage; }
    
    // ========== UTILITY METHODS ==========
    
    /**
     * Check if this represents a successful processing
     */
    public boolean isSuccess() {
        return errorClass == null && verificationPassed;
    }
    
    /**
     * Check if this represents a failure
     */
    public boolean isFailure() {
        return errorClass != null;
    }
    
    /**
     * Check if this represents a retry scenario
     */
    public boolean isRetry() {
        return retryCount > 0;
    }
    
    /**
     * Get a summary string for logging
     */
    public String getSummary() {
        return String.format(
            "ProcessingMetrics{success=%s, duration=%dms, size=%d bytes, mode=%s, " +
            "parsed[c=%d,a=%d,e=%d,d=%d,o=%d], persisted[c=%d,a=%d,e=%d,d=%d,o=%d], " +
            "retries=%d, verification=%s, ack=%s}",
            isSuccess(), getProcessingDurationMs(), fileSizeBytes, processingMode,
            parsedClaims, parsedActivities, parsedEncounters, parsedDiagnoses, parsedObservations,
            persistedClaims, persistedActivities, persistedEncounters, persistedDiagnoses, persistedObservations,
            retryCount, verificationPassed, ackSent
        );
    }
}
