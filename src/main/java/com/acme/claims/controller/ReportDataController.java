package com.acme.claims.controller;

import com.acme.claims.security.ReportType;
import com.acme.claims.security.context.UserContext;
import com.acme.claims.security.service.DataFilteringService;
import com.acme.claims.security.service.ReportAccessService;
import com.acme.claims.security.service.UserContextService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

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
     * Get balance amount report data
     * 
     * @param authentication Current user authentication context
     * @return Balance amount report data
     */
    @Operation(
        summary = "Get balance amount report",
        description = "Retrieves balance amount report data for the current user's accessible facilities"
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
    @GetMapping("/balance-amount")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getBalanceAmountReport(
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            
            // Check report access
            if (!reportAccessService.hasReportAccess(userContext.getUserId(), ReportType.BALANCE_AMOUNT_REPORT)) {
                log.warn("User {} (ID: {}) attempted to access balance amount report without permission", 
                        userContext.getUsername(), userContext.getUserId());
                return ResponseEntity.status(403)
                        .body(Map.of("error", "Access denied: You do not have permission to view this report"));
            }
            
            // Get user's accessible facilities
            Set<String> accessibleFacilities = dataFilteringService.getUserAccessibleFacilities();
            
            // TODO: Implement actual data retrieval from database
            // For now, return mock data structure
            Map<String, Object> response = new HashMap<>();
            response.put("reportType", ReportType.BALANCE_AMOUNT_REPORT.name());
            response.put("displayName", ReportType.BALANCE_AMOUNT_REPORT.getDisplayName());
            response.put("data", List.of()); // TODO: Replace with actual data query
            response.put("facilities", accessibleFacilities);
            response.put("user", userContext.getUsername());
            response.put("userId", userContext.getUserId());
            response.put("timestamp", java.time.LocalDateTime.now());
            response.put("note", "This is a placeholder response. Actual data retrieval will be implemented.");
            
            log.info("Balance amount report accessed by user: {} (ID: {}) for facilities: {}", 
                    userContext.getUsername(), userContext.getUserId(), accessibleFacilities);
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error retrieving balance amount report for user: {}", 
                    userContextService.getCurrentUsername(), e);
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
        description = "Retrieves claim details with activity report data for the current user's accessible facilities"
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
        description = "Retrieves report data for a specific report type with access control"
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
     * Get report access summary for the current user
     * 
     * @param authentication Current user authentication context
     * @return Report access summary
     */
    @Operation(
        summary = "Get report access summary",
        description = "Retrieves a summary of the current user's report access permissions"
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
}
