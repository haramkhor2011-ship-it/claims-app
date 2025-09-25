package com.acme.claims.security.controller;

import com.acme.claims.security.Role;
import com.acme.claims.security.entity.User;
import com.acme.claims.security.service.UserService;
import jakarta.validation.Valid;
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
 * User management controller
 */
@Slf4j
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {
    
    private final UserService userService;
    
    /**
     * Create a new user
     */
    @PostMapping
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<?> createUser(@Valid @RequestBody CreateUserRequest request, 
                                      Authentication authentication) {
        User currentUser = (User) authentication.getPrincipal();
        
        // Check if current user can create the target role
        if (!userService.canCreateUser(currentUser, request.getRole())) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "Insufficient permissions to create user with role: " + request.getRole()));
        }
        
        try {
            User newUser;
            
            if (request.getRole() == Role.FACILITY_ADMIN) {
                if (request.getFacilityCode() == null) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Facility code is required for facility admin"));
                }
                newUser = userService.createFacilityAdmin(
                        request.getUsername(),
                        request.getEmail(),
                        request.getPassword(),
                        request.getFacilityCode(),
                        currentUser.getId()
                );
            } else if (request.getRole() == Role.STAFF) {
                if (request.getFacilityCode() == null) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Facility code is required for staff"));
                }
                newUser = userService.createStaff(
                        request.getUsername(),
                        request.getEmail(),
                        request.getPassword(),
                        request.getFacilityCode(),
                        currentUser.getId()
                );
            } else {
                return ResponseEntity.badRequest()
                        .body(Map.of("error", "Invalid role for user creation"));
            }
            
            return ResponseEntity.ok(UserResponse.fromUser(newUser));
            
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
    
    /**
     * Get all users
     */
    @GetMapping
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<List<UserResponse>> getAllUsers(Authentication authentication) {
        User currentUser = (User) authentication.getPrincipal();
        List<User> users;
        
        if (currentUser.hasRole(Role.SUPER_ADMIN)) {
            users = userService.getAllUsers();
        } else {
            // Facility admin can only see users from their facilities
            Set<String> facilityCodes = currentUser.getFacilityCodes();
            users = userService.getAllUsers().stream()
                    .filter(user -> user.getFacilityCodes().stream()
                            .anyMatch(facilityCodes::contains))
                    .toList();
        }
        
        List<UserResponse> userResponses = users.stream()
                .map(UserResponse::fromUser)
                .toList();
        
        return ResponseEntity.ok(userResponses);
    }
    
    /**
     * Get user by ID
     */
    @GetMapping("/{id}")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<?> getUserById(@PathVariable Long id, Authentication authentication) {
        User currentUser = (User) authentication.getPrincipal();
        
        return userService.findById(id)
                .map(user -> {
                    // Check if current user can manage this user
                    if (!userService.canManageUser(currentUser, user)) {
                        return ResponseEntity.badRequest()
                                .body(Map.of("error", "Insufficient permissions to view this user"));
                    }
                    return ResponseEntity.ok(UserResponse.fromUser(user));
                })
                .orElse(ResponseEntity.notFound().build());
    }
    
    /**
     * Update user
     */
    @PutMapping("/{id}")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<?> updateUser(@PathVariable Long id, 
                                      @Valid @RequestBody UpdateUserRequest request,
                                      Authentication authentication) {
        User currentUser = (User) authentication.getPrincipal();
        
        return userService.findById(id)
                .map(user -> {
                    // Check if current user can manage this user
                    if (!userService.canManageUser(currentUser, user)) {
                        return ResponseEntity.badRequest()
                                .body(Map.of("error", "Insufficient permissions to update this user"));
                    }
                    
                    // Update user fields
                    if (request.getEmail() != null) {
                        user.setEmail(request.getEmail());
                    }
                    if (request.getEnabled() != null) {
                        userService.setUserEnabled(user, request.getEnabled(), currentUser.getId());
                    }
                    
                    User updatedUser = userService.updateUser(user);
                    return ResponseEntity.ok(UserResponse.fromUser(updatedUser));
                })
                .orElse(ResponseEntity.notFound().build());
    }
    
    /**
     * Change user password
     */
    @PostMapping("/{id}/change-password")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<?> changePassword(@PathVariable Long id,
                                          @Valid @RequestBody ChangePasswordRequest request,
                                          Authentication authentication) {
        User currentUser = (User) authentication.getPrincipal();
        
        return userService.findById(id)
                .map(user -> {
                    // Check if current user can manage this user
                    if (!userService.canManageUser(currentUser, user)) {
                        return ResponseEntity.badRequest()
                                .body(Map.of("error", "Insufficient permissions to change password for this user"));
                    }
                    
                    userService.changePassword(user, request.getNewPassword(), currentUser.getId());
                    return ResponseEntity.ok(Map.of("message", "Password changed successfully"));
                })
                .orElse(ResponseEntity.notFound().build());
    }
    
    /**
     * Lock/unlock user account
     */
    @PostMapping("/{id}/lock")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<?> lockUser(@PathVariable Long id,
                                    @RequestParam boolean locked,
                                    Authentication authentication) {
        User currentUser = (User) authentication.getPrincipal();
        
        return userService.findById(id)
                .map(user -> {
                    // Check if current user can manage this user
                    if (!userService.canManageUser(currentUser, user)) {
                        return ResponseEntity.badRequest()
                                .body(Map.of("error", "Insufficient permissions to lock/unlock this user"));
                    }
                    
                    userService.setUserLocked(user, locked, currentUser.getId());
                    return ResponseEntity.ok(Map.of("message", 
                            "User " + (locked ? "locked" : "unlocked") + " successfully"));
                })
                .orElse(ResponseEntity.notFound().build());
    }
    
    /**
     * Delete user
     */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<?> deleteUser(@PathVariable Long id, Authentication authentication) {
        User currentUser = (User) authentication.getPrincipal();
        
        return userService.findById(id)
                .map(user -> {
                    // Prevent deleting super admin
                    if (user.hasRole(Role.SUPER_ADMIN)) {
                        return ResponseEntity.badRequest()
                                .body(Map.of("error", "Cannot delete super admin user"));
                    }
                    
                    userService.deleteUser(user);
                    return ResponseEntity.ok(Map.of("message", "User deleted successfully"));
                })
                .orElse(ResponseEntity.notFound().build());
    }
    
    // DTOs
    
    public static class CreateUserRequest {
        private String username;
        private String email;
        private String password;
        private Role role;
        private String facilityCode;
        
        // Getters and setters
        public String getUsername() { return username; }
        public void setUsername(String username) { this.username = username; }
        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        public String getPassword() { return password; }
        public void setPassword(String password) { this.password = password; }
        public Role getRole() { return role; }
        public void setRole(Role role) { this.role = role; }
        public String getFacilityCode() { return facilityCode; }
        public void setFacilityCode(String facilityCode) { this.facilityCode = facilityCode; }
    }
    
    public static class UpdateUserRequest {
        private String email;
        private Boolean enabled;
        
        // Getters and setters
        public String getEmail() { return email; }
        public void setEmail(String email) { this.email = email; }
        public Boolean getEnabled() { return enabled; }
        public void setEnabled(Boolean enabled) { this.enabled = enabled; }
    }
    
    public static class ChangePasswordRequest {
        private String newPassword;
        
        // Getters and setters
        public String getNewPassword() { return newPassword; }
        public void setNewPassword(String newPassword) { this.newPassword = newPassword; }
    }
    
    public static class UserResponse {
        private Long id;
        private String username;
        private String email;
        private Boolean enabled;
        private Boolean locked;
        private Integer failedAttempts;
        private java.time.LocalDateTime lastLogin;
        private java.time.LocalDateTime createdAt;
        private List<String> roles;
        private Set<String> facilities;
        private String primaryFacility;
        
        public static UserResponse fromUser(User user) {
            UserResponse response = new UserResponse();
            response.id = user.getId();
            response.username = user.getUsername();
            response.email = user.getEmail();
            response.enabled = user.getEnabled();
            response.locked = user.getLocked();
            response.failedAttempts = user.getFailedAttempts();
            response.lastLogin = user.getLastLogin();
            response.createdAt = user.getCreatedAt();
            response.roles = user.getRoles().stream()
                    .map(role -> role.getRole().name())
                    .toList();
            response.facilities = user.getFacilityCodes();
            response.primaryFacility = user.getPrimaryFacilityCode();
            return response;
        }
        
        // Getters
        public Long getId() { return id; }
        public String getUsername() { return username; }
        public String getEmail() { return email; }
        public Boolean getEnabled() { return enabled; }
        public Boolean getLocked() { return locked; }
        public Integer getFailedAttempts() { return failedAttempts; }
        public java.time.LocalDateTime getLastLogin() { return lastLogin; }
        public java.time.LocalDateTime getCreatedAt() { return createdAt; }
        public List<String> getRoles() { return roles; }
        public Set<String> getFacilities() { return facilities; }
        public String getPrimaryFacility() { return primaryFacility; }
    }
}
