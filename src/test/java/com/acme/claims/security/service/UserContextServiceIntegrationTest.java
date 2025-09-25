package com.acme.claims.security.service;

import com.acme.claims.security.Role;
import com.acme.claims.security.SecurityIntegrationTestBase;
import com.acme.claims.security.context.UserContext;
import com.acme.claims.security.entity.User;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.context.SecurityContextImpl;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Integration tests for UserContextService.
 * 
 * Tests the UserContextService functionality including user context retrieval,
 * permission checking, and facility access validation.
 */
public class UserContextServiceIntegrationTest extends SecurityIntegrationTestBase {

    @Autowired
    private UserContextService userContextService;

    @Test
    void testGetCurrentUserContext_SuperAdmin() {
        // Setup security context
        setupSecurityContext(superAdmin);

        // Test user context retrieval
        UserContext context = userContextService.getCurrentUserContext();

        // Assertions
        assertNotNull(context);
        assertEquals(superAdmin.getId(), context.getUserId());
        assertEquals(superAdmin.getUsername(), context.getUsername());
        assertEquals(superAdmin.getEmail(), context.getEmail());
        assertTrue(context.isSuperAdmin());
        assertFalse(context.isFacilityAdmin());
        assertFalse(context.isStaff());
        assertTrue(context.hasRole(Role.SUPER_ADMIN));
    }

    @Test
    void testGetCurrentUserContext_FacilityAdmin() {
        // Setup security context
        setupSecurityContext(facilityAdmin);

        // Test user context retrieval
        UserContext context = userContextService.getCurrentUserContext();

        // Assertions
        assertNotNull(context);
        assertEquals(facilityAdmin.getId(), context.getUserId());
        assertEquals(facilityAdmin.getUsername(), context.getUsername());
        assertTrue(context.isFacilityAdmin());
        assertFalse(context.isSuperAdmin());
        assertFalse(context.isStaff());
        assertTrue(context.hasRole(Role.FACILITY_ADMIN));
        assertEquals(Set.of("FACILITY_001", "FACILITY_002"), context.getFacilities());
    }

    @Test
    void testGetCurrentUserContext_Staff() {
        // Setup security context
        setupSecurityContext(staff);

        // Test user context retrieval
        UserContext context = userContextService.getCurrentUserContext();

        // Assertions
        assertNotNull(context);
        assertEquals(staff.getId(), context.getUserId());
        assertEquals(staff.getUsername(), context.getUsername());
        assertTrue(context.isStaff());
        assertFalse(context.isSuperAdmin());
        assertFalse(context.isFacilityAdmin());
        assertTrue(context.hasRole(Role.STAFF));
        assertEquals(Set.of("FACILITY_001"), context.getFacilities());
    }

    @Test
    void testHasFacilityAccess_SuperAdmin() {
        // Setup security context
        setupSecurityContext(superAdmin);

        // Test facility access - super admin should have access to all facilities
        assertTrue(userContextService.hasFacilityAccess("FACILITY_001"));
        assertTrue(userContextService.hasFacilityAccess("FACILITY_002"));
        assertTrue(userContextService.hasFacilityAccess("FACILITY_999")); // Non-existent facility
    }

    @Test
    void testHasFacilityAccess_FacilityAdmin() {
        // Setup security context
        setupSecurityContext(facilityAdmin);

        // Test facility access - facility admin should have access to assigned facilities
        assertTrue(userContextService.hasFacilityAccess("FACILITY_001"));
        assertTrue(userContextService.hasFacilityAccess("FACILITY_002"));
        assertFalse(userContextService.hasFacilityAccess("FACILITY_999")); // Non-assigned facility
    }

    @Test
    void testHasFacilityAccess_Staff() {
        // Setup security context
        setupSecurityContext(staff);

        // Test facility access - staff should have access only to assigned facilities
        assertTrue(userContextService.hasFacilityAccess("FACILITY_001"));
        assertFalse(userContextService.hasFacilityAccess("FACILITY_002"));
        assertFalse(userContextService.hasFacilityAccess("FACILITY_999")); // Non-assigned facility
    }

    @Test
    void testGetUserFacilities() {
        // Setup security context
        setupSecurityContext(facilityAdmin);

        // Test facility retrieval
        Set<String> facilities = userContextService.getUserFacilities();

        // Assertions
        assertNotNull(facilities);
        assertEquals(2, facilities.size());
        assertTrue(facilities.contains("FACILITY_001"));
        assertTrue(facilities.contains("FACILITY_002"));
    }

    @Test
    void testGetPrimaryFacility() {
        // Setup security context
        setupSecurityContext(staff);

        // Test primary facility retrieval
        String primaryFacility = userContextService.getPrimaryFacility();

        // Assertions
        assertNotNull(primaryFacility);
        assertEquals("FACILITY_001", primaryFacility);
    }

    @Test
    void testRoleChecking() {
        // Test super admin role checking
        setupSecurityContext(superAdmin);
        assertTrue(userContextService.isSuperAdmin());
        assertFalse(userContextService.isFacilityAdmin());
        assertFalse(userContextService.isStaff());

        // Test facility admin role checking
        setupSecurityContext(facilityAdmin);
        assertFalse(userContextService.isSuperAdmin());
        assertTrue(userContextService.isFacilityAdmin());
        assertFalse(userContextService.isStaff());

        // Test staff role checking
        setupSecurityContext(staff);
        assertFalse(userContextService.isSuperAdmin());
        assertFalse(userContextService.isFacilityAdmin());
        assertTrue(userContextService.isStaff());
    }

    @Test
    void testGetCurrentUserId() {
        // Setup security context
        setupSecurityContext(superAdmin);

        // Test user ID retrieval
        Long userId = userContextService.getCurrentUserId();

        // Assertions
        assertNotNull(userId);
        assertEquals(superAdmin.getId(), userId);
    }

    @Test
    void testGetCurrentUsername() {
        // Setup security context
        setupSecurityContext(superAdmin);

        // Test username retrieval
        String username = userContextService.getCurrentUsername();

        // Assertions
        assertNotNull(username);
        assertEquals(superAdmin.getUsername(), username);
    }

    @Test
    void testLogUserContext() {
        // Setup security context
        setupSecurityContext(superAdmin);

        // Test context logging (should not throw exception)
        assertDoesNotThrow(() -> userContextService.logUserContext("test-operation"));
    }

    /**
     * Setup security context for testing
     */
    private void setupSecurityContext(User user) {
        UsernamePasswordAuthenticationToken authentication = 
                new UsernamePasswordAuthenticationToken(user, null, user.getAuthorities());
        SecurityContextHolder.setContext(new SecurityContextImpl(authentication));
    }
}
