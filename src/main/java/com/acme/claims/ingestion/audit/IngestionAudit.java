package com.acme.claims.ingestion.audit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class IngestionAudit {
    private static final Logger log = LoggerFactory.getLogger(IngestionAudit.class);
    private final JdbcTemplate jdbc;
    
    public IngestionAudit(JdbcTemplate jdbc){ this.jdbc=jdbc; }

    public long startRun(String profile, String fetcher, String acker, String reason){
        jdbc.update("""
      insert into claims.ingestion_run(profile, fetcher_name, acker_name, poll_reason, started_at)
      values (?,?,?,?, now())
    """, profile, fetcher, acker, reason);
        return jdbc.queryForObject("select max(id) from claims.ingestion_run", Long.class);
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
                              int projectedEvents, int projectedStatusRows,
                              int verificationFailedCount, boolean ackAttempted, boolean ackSent) {
        jdbc.update("""
            insert into claims.ingestion_file_audit(
                ingestion_run_id, ingestion_file_id, status, reason, validation_ok,
                header_sender_id, header_receiver_id, header_transaction_date, header_record_count, header_disposition_flag,
                parsed_claims, persisted_claims, parsed_activities, persisted_activities,
                parsed_encounters, persisted_encounters, parsed_diagnoses, persisted_diagnoses,
                parsed_observations, persisted_observations, projected_events, projected_status_rows,
                verification_passed, verification_failed_count, ack_attempted, ack_sent,
                created_at)
            select ?, id, 1, 'OK', true,
                   sender_id, receiver_id, transaction_date, record_count_declared, disposition_flag,
                   ?, ?, ?, ?,
                   ?, ?, ?, ?,
                   ?, ?, ?, ?,
                   ?, ?, ?, ?,
                   now()
            from claims.ingestion_file where id=?
        """, runId, parsedClaims, persistedClaims, parsedActs, persistedActs,
             parsedEncounters, persistedEncounters, parsedDiagnoses, persistedDiagnoses,
             parsedObservations, persistedObservations, projectedEvents, projectedStatusRows,
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
                              int projectedEvents, int projectedStatusRows,
                              long processingDurationMs, long fileSizeBytes,
                              String processingMode, String workerThread,
                              java.math.BigDecimal totalGross, java.math.BigDecimal totalNet, 
                              java.math.BigDecimal totalPatientShare,
                              int uniquePayers, int uniqueProviders,
                              boolean ackAttempted, boolean ackSent,
                              int verificationFailedCount) {
        jdbc.update("""
            insert into claims.ingestion_file_audit(
                ingestion_run_id, ingestion_file_id, status, reason, validation_ok,
                header_sender_id, header_receiver_id, header_transaction_date, header_record_count, header_disposition_flag,
                parsed_claims, persisted_claims, parsed_activities, persisted_activities,
                parsed_encounters, persisted_encounters, parsed_diagnoses, persisted_diagnoses,
                parsed_observations, persisted_observations, projected_events, projected_status_rows,
                verification_passed, verification_failed_count, ack_attempted, ack_sent,
                processing_duration_ms, file_size_bytes, processing_mode, worker_thread_name,
                total_gross_amount, total_net_amount, total_patient_share, unique_payers, unique_providers,
                created_at)
            select ?, id, 1, 'OK', true,
                   sender_id, receiver_id, transaction_date, record_count_declared, disposition_flag,
                   ?, ?, ?, ?,
                   ?, ?, ?, ?,
                   ?, ?, ?, ?,
                   ?, ?, ?, ?,
                   ?, ?, ?, ?,
                   ?, ?, ?, ?, ?,
                   now()
            from claims.ingestion_file where id=?
        """, runId, parsedClaims, persistedClaims, parsedActs, persistedActs,
             parsedEncounters, persistedEncounters, parsedDiagnoses, persistedDiagnoses,
             parsedObservations, persistedObservations, projectedEvents, projectedStatusRows,
             verified, verificationFailedCount, ackAttempted, ackSent,
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

    /**
     * Enhanced fileFail method with retry tracking and detailed error information.
     */
    public void fileFailEnhanced(long runId, long ingestionFileId, String errorClass, String message,
                                long processingDurationMs, long fileSizeBytes,
                                String processingMode, String workerThread,
                                int retryCount, String[] retryReasons, String[] retryErrorCodes,
                                java.time.OffsetDateTime firstAttemptAt, java.time.OffsetDateTime lastAttemptAt) {
        jdbc.update("""
            insert into claims.ingestion_file_audit(
                ingestion_run_id, ingestion_file_id, status, reason, error_class, error_message,
                processing_duration_ms, file_size_bytes, processing_mode, worker_thread_name,
                retry_count, retry_reasons, retry_error_codes, first_attempt_at, last_attempt_at,
                created_at)
            values (?,?,2,'FAIL',?,?,
                    ?,?,?,?,
                    ?,?,?,?,?,
                    now())
        """, runId, ingestionFileId, errorClass, message,
             processingDurationMs, fileSizeBytes, processingMode, workerThread,
             retryCount, retryReasons, retryErrorCodes, firstAttemptAt, lastAttemptAt);
        jdbc.update("update claims.ingestion_run set files_failed = files_failed + 1 where id=?", runId);
    }

    /**
     * Track a retry attempt for a file that previously failed.
     * This method updates the retry count and tracks retry reasons.
     */
    public void trackRetryAttempt(long ingestionFileId, String retryReason, String errorCode) {
        jdbc.update("""
            UPDATE claims.ingestion_file_audit 
            SET retry_count = retry_count + 1,
                retry_reasons = array_append(COALESCE(retry_reasons, ARRAY[]::text[]), ?),
                retry_error_codes = array_append(COALESCE(retry_error_codes, ARRAY[]::text[]), ?),
                last_attempt_at = now()
            WHERE ingestion_file_id = ? 
              AND status = 2 -- FAIL
              AND id = (SELECT max(id) FROM claims.ingestion_file_audit WHERE ingestion_file_id = ?)
        """, retryReason, errorCode, ingestionFileId, ingestionFileId);
    }

    // ========== SAFE METHODS WITH ERROR HANDLING ==========
    
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
        try {
            fileFail(runId, ingestionFileId, errorClass, message);
            return true;
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
        try {
            fileAlready(runId, ingestionFileId);
            return true;
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
                                       int projectedEvents, int projectedStatusRows,
                                       int verificationFailedCount, boolean ackAttempted, boolean ackSent) {
        if (runId == null || ingestionFileId == null) return false;
        try {
            fileOkComplete(runId, ingestionFileId, verified, parsedClaims, persistedClaims, parsedActs, persistedActs,
                          parsedEncounters, persistedEncounters, parsedDiagnoses, persistedDiagnoses,
                          parsedObservations, persistedObservations, projectedEvents, projectedStatusRows,
                          verificationFailedCount, ackAttempted, ackSent);
            return true;
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
                                       int projectedEvents, int projectedStatusRows,
                                       long processingDurationMs, long fileSizeBytes,
                                       String processingMode, String workerThread,
                                       java.math.BigDecimal totalGross, java.math.BigDecimal totalNet, 
                                       java.math.BigDecimal totalPatientShare,
                                       int uniquePayers, int uniqueProviders,
                                       boolean ackAttempted, boolean ackSent,
                                       int verificationFailedCount) {
        if (runId == null || ingestionFileId == null) return false;
        try {
            fileOkEnhanced(runId, ingestionFileId, verified, parsedClaims, persistedClaims, parsedActs, persistedActs,
                          parsedEncounters, persistedEncounters, parsedDiagnoses, persistedDiagnoses,
                          parsedObservations, persistedObservations, projectedEvents, projectedStatusRows,
                          processingDurationMs, fileSizeBytes, processingMode, workerThread,
                          totalGross, totalNet, totalPatientShare, uniquePayers, uniqueProviders,
                          ackAttempted, ackSent, verificationFailedCount);
            return true;
        } catch (Exception e) {
            log.error("Failed to audit enhanced file success: runId={}, fileId={}", 
                runId, ingestionFileId, e);
            return false;
        }
    }

    /**
     * Safely record enhanced file processing failure with error handling.
     * Returns false if operation fails, but doesn't throw exceptions.
     */
    public boolean fileFailEnhancedSafely(Long runId, Long ingestionFileId, String errorClass, String message,
                                         long processingDurationMs, long fileSizeBytes,
                                         String processingMode, String workerThread,
                                         int retryCount, String[] retryReasons, String[] retryErrorCodes,
                                         java.time.OffsetDateTime firstAttemptAt, java.time.OffsetDateTime lastAttemptAt) {
        if (runId == null || ingestionFileId == null) return false;
        try {
            fileFailEnhanced(runId, ingestionFileId, errorClass, message,
                           processingDurationMs, fileSizeBytes, processingMode, workerThread,
                           retryCount, retryReasons, retryErrorCodes, firstAttemptAt, lastAttemptAt);
            return true;
        } catch (Exception e) {
            log.error("Failed to audit enhanced file failure: runId={}, fileId={}", 
                runId, ingestionFileId, e);
            return false;
        }
    }

    /**
     * Safely track retry attempt with error handling.
     * Returns false if operation fails, but doesn't throw exceptions.
     */
    public boolean trackRetryAttemptSafely(Long ingestionFileId, String retryReason, String errorCode) {
        if (ingestionFileId == null) return false;
        try {
            trackRetryAttempt(ingestionFileId, retryReason, errorCode);
            return true;
        } catch (Exception e) {
            log.error("Failed to track retry attempt: fileId={}, reason={}", 
                ingestionFileId, retryReason, e);
            return false;
        }
    }
}
