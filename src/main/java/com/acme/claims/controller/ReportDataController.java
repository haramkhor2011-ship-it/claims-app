package com.acme.claims.controller;

import com.acme.claims.security.ReportType;
import com.acme.claims.controller.dto.ReportQueryRequest;
import com.acme.claims.security.context.UserContext;
import com.acme.claims.security.service.DataFilteringService;
import com.acme.claims.security.service.ReportAccessService;
import com.acme.claims.security.service.UserContextService;
import com.acme.claims.service.ClaimDetailsWithActivityReportService;
import com.acme.claims.service.ClaimSummaryMonthwiseReportService;
import com.acme.claims.service.DoctorDenialReportService;
import com.acme.claims.service.RemittanceAdvicePayerwiseReportService;
import com.acme.claims.service.RejectedClaimsReportService;
import com.acme.claims.service.RemittancesResubmissionReportService;
import com.acme.claims.service.BalanceAmountReportService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.parameters.RequestBody;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.*;

/**
 * REST Controller for serving report data to users.
 * 
 * This controller provides endpoints for accessing actual report data with
 * comprehensive access control based on user roles and report permissions.
 * All data is filtered based on user's facility assignments when multi-tenancy
 * is enabled.
 */
@Slf4j
@RestController
@RequestMapping("/api/reports/data")
@RequiredArgsConstructor
@Tag(name = "Report Data", description = "API for accessing report data with role-based access control")
@SecurityRequirement(name = "Bearer Authentication")
public class ReportDataController {
    
    private final UserContextService userContextService;
    private final DataFilteringService dataFilteringService;
    private final ReportAccessService reportAccessService;
    private final RemittanceAdvicePayerwiseReportService remittanceAdvicePayerwiseReportService;
    private final ClaimSummaryMonthwiseReportService claimSummaryMonthwiseReportService;
    private final ClaimDetailsWithActivityReportService claimDetailsWithActivityReportService;
    private final DoctorDenialReportService doctorDenialReportService;
    private final RejectedClaimsReportService rejectedClaimsReportService;
    private final RemittancesResubmissionReportService remittancesResubmissionReportService;
    private final BalanceAmountReportService balanceAmountReportService;
    
