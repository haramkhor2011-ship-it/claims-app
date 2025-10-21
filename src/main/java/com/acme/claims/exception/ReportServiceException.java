package com.acme.claims.exception;

/**
 * Base exception for all report service errors.
 * 
 * This serves as the parent exception for all report-related errors,
 * allowing for centralized exception handling in the GlobalExceptionHandler.
 * 
 * Usage:
 * - Extend this class for specific report error scenarios
 * - Throw from service layer when report operations fail
 * - Caught by GlobalExceptionHandler for consistent error responses
 */
public class ReportServiceException extends RuntimeException {
    
    /**
     * Constructs a new report service exception with the specified detail message.
     * 
     * @param message the detail message explaining the error
     */
    public ReportServiceException(String message) {
        super(message);
    }
    
    /**
     * Constructs a new report service exception with the specified detail message and cause.
     * 
     * @param message the detail message explaining the error
     * @param cause the underlying cause of this exception
     */
    public ReportServiceException(String message, Throwable cause) {
        super(message, cause);
    }
    
    /**
     * Constructs a new report service exception with the specified cause.
     * 
     * @param cause the underlying cause of this exception
     */
    public ReportServiceException(Throwable cause) {
        super(cause);
    }
}

