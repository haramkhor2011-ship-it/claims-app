package com.acme.claims.controller;

import com.acme.claims.security.context.UserContext;
import com.acme.claims.security.entity.User;
import com.acme.claims.security.service.UserContextService;
import com.acme.claims.util.ReportViewGenerator;
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

import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * REST Controller for generating database views and materialized views
 * based on the JSON mapping configuration.
 * 
 * This controller provides endpoints for generating SQL views and materialized views
 * for various report types. Access is restricted to users with appropriate roles.
 */
@Slf4j
@RestController
@RequestMapping("/api/reports/views")
@RequiredArgsConstructor
@Tag(name = "Report View Generation", description = "API for generating database views and materialized views for reports")
@SecurityRequirement(name = "Bearer Authentication")
public class ReportViewGenerationController {
    
    private final ReportViewGenerator reportViewGenerator;
    private final UserContextService userContextService;
    
    /**
     * Get all column mappings from the JSON configuration
     * 
     * @param authentication Current user authentication context
     * @return List of column mappings for report view generation
     */
    @Operation(
        summary = "Get column mappings",
        description = "Retrieves all column mappings from the JSON configuration file used for generating report views"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Column mappings retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                schema = @Schema(implementation = ReportViewGenerator.ColumnMapping.class)
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
    @GetMapping("/mappings")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<List<ReportViewGenerator.ColumnMapping>> getColumnMappings(
            @Parameter(hidden = true) Authentication authentication) {
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            log.info("User {} (ID: {}) requested column mappings from IP: {}", 
                    userContext.getUsername(), userContext.getUserId(), userContext.getIpAddress());
            
            List<ReportViewGenerator.ColumnMapping> mappings = reportViewGenerator.loadColumnMappings();
            
            log.info("Successfully loaded {} column mappings for user: {}", 
                    mappings.size(), userContext.getUsername());
            
            return ResponseEntity.ok(mappings);
        } catch (IOException e) {
            log.error("Error loading column mappings for user: {}", 
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * Generate comprehensive view SQL
     * 
     * @param authentication Current user authentication context
     * @return SQL script for comprehensive claims report view
     */
    @Operation(
        summary = "Generate comprehensive view SQL",
        description = "Generates SQL script for creating a comprehensive claims report view with all fields from JSON mapping"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "SQL script generated successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"sql\": \"CREATE VIEW v_comprehensive_claims_report_generated AS SELECT...\", \"viewName\": \"v_comprehensive_claims_report_generated\", \"description\": \"Comprehensive claims report view generated from JSON mapping\"}"
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
    @GetMapping("/sql/comprehensive")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<Map<String, String>> generateComprehensiveViewSql(
            @Parameter(hidden = true) Authentication authentication) {
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            log.info("User {} (ID: {}) requested comprehensive view SQL generation from IP: {}", 
                    userContext.getUsername(), userContext.getUserId(), userContext.getIpAddress());
            
            List<ReportViewGenerator.ColumnMapping> mappings = reportViewGenerator.loadColumnMappings();
            String sql = reportViewGenerator.generateComprehensiveViewSql(mappings);
            
            Map<String, String> response = new HashMap<>();
            response.put("sql", sql);
            response.put("viewName", "v_comprehensive_claims_report_generated");
            response.put("description", "Comprehensive claims report view generated from JSON mapping");
            
            log.info("Successfully generated comprehensive view SQL for user: {} (SQL length: {} chars)", 
                    userContext.getUsername(), sql.length());
            
            return ResponseEntity.ok(response);
        } catch (IOException e) {
            log.error("Error generating comprehensive view SQL for user: {}", 
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * Generate balance amount view SQL
     * 
     * @param authentication Current user authentication context
     * @return SQL script for balance amount report view
     */
    @Operation(
        summary = "Generate balance amount view SQL",
        description = "Generates SQL script for creating a balance amount report view for outstanding balances"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "SQL script generated successfully"),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "403", description = "Forbidden"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    @GetMapping("/sql/balance-amount")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<Map<String, String>> generateBalanceAmountViewSql(
            @Parameter(hidden = true) Authentication authentication) {
        try {
            User currentUser = (User) authentication.getPrincipal();
            log.info("User {} requested balance amount view SQL generation", currentUser.getUsername());
            
            List<ReportViewGenerator.ColumnMapping> mappings = reportViewGenerator.loadColumnMappings();
            String sql = reportViewGenerator.generateBalanceAmountViewSql(mappings);
            
            Map<String, String> response = new HashMap<>();
            response.put("sql", sql);
            response.put("viewName", "v_balance_amount_report_generated");
            response.put("description", "Balance amount report view generated from JSON mapping");
            
            return ResponseEntity.ok(response);
        } catch (IOException e) {
            log.error("Error generating balance amount view SQL", e);
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * Generate materialized views SQL
     * 
     * @param authentication Current user authentication context
     * @return SQL script for materialized views
     */
    @Operation(
        summary = "Generate materialized views SQL",
        description = "Generates SQL script for creating materialized views for performance optimization"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "SQL script generated successfully"),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "403", description = "Forbidden"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    @GetMapping("/sql/materialized-views")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<Map<String, String>> generateMaterializedViewsSql(
            @Parameter(hidden = true) Authentication authentication) {
        try {
            User currentUser = (User) authentication.getPrincipal();
            log.info("User {} requested materialized views SQL generation", currentUser.getUsername());
            
            String sql = reportViewGenerator.generateMaterializedViewsSql();
            
            Map<String, String> response = new HashMap<>();
            response.put("sql", sql);
            response.put("description", "Materialized views generated from JSON mapping");
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error generating materialized views SQL", e);
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * Generate complete SQL script for all views and materialized views
     * 
     * @param authentication Current user authentication context
     * @return Complete SQL script for all views and materialized views
     */
    @Operation(
        summary = "Generate complete SQL script",
        description = "Generates complete SQL script for all views and materialized views from JSON mapping"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "SQL script generated successfully"),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "403", description = "Forbidden"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    @GetMapping("/sql/complete")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<Map<String, String>> generateCompleteSqlScript(
            @Parameter(hidden = true) Authentication authentication) {
        try {
            User currentUser = (User) authentication.getPrincipal();
            log.info("User {} requested complete SQL script generation", currentUser.getUsername());
            
            String sql = reportViewGenerator.generateCompleteSqlScript();
            
            Map<String, String> response = new HashMap<>();
            response.put("sql", sql);
            response.put("description", "Complete SQL script for all views and materialized views generated from JSON mapping");
            
            return ResponseEntity.ok(response);
        } catch (IOException e) {
            log.error("Error generating complete SQL script", e);
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * Get information about available view types
     * 
     * @param authentication Current user authentication context
     * @return Information about available view types and endpoints
     */
    @Operation(
        summary = "Get view information",
        description = "Retrieves information about available view types and API endpoints"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "View information retrieved successfully"),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "403", description = "Forbidden")
    })
    @GetMapping("/info")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
    public ResponseEntity<Map<String, Object>> getViewInfo(
            @Parameter(hidden = true) Authentication authentication) {
        try {
            User currentUser = (User) authentication.getPrincipal();
            log.info("User {} requested view information", currentUser.getUsername());
            
            Map<String, Object> info = new HashMap<>();
            
            Map<String, String> viewTypes = new HashMap<>();
            viewTypes.put("comprehensive", "Comprehensive claims report view with all fields from JSON mapping");
            viewTypes.put("balance-amount", "Balance amount specific view for outstanding balances");
            viewTypes.put("materialized-views", "Materialized views for performance optimization");
            
            info.put("availableViewTypes", viewTypes);
            info.put("endpoints", Map.of(
                "mappings", "/api/reports/views/mappings",
                "comprehensive", "/api/reports/views/sql/comprehensive",
                "balance-amount", "/api/reports/views/sql/balance-amount",
                "materialized-views", "/api/reports/views/sql/materialized-views",
                "complete", "/api/reports/views/sql/complete"
            ));
            info.put("description", "View generation API based on JSON mapping configuration");
            info.put("user", Map.of(
                "username", currentUser.getUsername(),
                "roles", currentUser.getRoles().stream()
                        .map(role -> role.getRole().name())
                        .toList()
            ));
            
            // Add report access information
            info.put("reportAccess", Map.of(
                "accessibleReports", currentUser.getReportTypeNames(),
                "totalReports", com.acme.claims.security.ReportType.values().length,
                "hasAllReports", currentUser.isSuperAdmin() || currentUser.isFacilityAdmin()
            ));
            
            return ResponseEntity.ok(info);
        } catch (Exception e) {
            log.error("Error retrieving view information", e);
            return ResponseEntity.internalServerError().build();
        }
    }
}
