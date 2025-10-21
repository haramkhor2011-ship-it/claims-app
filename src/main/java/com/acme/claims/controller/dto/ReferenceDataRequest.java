package com.acme.claims.controller.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Request DTO for reference data lookup endpoints.
 * 
 * This DTO provides a standardized request format for all reference data
 * lookup endpoints with comprehensive validation and filtering options.
 * 
 * Features:
 * - Search term validation
 * - Pagination parameters with validation
 * - Status filtering
 * - Sort options
 * - Additional filters for type-specific searches
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
@Schema(description = "Request for reference data lookup endpoints")
public class ReferenceDataRequest {

    /**
     * Search term to look for in code and name fields
     */
    @Schema(description = "Search term to look for in code and name fields", 
            example = "hospital", maxLength = 100)
    @Pattern(regexp = "^[a-zA-Z0-9\\s._-]{0,100}$", 
             message = "Search term can only contain alphanumeric characters, spaces, dots, underscores, and hyphens")
    private String searchTerm;

    /**
     * Status filter (ACTIVE, INACTIVE, or null for all)
     */
    @Schema(description = "Status filter", example = "ACTIVE", 
            allowableValues = {"ACTIVE", "INACTIVE"})
    @Pattern(regexp = "^(ACTIVE|INACTIVE)?$", 
             message = "Status must be ACTIVE, INACTIVE, or empty")
    private String status;

    /**
     * Page number (0-based)
     */
    @Schema(description = "Page number (0-based)", example = "0", minimum = "0")
    @Min(value = 0, message = "Page number must be 0 or greater")
    @Max(value = 1000, message = "Page number cannot exceed 1000")
    @Builder.Default
    private Integer page = 0;

    /**
     * Number of items per page
     */
    @Schema(description = "Number of items per page", example = "20", minimum = "1", maximum = "100")
    @Min(value = 1, message = "Page size must be at least 1")
    @Max(value = 100, message = "Page size cannot exceed 100")
    @Builder.Default
    private Integer size = 20;

    /**
     * Sort field
     */
    @Schema(description = "Sort field", example = "code", 
            allowableValues = {"code", "name", "createdAt", "updatedAt"})
    @Pattern(regexp = "^(code|name|createdAt|updatedAt)?$", 
             message = "Sort field must be code, name, createdAt, updatedAt, or empty")
    private String sortBy;

    /**
     * Sort direction
     */
    @Schema(description = "Sort direction", example = "ASC", 
            allowableValues = {"ASC", "DESC"})
    @Pattern(regexp = "^(ASC|DESC)?$", 
             message = "Sort direction must be ASC, DESC, or empty")
    private String sortDirection;

    /**
     * Additional filters specific to the reference data type
     */
    @Schema(description = "Additional filters specific to the reference data type")
    private Object additionalFilters;

    /**
     * Get the sort direction with default value
     * 
     * @return sort direction, defaulting to ASC if not specified
     */
    public String getSortDirection() {
        return sortDirection != null ? sortDirection : "ASC";
    }

    /**
     * Get the sort field with default value
     * 
     * @return sort field, defaulting to "code" if not specified
     */
    public String getSortBy() {
        return sortBy != null ? sortBy : "code";
    }
}
