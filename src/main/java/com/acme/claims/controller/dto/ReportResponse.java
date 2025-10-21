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
 * Standardized response wrapper for all report endpoints.
 * 
 * This DTO provides a consistent structure for all report responses,
 * making it easier for clients to handle responses programmatically.
 * 
 * Features:
 * - Report metadata (type, display name, timestamp)
 * - User context information
 * - Report data with pagination
 * - Applied filters summary
 * - Performance metrics
 * - Correlation ID for tracing
 * 
 * Example JSON:
 * {
 *   "reportType": "BALANCE_AMOUNT_REPORT",
 *   "displayName": "Balance Amount to be Received",
 *   "data": [...],
 *   "pagination": {...},
 *   "filters": {...},
 *   "user": "john.doe",
 *   "userId": 123,
 *   "timestamp": "2025-10-20T10:30:45",
 *   "correlationId": "abc123-def456",
 *   "executionTimeMs": 234,
 *   "totalRecords": 150
 * }
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
@Schema(description = "Standardized response wrapper for report endpoints")
public class ReportResponse {
    
    @Schema(description = "Type of report that was executed", example = "BALANCE_AMOUNT_REPORT")
    private String reportType;
    
    @Schema(description = "Human-readable display name of the report", example = "Balance Amount to be Received")
    private String displayName;
    
    @Schema(description = "Tab name that was requested (for tabbed reports)", example = "summary")
    private String tab;
    
    @Schema(description = "Level that was requested (for level-based reports)", example = "activity")
    private String level;
    
    @Schema(description = "The actual report data as a list of records")
    private List<Map<String, Object>> data;
    
    @Schema(description = "Pagination metadata for the response")
    private PaginationMetadata pagination;
    
    @Schema(description = "Summary of filters that were applied to the report")
    private FilterMetadata filters;
    
    @Schema(description = "Report parameters and summary metrics")
    private Map<String, Object> parameters;
    
    @Schema(description = "Username of the user who requested the report", example = "john.doe")
    private String user;
    
    @Schema(description = "User ID of the user who requested the report", example = "123")
    private Long userId;
    
    @Schema(description = "Timestamp when the response was generated", example = "2025-10-20T10:30:45")
    private LocalDateTime timestamp;
    
    @Schema(description = "Correlation ID for request tracing", example = "abc123-def456-789ghi")
    private String correlationId;
    
    @Schema(description = "Execution time in milliseconds", example = "234")
    private Long executionTimeMs;
    
    @Schema(description = "Total number of records returned", example = "150")
    private Integer totalRecords;
    
    @Schema(description = "Additional metadata about the report execution")
    private Map<String, Object> metadata;
}

