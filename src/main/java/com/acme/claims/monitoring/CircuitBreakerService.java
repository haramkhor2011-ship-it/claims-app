package com.acme.claims.monitoring;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Circuit breaker service for protecting against cascading failures
 * Implements the circuit breaker pattern for external service calls
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CircuitBreakerService {
    
    private final ApplicationHealthMonitoringService healthMonitoringService;
    
    // Circuit breaker states
    public enum CircuitState {
        CLOSED,    // Normal operation
        OPEN,      // Circuit is open, calls are blocked
        HALF_OPEN  // Testing if service is back
    }
    
    // Configuration
    private static final int FAILURE_THRESHOLD = 5;
    private static final Duration TIMEOUT_DURATION = Duration.ofMinutes(1);
    private static final Duration HALF_OPEN_TIMEOUT = Duration.ofSeconds(30);
    
    // State tracking
    private final AtomicReference<CircuitState> state = new AtomicReference<>(CircuitState.CLOSED);
    private final AtomicInteger failureCount = new AtomicInteger(0);
    private final AtomicLong lastFailureTime = new AtomicLong(0);
    private final AtomicLong lastSuccessTime = new AtomicLong(0);
    private final AtomicInteger halfOpenAttempts = new AtomicInteger(0);
    
    /**
     * Execute a callable with circuit breaker protection
     */
    public <T> T execute(String serviceName, CircuitBreakerCallable<T> callable) throws Exception {
        if (!isCallAllowed(serviceName)) {
            throw new CircuitBreakerOpenException("Circuit breaker is OPEN for service: " + serviceName);
        }
        
        long startTime = System.currentTimeMillis();
        try {
            T result = callable.call();
            onSuccess(serviceName);
            return result;
        } catch (Exception e) {
            onFailure(serviceName, e);
            throw e;
        } finally {
            long duration = System.currentTimeMillis() - startTime;
            healthMonitoringService.addProcessingTime(duration);
        }
    }
    
    /**
     * Check if calls are allowed based on current circuit state
     */
    private boolean isCallAllowed(String serviceName) {
        CircuitState currentState = state.get();
        
        switch (currentState) {
            case CLOSED:
                return true;
                
            case OPEN:
                if (shouldAttemptReset()) {
                    state.set(CircuitState.HALF_OPEN);
                    halfOpenAttempts.set(0);
                    log.info("Circuit breaker transitioning to HALF_OPEN for service: {}", serviceName);
                    return true;
                }
                return false;
                
            case HALF_OPEN:
                if (halfOpenAttempts.get() >= 3) {
                    // Too many attempts in half-open, go back to open
                    state.set(CircuitState.OPEN);
                    lastFailureTime.set(System.currentTimeMillis());
                    log.warn("Circuit breaker transitioning back to OPEN for service: {} (too many half-open attempts)", serviceName);
                    return false;
                }
                return true;
                
            default:
                return false;
        }
    }
    
    /**
     * Handle successful call
     */
    private void onSuccess(String serviceName) {
        lastSuccessTime.set(System.currentTimeMillis());
        failureCount.set(0);
        
        if (state.get() == CircuitState.HALF_OPEN) {
            state.set(CircuitState.CLOSED);
            log.info("Circuit breaker transitioning to CLOSED for service: {} (successful call)", serviceName);
        }
        
        healthMonitoringService.incrementRequestCount();
    }
    
    /**
     * Handle failed call
     */
    private void onFailure(String serviceName, Exception e) {
        lastFailureTime.set(System.currentTimeMillis());
        int currentFailures = failureCount.incrementAndGet();
        
        log.warn("Circuit breaker failure for service: {} (failure count: {})", serviceName, currentFailures);
        
        if (currentFailures >= FAILURE_THRESHOLD && state.get() == CircuitState.CLOSED) {
            state.set(CircuitState.OPEN);
            log.error("Circuit breaker transitioning to OPEN for service: {} (failure threshold reached)", serviceName);
        }
        
        if (state.get() == CircuitState.HALF_OPEN) {
            halfOpenAttempts.incrementAndGet();
        }
        
        healthMonitoringService.incrementFailedRequestCount();
    }
    
    /**
     * Check if circuit breaker should attempt reset
     */
    private boolean shouldAttemptReset() {
        long timeSinceLastFailure = System.currentTimeMillis() - lastFailureTime.get();
        return timeSinceLastFailure >= TIMEOUT_DURATION.toMillis();
    }
    
    /**
     * Get current circuit breaker state
     */
    public CircuitBreakerState getState(String serviceName) {
        return new CircuitBreakerState(
            serviceName,
            state.get(),
            failureCount.get(),
            lastFailureTime.get(),
            lastSuccessTime.get(),
            halfOpenAttempts.get()
        );
    }
    
    /**
     * Reset circuit breaker to closed state
     */
    public void reset(String serviceName) {
        state.set(CircuitState.CLOSED);
        failureCount.set(0);
        halfOpenAttempts.set(0);
        log.info("Circuit breaker manually reset to CLOSED for service: {}", serviceName);
    }
    
    /**
     * Force circuit breaker to open state
     */
    public void forceOpen(String serviceName) {
        state.set(CircuitState.OPEN);
        lastFailureTime.set(System.currentTimeMillis());
        log.warn("Circuit breaker manually forced to OPEN for service: {}", serviceName);
    }
    
    /**
     * Functional interface for circuit breaker calls
     */
    @FunctionalInterface
    public interface CircuitBreakerCallable<T> {
        T call() throws Exception;
    }
    
    /**
     * Circuit breaker state information
     */
    public static class CircuitBreakerState {
        private final String serviceName;
        private final CircuitState state;
        private final int failureCount;
        private final long lastFailureTime;
        private final long lastSuccessTime;
        private final int halfOpenAttempts;
        
        public CircuitBreakerState(String serviceName, CircuitState state, int failureCount, 
                                 long lastFailureTime, long lastSuccessTime, int halfOpenAttempts) {
            this.serviceName = serviceName;
            this.state = state;
            this.failureCount = failureCount;
            this.lastFailureTime = lastFailureTime;
            this.lastSuccessTime = lastSuccessTime;
            this.halfOpenAttempts = halfOpenAttempts;
        }
        
        // Getters
        public String getServiceName() { return serviceName; }
        public CircuitState getState() { return state; }
        public int getFailureCount() { return failureCount; }
        public long getLastFailureTime() { return lastFailureTime; }
        public long getLastSuccessTime() { return lastSuccessTime; }
        public int getHalfOpenAttempts() { return halfOpenAttempts; }
        
        public boolean isOpen() { return state == CircuitState.OPEN; }
        public boolean isClosed() { return state == CircuitState.CLOSED; }
        public boolean isHalfOpen() { return state == CircuitState.HALF_OPEN; }
    }
    
    /**
     * Exception thrown when circuit breaker is open
     */
    public static class CircuitBreakerOpenException extends RuntimeException {
        public CircuitBreakerOpenException(String message) {
            super(message);
        }
    }
}

