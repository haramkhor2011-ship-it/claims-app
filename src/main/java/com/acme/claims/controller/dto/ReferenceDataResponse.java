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
 * Response DTO for reference data lookup endpoints.
 * 
 * This DTO provides a standardized response format for all reference data
 * endpoints with proper formatting (code - name) as requested.
 * 
 * Features:
 * - Consistent response structure across all reference data endpoints
 * - Proper formatting: "code - name" for display purposes
 * - Pagination support for large datasets
 * - Search and filter metadata
 * - Cache information for debugging
 * - User context for audit purposes
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
@Schema(description = "Standardized response for reference data lookup endpoints")
public class ReferenceDataResponse {

    /**
     * List of reference data items
     */
    @Schema(description = "List of reference data items with formatted display names")
    private List<ReferenceDataItem> items;

    /**
     * Pagination metadata
     */
    @Schema(description = "Pagination information for the response")
    private PaginationMetadata pagination;

    /**
     * Search and filter metadata
     */
    @Schema(description = "Search and filter information applied to the query")
    private FilterMetadata filters;

    /**
     * Response metadata
     */
    @Schema(description = "Response metadata including execution time and cache information")
    private ResponseMetadata metadata;

    /**
     * Individual reference data item with formatted display name.
     * 
     * Format: "code - name" (e.g., "FAC001 - Dubai Hospital")
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "Individual reference data item with formatted display name")
    public static class ReferenceDataItem {

        /**
         * Unique identifier for the item
         */
        @Schema(description = "Unique identifier for the reference data item", example = "1")
        private Long id;

        /**
         * The code/identifier for the item
         */
        @Schema(description = "Code/identifier for the reference data item", example = "FAC001")
        private String code;

        /**
         * The name/description of the item
         */
        @Schema(description = "Name/description of the reference data item", example = "Dubai Hospital")
        private String name;

        /**
         * Formatted display name: "code - name"
         */
        @Schema(description = "Formatted display name combining code and name", example = "FAC001 - Dubai Hospital")
        private String displayName;

        /**
         * Additional attributes specific to the reference data type
         */
        @Schema(description = "Additional attributes specific to the reference data type")
        private Object attributes;

        /**
         * Status of the item (ACTIVE/INACTIVE)
         */
        @Schema(description = "Status of the reference data item", example = "ACTIVE")
        private String status;

        /**
         * Timestamp when the item was created
         */
        @Schema(description = "Timestamp when the item was created")
        private LocalDateTime createdAt;

        /**
         * Timestamp when the item was last updated
         */
        @Schema(description = "Timestamp when the item was last updated")
        private LocalDateTime updatedAt;
    }

    /**
     * Pagination metadata for the response.
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "Pagination metadata for the response")
    public static class PaginationMetadata {

        /**
         * Current page number (0-based)
         */
        @Schema(description = "Current page number (0-based)", example = "0")
        private int page;

        /**
         * Number of items per page
         */
        @Schema(description = "Number of items per page", example = "20")
        private int size;

        /**
         * Total number of items across all pages
         */
        @Schema(description = "Total number of items across all pages", example = "150")
        private long totalElements;

        /**
         * Total number of pages
         */
        @Schema(description = "Total number of pages", example = "8")
        private int totalPages;

        /**
         * Whether this is the first page
         */
        @Schema(description = "Whether this is the first page", example = "true")
        private boolean first;

        /**
         * Whether this is the last page
         */
        @Schema(description = "Whether this is the last page", example = "false")
        private boolean last;

        /**
         * Number of items in the current page
         */
        @Schema(description = "Number of items in the current page", example = "20")
        private int numberOfElements;
    }

    /**
     * Filter metadata for the response.
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "Filter metadata applied to the query")
    public static class FilterMetadata {

        /**
         * Search term used in the query
         */
        @Schema(description = "Search term used in the query", example = "hospital")
        private String searchTerm;

        /**
         * Status filter applied
         */
        @Schema(description = "Status filter applied", example = "ACTIVE")
        private String status;

        /**
         * Additional filters applied (type-specific)
         */
        @Schema(description = "Additional filters applied (type-specific)")
        private Object additionalFilters;

        /**
         * Sort criteria applied
         */
        @Schema(description = "Sort criteria applied", example = "code ASC")
        private String sortBy;
    }

    /**
     * Response metadata including execution time and cache information.
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "Response metadata including execution time and cache information")
    public static class ResponseMetadata {

        /**
         * Timestamp when the response was generated
         */
        @Schema(description = "Timestamp when the response was generated")
        private LocalDateTime timestamp;

        /**
         * Execution time in milliseconds
         */
        @Schema(description = "Execution time in milliseconds", example = "45")
        private long executionTimeMs;

        /**
         * Whether the data was served from cache
         */
        @Schema(description = "Whether the data was served from cache", example = "true")
        private boolean fromCache;

        /**
         * Cache key used (for debugging)
         */
        @Schema(description = "Cache key used (for debugging)", example = "facilities:active:page0:size20")
        private String cacheKey;

        /**
         * User who made the request
         */
        @Schema(description = "User who made the request", example = "john.doe")
        private String user;

        /**
         * User ID who made the request
         */
        @Schema(description = "User ID who made the request", example = "123")
        private Long userId;

        /**
         * Correlation ID for request tracing
         */
        @Schema(description = "Correlation ID for request tracing", example = "abc123-def456")
        private String correlationId;

        /**
         * Additional metadata
         */
        @Schema(description = "Additional metadata")
        private Object additionalMetadata;
    }
}
