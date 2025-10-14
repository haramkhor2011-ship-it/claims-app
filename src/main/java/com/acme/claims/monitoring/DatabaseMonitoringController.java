package com.acme.claims.monitoring;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

/**
 * REST controller for database monitoring endpoints
 * Provides access to monitoring statistics and manual health checks
 */
@RestController
@RequestMapping("/api/monitoring/database")
@RequiredArgsConstructor
@Slf4j
public class DatabaseMonitoringController {
    
    private final DatabaseMonitoringService monitoringService;
    
    /**
     * Get current monitoring statistics
     */
    @GetMapping("/stats")
    public ResponseEntity<Map<String, Object>> getMonitoringStats() {
        try {
            Map<String, Object> stats = monitoringService.getCurrentStats();
            return ResponseEntity.ok(stats);
        } catch (Exception e) {
            log.error("Failed to get monitoring stats", e);
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * Trigger manual database health check
     */
    @PostMapping("/health-check")
    public ResponseEntity<Map<String, Object>> performHealthCheck() {
        try {
            DatabaseHealthMetrics metrics = monitoringService.collectDatabaseMetrics();
            
            // Convert metrics to a simple map for JSON response
            Map<String, Object> response = new HashMap<>();
            response.put("timestamp", metrics.getTimestamp());
            response.put("database", metrics.getDatabaseProductName());
            response.put("version", metrics.getDatabaseProductVersion());
            response.put("databaseSize", metrics.getDatabaseSize());
            response.put("schemaSize", metrics.getSchemaSize());
            response.put("activeConnections", metrics.getActiveConnections());
            response.put("activeQueries", metrics.getActiveQueries());
            response.put("totalLocks", metrics.getTotalLocks());
            response.put("totalQueryCalls", metrics.getTotalQueryCalls() != null ? metrics.getTotalQueryCalls() : 0);
            response.put("avgQueryTimeMs", metrics.getAvgQueryTimeMs() != null ? metrics.getAvgQueryTimeMs() : 0.0);
            response.put("slowQueries", metrics.getSlowQueries() != null ? metrics.getSlowQueries() : 0);
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Failed to perform health check", e);
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * Get database health status (simple health indicator)
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> getHealthStatus() {
        try {
            // Perform a quick health check
            DatabaseHealthMetrics metrics = monitoringService.collectDatabaseMetrics();
            
            String status = "UP";
            String message = "Database is healthy";
            
            // Check for potential issues
            if (metrics.getActiveConnections() > 100) {
                status = "WARNING";
                message = "High number of active connections: " + metrics.getActiveConnections();
            }
            
            if (metrics.getTotalLocks() > 50) {
                status = "WARNING";
                message = "High number of database locks: " + metrics.getTotalLocks();
            }
            
            if (metrics.getAvgQueryTimeMs() != null && metrics.getAvgQueryTimeMs() > 1000) {
                status = "WARNING";
                message = "Slow average query time: " + String.format("%.2f", metrics.getAvgQueryTimeMs()) + "ms";
            }
            
            Map<String, String> health = new HashMap<>();
            health.put("status", status);
            health.put("message", message);
            health.put("timestamp", metrics.getTimestamp().toString());
            
            return ResponseEntity.ok(health);
        } catch (Exception e) {
            log.error("Failed to get health status", e);
            Map<String, String> health = new HashMap<>();
            health.put("status", "DOWN");
            health.put("message", "Database health check failed: " + e.getMessage());
            health.put("timestamp", java.time.LocalDateTime.now().toString());
            return ResponseEntity.status(503).body(health);
        }
    }
}
