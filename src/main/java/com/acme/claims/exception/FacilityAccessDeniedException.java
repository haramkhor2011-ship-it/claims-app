package com.acme.claims.exception;

import java.util.Set;

/**
 * Exception thrown when a user attempts to access data from facilities they don't have access to.
 * 
 * This exception is thrown when:
 * - User requests data for facilities not in their access list
 * - Facility-based filtering fails
 * - Multi-tenancy access control violation occurs
 * 
 * Results in HTTP 403 (Forbidden) response.
 * 
 * Note: This functionality is currently commented out in the codebase for future use.
 */
public class FacilityAccessDeniedException extends ReportServiceException {
    
    private final Set<String> requestedFacilities;
    private final Set<String> accessibleFacilities;
    private final Long userId;
    
    /**
     * Constructs a new facility access denied exception.
     * 
     * @param message the detail message explaining why facility access was denied
     */
    public FacilityAccessDeniedException(String message) {
        super(message);
        this.requestedFacilities = null;
        this.accessibleFacilities = null;
        this.userId = null;
    }
    
    /**
     * Constructs a new facility access denied exception with detailed context.
     * 
     * @param message the detail message
     * @param requestedFacilities the facilities the user attempted to access
     * @param accessibleFacilities the facilities the user has access to
     * @param userId the ID of the user
     */
    public FacilityAccessDeniedException(String message, Set<String> requestedFacilities, 
                                        Set<String> accessibleFacilities, Long userId) {
        super(message);
        this.requestedFacilities = requestedFacilities;
        this.accessibleFacilities = accessibleFacilities;
        this.userId = userId;
    }
    
    /**
     * Gets the facilities that were requested.
     * 
     * @return the requested facilities, or null if not specified
     */
    public Set<String> getRequestedFacilities() {
        return requestedFacilities;
    }
    
    /**
     * Gets the facilities the user has access to.
     * 
     * @return the accessible facilities, or null if not specified
     */
    public Set<String> getAccessibleFacilities() {
        return accessibleFacilities;
    }
    
    /**
     * Gets the user ID.
     * 
     * @return the user ID, or null if not specified
     */
    public Long getUserId() {
        return userId;
    }
}

