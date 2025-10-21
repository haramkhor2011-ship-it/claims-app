package com.acme.claims.security.controller;

import com.acme.claims.security.ReportType;
import com.acme.claims.security.context.UserContext;
import com.acme.claims.security.entity.User;
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
import jakarta.validation.Valid;
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
 * REST Controller for managing report access permissions.
 * 
 * This controller provides endpoints for administrators to grant, revoke,
 * and manage report access permissions for users. Access is restricted to
 * users with appropriate administrative roles.
 */
@Slf4j
@RestController
@RequestMapping("/api/admin/report-access")
@RequiredArgsConstructor
@Tag(name = "Report Access Management", description = "API for managing report access permissions")
@SecurityRequirement(name = "Bearer Authentication")
public class ReportAccessController {
    
    private final ReportAccessService reportAccessService;
    private final UserContextService userContextService;
    
    /**
     * Grant report access to a user
     * 
     * @param request Report access grant request
     * @param authentication Current user authentication context
     * @return ResponseEntity indicating success or failure
     */
    @Operation(
        summary = "Grant report access to user",
        description = "Grants access to a specific report type for a user"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Report access granted successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"message\": \"Report access granted successfully\", \"userId\": 1, \"reportType\": \"BALANCE_AMOUNT_REPORT\"}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid user ID or report type",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
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
        )
    })
    @PostMapping("/grant")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<Map<String, Object>> grantReportAccess(
            @Valid @RequestBody GrantReportAccessRequest request,
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            
            log.info("User {} (ID: {}) granting report access - TargetUser: {}, ReportType: {} from IP: {}", 
                    userContext.getUsername(), userContext.getUserId(), 
                    request.getUserId(), request.getReportType(), userContext.getIpAddress());
            
            boolean success = reportAccessService.grantReportAccess(
                    request.getUserId(), 
                    request.getReportType().name(), 
                    userContext.getUserId());
            
            if (success) {
                Map<String, Object> response = new HashMap<>();
                response.put("message", "Report access granted successfully");
                response.put("userId", request.getUserId());
                response.put("reportType", request.getReportType().name());
                response.put("grantedBy", userContext.getUsername());
                response.put("timestamp", java.time.LocalDateTime.now());
                
                log.info("Report access granted successfully - User: {} (ID: {}), Report: {}, GrantedBy: {}", 
                        request.getUserId(), request.getReportType(), userContext.getUsername());
                
                return ResponseEntity.ok(response);
            } else {
                return ResponseEntity.badRequest()
                        .body(Map.of("error", "Failed to grant report access"));
            }
            
        } catch (Exception e) {
            log.error("Error granting report access for user: {} by user: {}", 
                    request.getUserId(), userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to grant report access: " + e.getMessage()));
        }
    }
    
    /**
     * Revoke report access from a user
     * 
     * @param request Report access revoke request
     * @param authentication Current user authentication context
     * @return ResponseEntity indicating success or failure
     */
    @Operation(
        summary = "Revoke report access from user",
        description = "Revokes access to a specific report type for a user"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Report access revoked successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"message\": \"Report access revoked successfully\", \"userId\": 1, \"reportType\": \"BALANCE_AMOUNT_REPORT\"}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid user ID or report type",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
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
        )
    })
    @PostMapping("/revoke")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<Map<String, Object>> revokeReportAccess(
            @Valid @RequestBody RevokeReportAccessRequest request,
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            
            log.info("User {} (ID: {}) revoking report access - TargetUser: {}, ReportType: {} from IP: {}", 
                    userContext.getUsername(), userContext.getUserId(), 
                    request.getUserId(), request.getReportType(), userContext.getIpAddress());
            
            boolean success = reportAccessService.revokeReportAccess(
                    request.getUserId(), 
                    request.getReportType().name(), 
                    userContext.getUserId());
            
            if (success) {
                Map<String, Object> response = new HashMap<>();
                response.put("message", "Report access revoked successfully");
                response.put("userId", request.getUserId());
                response.put("reportType", request.getReportType().name());
                response.put("revokedBy", userContext.getUsername());
                response.put("timestamp", java.time.LocalDateTime.now());
                
                log.info("Report access revoked successfully - User: {} (ID: {}), Report: {}, RevokedBy: {}", 
                        request.getUserId(), request.getReportType(), userContext.getUsername());
                
                return ResponseEntity.ok(response);
            } else {
                return ResponseEntity.badRequest()
                        .body(Map.of("error", "Failed to revoke report access or user did not have access"));
            }
            
        } catch (Exception e) {
            log.error("Error revoking report access for user: {} by user: {}", 
                    request.getUserId(), userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to revoke report access: " + e.getMessage()));
        }
    }
    
    /**
     * Grant multiple report access permissions to a user
     * 
     * @param request Multiple report access grant request
     * @param authentication Current user authentication context
     * @return ResponseEntity indicating success or failure
     */
    @Operation(
        summary = "Grant multiple report access permissions",
        description = "Grants access to multiple report types for a user"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Report access permissions granted successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"message\": \"Report access permissions granted\", \"userId\": 1, \"grantedCount\": 3, \"totalRequested\": 3}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid user ID or report types",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
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
        )
    })
    @PostMapping("/grant-multiple")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<Map<String, Object>> grantMultipleReportAccess(
            @Valid @RequestBody GrantMultipleReportAccessRequest request,
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            
            log.info("User {} (ID: {}) granting multiple report access - TargetUser: {}, ReportTypes: {} from IP: {}", 
                    userContext.getUsername(), userContext.getUserId(), 
                    request.getUserId(), request.getReportTypes(), userContext.getIpAddress());
            
            int grantedCount = reportAccessService.grantMultipleReportAccess(
                    request.getUserId(), 
                    request.getReportTypes().stream()
                            .map(ReportType::name)
                            .collect(java.util.stream.Collectors.toSet()), 
                    userContext.getUserId());
            
            Map<String, Object> response = new HashMap<>();
            response.put("message", "Report access permissions granted");
            response.put("userId", request.getUserId());
            response.put("grantedCount", grantedCount);
            response.put("totalRequested", request.getReportTypes().size());
            response.put("grantedBy", userContext.getUsername());
            response.put("timestamp", java.time.LocalDateTime.now());
            
            log.info("Multiple report access granted - User: {} (ID: {}), Granted: {}/{} by {}", 
                    request.getUserId(), grantedCount, request.getReportTypes().size(), userContext.getUsername());
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error granting multiple report access for user: {} by user: {}", 
                    request.getUserId(), userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to grant multiple report access: " + e.getMessage()));
        }
    }
    
    /**
     * Get users who have access to a specific report type
     * 
     * @param reportType Report type to check
     * @param authentication Current user authentication context
     * @return List of users with access to the report
     */
    @Operation(
        summary = "Get users with report access",
        description = "Retrieves list of users who have access to a specific report type"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Users with report access retrieved successfully"
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Bad request - Invalid report type"
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token"
        ),
        @ApiResponse(
            responseCode = "403",
            description = "Forbidden - Insufficient permissions"
        )
    })
    @GetMapping("/users/{reportType}")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<Map<String, Object>> getUsersWithReportAccess(
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
            
            log.info("User {} (ID: {}) requesting users with access to report: {} from IP: {}", 
                    userContext.getUsername(), userContext.getUserId(), reportType, userContext.getIpAddress());
            
            List<User> usersWithAccess = reportAccessService.getUsersWithReportAccess(reportTypeEnum.name());
            
            List<Map<String, Object>> userList = usersWithAccess.stream()
                    .map(user -> {
                        Map<String, Object> userInfo = new HashMap<>();
                        userInfo.put("userId", user.getId());
                        userInfo.put("username", user.getUsername());
                        userInfo.put("email", user.getEmail());
                        userInfo.put("enabled", user.getEnabled());
                        userInfo.put("roles", user.getRoles().stream()
                                .map(role -> role.getRole().name())
                                .toList());
                        return userInfo;
                    })
                    .toList();
            
            Map<String, Object> response = new HashMap<>();
            response.put("reportType", reportTypeEnum.name());
            response.put("displayName", reportTypeEnum.getDisplayName());
            response.put("users", userList);
            response.put("totalUsers", userList.size());
            response.put("requestedBy", userContext.getUsername());
            response.put("timestamp", java.time.LocalDateTime.now());
            
            log.info("Users with report access retrieved - Report: {}, Users: {} by {}", 
                    reportType, userList.size(), userContext.getUsername());
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error retrieving users with report access for report: {} by user: {}", 
                    reportType, userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve users with report access: " + e.getMessage()));
        }
    }
    
    /**
     * Get all available report types
     * 
     * @param authentication Current user authentication context
     * @return List of all available report types
     */
    @Operation(
        summary = "Get all report types",
        description = "Retrieves list of all available report types in the system"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Report types retrieved successfully"
        ),
        @ApiResponse(
            responseCode = "401",
            description = "Unauthorized - Invalid or missing authentication token"
        ),
        @ApiResponse(
            responseCode = "403",
            description = "Forbidden - Insufficient permissions"
        )
    })
    @GetMapping("/report-types")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<Map<String, Object>> getAllReportTypes(
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            
            log.info("User {} (ID: {}) requesting all report types from IP: {}", 
                    userContext.getUsername(), userContext.getUserId(), userContext.getIpAddress());
            
            List<Map<String, Object>> reportTypes = List.of(ReportType.values()).stream()
                    .map(reportType -> {
                        Map<String, Object> report = new HashMap<>();
                        report.put("type", reportType.name());
                        report.put("displayName", reportType.getDisplayName());
                        report.put("description", reportType.getDescription());
                        return report;
                    })
                    .toList();
            
            Map<String, Object> response = new HashMap<>();
            response.put("reportTypes", reportTypes);
            response.put("totalTypes", reportTypes.size());
            response.put("requestedBy", userContext.getUsername());
            response.put("timestamp", java.time.LocalDateTime.now());
            
            log.info("All report types retrieved by user: {} (ID: {}) - {} types", 
                    userContext.getUsername(), userContext.getUserId(), reportTypes.size());
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error retrieving all report types by user: {}", 
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to retrieve report types: " + e.getMessage()));
        }
    }
    
    // DTOs
    
    @Schema(description = "Request to grant report access to a user")
    public static class GrantReportAccessRequest {
        @Schema(description = "User ID to grant access to", example = "1", required = true)
        private Long userId;
        
        @Schema(description = "Report type to grant access to", example = "BALANCE_AMOUNT_REPORT", required = true)
        private ReportType reportType;
        
        // Getters and setters
        public Long getUserId() { return userId; }
        public void setUserId(Long userId) { this.userId = userId; }
        public ReportType getReportType() { return reportType; }
        public void setReportType(ReportType reportType) { this.reportType = reportType; }
    }
    
    @Schema(description = "Request to revoke report access from a user")
    public static class RevokeReportAccessRequest {
        @Schema(description = "User ID to revoke access from", example = "1", required = true)
        private Long userId;
        
        @Schema(description = "Report type to revoke access from", example = "BALANCE_AMOUNT_REPORT", required = true)
        private ReportType reportType;
        
        // Getters and setters
        public Long getUserId() { return userId; }
        public void setUserId(Long userId) { this.userId = userId; }
        public ReportType getReportType() { return reportType; }
        public void setReportType(ReportType reportType) { this.reportType = reportType; }
    }
    
    @Schema(description = "Request to grant multiple report access permissions to a user")
    public static class GrantMultipleReportAccessRequest {
        @Schema(description = "User ID to grant access to", example = "1", required = true)
        private Long userId;
        
        @Schema(description = "Set of report types to grant access to", required = true)
        private Set<ReportType> reportTypes;
        
        // Getters and setters
        public Long getUserId() { return userId; }
        public void setUserId(Long userId) { this.userId = userId; }
        public Set<ReportType> getReportTypes() { return reportTypes; }
        public void setReportTypes(Set<ReportType> reportTypes) { this.reportTypes = reportTypes; }
    }
}
