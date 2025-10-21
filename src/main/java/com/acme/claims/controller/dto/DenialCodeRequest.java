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
 * Request DTO for denial code CRUD operations.
 * 
 * This DTO provides fields for creating and updating denial code records
 * with comprehensive validation.
 * 
 * Features:
 * - Code validation with proper patterns
 * - Description validation
 * - Optional payer code validation
 * - Comprehensive validation annotations
 * 
 * Note: Denial codes typically don't have soft delete functionality
 * as they are reference data that should remain available for historical claims.
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
@Schema(description = "Request for denial code CRUD operations")
public class DenialCodeRequest {

    /**
     * Denial code (e.g., "CO-45", "PR-1", "MA-130")
     */
    @Schema(description = "Denial code", 
            example = "CO-45", required = true)
    @NotBlank(message = "Code is required")
    @Size(min = 1, max = 20, message = "Code must be between 1 and 20 characters")
    @Pattern(regexp = "^[a-zA-Z0-9._-]+$", 
             message = "Code can only contain alphanumeric characters, dots, underscores, and hyphens")
    private String code;

    /**
     * Description of the denial reason
     */
    @Schema(description = "Description of the denial reason", 
            example = "Claim/service denied", required = true)
    @NotBlank(message = "Description is required")
    @Size(min = 1, max = 500, message = "Description must be between 1 and 500 characters")
    @Pattern(regexp = "^[a-zA-Z0-9\\s._-]+$", 
             message = "Description can only contain alphanumeric characters, spaces, dots, underscores, and hyphens")
    private String description;

    /**
     * Optional payer code for payer-specific denial codes
     * If null or empty, the denial code applies to all payers
     */
    @Schema(description = "Optional payer code for payer-specific denial codes", 
            example = "DHA", maxLength = 50)
    @Size(max = 50, message = "Payer code must not exceed 50 characters")
    @Pattern(regexp = "^[a-zA-Z0-9._-]*$", 
             message = "Payer code can only contain alphanumeric characters, dots, underscores, and hyphens")
    private String payerCode;
}
