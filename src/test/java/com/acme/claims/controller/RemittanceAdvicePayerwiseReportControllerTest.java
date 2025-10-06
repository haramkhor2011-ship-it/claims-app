package com.acme.claims.controller;

import com.acme.claims.security.ReportType;
import com.acme.claims.security.context.UserContext;
import com.acme.claims.security.service.DataFilteringService;
import com.acme.claims.security.service.ReportAccessService;
import com.acme.claims.security.service.UserContextService;
import com.acme.claims.service.RemittanceAdvicePayerwiseReportService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;
import java.util.*;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Integration tests for RemittanceAdvicePayerwiseReportController
 */
@WebMvcTest(RemittanceAdvicePayerwiseReportController.class)
class RemittanceAdvicePayerwiseReportControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserContextService userContextService;

    @MockBean
    private DataFilteringService dataFilteringService;

    @MockBean
    private ReportAccessService reportAccessService;

    @MockBean
    private RemittanceAdvicePayerwiseReportService reportService;

    @Autowired
    private ObjectMapper objectMapper;

    private UserContext userContext;

    @BeforeEach
    void setUp() {
        userContext = UserContext.builder()
                .userId(1L)
                .username("testuser")
                .build();

        when(userContextService.getCurrentUserContextWithRequest()).thenReturn(userContext);
        when(dataFilteringService.getUserAccessibleFacilities()).thenReturn(Set.of("FAC001", "FAC002"));
    }

    @Test
    @WithMockUser(roles = {"SUPER_ADMIN"})
    void testGetRemittanceAdvicePayerwiseReport_HeaderTab_Success() throws Exception {
        // Arrange
        when(reportAccessService.hasReportAccess(eq(1L), eq(ReportType.REMITTANCE_ADVICE_PAYERWISE))).thenReturn(true);

        Map<String, Object> mockData = new HashMap<>();
        mockData.put("orderingClinicianName", "Dr. Smith");
        mockData.put("totalClaims", 5L);
        mockData.put("totalPaidAmount", 1000.00);

        Map<String, Object> mockParams = new HashMap<>();
        mockParams.put("totalClaims", 10L);
        mockParams.put("totalPaidAmount", 5000.00);

        when(reportService.getHeaderTabData(any(), any(), any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(List.of(mockData));
        when(reportService.getReportParameters(any(), any(), any(), any(), any(), any()))
                .thenReturn(mockParams);
        when(reportService.getFilterOptions()).thenReturn(Map.of("facilities", List.of("FAC001")));

        // Act & Assert
        mockMvc.perform(get("/api/reports/data/remittance-advice-payerwise")
                        .param("tab", "header")
                        .param("fromDate", "2025-01-01T00:00:00")
                        .param("toDate", "2025-01-31T23:59:59")
                        .param("facilityCode", "FAC001")
                        .with(user("testuser").roles("SUPER_ADMIN")))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.reportType").value("REMITTANCE_ADVICE_PAYERWISE"))
                .andExpect(jsonPath("$.tab").value("header"))
                .andExpect(jsonPath("$.data").isArray())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].orderingClinicianName").value("Dr. Smith"))
                .andExpect(jsonPath("$.data[0].totalClaims").value(5))
                .andExpect(jsonPath("$.parameters.totalClaims").value(10))
                .andExpect(jsonPath("$.filterOptions.facilities").isArray());
    }

    @Test
    @WithMockUser(roles = {"STAFF"})
    void testGetRemittanceAdvicePayerwiseReport_ClaimWiseTab_Success() throws Exception {
        // Arrange
        when(reportAccessService.hasReportAccess(eq(1L), eq(ReportType.REMITTANCE_ADVICE_PAYERWISE))).thenReturn(true);

        Map<String, Object> mockData = new HashMap<>();
        mockData.put("payerName", "Test Payer");
        mockData.put("claimNumber", "CL001");
        mockData.put("claimAmount", 500.00);

        Map<String, Object> mockParams = new HashMap<>();
        mockParams.put("totalClaims", 5L);

        when(reportService.getClaimWiseTabData(any(), any(), any(), any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(List.of(mockData));
        when(reportService.getReportParameters(any(), any(), any(), any(), any(), any()))
                .thenReturn(mockParams);
        when(reportService.getFilterOptions()).thenReturn(Map.of());

        // Act & Assert
        mockMvc.perform(get("/api/reports/data/remittance-advice-payerwise")
                        .param("tab", "claimWise")
                        .param("payerCode", "PAYER001")
                        .param("paymentReference", "PAY001")
                        .with(user("testuser").roles("STAFF")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tab").value("claimWise"))
                .andExpect(jsonPath("$.data[0].payerName").value("Test Payer"))
                .andExpect(jsonPath("$.data[0].claimNumber").value("CL001"));
    }

    @Test
    @WithMockUser(roles = {"SUPER_ADMIN"})
    void testGetRemittanceAdvicePayerwiseReport_ActivityWiseTab_Success() throws Exception {
        // Arrange
        when(reportAccessService.hasReportAccess(eq(1L), eq(ReportType.REMITTANCE_ADVICE_PAYERWISE))).thenReturn(true);

        Map<String, Object> mockData = new HashMap<>();
        mockData.put("cptCode", "99213");
        mockData.put("paymentStatus", "FULLY_PAID");
        mockData.put("netAmount", 100.00);

        when(reportService.getActivityWiseTabData(any(), any(), any(), any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(List.of(mockData));
        when(reportService.getReportParameters(any(), any(), any(), any(), any(), any()))
                .thenReturn(Map.of());
        when(reportService.getFilterOptions()).thenReturn(Map.of());

        // Act & Assert
        mockMvc.perform(get("/api/reports/data/remittance-advice-payerwise")
                        .param("tab", "activityWise")
                        .param("sortBy", "cpt_code")
                        .param("sortDirection", "ASC")
                        .param("page", "0")
                        .param("size", "10")
                        .with(user("testuser").roles("SUPER_ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tab").value("activityWise"))
                .andExpect(jsonPath("$.data[0].cptCode").value("99213"))
                .andExpect(jsonPath("$.data[0].paymentStatus").value("FULLY_PAID"))
                .andExpect(jsonPath("$.pagination.page").value(0))
                .andExpect(jsonPath("$.pagination.size").value(10))
                .andExpect(jsonPath("$.sorting.sortBy").value("cpt_code"))
                .andExpect(jsonPath("$.sorting.sortDirection").value("ASC"));
    }

    @Test
    @WithMockUser(roles = {"SUPER_ADMIN"})
    void testGetRemittanceAdvicePayerwiseReport_InvalidTab() throws Exception {
        // Arrange
        when(reportAccessService.hasReportAccess(eq(1L), eq(ReportType.REMITTANCE_ADVICE_PAYERWISE))).thenReturn(true);

        // Act & Assert
        mockMvc.perform(get("/api/reports/data/remittance-advice-payerwise")
                        .param("tab", "invalidTab")
                        .with(user("testuser").roles("SUPER_ADMIN")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("Invalid tab parameter. Must be one of: header, claimWise, activityWise"));
    }

    @Test
    @WithMockUser(roles = {"SUPER_ADMIN"})
    void testGetRemittanceAdvicePayerwiseReport_InvalidDateFormat() throws Exception {
        // Arrange
        when(reportAccessService.hasReportAccess(eq(1L), eq(ReportType.REMITTANCE_ADVICE_PAYERWISE))).thenReturn(true);

        // Act & Assert
        mockMvc.perform(get("/api/reports/data/remittance-advice-payerwise")
                        .param("fromDate", "invalid-date")
                        .with(user("testuser").roles("SUPER_ADMIN")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("Invalid fromDate format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
    }

    @Test
    @WithMockUser(roles = {"STAFF"})
    void testGetRemittanceAdvicePayerwiseReport_AccessDenied() throws Exception {
        // Arrange
        when(reportAccessService.hasReportAccess(eq(1L), eq(ReportType.REMITTANCE_ADVICE_PAYERWISE))).thenReturn(false);

        // Act & Assert
        mockMvc.perform(get("/api/reports/data/remittance-advice-payerwise")
                        .with(user("testuser").roles("STAFF")))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("Access denied: You do not have permission to view this report"));
    }

    @Test
    @WithMockUser(roles = {"SUPER_ADMIN"})
    void testGetRemittanceAdvicePayerwiseReport_ServiceException() throws Exception {
        // Arrange
        when(reportAccessService.hasReportAccess(eq(1L), eq(ReportType.REMITTANCE_ADVICE_PAYERWISE))).thenReturn(true);
        when(reportService.getHeaderTabData(any(), any(), any(), any(), any(), any(), any(), any(), any()))
                .thenThrow(new RuntimeException("Database error"));

        // Act & Assert
        mockMvc.perform(get("/api/reports/data/remittance-advice-payerwise")
                        .param("tab", "header")
                        .with(user("testuser").roles("SUPER_ADMIN")))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.error").value("Failed to retrieve Remittance Advice Payerwise report: Database error"));
    }

    @Test
    @WithMockUser(roles = {"SUPER_ADMIN"})
    void testGetRemittanceAdvicePayerwiseReport_WithAllFilters() throws Exception {
        // Arrange
        when(reportAccessService.hasReportAccess(eq(1L), eq(ReportType.REMITTANCE_ADVICE_PAYERWISE))).thenReturn(true);

        Map<String, Object> mockData = new HashMap<>();
        mockData.put("facilityId", "FAC001");
        mockData.put("payerId", "PAYER001");

        when(reportService.getHeaderTabData(any(), any(), eq("FAC001"), eq("PAYER001"), eq("RECEIVER001"), any(), any(), any(), any()))
                .thenReturn(List.of(mockData));
        when(reportService.getReportParameters(any(), any(), eq("FAC001"), eq("PAYER001"), eq("RECEIVER001"), any()))
                .thenReturn(Map.of());
        when(reportService.getFilterOptions()).thenReturn(Map.of());

        // Act & Assert
        mockMvc.perform(get("/api/reports/data/remittance-advice-payerwise")
                        .param("facilityCode", "FAC001")
                        .param("payerCode", "PAYER001")
                        .param("receiverCode", "RECEIVER001")
                        .param("paymentReference", "PAY001")
                        .param("sortBy", "facility_id")
                        .param("sortDirection", "ASC")
                        .param("page", "1")
                        .param("size", "20")
                        .with(user("testuser").roles("SUPER_ADMIN")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].facilityId").value("FAC001"))
                .andExpect(jsonPath("$.data[0].payerId").value("PAYER001"))
                .andExpect(jsonPath("$.pagination.page").value(1))
                .andExpect(jsonPath("$.pagination.size").value(20))
                .andExpect(jsonPath("$.sorting.sortBy").value("facility_id"))
                .andExpect(jsonPath("$.sorting.sortDirection").value("ASC"));
    }
}
