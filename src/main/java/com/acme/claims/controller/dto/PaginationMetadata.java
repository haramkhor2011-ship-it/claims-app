package com.acme.claims.controller.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Pagination metadata for report responses.
 * 
 * This DTO provides pagination information to help clients navigate
 * through large result sets efficiently.
 * 
 * Features:
 * - Current page information
 * - Navigation hints (hasNext, hasPrevious)
 * - Total count information
 * - Page size details
 * 
 * Example JSON:
 * {
 *   "page": 0,
 *   "size": 50,
 *   "totalPages": 3,
 *   "totalElements": 150,
 *   "hasNext": true,
 *   "hasPrevious": false,
 *   "isFirst": true,
 *   "isLast": false
 * }
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
@Schema(description = "Pagination metadata for report responses")
public class PaginationMetadata {
    
    @Schema(description = "Current page number (0-based)", example = "0")
    private Integer page;
    
    @Schema(description = "Number of records per page", example = "50")
    private Integer size;
    
    @Schema(description = "Total number of pages", example = "3")
    private Integer totalPages;
    
    @Schema(description = "Total number of elements across all pages", example = "150")
    private Long totalElements;
    
    @Schema(description = "Whether there is a next page available", example = "true")
    private Boolean hasNext;
    
    @Schema(description = "Whether there is a previous page available", example = "false")
    private Boolean hasPrevious;
    
    @Schema(description = "Whether this is the first page", example = "true")
    private Boolean isFirst;
    
    @Schema(description = "Whether this is the last page", example = "false")
    private Boolean isLast;
    
    @Schema(description = "Number of elements in the current page", example = "50")
    private Integer numberOfElements;
    
    /**
     * Creates pagination metadata from basic pagination parameters.
     * 
     * @param page the current page number
     * @param size the page size
     * @param totalElements the total number of elements
     * @return pagination metadata
     */
    public static PaginationMetadata of(int page, int size, long totalElements) {
        int totalPages = (int) Math.ceil((double) totalElements / size);
        
        return PaginationMetadata.builder()
                .page(page)
                .size(size)
                .totalPages(totalPages)
                .totalElements(totalElements)
                .hasNext(page < totalPages - 1)
                .hasPrevious(page > 0)
                .isFirst(page == 0)
                .isLast(page == totalPages - 1)
                .numberOfElements((int) Math.min(size, totalElements - (page * size)))
                .build();
    }
}

