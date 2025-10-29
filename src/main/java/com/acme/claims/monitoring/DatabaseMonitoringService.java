package com.acme.claims.monitoring;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.Marker;
import org.slf4j.MarkerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Lazy;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Database monitoring service that collects essential database metrics
 * and logs them to daily log files for monitoring and troubleshooting.
 */
@Service
@Slf4j
public class DatabaseMonitoringService {

    private final DataSource originalDataSource;
    private final JdbcTemplate jdbcTemplate;
    
    public DatabaseMonitoringService(@Qualifier("dataSource") @Lazy DataSource originalDataSource, JdbcTemplate jdbcTemplate) {
        this.originalDataSource = originalDataSource;
        this.jdbcTemplate = jdbcTemplate;
    }
    
    @Value("${claims.monitoring.database.enabled:true}")
    private boolean monitoringEnabled;
    
    @Value("${claims.monitoring.database.interval:PT5M}")
    private String monitoringInterval;
    
    private final AtomicLong connectionCount = new AtomicLong(0);
    private final AtomicLong queryCount = new AtomicLong(0);
    private final AtomicLong errorCount = new AtomicLong(0);
    
    private static final DateTimeFormatter LOG_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS");
    private static final Marker DB_MONITORING_MARKER = MarkerFactory.getMarker("DB_MONITORING");

    /**
     * Scheduled database health check - runs every 5 minutes by default
     */
    @Scheduled(fixedRateString = "#{T(java.time.Duration).parse('${claims.monitoring.database.interval:PT5M}').toMillis()}")
    public void performDatabaseHealthCheck() {
        if (!monitoringEnabled) {
            return;
        }
        
        try {
            DatabaseHealthMetrics metrics = collectDatabaseMetrics();
            logDatabaseHealthMetrics(metrics);
        } catch (Exception e) {
            errorCount.incrementAndGet();
            log.error("Failed to perform database health check", e);
        }
    }

    /**
     * Collect comprehensive database metrics
     */
    public DatabaseHealthMetrics collectDatabaseMetrics() throws SQLException {
        DatabaseHealthMetrics metrics = new DatabaseHealthMetrics();
        metrics.setTimestamp(LocalDateTime.now());
        
        try (Connection connection = originalDataSource.getConnection()) {
            DatabaseMetaData metaData = connection.getMetaData();
            
            // Basic connection info
            metrics.setDatabaseProductName(metaData.getDatabaseProductName());
            metrics.setDatabaseProductVersion(metaData.getDatabaseProductVersion());
            metrics.setDriverName(metaData.getDriverName());
            metrics.setDriverVersion(metaData.getDriverVersion());
            metrics.setUrl(metaData.getURL());
            metrics.setUsername(metaData.getUserName());
            
            // Connection pool metrics
            collectConnectionPoolMetrics(connection, metrics);
            
            // Database size and table statistics
            collectDatabaseSizeMetrics(metrics);
            
            // Active connections and locks
            collectActiveConnectionsMetrics(metrics);
            
            // Query performance metrics
            collectQueryPerformanceMetrics(metrics);
            
            // Table statistics
            collectTableStatistics(metrics);
            
        }
        
        return metrics;
    }

    private void collectConnectionPoolMetrics(Connection connection, DatabaseHealthMetrics metrics) {
        try {
            // HikariCP specific metrics (if using HikariCP)
            if (connection.getClass().getName().contains("Hikari")) {
                // Try to get HikariCP metrics via reflection
                Object hikariDataSource = connection.unwrap(Class.forName("com.zaxxer.hikari.HikariDataSource"));
                // This would require additional reflection to get pool metrics
                metrics.setConnectionPoolActive(0); // Placeholder
                metrics.setConnectionPoolIdle(0);   // Placeholder
                metrics.setConnectionPoolTotal(0);  // Placeholder
            }
        } catch (Exception e) {
            // Fallback to basic connection info
            metrics.setConnectionPoolActive(1);
            metrics.setConnectionPoolIdle(0);
            metrics.setConnectionPoolTotal(1);
        }
    }

