/*
 * SSOT NOTICE — Verify Service
 * Purpose: Lightweight, fast, per-file SQL integrity checks after ingestion completes.
 * Checks:
 *   1) At least one claim_event exists for this ingestion_file_id (projection happened).
 *   2) No orphans:
 *        - activity rows must have a parent claim
 *        - claim_event_activity rows must have a parent claim_event
 *        - event_observation rows must have a parent claim_event_activity
 *   3) Optional uniqueness spot-checks can be added if needed.
 * Returns: true if all checks pass; false otherwise (or throws on SQL errors).
 */
package com.acme.claims.ingestion.verify;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class VerifyService {

    private static final Logger log = LoggerFactory.getLogger(VerifyService.class);
    private final JdbcTemplate jdbc;

    public VerifyService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Run post-file verification; keep it quick and side-effect free. */
    public boolean verifyFile(long ingestionFileId, String xmlFileId) {
        try {
            // 1) Ensure at least one claim_event was projected for this file
            Integer ev = jdbc.queryForObject(
                    "select count(*) from claims.claim_event where ingestion_file_id = ?",
                    Integer.class, ingestionFileId);
            if (ev == null || ev <= 0) {
                log.warn("Verify: no claim_event rows for ingestion_file_id={}, fileId: {}", ingestionFileId, xmlFileId);
                return false;
            }

            // 2a) Orphan activities (activity.claim_id must exist in claim)
            Integer orphansAct = jdbc.queryForObject("""
          select count(*) from claims.activity a
          left join claims.claim c on c.id = a.claim_id
          where c.id is null
        """, Integer.class);
            if (orphansAct != null && orphansAct > 0) {
                log.warn("Verify: {} orphan activity rows (no parent claim) for ingestion_file_id={}", orphansAct, ingestionFileId);
                return false;
            }

            // 2b) Orphan claim_event_activity (must have parent claim_event)
            Integer orphansCEA = jdbc.queryForObject("""
          select count(*) from claims.claim_event_activity cea
          left join claims.claim_event ce on ce.id = cea.claim_event_id
          where ce.id is null
        """, Integer.class);
            if (orphansCEA != null && orphansCEA > 0) {
                log.warn("Verify: {} orphan claim_event_activity rows (no parent event) for ingestion_file_id={}", orphansCEA, ingestionFileId);
                return false;
            }

            // 2c) Orphan event_observation (must have parent claim_event_activity)
            Integer orphansEO = jdbc.queryForObject("""
          select count(*) from claims.event_observation eo
          left join claims.claim_event_activity cea on cea.id = eo.claim_event_activity_id
          where cea.id is null
        """, Integer.class);
            if (orphansEO != null && orphansEO > 0) {
                log.warn("Verify: {} orphan event_observation rows (no parent cea) for ingestion_file_id={}", orphansEO, ingestionFileId);
                return false;
            }

            // All checks passed
            return true;
        } catch (Exception e) {
            log.error("Verify exception for ingestion_file_id={}: {}", ingestionFileId, e.getMessage(), e);
            return false;
        }
    }
}
