package com.acme.claims.security.entity;

import com.acme.claims.security.Role;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.HashSet;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * User entity for authentication and authorization
 */
@Entity
@Table(name = "users", schema = "claims")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class User implements UserDetails {
    
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

    /**
     * Check if user is super admin
     */
    public boolean isSuperAdmin() {
        return hasRole(Role.SUPER_ADMIN);
    }

    /**
     * Check if user is facility admin
     */
    public boolean isFacilityAdmin() {
        return hasRole(Role.FACILITY_ADMIN);
    }

    /**
     * Get list of report types this user has access to
     */
    public Set<String> getReportTypeNames() {
        return reportPermissions.stream()
                .map(permission -> permission.getReportType().name())
                .collect(java.util.stream.Collectors.toSet());
    }

    // UserDetails implementation

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return roles.stream()
                .map(userRole -> new SimpleGrantedAuthority("ROLE_" + userRole.getRole().name()))
                .collect(Collectors.toList());
    }

    @Override
    public String getPassword() {
        return passwordHash;
    }

    @Override
    public String getUsername() {
        return username;
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return !locked && failedAttempts < 3;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return enabled;
    }
}