    private void collectDatabaseSizeMetrics(DatabaseHealthMetrics metrics) {
        try {
            // Database size
            String dbSizeQuery = "SELECT " +
                "pg_size_pretty(pg_database_size(current_database())) as database_size, " +
                "pg_database_size(current_database()) as database_size_bytes";
            
            jdbcTemplate.query(dbSizeQuery, rs -> {
                metrics.setDatabaseSize(rs.getString("database_size"));
                metrics.setDatabaseSizeBytes(rs.getLong("database_size_bytes"));
            });
            
            // Schema size
            String schemaSizeQuery = "SELECT " +
                "schemaname, " +
                "pg_size_pretty(sum(pg_total_relation_size(schemaname||'.'||tablename))) as schema_size, " +
                "sum(pg_total_relation_size(schemaname||'.'||tablename)) as schema_size_bytes " +
                "FROM pg_tables " +
                "WHERE schemaname = 'claims' " +
                "GROUP BY schemaname";
            
            jdbcTemplate.query(schemaSizeQuery, rs -> {
                metrics.setSchemaSize(rs.getString("schema_size"));
                metrics.setSchemaSizeBytes(rs.getLong("schema_size_bytes"));
            });
            
        } catch (Exception e) {
            log.warn("Failed to collect database size metrics", e);
        }
    }

    private void collectActiveConnectionsMetrics(DatabaseHealthMetrics metrics) {
        try {
            // Active connections
            String activeConnectionsQuery = "SELECT " +
                "count(*) as active_connections, " +
                "count(*) FILTER (WHERE state = 'active') as active_queries, " +
                "count(*) FILTER (WHERE state = 'idle') as idle_connections, " +
                "count(*) FILTER (WHERE state = 'idle in transaction') as idle_in_transaction " +
                "FROM pg_stat_activity " +
                "WHERE datname = current_database()";
            
            jdbcTemplate.query(activeConnectionsQuery, rs -> {
                metrics.setActiveConnections(rs.getInt("active_connections"));
                metrics.setActiveQueries(rs.getInt("active_queries"));
                metrics.setIdleConnections(rs.getInt("idle_connections"));
                metrics.setIdleInTransaction(rs.getInt("idle_in_transaction"));
            });
            
            // Database locks
            String locksQuery = "SELECT " +
                "count(*) as total_locks, " +
                "count(*) FILTER (WHERE mode = 'ExclusiveLock') as exclusive_locks, " +
                "count(*) FILTER (WHERE mode = 'ShareLock') as share_locks " +
                "FROM pg_locks " +
                "WHERE database = (SELECT oid FROM pg_database WHERE datname = current_database())";
            
            jdbcTemplate.query(locksQuery, rs -> {
                metrics.setTotalLocks(rs.getInt("total_locks"));
                metrics.setExclusiveLocks(rs.getInt("exclusive_locks"));
                metrics.setShareLocks(rs.getInt("share_locks"));
            });
            
        } catch (Exception e) {
            log.warn("Failed to collect active connections metrics", e);
        }
    }

