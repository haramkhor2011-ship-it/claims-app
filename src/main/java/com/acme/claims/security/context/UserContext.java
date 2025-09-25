package com.acme.claims.security.context;

import com.acme.claims.security.Role;
import com.acme.claims.security.ReportType;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.Set;

/**
 * User context holder containing current user information and permissions.
 * This class provides centralized access to user data throughout the application.
 */
@Data
@Builder
public class UserContext {
    
    /**
     * User ID
     */
    private final Long userId;
    
    /**
     * Username
     */
    private final String username;
    
    /**
     * User email
     */
    private final String email;
    
    /**
     * User roles
     */
    private final Set<Role> roles;
    
    /**
     * Facilities the user has access to
     */
    private final Set<String> facilities;
    
    /**
     * Primary facility code
     */
    private final String primaryFacility;
    
    /**
     * Report types the user has access to
     */
    private final Set<ReportType> reportPermissions;
    
    /**
     * Session start time
     */
    private final LocalDateTime sessionStartTime;
    
    /**
     * IP address of the user
     */
    private final String ipAddress;
    
    /**
     * User agent string
     */
    private final String userAgent;
    
    /**
     * Check if user has a specific role
     * 
     * @param role Role to check
     * @return true if user has the role
     */
    public boolean hasRole(Role role) {
        return roles != null && roles.contains(role);
    }
    
    /**
     * Check if user has any of the specified roles
     * 
     * @param roles Roles to check
     * @return true if user has any of the roles
     */
    public boolean hasAnyRole(Role... roles) {
        if (this.roles == null || roles == null) {
            return false;
        }
        
        for (Role role : roles) {
            if (this.roles.contains(role)) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * Check if user has access to a specific facility
     * 
     * @param facilityCode Facility code to check
     * @return true if user has access to the facility
     */
    public boolean hasFacilityAccess(String facilityCode) {
        if (facilityCode == null || facilities == null) {
            return false;
        }
        
        // Super admin has access to all facilities
        if (hasRole(Role.SUPER_ADMIN)) {
            return true;
        }
        
        return facilities.contains(facilityCode);
    }
    
    /**
     * Check if user has access to a specific report type
     * 
     * @param reportType Report type to check
     * @return true if user has access to the report
     */
    public boolean hasReportAccess(ReportType reportType) {
        if (reportType == null || reportPermissions == null) {
            return false;
        }
        
        // Super admin has access to all reports
        if (hasRole(Role.SUPER_ADMIN)) {
            return true;
        }
        
        return reportPermissions.contains(reportType);
    }
    
    /**
     * Check if user is super admin
     * 
     * @return true if user is super admin
     */
    public boolean isSuperAdmin() {
        return hasRole(Role.SUPER_ADMIN);
    }
    
    /**
     * Check if user is facility admin
     * 
     * @return true if user is facility admin
     */
    public boolean isFacilityAdmin() {
        return hasRole(Role.FACILITY_ADMIN);
    }
    
    /**
     * Check if user is staff
     * 
     * @return true if user is staff
     */
    public boolean isStaff() {
        return hasRole(Role.STAFF);
    }
    
    /**
     * Get user's role names as strings
     * 
     * @return Set of role names
     */
    public Set<String> getRoleNames() {
        if (roles == null) {
            return Set.of();
        }
        return roles.stream()
                .map(Role::name)
                .collect(java.util.stream.Collectors.toSet());
    }
    
    /**
     * Get user's report type names as strings
     * 
     * @return Set of report type names
     */
    public Set<String> getReportTypeNames() {
        if (reportPermissions == null) {
            return Set.of();
        }
        return reportPermissions.stream()
                .map(ReportType::name)
                .collect(java.util.stream.Collectors.toSet());
    }
    
    /**
     * Create a summary string for logging
     * 
     * @return User context summary
     */
    public String toSummaryString() {
        return String.format("UserContext{userId=%d, username='%s', roles=%s, facilities=%s, primaryFacility='%s', reports=%s}", 
                userId, username, getRoleNames(), facilities, primaryFacility, getReportTypeNames());
    }
}
