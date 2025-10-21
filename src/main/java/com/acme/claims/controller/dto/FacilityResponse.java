package com.acme.claims.controller.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Response DTO for facility reference data endpoints.
 * 
 * This DTO provides a specialized response format for facility data
 * with proper formatting (facilityCode - name) as requested.
 * 
 * Features:
 * - Formatted display names: "FAC001 - Dubai Hospital"
 * - Location information (city, country)
 * - Status information (ACTIVE/INACTIVE)
 * - Pagination and search metadata
 * - Cache information for debugging
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
@Schema(description = "Response for facility reference data endpoints")
public class FacilityResponse {

    /**
     * List of facility items
     */
    @Schema(description = "List of facility items with formatted display names")
    private List<FacilityItem> facilities;

    /**
     * Pagination metadata
     */
    @Schema(description = "Pagination information for the response")
    private ReferenceDataResponse.PaginationMetadata pagination;

    /**
     * Search and filter metadata
     */
    @Schema(description = "Search and filter information applied to the query")
    private ReferenceDataResponse.FilterMetadata filters;

    /**
     * Response metadata
     */
    @Schema(description = "Response metadata including execution time and cache information")
    private ReferenceDataResponse.ResponseMetadata metadata;

    /**
     * Individual facility item with formatted display name.
     * 
     * Format: "facilityCode - name" (e.g., "FAC001 - Dubai Hospital")
     */
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "Individual facility item with formatted display name")
    public static class FacilityItem extends ReferenceDataResponse.ReferenceDataItem {

        /**
         * Unique identifier for the facility
         */
        @Schema(description = "Unique identifier for the facility", example = "1")
        private Long id;

        /**
         * Facility code (external FacilityID from DHA/eClaim)
         */
        @Schema(description = "Facility code (external FacilityID)", example = "FAC001")
        private String facilityCode;

        /**
         * Facility name
         */
        @Schema(description = "Facility name", example = "Dubai Hospital")
        private String name;

        /**
         * Formatted display name: "facilityCode - name"
         */
        @Schema(description = "Formatted display name combining facility code and name", 
                example = "FAC001 - Dubai Hospital")
        private String displayName;

        /**
         * City where the facility is located
         */
        @Schema(description = "City where the facility is located", example = "Dubai")
        private String city;

        /**
         * Country where the facility is located
         */
        @Schema(description = "Country where the facility is located", example = "UAE")
        private String country;

        /**
         * Status of the facility (ACTIVE/INACTIVE)
         */
        @Schema(description = "Status of the facility", example = "ACTIVE")
        private String status;

        /**
         * Timestamp when the facility was created
         */
        @Schema(description = "Timestamp when the facility was created")
        private LocalDateTime createdAt;

        /**
         * Timestamp when the facility was last updated
         */
        @Schema(description = "Timestamp when the facility was last updated")
        private LocalDateTime updatedAt;

        /**
         * Check if the facility is active
         * 
         * @return true if status is ACTIVE
         */
        public boolean isActive() {
            return "ACTIVE".equals(this.status);
        }

        /**
         * Get formatted display name for UI rendering
         * Format: "facilityCode - name"
         * 
         * @return formatted display string
         */
        public String getDisplayName() {
            if (name != null && !name.trim().isEmpty()) {
                return facilityCode + " - " + name;
            }
            return facilityCode;
        }
    }
}
