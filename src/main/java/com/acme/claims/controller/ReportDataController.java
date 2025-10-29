package com.acme.claims.controller;

import com.acme.claims.audit.AuditLogService;
import com.acme.claims.controller.dto.*;
import com.acme.claims.security.ReportType;
import com.acme.claims.security.context.ServiceUserContext;
import com.acme.claims.security.context.UserContext;
import com.acme.claims.security.entity.ReportsMetadata;
import com.acme.claims.security.service.DataFilteringService;
import com.acme.claims.security.service.ReportAccessService;
import com.acme.claims.security.service.UserContextService;
import com.acme.claims.service.*;
import com.acme.claims.validation.ClaimValidationUtil;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.parameters.RequestBody;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.ErrorResponse;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.*;
import java.util.UUID;

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
    private final AuditLogService auditLogService;
    private final ClaimValidationUtil claimValidationUtil;
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
        ),
        @ApiResponse(
            responseCode = "403",
            description = "Forbidden - Insufficient permissions",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
        ),
        @ApiResponse(
            responseCode = "500",
            description = "Internal server error",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
        )
    })
    @GetMapping("/available")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getAvailableReports(
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            
            Set<ReportsMetadata> accessibleReports = reportAccessService.getUserReportAccess(userContext.getUserId());
            
            List<Map<String, Object>> reportList = accessibleReports.stream()
                    .map(reportMetadata -> {
                        Map<String, Object> report = new HashMap<>();
                        report.put("type", reportMetadata.getReportCode());
                        report.put("displayName", reportMetadata.getReportName());
                        report.put("description", reportMetadata.getDescription());
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
     *
     * @param request The report query request with filters
     * @param authentication Current user authentication context
     * @return Remittances & Resubmission report data
     */
    @Operation(
        summary = "Get Remittances & Resubmission report",
        description = "Retrieves Remittances & Resubmission report data for activity or claim level",
        requestBody = @RequestBody(
            description = "Report query request with filters and pagination",
            required = true,
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = ReportQueryRequest.class),
                examples = @ExampleObject(
                    name = "Remittances Resubmission Request",
                    summary = "Example request for remittances resubmission report",
                    value = """
                    {
                      "reportType": "REMITTANCES_RESUBMISSION",
                      "level": "activity",
                      "facilityCodes": ["FAC001"],
                      "payerCodes": ["DHA"],
                      "receiverCodes": ["PROV001"],
                      "fromDate": "2025-01-01T00:00:00",
                      "toDate": "2025-12-31T23:59:59",
                      "encounterType": "OUTPATIENT",
                      "clinicianCodes": ["DR001"],
                      "claimId": "CLM123456",
                      "cptCode": "99213",
                      "denialCodes": ["DEN001"],
                      "sortBy": "submission_date",
                      "sortDirection": "DESC",
                      "page": 0,
                      "size": 50
                    }
                    """
                )
            )
        )
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Remittances & Resubmission report data retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                schema = @Schema(implementation = ReportResponse.class)
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid parameters",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
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
    @PostMapping("/remittances-resubmission")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<ReportResponse> getRemittancesResubmission(
            @Parameter(description = "Remittances Resubmission report request with filters and pagination", required = true)
            @Valid @RequestBody RemittancesResubmissionRequest request,
            @Parameter(hidden = true) Authentication authentication) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            // Validate report type
            if (request.getReportType() == null || request.getReportType() != ReportType.REMITTANCES_RESUBMISSION) {
                return ResponseEntity.badRequest().body(ReportResponse.builder()
                        .reportType("ERROR")
                        .displayName("Error")
                        .data(List.of())
                        .metadata(Map.of("error", "Report type must be REMITTANCES_RESUBMISSION"))
                        .build());
            }

            // Check report access
            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.REMITTANCES_RESUBMISSION)) {
                log.warn("User {} (ID: {}) attempted to access Remittances Resubmission report without permission",
                        userContext.getUsername(), userContext.getUserId());
                return ResponseEntity.status(403)
                        .body(ReportResponse.builder()
                                .reportType("ERROR")
                                .displayName("Access Denied")
                                .data(List.of())
                                .metadata(Map.of("error", "Access denied: You do not have permission to view this report"))
                                .build());
            }

            // Validate level parameter
            String level = request.getLevel() != null ? request.getLevel() : "activity";
            if (!Arrays.asList("activity", "claim").contains(level)) {
                return ResponseEntity.badRequest().body(ReportResponse.builder()
                        .reportType("ERROR")
                        .displayName("Invalid Level")
                        .data(List.of())
                        .metadata(Map.of("error", "Invalid level. Must be one of: activity, claim"))
                        .build());
            }

            // Get report data based on level
            List<Map<String, Object>> data;
            if ("activity".equals(level)) {
                data = remittancesResubmissionReportService.getActivityLevelData(
                        request.getFacilityId(), request.getFacilityIds(), request.getPayerIds(), 
                        request.getReceiverIds(), request.getFromDate(), request.getToDate(), 
                        request.getEncounterType(), request.getClinicianIds(), request.getClaimNumber(), 
                        request.getCptCode(), request.getDenialFilter(), request.getOrderBy(),
                        request.getPage(), request.getSize(), request.getFacilityRefIds(), 
                        request.getPayerRefIds(), request.getClinicianRefIds());
            } else {
                data = remittancesResubmissionReportService.getClaimLevelData(
                        request.getFacilityId(), request.getFacilityIds(), request.getPayerIds(), 
                        request.getReceiverIds(), request.getFromDate(), request.getToDate(), 
                        request.getEncounterType(), request.getClinicianIds(), request.getClaimNumber(), 
                        request.getDenialFilter(), request.getOrderBy(),
                        request.getPage(), request.getSize(), request.getFacilityRefIds(), 
                        request.getPayerRefIds(), request.getClinicianRefIds());
            }

            // Build response using ReportResponse
            return ResponseEntity.ok(ReportResponse.builder()
                    .reportType(ReportType.REMITTANCES_RESUBMISSION.name())
                    .displayName(ReportType.REMITTANCES_RESUBMISSION.getDisplayName())
                    .data(data)
                    .totalRecords(data.size())
                    .user(userContext.getUsername())
                    .userId(userContext.getUserId())
                    .timestamp(LocalDateTime.now())
                    .parameters(new HashMap<String, Object>() {{
                        put("level", level);
                        put("filterOptions", remittancesResubmissionReportService.getFilterOptions());
                        put("facilityId", request.getFacilityId() != null ? request.getFacilityId() : "");
                        put("facilityIds", request.getFacilityIds() != null ? request.getFacilityIds() : List.of());
                        put("payerIds", request.getPayerIds() != null ? request.getPayerIds() : List.of());
                        put("receiverIds", request.getReceiverIds() != null ? request.getReceiverIds() : List.of());
                        put("encounterType", request.getEncounterType() != null ? request.getEncounterType() : "");
                        put("clinicianIds", request.getClinicianIds() != null ? request.getClinicianIds() : List.of());
                        put("claimNumber", request.getClaimNumber() != null ? request.getClaimNumber() : "");
                        put("cptCode", request.getCptCode() != null ? request.getCptCode() : "");
                        put("denialFilter", request.getDenialFilter() != null ? request.getDenialFilter() : "");
                        put("fromDate", request.getFromDate() != null ? request.getFromDate().toString() : "");
                        put("toDate", request.getToDate() != null ? request.getToDate().toString() : "");
                    }})
                    .metadata(Map.of(
                        "executionTimeMs", System.currentTimeMillis(),
                        "reportType", ReportType.REMITTANCES_RESUBMISSION.name(),
                        "level", level,
                        "user", userContext.getUsername(),
                        "userId", userContext.getUserId()
                    ))
                    .build());

        } catch (Exception e) {
            log.error("Error retrieving Remittances & Resubmission report for user: {}",
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError().body(ReportResponse.builder()
                    .reportType("ERROR")
                    .displayName("Internal Server Error")
                    .data(List.of())
                    .metadata(Map.of("error", "Failed to retrieve Remittances & Resubmission report: " + e.getMessage()))
                    .build());
        }
    }
    
    /**
     * Get balance amount report data
     * 
     * @param request The report query request with filters
     * @param authentication Current user authentication context
     * @return Balance amount report data
     */
    @Operation(
        summary = "Get balance amount report",
        description = "Retrieves balance amount report data (Tab A) with comprehensive filtering options",
        requestBody = @RequestBody(
            description = "Report query request with filters and pagination",
            required = true,
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = ReportQueryRequest.class),
                examples = @ExampleObject(
                    name = "Balance Amount Report Request",
                    summary = "Example request for balance amount report",
                    value = """
                    {
                      "reportType": "BALANCE_AMOUNT_REPORT",
                      "facilityCodes": ["FAC001", "FAC002"],
                      "payerCodes": ["DHA"],
                      "fromDate": "2025-01-01T00:00:00",
                      "toDate": "2025-12-31T23:59:59",
                      "year": 2025,
                      "month": 6,
                      "basedOnInitialNet": true,
                      "sortBy": "aging_days",
                      "sortDirection": "DESC",
                      "page": 0,
                      "size": 50
                    }
                    """
                )
            )
        )
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Balance amount report data retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                schema = @Schema(implementation = ReportResponse.class)
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid parameters",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
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
    @PostMapping("/balance-amount")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<ReportResponse> getBalanceAmountReport(
            @Parameter(description = "Report query request with filters and pagination", required = true)
            @Valid @RequestBody ReportQueryRequest request,
            @Parameter(hidden = true) Authentication authentication) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            // Validate report type
            if (request.getReportType() == null || request.getReportType() != ReportType.BALANCE_AMOUNT_REPORT) {
                return ResponseEntity.badRequest().body(ReportResponse.builder()
                        .reportType("ERROR")
                        .displayName("Error")
                        .data(List.of())
                        .metadata(Map.of("error", "Report type must be BALANCE_AMOUNT_REPORT"))
                        .build());
            }

            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.BALANCE_AMOUNT_REPORT)) {
                return ResponseEntity.status(403)
                        .body(ReportResponse.builder()
                                .reportType("ERROR")
                                .displayName("Access Denied")
                                .data(List.of())
                                .metadata(Map.of("error", "Access denied: You do not have permission to view this report"))
                                .build());
            }

            // Get report data using the service
            List<Map<String, Object>> data = balanceAmountReportService.getTabA_BalanceToBeReceived(
                    String.valueOf(userContext.getUserId()),
                    request.getClaimKeyIds(), 
                    (List<String>) request.getFacilityCodes(), 
                    (List<String>) request.getPayerCodes(), 
                    request.getReceiverIds(),
                    request.getFromDate(), 
                    request.getToDate(), 
                    request.getYear(), 
                    request.getMonth(),
                    request.getBasedOnInitialNet(), 
                    request.getSortBy(), 
                    request.getSortDirection(), 
                    request.getPage(), 
                    request.getSize(),
                    request.getFacilityRefIds(), 
                    request.getPayerRefIds());

            // Build response using ReportResponse
            return ResponseEntity.ok(ReportResponse.builder()
                    .reportType(ReportType.BALANCE_AMOUNT_REPORT.name())
                    .displayName(ReportType.BALANCE_AMOUNT_REPORT.getDisplayName())
                    .data(data)
                    .totalRecords(data.size())
                    .user(userContext.getUsername())
                    .userId(userContext.getUserId())
                    .timestamp(LocalDateTime.now())
                    .parameters(Map.of(
                        "filterOptions", balanceAmountReportService.getFilterOptions(),
                        "facilityCodes", request.getFacilityCodes() != null ? (List<String>) request.getFacilityCodes() : List.of(),
                        "payerCodes", request.getPayerCodes() != null ? (List<String>) request.getPayerCodes() : List.of(),
                        "fromDate", request.getFromDate() != null ? request.getFromDate().toString() : "",
                        "toDate", request.getToDate() != null ? request.getToDate().toString() : ""
                    ))
                    .metadata(Map.of(
                        "executionTimeMs", System.currentTimeMillis(),
                        "reportType", ReportType.BALANCE_AMOUNT_REPORT.name(),
                        "user", userContext.getUsername(),
                        "userId", userContext.getUserId()
                    ))
                    .build());

        } catch (Exception e) {
            log.error("Error retrieving balance amount report for user: {}", userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError().body(ReportResponse.builder()
                    .reportType("ERROR")
                    .displayName("Internal Server Error")
                    .data(List.of())
                    .metadata(Map.of("error", "Failed to retrieve balance amount report: " + e.getMessage()))
                    .build());
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
    @PostMapping(value = "/query", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    @Operation(
        summary = "Query Report Data",
        description = "Unified endpoint for querying all report types with comprehensive filtering, pagination, and access control",
        requestBody = @RequestBody(
            description = "Report query request with filters and pagination options",
            required = true,
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = ReportQueryRequest.class),
                examples = {
                    @ExampleObject(
                        name = "Balance Amount Report",
                        summary = "Example: Balance Amount Report Query",
                        value = """
                        {
                          "reportType": "BALANCE_AMOUNT_REPORT",
                          "tab": "overall",
                          "facilityCodes": ["FAC001", "FAC002"],
                          "fromDate": "2025-01-01T00:00:00",
                          "toDate": "2025-12-31T23:59:59",
                          "page": 0,
                          "size": 50,
                          "sortBy": "aging_days",
                          "sortDirection": "DESC"
                        }
                        """
                    ),
                    @ExampleObject(
                        name = "Rejected Claims Report",
                        summary = "Example: Rejected Claims Report Query",
                        value = """
                        {
                          "reportType": "REJECTED_CLAIMS_REPORT",
                          "tab": "summary",
                          "facilityCodes": ["FAC001"],
                          "payerCodes": ["DHA"],
                          "fromDate": "2025-01-01T00:00:00",
                          "toDate": "2025-12-31T23:59:59",
                          "page": 0,
                          "size": 50
                        }
                        """
                    )
                }
            )
        )
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Report data retrieved successfully",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = ReportResponse.class)
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Invalid request parameters",
            content = @Content(mediaType = "application/json")
        ),
        @ApiResponse(
            responseCode = "403",
            description = "Access denied - insufficient permissions",
            content = @Content(mediaType = "application/json")
        ),
        @ApiResponse(
            responseCode = "404",
            description = "No data found for the specified criteria",
            content = @Content(mediaType = "application/json")
        ),
        @ApiResponse(
            responseCode = "500",
            description = "Internal server error",
            content = @Content(mediaType = "application/json")
        )
    })
    @PreAuthorize("hasRole('STAFF') or hasRole('FACILITY_ADMIN') or hasRole('SUPER_ADMIN')")
    public ResponseEntity<ReportResponse> queryReportData(
            @Parameter(description = "Report query request with filters and pagination", required = true)
            @jakarta.validation.Valid @RequestBody ReportQueryRequest request) {
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            if (request.getReportType() == null) {
                return ResponseEntity.badRequest().body(ReportResponse.builder()
                        .reportType("ERROR")
                        .displayName("Error")
                        .data(List.of())
                        .metadata(Map.of("error", "reportType is required"))
                        .build());
            }

            if (!reportAccessService.hasReportAccess(userContext.getUserId(), request.getReportType())) {
                return ResponseEntity.status(403)
                        .body(ReportResponse.builder()
                                .reportType("ERROR")
                                .displayName("Access Denied")
                                .data(List.of())
                                .metadata(Map.of("error", "Access denied: You do not have permission to view this report"))
                                .build());
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
                        return ResponseEntity.badRequest().body(ReportResponse.builder()
                                .reportType("ERROR")
                                .displayName("Invalid Tab")
                                .data(List.of())
                                .metadata(Map.of("error", "Invalid tab for REMITTANCE_ADVICE_PAYERWISE"))
                                .build());
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
                        return ResponseEntity.badRequest().body(ReportResponse.builder()
                                .reportType("ERROR")
                                .displayName("Invalid Tab")
                                .data(List.of())
                                .metadata(Map.of("error", "Invalid tab for CLAIM_SUMMARY_MONTHWISE"))
                                .build());
                    }
                    break;
                case CLAIM_DETAILS_WITH_ACTIVITY:
                    data = claimDetailsWithActivityReportService.getClaimDetailsWithActivity(
                            request.getFacilityCode(), request.getReceiverCode(), request.getPayerCode(), request.getClinicianCode(),
                            request.getClaimId(), request.getPatientId(), request.getCptCode(), request.getClaimStatus(),
                            request.getPaymentStatus(), request.getEncounterType(), request.getResubType(),
                            (request.getDenialCodes() != null && !request.getDenialCodes().isEmpty()) ? (String) request.getDenialCodes().get(0) : null,
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
                                String.valueOf(userContext.getUserId()), (List<String>) request.getFacilityCodes(), (List<String>) request.getPayerCodes(), request.getReceiverIds(),
                                request.getFromDate(), request.getToDate(), request.getYear(), request.getMonth(),
                                request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize(),
                                request.getFacilityRefIds(), request.getPayerRefIds(), request.getClinicianRefIds());
                    } else if ("receiverPayer".equals(rtab)) {
                        data = rejectedClaimsReportService.getReceiverPayerTabData(
                                String.valueOf(userContext.getUserId()), (List<String>) request.getFacilityCodes(), (List<String>) request.getPayerCodes(), request.getReceiverIds(),
                                request.getFromDate(), request.getToDate(), request.getYear(), (List<String>) request.getDenialCodes(),
                                request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize(),
                                request.getFacilityRefIds(), request.getPayerRefIds(), request.getClinicianRefIds());
                    } else if ("claimWise".equals(rtab)) {
                        data = rejectedClaimsReportService.getClaimWiseTabData(
                                String.valueOf(userContext.getUserId()), (List<String>) request.getFacilityCodes(), (List<String>) request.getPayerCodes(), request.getReceiverIds(),
                                request.getFromDate(), request.getToDate(), request.getYear(), (List<String>) request.getDenialCodes(),
                                request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize(),
                                request.getFacilityRefIds(), request.getPayerRefIds(), request.getClinicianRefIds());
                    } else {
                        return ResponseEntity.badRequest().body(ReportResponse.builder()
                                .reportType("ERROR")
                                .displayName("Invalid Tab")
                                .data(List.of())
                                .metadata(Map.of("error", "Invalid tab for REJECTED_CLAIMS_REPORT"))
                                .build());
                    }
                    break;
                case REMITTANCES_RESUBMISSION:
                    String level = request.getLevel() == null ? "activity" : request.getLevel();
                    if ("activity".equals(level)) {
                        data = remittancesResubmissionReportService.getActivityLevelData(
                                request.getFacilityCode(), (List<String>) request.getFacilityCodes(), (List<String>) request.getPayerCodes(), request.getReceiverIds(),
                                request.getFromDate(), request.getToDate(), request.getEncounterType(), request.getClinicianIds(),
                                request.getClaimId(), request.getCptCode(), request.getDenialFilter(), request.getSortBy(),
                                request.getPage(), request.getSize(), request.getFacilityRefIds(), request.getPayerRefIds(), request.getClinicianRefIds());
                    } else if ("claim".equals(level)) {
                        data = remittancesResubmissionReportService.getClaimLevelData(
                                request.getFacilityCode(), (List<String>) request.getFacilityCodes(), (List<String>) request.getPayerCodes(), request.getReceiverIds(),
                                request.getFromDate(), request.getToDate(), request.getEncounterType(), request.getClinicianIds(),
                                request.getClaimId(), request.getDenialFilter(), request.getSortBy(),
                                request.getPage(), request.getSize(), request.getFacilityRefIds(), request.getPayerRefIds(), request.getClinicianRefIds());
                    } else {
                        return ResponseEntity.badRequest().body(ReportResponse.builder()
                                .reportType("ERROR")
                                .displayName("Invalid Level")
                                .data(List.of())
                                .metadata(Map.of("error", "Invalid level for REMITTANCES_RESUBMISSION"))
                                .build());
                    }
                    break;
                case BALANCE_AMOUNT_REPORT:
                    data = balanceAmountReportService.getTabA_BalanceToBeReceived(
                            String.valueOf(userContext.getUserId()), request.getClaimKeyIds(), (List<String>) request.getFacilityCodes(),
                            (List<String>) request.getPayerCodes(), request.getReceiverIds(), request.getFromDate(), request.getToDate(), request.getYear(), request.getMonth(),
                            request.getBasedOnInitialNet(), request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize(),
                            request.getFacilityRefIds(), request.getPayerRefIds());
                    break;
                default:
                    return ResponseEntity.badRequest().body(ReportResponse.builder()
                            .reportType("ERROR")
                            .displayName("Unsupported Report Type")
                            .data(List.of())
                            .metadata(Map.of("error", "Unsupported reportType"))
                            .build());
            }

            return ResponseEntity.ok(ReportResponse.builder()
                    .reportType(request.getReportType().name())
                    .displayName(request.getReportType().getDisplayName())
                    .data(data)
                    .parameters(parameters)
                    .totalRecords(data.size())
                    .user(userContext.getUsername())
                    .userId(userContext.getUserId())
                    .timestamp(LocalDateTime.now())
                    .metadata(response)
                    .build());
        } catch (Exception e) {
            log.error("Error querying report for user: {}", userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError().body(ReportResponse.builder()
                    .reportType("ERROR")
                    .displayName("Internal Server Error")
                    .data(List.of())
                    .metadata(Map.of("error", "Failed to query report: " + e.getMessage()))
                    .build());
        }
    }

    /**
     * Get Remittance Advice Payerwise report data
     *
     * @param request The report query request with filters
     * @param authentication Current user authentication context
     * @return Remittance Advice Payerwise report data
     */
    @Operation(
        summary = "Get Remittance Advice Payerwise report",
        description = "Retrieves Remittance Advice Payerwise report data with comprehensive filtering options",
        requestBody = @RequestBody(
            description = "Report query request with filters and pagination",
            required = true,
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = ReportQueryRequest.class),
                examples = @ExampleObject(
                    name = "Remittance Advice Payerwise Request",
                    summary = "Example request for remittance advice payerwise report",
                    value = """
                    {
                      "reportType": "REMITTANCE_ADVICE_PAYERWISE",
                      "tab": "header",
                      "facilityCode": "FAC001",
                      "payerCode": "DHA",
                      "receiverCode": "PROV001",
                      "fromDate": "2025-01-01T00:00:00",
                      "toDate": "2025-12-31T23:59:59",
                      "sortBy": "payment_date",
                      "sortDirection": "DESC",
                      "page": 0,
                      "size": 50
                    }
                    """
                )
            )
        )
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Remittance Advice Payerwise report data retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                schema = @Schema(implementation = ReportResponse.class)
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid parameters",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
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
    @PostMapping("/remittance-advice-payerwise")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<ReportResponse> getRemittanceAdvicePayerwiseReport(
            @Parameter(description = "Report query request with filters and pagination", required = true)
            @Valid @RequestBody ReportQueryRequest request,
            @Parameter(hidden = true) Authentication authentication) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            // Validate report type
            if (request.getReportType() == null || request.getReportType() != ReportType.REMITTANCE_ADVICE_PAYERWISE) {
                return ResponseEntity.badRequest().body(ReportResponse.builder()
                        .reportType("ERROR")
                        .displayName("Error")
                        .data(List.of())
                        .metadata(Map.of("error", "Report type must be REMITTANCE_ADVICE_PAYERWISE"))
                        .build());
            }

            // Check report access
            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.REMITTANCE_ADVICE_PAYERWISE)) {
                log.warn("User {} (ID: {}) attempted to access Remittance Advice Payerwise report without permission",
                        userContext.getUsername(), userContext.getUserId());
                return ResponseEntity.status(403)
                        .body(ReportResponse.builder()
                                .reportType("ERROR")
                                .displayName("Access Denied")
                                .data(List.of())
                                .metadata(Map.of("error", "Access denied: You do not have permission to view this report"))
                                .build());
            }

            // Validate tab parameter
            String tab = request.getTab() != null ? request.getTab() : "header";
            if (!Arrays.asList("header", "claimWise", "activityWise").contains(tab)) {
                return ResponseEntity.badRequest().body(ReportResponse.builder()
                        .reportType("ERROR")
                        .displayName("Invalid Tab")
                        .data(List.of())
                        .metadata(Map.of("error", "Invalid tab parameter. Must be one of: header, claimWise, activityWise"))
                        .build());
            }

            // Get report parameters (summary data)
            Map<String, Object> parameters = remittanceAdvicePayerwiseReportService.getReportParameters(
                    request.getFromDate(), request.getToDate(), request.getFacilityCode(), 
                    request.getPayerCode(), request.getReceiverCode(), request.getPaymentReference());

            // Get tab-specific data
            List<Map<String, Object>> data;
            switch (tab) {
                case "header":
                    data = remittanceAdvicePayerwiseReportService.getHeaderTabData(
                            request.getFromDate(), request.getToDate(), request.getFacilityCode(), 
                            request.getPayerCode(), request.getReceiverCode(),
                            request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize());
                    break;
                case "claimWise":
                    data = remittanceAdvicePayerwiseReportService.getClaimWiseTabData(
                            request.getFromDate(), request.getToDate(), request.getFacilityCode(), 
                            request.getPayerCode(), request.getReceiverCode(), request.getPaymentReference(),
                            request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize());
                    break;
                case "activityWise":
                    data = remittanceAdvicePayerwiseReportService.getActivityWiseTabData(
                            request.getFromDate(), request.getToDate(), request.getFacilityCode(), 
                            request.getPayerCode(), request.getReceiverCode(), request.getPaymentReference(),
                            request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize());
                    break;
                default:
                    data = new ArrayList<>();
            }

            // Build response using ReportResponse
            return ResponseEntity.ok(ReportResponse.builder()
                    .reportType(ReportType.REMITTANCE_ADVICE_PAYERWISE.name())
                    .displayName(ReportType.REMITTANCE_ADVICE_PAYERWISE.getDisplayName())
                    .tab(tab)
                    .data(data)
                    .totalRecords(data.size())
                    .user(userContext.getUsername())
                    .userId(userContext.getUserId())
                    .timestamp(LocalDateTime.now())
                    .parameters(Map.of(
                        "summary", parameters,
                        "filterOptions", remittanceAdvicePayerwiseReportService.getFilterOptions(),
                        "facilityCode", request.getFacilityCode() != null ? request.getFacilityCode() : "",
                        "payerCode", request.getPayerCode() != null ? request.getPayerCode() : "",
                        "receiverCode", request.getReceiverCode() != null ? request.getReceiverCode() : "",
                        "fromDate", request.getFromDate() != null ? request.getFromDate().toString() : "",
                        "toDate", request.getToDate() != null ? request.getToDate().toString() : ""
                    ))
                    .metadata(Map.of(
                        "executionTimeMs", System.currentTimeMillis(),
                        "reportType", ReportType.REMITTANCE_ADVICE_PAYERWISE.name(),
                        "tab", tab,
                        "user", userContext.getUsername(),
                        "userId", userContext.getUserId()
                    ))
                    .build());

        } catch (Exception e) {
            log.error("Error retrieving Remittance Advice Payerwise report for user: {}",
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError().body(ReportResponse.builder()
                    .reportType("ERROR")
                    .displayName("Internal Server Error")
                    .data(List.of())
                    .metadata(Map.of("error", "Failed to retrieve Remittance Advice Payerwise report: " + e.getMessage()))
                    .build());
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
     * @param request The report query request with filters
     * @param authentication Current user authentication context
     * @return Claim Summary Monthwise report data
     */
    @Operation(
        summary = "Get Claim Summary Monthwise report",
        description = "Retrieves Claim Summary Monthwise report data with comprehensive filtering and tab options",
        requestBody = @RequestBody(
            description = "Report query request with filters and pagination",
            required = true,
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = ReportQueryRequest.class),
                examples = @ExampleObject(
                    name = "Claim Summary Monthwise Request",
                    summary = "Example request for claim summary monthwise report",
                    value = """
                    {
                      "reportType": "CLAIM_SUMMARY_MONTHWISE",
                      "tab": "monthwise",
                      "facilityCode": "FAC001",
                      "payerCode": "DHA",
                      "receiverCode": "PROV001",
                      "encounterType": "OUTPATIENT",
                      "fromDate": "2025-01-01T00:00:00",
                      "toDate": "2025-12-31T23:59:59",
                      "sortBy": "month",
                      "sortDirection": "ASC",
                      "page": 0,
                      "size": 50
                    }
                    """
                )
            )
        )
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Claim Summary Monthwise report data retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                schema = @Schema(implementation = ReportResponse.class)
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid parameters",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
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
    @PostMapping("/claim-summary-monthwise")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<ReportResponse> getClaimSummaryMonthwiseReport(
            @Parameter(description = "Report query request with filters and pagination", required = true)
            @Valid @RequestBody ReportQueryRequest request,
            @Parameter(hidden = true) Authentication authentication) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            // Validate report type
            if (request.getReportType() == null || request.getReportType() != ReportType.CLAIM_SUMMARY_MONTHWISE) {
                return ResponseEntity.badRequest().body(ReportResponse.builder()
                        .reportType("ERROR")
                        .displayName("Error")
                        .data(List.of())
                        .metadata(Map.of("error", "Report type must be CLAIM_SUMMARY_MONTHWISE"))
                        .build());
            }

            // Check report access
            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.CLAIM_SUMMARY_MONTHWISE)) {
                log.warn("User {} (ID: {}) attempted to access Claim Summary Monthwise report without permission",
                        userContext.getUsername(), userContext.getUserId());
                return ResponseEntity.status(403)
                        .body(ReportResponse.builder()
                                .reportType("ERROR")
                                .displayName("Access Denied")
                                .data(List.of())
                                .metadata(Map.of("error", "Access denied: You do not have permission to view this report"))
                                .build());
            }

            // Validate tab parameter
            String tab = request.getTab() != null ? request.getTab() : "monthwise";
            if (!Arrays.asList("monthwise", "payerwise", "encounterwise").contains(tab)) {
                return ResponseEntity.badRequest().body(ReportResponse.builder()
                        .reportType("ERROR")
                        .displayName("Invalid Tab")
                        .data(List.of())
                        .metadata(Map.of("error", "Invalid tab parameter. Must be one of: monthwise, payerwise, encounterwise"))
                        .build());
            }

            // Get report parameters (summary data)
            Map<String, Object> parameters = claimSummaryMonthwiseReportService.getReportParameters(
                    request.getFromDate(), request.getToDate(), request.getFacilityCode(), 
                    request.getPayerCode(), request.getReceiverCode(), request.getEncounterType());

            // Get tab-specific data
            List<Map<String, Object>> data;
            switch (tab) {
                case "monthwise":
                    data = claimSummaryMonthwiseReportService.getMonthwiseTabData(
                            request.getFromDate(), request.getToDate(), request.getFacilityCode(), 
                            request.getPayerCode(), request.getReceiverCode(),
                            request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize());
                    break;
                case "payerwise":
                    data = claimSummaryMonthwiseReportService.getPayerwiseTabData(
                            request.getFromDate(), request.getToDate(), request.getFacilityCode(), 
                            request.getPayerCode(), request.getReceiverCode(),
                            request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize());
                    break;
                case "encounterwise":
                    data = claimSummaryMonthwiseReportService.getEncounterwiseTabData(
                            request.getFromDate(), request.getToDate(), request.getFacilityCode(), 
                            request.getPayerCode(), request.getReceiverCode(),
                            request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize());
                    break;
                default:
                    data = new ArrayList<>();
            }

            // Build response using ReportResponse
            return ResponseEntity.ok(ReportResponse.builder()
                    .reportType(ReportType.CLAIM_SUMMARY_MONTHWISE.name())
                    .displayName(ReportType.CLAIM_SUMMARY_MONTHWISE.getDisplayName())
                    .tab(tab)
                    .data(data)
                    .totalRecords(data.size())
                    .user(userContext.getUsername())
                    .userId(userContext.getUserId())
                    .timestamp(LocalDateTime.now())
                    .parameters(Map.of(
                        "summary", parameters,
                        "filterOptions", claimSummaryMonthwiseReportService.getFilterOptions(),
                        "facilityCode", request.getFacilityCode() != null ? request.getFacilityCode() : "",
                        "payerCode", request.getPayerCode() != null ? request.getPayerCode() : "",
                        "receiverCode", request.getReceiverCode() != null ? request.getReceiverCode() : "",
                        "encounterType", request.getEncounterType() != null ? request.getEncounterType() : "",
                        "fromDate", request.getFromDate() != null ? request.getFromDate().toString() : "",
                        "toDate", request.getToDate() != null ? request.getToDate().toString() : ""
                    ))
                    .metadata(Map.of(
                        "executionTimeMs", System.currentTimeMillis(),
                        "reportType", ReportType.CLAIM_SUMMARY_MONTHWISE.name(),
                        "tab", tab,
                        "user", userContext.getUsername(),
                        "userId", userContext.getUserId()
                    ))
                    .build());

        } catch (Exception e) {
            log.error("Error retrieving Claim Summary Monthwise report for user: {}",
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError().body(ReportResponse.builder()
                    .reportType("ERROR")
                    .displayName("Internal Server Error")
                    .data(List.of())
                    .metadata(Map.of("error", "Failed to retrieve Claim Summary Monthwise report: " + e.getMessage()))
                    .build());
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
        description = "Retrieves all information related to a specific claim including basic info, encounter, diagnosis, activities, remittance, timeline, attachments, and transaction types in a structured DTO format optimized for UI rendering",
        deprecated = false
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Claim details retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                schema = @Schema(implementation = ClaimDetailsResponse.class),
                examples = @ExampleObject(
                    value = "{\"claimId\": \"CLM001\", \"submission\": {\"fileName\": \"submission_batch_001.xml\", \"ingestionFileId\": 123, \"submissionDate\": \"2024-01-10T09:00:00Z\", \"claimInfo\": {\"claimId\": \"CLM001\", \"payerId\": \"DHA\", \"providerId\": \"PROV001\", \"netAmount\": 1500.00, \"submissionDate\": \"2024-01-10T09:00:00Z\"}, \"encounterInfo\": {\"facilityId\": \"FAC001\", \"encounterType\": \"OUTPATIENT\", \"startDate\": \"2024-01-10T08:00:00Z\"}, \"diagnosisInfo\": [{\"diagnosisCode\": \"Z00.00\", \"diagnosisType\": \"Principal\", \"diagnosisDescription\": \"Encounter for general adult medical examination\"}], \"activitiesInfo\": [{\"activityCode\": \"99213\", \"netAmount\": 150.00, \"quantity\": 1.0, \"clinicianName\": \"Dr. Smith\"}], \"attachments\": [{\"fileName\": \"claim.pdf\", \"createdAt\": \"2024-01-10T09:00:00Z\", \"mimeType\": \"application/pdf\"}]}, \"resubmissions\": [{\"fileName\": \"resubmission_batch_002.xml\", \"ingestionFileId\": 145, \"claimEventId\": 567, \"resubmissionDate\": \"2024-01-20T10:00:00Z\", \"resubmissionType\": \"CORRECTED\", \"resubmissionComment\": \"Corrected diagnosis code\", \"activitiesInfo\": [{\"activityCode\": \"99213\", \"netAmount\": 150.00, \"quantity\": 1.0, \"clinicianName\": \"Dr. Smith\"}], \"attachments\": []}], \"remittances\": [{\"fileName\": \"remittance_batch_003.xml\", \"ingestionFileId\": 178, \"remittanceId\": 89, \"remittanceClaimId\": 234, \"remittanceDate\": \"2024-01-25T14:30:00Z\", \"paymentReference\": \"PAY-2024-001\", \"settlementDate\": \"2024-01-25T00:00:00Z\", \"denialCode\": null, \"activities\": [{\"activityId\": \"ACT001\", \"paymentAmount\": 150.00, \"denialCode\": null}], \"attachments\": []}], \"claimTimeline\": [{\"eventTime\": \"2024-01-10T09:00:00Z\", \"eventType\": \"Submission\", \"currentStatus\": 1}], \"metadata\": {\"user\": \"john.doe\", \"userId\": 123, \"timestamp\": \"2025-10-20T10:30:45\", \"executionTimeMs\": 234}}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "404",
            description = "Claim not found",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                schema = @Schema(implementation = ErrorResponse.class)
            )
        ),
        @ApiResponse(
            responseCode = "403",
            description = "Forbidden - User does not have access to this claim",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                schema = @Schema(implementation = ErrorResponse.class)
            )
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                schema = @Schema(implementation = ErrorResponse.class)
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid claim ID",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                schema = @Schema(implementation = ErrorResponse.class)
            )
        )
    })
    @GetMapping("/claim/{claimId}")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<ClaimDetailsResponse> getClaimDetails(
            @Parameter(description = "Claim ID to retrieve details for", required = true, example = "CLM001")
            @PathVariable String claimId,
            @Parameter(hidden = true) Authentication authentication) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            // Input validation
            claimValidationUtil.validateClaimIdComprehensive(claimId);
            String sanitizedClaimId = claimValidationUtil.sanitizeClaimId(claimId);

            // Check if user has access to this claim (facility-based filtering)
            Set<String> accessibleFacilities = dataFilteringService.getUserAccessibleFacilities();
            if (accessibleFacilities != null && !accessibleFacilities.isEmpty()) {
                // TODO: Implement facility-based claim access check
                // For now, allow access but log the access
                log.debug("User {} accessing claim {} with facility restrictions: {}",
                        userContext.getUsername(), claimId, accessibleFacilities);
            }

            // Get comprehensive claim details using the new service method
            ClaimDetailsResponse claimDetails = claimSummaryMonthwiseReportService.getClaimDetailsById(sanitizedClaimId);

            // Update metadata with user information
            ClaimDetailsResponse.ClaimDetailsMetadata metadata = claimDetails.getMetadata();
            if (metadata != null) {
                metadata.setUser(userContext.getUsername());
                metadata.setUserId(userContext.getUserId());
                metadata.setCorrelationId(UUID.randomUUID().toString());
            }

            log.info("Claim details retrieved for claim ID: {} by user: {} (ID: {}) in {}ms",
                    sanitizedClaimId, userContext.getUsername(), userContext.getUserId(),
                    metadata != null ? metadata.getExecutionTimeMs() : "unknown");

            return ResponseEntity.ok(claimDetails);

        } catch (IllegalArgumentException e) {
            log.warn("Invalid request for claim details: {} by user: {} - {}", 
                    claimId, userContextService.getCurrentUsername(), e.getMessage());
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, e.getMessage());
        } catch (RuntimeException e) {
            if (e.getMessage().contains("not found")) {
                log.warn("Claim not found: {} requested by user: {}", claimId, userContextService.getCurrentUsername());
                throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Claim not found: " + claimId);
            }
            log.error("Error retrieving claim details for claim ID: {} by user: {}",
                    claimId, userContextService.getCurrentUsername(), e);
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, 
                    "Failed to retrieve claim details: " + e.getMessage());
        } catch (Exception e) {
            log.error("Unexpected error retrieving claim details for claim ID: {} by user: {}",
                    claimId, userContextService.getCurrentUsername(), e);
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, 
                    "An unexpected error occurred while retrieving claim details");
        }
    }

    /**
     * Get Claim Details with Activity report data
     *
     * @param request The report query request with filters
     * @param authentication Current user authentication context
     * @return Claim Details with Activity report data
     */
    @Operation(
        summary = "Get Claim Details with Activity report",
        description = "Retrieves comprehensive claim details with activity information including submission tracking, financials, denial info, remittance tracking, patient/payer info, encounter/activity details, and calculated metrics",
        requestBody = @RequestBody(
            description = "Report query request with filters and pagination",
            required = true,
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = ReportQueryRequest.class),
                examples = @ExampleObject(
                    name = "Claim Details with Activity Request",
                    summary = "Example request for claim details with activity report",
                    value = """
                    {
                      "reportType": "CLAIM_DETAILS_WITH_ACTIVITY",
                      "facilityCode": "FAC001",
                      "receiverCode": "PROV001",
                      "payerCode": "DHA",
                      "clinicianCode": "DR001",
                      "claimId": "CLM123456",
                      "patientId": "PAT789",
                      "cptCode": "99213",
                      "encounterType": "OUTPATIENT",
                      "fromDate": "2025-01-01T00:00:00",
                      "toDate": "2025-12-31T23:59:59",
                      "sortBy": "submission_date",
                      "sortDirection": "DESC",
                      "page": 0,
                      "size": 50
                    }
                    """
                )
            )
        )
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Claim Details with Activity report data retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                schema = @Schema(implementation = ReportResponse.class)
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid parameters",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
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
    @PostMapping("/claim-details-with-activity")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<ReportResponse> getClaimDetailsWithActivityReport(
            @Parameter(description = "Claim Details with Activity report request with filters and pagination", required = true)
            @Valid @RequestBody ClaimDetailsWithActivityRequest request,
            @Parameter(hidden = true) Authentication authentication) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            // Validate report type
            if (request.getReportType() == null || request.getReportType() != ReportType.CLAIM_DETAILS_WITH_ACTIVITY) {
                return ResponseEntity.badRequest().body(ReportResponse.builder()
                        .reportType("ERROR")
                        .displayName("Error")
                        .data(List.of())
                        .metadata(Map.of("error", "Report type must be CLAIM_DETAILS_WITH_ACTIVITY"))
                        .build());
            }

            // Check report access
            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.CLAIM_DETAILS_WITH_ACTIVITY)) {
                log.warn("User {} (ID: {}) attempted to access Claim Details with Activity report without permission",
                        userContext.getUsername(), userContext.getUserId());
                return ResponseEntity.status(403)
                        .body(ReportResponse.builder()
                                .reportType("ERROR")
                                .displayName("Access Denied")
                                .data(List.of())
                                .metadata(Map.of("error", "Access denied: You do not have permission to view this report"))
                                .build());
            }

            // Get report data
            List<Map<String, Object>> data = claimDetailsWithActivityReportService.getClaimDetailsWithActivity(
                    request.getFacilityCode(), request.getReceiverId(), request.getPayerCode(), 
                    request.getClinician(), request.getClaimId(), request.getPatientId(), 
                    request.getCptCode(), request.getClaimStatus(), request.getPaymentStatus(), 
                    request.getEncounterType(), request.getResubType(),
                    request.getDenialCode(), request.getMemberId(),
                    request.getFromDate(), request.getToDate(), request.getSortBy(), 
                    request.getSortDirection(), request.getPage(), request.getSize());

            // Get summary metrics for dashboard
            final Map<String, Object> summary = claimDetailsWithActivityReportService.getClaimDetailsSummary(
                    request.getFacilityCode(), request.getReceiverId(), request.getPayerCode(), 
                    request.getFromDate(), request.getToDate());

            // Build response using ReportResponse
            return ResponseEntity.ok(ReportResponse.builder()
                    .reportType(ReportType.CLAIM_DETAILS_WITH_ACTIVITY.name())
                    .displayName(ReportType.CLAIM_DETAILS_WITH_ACTIVITY.getDisplayName())
                    .data(data)
                    .totalRecords(data.size())
                    .user(userContext.getUsername())
                    .userId(userContext.getUserId())
                    .timestamp(LocalDateTime.now())
                    .parameters(new HashMap<String, Object>() {{
                        put("summary", summary);
                        put("filterOptions", claimDetailsWithActivityReportService.getFilterOptions());
                        put("facilityCode", request.getFacilityCode() != null ? request.getFacilityCode() : "");
                        put("receiverId", request.getReceiverId() != null ? request.getReceiverId() : "");
                        put("payerCode", request.getPayerCode() != null ? request.getPayerCode() : "");
                        put("clinician", request.getClinician() != null ? request.getClinician() : "");
                        put("claimId", request.getClaimId() != null ? request.getClaimId() : "");
                        put("patientId", request.getPatientId() != null ? request.getPatientId() : "");
                        put("cptCode", request.getCptCode() != null ? request.getCptCode() : "");
                        put("encounterType", request.getEncounterType() != null ? request.getEncounterType() : "");
                        put("fromDate", request.getFromDate() != null ? request.getFromDate().toString() : "");
                        put("toDate", request.getToDate() != null ? request.getToDate().toString() : "");
                    }})
                    .metadata(Map.of(
                        "executionTimeMs", System.currentTimeMillis(),
                        "reportType", ReportType.CLAIM_DETAILS_WITH_ACTIVITY.name(),
                        "user", userContext.getUsername(),
                        "userId", userContext.getUserId()
                    ))
                    .build());

        } catch (Exception e) {
            log.error("Error retrieving Claim Details with Activity report for user: {}",
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError().body(ReportResponse.builder()
                    .reportType("ERROR")
                    .displayName("Internal Server Error")
                    .data(List.of())
                    .metadata(Map.of("error", "Failed to retrieve Claim Details with Activity report: " + e.getMessage()))
                    .build());
        }
    }

    /**
     * Get Rejected Claims Report data
     *
     * @param request The report query request with filters and tab selection (summary, receiverPayer, claimWise)
     * @param authentication Current user authentication context
     * @return Rejected Claims Report data
     */
    @Operation(
        summary = "Get Rejected Claims Report",
        description = "Retrieves Rejected Claims Report data across tabs: summary, receiverPayer, and claimWise",
        requestBody = @RequestBody(
            description = "Report query request with filters and tab selection",
            required = true,
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = ReportQueryRequest.class),
                examples = @ExampleObject(
                    name = "Rejected Claims Report Request",
                    summary = "Example request for rejected claims report",
                    value = """
                    {
                      "reportType": "REJECTED_CLAIMS_REPORT",
                      "tab": "summary",
                      "facilityCodes": ["FAC001"],
                      "payerCodes": ["DHA"],
                      "fromDate": "2025-01-01T00:00:00",
                      "toDate": "2025-12-31T23:59:59",
                      "year": 2025,
                      "month": 6,
                      "denialCodes": ["DEN001"],
                      "sortBy": "rejection_date",
                      "sortDirection": "DESC",
                      "page": 0,
                      "size": 50
                    }
                    """
                )
            )
        )
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Rejected Claims Report data retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                schema = @Schema(implementation = ReportResponse.class)
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid parameters or tab selection",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
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
    @PostMapping("/rejected-claims")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<ReportResponse> getRejectedClaimsReport(
            @Parameter(description = "Report query request with filters and pagination", required = true)
            @Valid @RequestBody ReportQueryRequest request,
            @Parameter(hidden = true) Authentication authentication) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            // Validate report type
            if (request.getReportType() == null || request.getReportType() != ReportType.REJECTED_CLAIMS_REPORT) {
                return ResponseEntity.badRequest().body(ReportResponse.builder()
                        .reportType("ERROR")
                        .displayName("Error")
                        .data(List.of())
                        .metadata(Map.of("error", "Report type must be REJECTED_CLAIMS_REPORT"))
                        .build());
            }

            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.REJECTED_CLAIMS_REPORT)) {
                return ResponseEntity.status(403)
                        .body(ReportResponse.builder()
                                .reportType("ERROR")
                                .displayName("Access Denied")
                                .data(List.of())
                                .metadata(Map.of("error", "Access denied: You do not have permission to view this report"))
                                .build());
            }

            String tab = request.getTab() != null ? request.getTab() : "summary";
            if (!Arrays.asList("summary", "receiverPayer", "claimWise").contains(tab)) {
                return ResponseEntity.badRequest().body(ReportResponse.builder()
                        .reportType("ERROR")
                        .displayName("Invalid Tab")
                        .data(List.of())
                        .metadata(Map.of("error", "Invalid tab. Must be one of: summary, receiverPayer, claimWise"))
                        .build());
            }

            List<Map<String, Object>> data;
            switch (tab) {
                case "summary":
                    data = rejectedClaimsReportService.getSummaryTabData(
                            String.valueOf(userContext.getUserId()),
                            (List<String>) request.getFacilityCodes(), (List<String>) request.getPayerCodes(), request.getReceiverIds(),
                            request.getFromDate(), request.getToDate(), request.getYear(), request.getMonth(),
                            request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize(),
                            request.getFacilityRefIds(), request.getPayerRefIds(), request.getClinicianRefIds());
                    break;
                case "receiverPayer":
                    data = rejectedClaimsReportService.getReceiverPayerTabData(
                            String.valueOf(userContext.getUserId()),
                            (List<String>) request.getFacilityCodes(), (List<String>) request.getPayerCodes(), request.getReceiverIds(),
                            request.getFromDate(), request.getToDate(), request.getYear(), (List<String>) request.getDenialCodes(),
                            request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize(),
                            request.getFacilityRefIds(), request.getPayerRefIds(), request.getClinicianRefIds());
                    break;
                case "claimWise":
                    data = rejectedClaimsReportService.getClaimWiseTabData(
                            String.valueOf(userContext.getUserId()),
                            (List<String>) request.getFacilityCodes(), (List<String>) request.getPayerCodes(), request.getReceiverIds(),
                            request.getFromDate(), request.getToDate(), request.getYear(), (List<String>) request.getDenialCodes(),
                            request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize(),
                            request.getFacilityRefIds(), request.getPayerRefIds(), request.getClinicianRefIds());
                    break;
                default:
                    data = List.of();
            }

            return ResponseEntity.ok(ReportResponse.builder()
                    .reportType(ReportType.REJECTED_CLAIMS_REPORT.name())
                    .displayName(ReportType.REJECTED_CLAIMS_REPORT.getDisplayName())
                    .tab(tab)
                    .data(data)
                    .totalRecords(data.size())
                    .user(userContext.getUsername())
                    .userId(userContext.getUserId())
                    .timestamp(LocalDateTime.now())
                    .parameters(Map.of(
                        "filterOptions", rejectedClaimsReportService.getFilterOptions(),
                        "facilityCodes", request.getFacilityCodes() != null ? (List<String>) request.getFacilityCodes() : List.of(),
                        "payerCodes", request.getPayerCodes() != null ? (List<String>) request.getPayerCodes() : List.of(),
                        "fromDate", request.getFromDate() != null ? request.getFromDate().toString() : "",
                        "toDate", request.getToDate() != null ? request.getToDate().toString() : ""
                    ))
                    .metadata(Map.of(
                        "executionTimeMs", System.currentTimeMillis(),
                        "reportType", ReportType.REJECTED_CLAIMS_REPORT.name(),
                        "tab", tab,
                        "user", userContext.getUsername(),
                        "userId", userContext.getUserId()
                    ))
                    .build());

        } catch (Exception e) {
            log.error("Error retrieving Rejected Claims Report for user: {}", userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError().body(ReportResponse.builder()
                    .reportType("ERROR")
                    .displayName("Internal Server Error")
                    .data(List.of())
                    .metadata(Map.of("error", "Failed to retrieve Rejected Claims Report: " + e.getMessage()))
                    .build());
        }
    }

    /**
     * Get Doctor Denial Report data
     *
     * @param request The report query request with filters
     * @param authentication Current user authentication context
     * @return Doctor Denial Report data
     */
    @Operation(
        summary = "Get Doctor Denial Report",
        description = "Retrieves Doctor Denial Report data across three tabs: high_denial (doctors with high denial rates), summary (doctor-wise aggregated metrics), and detail (patient-level claim information)",
        requestBody = @RequestBody(
            description = "Report query request with filters and pagination",
            required = true,
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = ReportQueryRequest.class),
                examples = @ExampleObject(
                    name = "Doctor Denial Request",
                    summary = "Example request for doctor denial report",
                    value = """
                    {
                      "reportType": "DOCTOR_DENIAL_REPORT",
                      "facilityCode": "FAC001",
                      "clinicianCode": "DR001",
                      "fromDate": "2025-01-01T00:00:00",
                      "toDate": "2025-12-31T23:59:59",
                      "year": 2025,
                      "month": 1,
                      "tab": "high_denial",
                      "sortBy": "denial_count",
                      "sortDirection": "DESC",
                      "page": 0,
                      "size": 50
                    }
                    """
                )
            )
        )
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Doctor Denial Report data retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                schema = @Schema(implementation = ReportResponse.class)
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid parameters",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
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
    @PostMapping("/doctor-denial")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<ReportResponse> getDoctorDenialReport(
            @Parameter(description = "Report query request with filters and pagination", required = true)
            @Valid @RequestBody ReportQueryRequest request,
            @Parameter(hidden = true) Authentication authentication) {

        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();

            // Validate report type
            if (request.getReportType() == null || request.getReportType() != ReportType.DOCTOR_DENIAL_REPORT) {
                return ResponseEntity.badRequest().body(ReportResponse.builder()
                        .reportType("ERROR")
                        .displayName("Error")
                        .data(List.of())
                        .metadata(Map.of("error", "Report type must be DOCTOR_DENIAL_REPORT"))
                        .build());
            }

            // Check report access
            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.DOCTOR_DENIAL_REPORT)) {
                log.warn("User {} (ID: {}) attempted to access Doctor Denial Report without permission",
                        userContext.getUsername(), userContext.getUserId());
                return ResponseEntity.status(403)
                        .body(ReportResponse.builder()
                                .reportType("ERROR")
                                .displayName("Access Denied")
                                .data(List.of())
                                .metadata(Map.of("error", "Access denied: You do not have permission to view this report"))
                                .build());
            }

            // Validate tab parameter
            String tab = request.getTab() != null ? request.getTab() : "high_denial";
            if (!Arrays.asList("high_denial", "summary", "detail").contains(tab)) {
                return ResponseEntity.badRequest().body(ReportResponse.builder()
                        .reportType("ERROR")
                        .displayName("Invalid Tab")
                        .data(List.of())
                        .metadata(Map.of("error", "Invalid tab parameter. Must be one of: high_denial, summary, detail"))
                        .build());
            }

            // Validate month parameter
            if (request.getMonth() != null && (request.getMonth() < 1 || request.getMonth() > 12)) {
                return ResponseEntity.badRequest().body(ReportResponse.builder()
                        .reportType("ERROR")
                        .displayName("Invalid Month")
                        .data(List.of())
                        .metadata(Map.of("error", "Invalid month parameter. Must be between 1 and 12"))
                        .build());
            }

            // Get report data
            List<Map<String, Object>> data = doctorDenialReportService.getDoctorDenialReport(
                    request.getFacilityCode(), request.getClinicianCode(), request.getFromDate(), 
                    request.getToDate(), request.getYear(), request.getMonth(),
                    tab, request.getSortBy(), request.getSortDirection(), request.getPage(), request.getSize());

            // Get summary metrics for dashboard (for high_denial and summary tabs)
            final Map<String, Object> summary;
            if ("high_denial".equals(tab) || "summary".equals(tab)) {
                summary = doctorDenialReportService.getDoctorDenialSummary(
                        request.getFacilityCode(), request.getClinicianCode(), 
                        request.getFromDate(), request.getToDate(), request.getYear(), request.getMonth());
            } else {
                summary = null;
            }

            // Build response using ReportResponse
            return ResponseEntity.ok(ReportResponse.builder()
                    .reportType(ReportType.DOCTOR_DENIAL_REPORT.name())
                    .displayName(ReportType.DOCTOR_DENIAL_REPORT.getDisplayName())
                    .data(data)
                    .totalRecords(data.size())
                    .user(userContext.getUsername())
                    .userId(userContext.getUserId())
                    .timestamp(LocalDateTime.now())
                    .parameters(new HashMap<String, Object>() {{
                        put("tab", tab);
                        put("summary", summary != null ? summary : Map.of());
                        put("filterOptions", doctorDenialReportService.getFilterOptions());
                        put("facilityCode", request.getFacilityCode() != null ? request.getFacilityCode() : "");
                        put("clinicianCode", request.getClinicianCode() != null ? request.getClinicianCode() : "");
                        put("fromDate", request.getFromDate() != null ? request.getFromDate().toString() : "");
                        put("toDate", request.getToDate() != null ? request.getToDate().toString() : "");
                        put("year", request.getYear() != null ? request.getYear().toString() : "");
                        put("month", request.getMonth() != null ? request.getMonth().toString() : "");
                    }})
                    .metadata(Map.of(
                        "executionTimeMs", System.currentTimeMillis(),
                        "reportType", ReportType.DOCTOR_DENIAL_REPORT.name(),
                        "tab", tab,
                        "user", userContext.getUsername(),
                        "userId", userContext.getUserId()
                    ))
                    .build());

        } catch (Exception e) {
            log.error("Error retrieving Doctor Denial Report for user: {}",
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError().body(ReportResponse.builder()
                    .reportType("ERROR")
                    .displayName("Internal Server Error")
                    .data(List.of())
                    .metadata(Map.of("error", "Failed to retrieve Doctor Denial Report: " + e.getMessage()))
                    .build());
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
    
    /**
     * Execute report query based on report type and user context
     * 
     * @param request The filtered report query request
     * @param userContext The service user context
     * @return List of report data
     */
    private List<Map<String, Object>> executeReportQuery(ReportQueryRequest request, ServiceUserContext userContext) {
        // This method will route to the appropriate service based on report type
        // For now, return empty list - this will be implemented when we integrate with services
        return List.of();
    }
    
    /**
     * Build standardized report response with pagination and metadata
     * 
     * @param data The report data
     * @param request The original request
     * @param userContext The user context
     * @param correlationId The correlation ID
     * @param startTime The request start time
     * @return ReportResponse with all metadata
     */
    private ReportResponse buildReportResponse(List<Map<String, Object>> data, ReportQueryRequest request, 
                                             ServiceUserContext userContext, String correlationId, long startTime) {
        
        // Build pagination metadata
        PaginationMetadata pagination = PaginationMetadata.builder()
                .page(request.getPage() != null ? request.getPage() : 0)
                .size(request.getSize() != null ? request.getSize() : 50)
                .totalElements((long) data.size())
                .totalPages((int) Math.ceil((double) data.size() / (request.getSize() != null ? request.getSize() : 50)))
                .hasNext(request.getPage() != null && request.getPage() > 0)
                .hasPrevious(false) // Will be calculated properly in real implementation
                .build();
        
        // Build filter metadata
        FilterMetadata filters = FilterMetadata.builder()
                .appliedFilters(Map.of(
                    "facilityCodes", request.getFacilityCodes() != null ? request.getFacilityCodes() : List.of(),
                    "payerCodes", request.getPayerCodes() != null ? request.getPayerCodes() : List.of(),
                    "fromDate", request.getFromDate() != null ? request.getFromDate().toString() : "",
                    "toDate", request.getToDate() != null ? request.getToDate().toString() : ""
                ))
                .availableOptions(Map.of(
                    "facilityCodes", new ArrayList<>(userContext.getAccessibleFacilities()),
                    "payerCodes", List.of("DHA", "ADNOC") // This would come from database in real implementation
                ))
                .build();
        
        // Build response metadata
        Map<String, Object> metadata = Map.of(
            "reportType", request.getReportType().name(),
            "tab", request.getTab() != null ? request.getTab() : "",
            "level", request.getLevel() != null ? request.getLevel() : "",
            "generatedAt", LocalDateTime.now().toString(),
            "executionTimeMs", System.currentTimeMillis() - startTime,
            "correlationId", correlationId != null ? correlationId : "",
            "userId", userContext.getUserId(),
            "username", userContext.getUsername()
        );
        
        return ReportResponse.builder()
                .reportType(request.getReportType().name())
                .displayName(request.getReportType().getDisplayName())
                .tab(request.getTab())
                .level(request.getLevel())
                .data(data)
                .pagination(pagination)
                .filters(filters)
                .parameters(Map.of()) // Empty for now, will be populated by individual services
                .user(userContext.getUsername())
                .userId(userContext.getUserId())
                .timestamp(LocalDateTime.now())
                .correlationId(correlationId)
                .executionTimeMs(System.currentTimeMillis() - startTime)
                .totalRecords(data.size())
                .metadata(metadata)
                .build();
    }
}

