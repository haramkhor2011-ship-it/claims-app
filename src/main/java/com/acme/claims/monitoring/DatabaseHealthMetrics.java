package com.acme.claims.monitoring;

import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import java.time.LocalDateTime;
import java.util.Map;

/**
 * Data class to hold database health metrics collected during monitoring
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class DatabaseHealthMetrics {
    
    // Timestamp when metrics were collected
    private LocalDateTime timestamp;
    
    // Basic database information
    private String databaseProductName;
    private String databaseProductVersion;
    private String driverName;
    private String driverVersion;
    private String url;
    private String username;
    
    // Database size metrics
    private String databaseSize;
    private Long databaseSizeBytes;
    private String schemaSize;
    private Long schemaSizeBytes;
    
    // Connection pool metrics
    private Integer connectionPoolActive;
    private Integer connectionPoolIdle;
    private Integer connectionPoolTotal;
    
    // Active connections metrics
    private Integer activeConnections;
    private Integer activeQueries;
    private Integer idleConnections;
    private Integer idleInTransaction;
    
    // Database locks
    private Integer totalLocks;
    private Integer exclusiveLocks;
    private Integer shareLocks;
    
    // Query performance metrics
    private Long totalQueryCalls;
    private Double totalQueryTimeMs;
    private Double avgQueryTimeMs;
    private Long slowQueries;
    
    // Top tables statistics
    private Map<String, Object> topTables;
}
