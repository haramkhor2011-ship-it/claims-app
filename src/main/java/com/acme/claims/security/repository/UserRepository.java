package com.acme.claims.security.repository;

import com.acme.claims.security.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.Set;

/**
 * Repository for User entity
 */
@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    
    /**
     * Find user by username
     */
    Optional<User> findByUsername(String username);
    
    /**
     * Find user by email
     */
    Optional<User> findByEmail(String email);
    
    /**
     * Check if username exists
     */
    boolean existsByUsername(String username);
    
    /**
     * Check if email exists
     */
    boolean existsByEmail(String email);
    
    /**
     * Find users by facility code
     */
    @Query("SELECT DISTINCT u FROM User u JOIN u.facilities f WHERE f.facilityCode = :facilityCode")
    Set<User> findByFacilityCode(@Param("facilityCode") String facilityCode);
    
    /**
     * Find users by role
     */
    @Query("SELECT DISTINCT u FROM User u JOIN u.roles r WHERE r.role = :role")
    Set<User> findByRole(@Param("role") String role);
    
    /**
     * Find enabled users
     */
    Set<User> findByEnabledTrue();
    
    /**
     * Find locked users
     */
    Set<User> findByLockedTrue();
    
    /**
     * Find users with failed attempts
     */
    @Query("SELECT u FROM User u WHERE u.failedAttempts > 0")
    Set<User> findUsersWithFailedAttempts();
}
