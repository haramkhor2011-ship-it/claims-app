package com.acme.claims.monitoring;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * REST controller for production monitoring endpoints
 * Provides comprehensive monitoring and management capabilities
 */
@RestController
@RequestMapping("/api/monitoring/production")
@RequiredArgsConstructor
@Slf4j
public class ProductionMonitoringController {
    
    private final DatabaseMonitoringService databaseMonitoringService;
    private final ApplicationHealthMonitoringService applicationHealthMonitoringService;
    private final CircuitBreakerService circuitBreakerService;
    private final BackupService backupService;
    private final SecretsManager secretsManager;
    
    /**
     * Get comprehensive system health status
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> getSystemHealth() {
        try {
            Map<String, Object> health = new HashMap<>();
            
            // Database health
            try {
                DatabaseHealthMetrics dbMetrics = databaseMonitoringService.collectDatabaseMetrics();
                Map<String, Object> dbHealth = new HashMap<>();
                dbHealth.put("status", "UP");
                dbHealth.put("activeConnections", dbMetrics.getActiveConnections());
                dbHealth.put("databaseSize", dbMetrics.getDatabaseSize());
                dbHealth.put("totalLocks", dbMetrics.getTotalLocks());
                health.put("database", dbHealth);
            } catch (Exception e) {
                Map<String, Object> dbHealth = new HashMap<>();
                dbHealth.put("status", "DOWN");
                dbHealth.put("error", e.getMessage());
                health.put("database", dbHealth);
            }
            
            // Application health
            try {
                ApplicationHealthMetrics appMetrics = applicationHealthMonitoringService.collectApplicationMetrics();
                Map<String, Object> appHealth = new HashMap<>();
                appHealth.put("status", "UP");
                appHealth.put("heapUsedMb", appMetrics.getHeapUsedMb());
                appHealth.put("heapMaxMb", appMetrics.getHeapMaxMb());
                appHealth.put("threadCount", appMetrics.getThreadCount());
                appHealth.put("errorRate", appMetrics.getErrorRate());
                appHealth.put("avgProcessingTimeMs", appMetrics.getAvgProcessingTimeMs());
                health.put("application", appHealth);
            } catch (Exception e) {
                Map<String, Object> appHealth = new HashMap<>();
                appHealth.put("status", "DOWN");
                appHealth.put("error", e.getMessage());
                health.put("application", appHealth);
            }
            
            // Circuit breaker status
            Map<String, Object> circuitBreakerHealth = new HashMap<>();
            circuitBreakerHealth.put("dhpo-soap", circuitBreakerService.getState("dhpo-soap"));
            health.put("circuitBreakers", circuitBreakerHealth);
            
            // Backup status
            BackupService.BackupStatistics backupStats = backupService.getStatistics();
            Map<String, Object> backupHealth = new HashMap<>();
            backupHealth.put("enabled", backupStats.isEnabled());
            backupHealth.put("totalBackups", backupStats.getTotalBackups());
            backupHealth.put("successfulBackups", backupStats.getSuccessfulBackups());
            backupHealth.put("successRate", backupStats.getSuccessRate());
            health.put("backup", backupHealth);
            
            // Secrets management status
            SecretsManager.SecretsManagerStatus secretsStatus = secretsManager.getStatus();
            Map<String, Object> secretsHealth = new HashMap<>();
            secretsHealth.put("enabled", secretsStatus.isEnabled());
            secretsHealth.put("encryptionEnabled", secretsStatus.isEncryptionEnabled());
            secretsHealth.put("vaultEnabled", secretsStatus.isVaultEnabled());
            secretsHealth.put("cachedSecretsCount", secretsStatus.getCachedSecretsCount());
            health.put("secrets", secretsHealth);
            
            return ResponseEntity.ok(health);
            
        } catch (Exception e) {
            log.error("Failed to get system health", e);
            Map<String, Object> error = new HashMap<>();
            error.put("status", "ERROR");
            error.put("message", e.getMessage());
            return ResponseEntity.status(500).body(error);
        }
    }
    
    /**
     * Get application metrics
     */
    @GetMapping("/application/metrics")
    public ResponseEntity<Map<String, Object>> getApplicationMetrics() {
        try {
            ApplicationHealthMetrics metrics = applicationHealthMonitoringService.collectApplicationMetrics();
            
            Map<String, Object> response = new HashMap<>();
            response.put("timestamp", metrics.getTimestamp());
            response.put("memory", Map.of(
                "heapUsedMb", metrics.getHeapUsedMb(),
                "heapMaxMb", metrics.getHeapMaxMb(),
                "heapCommittedMb", metrics.getHeapCommittedMb(),
                "nonHeapUsedMb", metrics.getNonHeapUsedMb(),
                "nonHeapMaxMb", metrics.getNonHeapMaxMb(),
                "nonHeapCommittedMb", metrics.getNonHeapCommittedMb()
            ));
            response.put("threads", Map.of(
                "count", metrics.getThreadCount(),
                "peak", metrics.getPeakThreadCount(),
                "daemon", metrics.getDaemonThreadCount()
            ));
            response.put("gc", Map.of(
                "totalTimeMs", metrics.getTotalGcTimeMs(),
                "totalCount", metrics.getTotalGcCount(),
                "frequencyPerMinute", metrics.getGcFrequencyPerMinute()
            ));
            response.put("application", Map.of(
                "totalRequests", metrics.getTotalRequests(),
                "failedRequests", metrics.getFailedRequests(),
                "errorRate", metrics.getErrorRate(),
                "avgProcessingTimeMs", metrics.getAvgProcessingTimeMs()
            ));
            response.put("database", Map.of(
                "healthy", metrics.isDatabaseHealthy(),
                "activeConnections", metrics.getActiveConnections(),
                "databaseSize", metrics.getDatabaseSize()
            ));
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Failed to get application metrics", e);
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * Get circuit breaker status
     */
    @GetMapping("/circuit-breakers")
    public ResponseEntity<Map<String, Object>> getCircuitBreakerStatus() {
        try {
            Map<String, Object> response = new HashMap<>();
            response.put("dhpo-soap", circuitBreakerService.getState("dhpo-soap"));
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Failed to get circuit breaker status", e);
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * Reset circuit breaker
     */
    @PostMapping("/circuit-breakers/{serviceName}/reset")
    public ResponseEntity<Map<String, String>> resetCircuitBreaker(@PathVariable String serviceName) {
        try {
            circuitBreakerService.reset(serviceName);
            
            Map<String, String> response = new HashMap<>();
            response.put("status", "SUCCESS");
            response.put("message", "Circuit breaker reset for service: " + serviceName);
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Failed to reset circuit breaker: {}", serviceName, e);
            Map<String, String> response = new HashMap<>();
            response.put("status", "ERROR");
            response.put("message", e.getMessage());
            return ResponseEntity.internalServerError().body(response);
        }
    }
    
    /**
     * Force circuit breaker open
     */
    @PostMapping("/circuit-breakers/{serviceName}/force-open")
    public ResponseEntity<Map<String, String>> forceCircuitBreakerOpen(@PathVariable String serviceName) {
        try {
            circuitBreakerService.forceOpen(serviceName);
            
            Map<String, String> response = new HashMap<>();
            response.put("status", "SUCCESS");
            response.put("message", "Circuit breaker forced open for service: " + serviceName);
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Failed to force circuit breaker open: {}", serviceName, e);
            Map<String, String> response = new HashMap<>();
            response.put("status", "ERROR");
            response.put("message", e.getMessage());
            return ResponseEntity.internalServerError().body(response);
        }
    }
    
    /**
     * Get backup statistics
     */
    @GetMapping("/backup/statistics")
    public ResponseEntity<Map<String, Object>> getBackupStatistics() {
        try {
            BackupService.BackupStatistics stats = backupService.getStatistics();
            
            Map<String, Object> response = new HashMap<>();
            response.put("enabled", stats.isEnabled());
            response.put("totalBackups", stats.getTotalBackups());
            response.put("successfulBackups", stats.getSuccessfulBackups());
            response.put("failedBackups", stats.getFailedBackups());
            response.put("successRate", stats.getSuccessRate());
            response.put("retentionDays", stats.getRetentionDays());
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Failed to get backup statistics", e);
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * Trigger manual backup
     */
    @PostMapping("/backup/trigger")
    public ResponseEntity<Map<String, Object>> triggerBackup() {
        try {
            BackupService.BackupResult result = backupService.performBackup();
            
            Map<String, Object> response = new HashMap<>();
            response.put("backupId", result.getBackupId());
            response.put("success", result.isSuccess());
            response.put("backupPath", result.getBackupPath());
            response.put("durationMs", result.getDurationMs());
            response.put("integrityVerified", result.isIntegrityVerified());
            
            if (!result.isSuccess()) {
                response.put("error", result.getErrorMessage());
            }
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Failed to trigger backup", e);
            Map<String, Object> response = new HashMap<>();
            response.put("success", false);
            response.put("error", e.getMessage());
            return ResponseEntity.internalServerError().body(response);
        }
    }
    
    /**
     * Get secrets management status
     */
    @GetMapping("/secrets/status")
    public ResponseEntity<Map<String, Object>> getSecretsStatus() {
        try {
            SecretsManager.SecretsManagerStatus status = secretsManager.getStatus();
            
            Map<String, Object> response = new HashMap<>();
            response.put("enabled", status.isEnabled());
            response.put("encryptionEnabled", status.isEncryptionEnabled());
            response.put("vaultEnabled", status.isVaultEnabled());
            response.put("encryptionKeyLoaded", status.isEncryptionKeyLoaded());
            response.put("cachedSecretsCount", status.getCachedSecretsCount());
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Failed to get secrets status", e);
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * List available secrets (without values)
     */
    @GetMapping("/secrets/list")
    public ResponseEntity<Map<String, String>> listSecrets() {
        try {
            Map<String, String> secrets = secretsManager.listSecrets();
            
            // Mask sensitive values
            Map<String, String> maskedSecrets = new HashMap<>();
            secrets.forEach((key, value) -> {
                if (value != null && !value.equals("***")) {
                    maskedSecrets.put(key, "***");
                } else {
                    maskedSecrets.put(key, value);
                }
            });
            
            return ResponseEntity.ok(maskedSecrets);
            
        } catch (Exception e) {
            log.error("Failed to list secrets", e);
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * Get monitoring statistics summary
     */
    @GetMapping("/summary")
    public ResponseEntity<Map<String, Object>> getMonitoringSummary() {
        try {
            Map<String, Object> summary = new HashMap<>();
            
            // Database monitoring stats
            summary.put("database", databaseMonitoringService.getCurrentStats());
            
            // Application monitoring stats
            summary.put("application", applicationHealthMonitoringService.getCurrentStats());
            
            // Backup stats
            summary.put("backup", backupService.getStatistics());
            
            // Secrets stats
            summary.put("secrets", secretsManager.getStatus());
            
            return ResponseEntity.ok(summary);
            
        } catch (Exception e) {
            log.error("Failed to get monitoring summary", e);
            return ResponseEntity.internalServerError().build();
        }
    }
}

