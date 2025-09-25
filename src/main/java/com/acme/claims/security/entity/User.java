package com.acme.claims.security.entity;

import com.acme.claims.security.Role;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;

/**
 * User entity for authentication and authorization
 */
@Entity
@Table(name = "users", schema = "claims")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class User {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "username", nullable = false, unique = true, length = 50)
    private String username;
    
    @Column(name = "email", nullable = false, unique = true, length = 100)
    private String email;
    
    @Column(name = "password_hash", nullable = false)
    private String passwordHash;
    
    @Column(name = "enabled", nullable = false)
    @Builder.Default
    private Boolean enabled = true;
    
    @Column(name = "locked", nullable = false)
    @Builder.Default
    private Boolean locked = false;
    
    @Column(name = "failed_attempts", nullable = false)
    @Builder.Default
    private Integer failedAttempts = 0;
    
    @Column(name = "last_login")
    private LocalDateTime lastLogin;
    
    @Column(name = "locked_at")
    private LocalDateTime lockedAt;
    
    @Column(name = "password_changed_at", nullable = false)
    @Builder.Default
    private LocalDateTime passwordChangedAt = LocalDateTime.now();
    
    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
    
    @Column(name = "created_by")
    private Long createdBy;
    
    @Column(name = "updated_by")
    private Long updatedBy;
    
    // Relationships
    
    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private Set<UserRole> roles = new HashSet<>();
    
    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private Set<UserFacility> facilities = new HashSet<>();
    
    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private Set<UserReportPermission> reportPermissions = new HashSet<>();
    
    // Helper methods
    
    /**
     * Check if user has a specific role
     */
    public boolean hasRole(Role role) {
        return roles.stream()
                .anyMatch(userRole -> userRole.getRole() == role);
    }
    
    /**
     * Check if user has any of the specified roles
     */
    public boolean hasAnyRole(Role... roles) {
        for (Role role : roles) {
            if (hasRole(role)) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * Get primary facility code
     */
    public String getPrimaryFacilityCode() {
        return facilities.stream()
                .filter(UserFacility::getIsPrimary)
                .map(UserFacility::getFacilityCode)
                .findFirst()
                .orElse(null);
    }
    
    /**
     * Get all facility codes for this user
     */
    public Set<String> getFacilityCodes() {
        return facilities.stream()
                .map(UserFacility::getFacilityCode)
                .collect(java.util.stream.Collectors.toSet());
    }
    
    /**
     * Check if user is account locked
     */
    public boolean isAccountLocked() {
        return locked || (failedAttempts >= 3);
    }
    
    /**
     * Reset failed attempts
     */
    public void resetFailedAttempts() {
        this.failedAttempts = 0;
        this.locked = false;
        this.lockedAt = null;
    }
    
    /**
     * Increment failed attempts
     */
    public void incrementFailedAttempts() {
        this.failedAttempts++;
        if (this.failedAttempts >= 3) {
            this.locked = true;
            this.lockedAt = LocalDateTime.now();
        }
    }
    
    /**
     * Check if account is locked due to failed attempts
     */
    public boolean isLockedDueToFailedAttempts() {
        return locked && failedAttempts >= 3;
    }
    
    /**
     * Check if account is manually locked by admin
     */
    public boolean isManuallyLocked() {
        return locked && failedAttempts < 3;
    }
}
