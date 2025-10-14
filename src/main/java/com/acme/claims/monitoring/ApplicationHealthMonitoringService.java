package com.acme.claims.monitoring;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.Marker;
import org.slf4j.MarkerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.lang.management.ManagementFactory;
import java.lang.management.MemoryMXBean;
import java.lang.management.MemoryUsage;
import java.lang.management.ThreadMXBean;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Application-level health monitoring service that tracks JVM metrics,
 * memory usage, thread performance, and application-specific metrics.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ApplicationHealthMonitoringService {
    
    private final DatabaseMonitoringService databaseMonitoringService;
    
    @Value("${claims.monitoring.application.enabled:true}")
    private boolean monitoringEnabled;
    
    @Value("${claims.monitoring.application.interval:PT5M}")
    private String monitoringInterval;
    
    private final AtomicLong totalRequests = new AtomicLong(0);
    private final AtomicLong failedRequests = new AtomicLong(0);
    private final AtomicLong processingTimeMs = new AtomicLong(0);
    
    private static final DateTimeFormatter LOG_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS");
    private static final Marker APP_MONITORING_MARKER = MarkerFactory.getMarker("APP_MONITORING");
    
    /**
     * Scheduled application health check - runs every 5 minutes by default
     */
    @Scheduled(fixedRateString = "#{T(java.time.Duration).parse('${claims.monitoring.application.interval:PT5M}').toMillis()}")
    public void performApplicationHealthCheck() {
        if (!monitoringEnabled) {
            return;
        }
        
        try {
            ApplicationHealthMetrics metrics = collectApplicationMetrics();
            logApplicationHealthMetrics(metrics);
            checkForAlerts(metrics);
        } catch (Exception e) {
            log.error("Failed to perform application health check", e);
        }
    }
    
    /**
     * Collect comprehensive application metrics
     */
    public ApplicationHealthMetrics collectApplicationMetrics() {
        ApplicationHealthMetrics metrics = new ApplicationHealthMetrics();
        metrics.setTimestamp(LocalDateTime.now());
        
        // JVM Memory Metrics
        MemoryMXBean memoryBean = ManagementFactory.getMemoryMXBean();
        MemoryUsage heapMemory = memoryBean.getHeapMemoryUsage();
        MemoryUsage nonHeapMemory = memoryBean.getNonHeapMemoryUsage();
        
        metrics.setHeapUsedMb(heapMemory.getUsed() / 1024 / 1024);
        metrics.setHeapMaxMb(heapMemory.getMax() / 1024 / 1024);
        metrics.setHeapCommittedMb(heapMemory.getCommitted() / 1024 / 1024);
        metrics.setNonHeapUsedMb(nonHeapMemory.getUsed() / 1024 / 1024);
        metrics.setNonHeapMaxMb(nonHeapMemory.getMax() / 1024 / 1024);
        metrics.setNonHeapCommittedMb(nonHeapMemory.getCommitted() / 1024 / 1024);
        
        // Thread Metrics
        ThreadMXBean threadBean = ManagementFactory.getThreadMXBean();
        metrics.setThreadCount(threadBean.getThreadCount());
        metrics.setPeakThreadCount(threadBean.getPeakThreadCount());
        metrics.setDaemonThreadCount(threadBean.getDaemonThreadCount());
        
        // GC Metrics
        collectGarbageCollectionMetrics(metrics);
        
        // Application Metrics
        metrics.setTotalRequests(totalRequests.get());
        metrics.setFailedRequests(failedRequests.get());
        metrics.setProcessingTimeMs(processingTimeMs.get());
        
        // Calculate derived metrics
        if (metrics.getTotalRequests() > 0) {
            metrics.setErrorRate((double) metrics.getFailedRequests() / metrics.getTotalRequests() * 100);
            metrics.setAvgProcessingTimeMs((double) metrics.getProcessingTimeMs() / metrics.getTotalRequests());
        } else {
            metrics.setErrorRate(0.0);
            metrics.setAvgProcessingTimeMs(0.0);
        }
        
        // Database Health
        try {
            DatabaseHealthMetrics dbMetrics = databaseMonitoringService.collectDatabaseMetrics();
            metrics.setDatabaseHealthy(true);
            metrics.setActiveConnections(dbMetrics.getActiveConnections());
            metrics.setDatabaseSize(dbMetrics.getDatabaseSize());
        } catch (Exception e) {
            metrics.setDatabaseHealthy(false);
            log.warn("Failed to collect database metrics for application health check", e);
        }
        
        return metrics;
    }
    
    private void collectGarbageCollectionMetrics(ApplicationHealthMetrics metrics) {
        try {
            // Get GC information
            long totalGcTime = 0;
            long totalGcCount = 0;
            
            for (var gcBean : ManagementFactory.getGarbageCollectorMXBeans()) {
                totalGcTime += gcBean.getCollectionTime();
                totalGcCount += gcBean.getCollectionCount();
            }
            
            metrics.setTotalGcTimeMs(totalGcTime);
            metrics.setTotalGcCount(totalGcCount);
            
            // Calculate GC frequency (collections per minute)
            if (totalGcCount > 0) {
                metrics.setGcFrequencyPerMinute((double) totalGcCount / (System.currentTimeMillis() / 60000.0));
            } else {
                metrics.setGcFrequencyPerMinute(0.0);
            }
            
        } catch (Exception e) {
            log.warn("Failed to collect GC metrics", e);
            metrics.setTotalGcTimeMs(0);
            metrics.setTotalGcCount(0);
            metrics.setGcFrequencyPerMinute(0.0);
        }
    }
    
    /**
     * Log application health metrics to daily log file
     */
    private void logApplicationHealthMetrics(ApplicationHealthMetrics metrics) {
        StringBuilder logMessage = new StringBuilder();
        logMessage.append("APP_MONITORING|").append(metrics.getTimestamp().format(LOG_FORMATTER)).append("|");
        
        // Memory metrics
        logMessage.append("MEMORY|")
                .append("heap_used_mb=").append(metrics.getHeapUsedMb()).append("|")
                .append("heap_max_mb=").append(metrics.getHeapMaxMb()).append("|")
                .append("heap_committed_mb=").append(metrics.getHeapCommittedMb()).append("|")
                .append("non_heap_used_mb=").append(metrics.getNonHeapUsedMb()).append("|")
                .append("non_heap_max_mb=").append(metrics.getNonHeapMaxMb()).append("|")
                .append("non_heap_committed_mb=").append(metrics.getNonHeapCommittedMb()).append("|");
        
        // Thread metrics
        logMessage.append("THREADS|")
                .append("count=").append(metrics.getThreadCount()).append("|")
                .append("peak=").append(metrics.getPeakThreadCount()).append("|")
                .append("daemon=").append(metrics.getDaemonThreadCount()).append("|");
        
        // GC metrics
        logMessage.append("GC|")
                .append("total_time_ms=").append(metrics.getTotalGcTimeMs()).append("|")
                .append("total_count=").append(metrics.getTotalGcCount()).append("|")
                .append("frequency_per_min=").append(String.format("%.2f", metrics.getGcFrequencyPerMinute())).append("|");
        
        // Application metrics
        logMessage.append("APP_METRICS|")
                .append("total_requests=").append(metrics.getTotalRequests()).append("|")
                .append("failed_requests=").append(metrics.getFailedRequests()).append("|")
                .append("error_rate=").append(String.format("%.2f", metrics.getErrorRate())).append("%|")
                .append("avg_processing_time_ms=").append(String.format("%.2f", metrics.getAvgProcessingTimeMs())).append("|");
        
        // Database health
        logMessage.append("DB_HEALTH|")
                .append("healthy=").append(metrics.isDatabaseHealthy()).append("|")
                .append("active_connections=").append(metrics.getActiveConnections()).append("|")
                .append("db_size=").append(metrics.getDatabaseSize()).append("|");
        
        log.info(APP_MONITORING_MARKER, logMessage.toString());
    }
    
    /**
     * Check for alert conditions and log warnings
     */
    private void checkForAlerts(ApplicationHealthMetrics metrics) {
        // Memory alerts
        if (metrics.getHeapUsedMb() > metrics.getHeapMaxMb() * 0.85) {
            log.warn("HIGH_MEMORY_USAGE: Heap usage at {}% ({}MB/{}MB)", 
                    String.format("%.1f", (double) metrics.getHeapUsedMb() / metrics.getHeapMaxMb() * 100),
                    metrics.getHeapUsedMb(), metrics.getHeapMaxMb());
        }
        
        // Thread alerts
        if (metrics.getThreadCount() > 200) {
            log.warn("HIGH_THREAD_COUNT: {} threads active (peak: {})", 
                    metrics.getThreadCount(), metrics.getPeakThreadCount());
        }
        
        // GC alerts
        if (metrics.getGcFrequencyPerMinute() > 10) {
            log.warn("HIGH_GC_FREQUENCY: {} GC collections per minute", 
                    String.format("%.2f", metrics.getGcFrequencyPerMinute()));
        }
        
        // Error rate alerts
        if (metrics.getErrorRate() > 5.0) {
            log.warn("HIGH_ERROR_RATE: {}% error rate ({} failed out of {} total)", 
                    String.format("%.2f", metrics.getErrorRate()),
                    metrics.getFailedRequests(), metrics.getTotalRequests());
        }
        
        // Processing time alerts
        if (metrics.getAvgProcessingTimeMs() > 1000) {
            log.warn("SLOW_PROCESSING: Average processing time {}ms", 
                    String.format("%.2f", metrics.getAvgProcessingTimeMs()));
        }
        
        // Database health alerts
        if (!metrics.isDatabaseHealthy()) {
            log.warn("DATABASE_UNHEALTHY: Database health check failed");
        }
        
        if (metrics.getActiveConnections() > 50) {
            log.warn("HIGH_DB_CONNECTIONS: {} active database connections", 
                    metrics.getActiveConnections());
        }
    }
    
    /**
     * Increment request count (called by request interceptors)
     */
    public void incrementRequestCount() {
        totalRequests.incrementAndGet();
    }
    
    /**
     * Increment failed request count (called when requests fail)
     */
    public void incrementFailedRequestCount() {
        failedRequests.incrementAndGet();
    }
    
    /**
     * Add processing time (called by request interceptors)
     */
    public void addProcessingTime(long timeMs) {
        processingTimeMs.addAndGet(timeMs);
    }
    
    /**
     * Get current application statistics
     */
    public Map<String, Object> getCurrentStats() {
        Map<String, Object> stats = new HashMap<>();
        stats.put("totalRequests", totalRequests.get());
        stats.put("failedRequests", failedRequests.get());
        stats.put("processingTimeMs", processingTimeMs.get());
        stats.put("monitoringEnabled", monitoringEnabled);
        stats.put("monitoringInterval", monitoringInterval);
        return stats;
    }
}

