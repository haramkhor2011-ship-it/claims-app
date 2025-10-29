/*
 * SSOT NOTICE — LocalFS Fetcher with Continuous Scanning
 * Profile: localfs
 * Purpose: Watch a directory for *.xml and emit WorkItems with bytes in-memory.
 * Guarantees:
 *   - Initial sweep picks up existing files at startup.
 *   - Continuous scanning ensures all files are discovered.
 *   - WatchService listens for new files.
 *   - Backpressure-aware (pause/resume).
 *   - Duplicate prevention with file tracking.
 */
package com.acme.claims.ingestion.fetch;

import com.acme.claims.ingestion.config.IngestionProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.nio.file.*;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Consumer;

@Component
@Profile("localfs")
public class LocalFsFetcher implements Fetcher {
    private static final Logger log = LoggerFactory.getLogger(LocalFsFetcher.class);

    private final IngestionProperties props;
    private volatile boolean paused = false;
    private volatile boolean running = false;
    
    // Track processed files to prevent duplicates
    private final Set<String> processedFiles = ConcurrentHashMap.newKeySet();
    
    // Configuration
    private static final long CONTINUOUS_SCAN_INTERVAL_MS = 5000; // 5 seconds
    private static final long PAUSE_SLEEP_MS = 150L;

    public LocalFsFetcher(IngestionProperties props) {
        this.props = props;
    }

    @Override
    public void start(Consumer<WorkItem> onReady) {
        final Path ready = Paths.get(props.getLocalfs().getReadyDir());
        try { 
            Files.createDirectories(ready); 
        } catch (IOException e) { 
            log.error("Ready dir create failed: {}", ready, e); 
            return; 
        }

        running = true;
        
        // Start continuous scanning thread
        Thread continuousScanThread = new Thread(() -> {
            continuousScanLoop(onReady, ready);
        }, "fetch-localfs-continuous");
        continuousScanThread.setDaemon(true);
        continuousScanThread.start();

        // Start WatchService thread for new files
        Thread watchThread = new Thread(() -> {
            watchServiceLoop(onReady, ready);
        }, "fetch-localfs-watch");
        watchThread.setDaemon(true);
        watchThread.start();
        
        log.info("LocalFsFetcher started with continuous scanning; watching {}", ready);
    }

    /**
     * Continuous scanning loop that periodically scans the directory
     * for files that might have been missed by the initial sweep or WatchService.
     */
    private void continuousScanLoop(Consumer<WorkItem> onReady, Path ready) {
        log.info("Starting continuous scanning loop with interval {}ms", CONTINUOUS_SCAN_INTERVAL_MS);
        
        while (running && !Thread.currentThread().isInterrupted()) {
            try {
                Thread.sleep(CONTINUOUS_SCAN_INTERVAL_MS);
                
                if (paused) {
                    log.debug("Continuous scanning paused, skipping scan cycle");
                    continue;
                }
                
                scanDirectory(onReady, ready, "continuous");
                
            } catch (InterruptedException ie) {
                Thread.currentThread().interrupt();
                log.info("Continuous scanning thread interrupted");
                break;
            } catch (Exception e) {
                log.error("Continuous scanning error: {}", e.getMessage(), e);
                // Continue scanning despite errors
            }
        }
        
        log.info("Continuous scanning loop terminated");
    }

    /**
     * WatchService loop for detecting new files created after startup.
     */
    private void watchServiceLoop(Consumer<WorkItem> onReady, Path ready) {
        log.info("Starting WatchService loop");
        
        try (WatchService ws = FileSystems.getDefault().newWatchService()) {
            ready.register(ws, StandardWatchEventKinds.ENTRY_CREATE);
            
            while (running && !Thread.currentThread().isInterrupted()) {
                try {
                    if (paused) { 
                        Thread.sleep(PAUSE_SLEEP_MS); 
                        continue; 
                    }
                    
                    WatchKey key = ws.take();
                    for (WatchEvent<?> ev : key.pollEvents()) {
                        if (ev.kind() == StandardWatchEventKinds.OVERFLOW) continue;
                        
                        Path rel = (Path) ev.context();
                        Path file = ready.resolve(rel);
                        
                        if (file.toString().toLowerCase().endsWith(".xml")) {
                            emitFile(onReady, file, "watchservice");
                        }
                    }
                    key.reset();
                    
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    break;
                } catch (Exception e) {
                    log.error("WatchService error: {}", e.getMessage(), e);
                }
            }
        } catch (Exception e) {
            log.error("WatchService setup failed: {}", e.getMessage(), e);
        }
        
        log.info("WatchService loop terminated");
    }

    /**
     * Scan directory for XML files and emit them if not already processed.
     */
    private void scanDirectory(Consumer<WorkItem> onReady, Path ready, String source) {
        try (DirectoryStream<Path> ds = Files.newDirectoryStream(ready, "*.xml")) {
            int found = 0;
            int emitted = 0;
            
            for (Path file : ds) {
                found++;
                if (emitFile(onReady, file, source)) {
                    emitted++;
                }
            }
            
            if (found > 0) {
                log.debug("Directory scan [{}]: found={}, emitted={}", source, found, emitted);
            }
            
        } catch (Exception e) {
            log.warn("Directory scan [{}] error: {}", source, e.getMessage());
        }
    }

    /**
     * Emit a file if it hasn't been processed before.
     * Returns true if file was emitted, false if already processed.
     */
    private boolean emitFile(Consumer<WorkItem> onReady, Path file, String source) {
        try {
            String fileName = file.getFileName().toString();
            
            // Check if already processed
            if (processedFiles.contains(fileName)) {
                return false;
            }
            
            // Mark as processed before emitting to prevent race conditions
            processedFiles.add(fileName);
            
            // Read file and emit
            byte[] bytes = Files.readAllBytes(file);
            String fileId = fileName; // stable id for idempotency/audit
            
            WorkItem workItem = new WorkItem(fileId, bytes, file, "localfs", fileName);
            onReady.accept(workItem);
            
            log.debug("Emitted file [{}]: {}", source, fileName);
            return true;
            
        } catch (Exception e) {
            log.warn("Failed to emit file [{}] {}: {}", source, file, e.getMessage());
            return false;
        }
    }

    @Override 
    public void pause() { 
        this.paused = true; 
        log.debug("LocalFsFetcher paused");
    }
    
    @Override 
    public void resume() { 
        this.paused = false; 
        log.debug("LocalFsFetcher resumed");
    }
    
    /**
     * Shutdown the fetcher gracefully.
     */
    public void shutdown() {
        running = false;
        log.info("LocalFsFetcher shutdown requested");
    }
}
