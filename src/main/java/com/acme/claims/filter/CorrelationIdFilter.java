package com.acme.claims.filter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;

/**
 * Filter for managing correlation IDs across request lifecycle.
 * 
 * This filter ensures that every request has a unique correlation ID
 * for tracing purposes. The correlation ID is:
 * - Extracted from the X-Correlation-ID header if present
 * - Generated as a UUID if not present
 * - Stored in MDC for logging
 * - Added to the response header
 * - Cleared after request completion
 * 
 * The correlation ID enables:
 * - Request tracing across multiple services
 * - Log correlation for debugging
 * - Error tracking and analysis
 * - Performance monitoring
 */
@Slf4j
@Component
@Order(1) // Execute early in the filter chain
public class CorrelationIdFilter extends OncePerRequestFilter {
    
    private static final String CORRELATION_ID_HEADER = "X-Correlation-ID";
    private static final String CORRELATION_ID_MDC_KEY = "correlationId";
    
    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, 
                                  FilterChain filterChain) throws ServletException, IOException {
        
        try {
            // Extract or generate correlation ID
            String correlationId = extractOrGenerateCorrelationId(request);
            
            // Store in MDC for logging
            MDC.put(CORRELATION_ID_MDC_KEY, correlationId);
            
            // Add to response header
            response.setHeader(CORRELATION_ID_HEADER, correlationId);
            
            // Add to request attributes for controller access
            request.setAttribute(CORRELATION_ID_MDC_KEY, correlationId);
            
            // Log request start
            log.debug("Request started: {} {} - CorrelationId: {}", 
                     request.getMethod(), request.getRequestURI(), correlationId);
            
            // Continue with the filter chain
            filterChain.doFilter(request, response);
            
        } finally {
            // Clean up MDC after request completion
            MDC.remove(CORRELATION_ID_MDC_KEY);
            
            // Log request completion
            log.debug("Request completed: {} {} - CorrelationId: {}", 
                     request.getMethod(), request.getRequestURI(), 
                     request.getAttribute(CORRELATION_ID_MDC_KEY));
        }
    }
    
    /**
     * Extracts correlation ID from request header or generates a new one.
     * 
     * @param request the HTTP request
     * @return the correlation ID
     */
    private String extractOrGenerateCorrelationId(HttpServletRequest request) {
        String correlationId = request.getHeader(CORRELATION_ID_HEADER);
        
        if (correlationId == null || correlationId.trim().isEmpty()) {
            // Generate new correlation ID
            correlationId = UUID.randomUUID().toString();
            log.debug("Generated new correlation ID: {}", correlationId);
        } else {
            // Validate existing correlation ID
            if (!isValidCorrelationId(correlationId)) {
                log.warn("Invalid correlation ID format: {}, generating new one", correlationId);
                correlationId = UUID.randomUUID().toString();
            } else {
                log.debug("Using provided correlation ID: {}", correlationId);
            }
        }
        
        return correlationId;
    }
    
    /**
     * Validates the format of a correlation ID.
     * 
     * @param correlationId the correlation ID to validate
     * @return true if valid, false otherwise
     */
    private boolean isValidCorrelationId(String correlationId) {
        if (correlationId == null || correlationId.trim().isEmpty()) {
            return false;
        }
        
        // Check if it's a valid UUID format
        try {
            UUID.fromString(correlationId);
            return true;
        } catch (IllegalArgumentException e) {
            // Check if it's a custom format (alphanumeric, 8-64 characters)
            return correlationId.matches("^[a-zA-Z0-9_-]{8,64}$");
        }
    }
    
    /**
     * Gets the current correlation ID from MDC.
     * 
     * @return the current correlation ID or null if not set
     */
    public static String getCurrentCorrelationId() {
        return MDC.get(CORRELATION_ID_MDC_KEY);
    }
    
    /**
     * Sets a correlation ID in MDC.
     * 
     * @param correlationId the correlation ID to set
     */
    public static void setCorrelationId(String correlationId) {
        if (correlationId != null && !correlationId.trim().isEmpty()) {
            MDC.put(CORRELATION_ID_MDC_KEY, correlationId);
        }
    }
    
    /**
     * Clears the correlation ID from MDC.
     */
    public static void clearCorrelationId() {
        MDC.remove(CORRELATION_ID_MDC_KEY);
    }
}

