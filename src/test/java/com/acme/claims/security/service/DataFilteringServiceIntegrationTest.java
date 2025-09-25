package com.acme.claims.security.service;

import com.acme.claims.security.ReportType;
import com.acme.claims.security.SecurityIntegrationTestBase;
import com.acme.claims.security.entity.User;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.context.SecurityContextImpl;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Integration tests for DataFilteringService.
 * 
 * Tests the data filtering functionality including facility filtering,
 * report access control, and multi-tenancy toggle behavior.
 */
public class DataFilteringServiceIntegrationTest extends SecurityIntegrationTestBase {

    @Autowired
    private DataFilteringService dataFilteringService;

    @Test
    void testFilterFacilities_SuperAdmin() {
        // Setup security context
        setupSecurityContext(superAdmin);

        // Test facility filtering - super admin should get all facilities
        List<String> requestedFacilities = List.of("FACILITY_001", "FACILITY_002", "FACILITY_999");
        List<String> filteredFacilities = dataFilteringService.filterFacilities(requestedFacilities);

        // Assertions
        assertNotNull(filteredFacilities);
        assertEquals(requestedFacilities, filteredFacilities); // Super admin gets all
    }

    @Test
    void testFilterFacilities_FacilityAdmin() {
        // Setup security context
        setupSecurityContext(facilityAdmin);

        // Test facility filtering - facility admin should get only assigned facilities
        List<String> requestedFacilities = List.of("FACILITY_001", "FACILITY_002", "FACILITY_999");
        List<String> filteredFacilities = dataFilteringService.filterFacilities(requestedFacilities);

        // Assertions
        assertNotNull(filteredFacilities);
        assertEquals(2, filteredFacilities.size());
        assertTrue(filteredFacilities.contains("FACILITY_001"));
        assertTrue(filteredFacilities.contains("FACILITY_002"));
        assertFalse(filteredFacilities.contains("FACILITY_999"));
    }

    @Test
    void testFilterFacilities_Staff() {
        // Setup security context
        setupSecurityContext(staff);

        // Test facility filtering - staff should get only assigned facilities
        List<String> requestedFacilities = List.of("FACILITY_001", "FACILITY_002", "FACILITY_999");
        List<String> filteredFacilities = dataFilteringService.filterFacilities(requestedFacilities);

        // Assertions
        assertNotNull(filteredFacilities);
        assertEquals(1, filteredFacilities.size());
        assertTrue(filteredFacilities.contains("FACILITY_001"));
        assertFalse(filteredFacilities.contains("FACILITY_002"));
        assertFalse(filteredFacilities.contains("FACILITY_999"));
    }

    @Test
    void testCanAccessFacility_SuperAdmin() {
        // Setup security context
        setupSecurityContext(superAdmin);

        // Test facility access - super admin should have access to all facilities
        assertTrue(dataFilteringService.canAccessFacility("FACILITY_001"));
        assertTrue(dataFilteringService.canAccessFacility("FACILITY_002"));
        assertTrue(dataFilteringService.canAccessFacility("FACILITY_999")); // Non-existent facility
    }

    @Test
    void testCanAccessFacility_FacilityAdmin() {
        // Setup security context
        setupSecurityContext(facilityAdmin);

        // Test facility access - facility admin should have access to assigned facilities
        assertTrue(dataFilteringService.canAccessFacility("FACILITY_001"));
        assertTrue(dataFilteringService.canAccessFacility("FACILITY_002"));
        assertFalse(dataFilteringService.canAccessFacility("FACILITY_999")); // Non-assigned facility
    }

    @Test
    void testCanAccessFacility_Staff() {
        // Setup security context
        setupSecurityContext(staff);

        // Test facility access - staff should have access only to assigned facilities
        assertTrue(dataFilteringService.canAccessFacility("FACILITY_001"));
        assertFalse(dataFilteringService.canAccessFacility("FACILITY_002"));
        assertFalse(dataFilteringService.canAccessFacility("FACILITY_999")); // Non-assigned facility
    }

    @Test
    void testGetFacilityFilterClause_SuperAdmin() {
        // Setup security context
        setupSecurityContext(superAdmin);

        // Test SQL filter clause generation - super admin should get empty clause
        String filterClause = dataFilteringService.getFacilityFilterClause("facility_code");

        // Assertions
        assertNotNull(filterClause);
        assertEquals("", filterClause); // Super admin gets no filtering
    }

    @Test
    void testGetFacilityFilterClause_FacilityAdmin() {
        // Setup security context
        setupSecurityContext(facilityAdmin);

        // Test SQL filter clause generation - facility admin should get IN clause
        String filterClause = dataFilteringService.getFacilityFilterClause("facility_code");

        // Assertions
        assertNotNull(filterClause);
        assertTrue(filterClause.contains("facility_code"));
        assertTrue(filterClause.contains("FACILITY_001"));
        assertTrue(filterClause.contains("FACILITY_002"));
    }

