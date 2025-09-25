package com.acme.claims.admin;

import com.acme.claims.security.ame.ReencryptJob;
import com.acme.claims.security.context.UserContext;
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

import java.util.Map;

/**
 * REST Controller for facility administration operations.
 * 
 * This controller provides endpoints for managing DHPO facility configurations,
 * including creating, updating, retrieving, and activating facilities.
 * Access is restricted to users with appropriate administrative roles.
 */
@Slf4j
@RestController
@RequestMapping("/admin/facilities")
@RequiredArgsConstructor
@Tag(name = "Facility Administration", description = "API for managing DHPO facility configurations")
@SecurityRequirement(name = "Bearer Authentication")
public class FacilityAdminController {

    private final FacilityAdminService svc;
    private final ReencryptJob reencrypt;
    private final UserContextService userContextService;

    /**
     * Create or update a facility configuration
     * 
     * @param dto Facility data transfer object
     * @param authentication Current user authentication context
     * @return ResponseEntity indicating success or failure
     */
    @Operation(
        summary = "Create or update facility",
        description = "Creates a new facility configuration or updates an existing one with DHPO credentials"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Facility created or updated successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"message\": \"Facility created successfully\", \"facilityCode\": \"FACILITY_001\"}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "400",
            description = "Invalid facility data",
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
        ),
        @ApiResponse(
            responseCode = "500",
            description = "Internal server error",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
        )
    })
    @PostMapping
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<Map<String, Object>> createOrUpdate(
            @Valid @RequestBody FacilityAdminService.FacilityDto dto,
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            log.info("User {} (ID: {}) creating/updating facility: {} from IP: {}", 
                    userContext.getUsername(), userContext.getUserId(), dto.facilityCode(), userContext.getIpAddress());
            
            svc.upsert(dto);
            
            log.info("Successfully created/updated facility: {} by user: {} (ID: {})", 
                    dto.facilityCode(), userContext.getUsername(), userContext.getUserId());
            
            Map<String, Object> response = Map.of(
                "message", "Facility created/updated successfully",
                "facilityCode", dto.facilityCode(),
                "facilityName", dto.facilityName(),
                "updatedBy", userContext.getUsername(),
                "timestamp", java.time.LocalDateTime.now()
            );
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error creating/updating facility: {} by user: {}", 
                    dto.facilityCode(), userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to create/update facility: " + e.getMessage()));
        }
    }

    /**
     * Get facility configuration by code
     * 
     * @param code Facility code
     * @param authentication Current user authentication context
     * @return Facility configuration details
     */
    @Operation(
        summary = "Get facility configuration",
        description = "Retrieves facility configuration details by facility code"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Facility configuration retrieved successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                schema = @Schema(implementation = FacilityAdminService.FacilityView.class)
            )
        ),
        @ApiResponse(
            responseCode = "404",
            description = "Facility not found",
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
    @GetMapping("/{code}")
    @PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN')")
    public ResponseEntity<FacilityAdminService.FacilityView> get(
            @Parameter(description = "Facility code", required = true, example = "FACILITY_001")
            @PathVariable String code,
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            log.info("User {} (ID: {}) requesting facility configuration: {} from IP: {}", 
                    userContext.getUsername(), userContext.getUserId(), code, userContext.getIpAddress());
            
            // Check if user has access to this facility (for FACILITY_ADMIN)
            if (userContext.isFacilityAdmin() && !userContext.hasFacilityAccess(code)) {
                log.warn("User {} (ID: {}) attempted to access facility {} without permission", 
                        userContext.getUsername(), userContext.getUserId(), code);
                return ResponseEntity.status(403).build();
            }
            
            FacilityAdminService.FacilityView facility = svc.get(code);
            
            log.info("Successfully retrieved facility configuration: {} for user: {} (ID: {})", 
                    code, userContext.getUsername(), userContext.getUserId());
            
            return ResponseEntity.ok(facility);
            
        } catch (IllegalArgumentException e) {
            log.warn("Facility not found: {} requested by user: {}", code, userContextService.getCurrentUsername());
            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("Error retrieving facility: {} by user: {}", code, userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError().build();
        }
    }

    /**
     * Activate or deactivate a facility
     * 
     * @param code Facility code
     * @param active Activation status
     * @param authentication Current user authentication context
     * @return ResponseEntity indicating success or failure
     */
    @Operation(
        summary = "Activate or deactivate facility",
        description = "Activates or deactivates a facility configuration"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Facility activation status updated successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"message\": \"Facility activated successfully\", \"facilityCode\": \"FACILITY_001\", \"active\": true}"
                )
            )
        ),
        @ApiResponse(
            responseCode = "404",
            description = "Facility not found",
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
    @PatchMapping("/{code}/activate")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<Map<String, Object>> activate(
            @Parameter(description = "Facility code", required = true, example = "FACILITY_001")
            @PathVariable String code,
            @Parameter(description = "Activation status", required = true, example = "true")
            @RequestParam boolean active,
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            log.info("User {} (ID: {}) {} facility: {} from IP: {}", 
                    userContext.getUsername(), userContext.getUserId(), 
                    active ? "activating" : "deactivating", code, userContext.getIpAddress());
            
            svc.activate(code, active);
            
            log.info("Successfully {} facility: {} by user: {} (ID: {})", 
                    active ? "activated" : "deactivated", code, userContext.getUsername(), userContext.getUserId());
            
            Map<String, Object> response = Map.of(
                "message", "Facility " + (active ? "activated" : "deactivated") + " successfully",
                "facilityCode", code,
                "active", active,
                "updatedBy", userContext.getUsername(),
                "timestamp", java.time.LocalDateTime.now()
            );
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error {} facility: {} by user: {}", 
                    active ? "activating" : "deactivating", code, userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to " + (active ? "activate" : "deactivate") + " facility: " + e.getMessage()));
        }
    }

    /**
     * Rotate AME encryption keys for all facilities
     * 
     * @param authentication Current user authentication context
     * @return ResponseEntity with rotation results
     */
    @Operation(
        summary = "Rotate AME encryption keys",
        description = "Rotates App-Managed Encryption (AME) keys for all facility configurations"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "AME key rotation completed successfully",
            content = @Content(
                mediaType = MediaType.APPLICATION_JSON_VALUE,
                examples = @ExampleObject(
                    value = "{\"message\": \"AME key rotation completed\", \"updated\": 5, \"timestamp\": \"2025-01-27T10:30:00\"}"
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
            description = "Internal server error during key rotation",
            content = @Content(mediaType = MediaType.APPLICATION_JSON_VALUE)
        )
    })
    @PostMapping("/ame/rotate")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<Map<String, Object>> rotate(
            @Parameter(hidden = true) Authentication authentication) {
        
        try {
            UserContext userContext = userContextService.getCurrentUserContextWithRequest();
            log.info("User {} (ID: {}) initiating AME key rotation from IP: {}", 
                    userContext.getUsername(), userContext.getUserId(), userContext.getIpAddress());
            
            int updated = reencrypt.reencryptAllIfNeeded();
            
            log.info("AME key rotation completed by user: {} (ID: {}). Updated {} facilities", 
                    userContext.getUsername(), userContext.getUserId(), updated);
            
            Map<String, Object> response = Map.of(
                "message", "AME key rotation completed successfully",
                "updated", updated,
                "updatedBy", userContext.getUsername(),
                "timestamp", java.time.LocalDateTime.now()
            );
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error during AME key rotation by user: {}", 
                    userContextService.getCurrentUsername(), e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Failed to rotate AME keys: " + e.getMessage()));
        }
    }
}
