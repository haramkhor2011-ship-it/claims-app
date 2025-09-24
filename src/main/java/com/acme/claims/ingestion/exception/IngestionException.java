// IngestionException.java - Base exception for ingestion
package com.acme.claims.ingestion.exception;

public abstract class IngestionException extends RuntimeException {
    private final String fileId;
    private final String fileName;
    private final String stage;
    private final String errorCode;
    private final boolean retryable;
    private final long timestamp;

    public IngestionException(String fileId, String fileName, String stage,
                              String errorCode, String message, boolean retryable) {
        super(String.format("[%s] %s: %s", fileId, stage, message));
        this.fileId = fileId;
        this.fileName = fileName;
        this.stage = stage;
        this.errorCode = errorCode;
        this.retryable = retryable;
        this.timestamp = System.currentTimeMillis();
    }

    public IngestionException(String fileId, String fileName, String stage,
                              String errorCode, String message, Throwable cause, boolean retryable) {
        super(String.format("[%s] %s: %s", fileId, stage, message), cause);
        this.fileId = fileId;
        this.fileName = fileName;
        this.stage = stage;
        this.errorCode = errorCode;
        this.retryable = retryable;
        this.timestamp = System.currentTimeMillis();
    }

    // Getters...
    public String getFileId() { return fileId; }
    public String getFileName() { return fileName; }
    public String getStage() { return stage; }
    public String getErrorCode() { return errorCode; }
    public boolean isRetryable() { return retryable; }
    public long getTimestamp() { return timestamp; }
}