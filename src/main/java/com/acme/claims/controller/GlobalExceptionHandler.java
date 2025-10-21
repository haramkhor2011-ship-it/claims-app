package com.acme.claims.controller;

import com.acme.claims.controller.dto.ErrorResponse;
import com.acme.claims.exception.*;
import com.acme.claims.security.context.UserContext;
import com.acme.claims.security.service.UserContextService;
import io.swagger.v3.oas.annotations.Hidden;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import jakarta.servlet.http.HttpServletRequest;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Global exception handler for all REST controllers.
 * 
 * This class provides centralized exception handling across the entire application,
 * ensuring consistent error responses and proper HTTP status codes.
 * 
 * Features:
 * - Handles all custom report exceptions
 * - Processes Spring validation errors
 * - Manages Spring Security access denied scenarios
 * - Wraps database exceptions
 * - Provides correlation ID for request tracing
 * - Includes user context in error responses
 * - Structured logging for audit purposes
 * 
 * All error responses follow the standardized ErrorResponse format.
 */
@Slf4j
@RestControllerAdvice
@RequiredArgsConstructor
@Hidden // Hide from Swagger documentation
public class GlobalExceptionHandler {
    
    private final UserContextService userContextService;
    
    /**
     * Handles report access denied exceptions.
     * 
     * @param ex the ReportAccessDeniedException
     * @param request the HTTP request
     * @return standardized error response with 403 status
     */
    @ExceptionHandler(ReportAccessDeniedException.class)
    public ResponseEntity<ErrorResponse> handleReportAccessDenied(ReportAccessDeniedException ex, HttpServletRequest request) {
        log.warn("Report access denied: {} for user: {} (ID: {})", 
                ex.getMessage(), getCurrentUsername(), getCurrentUserId());
        
        ErrorResponse errorResponse = buildErrorResponse(
                HttpStatus.FORBIDDEN,
                "Access Denied",
                ex.getMessage(),
                request,
                getCurrentUserId()
        );
        
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(errorResponse);
    }
    
