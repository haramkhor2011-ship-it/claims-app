package com.acme.claims.security.service;

import com.acme.claims.security.ReportType;
import com.acme.claims.security.entity.ReportsMetadata;
import com.acme.claims.security.entity.User;
import com.acme.claims.security.entity.UserReportPermission;
import com.acme.claims.security.repository.ReportsMetadataRepository;
import com.acme.claims.security.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
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
    private final ReportsMetadataRepository reportsMetadataRepository;
    private final UserContextService userContextService;
    
    /**
     * Grant report access to a user
     * 
     * @param userId User ID to grant access to
     * @param reportCode Report code to grant access to
     * @param grantedBy User ID of the person granting access
     * @return true if access was granted successfully
     */
    @Transactional
    public boolean grantReportAccess(Long userId, String reportCode, Long grantedBy) {
        try {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new IllegalArgumentException("User not found with ID: " + userId));

            User grantedByUser = userRepository.findById(grantedBy)
                    .orElseThrow(() -> new IllegalArgumentException("Granting user not found with ID: " + grantedBy));

            ReportsMetadata reportMetadata = reportsMetadataRepository.findByReportCode(reportCode)
                    .orElseThrow(() -> new IllegalArgumentException("Report not found with code: " + reportCode));

            // Check if user already has access to this report
            boolean alreadyHasAccess = user.getReportPermissions().stream()
                    .anyMatch(permission -> permission.getReportMetadata().getReportCode().equals(reportCode));

            if (alreadyHasAccess) {
                log.info("User {} (ID: {}) already has access to report: {}",
                        user.getUsername(), userId, reportCode);
                return true;
            }

            // Grant access
            UserReportPermission permission = UserReportPermission.builder()
                    .user(user)
                    .reportMetadata(reportMetadata)
                    .grantedBy(grantedByUser)
                    .grantedAt(LocalDateTime.now())
                    .build();
            
            user.getReportPermissions().add(permission);
            userRepository.save(user);
            
            log.info("Report access granted - User: {} (ID: {}), Report: {}, GrantedBy: {}", 
                    user.getUsername(), userId, reportCode, grantedBy);
            
            return true;
            
        } catch (Exception e) {
            log.error("Error granting report access - UserID: {}, Report: {}, GrantedBy: {}", 
                    userId, reportCode, grantedBy, e);
            return false;
        }
    }
    
    /**
     * Revoke report access from a user
     * 
     * @param userId User ID to revoke access from
     * @param reportCode Report code to revoke access to
     * @param revokedBy User ID of the person revoking access
     * @return true if access was revoked successfully
     */
    @Transactional
    public boolean revokeReportAccess(Long userId, String reportCode, Long revokedBy) {
        try {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new IllegalArgumentException("User not found with ID: " + userId));
            
            // Remove the permission
            boolean removed = user.getReportPermissions().removeIf(
                    permission -> permission.getReportMetadata().getReportCode().equals(reportCode));
            
            if (removed) {
                userRepository.save(user);
                log.info("Report access revoked - User: {} (ID: {}), Report: {}, RevokedBy: {}", 
                        user.getUsername(), userId, reportCode, revokedBy);
                return true;
            } else {
                log.info("User {} (ID: {}) did not have access to report: {}", 
                        user.getUsername(), userId, reportCode);
                return false;
            }
            
        } catch (Exception e) {
            log.error("Error revoking report access - UserID: {}, Report: {}, RevokedBy: {}", 
                    userId, reportCode, revokedBy, e);
            return false;
        }
    }
    
    /**
     * Check if a user has access to a specific report type (backward compatibility)
     * 
     * @param userId User ID to check
     * @param reportType Report type to check
     * @return true if user has access
     */
    public boolean hasReportAccess(Long userId, ReportType reportType) {
        return hasReportAccess(userId, reportType.name());
    }
    
    /**
     * Check if a user has access to a specific report code
     * 
     * @param userId User ID to check
     * @param reportCode Report code to check
     * @return true if user has access
     */
    public boolean hasReportAccess(Long userId, String reportCode) {
        try {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new IllegalArgumentException("User not found with ID: " + userId));
            
            // Super admin and facility admin have access to all reports by default
            if (user.hasRole(com.acme.claims.security.Role.SUPER_ADMIN) || 
                user.hasRole(com.acme.claims.security.Role.FACILITY_ADMIN)) {
                log.debug("Admin user {} (ID: {}) has access to all reports including: {}", 
                        user.getUsername(), userId, reportCode);
                return true;
            }
            
            // Check if report exists and is active
            Optional<ReportsMetadata> reportMetadata = reportsMetadataRepository.findByReportCode(reportCode);
            if (reportMetadata.isEmpty() || !reportMetadata.get().isActive()) {
                log.debug("Report {} not found or inactive for user {} (ID: {})", 
                        reportCode, user.getUsername(), userId);
                return false;
            }
            
            // Check specific report permissions
            boolean hasAccess = user.getReportPermissions().stream()
                    .anyMatch(permission -> permission.getReportMetadata().getReportCode().equals(reportCode));
            
            log.debug("Report access check - User: {} (ID: {}), Report: {}, HasAccess: {}", 
                    user.getUsername(), userId, reportCode, hasAccess);
            
            return hasAccess;
            
        } catch (Exception e) {
            log.error("Error checking report access - UserID: {}, Report: {}", userId, reportCode, e);
            return false; // Deny access on error for security
        }
    }
    
    /**
     * Get all active report metadata a user has access to
     * 
     * @param userId User ID to check
     * @return Set of active report metadata the user can access
     */
    public Set<ReportsMetadata> getUserReportAccess(Long userId) {
        try {
            User user = userRepository.findById(userId)
                    .orElseThrow(() -> new IllegalArgumentException("User not found with ID: " + userId));
            
            // Super admin and facility admin have access to all active reports
            if (user.hasRole(com.acme.claims.security.Role.SUPER_ADMIN) || 
                user.hasRole(com.acme.claims.security.Role.FACILITY_ADMIN)) {
                Set<ReportsMetadata> allActiveReports = reportsMetadataRepository.findAllActiveReports()
                        .stream().collect(Collectors.toSet());
                log.debug("Admin user {} (ID: {}) has access to all active reports: {}", 
                        user.getUsername(), userId, allActiveReports.size());
                return allActiveReports;
            }
            
            // Get specific report permissions (only active reports)
            Set<ReportsMetadata> userReports = user.getActiveReportMetadata();
            
            log.debug("User report access - User: {} (ID: {}), Reports: {}", 
                    user.getUsername(), userId, userReports.size());
            
            return userReports;
            
        } catch (Exception e) {
            log.error("Error getting user report access - UserID: {}", userId, e);
            return Set.of(); // Return empty set on error
        }
    }
    
    /**
     * Get all users who have access to a specific report code
     * 
     * @param reportCode Report code to check
     * @return List of users with access to the report
     */
    public List<User> getUsersWithReportAccess(String reportCode) {
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
                                .anyMatch(permission -> permission.getReportMetadata().getReportCode().equals(reportCode));
                    })
                    .collect(Collectors.toList());
            
            log.info("Found {} users with access to report: {}", usersWithAccess.size(), reportCode);
            
            return usersWithAccess;
            
        } catch (Exception e) {
            log.error("Error getting users with report access - Report: {}", reportCode, e);
            return List.of();
        }
    }
    
    /**
     * Grant multiple report access permissions to a user
     * 
     * @param userId User ID to grant access to
     * @param reportCodes Set of report codes to grant access to
     * @param grantedBy User ID of the person granting access
     * @return Number of permissions granted
     */
    @Transactional
    public int grantMultipleReportAccess(Long userId, Set<String> reportCodes, Long grantedBy) {
        int grantedCount = 0;
        
        for (String reportCode : reportCodes) {
            if (grantReportAccess(userId, reportCode, grantedBy)) {
                grantedCount++;
            }
        }
        
        log.info("Granted {} out of {} report permissions to user ID: {}", 
                grantedCount, reportCodes.size(), userId);
        
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
            
            Set<ReportsMetadata> accessibleReports = getUserReportAccess(userId);
            List<ReportsMetadata> allActiveReports = reportsMetadataRepository.findAllActiveReports();
            
            java.util.Map<String, Object> summary = new java.util.HashMap<>();
            summary.put("userId", userId);
            summary.put("username", user.getUsername());
            summary.put("isSuperAdmin", user.hasRole(com.acme.claims.security.Role.SUPER_ADMIN));
            summary.put("isFacilityAdmin", user.hasRole(com.acme.claims.security.Role.FACILITY_ADMIN));
            summary.put("isStaff", user.hasRole(com.acme.claims.security.Role.STAFF));
            summary.put("accessibleReports", accessibleReports);
            summary.put("totalActiveReports", allActiveReports.size());
            summary.put("accessibleCount", accessibleReports.size());
            summary.put("hasAllReports", accessibleReports.size() == allActiveReports.size());
            
            log.debug("Report access summary generated for user: {} (ID: {})", 
                    user.getUsername(), userId);
            
            return summary;
            
        } catch (Exception e) {
            log.error("Error generating report access summary - UserID: {}", userId, e);
            return java.util.Map.of("error", "Failed to generate summary");
        }
    }
}
