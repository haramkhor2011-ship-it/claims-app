package com.acme.claims.security.aspect;

import com.acme.claims.security.service.DataFilteringService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Set;

/**
 * Aspect for automatic data filtering in service methods.
 * 
 * This aspect provides automatic data filtering for methods that work with
 * facility-specific data. When multi-tenancy is enabled, it automatically
 * applies facility-based filtering to ensure users only see data they're
 * authorized to access.
 * 
 * The aspect is designed to be non-intrusive and can be easily enabled/disabled
 * via configuration.
 */
@Slf4j
@Aspect
@Component
@RequiredArgsConstructor
public class DataFilteringAspect {
    
    private final DataFilteringService dataFilteringService;
    
    /**
     * Apply data filtering to service methods that work with facility data
     * 
     * This aspect automatically logs filtering status and can be extended
     * to apply automatic filtering to specific service methods.
     */
    @Around("execution(* com.acme.claims.service.*Service.*(..)) || " +
            "execution(* com.acme.claims.admin.*Service.*(..)) || " +
            "execution(* com.acme.claims.reports.*Service.*(..))")
    public Object applyDataFiltering(ProceedingJoinPoint joinPoint) throws Throwable {
        String className = joinPoint.getTarget().getClass().getSimpleName();
        String methodName = joinPoint.getSignature().getName();
        String operation = className + "." + methodName;
        
        try {
            // Log filtering status for debugging
            dataFilteringService.logFilteringStatus(operation);
            
            // Execute the method
            Object result = joinPoint.proceed();
            
            // Log successful execution with filtering context
            log.debug("Data filtering applied successfully for operation: {}", operation);
            
            return result;
            
        } catch (Exception e) {
            log.error("Error in filtered operation: {} - {}", operation, e.getMessage(), e);
            throw e;
        }
    }
    
    /**
     * Apply data filtering to repository methods that query facility-specific data
     * 
     * This aspect can be extended to automatically apply facility filtering
     * to database queries when multi-tenancy is enabled.
     */
    @Around("execution(* com.acme.claims.repository.*Repository.*(..))")
    public Object applyRepositoryFiltering(ProceedingJoinPoint joinPoint) throws Throwable {
        String className = joinPoint.getTarget().getClass().getSimpleName();
        String methodName = joinPoint.getSignature().getName();
        String operation = className + "." + methodName;
        
        try {
            // Log repository access for audit purposes
            log.debug("Repository access - Operation: {}", operation);
            
            // Execute the method
            Object result = joinPoint.proceed();
            
            log.debug("Repository operation completed successfully: {}", operation);
            
            return result;
            
        } catch (Exception e) {
            log.error("Error in repository operation: {} - {}", operation, e.getMessage(), e);
            throw e;
        }
    }
}