    private void collectQueryPerformanceMetrics(DatabaseHealthMetrics metrics) {
        try {
            // Check if pg_stat_statements extension is available and loaded
            String checkExtension = "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements') as ext_exists";
            Boolean extExists = jdbcTemplate.query(checkExtension, rs -> {
                if (rs.next()) {
                    return rs.getBoolean("ext_exists");
                }
                return false;
            });
            
            if (Boolean.FALSE.equals(extExists)) {
                log.debug("pg_stat_statements extension not installed, skipping query performance metrics");
                return;
            }
            
            // Try to query pg_stat_statements - PostgreSQL 16+ uses total_exec_time/mean_exec_time
            // For older versions (<13), we'd fall back to total_time/mean_time, but those aren't in PG16
            String queryStatsSql = "SELECT " +
                    "sum(calls) as total_calls, " +
                    "sum(total_exec_time) as total_time_ms, " +
                    "avg(mean_exec_time) as avg_query_time_ms, " +
                    "sum(calls) FILTER (WHERE mean_exec_time > 1000) as slow_queries " +
                    "FROM pg_stat_statements " +
                    "WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())";
            
            try {
                jdbcTemplate.query(queryStatsSql, rs -> {
                    if (rs.next()) {
                        metrics.setTotalQueryCalls(rs.getLong("total_calls"));
                        metrics.setTotalQueryTimeMs(rs.getDouble("total_time_ms"));
                        metrics.setAvgQueryTimeMs(rs.getDouble("avg_query_time_ms"));
                        metrics.setSlowQueries(rs.getLong("slow_queries"));
                    }
                });
            } catch (Exception queryEx) {
                // Extension exists but may not be loaded via shared_preload_libraries
                // This is expected if pg_stat_statements isn't fully enabled
                log.debug("pg_stat_statements query failed (extension may not be loaded): {}", queryEx.getMessage());
            }
        } catch (Exception e) {
            // Gracefully skip metrics if extension check fails
            log.debug("Failed to check pg_stat_statements extension: {}", e.getMessage());
        }
    }

    private void collectTableStatistics(DatabaseHealthMetrics metrics) {
        try {
            // Table statistics for claims schema
            String tableStatsQuery = "SELECT " +
                "schemaname, " +
                "relname as tablename, " +
                "n_tup_ins as inserts, " +
                "n_tup_upd as updates, " +
                "n_tup_del as deletes, " +
                "n_live_tup as live_tuples, " +
                "n_dead_tup as dead_tuples, " +
                "last_vacuum, " +
                "last_autovacuum, " +
                "last_analyze, " +
                "last_autoanalyze " +
                "FROM pg_stat_user_tables " +
                "WHERE schemaname = 'claims' " +
                "ORDER BY n_live_tup DESC " +
                "LIMIT 10";
            
            Map<String, Object> topTables = new HashMap<>();
            jdbcTemplate.query(tableStatsQuery, rs -> {
                String tableName = rs.getString("tablename");
                Map<String, Object> tableStats = new HashMap<>();
                tableStats.put("inserts", rs.getLong("inserts"));
                tableStats.put("updates", rs.getLong("updates"));
                tableStats.put("deletes", rs.getLong("deletes"));
                tableStats.put("live_tuples", rs.getLong("live_tuples"));
                tableStats.put("dead_tuples", rs.getLong("dead_tuples"));
                tableStats.put("last_vacuum", rs.getTimestamp("last_vacuum"));
                tableStats.put("last_autovacuum", rs.getTimestamp("last_autovacuum"));
                tableStats.put("last_analyze", rs.getTimestamp("last_analyze"));
                tableStats.put("last_autoanalyze", rs.getTimestamp("last_autoanalyze"));
                
                topTables.put(tableName, tableStats);
            });
            
            metrics.setTopTables(topTables);
            
        } catch (Exception e) {
            log.warn("Failed to collect table statistics", e);
        }
    }

