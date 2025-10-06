package com.acme.claims.security.service;

import com.acme.claims.security.ReportType;
import com.acme.claims.security.Role;
import com.acme.claims.security.config.SecurityProperties;
import com.acme.claims.security.entity.User;
import com.acme.claims.security.entity.UserFacility;
import com.acme.claims.security.entity.UserReportPermission;
import com.acme.claims.security.entity.UserRole;
import com.acme.claims.security.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.Set;

/**
 * User management service
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional
public class UserService {
    
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final SecurityProperties securityProperties;
    
    /**
     * Create a new user
     */
    public User createUser(String username, String email, String password, Role role, Long createdBy) {
        log.info("Creating user: {}", username);
        
        if (userRepository.existsByUsername(username)) {
            throw new IllegalArgumentException("Username already exists: " + username);
        }
        
        if (userRepository.existsByEmail(email)) {
            throw new IllegalArgumentException("Email already exists: " + email);
        }
        
        User user = User.builder()
                .username(username)
                .email(email)
                .passwordHash(passwordEncoder.encode(password))
                .enabled(true)
                .locked(false)
                .failedAttempts(0)
                .createdBy(createdBy)
                .updatedBy(createdBy)
                .build();
        
        user = userRepository.save(user);
        
        // Add role
        addRoleToUser(user, role, createdBy);
        
        log.info("User created successfully: {}", username);
        return user;
    }
    
    /**
     * Create facility admin user
     */
    public User createFacilityAdmin(String username, String email, String password, 
                                  String facilityCode, Long createdBy) {
        User user = createUser(username, email, password, Role.FACILITY_ADMIN, createdBy);
        
        // Add facility association
        addFacilityToUser(user, facilityCode, true, createdBy);
        
        // Grant all report permissions
        grantAllReportPermissions(user, createdBy);
        
        return user;
    }
    
    /**
     * Create staff user
     */
    public User createStaff(String username, String email, String password, 
                          String facilityCode, Long createdBy) {
        User user = createUser(username, email, password, Role.STAFF, createdBy);
        
        // Add facility association
        addFacilityToUser(user, facilityCode, true, createdBy);
        
        return user;
    }
    
    /**
     * Add role to user
     */
    public void addRoleToUser(User user, Role role, Long createdBy) {
        UserRole userRole = UserRole.builder()
                .user(user)
                .role(role)
                .createdBy(createdBy)
                .build();
        
        user.getRoles().add(userRole);
        userRepository.save(user);
    }
    
    /**
     * Add facility to user
     */
    public void addFacilityToUser(User user, String facilityCode, boolean isPrimary, Long createdBy) {
        // If this is primary, unset other primary facilities
        if (isPrimary) {
            user.getFacilities().forEach(f -> f.setIsPrimary(false));
        }
        
        UserFacility userFacility = UserFacility.builder()
                .user(user)
                .facilityCode(facilityCode)
                .isPrimary(isPrimary)
                .createdBy(createdBy)
                .build();
        
        user.getFacilities().add(userFacility);
        userRepository.save(user);
    }
    
    /**
     * Grant report permission to user
     */
    public void grantReportPermission(User user, ReportType reportType, Long grantedBy) {
        UserReportPermission permission = UserReportPermission.builder()
                .user(user)
                .reportType(reportType)
                .grantedBy(User.builder().id(grantedBy).build())
                .build();
        
        user.getReportPermissions().add(permission);
        userRepository.save(user);
    }
    
    /**
     * Grant all report permissions to user
     */
    public void grantAllReportPermissions(User user, Long grantedBy) {
        for (ReportType reportType : ReportType.values()) {
            grantReportPermission(user, reportType, grantedBy);
        }
    }
    
    /**
     * Find user by username
     */
    @Transactional(readOnly = true)
    public Optional<User> findByUsername(String username) {
        return userRepository.findByUsername(username);
    }
    
    /**
     * Find user by email
     */
    @Transactional(readOnly = true)
    public Optional<User> findByEmail(String email) {
        return userRepository.findByEmail(email);
    }
    
    /**
     * Find user by ID
     */
    @Transactional(readOnly = true)
    public Optional<User> findById(Long id) {
        return userRepository.findById(id);
    }
    
    /**
     * Get all users
     */
    @Transactional(readOnly = true)
    public List<User> getAllUsers() {
        return userRepository.findAll();
    }
    
    /**
     * Get users by role
     */
    @Transactional(readOnly = true)
    public Set<User> getUsersByRole(Role role) {
        return userRepository.findByRole(role.name());
    }
    
    /**
     * Get users by facility
     */
    @Transactional(readOnly = true)
    public Set<User> getUsersByFacility(String facilityCode) {
        return userRepository.findByFacilityCode(facilityCode);
    }
    
    /**
     * Update user
     */
    public User updateUser(User user) {
        return userRepository.save(user);
    }
    
    /**
     * Change user password
     */
    public void changePassword(User user, String newPassword, Long updatedBy) {
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        user.setPasswordChangedAt(LocalDateTime.now());
        user.setUpdatedBy(updatedBy);
        user.resetFailedAttempts();
        userRepository.save(user);
        
        log.info("Password changed for user: {}", user.getUsername());
    }
    
    /**
     * Enable/disable user
     */
    public void setUserEnabled(User user, boolean enabled, Long updatedBy) {
        user.setEnabled(enabled);
        user.setUpdatedBy(updatedBy);
        if (!enabled) {
            user.setLocked(true);
        }
        userRepository.save(user);
        
        log.info("User {} {}", user.getUsername(), enabled ? "enabled" : "disabled");
    }
    
    /**
     * Lock/unlock user account
     */
    public void setUserLocked(User user, boolean locked, Long updatedBy) {
        user.setLocked(locked);
        user.setUpdatedBy(updatedBy);
        if (!locked) {
            user.resetFailedAttempts();
        } else {
            // If manually locking, set locked timestamp
            if (user.getFailedAttempts() < 3) {
                user.setLockedAt(LocalDateTime.now());
            }
        }
        userRepository.save(user);
        
        log.info("User {} {} by admin", user.getUsername(), locked ? "locked" : "unlocked");
    }
    
    /**
     * Handle failed login attempt
     */
    public void handleFailedLogin(User user) {
        user.incrementFailedAttempts();
        userRepository.save(user);
        
        log.warn("Failed login attempt for user: {} (attempts: {})", 
                user.getUsername(), user.getFailedAttempts());
    }
    
    /**
     * Handle successful login
     */
    public void handleSuccessfulLogin(User user) {
        user.resetFailedAttempts();
        user.setLastLogin(LocalDateTime.now());
        userRepository.save(user);
        
        log.info("Successful login for user: {}", user.getUsername());
    }
    
    /**
     * Delete user
     */
    public void deleteUser(User user) {
        userRepository.delete(user);
        log.info("User deleted: {}", user.getUsername());
    }
    
    /**
     * Check if user can create other users
     */
    public boolean canCreateUser(User creator, Role targetRole) {
        if (creator.hasRole(Role.SUPER_ADMIN)) {
            return true; // Super admin can create anyone
        }
        
        if (creator.hasRole(Role.FACILITY_ADMIN) && targetRole == Role.STAFF) {
            return true; // Facility admin can create staff
        }
        
        return false; // Staff cannot create anyone
    }
    
    /**
     * Check if user can manage another user
     */
    public boolean canManageUser(User manager, User target) {
        if (manager.hasRole(Role.SUPER_ADMIN)) {
            return true; // Super admin can manage anyone
        }
        
        if (manager.hasRole(Role.FACILITY_ADMIN) && target.hasRole(Role.STAFF)) {
            // Check if they share at least one facility
            Set<String> managerFacilities = manager.getFacilityCodes();
            Set<String> targetFacilities = target.getFacilityCodes();
            return managerFacilities.stream().anyMatch(targetFacilities::contains);
        }
        
        return false;
    }
}
