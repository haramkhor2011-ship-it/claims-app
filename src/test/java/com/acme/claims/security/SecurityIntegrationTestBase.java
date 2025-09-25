package com.acme.claims.security;

import com.acme.claims.security.entity.User;
import com.acme.claims.security.entity.UserFacility;
import com.acme.claims.security.entity.UserRole;
import com.acme.claims.security.repository.UserRepository;
import com.acme.claims.security.service.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureWebMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Set;

/**
 * Base class for security integration tests.
 * 
 * This class provides common setup and utilities for testing security features
 * including user creation, authentication, and authorization scenarios.
 */
@SpringBootTest
@AutoConfigureWebMvc
@ActiveProfiles("test")
@Transactional
public abstract class SecurityIntegrationTestBase {

    @Autowired
    protected UserService userService;

    @Autowired
    protected UserRepository userRepository;

    @Autowired
    protected PasswordEncoder passwordEncoder;

    protected User superAdmin;
    protected User facilityAdmin;
    protected User staff;

    @BeforeEach
    void setUpSecurityTestData() {
        // Clean up existing test data
        userRepository.deleteAll();

        // Create test users
        createTestUsers();
    }

    /**
     * Create test users for security testing
     */
    private void createTestUsers() {
        // Create Super Admin
        superAdmin = User.builder()
                .username("test-super-admin")
                .email("superadmin@test.com")
                .passwordHash(passwordEncoder.encode("password123"))
                .enabled(true)
                .locked(false)
                .failedAttempts(0)
                .createdAt(LocalDateTime.now())
                .passwordChangedAt(LocalDateTime.now())
                .build();
        superAdmin.getRoles().add(UserRole.builder().user(superAdmin).role(Role.SUPER_ADMIN).build());
        superAdmin = userRepository.save(superAdmin);

        // Create Facility Admin
        facilityAdmin = User.builder()
                .username("test-facility-admin")
                .email("facilityadmin@test.com")
                .passwordHash(passwordEncoder.encode("password123"))
                .enabled(true)
                .locked(false)
                .failedAttempts(0)
                .createdAt(LocalDateTime.now())
                .passwordChangedAt(LocalDateTime.now())
                .build();
        facilityAdmin.getRoles().add(UserRole.builder().user(facilityAdmin).role(Role.FACILITY_ADMIN).build());
        facilityAdmin.getFacilities().add(UserFacility.builder().user(facilityAdmin).facilityCode("FACILITY_001").build());
        facilityAdmin.getFacilities().add(UserFacility.builder().user(facilityAdmin).facilityCode("FACILITY_002").build());
        facilityAdmin = userRepository.save(facilityAdmin);

        // Create Staff
        staff = User.builder()
                .username("test-staff")
                .email("staff@test.com")
                .passwordHash(passwordEncoder.encode("password123"))
                .enabled(true)
                .locked(false)
                .failedAttempts(0)
                .createdAt(LocalDateTime.now())
                .passwordChangedAt(LocalDateTime.now())
                .build();
        staff.getRoles().add(UserRole.builder().user(staff).role(Role.STAFF).build());
        staff.getFacilities().add(UserFacility.builder().user(staff).facilityCode("FACILITY_001").build());
        staff = userRepository.save(staff);
    }

    /**
     * Get JWT token for a user (simplified for testing)
     * In real tests, you would use the actual JWT service
     */
    protected String getJwtToken(User user) {
        // This is a placeholder - in real tests, you would generate actual JWT tokens
        return "Bearer test-jwt-token-for-" + user.getUsername();
    }

    /**
     * Create a test user with specific role and facilities
     */
    protected User createTestUser(String username, String email, Role role, Set<String> facilities) {
        User user = User.builder()
                .username(username)
                .email(email)
                .passwordHash(passwordEncoder.encode("password123"))
                .enabled(true)
                .locked(false)
                .failedAttempts(0)
                .createdAt(LocalDateTime.now())
                .passwordChangedAt(LocalDateTime.now())
                .build();

        user.getRoles().add(UserRole.builder().user(user).role(role).build());

        if (facilities != null) {
            for (String facility : facilities) {
                user.getFacilities().add(UserFacility.builder().user(user).facilityCode(facility).build());
            }
        }

        return userRepository.save(user);
    }

    /**
     * Assert that a user has the expected role
     */
    protected void assertUserHasRole(User user, Role expectedRole) {
        assert user.getRoles().stream()
                .anyMatch(userRole -> userRole.getRole().equals(expectedRole)) :
                "User " + user.getUsername() + " should have role " + expectedRole;
    }

    /**
     * Assert that a user has the expected facilities
     */
    protected void assertUserHasFacilities(User user, Set<String> expectedFacilities) {
        Set<String> userFacilities = user.getFacilityCodes();
        assert userFacilities.containsAll(expectedFacilities) :
                "User " + user.getUsername() + " should have facilities " + expectedFacilities + 
                " but has " + userFacilities;
    }
}
