package com.acme.claims.security.service;

import com.acme.claims.security.ReportType;
import com.acme.claims.security.Role;
import com.acme.claims.security.SecurityIntegrationTestBase;
import com.acme.claims.security.entity.User;
import com.acme.claims.security.entity.UserReportPermission;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Integration tests for ReportAccessService.
 * 
 * Tests the report access management functionality including granting,
 * revoking, and checking report access permissions.
 */
public class ReportAccessServiceIntegrationTest extends SecurityIntegrationTestBase {

    @Autowired
    private ReportAccessService reportAccessService;

    @Test
    void testGrantReportAccess_Success() {
        // Test granting report access to staff user
        boolean success = reportAccessService.grantReportAccess(
                staff.getId(), 
                ReportType.BALANCE_AMOUNT_REPORT, 
                superAdmin.getId());

        // Assertions
        assertTrue(success);
        
        // Verify the permission was granted
        User updatedStaff = userRepository.findById(staff.getId()).orElseThrow();
        assertTrue(updatedStaff.getReportPermissions().stream()
                .anyMatch(permission -> permission.getReportType().equals(ReportType.BALANCE_AMOUNT_REPORT)));
    }

    @Test
    void testGrantReportAccess_AlreadyExists() {
        // First grant access
        reportAccessService.grantReportAccess(
                staff.getId(), 
                ReportType.BALANCE_AMOUNT_REPORT, 
                superAdmin.getId());

        // Try to grant again - should return true (already exists)
        boolean success = reportAccessService.grantReportAccess(
                staff.getId(), 
                ReportType.BALANCE_AMOUNT_REPORT, 
                superAdmin.getId());

        // Assertions
        assertTrue(success);
    }

    @Test
    void testRevokeReportAccess_Success() {
        // First grant access
        reportAccessService.grantReportAccess(
                staff.getId(), 
                ReportType.BALANCE_AMOUNT_REPORT, 
                superAdmin.getId());

        // Then revoke access
        boolean success = reportAccessService.revokeReportAccess(
                staff.getId(), 
                ReportType.BALANCE_AMOUNT_REPORT, 
                superAdmin.getId());

        // Assertions
        assertTrue(success);
        
        // Verify the permission was revoked
        User updatedStaff = userRepository.findById(staff.getId()).orElseThrow();
        assertFalse(updatedStaff.getReportPermissions().stream()
                .anyMatch(permission -> permission.getReportType().equals(ReportType.BALANCE_AMOUNT_REPORT)));
    }

    @Test
    void testRevokeReportAccess_NotExists() {
        // Try to revoke access that doesn't exist
        boolean success = reportAccessService.revokeReportAccess(
                staff.getId(), 
                ReportType.BALANCE_AMOUNT_REPORT, 
                superAdmin.getId());

        // Assertions
        assertFalse(success);
    }

    @Test
    void testHasReportAccess_SuperAdmin() {
        // Test super admin access - should have access to all reports
        assertTrue(reportAccessService.hasReportAccess(superAdmin.getId(), ReportType.BALANCE_AMOUNT_REPORT));
        assertTrue(reportAccessService.hasReportAccess(superAdmin.getId(), ReportType.CLAIM_DETAILS_WITH_ACTIVITY));
    }

    @Test
    void testHasReportAccess_FacilityAdmin() {
        // Test facility admin access - should have access to all reports
        assertTrue(reportAccessService.hasReportAccess(facilityAdmin.getId(), ReportType.BALANCE_AMOUNT_REPORT));
        assertTrue(reportAccessService.hasReportAccess(facilityAdmin.getId(), ReportType.CLAIM_DETAILS_WITH_ACTIVITY));
    }

    @Test
    void testHasReportAccess_Staff_NoAccess() {
        // Test staff access - should not have access without explicit permission
        assertFalse(reportAccessService.hasReportAccess(staff.getId(), ReportType.BALANCE_AMOUNT_REPORT));
        assertFalse(reportAccessService.hasReportAccess(staff.getId(), ReportType.CLAIM_DETAILS_WITH_ACTIVITY));
    }

    @Test
    void testHasReportAccess_Staff_WithAccess() {
        // Grant access to staff
        reportAccessService.grantReportAccess(
                staff.getId(), 
                ReportType.BALANCE_AMOUNT_REPORT, 
                superAdmin.getId());

        // Test staff access - should have access to granted report
        assertTrue(reportAccessService.hasReportAccess(staff.getId(), ReportType.BALANCE_AMOUNT_REPORT));
        assertFalse(reportAccessService.hasReportAccess(staff.getId(), ReportType.CLAIM_DETAILS_WITH_ACTIVITY));
    }

    @Test
    void testGetUserReportAccess_SuperAdmin() {
        // Test super admin report access - should have access to all reports
        Set<ReportType> accessibleReports = reportAccessService.getUserReportAccess(superAdmin.getId());

        // Assertions
        assertNotNull(accessibleReports);
        assertEquals(Set.of(ReportType.values()), accessibleReports);
    }

    @Test
    void testGetUserReportAccess_FacilityAdmin() {
        // Test facility admin report access - should have access to all reports
        Set<ReportType> accessibleReports = reportAccessService.getUserReportAccess(facilityAdmin.getId());

        // Assertions
        assertNotNull(accessibleReports);
        assertEquals(Set.of(ReportType.values()), accessibleReports);
    }

    @Test
    void testGetUserReportAccess_Staff_NoAccess() {
        // Test staff report access - should have no access without explicit permission
        Set<ReportType> accessibleReports = reportAccessService.getUserReportAccess(staff.getId());

        // Assertions
        assertNotNull(accessibleReports);
        assertTrue(accessibleReports.isEmpty());
    }

