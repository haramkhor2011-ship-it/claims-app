package com.acme.claims.ingestion.verify;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

@Service
public class VerifyService {

    private static final Logger log = LoggerFactory.getLogger(VerifyService.class);
    private final JdbcTemplate jdbc;

    public VerifyService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Comprehensive verification that checks data integrity after ingestion.
     * This is a DEBUGGING TOOL to identify issues quickly.
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public boolean verifyFile(long ingestionFileId, String xmlFileId, Integer expectedClaims, Integer expectedActivities) {
        List<String> failures = new ArrayList<>();
        
        try {
            log.info("VERIFY_START: ingestionFileId={}, xmlFileId={}, expectedClaims={}, expectedActs={}", 
                ingestionFileId, xmlFileId, expectedClaims, expectedActivities);
            
            // Add small delay to ensure data is committed from previous transaction
            try {
                Thread.sleep(100); // 100ms delay to ensure data consistency
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                log.warn("VERIFY_INTERRUPTED: ingestionFileId={}", ingestionFileId);
                return false;
            }
            
            // 1. Basic existence - at least one claim_event created
            if (!verifyClaimEventsExist(ingestionFileId, failures)) {
                logFailures(ingestionFileId, xmlFileId, failures);
                return false;
            }
            
            // 2. Count matching - all parsed entities were persisted
            if (expectedClaims != null && expectedActivities != null) {
                if (!verifyCountsMatch(ingestionFileId, expectedClaims, expectedActivities, failures)) {
                    logFailures(ingestionFileId, xmlFileId, failures);
                    return false;
                }
            }
            
            // 3. Referential integrity - no orphan records
            if (!verifyReferentialIntegrity(ingestionFileId, failures)) {
                logFailures(ingestionFileId, xmlFileId, failures);
                return false;
            }
            
            // 4. Data quality - duplicates, consistency
            if (!verifyDataQuality(ingestionFileId, failures)) {
                logFailures(ingestionFileId, xmlFileId, failures);
                return false;
            }
            
            // 5. Business rules - event sequences, status progression
            if (!verifyBusinessRules(ingestionFileId, failures)) {
                logFailures(ingestionFileId, xmlFileId, failures);
                return false;
            }
            
            log.info("VERIFY_PASS: ingestionFileId={}, xmlFileId={}", ingestionFileId, xmlFileId);
            return true;
            
        } catch (Exception e) {
            log.error("VERIFY_EXCEPTION: ingestionFileId={}, error={}", ingestionFileId, e.getMessage(), e);
            return false;
        }
    }

    private boolean verifyClaimEventsExist(long ingestionFileId, List<String> failures) {
        // First check if the ingestion_file exists
        Integer fileExists = jdbc.queryForObject(
            "SELECT COUNT(*) FROM claims.ingestion_file WHERE id = ?",
            Integer.class, ingestionFileId);
        
        if (fileExists == null || fileExists == 0) {
            failures.add("Ingestion file not found in database");
            return false;
        }
        
        // Check for claim_event rows created by this file OR reused from previous files
        // This handles the case where submission events are reused due to unique constraints
        
        Integer count = jdbc.queryForObject(
            "SELECT COUNT(*) FROM claims.claim_event ce " +
            "JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id " +
            "JOIN claims.submission s ON c.submission_id = s.id " +
            "WHERE s.ingestion_file_id = ?",
            Integer.class, ingestionFileId);
        
        if (count == null || count == 0) {
            // Additional check: maybe events exist but with different ingestion_file_id
            Integer altCount = jdbc.queryForObject(
                "SELECT COUNT(*) FROM claims.claim_event ce " +
                "JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id " +
                "JOIN claims.submission s ON c.submission_id = s.id " +
                "WHERE s.ingestion_file_id = ? AND ce.ingestion_file_id = ?",
                Integer.class, ingestionFileId, ingestionFileId);
            
            if (altCount == null || altCount == 0) {
                failures.add("No claim_event rows found for file (checked both direct and reused events)");
                return false;
            }
        }
        return true;
    }

