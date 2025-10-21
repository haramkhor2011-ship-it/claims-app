package com.acme.claims.exception;

import java.time.LocalDateTime;

/**
 * Exception thrown when date range parameters are invalid.
 * 
 * This exception is thrown when:
 * - From date is after to date
 * - Date range is too large (exceeds maximum allowed)
 * - Dates are in an invalid format
 * - Required dates are missing
 * 
 * Results in HTTP 400 (Bad Request) response.
 */
public class InvalidDateRangeException extends ReportServiceException {
    
    private final LocalDateTime fromDate;
    private final LocalDateTime toDate;
    
    /**
     * Constructs a new invalid date range exception.
     * 
     * @param message the detail message explaining the date range error
     */
    public InvalidDateRangeException(String message) {
        super(message);
        this.fromDate = null;
        this.toDate = null;
    }
    
    /**
     * Constructs a new invalid date range exception with date context.
     * 
     * @param message the detail message
     * @param fromDate the start date that was provided
     * @param toDate the end date that was provided
     */
    public InvalidDateRangeException(String message, LocalDateTime fromDate, LocalDateTime toDate) {
        super(message);
        this.fromDate = fromDate;
        this.toDate = toDate;
    }
    
    /**
     * Gets the from date that was provided.
     * 
     * @return the from date, or null if not specified
     */
    public LocalDateTime getFromDate() {
        return fromDate;
    }
    
    /**
     * Gets the to date that was provided.
     * 
     * @return the to date, or null if not specified
     */
    public LocalDateTime getToDate() {
        return toDate;
    }
}

