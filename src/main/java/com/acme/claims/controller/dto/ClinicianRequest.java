package com.acme.claims.controller.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

/**
 * Request DTO for clinician CRUD operations.
 * 
 * This DTO extends BaseReferenceDataRequest with clinician-specific fields
 * for creating and updating clinician records.
 * 
 * Features:
 * - Inherits base validation (code, name, status)
 * - Specialty validation (CARDIOLOGY, DERMATOLOGY, etc.)
 * - Comprehensive validation annotations
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
@JsonInclude(JsonInclude.Include.NON_NULL)
@Schema(description = "Request for clinician CRUD operations")
public class ClinicianRequest extends BaseReferenceDataRequest {

    /**
     * Clinician code (external ClinicianID from DHA/eClaim)
     */
    @Schema(description = "Clinician code (external ClinicianID)", 
            example = "DOC001", required = true)
    @NotBlank(message = "Clinician code is required")
    @Size(min = 1, max = 50, message = "Clinician code must be between 1 and 50 characters")
    @Pattern(regexp = "^[a-zA-Z0-9_-]+$", 
             message = "Clinician code can only contain alphanumeric characters, underscores, and hyphens")
    private String clinicianCode;

    /**
     * Medical specialty of the clinician (CARDIOLOGY, DERMATOLOGY, GENERAL, etc.)
     */
    @Schema(description = "Medical specialty of the clinician", 
            example = "CARDIOLOGY", maxLength = 100)
    @Size(max = 100, message = "Specialty must not exceed 100 characters")
    @Pattern(regexp = "^[a-zA-Z0-9\\s._-]*$", 
             message = "Specialty can only contain alphanumeric characters, spaces, dots, underscores, and hyphens")
    private String specialty;
}
