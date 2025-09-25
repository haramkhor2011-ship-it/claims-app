package com.acme.claims.security.controller;

import com.acme.claims.security.config.SecurityProperties;
import com.acme.claims.security.context.UserContext;
import com.acme.claims.security.service.DataFilteringService;
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
 * REST Controller for data filtering operations and testing.
 * 
 * This controller provides endpoints for testing and managing data filtering
 * capabilities. It's primarily used for debugging and validating that the
 * multi-tenancy filtering is working correctly.
 * 
 * Access is restricted to authenticated users with appropriate roles.
 */
@Slf4j
@RestController
@RequestMapping("/api/security/filtering")
@RequiredArgsConstructor
@Tag(name = "Data Filtering", description = "API for testing and managing data filtering capabilities")
@SecurityRequirement(name = "Bearer Authentication")
public class DataFilteringController {
    
    private final DataFilteringService dataFilteringService;
    private final UserContextService userContextService;
    private final SecurityProperties securityProperties;
    
    /**
     * Get current user's filtering context
     * 
     * @param authentication Current user authentication context
     * @return User's filtering context and permissions
     */
    @Operation(
        summary = "Get user filtering context",
        description = "Retrieves the current user's data filtering context and permissions"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Filtering context retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"user\": \"admin\", \"multiTenancyEnabled\": false, \"isSuperAdmin\": true, \"facilities\": [], \"reports\": []}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
        )
    })
    @GetMapping("/context")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getFilteringContext(
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            
            Map<String, Object> context = new HashMap<>();
            context.put("user", userContext.getUsername());
            context.put("userId", userContext.getUserId());
            context.put("multiTenancyEnabled", securityProperties.getMultiTenancy().isEnabled());
            context.put("isSuperAdmin", userContext.isSuperAdmin());
            context.put("isFacilityAdmin", userContext.isFacilityAdmin());
            context.put("isStaff", userContext.isStaff());
            context.put("facilities", userContext.getFacilities());
            context.put("reports", userContext.getReportTypeNames());
            context.put("primaryFacility", userContext.getPrimaryFacility());
            context.put("ipAddress", userContext.getIpAddress());
            context.put("sessionStartTime", userContext.getSessionStartTime());
            
            log.info("Filtering context retrieved for user: {} (ID: {})", 
                    userContext.getUsername(), userContext.getUserId());
            
            return ResponseEntity.ok(context);
            
        } catch (Exception e) {
            log.error("Error retrieving filtering context for user: {}", 
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve filtering context: " + e.getMessage()));
        }
    }
    
    /**
     * Test facility access filtering
     * 
     * @param facilities List of facility codes to test
     * @param authentication Current user authentication context
     * @return Filtered list of accessible facilities
     */
    @Operation(
        summary = "Test facility access filtering",
        description = "Tests which facilities the current user can access from a provided list"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Facility filtering test completed successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"requested\": [\"FACILITY_001\", \"FACILITY_002\"], \"accessible\": [\"FACILITY_001\"], \"filtered\": 1}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
        )
    })
    @PostMapping("/test/facilities")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> testFacilityFiltering(
            @RequestBody List<String> facilities,
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            
            List<String> accessibleFacilities = dataFilteringService.filterFacilities(facilities);
            
            Map<String, Object> result = new HashMap<>();
            result.put("requested", facilities);
            result.put("accessible", accessibleFacilities);
            result.put("filtered", facilities.size() - accessibleFacilities.size());
            result.put("multiTenancyEnabled", securityProperties.getMultiTenancy().isEnabled());
            result.put("user", userContext.getUsername());
            
            log.info("Facility filtering test completed for user: {} (ID: {}) - Requested: {}, Accessible: {}", 
                    userContext.getUsername(), userContext.getUserId(), 
                    facilities.size(), accessibleFacilities.size());
            
            return ResponseEntity.ok(result);
            
        } catch (Exception e) {
            log.error("Error testing facility filtering for user: {}", 
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to test facility filtering: " + e.getMessage()));
        }
    }
    
    /**
     * Test single facility access
     * 
     * @param facilityCode Facility code to test
     * @param authentication Current user authentication context
     * @return Access result for the facility
     */
    @Operation(
        summary = "Test single facility access",
        description = "Tests if the current user can access a specific facility"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Facility access test completed successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"facilityCode\": \"FACILITY_001\", \"canAccess\": true, \"multiTenancyEnabled\": false}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
        )
    })
    @GetMapping("/test/facility/{facilityCode}")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> testFacilityAccess(
            @PathVariable String facilityCode,
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            
            boolean canAccess = dataFilteringService.canAccessFacility(facilityCode);
            
            Map<String, Object> result = new HashMap<>();
            result.put("facilityCode", facilityCode);
            result.put("canAccess", canAccess);
            result.put("multiTenancyEnabled", securityProperties.getMultiTenancy().isEnabled());
            result.put("user", userContext.getUsername());
            result.put("userFacilities", userContext.getFacilities());
            
            log.info("Facility access test completed for user: {} (ID: {}) - Facility: {}, CanAccess: {}", 
                    userContext.getUsername(), userContext.getUserId(), facilityCode, canAccess);
            
            return ResponseEntity.ok(result);
            
        } catch (Exception e) {
            log.error("Error testing facility access for facility: {} and user: {}", 
                    facilityCode, userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to test facility access: " + e.getMessage()));
        }
    }
    
    /**
     * Test report access filtering
     * 
     * @param reportType Report type to test
     * @param authentication Current user authentication context
     * @return Access result for the report
     */
    @Operation(
        summary = "Test report access",
        description = "Tests if the current user can access a specific report type"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Report access test completed successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"reportType\": \"BALANCE_AMOUNT_REPORT\", \"canAccess\": true, \"multiTenancyEnabled\": false}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
        )
    })
    @GetMapping("/test/report/{reportType}")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> testReportAccess(
            @PathVariable String reportType,
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            
            boolean canAccess = dataFilteringService.canAccessReport(reportType);
            
            Map<String, Object> result = new HashMap<>();
            result.put("reportType", reportType);
            result.put("canAccess", canAccess);
            result.put("multiTenancyEnabled", securityProperties.getMultiTenancy().isEnabled());
            result.put("user", userContext.getUsername());
            result.put("userReports", userContext.getReportTypeNames());
            
            log.info("Report access test completed for user: {} (ID: {}) - Report: {}, CanAccess: {}", 
                    userContext.getUsername(), userContext.getUserId(), reportType, canAccess);
            
            return ResponseEntity.ok(result);
            
        } catch (Exception e) {
            log.error("Error testing report access for report: {} and user: {}", 
                    reportType, userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to test report access: " + e.getMessage()));
        }
    }
    
    /**
     * Get SQL filter clause for testing
     * 
     * @param columnName Database column name for facility filtering
     * @param authentication Current user authentication context
     * @return SQL filter clause and parameters
     */
    @Operation(
        summary = "Get SQL filter clause",
        description = "Generates SQL filter clause for facility-based data filtering"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "SQL filter clause generated successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"filterClause\": \" AND facility_code IN ('FACILITY_001')\", \"parameters\": [\"FACILITY_001\"], \"multiTenancyEnabled\": false}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
        )
    })
    @GetMapping("/test/sql-filter")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<Map<String, Object>> getSqlFilterClause(
            @RequestParam(defaultValue = "facility_code") String columnName,
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            
            String filterClause = dataFilteringService.getFacilityFilterClause(columnName);
            Object[] filterWithParams = dataFilteringService.getFacilityFilterWithParameters(columnName);
            
            Map<String, Object> result = new HashMap<>();
            result.put("columnName", columnName);
            result.put("filterClause", filterClause);
            result.put("filterWithParameters", Map.of(
                "clause", filterWithParams[0],
                "parameters", filterWithParams[1]
            ));
            result.put("multiTenancyEnabled", securityProperties.getMultiTenancy().isEnabled());
            result.put("user", userContext.getUsername());
            result.put("userFacilities", userContext.getFacilities());
            
            log.info("SQL filter clause generated for user: {} (ID: {}) - Column: {}, Clause: {}", 
                    userContext.getUsername(), userContext.getUserId(), columnName, filterClause);
            
            return ResponseEntity.ok(result);
            
        } catch (Exception e) {
            log.error("Error generating SQL filter clause for user: {}", 
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to generate SQL filter clause: " + e.getMessage()));
        }
    }
}
