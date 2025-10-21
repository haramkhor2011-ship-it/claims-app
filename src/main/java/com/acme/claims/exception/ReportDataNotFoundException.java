package com.acme.claims.exception;

/**
 * Exception thrown when requested report data cannot be found.
 * 
 * This exception is thrown when:
 * - No data matches the provided filters
 * - Requested entity (claim, facility, etc.) doesn't exist
 * - Data has been archived or deleted
 * 
 * Results in HTTP 404 (Not Found) response.
 */
public class ReportDataNotFoundException extends ReportServiceException {
    
    private final String resourceType;
    private final String resourceId;
    
    /**
     * Constructs a new data not found exception.
     * 
     * @param message the detail message explaining what data was not found
     */
    public ReportDataNotFoundException(String message) {
        super(message);
        this.resourceType = null;
        this.resourceId = null;
    }
    
    /**
     * Constructs a new data not found exception with resource context.
     * 
     * @param message the detail message
     * @param resourceType the type of resource that was not found (e.g., "Claim", "Facility")
     * @param resourceId the ID of the resource that was not found
     */
    public ReportDataNotFoundException(String message, String resourceType, String resourceId) {
        super(message);
        this.resourceType = resourceType;
        this.resourceId = resourceId;
    }
    
    /**
     * Gets the type of resource that was not found.
     * 
     * @return the resource type, or null if not specified
     */
    public String getResourceType() {
        return resourceType;
    }
    
    /**
     * Gets the ID of the resource that was not found.
     * 
     * @return the resource ID, or null if not specified
     */
    public String getResourceId() {
        return resourceId;
    }
}

