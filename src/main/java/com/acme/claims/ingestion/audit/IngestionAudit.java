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

    public void fileAlready(long runId, long ingestionFileId){
        jdbc.update("""
      insert into claims.ingestion_file_audit(ingestion_run_id, ingestion_file_id, status, reason, validation_ok, created_at)
      values (?,?,0,'ALREADY',true,now())
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
}
