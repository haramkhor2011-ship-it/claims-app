package com.acme.claims.exception;

/**
 * Exception thrown when a user attempts to access a report they don't have permission for.
 * 
 * This exception is thrown when:
 * - User lacks the required report-specific permissions
 * - User's role doesn't allow access to the requested report type
 * - Report access has been explicitly revoked
 * 
 * Results in HTTP 403 (Forbidden) response.
 */
public class ReportAccessDeniedException extends ReportServiceException {
    
    private final String reportType;
    private final Long userId;
    
    /**
     * Constructs a new report access denied exception.
     * 
     * @param message the detail message explaining why access was denied
     */
    public ReportAccessDeniedException(String message) {
        super(message);
        this.reportType = null;
        this.userId = null;
    }
    
    /**
     * Constructs a new report access denied exception with report and user context.
     * 
     * @param message the detail message explaining why access was denied
     * @param reportType the type of report that was denied
     * @param userId the ID of the user who was denied access
     */
    public ReportAccessDeniedException(String message, String reportType, Long userId) {
        super(message);
        this.reportType = reportType;
        this.userId = userId;
    }
    
    /**
     * Gets the report type that was denied.
     * 
     * @return the report type, or null if not specified
     */
    public String getReportType() {
        return reportType;
    }
    
    /**
     * Gets the user ID that was denied access.
     * 
     * @return the user ID, or null if not specified
     */
    public Long getUserId() {
        return userId;
    }
}

