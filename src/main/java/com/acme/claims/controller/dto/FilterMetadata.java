package com.acme.claims.controller.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * Filter metadata for report responses.
 * 
 * This DTO provides information about the filters that were applied
 * to generate the report response, helping clients understand
 * what data was included/excluded.
 * 
 * Features:
 * - Applied filter values
 * - Available filter options
 * - Filter descriptions
 * - Date range information
 * 
 * Example JSON:
 * {
 *   "appliedFilters": {
 *     "facilityCodes": ["FAC001", "FAC002"],
 *     "fromDate": "2025-01-01T00:00:00",
 *     "toDate": "2025-12-31T23:59:59"
 *   },
 *   "availableOptions": {
 *     "facilities": ["FAC001", "FAC002", "FAC003"],
 *     "payers": ["DHA", "ADNOC"]
 *   },
 *   "dateRange": {
 *     "from": "2025-01-01T00:00:00",
 *     "to": "2025-12-31T23:59:59",
 *     "days": 365
 *   }
 * }
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
@Schema(description = "Filter metadata for report responses")
public class FilterMetadata {
    
    @Schema(description = "Filters that were actually applied to the report")
    private Map<String, Object> appliedFilters;
    
    @Schema(description = "Available filter options for the report type")
    private Map<String, List<String>> availableOptions;
    
    @Schema(description = "Date range information if date filters were applied")
    private DateRangeInfo dateRange;
    
    @Schema(description = "Sorting information")
    private SortingInfo sorting;
    
    @Schema(description = "Additional filter metadata")
    private Map<String, Object> metadata;
    
    /**
     * Date range information for date-based filters.
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "Date range information")
    public static class DateRangeInfo {
        
        @Schema(description = "Start date of the range", example = "2025-01-01T00:00:00")
        private LocalDateTime from;
        
        @Schema(description = "End date of the range", example = "2025-12-31T23:59:59")
        private LocalDateTime to;
        
        @Schema(description = "Number of days in the range", example = "365")
        private Long days;
        
        @Schema(description = "Number of months in the range", example = "12")
        private Long months;
        
        @Schema(description = "Number of years in the range", example = "1")
        private Long years;
    }
    
    /**
     * Sorting information for the report.
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "Sorting information")
    public static class SortingInfo {
        
        @Schema(description = "Column name used for sorting", example = "aging_days")
        private String sortBy;
        
        @Schema(description = "Sort direction", example = "DESC")
        private String sortDirection;
        
        @Schema(description = "Whether sorting was applied", example = "true")
        private Boolean applied;
    }
}

