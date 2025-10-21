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
 * Base request DTO for CRUD operations on reference data.
 * 
 * This DTO provides common fields and validation for all reference data
 * CRUD operations (Create, Update).
 * 
 * Features:
 * - Code validation with proper patterns
 * - Name validation with length limits
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
@Schema(description = "Base request for reference data CRUD operations")
public class BaseReferenceDataRequest {

    /**
     * The code/identifier for the reference data item
     */
    @Schema(description = "Code/identifier for the reference data item", 
            example = "FAC001", required = true)
    @NotBlank(message = "Code is required")
    @Size(min = 1, max = 50, message = "Code must be between 1 and 50 characters")
    @Pattern(regexp = "^[a-zA-Z0-9_-]+$", 
             message = "Code can only contain alphanumeric characters, underscores, and hyphens")
    private String code;

    /**
     * The name/description of the reference data item
     */
    @Schema(description = "Name/description of the reference data item", 
            example = "Dubai Hospital", required = true)
    @NotBlank(message = "Name is required")
    @Size(min = 1, max = 255, message = "Name must be between 1 and 255 characters")
    @Pattern(regexp = "^[a-zA-Z0-9\\s._-]+$", 
             message = "Name can only contain alphanumeric characters, spaces, dots, underscores, and hyphens")
    private String name;

    /**
     * Status of the reference data item
     */
    @Schema(description = "Status of the reference data item", 
            example = "ACTIVE", allowableValues = {"ACTIVE", "INACTIVE"})
    @Pattern(regexp = "^(ACTIVE|INACTIVE)$", 
             message = "Status must be ACTIVE or INACTIVE")
    @Builder.Default
    private String status = "ACTIVE";
}
