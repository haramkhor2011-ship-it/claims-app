/*
 * SSOT NOTICE — Ingestion Pipeline (FINAL)
 * Flow: Fetcher → Parser (StageParser) → Validate → Persist → Events/Timeline → Verify → Audit → (optional ACK)
 * Key decisions:
 *  - We INSERT a stub ingestion_file BEFORE parsing to provide a real FK id; placeholders are 'UNKNOWN'.
 *  - We perform a HEADER PRECHECK before any UPDATE so ingestion_file never gets nulls (keeps 'UNKNOWN').
 *  - We then run full business validation (validateSubmission/validateRemittance) before persistence.
 *  - Robust stage-to-disk archiving (best-effort).
 */
package com.acme.claims.ingestion;

import com.acme.claims.domain.model.dto.RemittanceAdviceDTO;
import com.acme.claims.domain.model.dto.SubmissionDTO;
import com.acme.claims.domain.model.entity.IngestionFile;
import com.acme.claims.ingestion.audit.ErrorLogger;
import com.acme.claims.ingestion.audit.IngestionAudit;
import com.acme.claims.ingestion.audit.RunContext;
import com.acme.claims.ingestion.config.IngestionProperties;
import com.acme.claims.ingestion.fetch.WorkItem;
import com.acme.claims.ingestion.parser.ParseOutcome;
import com.acme.claims.ingestion.parser.StageParser;
import com.acme.claims.ingestion.persist.PersistService;
import com.acme.claims.ingestion.util.RootDetector;
import com.acme.claims.metrics.DhpoMetrics;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;
import java.nio.file.Files;
import java.time.OffsetDateTime;
import java.util.Objects;

