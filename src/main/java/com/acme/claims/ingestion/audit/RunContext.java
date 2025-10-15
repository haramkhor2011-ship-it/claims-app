package com.acme.claims.ingestion.audit;

/**
 * Thread-local context for managing ingestion run state across the processing pipeline.
 * 
 * This class provides a thread-safe way to track the current ingestion run ID
 * throughout the file processing lifecycle, ensuring that audit operations
 * can be properly associated with the correct run.
 * 
 * Usage:
 * - Set the run ID at the beginning of a drain cycle
 * - Access the run ID during file processing
 * - Clear the context at the end of processing
 */
public class RunContext {
    private static final ThreadLocal<Long> currentRunId = new ThreadLocal<>();
    
    /**
     * Set the current ingestion run ID for this thread.
     * 
     * @param runId the ingestion run ID to set
     */
    public static void setCurrentRunId(Long runId) {
        currentRunId.set(runId);
    }
    
    /**
     * Get the current ingestion run ID for this thread.
     * 
     * @return the current run ID, or null if not set
     */
    public static Long getCurrentRunId() {
        return currentRunId.get();
    }
    
    /**
     * Clear the current run ID for this thread.
     * This should be called in a finally block to ensure cleanup.
     */
    public static void clear() {
        currentRunId.remove();
    }
    
    /**
     * Check if a run ID is currently set for this thread.
     * 
     * @return true if a run ID is set, false otherwise
     */
    public static boolean hasCurrentRunId() {
        return currentRunId.get() != null;
    }
}
