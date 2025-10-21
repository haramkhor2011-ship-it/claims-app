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
 * Response DTO for clinician reference data endpoints.
 * 
 * This DTO provides a specialized response format for clinician data
 * with proper formatting (clinicianCode - name) as requested.
 * 
 * Features:
 * - Formatted display names: "DOC001 - Dr. John Smith"
 * - Specialty information (CARDIOLOGY, DERMATOLOGY, etc.)
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
@Schema(description = "Response for clinician reference data endpoints")
public class ClinicianResponse {

    /**
     * List of clinician items
     */
    @Schema(description = "List of clinician items with formatted display names")
    private List<ClinicianItem> clinicians;

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
     * Individual clinician item with formatted display name.
     * 
     * Format: "clinicianCode - name" (e.g., "DOC001 - Dr. John Smith")
     */
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "Individual clinician item with formatted display name")
    public static class ClinicianItem extends ReferenceDataResponse.ReferenceDataItem {

        /**
         * Unique identifier for the clinician
         */
        @Schema(description = "Unique identifier for the clinician", example = "1")
        private Long id;

        /**
         * Clinician code (external ClinicianID from DHA/eClaim)
         */
        @Schema(description = "Clinician code (external ClinicianID)", example = "DOC001")
        private String clinicianCode;

        /**
         * Clinician name
         */
        @Schema(description = "Clinician name", example = "Dr. John Smith")
        private String name;

        /**
         * Formatted display name: "clinicianCode - name"
         */
        @Schema(description = "Formatted display name combining clinician code and name", 
                example = "DOC001 - Dr. John Smith")
        private String displayName;

        /**
         * Medical specialty of the clinician (CARDIOLOGY, DERMATOLOGY, GENERAL, etc.)
         */
        @Schema(description = "Medical specialty of the clinician", example = "CARDIOLOGY")
        private String specialty;

        /**
         * Status of the clinician (ACTIVE/INACTIVE)
         */
        @Schema(description = "Status of the clinician", example = "ACTIVE")
        private String status;

        /**
         * Timestamp when the clinician was created
         */
        @Schema(description = "Timestamp when the clinician was created")
        private LocalDateTime createdAt;

        /**
         * Timestamp when the clinician was last updated
         */
        @Schema(description = "Timestamp when the clinician was last updated")
        private LocalDateTime updatedAt;

        /**
         * Check if the clinician is active
         * 
         * @return true if status is ACTIVE
         */
        public boolean isActive() {
            return "ACTIVE".equals(this.status);
        }

        /**
         * Get formatted display name for UI rendering
         * Format: "clinicianCode - name"
         * 
         * @return formatted display string
         */
        public String getDisplayName() {
            if (name != null && !name.trim().isEmpty()) {
                return clinicianCode + " - " + name;
            }
            return clinicianCode;
        }
    }
}
