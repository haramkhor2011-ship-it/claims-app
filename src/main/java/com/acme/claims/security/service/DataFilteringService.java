package com.acme.claims.security.service;

import com.acme.claims.security.config.SecurityProperties;
import com.acme.claims.security.context.UserContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Service for filtering data based on user roles and facility assignments.
 * 
 * This service provides multi-tenant data filtering capabilities that can be
 * toggled on/off via configuration. When disabled, all data is accessible
 * to authenticated users. When enabled, data is filtered based on user roles
 * and facility assignments.
 * 
 * Multi-tenancy is controlled by the claims.security.multi-tenancy.enabled property.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DataFilteringService {
    
    private final UserContextService userContextService;
    private final SecurityProperties securityProperties;
    
    /**
     * Filter facility codes based on user permissions
     * 
     * @param requestedFacilities List of facility codes to filter
     * @return Filtered list of facility codes the user can access
     */
    public List<String> filterFacilities(List<String> requestedFacilities) {
        if (!isMultiTenancyEnabled()) {
            log.debug("Multi-tenancy disabled - returning all requested facilities: {}", requestedFacilities);
            return requestedFacilities;
        }
        
        try {
            UserContext userContext = userContextService.getCurrentUserContext();
            Set<String> userFacilities = userContext.getFacilities();
            
            // Super admin can access all facilities
            if (userContext.isSuperAdmin()) {
                log.debug("Super admin access - returning all facilities: {}", requestedFacilities);
                return requestedFacilities;
            }
            
            // Filter facilities based on user's assigned facilities
            List<String> filteredFacilities = requestedFacilities.stream()
                    .filter(userFacilities::contains)
                    .collect(Collectors.toList());
            
            log.info("Data filtering applied - User: {} (ID: {}), Requested: {}, Filtered: {}", 
                    userContext.getUsername(), userContext.getUserId(), 
                    requestedFacilities.size(), filteredFacilities.size());
            
            return filteredFacilities;
            
        } catch (Exception e) {
            log.error("Error filtering facilities for user: {}", 
                    userContextService.getCurrentUsername(), e);
            return List.of(); // Return empty list on error for security
        }
    }
    
    /**
     * Filter facility codes based on user permissions (single facility)
     * 
     * @param facilityCode Facility code to check
     * @return true if user can access the facility
     */
    public boolean canAccessFacility(String facilityCode) {
        if (!isMultiTenancyEnabled()) {
            log.debug("Multi-tenancy disabled - allowing access to facility: {}", facilityCode);
            return true;
        }
        
        try {
            UserContext userContext = userContextService.getCurrentUserContext();
            
            // Super admin can access all facilities
            if (userContext.isSuperAdmin()) {
                log.debug("Super admin access - allowing facility: {}", facilityCode);
                return true;
            }
            
            boolean canAccess = userContext.hasFacilityAccess(facilityCode);
            
            log.debug("Facility access check - User: {} (ID: {}), Facility: {}, CanAccess: {}", 
                    userContext.getUsername(), userContext.getUserId(), facilityCode, canAccess);
            
            return canAccess;
            
        } catch (Exception e) {
            log.error("Error checking facility access for facility: {} and user: {}", 
                    facilityCode, userContextService.getCurrentUsername(), e);
            return false; // Deny access on error for security
        }
    }
    
    /**
     * Get SQL WHERE clause for facility filtering
     * 
     * @param facilityColumnName Name of the facility column in the database
     * @return SQL WHERE clause for facility filtering
     */
    public String getFacilityFilterClause(String facilityColumnName) {
        if (!isMultiTenancyEnabled()) {
            log.debug("Multi-tenancy disabled - returning empty filter clause");
            return ""; // No filtering when multi-tenancy is disabled
        }
        
        try {
            UserContext userContext = userContextService.getCurrentUserContext();
            Set<String> userFacilities = userContext.getFacilities();
            
            // Super admin can access all facilities
            if (userContext.isSuperAdmin()) {
                log.debug("Super admin access - returning empty filter clause");
                return ""; // No filtering for super admin
            }
            
            if (userFacilities.isEmpty()) {
                log.warn("User {} (ID: {}) has no facility assignments - returning restrictive filter", 
                        userContext.getUsername(), userContext.getUserId());
                return " AND 1=0"; // No access if no facilities assigned
            }
            
            // Create IN clause for user's facilities
            String facilityList = userFacilities.stream()
                    .map(facility -> "'" + facility + "'")
                    .collect(Collectors.joining(","));
            
            String filterClause = " AND " + facilityColumnName + " IN (" + facilityList + ")";
            
            log.info("Generated facility filter clause for user: {} (ID: {}) - Facilities: {}", 
                    userContext.getUsername(), userContext.getUserId(), userFacilities);
            
            return filterClause;
            
        } catch (Exception e) {
            log.error("Error generating facility filter clause for user: {}", 
                    userContextService.getCurrentUsername(), e);
            return " AND 1=0"; // Restrictive filter on error for security
        }
    }
    
    /**
     * Get SQL WHERE clause for facility filtering with parameterized query support
     * 
     * @param facilityColumnName Name of the facility column in the database
     * @return Object array containing the filter clause and parameters
     */
    public Object[] getFacilityFilterWithParameters(String facilityColumnName) {
        if (!isMultiTenancyEnabled()) {
            log.debug("Multi-tenancy disabled - returning empty filter with no parameters");
            return new Object[]{"", new Object[0]};
        }
        
        try {
            UserContext userContext = userContextService.getCurrentUserContext();
            Set<String> userFacilities = userContext.getFacilities();
            
            // Super admin can access all facilities
            if (userContext.isSuperAdmin()) {
                log.debug("Super admin access - returning empty filter with no parameters");
                return new Object[]{"", new Object[0]};
            }
            
            if (userFacilities.isEmpty()) {
                log.warn("User {} (ID: {}) has no facility assignments - returning restrictive filter", 
                        userContext.getUsername(), userContext.getUserId());
                return new Object[]{" AND 1=0", new Object[0]};
            }
            
            // Create parameterized IN clause
            String placeholders = userFacilities.stream()
                    .map(facility -> "?")
                    .collect(Collectors.joining(","));
            
            String filterClause = " AND " + facilityColumnName + " IN (" + placeholders + ")";
            Object[] parameters = userFacilities.toArray();
            
            log.info("Generated parameterized facility filter for user: {} (ID: {}) - Facilities: {}", 
                    userContext.getUsername(), userContext.getUserId(), userFacilities);
            
            return new Object[]{filterClause, parameters};
            
        } catch (Exception e) {
            log.error("Error generating parameterized facility filter for user: {}", 
                    userContextService.getCurrentUsername(), e);
            return new Object[]{" AND 1=0", new Object[0]};
        }
    }
    
    /**
     * Check if user can access a specific report type
     * 
     * @param reportType Report type to check
     * @return true if user can access the report
     */
    public boolean canAccessReport(String reportType) {
        if (!isMultiTenancyEnabled()) {
            log.debug("Multi-tenancy disabled - allowing access to report: {}", reportType);
            return true;
        }
        
        try {
            UserContext userContext = userContextService.getCurrentUserContext();
            
            // Super admin can access all reports
            if (userContext.isSuperAdmin()) {
                log.debug("Super admin access - allowing report: {}", reportType);
                return true;
            }
            
            boolean canAccess = userContext.hasReportAccess(
                    com.acme.claims.security.ReportType.fromName(reportType));
            
            log.debug("Report access check - User: {} (ID: {}), Report: {}, CanAccess: {}", 
                    userContext.getUsername(), userContext.getUserId(), reportType, canAccess);
            
            return canAccess;
            
        } catch (Exception e) {
            log.error("Error checking report access for report: {} and user: {}", 
                    reportType, userContextService.getCurrentUsername(), e);
            return false; // Deny access on error for security
        }
    }
    
    /**
     * Get user's accessible facilities for display purposes
     * 
     * @return Set of facility codes the user can access
     */
    public Set<String> getUserAccessibleFacilities() {
        if (!isMultiTenancyEnabled()) {
            log.debug("Multi-tenancy disabled - returning empty set (all facilities accessible)");
            return Set.of(); // Empty set means all facilities accessible
        }
        
        try {
            UserContext userContext = userContextService.getCurrentUserContext();
            Set<String> facilities = userContext.getFacilities();
            
            log.debug("User accessible facilities - User: {} (ID: {}), Facilities: {}", 
                    userContext.getUsername(), userContext.getUserId(), facilities);
            
            return facilities;
            
        } catch (Exception e) {
            log.error("Error getting user accessible facilities for user: {}", 
                    userContextService.getCurrentUsername(), e);
            return Set.of(); // Return empty set on error
        }
    }
    
    /**
     * Get user's accessible report types for display purposes
     * 
     * @return Set of report types the user can access
     */
    public Set<String> getUserAccessibleReports() {
        if (!isMultiTenancyEnabled()) {
            log.debug("Multi-tenancy disabled - returning empty set (all reports accessible)");
            return Set.of(); // Empty set means all reports accessible
        }
        
        try {
            UserContext userContext = userContextService.getCurrentUserContext();
            Set<String> reports = userContext.getReportCodes();
            
            log.debug("User accessible reports - User: {} (ID: {}), Reports: {}", 
                    userContext.getUsername(), userContext.getUserId(), reports);
            
            return reports;
            
        } catch (Exception e) {
            log.error("Error getting user accessible reports for user: {}", 
                    userContextService.getCurrentUsername(), e);
            return Set.of(); // Return empty set on error
        }
    }
    
    /**
     * Log data filtering status for debugging
     * 
     * @param operation Operation being performed
     */
    public void logFilteringStatus(String operation) {
        try {
            UserContext userContext = userContextService.getCurrentUserContext();
            
            log.info("Data filtering status for operation '{}' - User: {} (ID: {}), " +
                    "MultiTenancy: {}, IsSuperAdmin: {}, Facilities: {}, Reports: {}", 
                    operation, userContext.getUsername(), userContext.getUserId(),
                    isMultiTenancyEnabled(), userContext.isSuperAdmin(),
                    userContext.getFacilities(), userContext.getReportCodes());
            
        } catch (Exception e) {
            log.warn("Could not log filtering status for operation '{}': {}", operation, e.getMessage());
        }
    }
    
    /**
     * Check if multi-tenancy is enabled
     * 
     * @return true if multi-tenancy is enabled
     */
    private boolean isMultiTenancyEnabled() {
        return securityProperties.getMultiTenancy().isEnabled();
    }
}