    /**
     * Log database health metrics to daily log file
     */
    private void logDatabaseHealthMetrics(DatabaseHealthMetrics metrics) {
        StringBuilder logMessage = new StringBuilder();
        logMessage.append("DB_MONITORING|").append(metrics.getTimestamp().format(LOG_FORMATTER)).append("|");
        
        // Basic info
        logMessage.append("DB_INFO|")
                .append("product=").append(metrics.getDatabaseProductName()).append("|")
                .append("version=").append(metrics.getDatabaseProductVersion()).append("|")
                .append("driver=").append(metrics.getDriverName()).append("|")
                .append("driver_version=").append(metrics.getDriverVersion()).append("|");
        
        // Size metrics
        logMessage.append("SIZE|")
                .append("db_size=").append(metrics.getDatabaseSize()).append("|")
                .append("db_size_bytes=").append(metrics.getDatabaseSizeBytes()).append("|")
                .append("schema_size=").append(metrics.getSchemaSize()).append("|")
                .append("schema_size_bytes=").append(metrics.getSchemaSizeBytes()).append("|");
        
        // Connection metrics
        logMessage.append("CONNECTIONS|")
                .append("active=").append(metrics.getActiveConnections()).append("|")
                .append("active_queries=").append(metrics.getActiveQueries()).append("|")
                .append("idle=").append(metrics.getIdleConnections()).append("|")
                .append("idle_in_transaction=").append(metrics.getIdleInTransaction()).append("|")
                .append("pool_active=").append(metrics.getConnectionPoolActive()).append("|")
                .append("pool_idle=").append(metrics.getConnectionPoolIdle()).append("|")
                .append("pool_total=").append(metrics.getConnectionPoolTotal()).append("|");
        
        // Lock metrics
        logMessage.append("LOCKS|")
                .append("total=").append(metrics.getTotalLocks()).append("|")
                .append("exclusive=").append(metrics.getExclusiveLocks()).append("|")
                .append("share=").append(metrics.getShareLocks()).append("|");
        
        // Query performance
        if (metrics.getTotalQueryCalls() != null && metrics.getTotalQueryCalls() > 0) {
            logMessage.append("QUERY_PERF|")
                    .append("total_calls=").append(metrics.getTotalQueryCalls()).append("|");
            
            // Safely handle potentially null values
            if (metrics.getTotalQueryTimeMs() != null) {
                logMessage.append("total_time_ms=").append(String.format("%.2f", metrics.getTotalQueryTimeMs())).append("|");
            }
            if (metrics.getAvgQueryTimeMs() != null) {
                logMessage.append("avg_time_ms=").append(String.format("%.2f", metrics.getAvgQueryTimeMs())).append("|");
            }
            if (metrics.getSlowQueries() != null) {
                logMessage.append("slow_queries=").append(metrics.getSlowQueries()).append("|");
            }
        }
        
        // Top tables summary
        if (metrics.getTopTables() != null && !metrics.getTopTables().isEmpty()) {
            logMessage.append("TOP_TABLES|");
            metrics.getTopTables().forEach((tableName, stats) -> {
                @SuppressWarnings("unchecked")
                Map<String, Object> tableStats = (Map<String, Object>) stats;
                logMessage.append(tableName).append(":")
                        .append("live=").append(tableStats.get("live_tuples")).append(",")
                        .append("dead=").append(tableStats.get("dead_tuples")).append(",")
                        .append("inserts=").append(tableStats.get("inserts")).append(",")
                        .append("updates=").append(tableStats.get("updates")).append(",")
                        .append("deletes=").append(tableStats.get("deletes")).append(";");
            });
        }
        
        // Application metrics
        logMessage.append("APP_METRICS|")
                .append("connection_count=").append(connectionCount.get()).append("|")
                .append("query_count=").append(queryCount.get()).append("|")
                .append("error_count=").append(errorCount.get()).append("|");
        
        log.info(DB_MONITORING_MARKER, logMessage.toString());
    }

    /**
     * Increment connection count (called by connection interceptors)
     */
    public void incrementConnectionCount() {
        connectionCount.incrementAndGet();
    }

    /**
     * Increment query count (called by query interceptors)
     */
    public void incrementQueryCount() {
        queryCount.incrementAndGet();
    }

    /**
     * Increment error count (called when database errors occur)
     */
    public void incrementErrorCount() {
        errorCount.incrementAndGet();
    }

    /**
     * Get current monitoring statistics
     */
    public Map<String, Object> getCurrentStats() {
        Map<String, Object> stats = new HashMap<>();
        stats.put("connectionCount", connectionCount.get());
        stats.put("queryCount", queryCount.get());
        stats.put("errorCount", errorCount.get());
        stats.put("monitoringEnabled", monitoringEnabled);
        stats.put("monitoringInterval", monitoringInterval);
        return stats;
    }
}
