package com.acme.claims.security;

import com.acme.claims.security.entity.User;
import com.acme.claims.security.repository.UserRepository;
import com.acme.claims.security.service.ReportAccessService;
import com.acme.claims.security.service.UserContextService;
import com.acme.claims.security.service.DataFilteringService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureWebMvc;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.context.SecurityContextImpl;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * End-to-end integration tests for the complete security system.
 * 
 * Tests the integration of all security components including authentication,
 * authorization, user context, data filtering, and report access control.
 */
@AutoConfigureWebMvc
public class SecurityEndToEndIntegrationTest extends SecurityIntegrationTestBase {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ReportAccessService reportAccessService;

    @Autowired
    private UserContextService userContextService;

    @Autowired
    private DataFilteringService dataFilteringService;

    @Test
    void testCompleteSecurityFlow_SuperAdmin() throws Exception {
        // Test complete security flow for super admin
        mockMvc.perform(get("/api/reports/data/available")
                .with(user(superAdmin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user").value(superAdmin.getUsername()))
                .andExpect(jsonPath("$.totalReports").exists());

        mockMvc.perform(get("/api/admin/facilities"))
                .with(user(superAdmin)))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/users"))
                .with(user(superAdmin)))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/reports/views/mappings"))
                .with(user(superAdmin)))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/admin/report-access/report-types"))
                .with(user(superAdmin)))
                .andExpect(status().isOk());
    }

    @Test
    void testCompleteSecurityFlow_FacilityAdmin() throws Exception {
        // Test complete security flow for facility admin
        mockMvc.perform(get("/api/reports/data/available")
                .with(user(facilityAdmin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user").value(facilityAdmin.getUsername()));

        mockMvc.perform(get("/api/admin/facilities"))
                .with(user(facilityAdmin)))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/users"))
                .with(user(facilityAdmin)))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/reports/views/mappings"))
                .with(user(facilityAdmin)))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/admin/report-access/report-types"))
                .with(user(facilityAdmin)))
                .andExpect(status().isOk());
    }

    @Test
    void testCompleteSecurityFlow_Staff() throws Exception {
        // Test complete security flow for staff
        mockMvc.perform(get("/api/reports/data/available")
                .with(user(staff)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user").value(staff.getUsername()));

        // Staff should not have access to admin endpoints
        mockMvc.perform(get("/api/admin/facilities"))
                .with(user(staff)))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/users"))
                .with(user(staff)))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/reports/views/mappings"))
                .with(user(staff)))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/admin/report-access/report-types"))
                .with(user(staff)))
                .andExpect(status().isForbidden());
    }

    @Test
    void testReportAccessControl_StaffWithPermissions() throws Exception {
        // Grant report access to staff
        reportAccessService.grantReportAccess(
                staff.getId(), 
                com.acme.claims.security.ReportType.BALANCE_AMOUNT_REPORT, 
                superAdmin.getId());

        // Test that staff can access granted reports
        mockMvc.perform(get("/api/reports/data/balance-amount")
                .with(user(staff)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reportType").value("BALANCE_AMOUNT_REPORT"));

        // Test that staff cannot access non-granted reports
        mockMvc.perform(get("/api/reports/data/claim-details-activity")
                .with(user(staff)))
                .andExpect(status().isForbidden());
    }

    @Test
    void testReportAccessControl_StaffWithoutPermissions() throws Exception {
        // Test that staff cannot access reports without permissions
        mockMvc.perform(get("/api/reports/data/balance-amount")
                .with(user(staff)))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/reports/data/claim-details-activity")
                .with(user(staff)))
                .andExpect(status().isForbidden());
    }

    @Test
    void testDataFilteringIntegration() throws Exception {
        // Test data filtering integration
        mockMvc.perform(get("/api/security/filtering/context")
                .with(user(facilityAdmin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user").value(facilityAdmin.getUsername()))
                .andExpect(jsonPath("$.facilities").isArray())
                .andExpect(jsonPath("$.facilities").value(org.hamcrest.Matchers.containsInAnyOrder("FACILITY_001", "FACILITY_002")));

        mockMvc.perform(get("/api/security/filtering/test/facility/FACILITY_001")
                .with(user(facilityAdmin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.canAccess").value(true));

        mockMvc.perform(get("/api/security/filtering/test/facility/FACILITY_999")
                .with(user(facilityAdmin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.canAccess").value(false));
    }

    @Test
    void testReportAccessManagement_SuperAdmin() throws Exception {
        // Test report access management for super admin
        mockMvc.perform(get("/api/admin/report-access/report-types")
                .with(user(superAdmin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reportTypes").isArray())
                .andExpect(jsonPath("$.totalTypes").exists());

        mockMvc.perform(get("/api/admin/report-access/users/BALANCE_AMOUNT_REPORT")
                .with(user(superAdmin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reportType").value("BALANCE_AMOUNT_REPORT"))
                .andExpect(jsonPath("$.users").isArray());
    }

    @Test
    void testReportAccessManagement_FacilityAdmin() throws Exception {
        // Test report access management for facility admin
        mockMvc.perform(get("/api/admin/report-access/report-types")
                .with(user(facilityAdmin)))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/admin/report-access/users/BALANCE_AMOUNT_REPORT")
                .with(user(facilityAdmin)))
                .andExpect(status().isOk());
    }

    @Test
    void testReportAccessManagement_Staff_Denied() throws Exception {
        // Test that staff cannot access report access management
        mockMvc.perform(get("/api/admin/report-access/report-types")
                .with(user(staff)))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/admin/report-access/users/BALANCE_AMOUNT_REPORT")
                .with(user(staff)))
                .andExpect(status().isForbidden());
    }

    @Test
    void testUserContextIntegration() throws Exception {
        // Test user context integration
        mockMvc.perform(get("/api/security/filtering/context")
                .with(user(superAdmin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user").value(superAdmin.getUsername()))
                .andExpect(jsonPath("$.userId").value(superAdmin.getId()))
                .andExpect(jsonPath("$.isSuperAdmin").value(true))
                .andExpect(jsonPath("$.isFacilityAdmin").value(false))
                .andExpect(jsonPath("$.isStaff").value(false));

        mockMvc.perform(get("/api/security/filtering/context")
                .with(user(facilityAdmin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user").value(facilityAdmin.getUsername()))
                .andExpect(jsonPath("$.userId").value(facilityAdmin.getId()))
                .andExpect(jsonPath("$.isSuperAdmin").value(false))
                .andExpect(jsonPath("$.isFacilityAdmin").value(true))
                .andExpect(jsonPath("$.isStaff").value(false));

        mockMvc.perform(get("/api/security/filtering/context")
                .with(user(staff)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user").value(staff.getUsername()))
                .andExpect(jsonPath("$.userId").value(staff.getId()))
                .andExpect(jsonPath("$.isSuperAdmin").value(false))
                .andExpect(jsonPath("$.isFacilityAdmin").value(false))
                .andExpect(jsonPath("$.isStaff").value(true));
    }

    @Test
    void testFacilityAccessControl() throws Exception {
        // Test facility access control
        mockMvc.perform(get("/api/security/filtering/test/facility/FACILITY_001")
                .with(user(staff)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.canAccess").value(true));

        mockMvc.perform(get("/api/security/filtering/test/facility/FACILITY_002")
                .with(user(staff)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.canAccess").value(false));

        mockMvc.perform(get("/api/security/filtering/test/facility/FACILITY_001")
                .with(user(facilityAdmin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.canAccess").value(true));

        mockMvc.perform(get("/api/security/filtering/test/facility/FACILITY_002")
                .with(user(facilityAdmin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.canAccess").value(true));
    }

    @Test
    void testReportAccessSummary() throws Exception {
        // Test report access summary
        mockMvc.perform(get("/api/reports/data/access-summary")
                .with(user(superAdmin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(superAdmin.getId()))
                .andExpect(jsonPath("$.isSuperAdmin").value(true))
                .andExpect(jsonPath("$.hasAllReports").value(true));

        mockMvc.perform(get("/api/reports/data/access-summary")
                .with(user(staff)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(staff.getId()))
                .andExpect(jsonPath("$.isStaff").value(true))
                .andExpect(jsonPath("$.hasAllReports").value(false));
    }

    @Test
    void testSwaggerDocumentationAccess() throws Exception {
        // Test that Swagger documentation is accessible
        mockMvc.perform(get("/swagger-ui/index.html"))
                .andExpect(status().isOk());

        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk());
    }

    @Test
    void testHealthCheckEndpoints() throws Exception {
        // Test that health check endpoints are accessible
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk());

        mockMvc.perform(get("/actuator/info"))
                .andExpect(status().isOk());
    }
}
