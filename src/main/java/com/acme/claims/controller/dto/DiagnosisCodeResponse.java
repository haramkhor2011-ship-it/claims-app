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
 * Response DTO for diagnosis code reference data endpoints.
 * 
 * This DTO provides a specialized response format for diagnosis code data
 * with proper formatting (code - description) as requested.
 * 
 * Features:
 * - Formatted display names: "Z00.00 - Encounter for general adult medical examination"
 * - Code system information (ICD-10, ICD-9, LOCAL)
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
@Schema(description = "Response for diagnosis code reference data endpoints")
public class DiagnosisCodeResponse {

    /**
     * List of diagnosis code items
     */
    @Schema(description = "List of diagnosis code items with formatted display names")
    private List<DiagnosisCodeItem> diagnosisCodes;

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
     * Individual diagnosis code item with formatted display name.
     * 
     * Format: "code - description" (e.g., "Z00.00 - Encounter for general adult medical examination")
     */
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "Individual diagnosis code item with formatted display name")
    public static class DiagnosisCodeItem extends ReferenceDataResponse.ReferenceDataItem {

        /**
         * Unique identifier for the diagnosis code
         */
        @Schema(description = "Unique identifier for the diagnosis code", example = "1")
        private Long id;

        /**
         * Diagnosis code (e.g., "Z00.00", "I10", "E11.9")
         */
        @Schema(description = "Diagnosis code", example = "Z00.00")
        private String code;

        /**
         * Code system (ICD-10, ICD-9, LOCAL)
         */
        @Schema(description = "Code system", example = "ICD-10")
        private String codeSystem;

        /**
         * Description of the diagnosis
         */
        @Schema(description = "Description of the diagnosis", 
                example = "Encounter for general adult medical examination")
        private String description;

        /**
         * Formatted display name: "code - description"
         */
        @Schema(description = "Formatted display name combining code and description", 
                example = "Z00.00 - Encounter for general adult medical examination")
        private String displayName;

        /**
         * Full code with system: "code (codeSystem)"
         */
        @Schema(description = "Full code with system", example = "Z00.00 (ICD-10)")
        private String fullCode;

        /**
         * Status of the diagnosis code (ACTIVE/INACTIVE)
         */
        @Schema(description = "Status of the diagnosis code", example = "ACTIVE")
        private String status;

        /**
         * Timestamp when the diagnosis code was created
         */
        @Schema(description = "Timestamp when the diagnosis code was created")
        private LocalDateTime createdAt;

        /**
         * Timestamp when the diagnosis code was last updated
         */
        @Schema(description = "Timestamp when the diagnosis code was last updated")
        private LocalDateTime updatedAt;

        /**
         * Check if the diagnosis code is active
         * 
         * @return true if status is ACTIVE
         */
        public boolean isActive() {
            return "ACTIVE".equals(this.status);
        }

        /**
         * Get formatted display name for UI rendering
         * Format: "code - description"
         * 
         * @return formatted display string
         */
        public String getDisplayName() {
            if (description != null && !description.trim().isEmpty()) {
                return code + " - " + description;
            }
            return code;
        }

        /**
         * Get full code with system for unique identification
         * Format: "code (codeSystem)"
         * 
         * @return formatted unique identifier
         */
        public String getFullCode() {
            return code + " (" + codeSystem + ")";
        }
    }
}
