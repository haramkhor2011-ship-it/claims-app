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
 * Response DTO for denial code reference data endpoints.
 * 
 * This DTO provides a specialized response format for denial code data
 * with proper formatting (code - description) as requested.
 * 
 * Features:
 * - Formatted display names: "CO-45 - Claim/service denied"
 * - Payer-specific vs global scope information
 * - Pagination and search metadata
 * - Cache information for debugging
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
@Schema(description = "Response for denial code reference data endpoints")
public class DenialCodeResponse {

    /**
     * List of denial code items
     */
    @Schema(description = "List of denial code items with formatted display names")
    private List<DenialCodeItem> denialCodes;

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
     * Individual denial code item with formatted display name.
     * 
     * Format: "code - description" (e.g., "CO-45 - Claim/service denied")
     */
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "Individual denial code item with formatted display name")
    public static class DenialCodeItem extends ReferenceDataResponse.ReferenceDataItem {

        /**
         * Unique identifier for the denial code
         */
        @Schema(description = "Unique identifier for the denial code", example = "1")
        private Long id;

        /**
         * Denial code (e.g., "CO-45", "PR-1", "MA-130")
         */
        @Schema(description = "Denial code", example = "CO-45")
        private String code;

        /**
         * Description of the denial reason
         */
        @Schema(description = "Description of the denial reason", 
                example = "Claim/service denied")
        private String description;

        /**
         * Formatted display name: "code - description"
         */
        @Schema(description = "Formatted display name combining code and description", 
                example = "CO-45 - Claim/service denied")
        private String displayName;

        /**
         * Optional payer code for payer-specific denial codes
         * If null, the denial code applies to all payers
         */
        @Schema(description = "Optional payer code for payer-specific denial codes", 
                example = "DHA")
        private String payerCode;

        /**
         * Full code with payer scope: "code (payerCode)" or "code (GLOBAL)"
         */
        @Schema(description = "Full code with payer scope", example = "CO-45 (DHA)")
        private String fullCode;

        /**
         * Whether this denial code is payer-specific
         */
        @Schema(description = "Whether this denial code is payer-specific", example = "true")
        private boolean payerSpecific;

        /**
         * Whether this denial code applies to all payers
         */
        @Schema(description = "Whether this denial code applies to all payers", example = "false")
        private boolean global;

        /**
         * Timestamp when the denial code was created
         */
        @Schema(description = "Timestamp when the denial code was created")
        private LocalDateTime createdAt;

        /**
         * Timestamp when the denial code was last updated
         */
        @Schema(description = "Timestamp when the denial code was last updated")
        private LocalDateTime updatedAt;

        /**
         * Check if this denial code is payer-specific
         * 
         * @return true if payer_code is not null
         */
        public boolean isPayerSpecific() {
            return payerCode != null && !payerCode.trim().isEmpty();
        }

        /**
         * Check if this denial code applies to all payers
         * 
         * @return true if payer_code is null or empty
         */
        public boolean isGlobal() {
            return !isPayerSpecific();
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
         * Get full code with payer scope for identification
         * Format: "code (payerCode)" or "code (GLOBAL)"
         * 
         * @return formatted unique identifier with scope
         */
        public String getFullCode() {
            if (isPayerSpecific()) {
                return code + " (" + payerCode + ")";
            }
            return code + " (GLOBAL)";
        }
    }
}
