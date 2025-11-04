package com.acme.claims.ingestion.audit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class IngestionAudit {
    private static final Logger log = LoggerFactory.getLogger(IngestionAudit.class);
    private final JdbcTemplate jdbc;
    
    public IngestionAudit(JdbcTemplate jdbc){ this.jdbc=jdbc; }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public Long startRun(String profile, String fetcher, String acker, String reason){
        return jdbc.queryForObject("""
            insert into claims.ingestion_run(profile, fetcher_name, acker_name, poll_reason, started_at)
            values (?,?,?,?, now())
            returning id
        """, Long.class, profile, fetcher, acker, reason);
    }
    public void endRun(long runId){ jdbc.update("update claims.ingestion_run set ended_at=now() where id=?", runId); }

    public void fileOk(long runId, long ingestionFileId, boolean verified, int parsedClaims, int persistedClaims, int parsedActs, int persistedActs){
        jdbc.update("""
      insert into claims.ingestion_file_audit(ingestion_run_id, ingestion_file_id, status, reason, validation_ok,
        header_sender_id, header_receiver_id, header_transaction_date, header_record_count, header_disposition_flag,
        parsed_claims, persisted_claims, parsed_activities, persisted_activities, verification_passed, created_at)
      select ?, id, 1, 'OK', true, sender_id, receiver_id, transaction_date, record_count_declared, disposition_flag,
             ?, ?, ?, ?, ?, now()
      from claims.ingestion_file where id=?
    """, runId, parsedClaims, persistedClaims, parsedActs, persistedActs, verified, ingestionFileId);
        jdbc.update("update claims.ingestion_run set files_processed_ok = files_processed_ok + 1 where id=?", runId);
    }

    /**
     * Enhanced fileOk method that populates ALL existing columns in the table.
     * This fixes the issue where many existing columns were not being populated.
     */
    public void fileOkComplete(long runId, long ingestionFileId, boolean verified, 
                              int parsedClaims, int persistedClaims, int parsedActs, int persistedActs,
                              int parsedEncounters, int persistedEncounters,
                              int parsedDiagnoses, int persistedDiagnoses,
                              int parsedObservations, int persistedObservations,
                              int parsedRemitClaims, int persistedRemitClaims,
                              int parsedRemitActivities, int persistedRemitActivities,
                              int projectedEvents, int projectedStatusRows,
                              int verificationFailedCount, boolean ackAttempted, boolean ackSent) {
        jdbc.update("""
            insert into claims.ingestion_file_audit(
                ingestion_run_id, ingestion_file_id, status, reason, validation_ok,
                header_sender_id, header_receiver_id, header_transaction_date, header_record_count, header_disposition_flag,
                parsed_claims, persisted_claims, parsed_activities, persisted_activities,
                parsed_encounters, persisted_encounters, parsed_diagnoses, persisted_diagnoses,
                parsed_observations, persisted_observations, 
                parsed_remit_claims, parsed_remit_activities, persisted_remit_claims, persisted_remit_activities,
                projected_events, projected_status_rows,
                verification_passed, verification_failed_count, ack_attempted, ack_sent,
                created_at)
            select ?, id, 1, 'OK', true,
                   sender_id, receiver_id, transaction_date, record_count_declared, disposition_flag,
                   ?, ?, ?, ?,
                   ?, ?, ?, ?,
                   ?, ?, 
                   ?, ?, ?, ?,
                   ?, ?,
                   ?, ?, ?, ?, ?,
                   now()
            from claims.ingestion_file where id=?
        """, runId, parsedClaims, persistedClaims, parsedActs, persistedActs,
             parsedEncounters, persistedEncounters, parsedDiagnoses, persistedDiagnoses,
             parsedObservations, persistedObservations,
             parsedRemitClaims, parsedRemitActivities, persistedRemitClaims, persistedRemitActivities,
             projectedEvents, projectedStatusRows,
             verified, verificationFailedCount, ackAttempted, ackSent,
             ingestionFileId);
        jdbc.update("update claims.ingestion_run set files_processed_ok = files_processed_ok + 1 where id=?", runId);
    }

    /**
     * Enhanced fileOk method with complete audit data including timing, file metrics, and business data.
     * This method populates all the new fields we added to strengthen the audit table.
     */
    public void fileOkEnhanced(long runId, long ingestionFileId, boolean verified, 
                              int parsedClaims, int persistedClaims, int parsedActs, int persistedActs,
                              int parsedEncounters, int persistedEncounters,
                              int parsedDiagnoses, int persistedDiagnoses,
                              int parsedObservations, int persistedObservations,
                              int parsedRemitClaims, int persistedRemitClaims,
                              int parsedRemitActivities, int persistedRemitActivities,
                              int projectedEvents, int projectedStatusRows,
                              long processingDurationMs, long fileSizeBytes,
                              String processingMode, String workerThread,
                              java.math.BigDecimal totalGross, java.math.BigDecimal totalNet, 
                              java.math.BigDecimal totalPatientShare,
                              int uniquePayers, int uniqueProviders,
                              boolean ackAttempted, boolean ackSent,
                              boolean pipelineSuccess,
                              int verificationFailedCount) {
        jdbc.update("""
            insert into claims.ingestion_file_audit(
                ingestion_run_id, ingestion_file_id, status, reason, validation_ok,
                header_sender_id, header_receiver_id, header_transaction_date, header_record_count, header_disposition_flag,
                parsed_claims, persisted_claims, parsed_activities, persisted_activities,
                parsed_encounters, persisted_encounters, parsed_diagnoses, persisted_diagnoses,
                parsed_observations, persisted_observations, 
                parsed_remit_claims, parsed_remit_activities, persisted_remit_claims, persisted_remit_activities,
                projected_events, projected_status_rows,
                verification_passed, verification_failed_count, ack_attempted, ack_sent, pipeline_success,
                processing_duration_ms, file_size_bytes, processing_mode, worker_thread_name,
                total_gross_amount, total_net_amount, total_patient_share, unique_payers, unique_providers,
                created_at)
            select ?, id, 1, 'OK', true,
                   sender_id, receiver_id, transaction_date, record_count_declared, disposition_flag,
                   ?, ?, ?, ?,
                   ?, ?, ?, ?,
                   ?, ?, 
                   ?, ?, ?, ?,
                   ?, ?,
                   ?, ?, ?, ?, ?,
                   ?, ?, ?, ?,
                   ?, ?, ?, ?, ?,
                   now()
            from claims.ingestion_file where id=?
        """, runId, parsedClaims, persistedClaims, parsedActs, persistedActs,
             parsedEncounters, persistedEncounters, parsedDiagnoses, persistedDiagnoses,
             parsedObservations, persistedObservations,
             parsedRemitClaims, parsedRemitActivities, persistedRemitClaims, persistedRemitActivities,
             projectedEvents, projectedStatusRows,
             verified, verificationFailedCount, ackAttempted, ackSent, pipelineSuccess,
             processingDurationMs, fileSizeBytes, processingMode, workerThread,
             totalGross, totalNet, totalPatientShare, uniquePayers, uniqueProviders,
             ingestionFileId);
        jdbc.update("update claims.ingestion_run set files_processed_ok = files_processed_ok + 1 where id=?", runId);
    }

    public void fileAlready(long runId, long ingestionFileId){
        jdbc.update("""
      insert into claims.ingestion_file_audit(
        ingestion_run_id, ingestion_file_id, status, reason, validation_ok,
        header_sender_id, header_receiver_id, header_transaction_date, header_record_count, header_disposition_flag,
        created_at)
      select ?, id, 0, 'ALREADY', true,
             sender_id, receiver_id, transaction_date, record_count_declared, disposition_flag,
             now()
      from claims.ingestion_file where id=?
    """, runId, ingestionFileId);
        jdbc.update("update claims.ingestion_run set files_already = files_already + 1 where id=?", runId);
    }

    public void fileFail(long runId, long ingestionFileId, String errorClass, String message){
        jdbc.update("""
      insert into claims.ingestion_file_audit(ingestion_run_id, ingestion_file_id, status, reason, error_class, error_message, created_at)
      values (?,?,2,'FAIL',?,?,now())
    """, runId, ingestionFileId, errorClass, message);
        jdbc.update("update claims.ingestion_run set files_failed = files_failed + 1 where id=?", runId);
    }

    /*
     * ======================================================================
     * RETRY TRACKING - DISABLED (not used currently)
     * ----------------------------------------------------------------------
     * These methods were intended for enhanced failure auditing and retry
     * tracking. Since retry tracking is not needed now and corresponding
     * columns are not present in the DDL, these methods are commented out
     * to avoid accidental use and compile-time drift.
     *
     * If retry tracking is reintroduced in the future, restore these methods
     * along with appropriate DDL changes.
     * ======================================================================
     */
    // public void fileFailEnhanced(long runId, long ingestionFileId, String errorClass, String message,
    //                             long processingDurationMs, long fileSizeBytes,
    //                             String processingMode, String workerThread,
    //                             int retryCount, String[] retryReasons, String[] retryErrorCodes,
    //                             java.time.OffsetDateTime firstAttemptAt, java.time.OffsetDateTime lastAttemptAt) {
    //     jdbc.update("""
    //         insert into claims.ingestion_file_audit(
    //             ingestion_run_id, ingestion_file_id, status, reason, error_class, error_message,
    //             duration_ms, file_size_bytes, processing_mode, worker_thread,
    //             retry_count, retry_reasons, retry_error_codes, first_attempt_at, last_attempt_at,
    //             created_at)
    //         values (?,?,2,'FAIL',?,?,
    //                 ?,?,?,?,
    //                 ?,?,?,?,?,
    //                 now())
    //     """, runId, ingestionFileId, errorClass, message,
    //          processingDurationMs, fileSizeBytes, processingMode, workerThread,
    //          retryCount, retryReasons, retryErrorCodes, firstAttemptAt, lastAttemptAt);
    //     jdbc.update("update claims.ingestion_run set files_failed = files_failed + 1 where id=?", runId);
    // }

    // /**
    //  * Track a retry attempt for a file that previously failed.
    //  * This method updates the retry count and tracks retry reasons.
    //  */
    // public void trackRetryAttempt(long ingestionFileId, String retryReason, String errorCode) {
    //     jdbc.update("""
    //         UPDATE claims.ingestion_file_audit 
    //         SET retry_count = retry_count + 1,
    //             retry_reasons = array_append(COALESCE(retry_reasons, ARRAY[]::text[]), ?),
    //             retry_error_codes = array_append(COALESCE(retry_error_codes, ARRAY[]::text[]), ?),
    //             last_attempt_at = now()
    //         WHERE ingestion_file_id = ? 
    //           AND status = 2 -- FAIL
    //           AND id = (SELECT max(id) FROM claims.ingestion_file_audit WHERE ingestion_file_id = ?)
    //     """, retryReason, errorCode, ingestionFileId, ingestionFileId);
    // }

    // ========== SAFE METHODS WITH ERROR HANDLING ==========
    
    /**
     * Helper method to verify ingestion run exists with retry logic.
     * Handles transaction visibility delays by retrying with exponential backoff.
     * Returns true if run exists, false otherwise.
     * 
     * <p>This method addresses PostgreSQL transaction isolation where a newly committed
     * runId may not be immediately visible in a different transaction/connection.
     * Increased delays (100ms, 200ms, 500ms) accommodate connection pool routing
     * and transaction visibility windows.</p>
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW, readOnly = true)
    private boolean verifyRunExists(Long runId, int maxRetries) {
        if (runId == null) return false;
        
        // Increased delays to handle transaction visibility windows
        // PostgreSQL + Spring may need 100-200ms for visibility across connections
        int[] delays = {0, 100, 200, 500}; // milliseconds: immediate, then retries with delays
        int retries = Math.min(maxRetries, delays.length - 1);
        
        for (int attempt = 0; attempt <= retries; attempt++) {
            try {
                if (attempt > 0) {
                    Thread.sleep(delays[attempt]);
                }
                
                // Use COUNT query - more reliable than SELECT with empty results
                // COUNT always returns a number (0 or 1), avoiding empty result set issues
                Integer count = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM claims.ingestion_run WHERE id = ?",
                    Integer.class,
                    runId);
                
                if (count != null && count > 0) {
                    if (attempt > 0) {
                        log.debug("Verified run {} exists on attempt {} (after {}ms delay)", 
                            runId, attempt + 1, delays[attempt]);
                    }
                    return true; // Run exists
                }
                
                // If count is 0 and this is the last attempt, return false
                if (attempt == retries) {
                    log.warn("Ingestion run {} not found after {} retries (delays: {})", 
                        runId, retries + 1, java.util.Arrays.toString(delays));
                    return false;
                }
                
            } catch (InterruptedException ie) {
                Thread.currentThread().interrupt();
                log.warn("Interrupted while verifying run existence: runId={}", runId);
                return false;
            } catch (Exception e) {
                // On transient errors, retry
                if (attempt < retries) {
                    log.debug("Run verification failed on attempt {}: {}, retrying...", 
                        attempt + 1, e.getMessage());
                    continue;
                }
                // On last attempt, log and return false
                log.warn("Run verification failed after {} attempts: runId={}, error={}", 
                    retries + 1, runId, e.getMessage());
                return false;
            }
        }
        
        return false;
    }
    
    /**
     * Safely start an ingestion run with error handling.
     * Returns null if operation fails, ensuring ingestion continues.
     */
    public Long startRunSafely(String profile, String fetcher, String acker, String reason) {
        try {
            return startRun(profile, fetcher, acker, reason);
        } catch (Exception e) {
            log.error("Failed to start ingestion run: profile={}, fetcher={}, acker={}, reason={}", 
                profile, fetcher, acker, reason, e);
            return null;
        }
    }
    
    /**
     * Safely end an ingestion run with error handling.
     * Returns false if operation fails, but doesn't throw exceptions.
     */
    public boolean endRunSafely(Long runId) {
        if (runId == null) return false;
        try {
            endRun(runId);
            return true;
        } catch (Exception e) {
            log.error("Failed to end ingestion run: runId={}", runId, e);
            return false;
        }
    }
    
    /**
     * Safely record file processing success with error handling.
     * Returns false if operation fails, but doesn't throw exceptions.
     */
    public boolean fileOkSafely(Long runId, Long ingestionFileId, boolean verified, 
                               int parsedClaims, int persistedClaims, 
                               int parsedActs, int persistedActs) {
        if (runId == null || ingestionFileId == null) return false;
        try {
            fileOk(runId, ingestionFileId, verified, parsedClaims, persistedClaims, 
                   parsedActs, persistedActs);
            return true;
        } catch (Exception e) {
            log.error("Failed to audit file success: runId={}, fileId={}", 
                runId, ingestionFileId, e);
            return false;
        }
    }
    
    /**
     * Safely record file processing failure with error handling.
     * Returns false if operation fails, but doesn't throw exceptions.
     */
    public boolean fileFailSafely(Long runId, Long ingestionFileId, String errorClass, String message) {
        if (runId == null || ingestionFileId == null) return false;
        
        // Defensive validation: verify runId exists before attempting insert
        // If verification fails, still attempt insert and catch FK violation as fallback
        boolean verified = verifyRunExists(runId, 3);
        if (!verified) {
            log.debug("Run {} verification failed, attempting insert anyway (will catch FK violation if needed)", runId);
        }
        
        try {
            fileFail(runId, ingestionFileId, errorClass, message);
            return true;
        } catch (DataIntegrityViolationException e) {
            // FK violation means runId doesn't exist - log and return false
            log.warn("FK violation while auditing file failure {}: runId={} does not exist: {}", 
                ingestionFileId, runId, e.getMessage());
            return false;
        } catch (Exception e) {
            log.error("Failed to audit file failure: runId={}, fileId={}", 
                runId, ingestionFileId, e);
            return false;
        }
    }
    
    /**
     * Safely record file already processed with error handling.
     * Returns false if operation fails, but doesn't throw exceptions.
     */
    public boolean fileAlreadySafely(Long runId, Long ingestionFileId) {
        if (runId == null || ingestionFileId == null) return false;
        
        // Defensive validation: verify runId exists before attempting insert
        // If verification fails, still attempt insert and catch FK violation as fallback
        boolean verified = verifyRunExists(runId, 3);
        if (!verified) {
            log.debug("Run {} verification failed, attempting insert anyway (will catch FK violation if needed)", runId);
        }
        
        try {
            fileAlready(runId, ingestionFileId);
            return true;
        } catch (DataIntegrityViolationException e) {
            // FK violation means runId doesn't exist - log and return false
            log.warn("FK violation while auditing file already {}: runId={} does not exist: {}", 
                ingestionFileId, runId, e.getMessage());
            return false;
        } catch (Exception e) {
            log.error("Failed to audit file already processed: runId={}, fileId={}", 
                runId, ingestionFileId, e);
            return false;
        }
    }

    /**
     * Safely record complete file processing success with error handling.
     * This method populates ALL existing columns in the table.
     * Returns false if operation fails, but doesn't throw exceptions.
     */
    public boolean fileOkCompleteSafely(Long runId, Long ingestionFileId, boolean verified, 
                                       int parsedClaims, int persistedClaims, int parsedActs, int persistedActs,
                                       int parsedEncounters, int persistedEncounters,
                                       int parsedDiagnoses, int persistedDiagnoses,
                                       int parsedObservations, int persistedObservations,
                                       int parsedRemitClaims, int persistedRemitClaims,
                                       int parsedRemitActivities, int persistedRemitActivities,
                                       int projectedEvents, int projectedStatusRows,
                                       int verificationFailedCount, boolean ackAttempted, boolean ackSent) {
        if (runId == null || ingestionFileId == null) return false;
        
        // Defensive validation: verify runId exists before attempting insert
        // If verification fails, still attempt insert and catch FK violation as fallback
        boolean verifiedRun = verifyRunExists(runId, 3);
        if (!verifiedRun) {
            log.debug("Run {} verification failed, attempting insert anyway (will catch FK violation if needed)", runId);
        }
        
        try {
            fileOkComplete(runId, ingestionFileId, verified, parsedClaims, persistedClaims, parsedActs, persistedActs,
                          parsedEncounters, persistedEncounters, parsedDiagnoses, persistedDiagnoses,
                          parsedObservations, persistedObservations,
                          parsedRemitClaims, persistedRemitClaims, parsedRemitActivities, persistedRemitActivities,
                          projectedEvents, projectedStatusRows,
                          verificationFailedCount, ackAttempted, ackSent);
            return true;
        } catch (DataIntegrityViolationException e) {
            // FK violation means runId doesn't exist - log and return false
            log.warn("FK violation while auditing file complete {}: runId={} does not exist: {}", 
                ingestionFileId, runId, e.getMessage());
            return false;
        } catch (Exception e) {
            log.error("Failed to audit complete file success: runId={}, fileId={}", 
                runId, ingestionFileId, e);
            return false;
        }
    }

    /**
     * Safely record enhanced file processing success with error handling.
     * Returns false if operation fails, but doesn't throw exceptions.
     */
    public boolean fileOkEnhancedSafely(Long runId, Long ingestionFileId, boolean verified, 
                                       int parsedClaims, int persistedClaims, int parsedActs, int persistedActs,
                                       int parsedEncounters, int persistedEncounters,
                                       int parsedDiagnoses, int persistedDiagnoses,
                                       int parsedObservations, int persistedObservations,
                                       int parsedRemitClaims, int persistedRemitClaims,
                                       int parsedRemitActivities, int persistedRemitActivities,
                                       int projectedEvents, int projectedStatusRows,
                                       long processingDurationMs, long fileSizeBytes,
                                       String processingMode, String workerThread,
                                       java.math.BigDecimal totalGross, java.math.BigDecimal totalNet, 
                                       java.math.BigDecimal totalPatientShare,
                                       int uniquePayers, int uniqueProviders,
                                       boolean ackAttempted, boolean ackSent,
                                       boolean pipelineSuccess,
                                       int verificationFailedCount) {
        if (runId == null || ingestionFileId == null) return false;
        
        // Defensive validation: verify runId exists before attempting insert
        // If verification fails, still attempt insert and catch FK violation as fallback
        // This handles transaction visibility delays more gracefully
        boolean verifiedRun = verifyRunExists(runId, 3);
        if (!verifiedRun) {
            log.debug("Run {} verification failed, attempting insert anyway (will catch FK violation if needed). " +
                    "Possible causes: transaction visibility delay, run was deleted, or stale runId in context.", 
                runId);
        }
        
        try {
            fileOkEnhanced(runId, ingestionFileId, verified, parsedClaims, persistedClaims, parsedActs, persistedActs,
                          parsedEncounters, persistedEncounters, parsedDiagnoses, persistedDiagnoses,
                          parsedObservations, persistedObservations,
                          parsedRemitClaims, persistedRemitClaims, parsedRemitActivities, persistedRemitActivities,
                          projectedEvents, projectedStatusRows,
                          processingDurationMs, fileSizeBytes, processingMode, workerThread,
                          totalGross, totalNet, totalPatientShare, uniquePayers, uniqueProviders,
                          ackAttempted, ackSent, pipelineSuccess, verificationFailedCount);
            return true;
        } catch (DataIntegrityViolationException e) {
            // FK violation means runId doesn't exist - log and return false
            log.warn("FK violation while auditing file enhanced {}: runId={} does not exist: {}", 
                ingestionFileId, runId, e.getMessage());
            return false;
        } catch (Exception e) {
            log.error("Failed to audit enhanced file success: runId={}, fileId={}", 
                runId, ingestionFileId, e);
            return false;
        }
    }

    /**
     * Safely update ack_sent status in ingestion_file_audit after ack attempt.
     * Returns false if operation fails, but doesn't throw exceptions.
     */
    public boolean updateAckSentSafely(Long runId, Long ingestionFileId, boolean ackSent) {
        if (runId == null || ingestionFileId == null) return false;
        
        // Defensive validation: verify runId exists before attempting update
        // If verification fails, still attempt update (UPDATE won't fail on FK violation, just affects 0 rows)
        boolean verifiedRun = verifyRunExists(runId, 3);
        if (!verifiedRun) {
            log.debug("Run {} verification failed, attempting update anyway (will silently affect 0 rows if run doesn't exist)", runId);
        }
        
        try {
            int rowsUpdated = jdbc.update("""
                update claims.ingestion_file_audit
                set ack_sent = ?
                where ingestion_run_id = ? and ingestion_file_id = ?
                """, ackSent, runId, ingestionFileId);
            
            if (rowsUpdated == 0 && !verifiedRun) {
                log.debug("Update ack_sent affected 0 rows for runId={}, fileId={} (run may not exist)", 
                    runId, ingestionFileId);
            }
            return true;
        } catch (Exception e) {
            log.error("Failed to update ack_sent in audit: runId={}, fileId={}, ackSent={}", 
                runId, ingestionFileId, ackSent, e);
            return false;
        }
    }

    // /**
    //  * Safely record enhanced file processing failure with error handling.
    //  * Returns false if operation fails, but doesn't throw exceptions.
    //  */
    // public boolean fileFailEnhancedSafely(Long runId, Long ingestionFileId, String errorClass, String message,
    //                                      long processingDurationMs, long fileSizeBytes,
    //                                      String processingMode, String workerThread,
    //                                      int retryCount, String[] retryReasons, String[] retryErrorCodes,
    //                                      java.time.OffsetDateTime firstAttemptAt, java.time.OffsetDateTime lastAttemptAt) {
    //     if (runId == null || ingestionFileId == null) return false;
    //     try {
    //         fileFailEnhanced(runId, ingestionFileId, errorClass, message,
    //                        processingDurationMs, fileSizeBytes, processingMode, workerThread,
    //                        retryCount, retryReasons, retryErrorCodes, firstAttemptAt, lastAttemptAt);
    //         return true;
    //     } catch (Exception e) {
    //         log.error("Failed to audit enhanced file failure: runId={}, fileId={}", 
    //             runId, ingestionFileId, e);
    //         return false;
    //     }
    // }

    // /**
    //  * Safely track retry attempt with error handling.
    //  * Returns false if operation fails, but doesn't throw exceptions.
    //  */
    // public boolean trackRetryAttemptSafely(Long ingestionFileId, String retryReason, String errorCode) {
    //     if (ingestionFileId == null) return false;
    //     try {
    //         trackRetryAttempt(ingestionFileId, retryReason, errorCode);
    //         return true;
    //     } catch (Exception e) {
    //         log.error("Failed to track retry attempt: fileId={}, reason={}", 
    //             ingestionFileId, retryReason, e);
    //         return false;
    //     }
    // }
}
