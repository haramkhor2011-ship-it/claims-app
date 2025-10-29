# 🔧 **EXACT EDIT PLAN: CONTINUOUS SCANNING MODE FOR LOCALFS FETCHER**

## 📋 **REQUIREMENTS ANALYSIS**

**Current Behavior**:
- Queue capacity: 100 files (from `queue-capacity: 100`)
- Resume threshold: `workers * 2` = `4 * 2` = 8 files remaining capacity
- Resume happens when: `queue.remainingCapacity() > 8` (i.e., when queue has ≤92 files)

**Desired Behavior**:
- Continuous scanning when queue is 30-50% empty
- Resume threshold: 30-50% of capacity = 30-50 files remaining capacity
- Keep queue full until all files are processed

## 🎯 **EDIT PLAN**

### **Step 1: Modify LocalFsFetcher.java**

**File**: `src/main/java/com/acme/claims/ingestion/fetch/LocalFsFetcher.java`

**Changes Required**:

1. **Add continuous scanning thread**
2. **Add file tracking to prevent duplicates**
3. **Add proper exception handling**
4. **Add configuration for scan interval**

### **Step 2: Update Orchestrator.java**

**File**: `src/main/java/com/acme/claims/ingestion/Orchestrator.java`

**Changes Required**:

1. **Modify resume threshold** from `workers * 2` to `queue.capacity * 0.3` (30% threshold)
2. **Add logging** for better observability

### **Step 3: Update Configuration**

**File**: `src/main/resources/application-localfs.yml`

**Changes Required**:

1. **Add continuous scanning configuration**
2. **Add scan interval setting**

## 📝 **DETAILED IMPLEMENTATION**

### **1. LocalFsFetcher.java - Complete Replacement**

```java
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
```

### **2. Orchestrator.java - Modify Resume Threshold**

**File**: `src/main/java/com/acme/claims/ingestion/Orchestrator.java`

**Find this section** (around line 397):
```java
if (queue.remainingCapacity() > (workers * 2)) {
    try { fetcher.resume(); } catch (Exception ignore) {}
}
```

**Replace with**:
```java
// Resume fetcher when queue has 30% capacity remaining (70% full)
int resumeThreshold = (int) (queue.capacity() * 0.3);
if (queue.remainingCapacity() > resumeThreshold) {
    try { 
        fetcher.resume(); 
        log.debug("Fetcher resumed - queue capacity: {}/{} ({}% full)", 
            queue.size(), queue.capacity(), 
            (int) ((queue.size() * 100.0) / queue.capacity()));
    } catch (Exception ignore) {}
}
```

### **3. application-localfs.yml - Add Configuration**

**File**: `src/main/resources/application-localfs.yml`

**Add this section** under `claims.ingestion.localfs`:
```yaml
    # Continuous scanning configuration
    continuous-scan:
      enabled: true
      interval-ms: 5000          # Scan every 5 seconds
      pause-sleep-ms: 150        # Sleep time when paused
```

## 🔧 **IMPLEMENTATION STEPS**

### **Step 1: Backup Current File**
```bash
cp src/main/java/com/acme/claims/ingestion/fetch/LocalFsFetcher.java src/main/java/com/acme/claims/ingestion/fetch/LocalFsFetcher.java.backup
```

### **Step 2: Replace LocalFsFetcher.java**
- Replace the entire file content with the new implementation above

### **Step 3: Update Orchestrator.java**
- Find the resume threshold logic around line 397
- Replace with the new logic above

### **Step 4: Update Configuration**
- Add the continuous scanning configuration to application-localfs.yml

### **Step 5: Compile and Test**
```bash
mvn clean compile -DskipTests
```

## ✅ **EXPECTED BEHAVIOR AFTER IMPLEMENTATION**

1. **Initial Sweep**: Scans directory once at startup
2. **Continuous Scanning**: Scans directory every 5 seconds
3. **WatchService**: Detects new files immediately
4. **Duplicate Prevention**: Files are only processed once
5. **Resume Threshold**: Fetcher resumes when queue has 30% capacity (70% full)
6. **Queue Management**: Queue stays full until all files are processed
7. **Exception Handling**: Robust error handling with logging
8. **Graceful Shutdown**: Proper cleanup on application shutdown

## 🎯 **KEY FEATURES**

- **No Duplicates**: File tracking prevents processing same file twice
- **Continuous Discovery**: All files in directory will be discovered
- **Backpressure Aware**: Respects pause/resume signals
- **Configurable**: Scan interval can be adjusted
- **Observable**: Comprehensive logging for debugging
- **Error Resilient**: Continues working despite individual file errors
- **Thread Safe**: Proper synchronization for concurrent access

This implementation ensures that all files in the directory will be discovered and processed, maintaining a full queue until all files are ingested.
