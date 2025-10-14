package com.acme.claims.monitoring;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * Initializer to start database monitoring when the application is ready
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class DatabaseMonitoringInitializer {
    
    private final DatabaseMonitoringService monitoringService;
    
    @Value("${claims.monitoring.database.enabled:true}")
    private boolean monitoringEnabled;
    
    @EventListener(ApplicationReadyEvent.class)
    public void initializeMonitoring() {
        if (monitoringEnabled) {
            log.info("Starting database monitoring service...");
            try {
                // Perform initial health check to verify monitoring is working
                monitoringService.collectDatabaseMetrics();
                log.info("Database monitoring service started successfully");
            } catch (Exception e) {
                log.error("Failed to initialize database monitoring service", e);
            }
        } else {
            log.info("Database monitoring is disabled");
        }
    }
}
