/*
 * SSOT NOTICE — Error Logger
 * Purpose: Persist structured errors with reliable object scoping and IDs.
 * Policy: Claim-level errors MUST include `claim_id`; file-level errors include `file_id`.
 */
package com.acme.claims.ingestion.audit;


import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;


@Service
public class ErrorLogger {

    private final JdbcTemplate jdbc;

    public ErrorLogger(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Log a claim-scoped error; claimId is required (use "UNKNOWN_CLAIM" only as a last resort). */ // inline doc
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void claimError(Long ingestionFileId, String stage, String claimId, String code, String message, boolean retryable) {
        String objectKey = (claimId == null || claimId.isBlank()) ? "UNKNOWN_CLAIM" : claimId;
        jdbc.update("""
      insert into claims.ingestion_error(ingestion_file_id, stage, object_type, object_key, error_code, error_message, retryable, occurred_at)
      values (?,?,?,?,?,?,?, now())
    """, ingestionFileId, stage, "CLAIM", objectKey, code, message, retryable);
    }

    /** Log a file-scoped error; object_key carries "FILE:<ingestionFileId>" marker. */ // inline doc
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void fileError(Long ingestionFileId, String stage, String code, String message, boolean retryable) {
        jdbc.update("""
      insert into claims.ingestion_error(ingestion_file_id, stage, object_type, object_key, error_code, error_message, retryable, occurred_at)
      values (?,?,?,?,?,?,?, now())
    """, ingestionFileId, stage, "FILE", "FILE:" + ingestionFileId, code, message, retryable);
    }
}
