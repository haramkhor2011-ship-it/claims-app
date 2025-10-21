package com.acme.claims.security.context;

import com.acme.claims.security.ReportType;
import com.acme.claims.security.context.UserContext;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.Set;

/**
 * Enhanced user context for service layer operations.
 * 
 * This class extends the basic UserContext with additional information needed
 * for service layer operations, including request tracing, audit logging,
 * and access control validation.
 * 
 * Features:
 * - Correlation ID for request tracing
 * - Request metadata (path, timestamp, IP)
 * - User's accessible facilities and reports
 * - Audit trail information
 * 
 * This context is built at the controller level and passed to all service methods
 * to ensure consistent user context throughout the request processing chain.
 */
@Data
@Builder
public class ServiceUserContext {
    
    /**
     * The base user context containing user identity and basic information.
     */
    private UserContext userContext;
    
    /**
     * Unique correlation ID for tracing requests across logs and services.
     * Generated at the controller level and used throughout the request lifecycle.
     */
    private String correlationId;
    
    /**
     * The API endpoint path that was requested.
     * Used for audit logging and request context.
     */
    private String requestPath;
    
    /**
     * Timestamp when the request was initiated.
     * Used for calculating execution time and audit logging.
     */
    private LocalDateTime requestTimestamp;
    
    /**
     * Client IP address from the request.
     * Used for security auditing and access logging.
     */
    private String ipAddress;
    
    /**
     * Set of facility codes that the user has access to.
     * Used for facility-based access control and data filtering.
     */
    private Set<String> accessibleFacilities;
    
    /**
     * Set of report types that the user has access to.
     * Used for report-level access control validation.
     */
    private Set<ReportType> accessibleReports;
    
    /**
     * Convenience method to get the user ID from the underlying user context.
     * 
     * @return the user ID
     */
    public Long getUserId() {
        return userContext != null ? userContext.getUserId() : null;
    }
    
    /**
     * Convenience method to get the username from the underlying user context.
     * 
     * @return the username
     */
    public String getUsername() {
        return userContext != null ? userContext.getUsername() : null;
    }
    
    /**
     * Convenience method to get the user's roles from the underlying user context.
     * 
     * @return the user's roles
     */
    public Set<String> getUserRoles() {
        return userContext != null ? userContext.getRoleNames() : Set.of();
    }
    
    /**
     * Checks if the user has access to a specific facility.
     * 
     * @param facilityCode the facility code to check
     * @return true if the user has access, false otherwise
     */
    public boolean hasFacilityAccess(String facilityCode) {
        // When multi-tenancy is disabled, accessibleFacilities will be empty (Set.of())
        // Empty set means no restrictions - all facilities accessible
        if (accessibleFacilities == null || accessibleFacilities.isEmpty()) {
            return true; // No restrictions
        }
        return accessibleFacilities.contains(facilityCode);
    }
    
    /**
     * Checks if the user has access to a specific report type.
     * 
     * @param reportType the report type to check
     * @return true if the user has access, false otherwise
     */
    public boolean hasReportAccess(ReportType reportType) {
        if (accessibleReports == null || accessibleReports.isEmpty()) {
            return true; // No restrictions
        }
        return accessibleReports.contains(reportType);
    }
    
    /**
     * Calculates the execution time since the request started.
     * 
     * @return the execution time in milliseconds
     */
    public long getExecutionTimeMs() {
        if (requestTimestamp == null) {
            return 0;
        }
        return java.time.Duration.between(requestTimestamp, LocalDateTime.now()).toMillis();
    }
    
    /**
     * Gets a summary of the user context for logging purposes.
     * 
     * @return a string representation of the key context information
     */
    public String getContextSummary() {
        return String.format("User: %s (ID: %d), CorrelationId: %s, Path: %s, Facilities: %d, Reports: %d",
                getUsername(),
                getUserId(),
                correlationId,
                requestPath,
                accessibleFacilities != null ? accessibleFacilities.size() : 0,
                accessibleReports != null ? accessibleReports.size() : 0);
    }
    
    /**
     * Creates a copy of this context with updated accessible facilities.
     * 
     * @param facilities the new accessible facilities
     * @return a new ServiceUserContext with updated facilities
     */
    public ServiceUserContext withAccessibleFacilities(Set<String> facilities) {
        return ServiceUserContext.builder()
                .userContext(this.userContext)
                .correlationId(this.correlationId)
                .requestPath(this.requestPath)
                .requestTimestamp(this.requestTimestamp)
                .ipAddress(this.ipAddress)
                .accessibleFacilities(facilities)
                .accessibleReports(this.accessibleReports)
                .build();
    }
    
    /**
     * Creates a copy of this context with updated accessible reports.
     * 
     * @param reports the new accessible reports
     * @return a new ServiceUserContext with updated reports
     */
    public ServiceUserContext withAccessibleReports(Set<ReportType> reports) {
        return ServiceUserContext.builder()
                .userContext(this.userContext)
                .correlationId(this.correlationId)
                .requestPath(this.requestPath)
                .requestTimestamp(this.requestTimestamp)
                .ipAddress(this.ipAddress)
                .accessibleFacilities(this.accessibleFacilities)
                .accessibleReports(reports)
                .build();
    }
}

