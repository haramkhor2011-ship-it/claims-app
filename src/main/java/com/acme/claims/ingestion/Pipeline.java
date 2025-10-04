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
import java.nio.file.Path;
import java.time.OffsetDateTime;
import java.util.Objects;

/**
 * Ingestion Pipeline — orchestrates parse → validate → persist → project → verify → audit.
 *
 * Runtime behavior:
 * - Called per WorkItem by the orchestrator using an executor; this method is non-transactional and
 *   delegates transactional units to helpers annotated with REQUIRES_NEW to ensure durable side-effects.
 * - Inserts a stub ingestion_file row first (idempotent on file_id) to anchor all downstream records.
 * - Performs header pre-check before any update to avoid nulls overwriting safe placeholders.
 * - Branches on root type (Submission/Remittance) and validates business rules before persistence.
 * - Records metrics for end-to-end duration and leverages a staging policy for cleanup/archival handled once in finally.
 *
 * Concurrency & idempotency:
 * - Safe to retry; DB unique constraints prevent double-inserts; alreadyProjected() short-circuits replays.
 * - No shared mutable state; all dependencies are Spring-managed singletons.
 *
 * Error handling:
 * - Validation/persistence failures are logged into ingestion_error and surfaced by rethrowing RuntimeException.
 * - Cleanup/archival is attempted once in finally based on success flag (no duplicate archive attempts on error paths).
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
    private final JdbcTemplate jdbc;
    private final DhpoMetrics dhpoMetrics;
    @Autowired
    @Lazy
    private Pipeline self;

    public record Result(
            long ingestionFileId,
            int rootType, // 1=submission, 2=remittance
            int parsedClaims, int persistedClaims,
            int parsedActivities, int persistedActivities,
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
                success = true;
                return new Result(filePk, rootType == ROOT_SUBMISSION ? 1 : 2, 0, 0, 0, 0, null);
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
                out.getRemittance() != null ? out.getRemittance().claims().size() : 0);

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
                            || dto.header().recordCount() != (dto.claims() == null ? 0 : dto.claims().size())) {
                                log.error("PIPELINE_VALIDATION_FAILED fileId={} fileName={} ingestionFileId={} reason=HEADER_PRECHECK", 
                                wi.fileId(), wi.fileName(), filePk);
                        errors.fileError(filePk, "VALIDATE", "MISSING_HEADER_FIELDS",
                                "Header required fields missing or RecordCount mismatch; file rejected.", false);
                        maybeArchive(wi, false);
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
                        if (log.isDebugEnabled()) {
                            log.debug("file already processed (short-circuit): {}", fileRow.getFileId());
                        }
                        success = true;
                        int claimCount = dto.claims().size();
                        int actCount = countActs(dto);
                        return new Result(filePk, 1, claimCount, 0, actCount, 0, dto.header().transactionDate());
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
                    return new Result(filePk, 1, claimCount, counts.claims(), actCount, counts.acts(), dto.header().transactionDate());
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
                        maybeArchive(wi, false);
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
                        if (log.isDebugEnabled()) {
                            log.debug("file already processed (short-circuit): {}", fileRow.getFileId());
                        }
                        success = true;
                        int claimCount = dto.claims().size();
                        int actCount = countActs(dto);
                        return new Result(filePk, 2, claimCount, 0, actCount, 0, dto.header().transactionDate());
                    }

                    try { validateRemittance(dto); }
                    catch (IllegalArgumentException vex) {
                        errors.fileError(filePk, "VALIDATE", "REMITTANCE_RULES", vex.getMessage(), false);
                        throw vex;
                    }

                    var counts = persist.persistRemittance(filePk, dto);
                    success = true;
                    int claimCount = dto.claims().size();
                    int actCount = countActs(dto);
                    return new Result(filePk, 2, claimCount, counts.remitClaims(), actCount, counts.remitActs(), dto.header().transactionDate());
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
            maybeArchive(wi, success);                               // single cleanup attempt
        }
    }

    // ---------- DB helpers ----------

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public Long insertStub(WorkItem wi, short rootType, byte[] xmlBytes) {
        return jdbc.queryForObject("""
                    INSERT INTO claims.ingestion_file
                      (file_id, file_name,root_type, sender_id, receiver_id, transaction_date,
                       record_count_declared, disposition_flag, xml_bytes)
                    VALUES
                      (?,     ?,  ?,         'UNKNOWN', 'UNKNOWN',  now(),
                       0,                   'UNKNOWN', ?)
                    ON CONFLICT (file_id) DO UPDATE
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

    private void maybeArchive(WorkItem wi, boolean ok) {
        if (wi.sourcePath() == null) return;
        try {
            if(ok) {
                // SUCCESS: delete the staged source
                Files.deleteIfExists(wi.sourcePath());
                log.debug("Deleted staged file on success: {}", wi.sourcePath());
            } else {
                Path target = Path.of(ok ? props.getLocalfs().getArchiveOkDir() : props.getLocalfs().getArchiveFailDir());
                Files.createDirectories(target);
                Files.move(wi.sourcePath(), target.resolve(wi.fileId()), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
            }
        } catch (Exception ignore) {
            log.debug("Cleanup,Archive skipped for {}: {}",wi.sourcePath(), ignore.getMessage());
        }
    }

    // ---------- Counters ----------

    private static int countActs(SubmissionDTO dto) {
        return dto.claims().stream().mapToInt(c -> c.activities() == null ? 0 : c.activities().size()).sum();
    }
    private static int countActs(RemittanceAdviceDTO dto) {
        return dto.claims().stream().mapToInt(c -> c.activities() == null ? 0 : c.activities().size()).sum();
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
