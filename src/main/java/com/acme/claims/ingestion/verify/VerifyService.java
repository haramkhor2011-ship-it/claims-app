package com.acme.claims.ingestion.verify;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class VerifyService {

    private static final Logger log = LoggerFactory.getLogger(VerifyService.class);

    private final JdbcTemplate jdbc;
    private final Map<String, Long> ruleIdCache = new ConcurrentHashMap<>();

    public VerifyService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record VerificationOutcome(Long verificationRunId, boolean passed, int failedRuleCount) {}

    private enum Status { PASS, WARN, FAIL, SKIP }

    private record CheckOutcome(Status status, String message, Long rowsAffected) {
        static CheckOutcome pass() { return new CheckOutcome(Status.PASS, null, null); }
        static CheckOutcome warn(String message, Long rowsAffected) { return new CheckOutcome(Status.WARN, message, rowsAffected); }
        static CheckOutcome fail(String message, Long rowsAffected) { return new CheckOutcome(Status.FAIL, message, rowsAffected); }
        static CheckOutcome skip(String message) { return new CheckOutcome(Status.SKIP, message, null); }

        boolean isFailure() { return status == Status.FAIL; }
        boolean isWarning() { return status == Status.WARN; }
        boolean isSkip() { return status == Status.SKIP; }
    }

    private record RuleSpec(String code, String description, int severity, String sqlText) {}

    private static final RuleSpec RULE_CLAIM_EVENTS = new RuleSpec(
        "CLAIM_EVENTS_PRESENT",
        "Claim events exist for the ingested file",
        3,
        "Managed by VerifyService.CLAIM_EVENTS_PRESENT");

    private static final RuleSpec RULE_COUNT_MATCH = new RuleSpec(
        "COUNT_MATCH",
        "Parsed and persisted entity counts match",
        3,
        "Managed by VerifyService.COUNT_MATCH");

    private static final RuleSpec RULE_REFERENTIAL = new RuleSpec(
        "REFERENTIAL_INTEGRITY",
        "No orphan records were created",
        3,
        "Managed by VerifyService.REFERENTIAL_INTEGRITY");

    private static final RuleSpec RULE_DATA_QUALITY = new RuleSpec(
        "DATA_QUALITY",
        "Data quality checks (duplicates, timelines)",
        2,
        "Managed by VerifyService.DATA_QUALITY");

    private static final RuleSpec RULE_BUSINESS = new RuleSpec(
        "BUSINESS_SEQUENCE",
        "Business rule checks for submission/resubmission sequence",
        2,
        "Managed by VerifyService.BUSINESS_SEQUENCE");

    private static final RuleSpec RULE_EXCEPTION = new RuleSpec(
        "UNEXPECTED_EXCEPTION",
        "Unexpected verification exception",
        3,
        "Managed by VerifyService.UNEXPECTED_EXCEPTION");

    /**
     * Comprehensive verification that checks data integrity after ingestion and persists
     * verification run metadata/results in the database.
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public VerificationOutcome verifyFile(long ingestionFileId, String xmlFileId, Integer expectedClaims, Integer expectedActivities) {
        Long verificationRunId = createVerificationRun(ingestionFileId);
        List<String> failureMessages = new ArrayList<>();
        List<String> warningMessages = new ArrayList<>();
        int failedRules = 0;

        log.info("VERIFY_START: ingestionFileId={} xmlFileId={} runId={} expectedClaims={} expectedActs={}",
            ingestionFileId, xmlFileId, verificationRunId, expectedClaims, expectedActivities);

        try {
            // Allow persistence transactions from pipeline to complete
            try {
                Thread.sleep(100L);
            } catch (InterruptedException ie) {
                Thread.currentThread().interrupt();
                log.warn("VERIFY_INTERRUPTED: ingestionFileId={} runId={}", ingestionFileId, verificationRunId);
                CheckOutcome interrupted = CheckOutcome.fail("Verification interrupted before checks completed", null);
                collectMessages(RULE_EXCEPTION, interrupted, failureMessages, warningMessages);
                recordRuleOutcome(verificationRunId, RULE_EXCEPTION, interrupted);
                completeVerificationRun(verificationRunId, false, 1);
                return new VerificationOutcome(verificationRunId, false, 1);
            }

            CheckOutcome claimEvents = verifyClaimEventsExist(ingestionFileId);
            if (claimEvents.isFailure()) {
                failedRules++;
            }
            collectMessages(RULE_CLAIM_EVENTS, claimEvents, failureMessages, warningMessages);
            recordRuleOutcome(verificationRunId, RULE_CLAIM_EVENTS, claimEvents);

            CheckOutcome countMatch = verifyCountsMatch(ingestionFileId, expectedClaims, expectedActivities);
            if (countMatch.isFailure()) {
                failedRules++;
            }
            collectMessages(RULE_COUNT_MATCH, countMatch, failureMessages, warningMessages);
            recordRuleOutcome(verificationRunId, RULE_COUNT_MATCH, countMatch);

            CheckOutcome referential = verifyReferentialIntegrity(ingestionFileId);
            if (referential.isFailure()) {
                failedRules++;
            }
            collectMessages(RULE_REFERENTIAL, referential, failureMessages, warningMessages);
            recordRuleOutcome(verificationRunId, RULE_REFERENTIAL, referential);

            CheckOutcome dataQuality = verifyDataQuality(ingestionFileId);
            if (dataQuality.isFailure()) {
                failedRules++;
            }
            collectMessages(RULE_DATA_QUALITY, dataQuality, failureMessages, warningMessages);
            recordRuleOutcome(verificationRunId, RULE_DATA_QUALITY, dataQuality);

            CheckOutcome business = verifyBusinessRules(ingestionFileId);
            if (business.isFailure()) {
                failedRules++;
            }
            collectMessages(RULE_BUSINESS, business, failureMessages, warningMessages);
            recordRuleOutcome(verificationRunId, RULE_BUSINESS, business);

            boolean passed = failedRules == 0;
            if (!failureMessages.isEmpty()) {
                log.warn("VERIFY_FAIL: ingestionFileId={} xmlFileId={} runId={} failures={}",
                    ingestionFileId, xmlFileId, verificationRunId, String.join("; ", failureMessages));
            } else if (!warningMessages.isEmpty()) {
                log.warn("VERIFY_WARN: ingestionFileId={} xmlFileId={} runId={} warnings={}",
                    ingestionFileId, xmlFileId, verificationRunId, String.join("; ", warningMessages));
            } else {
                log.info("VERIFY_PASS: ingestionFileId={} xmlFileId={} runId={}",
                    ingestionFileId, xmlFileId, verificationRunId);
            }

            completeVerificationRun(verificationRunId, passed, failedRules);
            return new VerificationOutcome(verificationRunId, passed, failedRules);
        } catch (Exception ex) {
            log.error("VERIFY_EXCEPTION: ingestionFileId={} runId={} error={}", ingestionFileId, verificationRunId, ex.getMessage(), ex);
            CheckOutcome exceptionOutcome = CheckOutcome.fail(ex.getMessage(), null);
            recordRuleOutcome(verificationRunId, RULE_EXCEPTION, exceptionOutcome);
            collectMessages(RULE_EXCEPTION, exceptionOutcome, failureMessages, warningMessages);
            failedRules = Math.max(1, failedRules + 1);
            completeVerificationRun(verificationRunId, false, failedRules);
            return new VerificationOutcome(verificationRunId, false, failedRules);
        }
    }

    private void collectMessages(RuleSpec rule, CheckOutcome outcome, List<String> failures, List<String> warnings) {
        if (outcome.status() == Status.PASS) {
            return;
        }
        StringBuilder builder = new StringBuilder(rule.description());
        if (outcome.message() != null && !outcome.message().isBlank()) {
            builder.append(": ").append(outcome.message());
        }
        String formatted = builder.toString();
        if (outcome.isFailure()) {
            failures.add(formatted);
        } else {
            warnings.add(formatted);
        }
    }

    private Long createVerificationRun(Long ingestionFileId) {
        if (ingestionFileId == null) {
            return null;
        }
        try {
            return jdbc.queryForObject(
                "INSERT INTO claims.verification_run (ingestion_file_id, started_at) VALUES (?, now()) RETURNING id",
                Long.class,
                ingestionFileId);
        } catch (Exception e) {
            log.warn("Failed to create verification run for ingestionFileId {}: {}", ingestionFileId, e.getMessage());
            return null;
        }
    }

    private void completeVerificationRun(Long verificationRunId, boolean passed, int failedRules) {
        if (verificationRunId == null) {
            return;
        }
        try {
            jdbc.update(
                "UPDATE claims.verification_run SET ended_at = now(), passed = ?, failed_rules = ? WHERE id = ?",
                passed,
                failedRules,
                verificationRunId);
        } catch (Exception e) {
            log.warn("Failed to finalize verification run {}: {}", verificationRunId, e.getMessage());
        }
    }

    private void recordRuleOutcome(Long verificationRunId, RuleSpec rule, CheckOutcome outcome) {
        if (verificationRunId == null) {
            return;
        }
        try {
            long ruleId = resolveRuleId(rule);
            jdbc.update(
                "INSERT INTO claims.verification_result (verification_run_id, rule_id, ok, rows_affected, sample_json, message) " +
                "VALUES (?, ?, ?, ?, NULL, ?)",
                verificationRunId,
                ruleId,
                outcome.status() != Status.FAIL,
                outcome.rowsAffected(),
                outcome.message());
        } catch (Exception e) {
            log.warn("Failed to record verification result for rule {} runId {}: {}", rule.code(), verificationRunId, e.getMessage());
        }
    }

    private long resolveRuleId(RuleSpec rule) {
        return ruleIdCache.computeIfAbsent(rule.code(), code -> {
            try {
                return jdbc.queryForObject(
                    "SELECT id FROM claims.verification_rule WHERE code = ?",
                    Long.class,
                    code);
            } catch (EmptyResultDataAccessException ex) {
                return insertRule(rule);
            }
        });
    }

    private long insertRule(RuleSpec rule) {
        try {
            return jdbc.queryForObject(
                "INSERT INTO claims.verification_rule (code, description, severity, sql_text) VALUES (?, ?, ?, ?) RETURNING id",
                Long.class,
                rule.code(),
                rule.description(),
                rule.severity(),
                rule.sqlText());
        } catch (DuplicateKeyException dup) {
            return jdbc.queryForObject(
                "SELECT id FROM claims.verification_rule WHERE code = ?",
                Long.class,
                rule.code());
        }
    }

    private CheckOutcome verifyClaimEventsExist(long ingestionFileId) {
        Integer fileExists = jdbc.queryForObject(
            "SELECT COUNT(*) FROM claims.ingestion_file WHERE id = ?",
            Integer.class,
            ingestionFileId);

        if (fileExists == null || fileExists == 0) {
            return CheckOutcome.fail("Ingestion file not found in database", 0L);
        }

        Integer directCount = jdbc.queryForObject(
            "SELECT COUNT(*) FROM claims.claim_event ce " +
            "JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id " +
            "JOIN claims.submission s ON c.submission_id = s.id " +
            "WHERE s.ingestion_file_id = ?",
            Integer.class,
            ingestionFileId);

        int direct = directCount != null ? directCount : 0;
        if (direct > 0) {
            return CheckOutcome.pass();
        }

        Integer reusedCount = jdbc.queryForObject(
            "SELECT COUNT(*) FROM claims.claim_event ce " +
            "JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id " +
            "JOIN claims.submission s ON c.submission_id = s.id " +
            "WHERE s.ingestion_file_id = ? AND ce.ingestion_file_id = ?",
            Integer.class,
            ingestionFileId,
            ingestionFileId);

        int reused = reusedCount != null ? reusedCount : 0;
        if (reused > 0) {
            return CheckOutcome.warn(String.format("Claim events reused from previous file (count=%d)", reused), (long) reused);
        }

        return CheckOutcome.fail("No claim_event rows found for file (checked both direct and reused events)", 0L);
    }

    private CheckOutcome verifyCountsMatch(long ingestionFileId, Integer expectedClaims, Integer expectedActs) {
        if (expectedClaims == null || expectedActs == null) {
            return CheckOutcome.skip("Expected counts not provided; skipping count verification");
        }

        Integer actualClaimsValue = jdbc.queryForObject(
            "SELECT COUNT(DISTINCT ce.claim_key_id) FROM claims.claim_event ce " +
            "JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id " +
            "JOIN claims.submission s ON c.submission_id = s.id " +
            "WHERE s.ingestion_file_id = ?",
            Integer.class,
            ingestionFileId);

        int actualClaims = actualClaimsValue != null ? actualClaimsValue : 0;
        if (actualClaims < expectedClaims) {
            return CheckOutcome.fail(String.format("Claim count mismatch: expected=%d, actual=%d", expectedClaims, actualClaims), (long) actualClaims);
        }

        Integer actualActsValue = jdbc.queryForObject(
            "SELECT COUNT(*) FROM claims.claim_event_activity cea " +
            "JOIN claims.claim_event ce ON cea.claim_event_id = ce.id " +
            "JOIN claims.claim c ON ce.claim_key_id = c.claim_key_id " +
            "JOIN claims.submission s ON c.submission_id = s.id " +
            "WHERE s.ingestion_file_id = ?",
            Integer.class,
            ingestionFileId);

        int actualActs = actualActsValue != null ? actualActsValue : 0;
        if (actualActs < expectedActs) {
            return CheckOutcome.fail(String.format("Activity count mismatch: expected=%d, actual=%d", expectedActs, actualActs), (long) actualActs);
        }

        return CheckOutcome.pass();
    }

    private CheckOutcome verifyReferentialIntegrity(long ingestionFileId) {
        List<String> issues = new ArrayList<>();
        long totalIssues = 0L;

        Integer orphanActs = jdbc.queryForObject(
            "SELECT COUNT(*) FROM claims.activity a LEFT JOIN claims.claim c ON a.claim_id = c.id WHERE c.id IS NULL",
            Integer.class);
        if (orphanActs != null && orphanActs > 0) {
            issues.add(String.format("Found %d orphan activities (no parent claim)", orphanActs));
            totalIssues += orphanActs;
        }

        Integer orphanCEA = jdbc.queryForObject(
            "SELECT COUNT(*) FROM claims.claim_event_activity cea LEFT JOIN claims.claim_event ce ON cea.claim_event_id = ce.id WHERE ce.id IS NULL",
            Integer.class);
        if (orphanCEA != null && orphanCEA > 0) {
            issues.add(String.format("Found %d orphan claim_event_activity rows", orphanCEA));
            totalIssues += orphanCEA;
        }

        Integer orphanObs = jdbc.queryForObject(
            "SELECT COUNT(*) FROM claims.event_observation eo LEFT JOIN claims.claim_event_activity cea ON eo.claim_event_activity_id = cea.id WHERE cea.id IS NULL",
            Integer.class);
        if (orphanObs != null && orphanObs > 0) {
            issues.add(String.format("Found %d orphan event_observation rows", orphanObs));
            totalIssues += orphanObs;
        }

        if (!issues.isEmpty()) {
            return CheckOutcome.fail(String.join("; ", issues), totalIssues);
        }
        return CheckOutcome.pass();
    }

    private CheckOutcome verifyDataQuality(long ingestionFileId) {
        List<String> warnings = new ArrayList<>();

        Integer dupesValue = jdbc.queryForObject(
            "SELECT COUNT(*) FROM (SELECT claim_id, COUNT(*) FROM claims.claim_key GROUP BY claim_id HAVING COUNT(*) > 1) dupes",
            Integer.class);
        int dupes = dupesValue != null ? dupesValue : 0;
        if (dupes > 0) {
            warnings.add(String.format("Found %d duplicate claim_key records", dupes));
        }

        Integer missingStatusValue = jdbc.queryForObject(
            "SELECT COUNT(DISTINCT ce.claim_key_id) FROM claims.claim_event ce " +
            "LEFT JOIN claims.claim_status_timeline cst ON ce.claim_key_id = cst.claim_key_id " +
            "WHERE ce.ingestion_file_id = ? AND cst.id IS NULL",
            Integer.class,
            ingestionFileId);

        int missingStatus = missingStatusValue != null ? missingStatusValue : 0;
        if (missingStatus > 0) {
            if (!warnings.isEmpty()) {
                warnings.add(String.format("Found %d claims without status timeline", missingStatus));
                return CheckOutcome.fail(String.join("; ", warnings), (long) missingStatus);
            }
            return CheckOutcome.fail(String.format("Found %d claims without status timeline", missingStatus), (long) missingStatus);
        }

        if (!warnings.isEmpty()) {
            return CheckOutcome.warn(String.join("; ", warnings), (long) dupes);
        }

        return CheckOutcome.pass();
    }

    private CheckOutcome verifyBusinessRules(long ingestionFileId) {
        Integer invalidResubValue = jdbc.queryForObject(
            "SELECT COUNT(*) FROM claims.claim_event ce1 " +
            "WHERE ce1.type = 2 AND ce1.ingestion_file_id = ? " +
            "AND NOT EXISTS (SELECT 1 FROM claims.claim_event ce2 WHERE ce2.claim_key_id = ce1.claim_key_id AND ce2.type = 1)",
            Integer.class,
            ingestionFileId);

        int invalidResub = invalidResubValue != null ? invalidResubValue : 0;
        if (invalidResub > 0) {
            return CheckOutcome.warn(String.format("Found %d resubmission events without initial submission", invalidResub), (long) invalidResub);
        }

        return CheckOutcome.pass();
    }
}