    /**
     * Handles invalid report parameters exceptions.
     * 
     * @param ex the InvalidReportParametersException
     * @param request the HTTP request
     * @return standardized error response with 400 status
     */
    @ExceptionHandler(InvalidReportParametersException.class)
    public ResponseEntity<ErrorResponse> handleInvalidReportParameters(InvalidReportParametersException ex, HttpServletRequest request) {
        log.warn("Invalid report parameters: {} for user: {} (ID: {})", 
                ex.getMessage(), getCurrentUsername(), getCurrentUserId());
        
        ErrorResponse errorResponse = buildErrorResponse(
                HttpStatus.BAD_REQUEST,
                "Invalid Parameters",
                ex.getMessage(),
                request,
                getCurrentUserId()
        );
        
        // Add parameter errors if available
        if (!ex.getParameterErrors().isEmpty()) {
            List<ErrorResponse.ValidationError> validationErrors = new ArrayList<>();
            for (String error : ex.getParameterErrors()) {
                validationErrors.add(ErrorResponse.ValidationError.builder()
                        .message(error)
                        .build());
            }
            errorResponse.setValidationErrors(validationErrors);
        }
        
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);
    }
    
    /**
     * Handles report data not found exceptions.
     * 
     * @param ex the ReportDataNotFoundException
     * @param request the HTTP request
     * @return standardized error response with 404 status
     */
    @ExceptionHandler(ReportDataNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleReportDataNotFound(ReportDataNotFoundException ex, HttpServletRequest request) {
        log.warn("Report data not found: {} for user: {} (ID: {})", 
                ex.getMessage(), getCurrentUsername(), getCurrentUserId());
        
        ErrorResponse errorResponse = buildErrorResponse(
                HttpStatus.NOT_FOUND,
                "Data Not Found",
                ex.getMessage(),
                request,
                getCurrentUserId()
        );
        
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(errorResponse);
    }
    
    /**
     * Handles facility access denied exceptions.
     * 
     * @param ex the FacilityAccessDeniedException
     * @param request the HTTP request
     * @return standardized error response with 403 status
     */
    @ExceptionHandler(FacilityAccessDeniedException.class)
    public ResponseEntity<ErrorResponse> handleFacilityAccessDenied(FacilityAccessDeniedException ex, HttpServletRequest request) {
        log.warn("Facility access denied: {} for user: {} (ID: {})", 
                ex.getMessage(), getCurrentUsername(), getCurrentUserId());
        
        ErrorResponse errorResponse = buildErrorResponse(
                HttpStatus.FORBIDDEN,
                "Facility Access Denied",
                ex.getMessage(),
                request,
                getCurrentUserId()
        );
        
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(errorResponse);
    }
    
    /**
     * Handles invalid date range exceptions.
     * 
     * @param ex the InvalidDateRangeException
     * @param request the HTTP request
     * @return standardized error response with 400 status
     */
    @ExceptionHandler(InvalidDateRangeException.class)
    public ResponseEntity<ErrorResponse> handleInvalidDateRange(InvalidDateRangeException ex, HttpServletRequest request) {
        log.warn("Invalid date range: {} for user: {} (ID: {})", 
                ex.getMessage(), getCurrentUsername(), getCurrentUserId());
        
        ErrorResponse errorResponse = buildErrorResponse(
                HttpStatus.BAD_REQUEST,
                "Invalid Date Range",
                ex.getMessage(),
                request,
                getCurrentUserId()
        );
        
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);
    }
    
    /**
     * Handles database query exceptions.
     * 
     * @param ex the DatabaseQueryException
     * @param request the HTTP request
     * @return standardized error response with 500 status
     */
    @ExceptionHandler(DatabaseQueryException.class)
    public ResponseEntity<ErrorResponse> handleDatabaseQueryException(DatabaseQueryException ex, HttpServletRequest request) {
        log.error("Database query failed: {} for user: {} (ID: {})", 
                ex.getMessage(), getCurrentUsername(), getCurrentUserId(), ex);
        
        ErrorResponse errorResponse = buildErrorResponse(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "Database Error",
                "An error occurred while retrieving data. Please try again later.",
                request,
                getCurrentUserId()
        );
        
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
    }
    
    /**
     * Handles Spring validation errors from @Valid annotations.
     * 
     * @param ex the MethodArgumentNotValidException
     * @param request the HTTP request
     * @return standardized error response with 400 status and validation details
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationErrors(MethodArgumentNotValidException ex, HttpServletRequest request) {
        log.warn("Validation errors: {} for user: {} (ID: {})", 
                ex.getMessage(), getCurrentUsername(), getCurrentUserId());
        
        List<ErrorResponse.ValidationError> validationErrors = new ArrayList<>();
        
        for (FieldError fieldError : ex.getBindingResult().getFieldErrors()) {
            validationErrors.add(ErrorResponse.ValidationError.builder()
                    .field(fieldError.getField())
                    .message(fieldError.getDefaultMessage())
                    .rejectedValue(fieldError.getRejectedValue())
                    .build());
        }
        
        ErrorResponse errorResponse = buildErrorResponse(
                HttpStatus.BAD_REQUEST,
                "Validation Failed",
                "Request validation failed. Please check the provided parameters.",
                request,
                getCurrentUserId()
        );
        errorResponse.setValidationErrors(validationErrors);
        
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);
    }
    
    /**
     * Handles Spring Security access denied exceptions.
     * 
     * @param ex the AccessDeniedException
     * @param request the HTTP request
     * @return standardized error response with 403 status
     */
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ErrorResponse> handleAccessDenied(AccessDeniedException ex, HttpServletRequest request) {
        log.warn("Access denied: {} for user: {} (ID: {})", 
                ex.getMessage(), getCurrentUsername(), getCurrentUserId());
        
        ErrorResponse errorResponse = buildErrorResponse(
                HttpStatus.FORBIDDEN,
                "Access Denied",
                "You do not have permission to access this resource.",
                request,
                getCurrentUserId()
        );
        
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(errorResponse);
    }
    
    /**
     * Handles SQL exceptions from database operations.
     * 
     * @param ex the SQLException
     * @param request the HTTP request
     * @return standardized error response with 500 status
     */
    @ExceptionHandler(SQLException.class)
    public ResponseEntity<ErrorResponse> handleSQLException(SQLException ex, HttpServletRequest request) {
        log.error("SQL exception occurred for user: {} (ID: {})", 
                getCurrentUsername(), getCurrentUserId(), ex);
        
        ErrorResponse errorResponse = buildErrorResponse(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "Database Error",
                "An error occurred while accessing the database. Please try again later.",
                request,
                getCurrentUserId()
        );
        
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
    }
    
    /**
     * Handles Spring Data access exceptions.
     * 
     * @param ex the DataAccessException
     * @param request the HTTP request
     * @return standardized error response with 500 status
     */
    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<ErrorResponse> handleDataAccessException(DataAccessException ex, HttpServletRequest request) {
        log.error("Data access exception occurred for user: {} (ID: {})", 
                getCurrentUsername(), getCurrentUserId(), ex);
        
        ErrorResponse errorResponse = buildErrorResponse(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "Database Error",
                "An error occurred while accessing data. Please try again later.",
                request,
                getCurrentUserId()
        );
        
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
    }
    
    /**
     * Handles all other report service exceptions.
     * 
     * @param ex the ReportServiceException
     * @param request the HTTP request
     * @return standardized error response with 500 status
     */
    @ExceptionHandler(ReportServiceException.class)
    public ResponseEntity<ErrorResponse> handleReportServiceException(ReportServiceException ex, HttpServletRequest request) {
        log.error("Report service exception: {} for user: {} (ID: {})", 
                ex.getMessage(), getCurrentUsername(), getCurrentUserId(), ex);
        
        ErrorResponse errorResponse = buildErrorResponse(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "Report Service Error",
                "An error occurred while processing the report request. Please try again later.",
                request,
                getCurrentUserId()
        );
        
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
    }
    
    /**
     * Handles all other unhandled exceptions.
     * 
     * @param ex the Exception
     * @param request the HTTP request
     * @return standardized error response with 500 status
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGenericException(Exception ex, HttpServletRequest request) {
        log.error("Unexpected error occurred for user: {} (ID: {})", 
                getCurrentUsername(), getCurrentUserId(), ex);
        
        ErrorResponse errorResponse = buildErrorResponse(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "Internal Server Error",
                "An unexpected error occurred. Please try again later.",
                request,
                getCurrentUserId()
        );
        
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
    }
    
    /**
     * Builds a standardized error response.
     * 
     * @param status the HTTP status
     * @param error the error type
     * @param message the error message
     * @param request the HTTP request
     * @param userId the user ID (can be null)
     * @return the ErrorResponse object
     */
    private ErrorResponse buildErrorResponse(HttpStatus status, String error, String message, 
                                           HttpServletRequest request, Long userId) {
        String correlationId = getCorrelationId();
        
        return ErrorResponse.builder()
                .timestamp(LocalDateTime.now())
                .status(status.value())
                .error(error)
                .message(message)
                .path(request.getRequestURI())
                .correlationId(correlationId)
                .userId(userId)
                .build();
    }
    
    /**
     * Gets the correlation ID from MDC or generates a new one.
     * 
     * @return the correlation ID
     */
    private String getCorrelationId() {
        String correlationId = MDC.get("correlationId");
        if (correlationId == null) {
            correlationId = UUID.randomUUID().toString();
            MDC.put("correlationId", correlationId);
        }
        return correlationId;
    }
    
    /**
     * Gets the current username safely.
     * 
     * @return the username or "unknown" if not available
     */
    private String getCurrentUsername() {
        try {
            UserContext userContext = userContextService.getCurrentUserContext();
            return userContext.getUsername();
        } catch (Exception e) {
            return "unknown";
        }
    }
    
    /**
     * Gets the current user ID safely.
     * 
     * @return the user ID or null if not available
     */
    private Long getCurrentUserId() {
        try {
            UserContext userContext = userContextService.getCurrentUserContext();
            return userContext.getUserId();
        } catch (Exception e) {
            return null;
        }
    }
}

