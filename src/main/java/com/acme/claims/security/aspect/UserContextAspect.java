package com.acme.claims.security.aspect;

import com.acme.claims.security.context.UserContext;
import com.acme.claims.security.service.UserContextService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.stereotype.Component;

import java.util.Arrays;

/**
 * Aspect for automatic user context logging and debugging.
 * Provides comprehensive logging for security-related operations.
 */
@Slf4j
@Aspect
@Component
@RequiredArgsConstructor
public class UserContextAspect {
    
    private final UserContextService userContextService;
    
    /**
     * Log user context for all controller methods
     */
    @Around("execution(* com.acme.claims.controller.*.*(..)) || " +
            "execution(* com.acme.claims.security.controller.*.*(..)) || " +
            "execution(* com.acme.claims.admin.*.*(..))")
    public Object logUserContext(ProceedingJoinPoint joinPoint) throws Throwable {
        String className = joinPoint.getTarget().getClass().getSimpleName();
        String methodName = joinPoint.getSignature().getName();
        String operation = className + "." + methodName;
        
        try {
            // Log method entry with user context
            UserContext context = userContextService.getCurrentUserContextWithRequest();
            log.info("API call started - Operation: {}, User: {} (ID: {}), Roles: {}, Facilities: {}, IP: {}", 
                    operation, 
                    context.getUsername(), 
                    context.getUserId(),
                    context.getRoleNames(),
                    context.getFacilities(),
                    context.getIpAddress());
            
            // Log method parameters (excluding sensitive data)
            Object[] args = joinPoint.getArgs();
            if (args.length > 0) {
                log.debug("Method parameters for {}: {}", operation, 
                        Arrays.toString(Arrays.stream(args)
                                .map(arg -> arg != null ? arg.getClass().getSimpleName() : "null")
                                .toArray()));
            }
            
            // Execute the method
            Object result = joinPoint.proceed();
            
            // Log successful completion
            log.info("API call completed successfully - Operation: {}, User: {}", 
                    operation, context.getUsername());
            
            return result;
            
        } catch (Exception e) {
            // Log error with user context
            try {
                UserContext context = userContextService.getCurrentUserContext();
                log.error("API call failed - Operation: {}, User: {} (ID: {}), Error: {}", 
                        operation, context.getUsername(), context.getUserId(), e.getMessage(), e);
            } catch (Exception contextError) {
                log.error("API call failed - Operation: {}, Error: {} (Could not get user context: {})", 
                        operation, e.getMessage(), contextError.getMessage(), e);
            }
            throw e;
        }
    }
    
    /**
     * Log user context for service methods that perform data filtering
     */
    @Around("execution(* com.acme.claims.security.service.*Service.*(..)) && " +
            "!execution(* com.acme.claims.security.service.UserContextService.getCurrentUserContext(..)) && " +
            "!execution(* com.acme.claims.security.service.UserContextService.getCurrentUserContextWithRequest(..))")
    public Object logServiceOperations(ProceedingJoinPoint joinPoint) throws Throwable {
        String className = joinPoint.getTarget().getClass().getSimpleName();
        String methodName = joinPoint.getSignature().getName();
        String operation = className + "." + methodName;

        try {
            // Try to get user context, but handle unauthenticated scenarios gracefully
            UserContext context = null;
            try {
                context = userContextService.getCurrentUserContext();
            } catch (IllegalStateException e) {
                // No authenticated user - this is expected for startup services like DataInitializationService
                log.debug("Service operation started - Operation: {} (no authenticated user)", operation);
            }

            if (context != null) {
                log.debug("Service operation started - Operation: {}, User: {} (ID: {}), Roles: {}",
                        operation, context.getUsername(), context.getUserId(), context.getRoleNames());

                Object result = joinPoint.proceed();

                log.debug("Service operation completed - Operation: {}, User: {}",
                        operation, context.getUsername());

                return result;
            } else {
                // No authenticated user - proceed without logging user context
                Object result = joinPoint.proceed();
                log.debug("Service operation completed - Operation: {} (no authenticated user)", operation);
                return result;
            }

        } catch (Exception e) {
            // Log error with or without user context
            try {
                UserContext context = userContextService.getCurrentUserContext();
                log.error("Service operation failed - Operation: {}, User: {} (ID: {}), Error: {}",
                        operation, context.getUsername(), context.getUserId(), e.getMessage(), e);
            } catch (Exception contextError) {
                log.error("Service operation failed - Operation: {}, Error: {} (Could not get user context: {})",
                        operation, e.getMessage(), contextError.getMessage(), e);
            }
            throw e;
        }
    }
}
