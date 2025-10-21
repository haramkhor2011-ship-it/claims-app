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
 * Request DTO for payer CRUD operations.
 * 
 * This DTO extends BaseReferenceDataRequest with payer-specific fields
 * for creating and updating payer records.
 * 
 * Features:
 * - Inherits base validation (code, name, status)
 * - Classification validation (GOVERNMENT, PRIVATE, etc.)
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
@Schema(description = "Request for payer CRUD operations")
public class PayerRequest extends BaseReferenceDataRequest {

    /**
     * Payer code (external PayerID from DHA/eClaim)
     */
    @Schema(description = "Payer code (external PayerID)", 
            example = "DHA", required = true)
    @NotBlank(message = "Payer code is required")
    @Size(min = 1, max = 50, message = "Payer code must be between 1 and 50 characters")
    @Pattern(regexp = "^[a-zA-Z0-9_-]+$", 
             message = "Payer code can only contain alphanumeric characters, underscores, and hyphens")
    private String payerCode;

    /**
     * Classification of the payer (GOVERNMENT, PRIVATE, SELF_PAY, etc.)
     */
    @Schema(description = "Classification of the payer", 
            example = "GOVERNMENT", maxLength = 50)
    @Size(max = 50, message = "Classification must not exceed 50 characters")
    @Pattern(regexp = "^[a-zA-Z0-9\\s._-]*$", 
             message = "Classification can only contain alphanumeric characters, spaces, dots, underscores, and hyphens")
    private String classification;
}