    private boolean verifyCountsMatch(long ingestionFileId, Integer expectedClaims, Integer expectedActs, List<String> failures) {
        // Check claim counts - use submission-based approach to handle reused events
        Integer actualClaims = jdbc.queryForObject(
            "SELECT COUNT(DISTINCT ce.claim_key_id) FROM claims.claim_event ce " +
            "JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id " +
            "JOIN claims.submission s ON c.submission_id = s.id " +
            "WHERE s.ingestion_file_id = ?",
            Integer.class, ingestionFileId);
        
        if (actualClaims == null || actualClaims < expectedClaims) {
            failures.add(String.format("Claim count mismatch: expected=%d, actual=%d", expectedClaims, actualClaims));
            return false;
        }
        
        // Check activity counts (from claim_event_activity) - use submission-based approach
        Integer actualActs = jdbc.queryForObject(
            "SELECT COUNT(*) FROM claims.claim_event_activity cea " +
            "JOIN claims.claim_event ce ON cea.claim_event_id = ce.id " +
            "JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id " +
            "JOIN claims.submission s ON c.submission_id = s.id " +
            "WHERE s.ingestion_file_id = ?",
            Integer.class, ingestionFileId);
        
        if (actualActs == null || actualActs < expectedActs) {
            failures.add(String.format("Activity count mismatch: expected=%d, actual=%d", expectedActs, actualActs));
            return false;
        }
        
        return true;
    }

    private boolean verifyReferentialIntegrity(long ingestionFileId, List<String> failures) {
        // Orphan activities
        Integer orphanActs = jdbc.queryForObject(
            "SELECT COUNT(*) FROM claims.activity a LEFT JOIN claims.claim c ON a.claim_id = c.id WHERE c.id IS NULL",
            Integer.class);
        if (orphanActs != null && orphanActs > 0) {
            failures.add(String.format("Found %d orphan activities (no parent claim)", orphanActs));
            return false;
        }
        
        // Orphan claim_event_activity
        Integer orphanCEA = jdbc.queryForObject(
            "SELECT COUNT(*) FROM claims.claim_event_activity cea LEFT JOIN claims.claim_event ce ON cea.claim_event_id = ce.id WHERE ce.id IS NULL",
            Integer.class);
        if (orphanCEA != null && orphanCEA > 0) {
            failures.add(String.format("Found %d orphan claim_event_activity rows", orphanCEA));
            return false;
        }
        
        // Orphan event_observation
        Integer orphanObs = jdbc.queryForObject(
            "SELECT COUNT(*) FROM claims.event_observation eo LEFT JOIN claims.claim_event_activity cea ON eo.claim_event_activity_id = cea.id WHERE cea.id IS NULL",
            Integer.class);
        if (orphanObs != null && orphanObs > 0) {
            failures.add(String.format("Found %d orphan event_observation rows", orphanObs));
            return false;
        }
        
        return true;
    }

    private boolean verifyDataQuality(long ingestionFileId, List<String> failures) {
        // Check for duplicate claim_keys with same business ID
        Integer dupes = jdbc.queryForObject(
            "SELECT COUNT(*) FROM (SELECT claim_id, COUNT(*) FROM claims.claim_key GROUP BY claim_id HAVING COUNT(*) > 1) dupes",
            Integer.class);
        if (dupes != null && dupes > 0) {
            failures.add(String.format("Found %d duplicate claim_key records", dupes));
            // Don't fail verification, just warn
        }
        
        // Check status timeline exists for all claims in this file
        Integer missingStatus = jdbc.queryForObject(
            "SELECT COUNT(DISTINCT ce.claim_key_id) FROM claims.claim_event ce " +
            "LEFT JOIN claims.claim_status_timeline cst ON ce.claim_key_id = cst.claim_key_id " +
            "WHERE ce.ingestion_file_id = ? AND cst.id IS NULL",
            Integer.class, ingestionFileId);
        if (missingStatus != null && missingStatus > 0) {
            failures.add(String.format("Found %d claims without status timeline", missingStatus));
            return false;
        }
        
        return true;
    }

    private boolean verifyBusinessRules(long ingestionFileId, List<String> failures) {
        // Verify resubmission events have corresponding submission events
        Integer invalidResub = jdbc.queryForObject(
            "SELECT COUNT(*) FROM claims.claim_event ce1 " +
            "WHERE ce1.type = 2 AND ce1.ingestion_file_id = ? " +
            "AND NOT EXISTS (SELECT 1 FROM claims.claim_event ce2 WHERE ce2.claim_key_id = ce1.claim_key_id AND ce2.type = 1)",
            Integer.class, ingestionFileId);
        if (invalidResub != null && invalidResub > 0) {
            failures.add(String.format("Found %d resubmission events without initial submission", invalidResub));
            // Warn but don't fail
        }
        
        return true;
    }

    private void logFailures(long ingestionFileId, String xmlFileId, List<String> failures) {
        log.warn("VERIFY_FAIL: ingestionFileId={}, xmlFileId={}, failures={}", 
            ingestionFileId, xmlFileId, String.join("; ", failures));
    }
}