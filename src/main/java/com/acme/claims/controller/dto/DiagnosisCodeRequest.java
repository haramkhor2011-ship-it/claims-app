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
 * Request DTO for diagnosis code CRUD operations.
 * 
 * This DTO provides fields for creating and updating diagnosis code records
 * with comprehensive validation.
 * 
 * Features:
 * - Code validation with proper patterns
 * - Code system validation (ICD-10, ICD-9, LOCAL)
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
@Schema(description = "Request for diagnosis code CRUD operations")
public class DiagnosisCodeRequest {

    /**
     * Diagnosis code (e.g., "Z00.00", "I10", "E11.9")
     */
    @Schema(description = "Diagnosis code", 
            example = "Z00.00", required = true)
    @NotBlank(message = "Code is required")
    @Size(min = 1, max = 20, message = "Code must be between 1 and 20 characters")
    @Pattern(regexp = "^[a-zA-Z0-9._-]+$", 
             message = "Code can only contain alphanumeric characters, dots, underscores, and hyphens")
    private String code;

    /**
     * Code system (ICD-10, ICD-9, LOCAL)
     */
    @Schema(description = "Code system", 
            example = "ICD-10", required = true)
    @NotBlank(message = "Code system is required")
    @Size(min = 1, max = 20, message = "Code system must be between 1 and 20 characters")
    @Pattern(regexp = "^[a-zA-Z0-9._-]+$", 
             message = "Code system can only contain alphanumeric characters, dots, underscores, and hyphens")
    @Builder.Default
    private String codeSystem = "ICD-10";

    /**
     * Description of the diagnosis
     */
    @Schema(description = "Description of the diagnosis", 
            example = "Encounter for general adult medical examination", required = true)
    @NotBlank(message = "Description is required")
    @Size(min = 1, max = 500, message = "Description must be between 1 and 500 characters")
    @Pattern(regexp = "^[a-zA-Z0-9\\s._-]+$", 
             message = "Description can only contain alphanumeric characters, spaces, dots, underscores, and hyphens")
    private String description;

    /**
     * Status of the diagnosis code
     */
    @Schema(description = "Status of the diagnosis code", 
            example = "ACTIVE", allowableValues = {"ACTIVE", "INACTIVE"})
    @Pattern(regexp = "^(ACTIVE|INACTIVE)$", 
             message = "Status must be ACTIVE or INACTIVE")
    @Builder.Default
    private String status = "ACTIVE";
}
