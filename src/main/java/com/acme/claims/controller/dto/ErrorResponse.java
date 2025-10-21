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
 * Standardized error response model for all API errors.
 * 
 * This DTO provides a consistent structure for error responses across the API,
 * making it easier for clients to handle errors programmatically.
 * 
 * Features:
 * - Timestamp for when the error occurred
 * - HTTP status code for quick identification
 * - Error type classification
 * - User-friendly message
 * - Request path for context
 * - Correlation ID for tracing
 * - Validation errors for field-level issues
 * - User ID for audit purposes
 * 
 * Example JSON:
 * {
 *   "timestamp": "2025-10-20T10:30:45",
 *   "status": 400,
 *   "error": "Bad Request",
 *   "message": "Invalid report parameters",
 *   "path": "/api/reports/data/query",
 *   "correlationId": "abc123-def456",
 *   "validationErrors": [
 *     {"field": "fromDate", "message": "From date cannot be in the future"}
 *   ],
 *   "userId": 123
 * }
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
@Schema(description = "Standardized error response for API errors")
public class ErrorResponse {
    
    @Schema(description = "Timestamp when the error occurred", example = "2025-10-20T10:30:45")
    private LocalDateTime timestamp;
    
    @Schema(description = "HTTP status code", example = "400")
    private int status;
    
    @Schema(description = "Error type classification", example = "Bad Request")
    private String error;
    
    @Schema(description = "User-friendly error message explaining what went wrong", 
            example = "Invalid report parameters: fromDate cannot be after toDate")
    private String message;
    
    @Schema(description = "The request path that generated this error", example = "/api/reports/data/query")
    private String path;
    
    @Schema(description = "Correlation ID for request tracing and log correlation", 
            example = "abc123-def456-789ghi")
    private String correlationId;
    
    @Schema(description = "List of field-level validation errors (only present for validation failures)")
    private List<ValidationError> validationErrors;
    
    @Schema(description = "User ID of the user who made the request (only included when user context is available)", 
            example = "123")
    private Long userId;
    
    /**
     * Represents a single field validation error.
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "Field-level validation error details")
    public static class ValidationError {
        
        @Schema(description = "Name of the field that failed validation", example = "fromDate")
        private String field;
        
        @Schema(description = "Validation error message for this field", 
                example = "From date cannot be in the future")
        private String message;
        
        @Schema(description = "The rejected value (optional)", example = "2026-01-01")
        private Object rejectedValue;
    }
}

