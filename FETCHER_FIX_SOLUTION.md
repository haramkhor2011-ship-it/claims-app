# 🔧 **FETCHER FIX: ADD PERIODIC DIRECTORY SCANNING**

## 🚨 **ROOT CAUSE CONFIRMED**

**The LocalFsFetcher only scans the directory ONCE at startup, then relies on WatchService for new files.**

**This is why the remaining 499 files weren't processed - they were already in the directory but not detected by the initial sweep.**

## 🔧 **SOLUTION: ADD PERIODIC SCANNING**

### **Current Behavior** (BROKEN):
1. **Initial Sweep**: Scans directory once at startup
2. **WatchService**: Only detects NEW files created after startup
3. **Missing Files**: Files already in directory but not in initial sweep are ignored

### **Fixed Behavior** (CORRECT):
1. **Initial Sweep**: Scans directory at startup
2. **Periodic Scanning**: Rescans directory every 30 seconds
3. **WatchService**: Detects NEW files created after startup
4. **Complete Coverage**: All files are eventually discovered

## 📝 **IMPLEMENTATION**

### **Option 1: Modify LocalFsFetcher (Recommended)**

Add periodic scanning to the existing fetcher:

```java
// In LocalFsFetcher.java - add periodic scanning
private void startPeriodicScanning(Consumer<WorkItem> onReady, Path ready) {
    Thread.ofVirtual().start(() -> {
        while (!Thread.currentThread().isInterrupted()) {
            try {
                Thread.sleep(30000); // Scan every 30 seconds
                if (paused) continue;
                
                // Rescan directory for missed files
                try (DirectoryStream<Path> ds = Files.newDirectoryStream(ready, "*.xml")) {
                    for (Path p : ds) {
                        // Only emit if file is newer than last scan
                        if (shouldEmitFile(p)) {
                            emit(onReady, p);
                        }
                    }
                } catch (Exception e) {
                    log.warn("Periodic scan error: {}", e.getMessage());
                }
            } catch (InterruptedException ie) {
                Thread.currentThread().interrupt();
                break;
            }
        }
    });
}
```

### **Option 2: Configuration-Based Solution (Quick Fix)**

Add a configuration property to control scanning behavior:

```yaml
# In application-localfs.yml
claims:
  ingestion:
    localfs:
      periodic-scan-enabled: true
      periodic-scan-interval-ms: 30000
```

## 🎯 **IMMEDIATE WORKAROUND**

### **For Your 3000 File Run**:

**Option A: Restart Application**
- Stop the application
- Restart it
- The initial sweep will pick up all files in the directory

**Option B: Add Files After Startup**
- Move files out of `data/ready`
- Start application
- Move files back to `data/ready` (WatchService will detect them)

**Option C: Use Different Directory**
- Put 3000 files in a different directory
- Start application
- Move files to `data/ready` in batches

## 🚀 **RECOMMENDED APPROACH**

### **For Production Use**:

1. **Implement Periodic Scanning**: Add the fix to LocalFsFetcher
2. **Test Thoroughly**: Ensure it doesn't cause duplicate processing
3. **Monitor Performance**: Ensure periodic scanning doesn't impact performance

### **For Your 3000 File Test**:

1. **Use Workaround**: Restart application or move files after startup
2. **Monitor Queue**: Ensure all files are discovered
3. **Verify Processing**: Check that all 3000 files are processed

## 📋 **IMPLEMENTATION STEPS**

### **Step 1: Quick Fix for Testing**
```bash
# Move files out of directory
mkdir data/ready_backup
mv data/ready/*.xml data/ready_backup/

# Start application
mvn spring-boot:run -Dspring-boot.run.profiles=localfs,ingestion

# Move files back in batches
mv data/ready_backup/*.xml data/ready/
```

### **Step 2: Permanent Fix (After Testing)**
- Modify LocalFsFetcher to add periodic scanning
- Test with small batches first
- Deploy to production

## 🎯 **FINAL ASSESSMENT**

**The fetcher design is fundamentally flawed for batch processing scenarios.**

**The fix is straightforward but requires code changes to LocalFsFetcher.**

**For your 3000 file test, use the workaround approach to ensure all files are processed.**
