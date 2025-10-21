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
 * Request DTO for facility CRUD operations.
 * 
 * This DTO extends BaseReferenceDataRequest with facility-specific fields
 * for creating and updating facility records.
 * 
 * Features:
 * - Inherits base validation (code, name, status)
 * - Location validation (city, country)
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
@Schema(description = "Request for facility CRUD operations")
public class FacilityRequest extends BaseReferenceDataRequest {

    /**
     * Facility code (external FacilityID from DHA/eClaim)
     */
    @Schema(description = "Facility code (external FacilityID)", 
            example = "FAC001", required = true)
    @NotBlank(message = "Facility code is required")
    @Size(min = 1, max = 50, message = "Facility code must be between 1 and 50 characters")
    @Pattern(regexp = "^[a-zA-Z0-9_-]+$", 
             message = "Facility code can only contain alphanumeric characters, underscores, and hyphens")
    private String facilityCode;

    /**
     * City where the facility is located
     */
    @Schema(description = "City where the facility is located", 
            example = "Dubai", maxLength = 100)
    @Size(max = 100, message = "City must not exceed 100 characters")
    @Pattern(regexp = "^[a-zA-Z0-9\\s._-]*$", 
             message = "City can only contain alphanumeric characters, spaces, dots, underscores, and hyphens")
    private String city;

    /**
     * Country where the facility is located
     */
    @Schema(description = "Country where the facility is located", 
            example = "UAE", maxLength = 100)
    @Size(max = 100, message = "Country must not exceed 100 characters")
    @Pattern(regexp = "^[a-zA-Z0-9\\s._-]*$", 
             message = "Country can only contain alphanumeric characters, spaces, dots, underscores, and hyphens")
    private String country;
}
