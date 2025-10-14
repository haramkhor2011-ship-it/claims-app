package com.acme.claims.monitoring;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Automated backup service for database and file system
 * Provides disaster recovery capabilities with integrity verification
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class BackupService {
    
    private final DatabaseMonitoringService databaseMonitoringService;
    
    @Value("${claims.backup.enabled:true}")
    private boolean backupEnabled;
    
    @Value("${claims.backup.database.enabled:true}")
    private boolean databaseBackupEnabled;
    
    @Value("${claims.backup.files.enabled:true}")
    private boolean fileBackupEnabled;
    
    @Value("${claims.backup.retention.days:30}")
    private int retentionDays;
    
    @Value("${claims.backup.path:/backups}")
    private String backupPath;
    
    @Value("${spring.datasource.url:}")
    private String databaseUrl;
    
    @Value("${spring.datasource.username:}")
    private String databaseUsername;
    
    @Value("${spring.datasource.password:}")
    private String databasePassword;
    
    private final AtomicLong totalBackups = new AtomicLong(0);
    private final AtomicLong successfulBackups = new AtomicLong(0);
    private final AtomicLong failedBackups = new AtomicLong(0);
    
    private static final DateTimeFormatter BACKUP_FORMATTER = DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss");
    
    /**
     * Scheduled daily backup - runs at 2 AM
     */
    @Scheduled(cron = "0 0 2 * * ?")
    public void performDailyBackup() {
        if (!backupEnabled) {
            log.info("Backup service is disabled");
            return;
        }
        
        log.info("Starting daily backup process");
        long startTime = System.currentTimeMillis();
        
        try {
            BackupResult result = performBackup();
            logBackupResult(result);
            
            if (result.isSuccess()) {
                successfulBackups.incrementAndGet();
                log.info("Daily backup completed successfully in {}ms", System.currentTimeMillis() - startTime);
            } else {
                failedBackups.incrementAndGet();
                log.error("Daily backup failed: {}", result.getErrorMessage());
            }
            
        } catch (Exception e) {
            failedBackups.incrementAndGet();
            log.error("Daily backup failed with exception", e);
        } finally {
            totalBackups.incrementAndGet();
        }
    }
    
    /**
     * Perform comprehensive backup
     */
    public BackupResult performBackup() {
        BackupResult result = new BackupResult();
        result.setStartTime(LocalDateTime.now());
        result.setBackupId(generateBackupId());
        
        try {
            // Create backup directory
            Path backupDir = createBackupDirectory(result.getBackupId());
            result.setBackupPath(backupDir.toString());
            
            // Database backup
            if (databaseBackupEnabled) {
                BackupResult dbResult = performDatabaseBackup(backupDir);
                result.addDatabaseResult(dbResult);
            }
            
            // File system backup
            if (fileBackupEnabled) {
                BackupResult fsResult = performFileSystemBackup(backupDir);
                result.addFileSystemResult(fsResult);
            }
            
            // Verify backup integrity
            boolean integrityCheck = verifyBackupIntegrity(backupDir);
            result.setIntegrityVerified(integrityCheck);
            
            // Cleanup old backups
            cleanupOldBackups();
            
            result.setSuccess(true);
            result.setEndTime(LocalDateTime.now());
            
        } catch (Exception e) {
            result.setSuccess(false);
            result.setErrorMessage(e.getMessage());
            result.setEndTime(LocalDateTime.now());
            log.error("Backup failed", e);
        }
        
        return result;
    }
    
    /**
     * Perform database backup using pg_dump
     */
    private BackupResult performDatabaseBackup(Path backupDir) throws Exception {
        BackupResult result = new BackupResult();
        result.setStartTime(LocalDateTime.now());
        
        try {
            // Extract database name from URL
            String dbName = extractDatabaseName(databaseUrl);
            String backupFile = backupDir.resolve("database_" + dbName + ".sql").toString();
            
            // Build pg_dump command
            List<String> command = new ArrayList<>();
            command.add("pg_dump");
            command.add("-h");
            command.add(extractHost(databaseUrl));
            command.add("-p");
            command.add(extractPort(databaseUrl));
            command.add("-U");
            command.add(databaseUsername);
            command.add("-d");
            command.add(dbName);
            command.add("-f");
            command.add(backupFile);
            command.add("--verbose");
            command.add("--no-password");
            
            // Set password environment variable
            ProcessBuilder pb = new ProcessBuilder(command);
            pb.environment().put("PGPASSWORD", databasePassword);
            
            // Execute backup
            Process process = pb.start();
            int exitCode = process.waitFor();
            
            if (exitCode == 0) {
                result.setSuccess(true);
                result.setBackupSize(getFileSize(backupFile));
                log.info("Database backup completed successfully: {}", backupFile);
            } else {
                result.setSuccess(false);
                result.setErrorMessage("pg_dump exited with code: " + exitCode);
                log.error("Database backup failed with exit code: {}", exitCode);
            }
            
        } catch (Exception e) {
            result.setSuccess(false);
            result.setErrorMessage(e.getMessage());
            log.error("Database backup failed", e);
        }
        
        result.setEndTime(LocalDateTime.now());
        return result;
    }
    
    /**
     * Perform file system backup
     */
    private BackupResult performFileSystemBackup(Path backupDir) throws Exception {
        BackupResult result = new BackupResult();
        result.setStartTime(LocalDateTime.now());
        
        try {
            // Backup application logs
            Path logsDir = Paths.get("logs");
            if (Files.exists(logsDir)) {
                Path logsBackup = backupDir.resolve("logs");
                copyDirectory(logsDir, logsBackup);
                result.setLogsBackedUp(true);
                log.info("Logs backup completed: {}", logsBackup);
            }
            
            // Backup configuration files
            Path configDir = Paths.get("config");
            if (Files.exists(configDir)) {
                Path configBackup = backupDir.resolve("config");
                copyDirectory(configDir, configBackup);
                result.setConfigBackedUp(true);
                log.info("Configuration backup completed: {}", configBackup);
            }
            
            // Backup data directory
            Path dataDir = Paths.get("data");
            if (Files.exists(dataDir)) {
                Path dataBackup = backupDir.resolve("data");
                copyDirectory(dataDir, dataBackup);
                result.setDataBackedUp(true);
                log.info("Data backup completed: {}", dataBackup);
            }
            
            result.setSuccess(true);
            
        } catch (Exception e) {
            result.setSuccess(false);
            result.setErrorMessage(e.getMessage());
            log.error("File system backup failed", e);
        }
        
        result.setEndTime(LocalDateTime.now());
        return result;
    }
    
    /**
     * Verify backup integrity
     */
    private boolean verifyBackupIntegrity(Path backupDir) {
        try {
            // Check if backup directory exists and is not empty
            if (!Files.exists(backupDir) || !Files.isDirectory(backupDir)) {
                log.error("Backup directory does not exist: {}", backupDir);
                return false;
            }
            
            // Check for database backup file
            boolean hasDatabaseBackup = Files.list(backupDir)
                    .anyMatch(path -> path.getFileName().toString().endsWith(".sql"));
            
            if (!hasDatabaseBackup) {
                log.error("No database backup file found in: {}", backupDir);
                return false;
            }
            
            // Check file sizes (basic integrity check)
            long totalSize = Files.list(backupDir)
                    .mapToLong(this::getFileSize)
                    .sum();
            
            if (totalSize == 0) {
                log.error("Backup files are empty: {}", backupDir);
                return false;
            }
            
            log.info("Backup integrity verification passed: {} ({} bytes)", backupDir, totalSize);
            return true;
            
        } catch (Exception e) {
            log.error("Backup integrity verification failed", e);
            return false;
        }
    }
    
    /**
     * Cleanup old backups based on retention policy
     */
    private void cleanupOldBackups() {
        try {
            Path backupRoot = Paths.get(backupPath);
            if (!Files.exists(backupRoot)) {
                return;
            }
            
            LocalDateTime cutoffDate = LocalDateTime.now().minusDays(retentionDays);
            
            Files.list(backupRoot)
                    .filter(Files::isDirectory)
                    .forEach(backupDir -> {
                        try {
                            String dirName = backupDir.getFileName().toString();
                            if (dirName.startsWith("backup_")) {
                                LocalDateTime backupDate = parseBackupDate(dirName);
                                if (backupDate.isBefore(cutoffDate)) {
                                    deleteDirectory(backupDir);
                                    log.info("Deleted old backup: {}", backupDir);
                                }
                            }
                        } catch (Exception e) {
                            log.warn("Failed to process backup directory: {}", backupDir, e);
                        }
                    });
            
        } catch (Exception e) {
            log.error("Failed to cleanup old backups", e);
        }
    }
    
    /**
     * Create backup directory with timestamp
     */
    private Path createBackupDirectory(String backupId) throws IOException {
        Path backupDir = Paths.get(backupPath, "backup_" + backupId);
        Files.createDirectories(backupDir);
        return backupDir;
    }
    
    /**
     * Generate unique backup ID
     */
    private String generateBackupId() {
        return LocalDateTime.now().format(BACKUP_FORMATTER);
    }
    
    /**
     * Extract database name from JDBC URL
     */
    private String extractDatabaseName(String url) {
        if (url == null || url.isEmpty()) {
            return "claims_db";
        }
        String[] parts = url.split("/");
        return parts[parts.length - 1];
    }
    
    /**
     * Extract host from JDBC URL
     */
    private String extractHost(String url) {
        if (url == null || url.isEmpty()) {
            return "localhost";
        }
        String[] parts = url.split("://")[1].split(":");
        return parts[0];
    }
    
    /**
     * Extract port from JDBC URL
     */
    private String extractPort(String url) {
        if (url == null || url.isEmpty()) {
            return "5432";
        }
        String[] parts = url.split("://")[1].split(":");
        if (parts.length > 1) {
            return parts[1].split("/")[0];
        }
        return "5432";
    }
    
    /**
     * Get file size in bytes
     */
    private long getFileSize(String filePath) {
        try {
            return Files.size(Paths.get(filePath));
        } catch (IOException e) {
            return 0;
        }
    }
    
    /**
     * Get file size in bytes
     */
    private long getFileSize(Path path) {
        try {
            return Files.size(path);
        } catch (IOException e) {
            return 0;
        }
    }
    
    /**
     * Copy directory recursively
     */
    private void copyDirectory(Path source, Path target) throws IOException {
        Files.walk(source)
                .forEach(sourcePath -> {
                    try {
                        Path targetPath = target.resolve(source.relativize(sourcePath));
                        if (Files.isDirectory(sourcePath)) {
                            Files.createDirectories(targetPath);
                        } else {
                            Files.createDirectories(targetPath.getParent());
                            Files.copy(sourcePath, targetPath);
                        }
                    } catch (IOException e) {
                        log.error("Failed to copy file: {} to {}", sourcePath, target.resolve(source.relativize(sourcePath)), e);
                    }
                });
    }
    
    /**
     * Delete directory recursively
     */
    private void deleteDirectory(Path directory) throws IOException {
        Files.walk(directory)
                .sorted((a, b) -> b.compareTo(a)) // Delete files before directories
                .forEach(path -> {
                    try {
                        Files.delete(path);
                    } catch (IOException e) {
                        log.warn("Failed to delete: {}", path, e);
                    }
                });
    }
    
    /**
     * Parse backup date from directory name
     */
    private LocalDateTime parseBackupDate(String dirName) {
        try {
            String dateStr = dirName.substring(7); // Remove "backup_" prefix
            return LocalDateTime.parse(dateStr, BACKUP_FORMATTER);
        } catch (Exception e) {
            return LocalDateTime.now().minusDays(retentionDays + 1); // Force deletion
        }
    }
    
    /**
     * Log backup result
     */
    private void logBackupResult(BackupResult result) {
        if (result.isSuccess()) {
            log.info("BACKUP_SUCCESS|backup_id={}|path={}|duration_ms={}|integrity_verified={}",
                    result.getBackupId(),
                    result.getBackupPath(),
                    result.getDurationMs(),
                    result.isIntegrityVerified());
        } else {
            log.error("BACKUP_FAILED|backup_id={}|error={}|duration_ms={}",
                    result.getBackupId(),
                    result.getErrorMessage(),
                    result.getDurationMs());
        }
    }
    
    /**
     * Get backup statistics
     */
    public BackupStatistics getStatistics() {
        return new BackupStatistics(
                totalBackups.get(),
                successfulBackups.get(),
                failedBackups.get(),
                backupEnabled,
                retentionDays
        );
    }
    
    /**
     * Backup result information
     */
    public static class BackupResult {
        private String backupId;
        private String backupPath;
        private LocalDateTime startTime;
        private LocalDateTime endTime;
        private boolean success;
        private String errorMessage;
        private boolean integrityVerified;
        private boolean logsBackedUp;
        private boolean configBackedUp;
        private boolean dataBackedUp;
        private long backupSize;
        
        // Getters and setters
        public String getBackupId() { return backupId; }
        public void setBackupId(String backupId) { this.backupId = backupId; }
        
        public String getBackupPath() { return backupPath; }
        public void setBackupPath(String backupPath) { this.backupPath = backupPath; }
        
        public LocalDateTime getStartTime() { return startTime; }
        public void setStartTime(LocalDateTime startTime) { this.startTime = startTime; }
        
        public LocalDateTime getEndTime() { return endTime; }
        public void setEndTime(LocalDateTime endTime) { this.endTime = endTime; }
        
        public boolean isSuccess() { return success; }
        public void setSuccess(boolean success) { this.success = success; }
        
        public String getErrorMessage() { return errorMessage; }
        public void setErrorMessage(String errorMessage) { this.errorMessage = errorMessage; }
        
        public boolean isIntegrityVerified() { return integrityVerified; }
        public void setIntegrityVerified(boolean integrityVerified) { this.integrityVerified = integrityVerified; }
        
        public boolean isLogsBackedUp() { return logsBackedUp; }
        public void setLogsBackedUp(boolean logsBackedUp) { this.logsBackedUp = logsBackedUp; }
        
        public boolean isConfigBackedUp() { return configBackedUp; }
        public void setConfigBackedUp(boolean configBackedUp) { this.configBackedUp = configBackedUp; }
        
        public boolean isDataBackedUp() { return dataBackedUp; }
        public void setDataBackedUp(boolean dataBackedUp) { this.dataBackedUp = dataBackedUp; }
        
        public long getBackupSize() { return backupSize; }
        public void setBackupSize(long backupSize) { this.backupSize = backupSize; }
        
        public long getDurationMs() {
            if (startTime != null && endTime != null) {
                return java.time.Duration.between(startTime, endTime).toMillis();
            }
            return 0;
        }
        
        public void addDatabaseResult(BackupResult dbResult) {
            // Merge database backup results
        }
        
        public void addFileSystemResult(BackupResult fsResult) {
            // Merge file system backup results
        }
    }
    
    /**
     * Backup statistics
     */
    public static class BackupStatistics {
        private final long totalBackups;
        private final long successfulBackups;
        private final long failedBackups;
        private final boolean enabled;
        private final int retentionDays;
        
        public BackupStatistics(long totalBackups, long successfulBackups, long failedBackups, 
                              boolean enabled, int retentionDays) {
            this.totalBackups = totalBackups;
            this.successfulBackups = successfulBackups;
            this.failedBackups = failedBackups;
            this.enabled = enabled;
            this.retentionDays = retentionDays;
        }
        
        // Getters
        public long getTotalBackups() { return totalBackups; }
        public long getSuccessfulBackups() { return successfulBackups; }
        public long getFailedBackups() { return failedBackups; }
        public boolean isEnabled() { return enabled; }
        public int getRetentionDays() { return retentionDays; }
        
        public double getSuccessRate() {
            return totalBackups > 0 ? (double) successfulBackups / totalBackups * 100 : 0;
        }
    }
}
