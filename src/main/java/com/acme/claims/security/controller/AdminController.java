package com.acme.claims.security.controller;

import com.acme.claims.security.entity.User;
import com.acme.claims.security.service.UserService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Admin controller for account management
 */
@Slf4j
@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminController {
    
    private final UserService userService;
    
    /**
     * Get all locked accounts
     */
    @GetMapping("/locked-accounts")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<List<LockedAccountInfo>> getLockedAccounts(Authentication authentication) {
        User currentUser = (User) authentication.getPrincipal();
        
        List<User> lockedUsers = userService.getAllUsers().stream()
                .filter(User::isAccountLocked)
                .filter(user -> {
                    // TODO: When multi-tenancy is enabled, uncomment the following logic:
                    // Facility admins can only see users from their facilities
                    // if (currentUser.hasRole(com.acme.claims.security.Role.FACILITY_ADMIN)) {
                    //     Set<String> currentUserFacilities = currentUser.getFacilityCodes();
                    //     return user.getFacilityCodes().stream()
                    //             .anyMatch(currentUserFacilities::contains);
                    // }
                    return true; // When multi-tenancy disabled, all users can see all locked accounts
                })
                .toList();
        
        List<LockedAccountInfo> lockedAccounts = lockedUsers.stream()
                .map(LockedAccountInfo::fromUser)
                .toList();
        
        return ResponseEntity.ok(lockedAccounts);
    }
    
    /**
     * Unlock a user account
     */
    @PostMapping("/unlock-account/{userId}")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<?> unlockAccount(@PathVariable Long userId, Authentication authentication) {
        User currentUser = (User) authentication.getPrincipal();
        
        return userService.findById(userId)
                .map(user -> {
                    // Check if current user can manage this user
                    if (!userService.canManageUser(currentUser, user)) {
                        return ResponseEntity.badRequest()
                                .body(Map.of("error", "Insufficient permissions to unlock this user"));
                    }
                    
                    if (!user.isAccountLocked()) {
                        return ResponseEntity.badRequest()
                                .body(Map.of("error", "Account is not locked"));
                    }
                    
                    userService.setUserLocked(user, false, currentUser.getId());
                    
                    log.info("Account unlocked by {} for user: {}", 
                            currentUser.getUsername(), user.getUsername());
                    
                    return ResponseEntity.ok(Map.of(
                            "message", "Account unlocked successfully",
                            "username", user.getUsername()
                    ));
                })
                .orElse(ResponseEntity.notFound().build());
    }
    
    /**
     * Reset failed attempts for a user
     */
    @PostMapping("/reset-attempts/{userId}")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<?> resetFailedAttempts(@PathVariable Long userId, Authentication authentication) {
        User currentUser = (User) authentication.getPrincipal();
        
        return userService.findById(userId)
                .map(user -> {
                    // Check if current user can manage this user
                    if (!userService.canManageUser(currentUser, user)) {
                        return ResponseEntity.badRequest()
                                .body(Map.of("error", "Insufficient permissions to reset attempts for this user"));
                    }
                    
                    user.resetFailedAttempts();
                    userService.updateUser(user);
                    
                    log.info("Failed attempts reset by {} for user: {}", 
                            currentUser.getUsername(), user.getUsername());
                    
                    return ResponseEntity.ok(Map.of(
                            "message", "Failed attempts reset successfully",
                            "username", user.getUsername()
                    ));
                })
                .orElse(ResponseEntity.notFound().build());
    }
    
    /**
     * Get account lockout statistics
     */
    @GetMapping("/lockout-stats")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<LockoutStats> getLockoutStats() {
        List<User> allUsers = userService.getAllUsers();
        
        long totalUsers = allUsers.size();
        long lockedUsers = allUsers.stream().filter(User::isAccountLocked).count();
        long lockedByFailedAttempts = allUsers.stream()
                .filter(User::isLockedDueToFailedAttempts).count();
        long manuallyLocked = allUsers.stream()
                .filter(User::isManuallyLocked).count();
        long usersWithFailedAttempts = allUsers.stream()
                .filter(user -> user.getFailedAttempts() > 0).count();
        
        LockoutStats stats = new LockoutStats(
                totalUsers,
                lockedUsers,
                lockedByFailedAttempts,
                manuallyLocked,
                usersWithFailedAttempts
        );
        
        return ResponseEntity.ok(stats);
    }
    
    // DTOs
    
    public static class LockedAccountInfo {
        private Long id;
        private String username;
        private String email;
        private Integer failedAttempts;
        private java.time.LocalDateTime lockedAt;
        private String lockReason;
        private java.util.Set<String> facilities;
        
        public static LockedAccountInfo fromUser(User user) {
            LockedAccountInfo info = new LockedAccountInfo();
            info.id = user.getId();
            info.username = user.getUsername();
            info.email = user.getEmail();
            info.failedAttempts = user.getFailedAttempts();
            info.lockedAt = user.getLockedAt();
            info.facilities = user.getFacilityCodes();
            
            if (user.isLockedDueToFailedAttempts()) {
                info.lockReason = "Failed login attempts (" + user.getFailedAttempts() + "/3)";
            } else if (user.isManuallyLocked()) {
                info.lockReason = "Manually locked by administrator";
            } else {
                info.lockReason = "Unknown";
            }
            
            return info;
        }
        
        // Getters
        public Long getId() { return id; }
        public String getUsername() { return username; }
        public String getEmail() { return email; }
        public Integer getFailedAttempts() { return failedAttempts; }
        public java.time.LocalDateTime getLockedAt() { return lockedAt; }
        public String getLockReason() { return lockReason; }
        public java.util.Set<String> getFacilities() { return facilities; }
    }
    
    public static class LockoutStats {
        private final long totalUsers;
        private final long lockedUsers;
        private final long lockedByFailedAttempts;
        private final long manuallyLocked;
        private final long usersWithFailedAttempts;
        
        public LockoutStats(long totalUsers, long lockedUsers, long lockedByFailedAttempts, 
                          long manuallyLocked, long usersWithFailedAttempts) {
            this.totalUsers = totalUsers;
            this.lockedUsers = lockedUsers;
            this.lockedByFailedAttempts = lockedByFailedAttempts;
            this.manuallyLocked = manuallyLocked;
            this.usersWithFailedAttempts = usersWithFailedAttempts;
        }
        
        // Getters
        public long getTotalUsers() { return totalUsers; }
        public long getLockedUsers() { return lockedUsers; }
        public long getLockedByFailedAttempts() { return lockedByFailedAttempts; }
        public long getManuallyLocked() { return manuallyLocked; }
        public long getUsersWithFailedAttempts() { return usersWithFailedAttempts; }
    }
}
