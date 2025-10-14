package com.acme.claims.monitoring;

import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import java.time.LocalDateTime;

/**
 * Data class to hold application health metrics collected during monitoring
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ApplicationHealthMetrics {
    
    // Timestamp when metrics were collected
    private LocalDateTime timestamp;
    
    // Memory metrics (in MB)
    private long heapUsedMb;
    private long heapMaxMb;
    private long heapCommittedMb;
    private long nonHeapUsedMb;
    private long nonHeapMaxMb;
    private long nonHeapCommittedMb;
    
    // Thread metrics
    private int threadCount;
    private int peakThreadCount;
    private int daemonThreadCount;
    
    // Garbage Collection metrics
    private long totalGcTimeMs;
    private long totalGcCount;
    private double gcFrequencyPerMinute;
    
    // Application metrics
    private long totalRequests;
    private long failedRequests;
    private long processingTimeMs;
    private double errorRate;
    private double avgProcessingTimeMs;
    
    // Database health
    private boolean databaseHealthy;
    private int activeConnections;
    private String databaseSize;
}

