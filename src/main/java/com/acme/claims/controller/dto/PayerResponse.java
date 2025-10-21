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
 * Response DTO for payer reference data endpoints.
 * 
 * This DTO provides a specialized response format for payer data
 * with proper formatting (payerCode - name) as requested.
 * 
 * Features:
 * - Formatted display names: "DHA - Dubai Health Authority"
 * - Classification information (GOVERNMENT, PRIVATE, etc.)
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
@Schema(description = "Response for payer reference data endpoints")
public class PayerResponse {

    /**
     * List of payer items
     */
    @Schema(description = "List of payer items with formatted display names")
    private List<PayerItem> payers;

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
     * Individual payer item with formatted display name.
     * 
     * Format: "payerCode - name" (e.g., "DHA - Dubai Health Authority")
     */
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "Individual payer item with formatted display name")
    public static class PayerItem extends ReferenceDataResponse.ReferenceDataItem {

        /**
         * Unique identifier for the payer
         */
        @Schema(description = "Unique identifier for the payer", example = "1")
        private Long id;

        /**
         * Payer code (external PayerID from DHA/eClaim)
         */
        @Schema(description = "Payer code (external PayerID)", example = "DHA")
        private String payerCode;

        /**
         * Payer name
         */
        @Schema(description = "Payer name", example = "Dubai Health Authority")
        private String name;

        /**
         * Formatted display name: "payerCode - name"
         */
        @Schema(description = "Formatted display name combining payer code and name", 
                example = "DHA - Dubai Health Authority")
        private String displayName;

        /**
         * Classification of the payer (GOVERNMENT, PRIVATE, SELF_PAY, etc.)
         */
        @Schema(description = "Classification of the payer", example = "GOVERNMENT")
        private String classification;

        /**
         * Status of the payer (ACTIVE/INACTIVE)
         */
        @Schema(description = "Status of the payer", example = "ACTIVE")
        private String status;

        /**
         * Timestamp when the payer was created
         */
        @Schema(description = "Timestamp when the payer was created")
        private LocalDateTime createdAt;

        /**
         * Timestamp when the payer was last updated
         */
        @Schema(description = "Timestamp when the payer was last updated")
        private LocalDateTime updatedAt;

        /**
         * Check if the payer is active
         * 
         * @return true if status is ACTIVE
         */
        public boolean isActive() {
            return "ACTIVE".equals(this.status);
        }

        /**
         * Get formatted display name for UI rendering
         * Format: "payerCode - name"
         * 
         * @return formatted display string
         */
        public String getDisplayName() {
            if (name != null && !name.trim().isEmpty()) {
                return payerCode + " - " + name;
            }
            return payerCode;
        }
    }
}