    /**
     * Get available reports for the current user
     * 
     * @param authentication Current user authentication context
     * @return List of reports the user can access
     */
    @Operation(
        summary = "Get available reports",
        description = "Retrieves list of reports that the current user has access to"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Available reports retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"reports\": [{\"type\": \"BALANCE_AMOUNT_REPORT\", \"displayName\": \"Balance Amount Report\", \"description\": \"Shows balance amounts to be received\"}], \"user\": \"admin\"}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
        )
    })
    @GetMapping("/available")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getAvailableReports(
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            
            Set<ReportType> accessibleReports = reportAccessService.getUserReportAccess(userContext.getUserId());
            
            List<Map<String, Object>> reportList = accessibleReports.stream()
                    .map(reportType -> {
                        Map<String, Object> report = new HashMap<>();
                        report.put("type", reportType.name());
                        report.put("displayName", reportType.getDisplayName());
                        report.put("description", reportType.getDescription());
                        return report;
                    })
                    .toList();
            
            Map<String, Object> response = new HashMap<>();
            response.put("reports", reportList);
            response.put("user", userContext.getUsername());
            response.put("userId", userContext.getUserId());
            response.put("totalReports", reportList.size());
            response.put("timestamp", java.time.LocalDateTime.now());
            
            log.info("Available reports retrieved for user: {} (ID: {}) - {} reports accessible", 
                    userContext.getUsername(), userContext.getUserId(), reportList.size());
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error retrieving available reports for user: {}", 
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve available reports: " + e.getMessage()));
        }
    }

    /**
     * Get Remittances & Resubmission report data
     */
    @Operation(
        summary = "Get Remittances & Resubmission report",
        description = "Retrieves Remittances & Resubmission report data for activity or claim level",
        deprecated = true
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Report data retrieved successfully"),
        @ApiResponse(responseCode = "400", description = "Bad request - Invalid parameters"),
        @ApiResponse(responseCode = "403", description = "Forbidden - User does not have access to this report"),
        @ApiResponse(responseCode = "401", description = "Unauthorized - Invalid or missing authentication token")
    })
    @Deprecated
    @GetMapping("/remittances-resubmission")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getRemittancesResubmission(
            @RequestParam(defaultValue = "activity") String level, // activity | claim
            @RequestParam(required = false) String facilityId,
            @RequestParam(required = false) List<String> facilityIds,
            @RequestParam(required = false) List<String> payerIds,
            @RequestParam(required = false) List<String> receiverIds,
            @RequestParam(required = false) String fromDate,
            @RequestParam(required = false) String toDate,
            @RequestParam(required = false) String encounterType,
            @RequestParam(required = false) List<String> clinicianIds,
            @RequestParam(required = false) String claimNumber,
            @RequestParam(required = false) String cptCode,
            @RequestParam(required = false) String denialFilter,
            @RequestParam(required = false) String orderBy,
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.REMITTANCES_RESUBMISSION)) {
                return ResponseEntity.status(403)
                        .body(Map.of("error", "Access denied: You do not have permission to view this report"));
            }

            if (!Arrays.asList("activity", "claim").contains(level)) {
                return ResponseEntity.badRequest()
                        .body(Map.of("error", "Invalid level. Must be one of: activity, claim"));
            }

            LocalDateTime fromDateTime = null;
            LocalDateTime toDateTime = null;
            if (fromDate != null && !fromDate.isEmpty()) {
                try {
                    fromDateTime = LocalDateTime.parse(fromDate);
                } catch (Exception e) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Invalid fromDate format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
                }
            }
            if (toDate != null && !toDate.isEmpty()) {
                try {
                    toDateTime = LocalDateTime.parse(toDate);
                } catch (Exception e) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Invalid toDate format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
                }
            }

            Map<String, Object> response = new HashMap<>();
            response.put("reportType", ReportType.REMITTANCES_RESUBMISSION.name());
            response.put("displayName", ReportType.REMITTANCES_RESUBMISSION.getDisplayName());
            response.put("level", level);
            response.put("user", userContext.getUsername());
            response.put("userId", userContext.getUserId());
            response.put("timestamp", java.time.LocalDateTime.now());

            List<Map<String, Object>> data;
            if ("activity".equals(level)) {
                data = remittancesResubmissionReportService.getActivityLevelData(
                        facilityId, facilityIds, payerIds, receiverIds,
                        fromDateTime, toDateTime, encounterType, clinicianIds,
                        claimNumber, cptCode, denialFilter, orderBy,
                        page, size, null, null, null);
            } else {
                data = remittancesResubmissionReportService.getClaimLevelData(
                        facilityId, facilityIds, payerIds, receiverIds,
                        fromDateTime, toDateTime, encounterType, clinicianIds,
                        claimNumber, denialFilter, orderBy,
                        page, size, null, null, null);
            }

            response.put("data", data);
            response.put("totalRecords", data.size());
            response.put("filterOptions", remittancesResubmissionReportService.getFilterOptions());

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error retrieving Remittances & Resubmission report for user: {}", userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve Remittances & Resubmission report: " + e.getMessage()));
        }
    }
    
    /**
     * Get balance amount report data
     * 
     * @param authentication Current user authentication context
     * @return Balance amount report data
     */
    @Operation(
        summary = "Get balance amount report",
        description = "Retrieves balance amount report data (Tab A) with filters",
        requestBody = @RequestBody(required = false, description = "Use POST /api/reports/data/query for unified body-style calls"),
        deprecated = true
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Balance amount report data retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"reportType\": \"BALANCE_AMOUNT_REPORT\", \"data\": [], \"facilities\": [], \"user\": \"admin\"}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "403",
            description = "Forbidden - User does not have access to this report",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
        )
    })
    @Deprecated
    @GetMapping("/balance-amount")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getBalanceAmountReport(
            @RequestParam(required = false) List<Long> claimKeyIds,
            @RequestParam(required = false) List<String> facilityCodes,
            @RequestParam(required = false) List<String> payerCodes,
            @RequestParam(required = false) List<String> receiverIds,
            @RequestParam(required = false) String dateFrom,
            @RequestParam(required = false) String dateTo,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer month,
            @RequestParam(required = false) Boolean basedOnInitialNet,
            @RequestParam(required = false) String orderBy,
            @RequestParam(required = false) String orderDirection,
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.BALANCE_AMOUNT_REPORT)) {
                return ResponseEntity.status(403)
                        .body(Map.of("error", "Access denied: You do not have permission to view this report"));
            }

            LocalDateTime fromDt = null;
            LocalDateTime toDt = null;
            if (dateFrom != null && !dateFrom.isEmpty()) {
                try {
                    fromDt = LocalDateTime.parse(dateFrom);
                } catch (Exception e) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Invalid dateFrom format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
                }
            }
            if (dateTo != null && !dateTo.isEmpty()) {
                try {
                    toDt = LocalDateTime.parse(dateTo);
                } catch (Exception e) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Invalid dateTo format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
                }
            }

            List<Map<String, Object>> data = balanceAmountReportService.getTabA_BalanceToBeReceived(
                    String.valueOf(userContext.getUserId()),
                    claimKeyIds, facilityCodes, payerCodes, receiverIds,
                    fromDt, toDt, year, month,
                    basedOnInitialNet, orderBy, orderDirection, page, size,
                    null, null);

            Map<String, Object> response = new HashMap<>();
            response.put("reportType", ReportType.BALANCE_AMOUNT_REPORT.name());
            response.put("displayName", ReportType.BALANCE_AMOUNT_REPORT.getDisplayName());
            response.put("data", data);
            response.put("totalRecords", data.size());
            response.put("filterOptions", balanceAmountReportService.getFilterOptions());
            response.put("user", userContext.getUsername());
            response.put("userId", userContext.getUserId());
            response.put("timestamp", java.time.LocalDateTime.now());

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            log.error("Error retrieving balance amount report for user: {}", userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve balance amount report: " + e.getMessage()));
        }
    }
    
    /**
     * Get claim details with activity report data
     * 
     * @param authentication Current user authentication context
     * @return Claim details with activity report data
     */
    @Operation(
        summary = "Get claim details with activity report",
        description = "Retrieves claim details with activity report data for the current user's accessible facilities",
        deprecated = true
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Claim details with activity report data retrieved successfully"
        ),
        @ApiResponse(
            responseCode = "403",
            description = "Forbidden - User does not have access to this report"
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token"
        )
    })
    @Deprecated
    @GetMapping("/claim-details-activity")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getClaimDetailsWithActivityReport(
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            
            // Check report access
            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.CLAIM_DETAILS_WITH_ACTIVITY)) {
                log.warn("User {} (ID: {}) attempted to access claim details with activity report without permission", 
                        userContext.getUsername(), userContext.getUserId());
                return ResponseEntity.status(403)
                        .body(Map.of("error", "Access denied: You do not have permission to view this report"));
            }
            
            // Get user's accessible facilities
            Set<String> accessibleFacilities = dataFilteringService.getUserAccessibleFacilities();
            
            // TODO: Implement actual data retrieval from database
            Map<String, Object> response = new HashMap<>();
            response.put("reportType", ReportType.CLAIM_DETAILS_WITH_ACTIVITY.name());
            response.put("displayName", ReportType.CLAIM_DETAILS_WITH_ACTIVITY.getDisplayName());
            response.put("data", List.of()); // TODO: Replace with actual data query
            response.put("facilities", accessibleFacilities);
            response.put("user", userContext.getUsername());
            response.put("userId", userContext.getUserId());
            response.put("timestamp", java.time.LocalDateTime.now());
            response.put("note", "This is a placeholder response. Actual data retrieval will be implemented.");
            
            log.info("Claim details with activity report accessed by user: {} (ID: {}) for facilities: {}", 
                    userContext.getUsername(), userContext.getUserId(), accessibleFacilities);
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error retrieving claim details with activity report for user: {}", 
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve claim details with activity report: " + e.getMessage()));
        }
    }
    
    /**
     * Get generic report data by report type
     * 
     * @param reportType Report type to retrieve
     * @param authentication Current user authentication context
     * @return Report data for the specified report type
     */
    @Operation(
        summary = "Get report data by type",
        description = "Retrieves report data for a specific report type with access control",
        deprecated = true
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Report data retrieved successfully"
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid report type"
        ),
        @ApiResponse(
            responseCode = "403",
            description = "Forbidden - User does not have access to this report"
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token"
        )
    })
    @Deprecated
    @GetMapping("/{reportType}")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getReportData(
            @Parameter(description = "Report type", required = true, example = "BALANCE_AMOUNT_REPORT")
            @PathVariable String reportType,
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            
            // Validate report type
            ReportType reportTypeEnum;
            try {
                reportTypeEnum = ReportType.fromName(reportType);
            } catch (IllegalArgumentException e) {
                log.warn("Invalid report type requested: {} by user: {}", reportType, userContext.getUsername());
                return ResponseEntity.badRequest()
                        .body(Map.of("error", "Invalid report type: " + reportType));
            }
            
            // Check report access
            if (!reportAccessService.hasReportAccess(userContext.getUserId(), reportTypeEnum)) {
                log.warn("User {} (ID: {}) attempted to access report {} without permission", 
                        userContext.getUsername(), userContext.getUserId(), reportType);
                return ResponseEntity.status(403)
                        .body(Map.of("error", "Access denied: You do not have permission to view this report"));
            }
            
            // Get user's accessible facilities
            Set<String> accessibleFacilities = dataFilteringService.getUserAccessibleFacilities();
            
            // TODO: Implement actual data retrieval from database based on report type
            Map<String, Object> response = new HashMap<>();
            response.put("reportType", reportTypeEnum.name());
            response.put("displayName", reportTypeEnum.getDisplayName());
            response.put("description", reportTypeEnum.getDescription());
            response.put("data", List.of()); // TODO: Replace with actual data query
            response.put("facilities", accessibleFacilities);
            response.put("user", userContext.getUsername());
            response.put("userId", userContext.getUserId());
            response.put("timestamp", java.time.LocalDateTime.now());
            response.put("note", "This is a placeholder response. Actual data retrieval will be implemented.");
            
            log.info("Report {} accessed by user: {} (ID: {}) for facilities: {}", 
                    reportType, userContext.getUsername(), userContext.getUserId(), accessibleFacilities);
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error retrieving report {} for user: {}", reportType, userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve report: " + e.getMessage()));
        }
    }

    /**
     * Unified report endpoint - accepts request body with reportType and parameters
     */
    @Operation(
        summary = "Query report (unified endpoint)",
        description = "Single endpoint to retrieve any report using ReportType and parameters in the request body"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Report data retrieved successfully"),
        @ApiResponse(responseCode = "400", description = "Bad request - Invalid report type or parameters"),
        @ApiResponse(responseCode = "403", description = "Forbidden - User does not have access to this report"),
        @ApiResponse(responseCode = "401", description = "Unauthorized - Invalid or missing authentication token")
    })
    @PostMapping("/query")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> queryReport(
            @RequestBody(
                required = true,
                description = "Unified report query body with reportType and filters",
                content = @Content(
                    mediaType = MediaType.APPLICATION_JSON_VALUE,
                    schema = @Schema(implementation = ReportQueryRequest.class),
                    examples = {
                        @ExampleObject(name = "Claim Summary - Monthwise", value = "{\n  \"reportType\": \"CLAIM_SUMMARY_MONTHWISE\",\n  \"tab\": \"monthwise\",\n  \"facilityCode\": \"FAC001\",\n  \"fromDate\": \"2025-01-01T00:00:00\",\n  \"toDate\": \"2025-01-31T23:59:59\",\n  \"page\": 0,\n  \"size\": 50\n}"),
                        @ExampleObject(name = "Rejected Claims - ReceiverPayer", value = "{\n  \"reportType\": \"REJECTED_CLAIMS_REPORT\",\n  \"tab\": \"receiverPayer\",\n  \"facilityCodes\": [\"FAC001\"],\n  \"payerCodes\": [\"DHA\"],\n  \"fromDate\": \"2025-01-01T00:00:00\",\n  \"toDate\": \"2025-01-31T23:59:59\"\n}"),
                        @ExampleObject(name = "Remittances & Resubmission - Activity", value = "{\n  \"reportType\": \"REMITTANCES_RESUBMISSION\",\n  \"level\": \"activity\",\n  \"facilityCodes\": [\"FAC001\"],\n  \"fromDate\": \"2025-01-01T00:00:00\",\n  \"toDate\": \"2025-01-31T23:59:59\"\n}"),
                        @ExampleObject(name = "Balance Amount - Tab A", value = "{\n  \"reportType\": \"BALANCE_AMOUNT_REPORT\",\n  \"facilityCodes\": [\"FAC001\"],\n  \"fromDate\": \"2024-01-01T00:00:00\",\n  \"toDate\": \"2024-12-31T23:59:59\",\n  \"orderBy\": \"aging_days\",\n  \"sortDirection\": \"DESC\"\n}")
                    }
                )
            ) ReportQueryRequest request) {
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            if (request.getReportType() == null) {
                return ResponseEntity.badRequest().body(Map.of("error", "reportType is required"));
            }

            if (!reportAccessService.hasReportAccess(userContext.getUserId(), request.getReportType())) {
                return ResponseEntity.status(403)
                        .body(Map.of("error", "Access denied: You do not have permission to view this report"));
            }

            Map<String, Object> response = new HashMap<>();
            response.put("reportType", request.getReportType().name());
            response.put("displayName", request.getReportType().getDisplayName());
            response.put("user", userContext.getUsername());
            response.put("userId", userContext.getUserId());
            response.put("timestamp", java.time.LocalDateTime.now());

            // Route based on report type
            List<Map<String, Object>> data = List.of();
            Map<String, Object> parameters = Map.of();

            switch (request.getReportType()) {
                case REMITTANCE_ADVICE_PAYERWISE:
                    parameters = remittanceAdvicePayerwiseReportService.getReportParameters(
                            request.getFromDate(), request.getToDate(), request.getFacilityCode(),
                            request.getPayerCode(), request.getReceiverCode(), request.getPaymentReference());
                    String tab = request.getTab() == null ? "header" : request.getTab();
                    if ("header".equals(tab)) {
                        data = remittanceAdvicePayerwiseReportService.getHeaderTabData(
                                request.getFromDate(), request.getToDate(), request.getFacilityCode(),
                                request.getPayerCode(), request.getReceiverCode(),
                                request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize());
                    } else if ("claimWise".equals(tab)) {
                        data = remittanceAdvicePayerwiseReportService.getClaimWiseTabData(
                                request.getFromDate(), request.getToDate(), request.getFacilityCode(),
                                request.getPayerCode(), request.getReceiverCode(), request.getPaymentReference(),
                                request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize());
                    } else if ("activityWise".equals(tab)) {
                        data = remittanceAdvicePayerwiseReportService.getActivityWiseTabData(
                                request.getFromDate(), request.getToDate(), request.getFacilityCode(),
                                request.getPayerCode(), request.getReceiverCode(), request.getPaymentReference(),
                                request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize());
                    } else {
                        return ResponseEntity.badRequest().body(Map.of("error", "Invalid tab for REMITTANCE_ADVICE_PAYERWISE"));
                    }
                    break;
                case CLAIM_SUMMARY_MONTHWISE:
                    String ctab = request.getTab() == null ? "monthwise" : request.getTab();
                    parameters = claimSummaryMonthwiseReportService.getReportParameters(
                            request.getFromDate(), request.getToDate(), request.getFacilityCode(),
                            request.getPayerCode(), request.getReceiverCode(), request.getEncounterType());
                    if ("monthwise".equals(ctab)) {
                        data = claimSummaryMonthwiseReportService.getMonthwiseTabData(
                                request.getFromDate(), request.getToDate(), request.getFacilityCode(),
                                request.getPayerCode(), request.getReceiverCode(), request.getSortBy(),
                                request.getSortDirection(), request.getPage(), request.getSize());
                    } else if ("payerwise".equals(ctab)) {
                        data = claimSummaryMonthwiseReportService.getPayerwiseTabData(
                                request.getFromDate(), request.getToDate(), request.getFacilityCode(),
                                request.getPayerCode(), request.getReceiverCode(), request.getSortBy(),
                                request.getSortDirection(), request.getPage(), request.getSize());
                    } else if ("encounterwise".equals(ctab)) {
                        data = claimSummaryMonthwiseReportService.getEncounterwiseTabData(
                                request.getFromDate(), request.getToDate(), request.getFacilityCode(),
                                request.getPayerCode(), request.getReceiverCode(), request.getSortBy(),
                                request.getSortDirection(), request.getPage(), request.getSize());
                    } else {
                        return ResponseEntity.badRequest().body(Map.of("error", "Invalid tab for CLAIM_SUMMARY_MONTHWISE"));
                    }
                    break;
                case CLAIM_DETAILS_WITH_ACTIVITY:
                    data = claimDetailsWithActivityReportService.getClaimDetailsWithActivity(
                            request.getFacilityCode(), request.getReceiverCode(), request.getPayerCode(), request.getClinicianCode(),
                            request.getClaimId(), request.getPatientId(), request.getCptCode(), request.getClaimStatus(),
                            request.getPaymentStatus(), request.getEncounterType(), request.getResubType(),
                            (request.getDenialCodes() != null && !request.getDenialCodes().isEmpty()) ? request.getDenialCodes().get(0) : null,
                            request.getExtra() != null ? (String) request.getExtra().get("memberId") : null,
                            request.getFromDate(), request.getToDate(), request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize());
                    parameters = claimDetailsWithActivityReportService.getClaimDetailsSummary(
                            request.getFacilityCode(), request.getReceiverCode(), request.getPayerCode(), request.getFromDate(), request.getToDate());
                    break;
                case DOCTOR_DENIAL_REPORT:
                    String dtab = request.getTab() == null ? "high_denial" : request.getTab();
                    data = doctorDenialReportService.getDoctorDenialReport(
                            request.getFacilityCode(), request.getClinicianCode(), request.getFromDate(), request.getToDate(),
                            request.getYear(), request.getMonth(), dtab, request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize());
                    if ("high_denial".equals(dtab) || "summary".equals(dtab)) {
                        parameters = doctorDenialReportService.getDoctorDenialSummary(
                                request.getFacilityCode(), request.getClinicianCode(), request.getFromDate(), request.getToDate(), request.getYear(), request.getMonth());
                    }
                    break;
                case REJECTED_CLAIMS_REPORT:
                    String rtab = request.getTab() == null ? "summary" : request.getTab();
                    if ("summary".equals(rtab)) {
                        data = rejectedClaimsReportService.getSummaryTabData(
                                String.valueOf(userContext.getUserId()), request.getFacilityCodes(), request.getPayerCodes(), request.getReceiverIds(),
                                request.getFromDate(), request.getToDate(), request.getYear(), request.getMonth(),
                                request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize(),
                                request.getFacilityRefIds(), request.getPayerRefIds(), request.getClinicianRefIds());
                    } else if ("receiverPayer".equals(rtab)) {
                        data = rejectedClaimsReportService.getReceiverPayerTabData(
                                String.valueOf(userContext.getUserId()), request.getFacilityCodes(), request.getPayerCodes(), request.getReceiverIds(),
                                request.getFromDate(), request.getToDate(), request.getYear(), request.getDenialCodes(),
                                request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize(),
                                request.getFacilityRefIds(), request.getPayerRefIds(), request.getClinicianRefIds());
                    } else if ("claimWise".equals(rtab)) {
                        data = rejectedClaimsReportService.getClaimWiseTabData(
                                String.valueOf(userContext.getUserId()), request.getFacilityCodes(), request.getPayerCodes(), request.getReceiverIds(),
                                request.getFromDate(), request.getToDate(), request.getYear(), request.getDenialCodes(),
                                request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize(),
                                request.getFacilityRefIds(), request.getPayerRefIds(), request.getClinicianRefIds());
                    } else {
                        return ResponseEntity.badRequest().body(Map.of("error", "Invalid tab for REJECTED_CLAIMS_REPORT"));
                    }
                    break;
                case REMITTANCES_RESUBMISSION:
                    String level = request.getLevel() == null ? "activity" : request.getLevel();
                    if ("activity".equals(level)) {
                        data = remittancesResubmissionReportService.getActivityLevelData(
                                request.getFacilityCode(), request.getFacilityCodes(), request.getPayerCodes(), request.getReceiverIds(),
                                request.getFromDate(), request.getToDate(), request.getEncounterType(), request.getClinicianIds(),
                                request.getClaimId(), request.getCptCode(), request.getDenialFilter(), request.getSortBy(),
                                request.getPage(), request.getSize(), request.getFacilityRefIds(), request.getPayerRefIds(), request.getClinicianRefIds());
                    } else if ("claim".equals(level)) {
                        data = remittancesResubmissionReportService.getClaimLevelData(
                                request.getFacilityCode(), request.getFacilityCodes(), request.getPayerCodes(), request.getReceiverIds(),
                                request.getFromDate(), request.getToDate(), request.getEncounterType(), request.getClinicianIds(),
                                request.getClaimId(), request.getDenialFilter(), request.getSortBy(),
                                request.getPage(), request.getSize(), request.getFacilityRefIds(), request.getPayerRefIds(), request.getClinicianRefIds());
                    } else {
                        return ResponseEntity.badRequest().body(Map.of("error", "Invalid level for REMITTANCES_RESUBMISSION"));
                    }
                    break;
                case BALANCE_AMOUNT_REPORT:
                    data = balanceAmountReportService.getTabA_BalanceToBeReceived(
                            String.valueOf(userContext.getUserId()), request.getClaimKeyIds(), request.getFacilityCodes(),
                            request.getPayerCodes(), request.getReceiverIds(), request.getFromDate(), request.getToDate(), request.getYear(), request.getMonth(),
                            request.getBasedOnInitialNet(), request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize(),
                            request.getFacilityRefIds(), request.getPayerRefIds());
                    break;
                default:
                    return ResponseEntity.badRequest().body(Map.of("error", "Unsupported reportType"));
            }

            response.put("data", data);
            response.put("parameters", parameters);
            response.put("totalRecords", data.size());
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error querying report for user: {}", userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError().body(Map.of("error", "Failed to query report: " + e.getMessage()));
        }
    }

    /**
     * Get Remittance Advice Payerwise report data
     *
     * @param fromDate Start date for filtering (optional)
     * @param toDate End date for filtering (optional)
     * @param facilityCode Facility code for filtering (optional)
     * @param payerCode Payer code for filtering (optional)
     * @param receiverCode Receiver code for filtering (optional)
     * @param paymentReference Payment reference for filtering (optional)
     * @param tab Tab to retrieve (header, claimWise, activityWise)
     * @param authentication Current user authentication context
     * @return Remittance Advice Payerwise report data
     */
    @Operation(
        summary = "Get Remittance Advice Payerwise report",
        description = "Retrieves Remittance Advice Payerwise report data with comprehensive filtering options",
        deprecated = true
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Remittance Advice Payerwise report data retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"reportType\": \"REMITTANCE_ADVICE_PAYERWISE\", \"tab\": \"header\", \"data\": [], \"parameters\": {}, \"user\": \"admin\"}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid parameters"
        ),
        @ApiResponse(
            responseCode = "403",
            description = "Forbidden - User does not have access to this report"
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token"
        )
    })
    @Deprecated
    @GetMapping("/remittance-advice-payerwise")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getRemittanceAdvicePayerwiseReport(
            @Parameter(description = "Start date (YYYY-MM-DDTHH:mm:ss)")
            @RequestParam(required = false) String fromDate,
            @Parameter(description = "End date (YYYY-MM-DDTHH:mm:ss)")
            @RequestParam(required = false) String toDate,
            @Parameter(description = "Facility code filter")
            @RequestParam(required = false) String facilityCode,
            @Parameter(description = "Payer code filter")
            @RequestParam(required = false) String payerCode,
            @Parameter(description = "Receiver code filter")
            @RequestParam(required = false) String receiverCode,
            @Parameter(description = "Payment reference filter")
            @RequestParam(required = false) String paymentReference,
            @Parameter(description = "Tab to retrieve (header, claimWise, activityWise)", example = "header")
            @RequestParam(defaultValue = "header") String tab,
            @Parameter(description = "Sort by column")
            @RequestParam(required = false) String sortBy,
            @Parameter(description = "Sort direction (ASC or DESC)")
            @RequestParam(required = false) String sortDirection,
            @Parameter(description = "Page number (0-based)")
            @RequestParam(required = false) Integer page,
            @Parameter(description = "Page size")
            @RequestParam(required = false) Integer size,
            @Parameter(hidden = true) Authentication authentication) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            // Check report access
            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.REMITTANCE_ADVICE_PAYERWISE)) {
                log.warn("User {} (ID: {}) attempted to access Remittance Advice Payerwise report without permission",
                        userContext.getUsername(), userContext.getUserId());
                return ResponseEntity.status(403)
                        .body(Map.of("error", "Access denied: You do not have permission to view this report"));
            }

            // Parse dates
            LocalDateTime fromDateTime = null;
            LocalDateTime toDateTime = null;

            if (fromDate != null && !fromDate.isEmpty()) {
                try {
                    fromDateTime = LocalDateTime.parse(fromDate);
                } catch (Exception e) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Invalid fromDate format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
                }
            }

            if (toDate != null && !toDate.isEmpty()) {
                try {
                    toDateTime = LocalDateTime.parse(toDate);
                } catch (Exception e) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Invalid toDate format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
                }
            }

            // Validate tab parameter
            if (!Arrays.asList("header", "claimWise", "activityWise").contains(tab)) {
                return ResponseEntity.badRequest()
                        .body(Map.of("error", "Invalid tab parameter. Must be one of: header, claimWise, activityWise"));
            }

            // Get user's accessible facilities for additional filtering
            Set<String> accessibleFacilities = dataFilteringService.getUserAccessibleFacilities();

            // Apply facility filter if user doesn't have access to all facilities
            if (accessibleFacilities != null && !accessibleFacilities.isEmpty() && facilityCode == null) {
                // If no specific facility is requested, limit to accessible facilities
                // This would require modifying the service to accept facility restrictions
                log.debug("User {} has limited facility access: {}", userContext.getUsername(), accessibleFacilities);
            }

            Map<String, Object> response = new HashMap<>();
            response.put("reportType", ReportType.REMITTANCE_ADVICE_PAYERWISE.name());
            response.put("displayName", ReportType.REMITTANCE_ADVICE_PAYERWISE.getDisplayName());
            response.put("tab", tab);
            response.put("user", userContext.getUsername());
            response.put("userId", userContext.getUserId());
            response.put("timestamp", java.time.LocalDateTime.now());

            // Get report parameters (summary data)
            Map<String, Object> parameters = remittanceAdvicePayerwiseReportService.getReportParameters(
                    fromDateTime, toDateTime, facilityCode, payerCode, receiverCode, paymentReference);
            response.put("parameters", parameters);

            // Get tab-specific data
            List<Map<String, Object>> data;
            switch (tab) {
                case "header":
                    data = remittanceAdvicePayerwiseReportService.getHeaderTabData(
                            fromDateTime, toDateTime, facilityCode, payerCode, receiverCode,
                            sortBy, sortDirection, page, size);
                    break;
                case "claimWise":
                    data = remittanceAdvicePayerwiseReportService.getClaimWiseTabData(
                            fromDateTime, toDateTime, facilityCode, payerCode, receiverCode, paymentReference,
                            sortBy, sortDirection, page, size);
                    break;
                case "activityWise":
                    data = remittanceAdvicePayerwiseReportService.getActivityWiseTabData(
                            fromDateTime, toDateTime, facilityCode, payerCode, receiverCode, paymentReference,
                            sortBy, sortDirection, page, size);
                    break;
                default:
                    data = new ArrayList<>();
            }

            response.put("data", data);
            response.put("totalRecords", data.size());

            // Add pagination info
            Map<String, Object> pagination = new HashMap<>();
            if (page != null && size != null) {
                pagination.put("page", page);
                pagination.put("size", size);
                pagination.put("hasNext", data.size() == size); // Simple check - could be improved
                pagination.put("hasPrevious", page > 0);
            }
            response.put("pagination", pagination);

            // Add sorting info
            Map<String, Object> sorting = new HashMap<>();
            sorting.put("sortBy", sortBy);
            sorting.put("sortDirection", sortDirection);
            response.put("sorting", sorting);

            // Add filter options for UI
            response.put("filterOptions", remittanceAdvicePayerwiseReportService.getFilterOptions());

            log.info("Remittance Advice Payerwise report ({}) accessed by user: {} (ID: {}) - {} records returned",
                    tab, userContext.getUsername(), userContext.getUserId(), data.size());

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            log.error("Error retrieving Remittance Advice Payerwise report for user: {}",
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve Remittance Advice Payerwise report: " + e.getMessage()));
        }
    }

    /**
     * Get report access summary for the current user
     * 
     * @param authentication Current user authentication context
     * @return Report access summary
     */
    @Operation(
        summary = "Get report access summary",
        description = "Retrieves a summary of the current user's report access permissions",
        deprecated = true
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Report access summary retrieved successfully"
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token"
        )
    })
    @GetMapping("/access-summary")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getReportAccessSummary(
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            
            Map<String, Object> summary = reportAccessService.getReportAccessSummary(userContext.getUserId());
            
            log.info("Report access summary retrieved for user: {} (ID: {})", 
                    userContext.getUsername(), userContext.getUserId());
            
            return ResponseEntity.ok(summary);
            
        } catch (Exception e) {
            log.error("Error retrieving report access summary for user: {}", 
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve report access summary: " + e.getMessage()));
        }
    }

    /**
     * Get Claim Summary Monthwise report data
     *
     * @param fromDate Start date for filtering (optional)
     * @param toDate End date for filtering (optional)
     * @param facilityCode Facility code for filtering (optional)
     * @param payerCode Payer code for filtering (optional)
     * @param receiverCode Receiver code for filtering (optional)
     * @param encounterType Encounter type for filtering (optional)
     * @param tab Tab to retrieve (monthwise, payerwise, encounterwise)
     * @param sortBy Sort by column
     * @param sortDirection Sort direction (ASC or DESC)
     * @param page Page number (0-based)
     * @param size Page size
     * @param authentication Current user authentication context
     * @return Claim Summary Monthwise report data
     */
    @Operation(
        summary = "Get Claim Summary Monthwise report",
        description = "Retrieves Claim Summary Monthwise report data with comprehensive filtering and tab options",
        deprecated = true
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Claim Summary Monthwise report data retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"reportType\": \"CLAIM_SUMMARY_MONTHWISE\", \"tab\": \"monthwise\", \"data\": [], \"parameters\": {}, \"user\": \"admin\"}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid parameters"
        ),
        @ApiResponse(
            responseCode = "403",
            description = "Forbidden - User does not have access to this report"
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token"
        )
    })
    @Deprecated
    @GetMapping("/claim-summary-monthwise")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getClaimSummaryMonthwiseReport(
            @Parameter(description = "Start date (YYYY-MM-DDTHH:mm:ss)")
            @RequestParam(required = false) String fromDate,
            @Parameter(description = "End date (YYYY-MM-DDTHH:mm:ss)")
            @RequestParam(required = false) String toDate,
            @Parameter(description = "Facility code filter")
            @RequestParam(required = false) String facilityCode,
            @Parameter(description = "Payer code filter")
            @RequestParam(required = false) String payerCode,
            @Parameter(description = "Receiver code filter")
            @RequestParam(required = false) String receiverCode,
            @Parameter(description = "Encounter type filter")
            @RequestParam(required = false) String encounterType,
            @Parameter(description = "Tab to retrieve (monthwise, payerwise, encounterwise)", example = "monthwise")
            @RequestParam(defaultValue = "monthwise") String tab,
            @Parameter(description = "Sort by column")
            @RequestParam(required = false) String sortBy,
            @Parameter(description = "Sort direction (ASC or DESC)")
            @RequestParam(required = false) String sortDirection,
            @Parameter(description = "Page number (0-based)")
            @RequestParam(required = false) Integer page,
            @Parameter(description = "Page size")
            @RequestParam(required = false) Integer size,
            @Parameter(hidden = true) Authentication authentication) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            // Check report access
            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.CLAIM_SUMMARY_MONTHWISE)) {
                log.warn("User {} (ID: {}) attempted to access Claim Summary Monthwise report without permission",
                        userContext.getUsername(), userContext.getUserId());
                return ResponseEntity.status(403)
                        .body(Map.of("error", "Access denied: You do not have permission to view this report"));
            }

            // Parse dates
            LocalDateTime fromDateTime = null;
            LocalDateTime toDateTime = null;

            if (fromDate != null && !fromDate.isEmpty()) {
                try {
                    fromDateTime = LocalDateTime.parse(fromDate);
                } catch (Exception e) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Invalid fromDate format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
                }
            }

            if (toDate != null && !toDate.isEmpty()) {
                try {
                    toDateTime = LocalDateTime.parse(toDate);
                } catch (Exception e) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Invalid toDate format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
                }
            }

            // Validate tab parameter
            if (!Arrays.asList("monthwise", "payerwise", "encounterwise").contains(tab)) {
                return ResponseEntity.badRequest()
                        .body(Map.of("error", "Invalid tab parameter. Must be one of: monthwise, payerwise, encounterwise"));
            }

            // Get user's accessible facilities for additional filtering
            Set<String> accessibleFacilities = dataFilteringService.getUserAccessibleFacilities();

            // Apply facility filter if user doesn't have access to all facilities
            if (accessibleFacilities != null && !accessibleFacilities.isEmpty() && facilityCode == null) {
                // If no specific facility is requested, limit to accessible facilities
                // This would require modifying the service to accept facility restrictions
                log.debug("User {} has limited facility access: {}", userContext.getUsername(), accessibleFacilities);
            }

            Map<String, Object> response = new HashMap<>();
            response.put("reportType", ReportType.CLAIM_SUMMARY_MONTHWISE.name());
            response.put("displayName", ReportType.CLAIM_SUMMARY_MONTHWISE.getDisplayName());
            response.put("tab", tab);
            response.put("user", userContext.getUsername());
            response.put("userId", userContext.getUserId());
            response.put("timestamp", java.time.LocalDateTime.now());

            // Get report parameters (summary data)
            Map<String, Object> parameters = claimSummaryMonthwiseReportService.getReportParameters(
                    fromDateTime, toDateTime, facilityCode, payerCode, receiverCode, encounterType);
            response.put("parameters", parameters);

            // Get tab-specific data
            List<Map<String, Object>> data;
            switch (tab) {
                case "monthwise":
                    data = claimSummaryMonthwiseReportService.getMonthwiseTabData(
                            fromDateTime, toDateTime, facilityCode, payerCode, receiverCode,
                            sortBy, sortDirection, page, size);
                    break;
                case "payerwise":
                    data = claimSummaryMonthwiseReportService.getPayerwiseTabData(
                            fromDateTime, toDateTime, facilityCode, payerCode, receiverCode,
                            sortBy, sortDirection, page, size);
                    break;
                case "encounterwise":
                    data = claimSummaryMonthwiseReportService.getEncounterwiseTabData(
                            fromDateTime, toDateTime, facilityCode, payerCode, receiverCode,
                            sortBy, sortDirection, page, size);
                    break;
                default:
                    data = new ArrayList<>();
            }

            response.put("data", data);
            response.put("totalRecords", data.size());

            // Add pagination info
            Map<String, Object> pagination = new HashMap<>();
            if (page != null && size != null) {
                pagination.put("page", page);
                pagination.put("size", size);
                pagination.put("hasNext", data.size() == size); // Simple check - could be improved
                pagination.put("hasPrevious", page > 0);
            }
            response.put("pagination", pagination);

            // Add sorting info
            Map<String, Object> sorting = new HashMap<>();
            sorting.put("sortBy", sortBy);
            sorting.put("sortDirection", sortDirection);
            response.put("sorting", sorting);

            // Add filter options for UI
            response.put("filterOptions", claimSummaryMonthwiseReportService.getFilterOptions());

            log.info("Claim Summary Monthwise report ({}) accessed by user: {} (ID: {}) - {} records returned",
                    tab, userContext.getUsername(), userContext.getUserId(), data.size());

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            log.error("Error retrieving Claim Summary Monthwise report for user: {}",
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve Claim Summary Monthwise report: " + e.getMessage()));
        }
    }

    /**
     * Get claim status breakdown popup data for Tab A row clicks
     *
     * @param monthYear Month and year in format "Month YYYY" (e.g., "January 2024")
     * @param facilityId Facility ID filter (optional)
     * @param healthAuthority Health authority filter (optional)
     * @param authentication Current user authentication context
     * @return Claim status breakdown popup data
     */
    @Operation(
        summary = "Get claim status breakdown popup data",
        description = "Retrieves detailed claim status breakdown for popup when clicking Tab A rows",
        deprecated = true
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Claim status breakdown popup data retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"popupData\": [{\"statusName\": \"Claimed\", \"statusCount\": 100, \"statusDescription\": \"Total claims submitted for that period.\", \"totalAmount\": 50000.00, \"statusPercentage\": 45.45}], \"monthYear\": \"January 2024\", \"facilityId\": \"FAC001\", \"healthAuthority\": \"DHA\"}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid parameters"
        ),
        @ApiResponse(
            responseCode = "403",
            description = "Forbidden - User does not have access to this report"
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token"
        )
    })
    @Deprecated
    @GetMapping("/claim-summary-monthwise/popup")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getClaimStatusBreakdownPopup(
            @Parameter(description = "Month and year in format 'Month YYYY' (e.g., 'January 2024')", required = true, example = "January 2024")
            @RequestParam String monthYear,
            @Parameter(description = "Facility ID filter")
            @RequestParam(required = false) String facilityId,
            @Parameter(description = "Health authority filter")
            @RequestParam(required = false) String healthAuthority,
            @Parameter(hidden = true) Authentication authentication) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            // Check report access
            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.CLAIM_SUMMARY_MONTHWISE)) {
                log.warn("User {} (ID: {}) attempted to access Claim Summary Monthwise popup without permission",
                        userContext.getUsername(), userContext.getUserId());
                return ResponseEntity.status(403)
                        .body(Map.of("error", "Access denied: You do not have permission to view this report"));
            }

            // Get user's accessible facilities for additional filtering
            Set<String> accessibleFacilities = dataFilteringService.getUserAccessibleFacilities();

            // Apply facility filter if user doesn't have access to all facilities
            if (accessibleFacilities != null && !accessibleFacilities.isEmpty() && facilityId == null) {
                // If no specific facility is requested, limit to accessible facilities
                // This would require modifying the service to accept facility restrictions
                log.debug("User {} has limited facility access: {}", userContext.getUsername(), accessibleFacilities);
            }

            // Get popup data
            List<Map<String, Object>> popupData = claimSummaryMonthwiseReportService.getClaimStatusBreakdownPopup(
                    monthYear, facilityId, healthAuthority);

            Map<String, Object> response = new HashMap<>();
            response.put("popupData", popupData);
            response.put("monthYear", monthYear);
            response.put("facilityId", facilityId);
            response.put("healthAuthority", healthAuthority);
            response.put("user", userContext.getUsername());
            response.put("userId", userContext.getUserId());
            response.put("timestamp", java.time.LocalDateTime.now());
            response.put("totalStatuses", popupData.size());

            log.info("Claim Summary Monthwise popup data accessed by user: {} (ID: {}) for monthYear={}, facilityId={}, healthAuthority={}",
                    userContext.getUsername(), userContext.getUserId(), monthYear, facilityId, healthAuthority);

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            log.error("Error retrieving Claim Summary Monthwise popup data for user: {}",
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve Claim Summary Monthwise popup data: " + e.getMessage()));
        }
    }

    /**
     * Get comprehensive claim details by claim ID
     *
     * @param claimId The claim ID to retrieve details for
     * @param authentication Current user authentication context
     * @return Comprehensive claim details in structured format for UI rendering
     */
    @Operation(
        summary = "Get comprehensive claim details by ID",
        description = "Retrieves all information related to a specific claim including basic info, encounter, diagnosis, activities, remittance, timeline, attachments, and transaction types",
        deprecated = true
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Claim details retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"claimInfo\": {\"claimId\": \"CLM001\", \"payerId\": \"DHA\", \"providerId\": \"PROV001\", \"netAmount\": 1500.00}, \"encounterInfo\": {\"facilityId\": \"FAC001\", \"encounterType\": \"OUTPATIENT\"}, \"diagnosisInfo\": [{\"diagnosisCode\": \"Z00.00\", \"diagnosisType\": \"Principal\"}], \"activitiesInfo\": [{\"activityCode\": \"99213\", \"netAmount\": 150.00}], \"remittanceInfo\": {\"paymentReference\": \"REM001\", \"settlementDate\": \"2024-01-15T10:30:00Z\"}, \"claimTimeline\": [{\"eventTime\": \"2024-01-10T09:00:00Z\", \"eventType\": \"Submission\"}], \"attachments\": [{\"fileName\": \"claim.pdf\", \"createdAt\": \"2024-01-10T09:00:00Z\"}], \"transactionTypes\": [{\"transactionType\": \"Initial Submission\", \"eventTime\": \"2024-01-10T09:00:00Z\"}]}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "404",
            description = "Claim not found"
        ),
        @ApiResponse(
            responseCode = "403",
            description = "Forbidden - User does not have access to this claim"
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token"
        )
    })
    @Deprecated
    @GetMapping("/claim/{claimId}")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getClaimDetails(
            @Parameter(description = "Claim ID to retrieve details for", required = true, example = "CLM001")
            @PathVariable String claimId,
            @Parameter(hidden = true) Authentication authentication) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            // Check if user has access to this claim (facility-based filtering)
            Set<String> accessibleFacilities = dataFilteringService.getUserAccessibleFacilities();
            if (accessibleFacilities != null && !accessibleFacilities.isEmpty()) {
                // TODO: Implement facility-based claim access check
                // For now, allow access but log the access
                log.debug("User {} accessing claim {} with facility restrictions: {}",
                        userContext.getUsername(), claimId, accessibleFacilities);
            }

            // Get comprehensive claim details
            Map<String, Object> claimDetails = claimSummaryMonthwiseReportService.getClaimDetailsById(claimId);

            // Check if claim exists
            if (claimDetails.get("claimInfo") == null || ((Map<?, ?>) claimDetails.get("claimInfo")).isEmpty()) {
                log.warn("Claim not found: {} requested by user: {}", claimId, userContext.getUsername());
                return ResponseEntity.notFound().build();
            }

            // Add metadata
            Map<String, Object> response = new HashMap<>();
            response.put("claimDetails", claimDetails);
            response.put("claimId", claimId);
            response.put("user", userContext.getUsername());
            response.put("userId", userContext.getUserId());
            response.put("timestamp", java.time.LocalDateTime.now());

            log.info("Claim details retrieved for claim ID: {} by user: {} (ID: {})",
                    claimId, userContext.getUsername(), userContext.getUserId());

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            log.error("Error retrieving claim details for claim ID: {} by user: {}",
                    claimId, userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve claim details: " + e.getMessage()));
        }
    }

    /**
     * Get Claim Details with Activity report data
     *
     * @param facilityCode Facility code filter
     * @param receiverId Receiver ID filter
     * @param payerCode Payer code filter
     * @param clinician Clinician filter
     * @param claimId Claim ID filter
     * @param patientId Patient ID filter
     * @param cptCode CPT code filter
     * @param claimStatus Claim status filter
     * @param paymentStatus Payment status filter
     * @param encounterType Encounter type filter
     * @param resubType Resubmission type filter
     * @param denialCode Denial code filter
     * @param memberId Member ID filter
     * @param fromDate Start date filter
     * @param toDate End date filter
     * @param sortBy Sort by column
     * @param sortDirection Sort direction
     * @param page Page number
     * @param size Page size
     * @param authentication Current user authentication context
     * @return Claim Details with Activity report data
     */
    @Operation(
        summary = "Get Claim Details with Activity report",
        description = "Retrieves comprehensive claim details with activity information including submission tracking, financials, denial info, remittance tracking, patient/payer info, encounter/activity details, and calculated metrics",
        deprecated = true
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Claim Details with Activity report data retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"reportType\": \"CLAIM_DETAILS_WITH_ACTIVITY\", \"data\": [], \"summary\": {}, \"filters\": {}, \"user\": \"admin\"}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid parameters"
        ),
        @ApiResponse(
            responseCode = "403",
            description = "Forbidden - User does not have access to this report"
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token"
        )
    })
    @Deprecated
    @GetMapping("/claim-details-with-activity")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getClaimDetailsWithActivityReport(
            @Parameter(description = "Facility code filter")
            @RequestParam(required = false) String facilityCode,
            @Parameter(description = "Receiver ID filter")
            @RequestParam(required = false) String receiverId,
            @Parameter(description = "Payer code filter")
            @RequestParam(required = false) String payerCode,
            @Parameter(description = "Clinician filter")
            @RequestParam(required = false) String clinician,
            @Parameter(description = "Claim ID filter")
            @RequestParam(required = false) String claimId,
            @Parameter(description = "Patient ID filter")
            @RequestParam(required = false) String patientId,
            @Parameter(description = "CPT code filter")
            @RequestParam(required = false) String cptCode,
            @Parameter(description = "Claim status filter")
            @RequestParam(required = false) String claimStatus,
            @Parameter(description = "Payment status filter")
            @RequestParam(required = false) String paymentStatus,
            @Parameter(description = "Encounter type filter")
            @RequestParam(required = false) String encounterType,
            @Parameter(description = "Resubmission type filter")
            @RequestParam(required = false) String resubType,
            @Parameter(description = "Denial code filter")
            @RequestParam(required = false) String denialCode,
            @Parameter(description = "Member ID filter")
            @RequestParam(required = false) String memberId,
            @Parameter(description = "Start date (YYYY-MM-DDTHH:mm:ss)")
            @RequestParam(required = false) String fromDate,
            @Parameter(description = "End date (YYYY-MM-DDTHH:mm:ss)")
            @RequestParam(required = false) String toDate,
            @Parameter(description = "Sort by column")
            @RequestParam(required = false) String sortBy,
            @Parameter(description = "Sort direction (ASC or DESC)")
            @RequestParam(required = false) String sortDirection,
            @Parameter(description = "Page number (0-based)")
            @RequestParam(required = false) Integer page,
            @Parameter(description = "Page size")
            @RequestParam(required = false) Integer size,
            @Parameter(hidden = true) Authentication authentication) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            // Check report access
            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.CLAIM_DETAILS_WITH_ACTIVITY)) {
                log.warn("User {} (ID: {}) attempted to access Claim Details with Activity report without permission",
                        userContext.getUsername(), userContext.getUserId());
                return ResponseEntity.status(403)
                        .body(Map.of("error", "Access denied: You do not have permission to view this report"));
            }

            // Parse dates
            LocalDateTime fromDateTime = null;
            LocalDateTime toDateTime = null;

            if (fromDate != null && !fromDate.isEmpty()) {
                try {
                    fromDateTime = LocalDateTime.parse(fromDate);
                } catch (Exception e) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Invalid fromDate format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
                }
            }

            if (toDate != null && !toDate.isEmpty()) {
                try {
                    toDateTime = LocalDateTime.parse(toDate);
                } catch (Exception e) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Invalid toDate format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
                }
            }

            // Get user's accessible facilities for additional filtering
            Set<String> accessibleFacilities = dataFilteringService.getUserAccessibleFacilities();

            // Apply facility filter if user doesn't have access to all facilities
            if (accessibleFacilities != null && !accessibleFacilities.isEmpty() && facilityCode == null) {
                // If no specific facility is requested, limit to accessible facilities
                // This would require modifying the service to accept facility restrictions
                log.debug("User {} has limited facility access: {}", userContext.getUsername(), accessibleFacilities);
            }

            Map<String, Object> response = new HashMap<>();
            response.put("reportType", ReportType.CLAIM_DETAILS_WITH_ACTIVITY.name());
            response.put("displayName", ReportType.CLAIM_DETAILS_WITH_ACTIVITY.getDisplayName());
            response.put("user", userContext.getUsername());
            response.put("userId", userContext.getUserId());
            response.put("timestamp", java.time.LocalDateTime.now());

            // Get report data
            List<Map<String, Object>> data = claimDetailsWithActivityReportService.getClaimDetailsWithActivity(
                    facilityCode, receiverId, payerCode, clinician, claimId, patientId,
                    cptCode, claimStatus, paymentStatus, encounterType, resubType,
                    denialCode, memberId, fromDateTime, toDateTime, sortBy, sortDirection, page, size);

            response.put("data", data);
            response.put("totalRecords", data.size());

            // Get summary metrics for dashboard
            Map<String, Object> summary = claimDetailsWithActivityReportService.getClaimDetailsSummary(
                    facilityCode, receiverId, payerCode, fromDateTime, toDateTime);
            response.put("summary", summary);

            // Add pagination info
            Map<String, Object> pagination = new HashMap<>();
            if (page != null && size != null) {
                pagination.put("page", page);
                pagination.put("size", size);
                pagination.put("hasNext", data.size() == size); // Simple check - could be improved
                pagination.put("hasPrevious", page > 0);
            }
            response.put("pagination", pagination);

            // Add sorting info
            Map<String, Object> sorting = new HashMap<>();
            sorting.put("sortBy", sortBy);
            sorting.put("sortDirection", sortDirection);
            response.put("sorting", sorting);

            // Add filter options for UI
            response.put("filterOptions", claimDetailsWithActivityReportService.getFilterOptions());

            // Add applied filters for reference
            Map<String, Object> appliedFilters = new HashMap<>();
            appliedFilters.put("facilityCode", facilityCode);
            appliedFilters.put("receiverId", receiverId);
            appliedFilters.put("payerCode", payerCode);
            appliedFilters.put("clinician", clinician);
            appliedFilters.put("claimId", claimId);
            appliedFilters.put("patientId", patientId);
            appliedFilters.put("cptCode", cptCode);
            appliedFilters.put("claimStatus", claimStatus);
            appliedFilters.put("paymentStatus", paymentStatus);
            appliedFilters.put("encounterType", encounterType);
            appliedFilters.put("resubType", resubType);
            appliedFilters.put("denialCode", denialCode);
            appliedFilters.put("memberId", memberId);
            appliedFilters.put("fromDate", fromDate);
            appliedFilters.put("toDate", toDate);
            response.put("appliedFilters", appliedFilters);

            log.info("Claim Details with Activity report accessed by user: {} (ID: {}) - {} records returned",
                    userContext.getUsername(), userContext.getUserId(), data.size());

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            log.error("Error retrieving Claim Details with Activity report for user: {}",
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve Claim Details with Activity report: " + e.getMessage()));
        }
    }

    /**
     * Get Rejected Claims Report data
     *
     * @param tab Which tab to fetch: summary, receiverPayer, claimWise
     * @return Rejected Claims Report data
     */
    @Operation(
        summary = "Get Rejected Claims Report",
        description = "Retrieves Rejected Claims Report data across tabs: summary, receiverPayer, and claimWise"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Rejected Claims Report data retrieved successfully"
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid parameters"
        ),
        @ApiResponse(
            responseCode = "403",
            description = "Forbidden - User does not have access to this report"
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token"
        )
    })
    @Deprecated
    @GetMapping("/rejected-claims")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getRejectedClaimsReport(
            @Parameter(description = "Tab to retrieve (summary, receiverPayer, claimWise)", example = "summary")
            @RequestParam(defaultValue = "summary") String tab,
            @RequestParam(required = false) List<String> facilityCodes,
            @RequestParam(required = false) List<String> payerCodes,
            @RequestParam(required = false) List<String> receiverIds,
            @RequestParam(required = false) String fromDate,
            @RequestParam(required = false) String toDate,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer month,
            @RequestParam(required = false) List<String> denialCodes,
            @RequestParam(required = false) String sortBy,
            @RequestParam(required = false) String sortDirection,
            @RequestParam(required = false) Integer page,
            @RequestParam(required = false) Integer size) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.REJECTED_CLAIMS_REPORT)) {
                return ResponseEntity.status(403)
                        .body(Map.of("error", "Access denied: You do not have permission to view this report"));
            }

            if (!Arrays.asList("summary", "receiverPayer", "claimWise").contains(tab)) {
                return ResponseEntity.badRequest()
                        .body(Map.of("error", "Invalid tab. Must be one of: summary, receiverPayer, claimWise"));
            }

            LocalDateTime fromDateTime = null;
            LocalDateTime toDateTime = null;
            if (fromDate != null && !fromDate.isEmpty()) {
                try {
                    fromDateTime = LocalDateTime.parse(fromDate);
                } catch (Exception e) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Invalid fromDate format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
                }
            }
            if (toDate != null && !toDate.isEmpty()) {
                try {
                    toDateTime = LocalDateTime.parse(toDate);
                } catch (Exception e) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Invalid toDate format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
                }
            }

            Map<String, Object> response = new HashMap<>();
            response.put("reportType", ReportType.REJECTED_CLAIMS_REPORT.name());
            response.put("displayName", ReportType.REJECTED_CLAIMS_REPORT.getDisplayName());
            response.put("tab", tab);
            response.put("user", userContext.getUsername());
            response.put("userId", userContext.getUserId());
            response.put("timestamp", java.time.LocalDateTime.now());

            List<Map<String, Object>> data;
            switch (tab) {
                case "summary":
                    data = rejectedClaimsReportService.getSummaryTabData(
                            String.valueOf(userContext.getUserId()),
                            facilityCodes, payerCodes, receiverIds,
                            fromDateTime, toDateTime, year, month,
                            sortBy, sortDirection, page, size,
                            null, null, null);
                    break;
                case "receiverPayer":
                    data = rejectedClaimsReportService.getReceiverPayerTabData(
                            String.valueOf(userContext.getUserId()),
                            facilityCodes, payerCodes, receiverIds,
                            fromDateTime, toDateTime, year, denialCodes,
                            sortBy, sortDirection, page, size,
                            null, null, null);
                    break;
                case "claimWise":
                    data = rejectedClaimsReportService.getClaimWiseTabData(
                            String.valueOf(userContext.getUserId()),
                            facilityCodes, payerCodes, receiverIds,
                            fromDateTime, toDateTime, year, denialCodes,
                            sortBy, sortDirection, page, size,
                            null, null, null);
                    break;
                default:
                    data = List.of();
            }

            response.put("data", data);
            response.put("totalRecords", data.size());
            response.put("filterOptions", rejectedClaimsReportService.getFilterOptions());

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            log.error("Error retrieving Rejected Claims Report for user: {}", userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve Rejected Claims Report: " + e.getMessage()));
        }
    }

    /**
     * Get Doctor Denial Report data
     *
     * @param facilityCode Facility code filter
     * @param clinicianCode Clinician code filter (Ordering Clinician)
     * @param fromDate Start date filter
     * @param toDate End date filter
     * @param year Year filter
     * @param month Month filter
     * @param tab Tab to retrieve (high_denial, summary, detail)
     * @param sortBy Sort by column
     * @param sortDirection Sort direction
     * @param page Page number
     * @param size Page size
     * @param authentication Current user authentication context
     * @return Doctor Denial Report data
     */
    @Operation(
        summary = "Get Doctor Denial Report",
        description = "Retrieves Doctor Denial Report data across three tabs: high_denial (doctors with high denial rates), summary (doctor-wise aggregated metrics), and detail (patient-level claim information)",
        deprecated = true
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Doctor Denial Report data retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"reportType\": \"DOCTOR_DENIAL_REPORT\", \"tab\": \"high_denial\", \"data\": [], \"summary\": {}, \"filters\": {}, \"user\": \"admin\"}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid parameters"
        ),
        @ApiResponse(
            responseCode = "403",
            description = "Forbidden - User does not have access to this report"
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token"
        )
    })
    @Deprecated
    @GetMapping("/doctor-denial")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getDoctorDenialReport(
            @Parameter(description = "Facility code filter")
            @RequestParam(required = false) String facilityCode,
            @Parameter(description = "Clinician code filter (Ordering Clinician)")
            @RequestParam(required = false) String clinicianCode,
            @Parameter(description = "Start date (YYYY-MM-DDTHH:mm:ss)")
            @RequestParam(required = false) String fromDate,
            @Parameter(description = "End date (YYYY-MM-DDTHH:mm:ss)")
            @RequestParam(required = false) String toDate,
            @Parameter(description = "Year filter")
            @RequestParam(required = false) Integer year,
            @Parameter(description = "Month filter (1-12)")
            @RequestParam(required = false) Integer month,
            @Parameter(description = "Tab to retrieve (high_denial, summary, detail)", example = "high_denial")
            @RequestParam(defaultValue = "high_denial") String tab,
            @Parameter(description = "Sort by column")
            @RequestParam(required = false) String sortBy,
            @Parameter(description = "Sort direction (ASC or DESC)")
            @RequestParam(required = false) String sortDirection,
            @Parameter(description = "Page number (0-based)")
            @RequestParam(required = false) Integer page,
            @Parameter(description = "Page size")
            @RequestParam(required = false) Integer size,
            @Parameter(hidden = true) Authentication authentication) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            // Check report access
            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.DOCTOR_DENIAL_REPORT)) {
                log.warn("User {} (ID: {}) attempted to access Doctor Denial Report without permission",
                        userContext.getUsername(), userContext.getUserId());
                return ResponseEntity.status(403)
                        .body(Map.of("error", "Access denied: You do not have permission to view this report"));
            }

            // Parse dates
            LocalDateTime fromDateTime = null;
            LocalDateTime toDateTime = null;

            if (fromDate != null && !fromDate.isEmpty()) {
                try {
                    fromDateTime = LocalDateTime.parse(fromDate);
                } catch (Exception e) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Invalid fromDate format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
                }
            }

            if (toDate != null && !toDate.isEmpty()) {
                try {
                    toDateTime = LocalDateTime.parse(toDate);
                } catch (Exception e) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Invalid toDate format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
                }
            }

            // Validate tab parameter
            if (!Arrays.asList("high_denial", "summary", "detail").contains(tab)) {
                return ResponseEntity.badRequest()
                        .body(Map.of("error", "Invalid tab parameter. Must be one of: high_denial, summary, detail"));
            }

            // Validate month parameter
            if (month != null && (month < 1 || month > 12)) {
                return ResponseEntity.badRequest()
                        .body(Map.of("error", "Invalid month parameter. Must be between 1 and 12"));
            }

            // Get user's accessible facilities for additional filtering
            Set<String> accessibleFacilities = dataFilteringService.getUserAccessibleFacilities();

            // Apply facility filter if user doesn't have access to all facilities
            if (accessibleFacilities != null && !accessibleFacilities.isEmpty() && facilityCode == null) {
                // If no specific facility is requested, limit to accessible facilities
                // This would require modifying the service to accept facility restrictions
                log.debug("User {} has limited facility access: {}", userContext.getUsername(), accessibleFacilities);
            }

            Map<String, Object> response = new HashMap<>();
            response.put("reportType", ReportType.DOCTOR_DENIAL_REPORT.name());
            response.put("displayName", ReportType.DOCTOR_DENIAL_REPORT.getDisplayName());
            response.put("tab", tab);
            response.put("user", userContext.getUsername());
            response.put("userId", userContext.getUserId());
            response.put("timestamp", java.time.LocalDateTime.now());

            // Get report data
            List<Map<String, Object>> data = doctorDenialReportService.getDoctorDenialReport(
                    facilityCode, clinicianCode, fromDateTime, toDateTime, year, month,
                    tab, sortBy, sortDirection, page, size);

            response.put("data", data);
            response.put("totalRecords", data.size());

            // Get summary metrics for dashboard (for high_denial and summary tabs)
            if ("high_denial".equals(tab) || "summary".equals(tab)) {
                Map<String, Object> summary = doctorDenialReportService.getDoctorDenialSummary(
                        facilityCode, clinicianCode, fromDateTime, toDateTime, year, month);
                response.put("summary", summary);
            }

            // Add pagination info
            Map<String, Object> pagination = new HashMap<>();
            if (page != null && size != null) {
                pagination.put("page", page);
                pagination.put("size", size);
                pagination.put("hasNext", data.size() == size); // Simple check - could be improved
                pagination.put("hasPrevious", page > 0);
            }
            response.put("pagination", pagination);

            // Add sorting info
            Map<String, Object> sorting = new HashMap<>();
            sorting.put("sortBy", sortBy);
            sorting.put("sortDirection", sortDirection);
            response.put("sorting", sorting);

            // Add filter options for UI
            response.put("filterOptions", doctorDenialReportService.getFilterOptions());

            // Add applied filters for reference
            Map<String, Object> appliedFilters = new HashMap<>();
            appliedFilters.put("facilityCode", facilityCode);
            appliedFilters.put("clinicianCode", clinicianCode);
            appliedFilters.put("fromDate", fromDate);
            appliedFilters.put("toDate", toDate);
            appliedFilters.put("year", year);
            appliedFilters.put("month", month);
            appliedFilters.put("tab", tab);
            response.put("appliedFilters", appliedFilters);

            log.info("Doctor Denial Report ({}) accessed by user: {} (ID: {}) - {} records returned",
                    tab, userContext.getUsername(), userContext.getUserId(), data.size());

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            log.error("Error retrieving Doctor Denial Report for user: {}",
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve Doctor Denial Report: " + e.getMessage()));
        }
    }

    /**
     * Get claims for a specific clinician (drill-down from doctor denial report)
     *
     * @param clinicianCode Clinician code to get claims for
     * @param facilityCode Facility code filter
     * @param fromDate Start date filter
     * @param toDate End date filter
     * @param year Year filter
     * @param month Month filter
     * @param sortBy Sort by column
     * @param sortDirection Sort direction
     * @param page Page number
     * @param size Page size
     * @param authentication Current user authentication context
     * @return Claims for the specified clinician
     */
    @Operation(
        summary = "Get claims for a specific clinician (drill-down)",
        description = "Retrieves all claims for a specific clinician, allowing drill-down from the doctor denial report summary views to see actual claim details",
        deprecated = true
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Clinician claims retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"clinicianId\": \"DR001\", \"clinicianName\": \"Dr. John Smith\", \"claims\": [], \"totalClaims\": 150, \"user\": \"admin\"}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid parameters"
        ),
        @ApiResponse(
            responseCode = "403",
            description = "Forbidden - User does not have access to this report"
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token"
        )
    })
    @Deprecated
    @GetMapping("/doctor-denial/clinician/{clinicianCode}/claims")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getClinicianClaims(
            @Parameter(description = "Clinician code to get claims for", required = true, example = "DR001")
            @PathVariable String clinicianCode,
            @Parameter(description = "Facility code filter")
            @RequestParam(required = false) String facilityCode,
            @Parameter(description = "Start date (YYYY-MM-DDTHH:mm:ss)")
            @RequestParam(required = false) String fromDate,
            @Parameter(description = "End date (YYYY-MM-DDTHH:mm:ss)")
            @RequestParam(required = false) String toDate,
            @Parameter(description = "Year filter")
            @RequestParam(required = false) Integer year,
            @Parameter(description = "Month filter (1-12)")
            @RequestParam(required = false) Integer month,
            @Parameter(description = "Sort by column")
            @RequestParam(required = false) String sortBy,
            @Parameter(description = "Sort direction (ASC or DESC)")
            @RequestParam(required = false) String sortDirection,
            @Parameter(description = "Page number (0-based)")
            @RequestParam(required = false) Integer page,
            @Parameter(description = "Page size")
            @RequestParam(required = false) Integer size,
            @Parameter(hidden = true) Authentication authentication) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            // Check report access
            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.DOCTOR_DENIAL_REPORT)) {
                log.warn("User {} (ID: {}) attempted to access clinician claims drill-down without permission",
                        userContext.getUsername(), userContext.getUserId());
                return ResponseEntity.status(403)
                        .body(Map.of("error", "Access denied: You do not have permission to view this report"));
            }

            // Parse dates
            LocalDateTime fromDateTime = null;
            LocalDateTime toDateTime = null;

            if (fromDate != null && !fromDate.isEmpty()) {
                try {
                    fromDateTime = LocalDateTime.parse(fromDate);
                } catch (Exception e) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Invalid fromDate format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
                }
            }

            if (toDate != null && !toDate.isEmpty()) {
                try {
                    toDateTime = LocalDateTime.parse(toDate);
                } catch (Exception e) {
                    return ResponseEntity.badRequest()
                            .body(Map.of("error", "Invalid toDate format. Use ISO format: YYYY-MM-DDTHH:mm:ss"));
                }
            }

            // Validate month parameter
            if (month != null && (month < 1 || month > 12)) {
                return ResponseEntity.badRequest()
                        .body(Map.of("error", "Invalid month parameter. Must be between 1 and 12"));
            }

            // Get user's accessible facilities for additional filtering
            Set<String> accessibleFacilities = dataFilteringService.getUserAccessibleFacilities();

            // Apply facility filter if user doesn't have access to all facilities
            if (accessibleFacilities != null && !accessibleFacilities.isEmpty() && facilityCode == null) {
                log.debug("User {} has limited facility access: {}", userContext.getUsername(), accessibleFacilities);
            }

            // Get clinician claims (drill-down data)
            List<Map<String, Object>> claims = doctorDenialReportService.getClinicianClaims(
                    clinicianCode, facilityCode, fromDateTime, toDateTime, year, month,
                    sortBy, sortDirection, page, size);

            // Get clinician info for context
            Map<String, Object> clinicianInfo = new HashMap<>();
            if (!claims.isEmpty()) {
                Map<String, Object> firstClaim = claims.get(0);
                clinicianInfo.put("clinicianId", firstClaim.get("clinicianId"));
                clinicianInfo.put("clinicianName", firstClaim.get("clinicianName"));
            }

            Map<String, Object> response = new HashMap<>();
            response.put("clinicianInfo", clinicianInfo);
            response.put("clinicianCode", clinicianCode);
            response.put("claims", claims);
            response.put("totalClaims", claims.size());
            response.put("user", userContext.getUsername());
            response.put("userId", userContext.getUserId());
            response.put("timestamp", java.time.LocalDateTime.now());

            // Add pagination info
            Map<String, Object> pagination = new HashMap<>();
            if (page != null && size != null) {
                pagination.put("page", page);
                pagination.put("size", size);
                pagination.put("hasNext", claims.size() == size);
                pagination.put("hasPrevious", page > 0);
            }
            response.put("pagination", pagination);

            // Add sorting info
            Map<String, Object> sorting = new HashMap<>();
            sorting.put("sortBy", sortBy);
            sorting.put("sortDirection", sortDirection);
            response.put("sorting", sorting);

            // Add applied filters for reference
            Map<String, Object> appliedFilters = new HashMap<>();
            appliedFilters.put("clinicianCode", clinicianCode);
            appliedFilters.put("facilityCode", facilityCode);
            appliedFilters.put("fromDate", fromDate);
            appliedFilters.put("toDate", toDate);
            appliedFilters.put("year", year);
            appliedFilters.put("month", month);
            response.put("appliedFilters", appliedFilters);

            log.info("Clinician claims drill-down accessed by user: {} (ID: {}) for clinician: {} - {} claims returned",
                    userContext.getUsername(), userContext.getUserId(), clinicianCode, claims.size());

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            log.error("Error retrieving clinician claims for user: {}",
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve clinician claims: " + e.getMessage()));
        }
    }
}
