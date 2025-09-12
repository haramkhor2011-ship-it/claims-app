package com.acme.claims.ingestion.audit;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class IngestionAudit {
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
}
