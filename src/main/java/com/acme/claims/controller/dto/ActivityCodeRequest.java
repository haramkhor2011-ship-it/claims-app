package com.acme.claims.controller.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Request DTO for activity code CRUD operations.
 * 
 * This DTO provides fields for creating and updating activity code records
 * with comprehensive validation.
 * 
 * Features:
 * - Code validation with proper patterns
 * - Type validation (CPT, HCPCS, LOCAL, etc.)
 * - Code system validation (CPT, HCPCS, LOCAL)
 * - Description validation
 * - Status validation
 * - Comprehensive validation annotations
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
@Schema(description = "Request for activity code CRUD operations")
public class ActivityCodeRequest {

    /**
     * Activity type/category (CPT, HCPCS, LOCAL, PROCEDURE, SERVICE)
     */
    @Schema(description = "Activity type/category", 
            example = "CPT", maxLength = 50)
    @Size(max = 50, message = "Type must not exceed 50 characters")
    @Pattern(regexp = "^[a-zA-Z0-9._-]*$", 
             message = "Type can only contain alphanumeric characters, dots, underscores, and hyphens")
    private String type;

    /**
     * Activity code (e.g., "99213", "99214", "A1234")
     */
    @Schema(description = "Activity code", 
            example = "99213", required = true)
    @NotBlank(message = "Code is required")
    @Size(min = 1, max = 20, message = "Code must be between 1 and 20 characters")
    @Pattern(regexp = "^[a-zA-Z0-9._-]+$", 
             message = "Code can only contain alphanumeric characters, dots, underscores, and hyphens")
    private String code;

    /**
     * Code system (CPT, HCPCS, LOCAL)
     */
    @Schema(description = "Code system", 
            example = "CPT", required = true)
    @NotBlank(message = "Code system is required")
    @Size(min = 1, max = 20, message = "Code system must be between 1 and 20 characters")
    @Pattern(regexp = "^[a-zA-Z0-9._-]+$", 
             message = "Code system can only contain alphanumeric characters, dots, underscores, and hyphens")
    @Builder.Default
    private String codeSystem = "LOCAL";

    /**
     * Description of the activity/service
     */
    @Schema(description = "Description of the activity/service", 
            example = "Office or other outpatient visit", required = true)
    @NotBlank(message = "Description is required")
    @Size(min = 1, max = 500, message = "Description must be between 1 and 500 characters")
    @Pattern(regexp = "^[a-zA-Z0-9\\s._-]+$", 
             message = "Description can only contain alphanumeric characters, spaces, dots, underscores, and hyphens")
    private String description;

    /**
     * Status of the activity code
     */
    @Schema(description = "Status of the activity code", 
            example = "ACTIVE", allowableValues = {"ACTIVE", "INACTIVE"})
    @Pattern(regexp = "^(ACTIVE|INACTIVE)$", 
             message = "Status must be ACTIVE or INACTIVE")
    @Builder.Default
    private String status = "ACTIVE";
}