    @Test
    void testGetUserReportAccess_Staff_WithAccess() {
        // Grant access to staff
        reportAccessService.grantReportAccess(
                staff.getId(), 
                ReportType.BALANCE_AMOUNT_REPORT, 
                superAdmin.getId());
        reportAccessService.grantReportAccess(
                staff.getId(), 
                ReportType.CLAIM_DETAILS_WITH_ACTIVITY, 
                superAdmin.getId());

        // Test staff report access - should have access to granted reports
        Set<ReportType> accessibleReports = reportAccessService.getUserReportAccess(staff.getId());

        // Assertions
        assertNotNull(accessibleReports);
        assertEquals(2, accessibleReports.size());
        assertTrue(accessibleReports.contains(ReportType.BALANCE_AMOUNT_REPORT));
        assertTrue(accessibleReports.contains(ReportType.CLAIM_DETAILS_WITH_ACTIVITY));
    }

    @Test
    void testGetUsersWithReportAccess() {
        // Grant access to staff
        reportAccessService.grantReportAccess(
                staff.getId(), 
                ReportType.BALANCE_AMOUNT_REPORT, 
                superAdmin.getId());

        // Test getting users with report access
        List<User> usersWithAccess = reportAccessService.getUsersWithReportAccess(ReportType.BALANCE_AMOUNT_REPORT);

        // Assertions
        assertNotNull(usersWithAccess);
        assertTrue(usersWithAccess.size() >= 2); // Super admin, facility admin, and staff
        assertTrue(usersWithAccess.stream().anyMatch(user -> user.getId().equals(superAdmin.getId())));
        assertTrue(usersWithAccess.stream().anyMatch(user -> user.getId().equals(facilityAdmin.getId())));
        assertTrue(usersWithAccess.stream().anyMatch(user -> user.getId().equals(staff.getId())));
    }

    @Test
    void testGrantMultipleReportAccess() {
        // Test granting multiple report access permissions
        Set<ReportType> reportTypes = Set.of(
                ReportType.BALANCE_AMOUNT_REPORT,
                ReportType.CLAIM_DETAILS_WITH_ACTIVITY,
                ReportType.CLAIM_SUMMARY
        );

        int grantedCount = reportAccessService.grantMultipleReportAccess(
                staff.getId(), 
                reportTypes, 
                superAdmin.getId());

        // Assertions
        assertEquals(3, grantedCount);

        // Verify all permissions were granted
        User updatedStaff = userRepository.findById(staff.getId()).orElseThrow();
        assertEquals(3, updatedStaff.getReportPermissions().size());
        assertTrue(updatedStaff.getReportPermissions().stream()
                .anyMatch(permission -> permission.getReportType().equals(ReportType.BALANCE_AMOUNT_REPORT)));
        assertTrue(updatedStaff.getReportPermissions().stream()
                .anyMatch(permission -> permission.getReportType().equals(ReportType.CLAIM_DETAILS_WITH_ACTIVITY)));
        assertTrue(updatedStaff.getReportPermissions().stream()
                .anyMatch(permission -> permission.getReportType().equals(ReportType.CLAIM_SUMMARY)));
    }

    @Test
    void testRevokeAllReportAccess() {
        // First grant multiple permissions
        Set<ReportType> reportTypes = Set.of(
                ReportType.BALANCE_AMOUNT_REPORT,
                ReportType.CLAIM_DETAILS_WITH_ACTIVITY
        );
        reportAccessService.grantMultipleReportAccess(
                staff.getId(), 
                reportTypes, 
                superAdmin.getId());

        // Then revoke all permissions
        int revokedCount = reportAccessService.revokeAllReportAccess(
                staff.getId(), 
                superAdmin.getId());

        // Assertions
        assertEquals(2, revokedCount);

        // Verify all permissions were revoked
        User updatedStaff = userRepository.findById(staff.getId()).orElseThrow();
        assertTrue(updatedStaff.getReportPermissions().isEmpty());
    }

    @Test
    void testGetReportAccessSummary() {
        // Grant access to staff
        reportAccessService.grantReportAccess(
                staff.getId(), 
                ReportType.BALANCE_AMOUNT_REPORT, 
                superAdmin.getId());

        // Test getting report access summary
        var summary = reportAccessService.getReportAccessSummary(staff.getId());

        // Assertions
        assertNotNull(summary);
        assertEquals(staff.getId(), summary.get("userId"));
        assertEquals(staff.getUsername(), summary.get("username"));
        assertFalse((Boolean) summary.get("isSuperAdmin"));
        assertFalse((Boolean) summary.get("isFacilityAdmin"));
        assertTrue((Boolean) summary.get("isStaff"));
        assertTrue(((Set<?>) summary.get("accessibleReports")).contains(ReportType.BALANCE_AMOUNT_REPORT));
        assertEquals(1, ((Integer) summary.get("accessibleCount")));
        assertFalse((Boolean) summary.get("hasAllReports"));
    }

    @Test
    void testReportAccessSummary_SuperAdmin() {
        // Test getting report access summary for super admin
        var summary = reportAccessService.getReportAccessSummary(superAdmin.getId());

        // Assertions
        assertNotNull(summary);
        assertEquals(superAdmin.getId(), summary.get("userId"));
        assertEquals(superAdmin.getUsername(), summary.get("username"));
        assertTrue((Boolean) summary.get("isSuperAdmin"));
        assertFalse((Boolean) summary.get("isFacilityAdmin"));
        assertFalse((Boolean) summary.get("isStaff"));
        assertTrue((Boolean) summary.get("hasAllReports"));
    }
}
