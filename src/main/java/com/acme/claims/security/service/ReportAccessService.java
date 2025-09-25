package com.acme.claims.security.service;

import com.acme.claims.security.ReportType;
import com.acme.claims.security.entity.User;
import com.acme.claims.security.entity.UserReportPermission;
import com.acme.claims.security.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Service for managing report access permissions.
 * 
 * This service provides functionality to grant, revoke, and check report access
 * permissions for users. It integrates with the existing user management system
 * and provides comprehensive logging for audit purposes.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ReportAccessService {
    
    private final UserRepository userRepository;
    private final UserContextService userContextService;
    
    /**
     * Grant report access to a user
     * 
     * @param userId User ID to grant access to
     * @param reportType Report type to grant access to
     * @param grantedBy User ID of the person granting access
     * @return true if access was granted successfully
     */
    @Transactional
    public boolean grantReportAccess(Long userId, ReportType reportType, Long grantedBy) {
        try {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new IllegalArgumentException("User not found with ID: " + userId));
            
            // Check if user already has access to this report
            boolean alreadyHasAccess = user.getReportPermissions().stream()
                    .anyMatch(permission -> permission.getReportType().equals(reportType));
            
            if (alreadyHasAccess) {
                log.info("User {} (ID: {}) already has access to report: {}", 
                        user.getUsername(), userId, reportType);
                return true;
            }
            
            // Grant access
            UserReportPermission permission = UserReportPermission.builder()
                    .user(user)
                    .reportType(reportType)
                    .grantedBy(grantedBy)
                    .grantedAt(LocalDateTime.now())
                    .build();
            
            user.getReportPermissions().add(permission);
            userRepository.save(user);
            
            log.info("Report access granted - User: {} (ID: {}), Report: {}, GrantedBy: {}", 
                    user.getUsername(), userId, reportType, grantedBy);
            
            return true;
            
        } catch (Exception e) {
            log.error("Error granting report access - UserID: {}, Report: {}, GrantedBy: {}", 
                    userId, reportType, grantedBy, e);
            return false;
        }
    }
    
    /**
     * Revoke report access from a user
     * 
     * @param userId User ID to revoke access from
     * @param reportType Report type to revoke access to
     * @param revokedBy User ID of the person revoking access
     * @return true if access was revoked successfully
     */
    @Transactional
    public boolean revokeReportAccess(Long userId, ReportType reportType, Long revokedBy) {
        try {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new IllegalArgumentException("User not found with ID: " + userId));
            
            // Remove the permission
            boolean removed = user.getReportPermissions().removeIf(
                    permission -> permission.getReportType().equals(reportType));
            
            if (removed) {
                userRepository.save(user);
                log.info("Report access revoked - User: {} (ID: {}), Report: {}, RevokedBy: {}", 
                        user.getUsername(), userId, reportType, revokedBy);
                return true;
            } else {
                log.info("User {} (ID: {}) did not have access to report: {}", 
                        user.getUsername(), userId, reportType);
                return false;
            }
            
        } catch (Exception e) {
            log.error("Error revoking report access - UserID: {}, Report: {}, RevokedBy: {}", 
                    userId, reportType, revokedBy, e);
            return false;
        }
    }
    
    /**
     * Check if a user has access to a specific report type
     * 
     * @param userId User ID to check
     * @param reportType Report type to check
     * @return true if user has access
     */
    public boolean hasReportAccess(Long userId, ReportType reportType) {
        try {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new IllegalArgumentException("User not found with ID: " + userId));
            
            // Super admin and facility admin have access to all reports by default
            if (user.hasRole(com.acme.claims.security.Role.SUPER_ADMIN) || 
                user.hasRole(com.acme.claims.security.Role.FACILITY_ADMIN)) {
                log.debug("Admin user {} (ID: {}) has access to all reports including: {}", 
                        user.getUsername(), userId, reportType);
                return true;
            }
            
            // Check specific report permissions
            boolean hasAccess = user.getReportPermissions().stream()
                    .anyMatch(permission -> permission.getReportType().equals(reportType));
            
            log.debug("Report access check - User: {} (ID: {}), Report: {}, HasAccess: {}", 
                    user.getUsername(), userId, reportType, hasAccess);
            
            return hasAccess;
            
        } catch (Exception e) {
            log.error("Error checking report access - UserID: {}, Report: {}", userId, reportType, e);
            return false; // Deny access on error for security
        }
    }
    
    /**
     * Get all report types a user has access to
     * 
     * @param userId User ID to check
     * @return Set of report types the user can access
     */
    public Set<ReportType> getUserReportAccess(Long userId) {
        try {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new IllegalArgumentException("User not found with ID: " + userId));
            
            // Super admin and facility admin have access to all reports
            if (user.hasRole(com.acme.claims.security.Role.SUPER_ADMIN) || 
                user.hasRole(com.acme.claims.security.Role.FACILITY_ADMIN)) {
                Set<ReportType> allReports = Set.of(ReportType.values());
                log.debug("Admin user {} (ID: {}) has access to all reports: {}", 
                        user.getUsername(), userId, allReports);
                return allReports;
            }
            
            // Get specific report permissions
            Set<ReportType> userReports = user.getReportPermissions().stream()
                    .map(UserReportPermission::getReportType)
                    .collect(Collectors.toSet());
            
            log.debug("User report access - User: {} (ID: {}), Reports: {}", 
                    user.getUsername(), userId, userReports);
            
            return userReports;
            
        } catch (Exception e) {
            log.error("Error getting user report access - UserID: {}", userId, e);
            return Set.of(); // Return empty set on error
        }
    }
    
    /**
     * Get all users who have access to a specific report type
     * 
     * @param reportType Report type to check
     * @return List of users with access to the report
     */
    public List<User> getUsersWithReportAccess(ReportType reportType) {
        try {
            List<User> allUsers = userRepository.findAll();
            
            List<User> usersWithAccess = allUsers.stream()
                    .filter(user -> {
                        // Super admin and facility admin have access to all reports
                        if (user.hasRole(com.acme.claims.security.Role.SUPER_ADMIN) || 
                            user.hasRole(com.acme.claims.security.Role.FACILITY_ADMIN)) {
                            return true;
                        }
                        
                        // Check specific report permissions
                        return user.getReportPermissions().stream()
                                .anyMatch(permission -> permission.getReportType().equals(reportType));
                    })
                    .collect(Collectors.toList());
            
            log.info("Found {} users with access to report: {}", usersWithAccess.size(), reportType);
            
            return usersWithAccess;
            
        } catch (Exception e) {
            log.error("Error getting users with report access - Report: {}", reportType, e);
            return List.of();
        }
    }
    
    /**
     * Grant multiple report access permissions to a user
     * 
     * @param userId User ID to grant access to
     * @param reportTypes Set of report types to grant access to
     * @param grantedBy User ID of the person granting access
     * @return Number of permissions granted
     */
    @Transactional
    public int grantMultipleReportAccess(Long userId, Set<ReportType> reportTypes, Long grantedBy) {
        int grantedCount = 0;
        
        for (ReportType reportType : reportTypes) {
            if (grantReportAccess(userId, reportType, grantedBy)) {
                grantedCount++;
            }
        }
        
        log.info("Granted {} out of {} report permissions to user ID: {}", 
                grantedCount, reportTypes.size(), userId);
        
        return grantedCount;
    }
    
    /**
     * Revoke all report access from a user
     * 
     * @param userId User ID to revoke access from
     * @param revokedBy User ID of the person revoking access
     * @return Number of permissions revoked
     */
    @Transactional
    public int revokeAllReportAccess(Long userId, Long revokedBy) {
        try {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new IllegalArgumentException("User not found with ID: " + userId));
            
            int revokedCount = user.getReportPermissions().size();
            user.getReportPermissions().clear();
            userRepository.save(user);
            
            log.info("Revoked all {} report permissions from user: {} (ID: {}) by user ID: {}", 
                    revokedCount, user.getUsername(), userId, revokedBy);
            
            return revokedCount;
            
        } catch (Exception e) {
            log.error("Error revoking all report access - UserID: {}, RevokedBy: {}", userId, revokedBy, e);
            return 0;
        }
    }
    
    /**
     * Get report access summary for a user
     * 
     * @param userId User ID to get summary for
     * @return Map containing report access summary
     */
    public java.util.Map<String, Object> getReportAccessSummary(Long userId) {
        try {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new IllegalArgumentException("User not found with ID: " + userId));
            
            Set<ReportType> accessibleReports = getUserReportAccess(userId);
            Set<ReportType> allReports = Set.of(ReportType.values());
            
            java.util.Map<String, Object> summary = new java.util.HashMap<>();
            summary.put("userId", userId);
            summary.put("username", user.getUsername());
            summary.put("isSuperAdmin", user.hasRole(com.acme.claims.security.Role.SUPER_ADMIN));
            summary.put("isFacilityAdmin", user.hasRole(com.acme.claims.security.Role.FACILITY_ADMIN));
            summary.put("isStaff", user.hasRole(com.acme.claims.security.Role.STAFF));
            summary.put("accessibleReports", accessibleReports);
            summary.put("totalReports", allReports.size());
            summary.put("accessibleCount", accessibleReports.size());
            summary.put("hasAllReports", accessibleReports.containsAll(allReports));
            
            log.debug("Report access summary generated for user: {} (ID: {})", 
                    user.getUsername(), userId);
            
            return summary;
            
        } catch (Exception e) {
            log.error("Error generating report access summary - UserID: {}", userId, e);
            return java.util.Map.of("error", "Failed to generate summary");
        }
    }
}