/**
 * <h1>Purpose</h1>
 * Core ingestion pipeline that orchestrates the complete flow from XML parsing through database persistence,
 * verification, and audit. This is the main processing engine for both claim submissions and remittance advice.
 * 
 * <h2>Responsibilities</h2>
 * <ul>
 *   <li>Parse XML files into DTOs using StAX parsing</li>
 *   <li>Validate business rules and data integrity</li>
 *   <li>Persist data to database with proper transaction management</li>
 *   <li>Project events for claim lifecycle tracking</li>
 *   <li>Verify data integrity after persistence</li>
 *   <li>Record audit information and metrics</li>
 *   <li>Handle file staging and cleanup</li>
 * </ul>
 * 
 * <h2>Dependencies</h2>
 * <ul>
 *   <li>{@link StageParser} - XML parsing and DTO conversion</li>
 *   <li>{@link PersistService} - Database persistence with transaction management</li>
 *   <li>{@link VerifyService} - Post-persistence data integrity verification</li>
 *   <li>{@link IngestionAudit} - Audit trail recording</li>
 *   <li>{@link ErrorLogger} - Error logging and categorization</li>
 *   <li>{@link DhpoMetrics} - Performance metrics collection</li>
 *   <li>{@link IngestionProperties} - Configuration and tuning parameters</li>
 * </ul>
 * 
 * <h2>Used By</h2>
 * <ul>
 *   <li>{@link Orchestrator} - Main coordination engine that calls this pipeline</li>
 *   <li>{@link AdminController} - Manual processing operations</li>
 *   <li>{@link MonitoringService} - Health checks and metrics</li>
 * </ul>
 * 
 * <h2>Key Decisions</h2>
 * <ul>
 *   <li>Uses REQUIRES_NEW transactions to ensure critical operations always commit</li>
 *   <li>Implements idempotency through database unique constraints</li>
 *   <li>Performs header pre-check before any update to avoid nulls overwriting placeholders</li>
 *   <li>Uses stub insertion pattern to provide real FK IDs for downstream operations</li>
 *   <li>Implements comprehensive error handling with detailed logging</li>
 * </ul>
 * 
 * <h2>Configuration</h2>
 * <ul>
 *   <li>{@code claims.ingestion.batchSize} - Controls batch processing size</li>
 *   <li>{@code claims.ingestion.timeout} - Processing timeout duration</li>
 *   <li>{@code claims.ingestion.staging.enabled} - Enables file staging</li>
 * </ul>
 * 
 * <h2>Thread Safety</h2>
 * This class is thread-safe. All dependencies are Spring-managed singletons,
 * and there is no shared mutable state. Concurrent access is protected by
 * database unique constraints and transaction boundaries.
 * 
 * <h2>Performance Characteristics</h2>
 * <ul>
 *   <li>Processes files in configurable batches for optimal throughput</li>
 *   <li>Uses streaming XML parsing to minimize memory usage</li>
 *   <li>Implements transaction boundaries to prevent long-running transactions</li>
 *   <li>Records comprehensive metrics for performance monitoring</li>
 * </ul>
 * 
 * <h2>Error Handling</h2>
 * <ul>
 *   <li>Parse errors - Logged to ingestion_error table, processing continues</li>
 *   <li>Validation errors - File rejected, error logged</li>
 *   <li>Database errors - Transaction rollback, error logged</li>
 *   <li>System errors - Comprehensive error logging and recovery</li>
 * </ul>
 * 
 * <h2>Example Usage</h2>
 * <pre>{@code
 * // Process a single work item
 * WorkItem item = new WorkItem("file123", "submission.xml", "SOAP", xmlBytes, null);
 * Result result = pipeline.process(item);
 * 
 * // Check processing results
 * if (result.parsedClaims() > 0) {
 *     log.info("Processed {} claims", result.parsedClaims());
 * }
 * }</pre>
 * 
 * <h2>Common Issues</h2>
 * <ul>
 *   <li>OutOfMemoryError - Increase JVM heap size or reduce batch size</li>
 *   <li>Transaction timeout - Increase transaction timeout or reduce batch size</li>
 *   <li>Duplicate key violations - Check for duplicate file processing</li>
 *   <li>Validation failures - Check XML format and business rules</li>
 * </ul>
 * 
 * @see Orchestrator
 * @see StageParser
 * @see PersistService
 * @see VerifyService
 * @see IngestionAudit
 * @see ErrorLogger
 * @see DhpoMetrics
 * @since 1.0
 * @author Claims Team
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class Pipeline {

    private static final short ROOT_SUBMISSION = 1;
    private static final short ROOT_REMITTANCE = 2;

    private final IngestionProperties props;
    private final StageParser parser;           // ClaimXmlParserStax implements this
    private final PersistService persist;
    private final ErrorLogger errors;
    private final IngestionAudit audit;
    private final JdbcTemplate jdbc;
    private final DhpoMetrics dhpoMetrics;
    @Autowired
    @Lazy
    private Pipeline self;

    public record Result(
            long ingestionFileId,
            int rootType, // 1=submission, 2=remittance
            // Submission counts
            int parsedClaims, int persistedClaims,
            int parsedActivities, int persistedActivities,
            int parsedDiagnoses, int persistedDiagnoses,
            int parsedEncounters, int persistedEncounters,
            int parsedObservations, int persistedObservations,
            // Remittance counts
            int parsedRemitClaims, int persistedRemitClaims,
            int parsedRemitActivities, int persistedRemitActivities,
            // Event projection counts (for debugging)
            int projectedEvents, int projectedStatusRows,
            OffsetDateTime txTime
    ) {}

    /** Process a single item end-to-end. Safe for retry; idempotency = DB uniques downstream. */
    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    public Result process(WorkItem wi) {
        Long filePk = null;
        long t0 = System.nanoTime();
        boolean success = false;

        // Handle disk-based files where xmlBytes might be null
        byte[] xmlBytes = wi.xmlBytes();
        if (xmlBytes == null && wi.sourcePath() != null) {
            try {
                xmlBytes = Files.readAllBytes(wi.sourcePath());
                log.info("Loaded XML from disk: fileId={} fileName={} size={}",
                    wi.fileId(), wi.fileName(), xmlBytes.length);
            } catch (IOException e) {
                log.error("Failed to read XML from disk: fileId={} fileName={} path={} error={}",
                    wi.fileId(), wi.fileName(), wi.sourcePath(), e.getMessage());
                throw new RuntimeException("Failed to read XML file from disk", e);
            }
        }

        log.info("PIPELINE_START fileId={} fileName={} source={} size={}",
            wi.fileId(), wi.fileName(), wi.source(), xmlBytes.length);
        try {
            // 1) Root sniff (cheap) so stub row has a valid root_type (1 or 2)
            RootDetector.RootKind sniffed = RootDetector.detect(xmlBytes);
            short rootType = switch (sniffed) { case SUBMISSION -> ROOT_SUBMISSION; case REMITTANCE -> ROOT_REMITTANCE; };
            log.info("sniffed root type: {}", rootType);
            // 2) INSERT stub ingestion_file with safe placeholders
            filePk = self.insertStub(wi, rootType, xmlBytes);
            // Early duplicate short-circuit for disk-staged files — if events already exist, treat as success
            if (wi.sourcePath() != null && alreadyProjected(filePk)) {
                if (log.isDebugEnabled()) {
                    log.debug("disk-staged file already processed (short-circuit): {}", wi.fileId());
                }
                // Audit: mark as already processed under current run (if available)
                try {
                    Long runId = RunContext.getCurrentRunId();
                    if (runId != null) {
                        audit.fileAlreadySafely(runId, filePk);
                    }
                } catch (Exception ignore) {}
                success = true;
                return new Result(filePk.longValue(), rootType == ROOT_SUBMISSION ? 1 : 2, 
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, OffsetDateTime.now());
            }
            IngestionFile fileRow = new IngestionFile();
            fileRow.setId(filePk);
            fileRow.setFileId(wi.fileId());
            fileRow.setXmlBytes(xmlBytes);
            fileRow.setFileName(wi.fileName());
            // 3) Parse (XSD → StAX). Parser writes parse errors using ingestion_file_id=filePk
            log.info("going to parse our ingestion file : {}", filePk);
            ParseOutcome out = parser.parse(fileRow);
            log.info("PIPELINE_PARSE_COMPLETE fileId={} fileName={} ingestionFileId={} rootType={} claims={} activities={}", 
                wi.fileId(), wi.fileName(), filePk, out.getRootType(), 
                out.getSubmission() != null ? out.getSubmission().claims().size() : 0,
                out.getSubmission() != null ? countActs(out.getSubmission()) : (out.getRemittance() != null ? countActs(out.getRemittance()) : 0));

            // 4) Branch by actual root (authoritative)
            switch (out.getRootType()) {
                case SUBMISSION -> {
                    SubmissionDTO dto = out.getSubmission();

                    // PATCH: HEADER PRECHECK (before any UPDATE) — avoid nulls overwriting placeholders.
                    if (dto == null || dto.header() == null
                            || isBlank(dto.header().senderId())
                            || isBlank(dto.header().receiverId())
                            || dto.header().transactionDate() == null
                            || isBlank(dto.header().dispositionFlag())
                            || dto.claims() == null
                            || dto.header().recordCount() <= 0
                            /*|| dto.header().recordCount() != (dto.claims() == null ? 0 : dto.claims().size())*/) {
                                log.error("PIPELINE_VALIDATION_FAILED fileId={} fileName={} ingestionFileId={} reason=HEADER_PRECHECK", 
                                wi.fileId(), wi.fileName(), filePk);
                        errors.fileError(filePk, "VALIDATE", "MISSING_HEADER_FIELDS",
                                "Header required fields missing; file rejected.", false);
                        throw new RuntimeException("Header validation failed (submission) for fileId=" + wi.fileId());
                    }
                    log.info("PIPELINE_VALIDATION_SUCCESS fileId={} fileName={} ingestionFileId={} senderId={} receiverId={} recordCount={}", 
        wi.fileId(), wi.fileName(), filePk, dto.header().senderId(), 
        dto.header().receiverId(), dto.header().recordCount());

                    // Only now update ingestion_file header (COALESCE keeps existing 'UNKNOWN' if any null leaks)
                    self.updateIngestionFileHeader(
                            filePk, ROOT_SUBMISSION,
                            dto.header().senderId(), dto.header().receiverId(),
                            dto.header().transactionDate(), dto.header().recordCount(), dto.header().dispositionFlag()
                    );
                    log.info("Updated Ingestion File Header data : {}", fileRow.getFileId());

                    // Idempotency short-circuit early (skip validation/mapping/persist)
                    if (alreadyProjected(filePk)) {
                        log.info("file already processed (short-circuit): {}", fileRow.getFileId());
                        // Audit: mark as already processed under current run (if available)
                        try {
                            Long runId = RunContext.getCurrentRunId();
                            if (runId != null) {
                                audit.fileAlreadySafely(runId, filePk);
                            }
                        } catch (Exception ignore) {}
                        success = true;
                        int claimCount = dto.claims().size();
                        int actCount = countActs(dto);
                        return new Result(filePk, 1, 
                            claimCount, 0, 
                            actCount, 0,
                            0, 0, // no submission diagnoses
                            0, 0, // no encounters  
                            0, 0, // no observations
                            0, 0, // no remit counts
                            0, 0, // no remit activities
                            0, 0, // no events for already processed
                            dto.header().transactionDate());
                    }

                    // Full business validation
                    try {
                        validateSubmission(dto);
                        log.info("Validation Success for file id : {}", fileRow.getFileId());
                    }
                    catch (IllegalArgumentException vex) {
                        errors.fileError(filePk, "VALIDATE", "SUBMISSION_RULES", vex.getMessage(), false);
                        throw vex;
                    }

                    // 5) Persist graph + events/timeline
                    var counts = persist.persistSubmission(filePk, dto, out.getAttachments());
                    log.info("submission persisted");
                    success =true;
                    int claimCount = dto.claims().size();
                    int actCount = countActs(dto);
                    return new Result(filePk, 1, 
                        claimCount, counts.claims(), 
                        actCount, counts.acts(),
                        countDiagnoses(dto), counts.dxs(),
                        countEncounters(dto), counts.encounters(),
                        countObservations(dto), counts.obs(),
                        0, 0, // no remit counts
                        0, 0, // no remit activities
                        counts.projectedEvents(), counts.projectedStatusRows(),
                        dto.header().transactionDate());
                }

                case REMITTANCE -> {
                    RemittanceAdviceDTO dto = out.getRemittance();

                    // PATCH: HEADER PRECHECK (remittance)
                    if (dto == null || dto.header() == null
                            || isBlank(dto.header().senderId())
                            || isBlank(dto.header().receiverId())
                            || dto.header().transactionDate() == null
                            || isBlank(dto.header().dispositionFlag())
                            || dto.claims() == null
                            || dto.header().recordCount() <= 0
                            || dto.header().recordCount() != (dto.claims() == null ? 0 : dto.claims().size())) {
                        errors.fileError(filePk, "VALIDATE", "MISSING_HEADER_FIELDS",
                                "Header required fields missing or RecordCount mismatch; file rejected.", false);
                        throw new RuntimeException("Header validation failed (remittance) for fileId=" + wi.fileId());
                    }

                    // Update header now (COALESCE-safe)
                    self.updateIngestionFileHeader(
                            filePk, ROOT_REMITTANCE,
                            dto.header().senderId(), dto.header().receiverId(),
                            dto.header().transactionDate(), dto.header().recordCount(), dto.header().dispositionFlag()
                    );

                    // Idempotency short-circuit early (skip validation/persist)
                    if (alreadyProjected(filePk)) {
                        log.info("file already processed (short-circuit): {}", fileRow.getFileId());
                        // Audit: mark as already processed under current run (if available)
                        try {
                            Long runId = RunContext.getCurrentRunId();
                            if (runId != null) {
                                audit.fileAlreadySafely(runId, filePk);
                            }
                        } catch (Exception ignore) {}
                        success = true;
                        int claimCount = dto.claims().size();
                        int actCount = countActs(dto);
                        return new Result(filePk, 2, 
                            claimCount, 0, 
                            actCount, 0,
                            0, 0, // no submission diagnoses
                            0, 0, // no encounters  
                            0, 0, // no observations
                            claimCount, 0,
                            actCount, 0,
                            0, 0, // no events for already processed
                            dto.header().transactionDate());
                    }

                    try { validateRemittance(dto); }
                    catch (IllegalArgumentException vex) {
                        errors.fileError(filePk, "VALIDATE", "REMITTANCE_RULES", vex.getMessage(), false);
                        throw vex;
                    }

                    var counts = persist.persistRemittance(filePk, dto, out.getAttachments());
                    success = true;
                    int claimCount = dto.claims().size();
                    int actCount = countActs(dto);
                    return new Result(filePk, 2, 
                        claimCount, counts.remitClaims(), 
                        actCount, counts.remitActs(),
                        0, 0, // no submission diagnoses
                        0, 0, // no encounters  
                        0, 0, // no observations
                        claimCount, counts.remitClaims(),
                        actCount, counts.remitActs(),
                        counts.projectedEvents(), counts.projectedStatusRows(),
                        dto.header().transactionDate());
                }
            }

            throw new IllegalStateException("Unknown root type from parser for fileId=" + wi.fileId());
        } catch (Exception ex) {
            success = false;
            if (filePk != null) {
                errors.fileError(filePk, "PIPELINE", "PIPELINE_FAIL",
                        "fileId=" + wi.fileId() + " msg=" + ex.getMessage(), false);
            } else {
                log.warn("PIPELINE_FAIL before file registration. fileId={} msg={}", wi.fileId(), ex.toString());
            }
            throw (ex instanceof RuntimeException re) ? re : new RuntimeException(ex);
        } finally {
            long durMs = (System.nanoTime() - t0) / 1_000_000L;      // duration in ms
            String mode   = (wi.sourcePath() != null) ? "disk" : "mem";
            String source = (wi.source() != null) ? wi.source() : "unknown";
            dhpoMetrics.recordIngestion(wi.source(), mode, success, durMs);
            // per-facility metrics intentionally not recorded here to avoid changing pipeline behavior
            // NOTE: File archiving moved to Orchestrator after verification
        }
    }

    // ---------- DB helpers ----------

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public Long insertStub(WorkItem wi, short rootType, byte[] xmlBytes) {
        return jdbc.queryForObject("""
                    INSERT INTO claims.ingestion_file
                      (file_id, file_name,root_type, sender_id, receiver_id, transaction_date,
                       record_count_declared, disposition_flag, xml_bytes, created_at)
                    VALUES
                      (?,     ?,  ?,         'UNKNOWN', 'UNKNOWN',  now(),
                       0,                   'UNKNOWN', ?, now())
                    ON CONFLICT ON CONSTRAINT uq_ingestion_file DO UPDATE
                       SET updated_at = now()                 -- touch row, no rollback-inducing error
                    RETURNING id
                """, Long.class, wi.fileId(), wi.fileName(), rootType, xmlBytes);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void updateIngestionFileHeader(Long id, short rootType,
                                             String sender, String receiver,
                                             OffsetDateTime tx, Integer recordCount, String disp) {
        jdbc.update("""
          UPDATE claims.ingestion_file
             SET root_type = ?,
                 sender_id = COALESCE(?, sender_id),
                 receiver_id = COALESCE(?, receiver_id),
                 transaction_date = COALESCE(?, transaction_date),
                 record_count_declared = COALESCE(?, record_count_declared),
                 disposition_flag = COALESCE(?, disposition_flag),
                 updated_at = now()
           WHERE id = ?
        """, rootType, sender, receiver, tx, recordCount, disp, id);
    }

    private boolean alreadyProjected(long ingestionFileId) {
        Integer n = jdbc.queryForObject("select count(*) from claims.claim_event where ingestion_file_id = ?", Integer.class, ingestionFileId);
        return Objects.requireNonNullElse(n, 0) > 0;
    }


    // ---------- Counters ----------

    private static int countActs(SubmissionDTO dto) {
        return dto.claims().stream().mapToInt(c -> c.activities() == null ? 0 : c.activities().size()).sum();
    }
    private static int countActs(RemittanceAdviceDTO dto) {
        return dto.claims().stream().mapToInt(c -> c.activities() == null ? 0 : c.activities().size()).sum();
    }

    private static int countDiagnoses(SubmissionDTO dto) {
        return dto.claims().stream()
            .mapToInt(c -> c.diagnoses() == null ? 0 : c.diagnoses().size())
            .sum();
    }

    private static int countEncounters(SubmissionDTO dto) {
        return (int) dto.claims().stream()
            .filter(c -> c.encounter() != null)
            .count();
    }

    private static int countObservations(SubmissionDTO dto) {
        return dto.claims().stream()
            .flatMap(c -> c.activities() == null ? java.util.stream.Stream.empty() : c.activities().stream())
            .mapToInt(a -> a.observations() == null ? 0 : a.observations().size())
            .sum();
    }

    // ---------- Business validation (RESTORED as requested) ----------

    // PATCH: kept exactly in spirit with your earlier version; throws IllegalArgumentException on violations.
    private static void validateSubmission(SubmissionDTO f) {
        req(f.header(), "Header");
        req(f.header().senderId(), "Header.SenderID");
        req(f.header().receiverId(), "Header.ReceiverID");
        req(f.header().transactionDate(), "Header.TransactionDate");
        req(f.header().dispositionFlag(), "Header.DispositionFlag");
        if (f.claims() == null || f.claims().isEmpty()) throw new IllegalArgumentException("No claims in submission");
        //if (!Objects.equals(f.header().recordCount(), f.claims().size()))
         //   throw new IllegalArgumentException("RecordCount mismatch in submission");
        for (var c : f.claims()) {
            req(c.id(), "Claim.ID");
            req(c.payerId(), "Claim.PayerID (claimId=" + c.id() + ")");
            req(c.providerId(), "Claim.ProviderID (claimId=" + c.id() + ")");
            req(c.emiratesIdNumber(), "Claim.EmiratesIDNumber (claimId=" + c.id() + ")");
            //if (c.activities() == null || c.activities().isEmpty())
              //  throw new IllegalArgumentException("No activities (claimId=" + c.id() + ")");
        }
    }

    private static void validateRemittance(RemittanceAdviceDTO f) {
        req(f.header(), "Header");
        req(f.header().senderId(), "Header.SenderID");
        req(f.header().receiverId(), "Header.ReceiverID");
        req(f.header().transactionDate(), "Header.TransactionDate");
        req(f.header().dispositionFlag(), "Header.DispositionFlag");
        if (f.claims() == null || f.claims().isEmpty()) throw new IllegalArgumentException("No claims in remittance");
        //if (!Objects.equals(f.header().recordCount(), f.claims().size()))
          //  throw new IllegalArgumentException("RecordCount mismatch in remittance");
        for (var c : f.claims()) {
            req(c.id(), "Claim.ID");
            req(c.idPayer(), "Claim.IDPayer (claimId=" + c.id() + ")");
            req(c.paymentReference(), "Claim.PaymentReference (claimId=" + c.id() + ")");
            //if (c.activities() == null || c.activities().isEmpty())
              //  throw new IllegalArgumentException("No activities (claimId=" + c.id() + ")");
        }
    }

    private static void req(Object v, String f) {
        if (v == null || (v instanceof String s && s.isBlank()))
            throw new IllegalArgumentException("Missing required: " + f);
    }

    private static boolean isBlank(String s) { return s == null || s.isBlank(); }
}