    @Test
    void testGetFacilityFilterClause_Staff() {
        // Setup security context
        setupSecurityContext(staff);

        // Test SQL filter clause generation - staff should get IN clause for assigned facilities
        String filterClause = dataFilteringService.getFacilityFilterClause("facility_code");

        // Assertions
        assertNotNull(filterClause);
        assertTrue(filterClause.contains("facility_code"));
        assertTrue(filterClause.contains("FACILITY_001"));
        assertFalse(filterClause.contains("FACILITY_002"));
    }

    @Test
    void testGetFacilityFilterWithParameters_SuperAdmin() {
        // Setup security context
        setupSecurityContext(superAdmin);

        // Test parameterized filter generation - super admin should get empty clause
        Object[] filterWithParams = dataFilteringService.getFacilityFilterWithParameters("facility_code");

        // Assertions
        assertNotNull(filterWithParams);
        assertEquals(2, filterWithParams.length);
        assertEquals("", filterWithParams[0]); // Empty clause
        assertEquals(0, ((Object[]) filterWithParams[1]).length); // No parameters
    }

    @Test
    void testGetFacilityFilterWithParameters_FacilityAdmin() {
        // Setup security context
        setupSecurityContext(facilityAdmin);

        // Test parameterized filter generation - facility admin should get IN clause with parameters
        Object[] filterWithParams = dataFilteringService.getFacilityFilterWithParameters("facility_code");

        // Assertions
        assertNotNull(filterWithParams);
        assertEquals(2, filterWithParams.length);
        String clause = (String) filterWithParams[0];
        Object[] parameters = (Object[]) filterWithParams[1];
        
        assertTrue(clause.contains("facility_code"));
        assertTrue(clause.contains("?"));
        assertEquals(2, parameters.length);
        assertTrue(List.of(parameters).contains("FACILITY_001"));
        assertTrue(List.of(parameters).contains("FACILITY_002"));
    }

    @Test
    void testCanAccessReport_SuperAdmin() {
        // Setup security context
        setupSecurityContext(superAdmin);

        // Test report access - super admin should have access to all reports
        assertTrue(dataFilteringService.canAccessReport(ReportType.BALANCE_AMOUNT_REPORT.name()));
        assertTrue(dataFilteringService.canAccessReport(ReportType.CLAIM_DETAILS_WITH_ACTIVITY.name()));
        assertTrue(dataFilteringService.canAccessReport("NON_EXISTENT_REPORT"));
    }

    @Test
    void testCanAccessReport_FacilityAdmin() {
        // Setup security context
        setupSecurityContext(facilityAdmin);

        // Test report access - facility admin should have access to all reports
        assertTrue(dataFilteringService.canAccessReport(ReportType.BALANCE_AMOUNT_REPORT.name()));
        assertTrue(dataFilteringService.canAccessReport(ReportType.CLAIM_DETAILS_WITH_ACTIVITY.name()));
    }

    @Test
    void testCanAccessReport_Staff() {
        // Setup security context
        setupSecurityContext(staff);

        // Test report access - staff should have access only to granted reports
        // Note: Staff users need explicit report permissions granted
        assertFalse(dataFilteringService.canAccessReport(ReportType.BALANCE_AMOUNT_REPORT.name()));
        assertFalse(dataFilteringService.canAccessReport(ReportType.CLAIM_DETAILS_WITH_ACTIVITY.name()));
    }

    @Test
    void testGetUserAccessibleFacilities() {
        // Setup security context
        setupSecurityContext(facilityAdmin);

        // Test accessible facilities retrieval
        Set<String> facilities = dataFilteringService.getUserAccessibleFacilities();

        // Assertions
        assertNotNull(facilities);
        assertEquals(2, facilities.size());
        assertTrue(facilities.contains("FACILITY_001"));
        assertTrue(facilities.contains("FACILITY_002"));
    }

    @Test
    void testGetUserAccessibleReports() {
        // Setup security context
        setupSecurityContext(superAdmin);

        // Test accessible reports retrieval
        Set<String> reports = dataFilteringService.getUserAccessibleReports();

        // Assertions
        assertNotNull(reports);
        // Super admin should have access to all reports
        assertTrue(reports.containsAll(Set.of(ReportType.values()).stream()
                .map(ReportType::name)
                .toList()));
    }

    @Test
    void testLogFilteringStatus() {
        // Setup security context
        setupSecurityContext(superAdmin);

        // Test filtering status logging (should not throw exception)
        assertDoesNotThrow(() -> dataFilteringService.logFilteringStatus("test-operation"));
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
