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
 * Response DTO for activity code reference data endpoints.
 * 
 * This DTO provides a specialized response format for activity code data
 * with proper formatting (code - description) as requested.
 * 
 * Features:
 * - Formatted display names: "99213 - Office or other outpatient visit"
 * - Type information (CPT, HCPCS, LOCAL, etc.)
 * - Code system information (CPT, HCPCS, LOCAL)
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
@Schema(description = "Response for activity code reference data endpoints")
public class ActivityCodeResponse {

    /**
     * List of activity code items
     */
    @Schema(description = "List of activity code items with formatted display names")
    private List<ActivityCodeItem> activityCodes;

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
     * Individual activity code item with formatted display name.
     * 
     * Format: "code - description" (e.g., "99213 - Office or other outpatient visit")
     */
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "Individual activity code item with formatted display name")
    public static class ActivityCodeItem extends ReferenceDataResponse.ReferenceDataItem {

        /**
         * Unique identifier for the activity code
         */
        @Schema(description = "Unique identifier for the activity code", example = "1")
        private Long id;

        /**
         * Activity type/category (CPT, HCPCS, LOCAL, PROCEDURE, SERVICE)
         */
        @Schema(description = "Activity type/category", example = "CPT")
        private String type;

        /**
         * Activity code (e.g., "99213", "99214", "A1234")
         */
        @Schema(description = "Activity code", example = "99213")
        private String code;

        /**
         * Code system (CPT, HCPCS, LOCAL)
         */
        @Schema(description = "Code system", example = "CPT")
        private String codeSystem;

        /**
         * Description of the activity/service
         */
        @Schema(description = "Description of the activity/service", 
                example = "Office or other outpatient visit")
        private String description;

        /**
         * Formatted display name: "code - description"
         */
        @Schema(description = "Formatted display name combining code and description", 
                example = "99213 - Office or other outpatient visit")
        private String displayName;

        /**
         * Full code with type: "code (type)"
         */
        @Schema(description = "Full code with type", example = "99213 (CPT)")
        private String fullCode;

        /**
         * Status of the activity code (ACTIVE/INACTIVE)
         */
        @Schema(description = "Status of the activity code", example = "ACTIVE")
        private String status;

        /**
         * Timestamp when the activity code was created
         */
        @Schema(description = "Timestamp when the activity code was created")
        private LocalDateTime createdAt;

        /**
         * Timestamp when the activity code was last updated
         */
        @Schema(description = "Timestamp when the activity code was last updated")
        private LocalDateTime updatedAt;

        /**
         * Check if the activity code is active
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
         * Get full code with type for unique identification
         * Format: "code (type)"
         * 
         * @return formatted unique identifier
         */
        public String getFullCode() {
            if (type != null && !type.trim().isEmpty()) {
                return code + " (" + type + ")";
            }
            return code;
        }
    }
}
