package com.acme.claims.audit;

import com.acme.claims.security.ReportType;
import com.acme.claims.security.context.ServiceUserContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.Map;

/**
 * Service for structured audit logging of report access and data operations.
 * 
 * This service provides methods for logging various audit events related to
 * report access, data exports, and security events. All logs are structured
 * in JSON format for easy parsing and analysis.
 * 
 * Audit events include:
 * - Report access (successful and denied)
 * - Data export operations
 * - Security violations
 * - Performance metrics
 * 
 * All audit logs include user context, correlation IDs, and timing information
 * for comprehensive audit trails.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuditLogService {
    
    /**
     * Logs successful report access with performance metrics.
     * 
     * @param reportType the type of report accessed
     * @param filters the filters applied to the report
     * @param rowCount the number of rows returned
     * @param executionTimeMs the execution time in milliseconds
     * @param userContext the user context for audit information
     */
    public void logReportAccess(ReportType reportType, Map<String, Object> filters, 
                               int rowCount, long executionTimeMs, ServiceUserContext userContext) {
        
        AuditEvent event = AuditEvent.builder()
                .timestamp(LocalDateTime.now())
                .eventType("REPORT_ACCESS")
                .userId(userContext.getUserId())
                .username(userContext.getUsername())
                .reportType(reportType.name())
                .filters(filters)
                .rowCount(rowCount)
                .executionTimeMs(executionTimeMs)
                .correlationId(userContext.getCorrelationId())
                .ipAddress(userContext.getIpAddress())
                .requestPath(userContext.getRequestPath())
                .facilityRestrictions(userContext.getAccessibleFacilities())
                .success(true)
                .build();
        
        logAuditEvent(event);
        
        // Also log performance warning if execution time is high
        if (executionTimeMs > 5000) { // 5 seconds
            log.warn("Slow report execution: {}ms for report {} by user {} (ID: {})", 
                    executionTimeMs, reportType, userContext.getUsername(), userContext.getUserId());
        }
        
        // Log warning if result set is very large
        if (rowCount > 5000) {
            log.warn("Large result set: {} rows returned for report {} by user {} (ID: {})", 
                    rowCount, reportType, userContext.getUsername(), userContext.getUserId());
        }
    }
    
    /**
     * Logs denied report access attempts.
     * 
     * @param reportType the type of report that was denied
     * @param reason the reason for denial
     * @param userContext the user context for audit information
     */
    public void logReportAccessDenied(ReportType reportType, String reason, ServiceUserContext userContext) {
        
        AuditEvent event = AuditEvent.builder()
                .timestamp(LocalDateTime.now())
                .eventType("REPORT_ACCESS_DENIED")
                .userId(userContext.getUserId())
                .username(userContext.getUsername())
                .reportType(reportType.name())
                .reason(reason)
                .correlationId(userContext.getCorrelationId())
                .ipAddress(userContext.getIpAddress())
                .requestPath(userContext.getRequestPath())
                .facilityRestrictions(userContext.getAccessibleFacilities())
                .success(false)
                .build();
        
        logAuditEvent(event);
        
        // Log security warning for denied access
        log.warn("Report access denied: {} for report {} by user {} (ID: {}) - Reason: {}", 
                userContext.getUsername(), reportType, userContext.getUsername(), 
                userContext.getUserId(), reason);
    }
    
    /**
     * Logs data export operations.
     * 
     * @param reportType the type of report being exported
     * @param format the export format (e.g., "CSV", "Excel", "PDF")
     * @param rowCount the number of rows exported
     * @param userContext the user context for audit information
     */
    public void logDataExport(ReportType reportType, String format, int rowCount, ServiceUserContext userContext) {
        
        AuditEvent event = AuditEvent.builder()
                .timestamp(LocalDateTime.now())
                .eventType("DATA_EXPORT")
                .userId(userContext.getUserId())
                .username(userContext.getUsername())
                .reportType(reportType.name())
                .exportFormat(format)
                .rowCount(rowCount)
                .correlationId(userContext.getCorrelationId())
                .ipAddress(userContext.getIpAddress())
                .requestPath(userContext.getRequestPath())
                .facilityRestrictions(userContext.getAccessibleFacilities())
                .success(true)
                .build();
        
        logAuditEvent(event);
        
        // Log warning for large exports
        if (rowCount > 10000) {
            log.warn("Large data export: {} rows exported in {} format for report {} by user {} (ID: {})", 
                    rowCount, format, reportType, userContext.getUsername(), userContext.getUserId());
        }
    }
    
    /**
     * Logs facility access violations.
     * 
     * @param requestedFacilities the facilities that were requested
     * @param accessibleFacilities the facilities the user has access to
     * @param userContext the user context for audit information
     */
    public void logFacilityAccessViolation(java.util.List<String> requestedFacilities, 
                                         java.util.Set<String> accessibleFacilities, 
                                         ServiceUserContext userContext) {
        
        AuditEvent event = AuditEvent.builder()
                .timestamp(LocalDateTime.now())
                .eventType("FACILITY_ACCESS_VIOLATION")
                .userId(userContext.getUserId())
                .username(userContext.getUsername())
                .requestedFacilities(requestedFacilities)
                .accessibleFacilities(accessibleFacilities)
                .correlationId(userContext.getCorrelationId())
                .ipAddress(userContext.getIpAddress())
                .requestPath(userContext.getRequestPath())
                .success(false)
                .build();
        
        logAuditEvent(event);
        
        // Log security alert for facility violations
        log.error("SECURITY ALERT: Facility access violation by user {} (ID: {}) - " +
                 "Requested: {}, Accessible: {}", 
                 userContext.getUsername(), userContext.getUserId(), 
                 requestedFacilities, accessibleFacilities);
    }
    
    /**
     * Logs general security events.
     * 
     * @param eventType the type of security event
     * @param description the description of the event
     * @param userContext the user context for audit information
     */
    public void logSecurityEvent(String eventType, String description, ServiceUserContext userContext) {
        
        AuditEvent event = AuditEvent.builder()
                .timestamp(LocalDateTime.now())
                .eventType("SECURITY_EVENT")
                .securityEventType(eventType)
                .description(description)
                .userId(userContext.getUserId())
                .username(userContext.getUsername())
                .correlationId(userContext.getCorrelationId())
                .ipAddress(userContext.getIpAddress())
                .requestPath(userContext.getRequestPath())
                .success(false)
                .build();
        
        logAuditEvent(event);
        
        // Log security alert
        log.error("SECURITY EVENT: {} - {} by user {} (ID: {})", 
                 eventType, description, userContext.getUsername(), userContext.getUserId());
    }
    
    /**
     * Logs the audit event in structured JSON format.
     * 
     * @param event the audit event to log
     */
    private void logAuditEvent(AuditEvent event) {
        // Use a dedicated audit logger with JSON formatting
        log.info("AUDIT: {}", event.toJson());
    }
    
    /**
     * Audit event data structure for structured logging.
     */
    @lombok.Data
    @lombok.Builder
    private static class AuditEvent {
        private LocalDateTime timestamp;
        private String eventType;
        private Long userId;
        private String username;
        private String reportType;
        private Map<String, Object> filters;
        private Integer rowCount;
        private Long executionTimeMs;
        private String correlationId;
        private String ipAddress;
        private String requestPath;
        private java.util.Set<String> facilityRestrictions;
        private java.util.List<String> requestedFacilities;
        private java.util.Set<String> accessibleFacilities;
        private String reason;
        private String exportFormat;
        private String securityEventType;
        private String description;
        private Boolean success;
        
        /**
         * Converts the audit event to JSON format for logging.
         * 
         * @return JSON string representation of the audit event
         */
        public String toJson() {
            return String.format(
                "{\"timestamp\":\"%s\",\"eventType\":\"%s\",\"userId\":%d,\"username\":\"%s\"," +
                "\"reportType\":\"%s\",\"rowCount\":%d,\"executionTimeMs\":%d," +
                "\"correlationId\":\"%s\",\"ipAddress\":\"%s\",\"requestPath\":\"%s\"," +
                "\"success\":%s,\"facilityRestrictions\":%s}",
                timestamp,
                eventType,
                userId,
                username,
                reportType != null ? reportType : "",
                rowCount != null ? rowCount : 0,
                executionTimeMs != null ? executionTimeMs : 0,
                correlationId,
                ipAddress,
                requestPath,
                success,
                facilityRestrictions != null ? facilityRestrictions.toString() : "[]"
            );
        }
    }
}

