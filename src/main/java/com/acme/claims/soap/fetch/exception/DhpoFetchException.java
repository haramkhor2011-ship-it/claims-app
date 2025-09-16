package com.acme.claims.soap.fetch.exception;

/**
 * Base exception for DHPO fetch operations.
 * Provides structured error information for better error handling and monitoring.
 */
public class DhpoFetchException extends RuntimeException {
    private final String facilityCode;
    private final String operation;
    private final String errorCode;
    private final boolean retryable;

    public DhpoFetchException(String facilityCode, String operation, String message) {
        this(facilityCode, operation, null, message, null, false);
    }

    public DhpoFetchException(String facilityCode, String operation, String errorCode, String message) {
        this(facilityCode, operation, errorCode, message, null, false);
    }

    public DhpoFetchException(String facilityCode, String operation, String errorCode, String message, Throwable cause) {
        this(facilityCode, operation, errorCode, message, cause, false);
    }

    public DhpoFetchException(String facilityCode, String operation, String errorCode, String message, Throwable cause, boolean retryable) {
        super(String.format("[%s] %s: %s", facilityCode, operation, message), cause);
        this.facilityCode = facilityCode;
        this.operation = operation;
        this.errorCode = errorCode;
        this.retryable = retryable;
    }

    public String getFacilityCode() {
        return facilityCode;
    }

    public String getOperation() {
        return operation;
    }

    public String getErrorCode() {
        return errorCode;
    }

    public boolean isRetryable() {
        return retryable;
    }
}
