package com.acme.claims.ratelimit;

import com.acme.claims.security.context.UserContext;
import com.acme.claims.security.service.UserContextService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import java.time.LocalDateTime;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Rate limiting interceptor for API endpoints.
 * 
 * This interceptor implements rate limiting to prevent abuse and ensure
 * fair resource usage. It tracks requests per user and per endpoint
 * using sliding window counters.
 * 
 * Rate Limits:
 * - 100 requests per minute per user
 * - 1000 requests per minute per endpoint
 * 
 * Features:
 * - Per-user rate limiting
 * - Per-endpoint rate limiting
 * - Sliding window implementation
 * - Automatic cleanup of expired entries
 * - Detailed logging of rate limit violations
 * 
 * When rate limits are exceeded, the interceptor returns HTTP 429
 * (Too Many Requests) with appropriate headers.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RateLimitInterceptor implements HandlerInterceptor {
    
    private final UserContextService userContextService;
    
    // Rate limit configurations
    private static final int USER_RATE_LIMIT = 100; // requests per minute
    private static final int ENDPOINT_RATE_LIMIT = 1000; // requests per minute
    private static final long WINDOW_SIZE_MS = 60 * 1000; // 1 minute
    
    // Rate limit tracking
    private final ConcurrentHashMap<String, RateLimitWindow> userRateLimits = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, RateLimitWindow> endpointRateLimits = new ConcurrentHashMap<>();
    
    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        
        // Skip rate limiting for non-API requests
        if (!request.getRequestURI().startsWith("/api/")) {
            return true;
        }
        
        try {
            // Get user context for rate limiting
            UserContext userContext = userContextService.getCurrentUserContext();
            String userId = String.valueOf(userContext.getUserId());
            String endpoint = request.getRequestURI();
            
            // Check user rate limit
            if (!checkRateLimit(userId, userRateLimits, USER_RATE_LIMIT, "user")) {
                logRateLimitViolation(userId, endpoint, "user", USER_RATE_LIMIT);
                sendRateLimitResponse(response, "User rate limit exceeded", USER_RATE_LIMIT);
                return false;
            }
            
            // Check endpoint rate limit
            if (!checkRateLimit(endpoint, endpointRateLimits, ENDPOINT_RATE_LIMIT, "endpoint")) {
                logRateLimitViolation(userId, endpoint, "endpoint", ENDPOINT_RATE_LIMIT);
                sendRateLimitResponse(response, "Endpoint rate limit exceeded", ENDPOINT_RATE_LIMIT);
                return false;
            }
            
            // Add rate limit headers to response
            addRateLimitHeaders(response, userId, endpoint);
            
            return true;
            
        } catch (Exception e) {
            // If we can't get user context, allow the request but log the issue
            log.warn("Could not apply rate limiting due to error: {}", e.getMessage());
            return true;
        }
    }
    
    /**
     * Checks if a rate limit has been exceeded for a given key.
     * 
     * @param key the key to check (user ID or endpoint)
     * @param rateLimits the rate limit map
     * @param limit the rate limit threshold
     * @param type the type of rate limit (for logging)
     * @return true if within limits, false if exceeded
     */
    private boolean checkRateLimit(String key, ConcurrentHashMap<String, RateLimitWindow> rateLimits, 
                                 int limit, String type) {
        
        long currentTime = System.currentTimeMillis();
        
        // Get or create rate limit window
        RateLimitWindow window = rateLimits.computeIfAbsent(key, k -> new RateLimitWindow());
        
        // Clean up old entries
        window.cleanup(currentTime);
        
        // Check if we're within the rate limit
        if (window.getRequestCount() >= limit) {
            return false;
        }
        
        // Increment request count
        window.incrementRequest(currentTime);
        
        return true;
    }
    
    /**
     * Logs rate limit violations with detailed information.
     * 
     * @param userId the user ID
     * @param endpoint the endpoint
     * @param limitType the type of limit violated
     * @param limit the limit threshold
     */
    private void logRateLimitViolation(String userId, String endpoint, String limitType, int limit) {
        log.warn("Rate limit exceeded - User: {}, Endpoint: {}, Type: {}, Limit: {}/min", 
                userId, endpoint, limitType, limit);
        
        // Log additional context for security monitoring
        log.error("SECURITY: Rate limit violation by user {} on endpoint {} - {} limit exceeded", 
                 userId, endpoint, limitType);
    }
    
    /**
     * Sends rate limit exceeded response with appropriate headers.
     * 
     * @param response the HTTP response
     * @param message the error message
     * @param limit the rate limit threshold
     */
    private void sendRateLimitResponse(HttpServletResponse response, String message, int limit) throws Exception {
        response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
        response.setHeader("X-RateLimit-Limit", String.valueOf(limit));
        response.setHeader("X-RateLimit-Remaining", "0");
        response.setHeader("X-RateLimit-Reset", String.valueOf(System.currentTimeMillis() + WINDOW_SIZE_MS));
        response.setContentType("application/json");
        
        String errorResponse = String.format(
            "{\"error\":\"Rate limit exceeded\",\"message\":\"%s\",\"limit\":%d,\"window\":\"1 minute\"}", 
            message, limit
        );
        
        response.getWriter().write(errorResponse);
    }
    
    /**
     * Adds rate limit headers to successful responses.
     * 
     * @param response the HTTP response
     * @param userId the user ID
     * @param endpoint the endpoint
     */
    private void addRateLimitHeaders(HttpServletResponse response, String userId, String endpoint) {
        // Add user rate limit headers
        RateLimitWindow userWindow = userRateLimits.get(userId);
        if (userWindow != null) {
            response.setHeader("X-RateLimit-Limit", String.valueOf(USER_RATE_LIMIT));
            response.setHeader("X-RateLimit-Remaining", String.valueOf(USER_RATE_LIMIT - userWindow.getRequestCount()));
        }
        
        // Add endpoint rate limit headers
        RateLimitWindow endpointWindow = endpointRateLimits.get(endpoint);
        if (endpointWindow != null) {
            response.setHeader("X-Endpoint-RateLimit-Limit", String.valueOf(ENDPOINT_RATE_LIMIT));
            response.setHeader("X-Endpoint-RateLimit-Remaining", String.valueOf(ENDPOINT_RATE_LIMIT - endpointWindow.getRequestCount()));
        }
    }
    
    /**
     * Rate limit window for tracking requests in a sliding window.
     */
    private static class RateLimitWindow {
        private final AtomicInteger requestCount = new AtomicInteger(0);
        private final AtomicLong windowStart = new AtomicLong(System.currentTimeMillis());
        
        /**
         * Increments the request count and resets window if needed.
         * 
         * @param currentTime the current timestamp
         */
        public void incrementRequest(long currentTime) {
            // Reset window if it's expired
            if (currentTime - windowStart.get() >= WINDOW_SIZE_MS) {
                resetWindow(currentTime);
            }
            
            requestCount.incrementAndGet();
        }
        
        /**
         * Gets the current request count.
         * 
         * @return the request count
         */
        public int getRequestCount() {
            return requestCount.get();
        }
        
        /**
         * Cleans up expired entries.
         * 
         * @param currentTime the current timestamp
         */
        public void cleanup(long currentTime) {
            if (currentTime - windowStart.get() >= WINDOW_SIZE_MS) {
                resetWindow(currentTime);
            }
        }
        
        /**
         * Resets the window to start at the given time.
         * 
         * @param currentTime the current timestamp
         */
        private void resetWindow(long currentTime) {
            windowStart.set(currentTime);
            requestCount.set(0);
        }
    }
}

