package com.acme.claims.security.service;

import com.acme.claims.security.ReportType;
import com.acme.claims.security.Role;
import com.acme.claims.security.config.SecurityProperties;
import com.acme.claims.security.context.ServiceUserContext;
import com.acme.claims.security.context.UserContext;
import com.acme.claims.security.entity.ReportsMetadata;
import com.acme.claims.security.entity.User;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.time.LocalDateTime;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Service for managing user context throughout the application.
 * Provides centralized access to current user information, permissions, and facilities.
 * 
 * This service includes comprehensive logging for debugging and audit purposes.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class UserContextService {
    
    private final UserService userService;
    private final SecurityProperties securityProperties;
    
    /**
     * Get current user context from security context
     * 
     * @return UserContext for current user
     * @throws IllegalStateException if no user is authenticated
     */
    public UserContext getCurrentUserContext() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        
        if (authentication == null || !authentication.isAuthenticated() || 
            "anonymousUser".equals(authentication.getPrincipal())) {
            log.debug("Attempted to get user context for unauthenticated user");
            throw new IllegalStateException("No authenticated user found");
        }
        
        User user = (User) authentication.getPrincipal();
        log.debug("Getting user context for user: {} (ID: {})", user.getUsername(), user.getId());
        
        return buildUserContext(user);
    }
    
    /**
     * Get current service user context from security context
     * This method returns ServiceUserContext which is used by service layer
     * 
     * @return ServiceUserContext for current user
     * @throws IllegalStateException if no user is authenticated
     */
    public ServiceUserContext getCurrentServiceUserContext() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        
        if (authentication == null || !authentication.isAuthenticated() || 
            "anonymousUser".equals(authentication.getPrincipal())) {
            log.warn("Attempted to get service user context for unauthenticated user");
            throw new IllegalStateException("No authenticated user found");
        }
        
        User user = (User) authentication.getPrincipal();
        log.debug("Getting service user context for user: {} (ID: {})", user.getUsername(), user.getId());
        
        return buildServiceUserContext(user);
    }
    
    /**
     * Get current user context with request information
     * 
     * @param request HTTP request for additional context
     * @return UserContext for current user with request details
     */
    public UserContext getCurrentUserContext(HttpServletRequest request) {
        UserContext baseContext = getCurrentUserContext();
        
        // Enhance with request information
        String ipAddress = getClientIpAddress(request);
        String userAgent = request.getHeader("User-Agent");
        
        log.debug("Enhanced user context with request info - IP: {}, UserAgent: {}", 
                ipAddress, userAgent != null ? userAgent.substring(0, Math.min(50, userAgent.length())) + "..." : "null");
        
        return UserContext.builder()
                .userId(baseContext.getUserId())
                .username(baseContext.getUsername())
                .email(baseContext.getEmail())
                .roles(baseContext.getRoles())
                .facilities(baseContext.getFacilities())
                .primaryFacility(baseContext.getPrimaryFacility())
                .reportPermissions(baseContext.getReportPermissions())
                .sessionStartTime(baseContext.getSessionStartTime())
                .ipAddress(ipAddress)
                .userAgent(userAgent)
                .build();
    }
    
    /**
     * Get current user context with automatic request detection
     * 
     * @return UserContext for current user
     */
    public UserContext getCurrentUserContextWithRequest() {
        try {
            ServletRequestAttributes attributes = (ServletRequestAttributes) RequestContextHolder.currentRequestAttributes();
            HttpServletRequest request = attributes.getRequest();
            return getCurrentUserContext(request);
        } catch (Exception e) {
            log.debug("Could not get request attributes, returning basic user context: {}", e.getMessage());
            return getCurrentUserContext();
        }
    }
    
    /**
     * Check if current user has access to a specific facility
     * 
     * @param facilityCode Facility code to check
     * @return true if user has access
     */
    public boolean hasFacilityAccess(String facilityCode) {
        try {
            UserContext context = getCurrentUserContext();
            boolean hasAccess = context.hasFacilityAccess(facilityCode);
            
            log.debug("Facility access check - User: {}, Facility: {}, HasAccess: {}", 
                    context.getUsername(), facilityCode, hasAccess);
            
            return hasAccess;
        } catch (Exception e) {
            log.error("Error checking facility access for facility: {}", facilityCode, e);
            return false;
        }
    }
    
    /**
     * Check if current user has access to a specific report type
     * 
     * @param reportType Report type to check
     * @return true if user has access
     */
    public boolean hasReportAccess(ReportType reportType) {
        try {
            UserContext context = getCurrentUserContext();
            boolean hasAccess = context.hasReportAccess(reportType);
            
            log.debug("Report access check - User: {}, ReportType: {}, HasAccess: {}", 
                    context.getUsername(), reportType, hasAccess);
            
            return hasAccess;
        } catch (Exception e) {
            log.error("Error checking report access for report type: {}", reportType, e);
            return false;
        }
    }
    
    /**
     * Get facilities accessible by current user
     * 
     * @return Set of facility codes
     */
    public Set<String> getUserFacilities() {
        try {
            UserContext context = getCurrentUserContext();
            Set<String> facilities = context.getFacilities();
            
            log.debug("User facilities retrieved - User: {}, Facilities: {}", 
                    context.getUsername(), facilities);
            
            return facilities;
        } catch (Exception e) {
            log.error("Error getting user facilities", e);
            return Set.of();
        }
    }
    
    /**
     * Get primary facility for current user
     * 
     * @return Primary facility code or null
     */
    public String getPrimaryFacility() {
        try {
            UserContext context = getCurrentUserContext();
            String primaryFacility = context.getPrimaryFacility();
            
            log.debug("Primary facility retrieved - User: {}, PrimaryFacility: {}", 
                    context.getUsername(), primaryFacility);
            
            return primaryFacility;
        } catch (Exception e) {
            log.error("Error getting primary facility", e);
            return null;
        }
    }
    
    /**
     * Check if current user is super admin
     * 
     * @return true if user is super admin
     */
    public boolean isSuperAdmin() {
        try {
            UserContext context = getCurrentUserContext();
            boolean isSuperAdmin = context.isSuperAdmin();
            
            log.debug("Super admin check - User: {}, IsSuperAdmin: {}", 
                    context.getUsername(), isSuperAdmin);
            
            return isSuperAdmin;
        } catch (Exception e) {
            log.error("Error checking super admin status", e);
            return false;
        }
    }
    
    /**
     * Check if current user is facility admin
     * 
     * @return true if user is facility admin
     */
    public boolean isFacilityAdmin() {
        try {
            UserContext context = getCurrentUserContext();
            boolean isFacilityAdmin = context.isFacilityAdmin();
            
            log.debug("Facility admin check - User: {}, IsFacilityAdmin: {}", 
                    context.getUsername(), isFacilityAdmin);
            
            return isFacilityAdmin;
        } catch (Exception e) {
            log.error("Error checking facility admin status", e);
            return false;
        }
    }
    
    /**
     * Check if current user is staff
     * 
     * @return true if user is staff
     */
    public boolean isStaff() {
        try {
            UserContext context = getCurrentUserContext();
            boolean isStaff = context.isStaff();
            
            log.debug("Staff check - User: {}, IsStaff: {}", 
                    context.getUsername(), isStaff);
            
            return isStaff;
        } catch (Exception e) {
            log.error("Error checking staff status", e);
            return false;
        }
    }
    
    /**
     * Get current user ID
     * 
     * @return User ID or null if not authenticated
     */
    public Long getCurrentUserId() {
        try {
            UserContext context = getCurrentUserContext();
            log.debug("Current user ID retrieved: {}", context.getUserId());
            return context.getUserId();
        } catch (Exception e) {
            log.error("Error getting current user ID", e);
            return null;
        }
    }
    
    /**
     * Get current username
     * 
     * @return Username or null if not authenticated
     */
    public String getCurrentUsername() {
        try {
            UserContext context = getCurrentUserContext();
            log.debug("Current username retrieved: {}", context.getUsername());
            return context.getUsername();
        } catch (Exception e) {
            log.error("Error getting current username", e);
            return null;
        }
    }
    
    /**
     * Log user context for debugging
     * 
     * @param operation Operation being performed
     */
    public void logUserContext(String operation) {
        try {
            UserContext context = getCurrentUserContext();
            log.info("User context for operation '{}': {}", operation, context.toSummaryString());
        } catch (Exception e) {
            log.warn("Could not log user context for operation '{}': {}", operation, e.getMessage());
        }
    }
    
    /**
     * Build ServiceUserContext from User entity
     * 
     * @param user User entity
     * @return ServiceUserContext
     */
    private ServiceUserContext buildServiceUserContext(User user) {
        log.debug("Building service user context for user: {} (ID: {})", user.getUsername(), user.getId());
        
        // Get user roles
        Set<Role> roles = user.getRoles().stream()
                .map(userRole -> userRole.getRole())
                .collect(Collectors.toSet());
        
        // Get user facilities
        Set<String> facilities = user.getFacilityCodes();
        
        // TODO: When multi-tenancy is enabled, uncomment the following logic:
        // When multi-tenancy is disabled, return empty set to indicate no restrictions
        if (!securityProperties.getMultiTenancy().isEnabled()) {
            log.debug("Multi-tenancy disabled - returning empty facilities set (no restrictions) for service user: {}", user.getUsername());
            facilities = Set.of(); // Empty set means no facility restrictions
        }
        
        // TODO: Implement facility code to ref ID mapping when needed
        // For now, we'll work with facility codes directly
        
        // Build the base UserContext first
        UserContext baseUserContext = buildUserContext(user);
        
        ServiceUserContext context = ServiceUserContext.builder()
                .userContext(baseUserContext)
                .accessibleFacilities(facilities)
                .accessibleReports(Set.of()) // Will be populated by ReportAccessService
                .build();
        
        log.debug("Service user context built successfully: userId={}, username={}, roles={}, facilities={}", 
                context.getUserId(), context.getUsername(), context.getUserRoles(), context.getAccessibleFacilities());
        return context;
    }
    
    /**
     * Build UserContext from User entity
     * 
     * @param user User entity
     * @return UserContext
     */
    private UserContext buildUserContext(User user) {
        log.debug("Building user context for user: {} (ID: {})", user.getUsername(), user.getId());
        
        // Get user roles
        Set<Role> roles = user.getRoles().stream()
                .map(userRole -> userRole.getRole())
                .collect(Collectors.toSet());
        
        // Get user facilities
        Set<String> facilities = user.getFacilityCodes();
        
        // TODO: When multi-tenancy is enabled, uncomment the following logic:
        // When multi-tenancy is disabled, return empty set to indicate no restrictions
        if (!securityProperties.getMultiTenancy().isEnabled()) {
            log.debug("Multi-tenancy disabled - returning empty facilities set (no restrictions) for user: {}", user.getUsername());
            facilities = Set.of(); // Empty set means no facility restrictions
        }
        
        // Get report permissions
        Set<ReportsMetadata> reportPermissions = user.getActiveReportMetadata();
        
        // If user has no specific report permissions but is admin, grant all active reports
        if (reportPermissions.isEmpty() && (roles.contains(Role.SUPER_ADMIN) || roles.contains(Role.FACILITY_ADMIN))) {
            // This will be handled by the ReportAccessService.getUserReportAccess() method
            log.debug("Admin user {} will get all active report permissions", user.getUsername());
        }
        
        UserContext context = UserContext.builder()
                .userId(user.getId())
                .username(user.getUsername())
                .email(user.getEmail())
                .roles(roles)
                .facilities(facilities)
                .primaryFacility(user.getPrimaryFacilityCode())
                .reportPermissions(reportPermissions)
                .sessionStartTime(LocalDateTime.now())
                .build();
        
        log.debug("User context built successfully: {}", context.toSummaryString());
        return context;
    }
    
    /**
     * Get client IP address from request
     * 
     * @param request HTTP request
     * @return Client IP address
     */
    private String getClientIpAddress(HttpServletRequest request) {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty() && !"unknown".equalsIgnoreCase(xForwardedFor)) {
            return xForwardedFor.split(",")[0].trim();
        }
        
        String xRealIp = request.getHeader("X-Real-IP");
        if (xRealIp != null && !xRealIp.isEmpty() && !"unknown".equalsIgnoreCase(xRealIp)) {
            return xRealIp;
        }
        
        return request.getRemoteAddr();
    }
}
