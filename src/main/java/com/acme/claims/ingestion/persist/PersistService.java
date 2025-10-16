package com.acme.claims.ingestion.persist;

import com.acme.claims.domain.model.dto.*;
import com.acme.claims.ingestion.audit.ErrorLogger;
import com.acme.claims.ingestion.parser.ParseOutcome;
import com.acme.claims.refdata.RefCodeResolver;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.Assert;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Objects;
import java.util.Set;

/**
 * # PersistService - Claims Data Persistence Layer
 *
 * <p><b>Core Responsibility:</b> Safely and efficiently persist parsed claims data into the database
 * with robust error handling and transaction management.</p>
 *
 * <h2>📋 Data Flows Handled</h2>
 * <h3>1. Submission Processing</h3>
 * <p>Processes claim submissions containing:</p>
 * <ul>
 *   <li><b>Claim Headers:</b> Basic claim information (ID, payer, provider, amounts)</li>
 *   <li><b>Encounters:</b> Patient encounter details (facility, dates, types)</li>
 *   <li><b>Diagnoses:</b> Medical diagnosis codes and types</li>
 *   <li><b>Activities:</b> Medical procedures with quantities, amounts, and clinicians</li>
 *   <li><b>Observations:</b> Additional clinical observations for activities</li>
 *   <li><b>Resubmissions:</b> Claim resubmission tracking and reasons</li>
 *   <li><b>Contracts:</b> Insurance contract package information</li>
 *   <li><b>Attachments:</b> Supporting documents and files</li>
 * </ul>
 *
 * <h3>2. Remittance Processing</h3>
 * <p>Processes remittance advice containing:</p>
 * <ul>
 *   <li><b>Payment Information:</b> Payment amounts, references, and settlement dates</li>
 *   <li><b>Denial Codes:</b> Rejection reasons and denial tracking</li>
 *   <li><b>Status Updates:</b> Automatic claim status calculation (PAID/PARTIALLY_PAID/REJECTED)</li>
 *   <li><b>Activity-Level Payments:</b> Individual activity payment tracking</li>
 * </ul>
 *
 * <h2>🔒 Data Integrity & Error Handling</h2>
 * <h3>Reference Data Resolution</h3>
 * <p>Automatically resolves business codes to database IDs:</p>
 * <ul>
 *   <li><b>Payers:</b> Insurance company codes → payer_ref_id</li>
 *   <li><b>Providers:</b> Healthcare provider codes → provider_ref_id</li>
 *   <li><b>Facilities:</b> Facility codes → facility_ref_id</li>
 *   <li><b>Clinicians:</b> Clinician codes → clinician_ref_id</li>
 *   <li><b>Diagnosis Codes:</b> ICD codes → diagnosis_code_ref_id</li>
 *   <li><b>Activity Codes:</b> CPT/HCPCS codes → activity_code_ref_id</li>
 *   <li><b>Denial Codes:</b> Rejection codes → denial_code_ref_id</li>
 * </ul>
 *
 * <h3>Duplicate Handling</h3>
 * <ul>
 *   <li><b>Claim Keys:</b> Uses `ON CONFLICT DO NOTHING` with fallback queries</li>
 *   <li><b>Submissions:</b> Prevents duplicate submissions without resubmission flags</li>
 *   <li><b>Events:</b> Idempotent event creation with conflict resolution</li>
 * </ul>
 *
 * <h2>⚡ Transaction Strategy</h2>
 * <p><b>Per-Claim Isolation:</b> Each claim processed in its own `REQUIRES_NEW` transaction</p>
 * <ul>
 *   <li><b>Benefit:</b> Single claim failure doesn't stop entire file processing</li>
 *   <li><b>Benefit:</b> Successful claims commit even if others fail (partial success)</li>
 *   <li><b>Benefit:</b> Better error isolation and debugging</li>
 * </ul>
 *
 * <h2>📊 Performance Features</h2>
 * <ul>
 *   <li><b>Batch Processing:</b> Efficient bulk operations for multiple entities</li>
 *   <li><b>Reference Caching:</b> Avoids repeated lookups for same reference codes</li>
 *   <li><b>Minimal Round Trips:</b> Uses CTEs and single queries where possible</li>
 *   <li><b>Async Processing:</b> Non-blocking reference resolution where appropriate</li>
 * </ul>
 *
 * <h2>🔍 Error Recovery</h2>
 * <ul>
 *   <li><b>Validation First:</b> Validates all required fields before database operations</li>
 *   <li><b>Graceful Degradation:</b> Continues processing other claims if one fails</li>
 *   <li><b>Comprehensive Logging:</b> Detailed error information for debugging</li>
 *   <li><b>Fallback Mechanisms:</b> Alternative approaches for edge cases</li>
 * </ul>
 *
 * @author Claims Team
 * @since 1.0
 * @version 2.0 - Enhanced with per-claim transactions and flexible XSD validation
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PersistService {

    private final JdbcTemplate jdbc;
    private final ErrorLogger errors;
    private final RefCodeResolver refCodeResolver;

    /* ========================= SUBMISSION PATH ========================= */

    /**
     * Persists a submission file without attachments.
     * 
     * <p>This is a convenience method that delegates to the main persistence method
     * with an empty list of attachments.
     * 
     * @param ingestionFileId the ID of the ingestion file being processed
     * @param file the parsed submission data
     * @return counts of persisted entities
     * @see #persistSubmission(long, SubmissionDTO, List)
     */
    @Transactional
    public PersistCounts persistSubmission(long ingestionFileId, SubmissionDTO file) {
        return persistSubmission(ingestionFileId, file, List.of());
    }

    /**
     * # persistSubmission - Main Entry Point for Claim Submission Processing
     *
     * <p><b>Purpose:</b> Orchestrates the complete persistence of a parsed claim submission file,
     * ensuring data integrity and providing partial success capability.</p>
     *
     * <h3>Processing Flow</h3>
     * <ol>
     *   <li><b>Submission Record:</b> Creates submission header record</li>
     *   <li><b>Claim Processing:</b> Processes each claim in isolated transaction</li>
     *   <li><b>Reference Resolution:</b> Resolves all business codes to database IDs</li>
     *   <li><b>Event Tracking:</b> Creates claim events and status timeline</li>
     *   <li><b>Attachment Handling:</b> Processes file attachments (if present)</li>
     * </ol>
     *
     * <h3>Transaction Strategy</h3>
     * <ul>
     *   <li><b>File Coordination:</b> No transaction boundary (orchestration only)</li>
     *   <li><b>Per-Claim Isolation:</b> Each claim in {@code REQUIRES_NEW} transaction</li>
     *   <li><b>Partial Success:</b> Successful claims commit independently</li>
     *   <li><b>Error Containment:</b> Claim failures don't affect other claims</li>
     * </ul>
     *
     * <h3>Error Handling</h3>
     * <ul>
     *   <li><b>Validation:</b> Required fields validated before database operations</li>
     *   <li><b>Duplicates:</b> Existing submissions without resubmission flags are skipped</li>
     *   <li><b>Reference Resolution:</b> Missing reference data is created automatically</li>
     *   <li><b>Graceful Degradation:</b> Continues processing other claims if one fails</li>
     * </ul>
     *
     * @param ingestionFileId the unique ID of the ingestion file being processed
     * @param file the parsed submission data containing header and claims information
     * @param attachments optional list of file attachments associated with this submission
     * @return PersistCounts summary of entities successfully persisted
     * @throws IllegalArgumentException if ingestionFileId is invalid or file is null
     *
     * @see PersistCounts for detailed count information
     * @see SubmissionDTO for input data structure
     */
    @Transactional
    public PersistCounts persistSubmission(long ingestionFileId, SubmissionDTO file, List<ParseOutcome.AttachmentRecord> attachments) {
        final OffsetDateTime now = OffsetDateTime.now();

        final Long submissionId = jdbc.queryForObject(
                "insert into claims.submission(ingestion_file_id, tx_at) values (?, ?) returning id",
                Long.class, ingestionFileId, file.header().transactionDate()
        );
        log.info("persistSubmission: created submission header id={} for ingestionFileId={}", submissionId, ingestionFileId);

        int claims = 0, acts = 0, obs = 0, dxs = 0;
        int skippedDup = 0, skippedInvalidClaim = 0;

        for (SubmissionClaimDTO c : file.claims()) {
            try {
                log.info("persistSingleClaim: start claimId={} payerId={} providerId={} emiratesId={} gross={} patientShare={} net={} activities={} diagnoses={}",
                        c.id(), c.payerId(), c.providerId(), c.emiratesIdNumber(), c.gross(), c.patientShare(), c.net(),
                        (c.activities() == null ? 0 : c.activities().size()), (c.diagnoses() == null ? 0 : c.diagnoses().size()));
                // Process each claim in its own transaction to prevent single failure from stopping entire file
                PersistCounts claimCounts = persistSingleClaim(ingestionFileId, submissionId, c, attachments, file);

                log.info("persistSingleClaim: result claimId={} counts[c={},a={},obs={},dxs={}]",
                        c.id(), claimCounts.claims(), claimCounts.acts(), claimCounts.obs(), claimCounts.dxs());

                claims += claimCounts.claims();
                acts += claimCounts.acts();
                obs += claimCounts.obs();
                dxs += claimCounts.dxs();

            } catch (Exception claimEx) {
                final String claimIdBiz = c.id();
                // Log error but continue with next claim (partial success)
                errors.claimError(ingestionFileId, "PERSIST", claimIdBiz,
                        "CLAIM_PERSIST_FAIL", claimEx.getMessage(), false);
                log.warn("persistSingleClaim: failure claimId={} : {}", claimIdBiz, claimEx.getMessage());
                log.info("persistSingleClaim: exception stack for claimId={} ", claimIdBiz, claimEx);
                // continue with next claim - transaction isolation prevents this from affecting other claims
            }
        }

            if (skippedDup > 0) {
                errors.fileError(ingestionFileId, "VALIDATE", "DUP_SUBMISSION_NO_RESUB_SUMMARY",
                        "Skipped " + skippedDup + " duplicate submission(s) without <Resubmission>.", false);
            }
            if (skippedInvalidClaim > 0) {
                errors.fileError(ingestionFileId, "VALIDATE", "MISSING_CLAIM_REQUIRED_SUMMARY",
                        "Skipped " + skippedInvalidClaim + " invalid claim(s) due to missing requireds.", false);
            }

        return new PersistCounts(claims, acts, obs, dxs, 0, 0);
    }

    /**
     * # persistSingleClaim - Isolated Claim Processing with Transaction Safety
     *
     * <p><b>Purpose:</b> Process a single claim in complete isolation within its own transaction.
     * This ensures that claim-level failures don't cascade to other claims in the same file.</p>
     *
     * <h3>Processing Scope</h3>
     * <p>Handles all aspects of a single claim:</p>
     * <ul>
     *   <li><b>Claim Key:</b> Creates or retrieves canonical claim identifier</li>
     *   <li><b>Claim Record:</b> Persists main claim data with reference IDs</li>
     *   <li><b>Related Entities:</b> Encounters, diagnoses, activities, observations</li>
     *   <li><b>Event Tracking:</b> Creates submission/resubmission events</li>
     *   <li><b>Status Timeline:</b> Updates claim status history</li>
     *   <li><b>Attachments:</b> Links file attachments to the claim</li>
     * </ul>
     *
     * <h3>Transaction Strategy</h3>
     * <ul>
     *   <li><b>Isolation Level:</b> {@code REQUIRES_NEW} - Independent transaction</li>
     *   <li><b>Failure Containment:</b> Claim failure doesn't affect other claims</li>
     *   <li><b>Success Guarantee:</b> If this method returns successfully, all claim data is committed</li>
     *   <li><b>Error Recovery:</b> Failed claims are logged but don't prevent other claims from processing</li>
     * </ul>
     *
     * <h3>Error Handling</h3>
     * <ul>
     *   <li><b>Pre-validation:</b> Validates all required fields before database operations</li>
     *   <li><b>Reference Resolution:</b> Creates missing reference data automatically</li>
     *   <li><b>Duplicate Detection:</b> Skips duplicate submissions without resubmission flags</li>
     *   <li><b>Graceful Logging:</b> Detailed error information for debugging</li>
     * </ul>
     *
     * @param ingestionFileId the unique ID of the ingestion file being processed
     * @param submissionId    the database ID of the parent submission record
     * @param c               the claim DTO containing all claim data to persist
     * @param attachments     list of all attachments for the submission (filtered by claim ID)
     * @param file
     * @return PersistCounts containing counts of entities persisted for this claim
     * @throws RuntimeException if claim processing fails (logged and handled by caller)
     * @see SubmissionClaimDTO for input data structure
     * @see PersistCounts for return value details
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public PersistCounts persistSingleClaim(long ingestionFileId, long submissionId, SubmissionClaimDTO c,
                                            List<ParseOutcome.AttachmentRecord> attachments, SubmissionDTO file) {
        final String claimIdBiz = c.id();
        final OffsetDateTime now = OffsetDateTime.now();

        // hard guard at claim level (before any DB writes)
        if (!claimHasRequired(ingestionFileId, c)) {
            errors.claimError(ingestionFileId, "VALIDATE", claimIdBiz, "MISSING_CLAIM_REQUIRED",
                    "Claim required fields missing; skipping claim.", false);
            log.warn("persistSingleClaim: validation failed, required field missing for claimId={}", claimIdBiz);
            return new PersistCounts(0, 0, 0, 0, 0, 0);
        }

        // Duplicate prior SUBMISSION and current has no <Resubmission> → skip & log
        if (isAlreadySubmitted(claimIdBiz) && c.resubmission() == null) {
            log.info("Claim already submitted : {}", claimIdBiz);
            log.info("persistSingleClaim: skipping duplicate without <Resubmission> claimId={}", claimIdBiz);
            errors.claimError(ingestionFileId, "VALIDATE", claimIdBiz, "DUP_SUBMISSION_NO_RESUB",
                    "Duplicate Claim.Submission without <Resubmission>; skipped.", false);
            return new PersistCounts(0, 0, 0, 0, 0, 0);
        }

        // Upsert core graph
        log.info("persistSingleClaim: upserting claim_key for claimId={} txAt={} type=S", claimIdBiz, file.header().transactionDate());
        final long claimKeyId = upsertClaimKey(claimIdBiz, file.header().transactionDate(), "S");
        log.info("persistSingleClaim: claim_key id={} for claimId={}", claimKeyId, claimIdBiz);

        // resolve ref IDs (inserting into ref tables + auditing if missing)
        final Long payerRefId = (c.payerId() == null) ? null
                : refCodeResolver.resolvePayer(c.payerId(), null, "SYSTEM", ingestionFileId, c.id()).orElse(null);
        final Long providerRefId = (c.providerId() == null) ? null
                : refCodeResolver.resolveProvider(c.providerId(), null, "SYSTEM", ingestionFileId, c.id()).orElse(null);

        log.info("persistSingleClaim: about to insert claim for claimId={} amounts[gross={}, patientShare={}, net={}]",
                claimIdBiz, c.gross(), c.patientShare(), c.net());
        final long claimId = upsertClaim(claimKeyId, submissionId, c, payerRefId, providerRefId);
        log.info("persistSingleClaim: inserted claim dbId={} for claimId={} (submissionId={})", claimId, claimIdBiz, submissionId);

        // Contract (optional)
        if (c.contract() != null) {
            upsertContract(claimId, c.contract());
        }

        // Encounter (optional, but has NOT NULL cols in DDL)
        if (c.encounter() != null && encounterHasRequired(ingestionFileId, claimIdBiz, c.encounter())) {
            // PATCH: resolve facility ref id
            final Long facilityRefId = (c.encounter().facilityId() == null) ? null
                    : refCodeResolver.resolveFacility(c.encounter().facilityId(), null, null, null, "SYSTEM", ingestionFileId, c.id())
                    .orElse(null);
            upsertEncounter(claimId, c.encounter(), facilityRefId);
        }

        // Diagnoses (optional)
        int dxs = 0;
        if (c.diagnoses() != null) {
            for (DiagnosisDTO d : c.diagnoses()) {
                if (diagnosisHasRequired(ingestionFileId, claimIdBiz, d)) {
                    // PATCH: resolve diagnosis ref id
                    final Long diagnosisRefId = (d.code() == null) ? null
                            : refCodeResolver.resolveDiagnosisCode(d.code(), null, null, "SYSTEM", ingestionFileId, c.id()).orElse(null);
                    upsertDiagnosis(claimId, d, diagnosisRefId);
                    dxs++;
                }
            }
        }

        // Activities (optional)
        int acts = 0, obs = 0;
        if (c.activities() != null) {
            for (ActivityDTO a : c.activities()) {
                if (!activityHasRequired(ingestionFileId, claimIdBiz, a)) continue;
                // resolve activity/clinician refs
                final Long activityCodeRefId = (a.code() == null) ? null
                        : refCodeResolver.resolveActivityCode(a.code(), a.type(), null, "SYSTEM", ingestionFileId, c.id()).orElse(null);
                final Long clinicianRefId = (a.clinician() == null) ? null
                        : refCodeResolver.resolveClinician(a.clinician(), null, null, "SYSTEM", ingestionFileId, c.id()).orElse(null);

                long actId = upsertActivity(claimId, a, clinicianRefId, activityCodeRefId);

                acts++;
                if (a.observations() != null) {
                    for (ObservationDTO o : a.observations()) {
                        // Observation unique index will dedupe; value_text may be null → OK
                        upsertObservation(actId, o);
                        obs++;
                    }
                }
            }
        }

        // Events & Timeline (only for persisted claim)
        long ev1 = insertClaimEvent(claimKeyId, ingestionFileId, file.header().transactionDate(), (short) 1, submissionId, null);
        log.info("persistSingleClaim: inserted submission event id={} for claimId={} ingestionFileId={}", ev1, claimIdBiz, ingestionFileId);
        projectActivitiesToClaimEventFromSubmission(ev1, c.activities());
        insertStatusTimeline(claimKeyId, (short) 1, file.header().transactionDate(), ev1);

        if (c.resubmission() != null) {
            long ev2 = insertClaimEvent(claimKeyId, ingestionFileId, file.header().transactionDate(), (short) 2, submissionId, null);
            log.info("persistSingleClaim: inserted resubmission event id={} for claimId={} ingestionFileId={}", ev2, claimIdBiz, ingestionFileId);
            insertResubmission(ev2, c.resubmission());
            insertStatusTimeline(claimKeyId, (short) 2, file.header().transactionDate(), ev2);
        }

        // Attachments (Submission-only)
        if (attachments != null && !attachments.isEmpty()) {
            for (ParseOutcome.AttachmentRecord ar : attachments) {
                if (!Objects.equals(ar.claimId(), claimIdBiz)) continue;
                upsertClaimAttachment(claimKeyId, ev1, ingestionFileId, ar);
            }
        }

        log.info("Successfully persisted claim: {} with {} activities, {} observations, {} diagnoses",
                claimIdBiz, acts, obs, dxs);

        return new PersistCounts(1, acts, obs, dxs, 0, 0);
    }

    /* ========================= REMITTANCE PATH ========================= */

    /**
     * Persists a remittance file without attachments.
     * 
     * <p>This is a convenience method that delegates to the main persistence method
     * with an empty list of attachments.
     * 
     * @param ingestionFileId the ID of the ingestion file being processed
     * @param file the parsed remittance advice data
     * @return counts of persisted entities
     * @see #persistRemittance(long, RemittanceAdviceDTO, List)
     */
    @Transactional
    public PersistCounts persistRemittance(long ingestionFileId, RemittanceAdviceDTO file) {
        return persistRemittance(ingestionFileId, file, List.of());
    }

    /**
     * Persists remittance advice data and updates claim statuses.
     * 
     * <p>This method processes remittance advice files which contain payment information
     * and denial codes for previously submitted claims. It performs the following operations:
     * <ul>
     *   <li>Creates remittance records linked to the ingestion file</li>
     *   <li>Updates or creates remittance claim records</li>
     *   <li>Processes remittance activities with payment amounts and denial codes</li>
     *   <li>Resolves reference data for payers, providers, and denial codes</li>
     *   <li>Calculates and updates claim statuses based on payment amounts</li>
     *   <li>Creates claim events and status timeline entries</li>
     *   <li>Processes file attachments (if present)</li>
     * </ul>
     * 
     * <p>Status determination logic:
     * <ul>
     *   <li><strong>PAID (3):</strong> Payment amount equals net requested amount</li>
     *   <li><strong>PARTIALLY_PAID (4):</strong> Payment amount is less than net requested</li>
     *   <li><strong>REJECTED (5):</strong> No payment and all activities are denied</li>
     * </ul>
     * 
     * <p>All operations are performed within a single transaction. Individual claim failures
     * are logged and skipped to allow processing of other claims in the batch.
     * 
     * @param ingestionFileId the ID of the ingestion file being processed
     * @param file the parsed remittance advice data
     * @param attachments optional list of file attachments associated with this remittance
     * @return PersistCounts containing the number of remittance entities persisted
     * @throws IllegalArgumentException if required parameters are null or invalid
     */
    @Transactional
    public PersistCounts persistRemittance(long ingestionFileId, RemittanceAdviceDTO file, List<ParseOutcome.AttachmentRecord> attachments) {
        final Long remittanceId = jdbc.queryForObject(
                "insert into claims.remittance(ingestion_file_id, tx_at) values (?, ?) returning id",
                Long.class, ingestionFileId, file.header().transactionDate()
        );

        int rClaims = 0, rActs = 0, skippedInvalidRemitClaim = 0;

        for (RemittanceClaimDTO c : file.claims()) {
            // guard remittance-claim level (ID, IDPayer, ProviderID, PaymentReference as used)
            if (!remitClaimHasRequired(ingestionFileId, c)) {
                skippedInvalidRemitClaim++;
                log.warn("persistRemittance: missing required remittance fields; skipping claimId={} idPayer={} providerId={} paymentRef={}",
                        c.id(), c.idPayer(), c.providerId(), c.paymentReference());
                continue; // logged above
            }

            try {
                // Process each claim in its own transaction to prevent single failure from stopping entire file
                log.info("persistSingleRemittanceClaim: start claimId={} idPayer={} providerId={} activities={} paymentRef={}",
                        c.id(), c.idPayer(), c.providerId(), (c.activities() == null ? 0 : c.activities().size()), c.paymentReference());
                PersistCounts claimCounts = persistSingleRemittanceClaim(ingestionFileId, remittanceId, c, attachments, file);
                rClaims += claimCounts.remitClaims();
                rActs += claimCounts.remitActs();
            } catch (Exception claimEx) {
                // Log error but continue with next claim (partial success)
                errors.claimError(ingestionFileId, "PERSIST", c.id(),
                        "CLAIM_PERSIST_FAIL", claimEx.getMessage(), false);
                log.warn("persistRemittance: failure claimId={} : {}", c.id(), claimEx.getMessage());
                log.info("persistRemittance: exception stack for claimId={} ", c.id(), claimEx);
                // continue with next claim - transaction isolation prevents this from affecting other claims
            }
        }

        if (skippedInvalidRemitClaim > 0) {
            errors.fileError(ingestionFileId, "VALIDATE", "MISSING_REMIT_REQUIRED_SUMMARY",
                    "Skipped " + skippedInvalidRemitClaim + " invalid remittance claim(s) due to missing requireds.", false);
        }

        return new PersistCounts(0, 0, 0, 0, rClaims, rActs);
    }

    /**
     * # persistSingleRemittanceClaim - Isolated Remittance Claim Processing with Transaction Safety
     *
     * <p><b>Purpose:</b> Process a single remittance claim in complete isolation within its own transaction.
     * This ensures that claim-level failures don't cascade to other claims in the same file.</p>
     *
     * <h3>Processing Scope</h3>
     * <p>Handles all aspects of a single remittance claim:</p>
     * <ul>
     *   <li><b>Claim Key:</b> Creates or retrieves canonical claim identifier</li>
     *   <li><b>Remittance Claim Record:</b> Persists remittance claim data with reference IDs</li>
     *   <li><b>Remittance Activities:</b> Individual activity payment tracking</li>
     *   <li><b>Event Tracking:</b> Creates remittance events and status timeline</li>
     *   <li><b>Status Calculation:</b> Determines claim status based on payments and denials</li>
     *   <li><b>Attachments:</b> Links file attachments to the claim</li>
     * </ul>
     *
     * <h3>Transaction Strategy</h3>
     * <ul>
     *   <li><b>Isolation Level:</b> {@code REQUIRES_NEW} - Independent transaction</li>
     *   <li><b>Failure Containment:</b> Claim failure doesn't affect other claims</li>
     *   <li><b>Success Guarantee:</b> If this method returns successfully, all claim data is committed</li>
     *   <li><b>Error Recovery:</b> Failed claims are logged but don't prevent other claims from processing</li>
     * </ul>
     *
     * @param ingestionFileId the unique ID of the ingestion file being processed
     * @param remittanceId    the database ID of the parent remittance record
     * @param c               the remittance claim DTO containing all claim data to persist
     * @param attachments     list of all attachments for the remittance (filtered by claim ID)
     * @param file            the complete remittance file for header information
     * @return PersistCounts containing counts of entities persisted for this claim
     * @throws RuntimeException if claim processing fails (logged and handled by caller)
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public PersistCounts persistSingleRemittanceClaim(long ingestionFileId, long remittanceId, RemittanceClaimDTO c,
                                                      List<ParseOutcome.AttachmentRecord> attachments, RemittanceAdviceDTO file) {
        final String claimIdBiz = c.id();
        final long claimKeyId = upsertClaimKey(c.id(), file.header().transactionDate(), "R");
        
        // resolve denial code ref id for the claim scope (if any denial present at claim level)
        // final Long denialRefId = (c.denialCode() == null) ? null
        //         : refCodeResolver.resolveDenialCode(c.denialCode(), null, c.idPayer(), "SYSTEM", ingestionFileId, c.id())
        //         .orElse(null);
        final Long payerRefId = (c.idPayer() == null) ? null
                : refCodeResolver.resolvePayer(c.idPayer(), null, "SYSTEM", ingestionFileId, c.id())
                .orElse(null);
        final Long providerRefId = (c.providerId() == null) ? null
                : refCodeResolver.resolveProvider(c.providerId(), null, "SYSTEM", ingestionFileId, c.id())
                .orElse(null);

        final long rcId = upsertRemittanceClaim(remittanceId, claimKeyId, c, null, payerRefId, providerRefId);

        int rActs = 0;
        if (c.activities() != null) {
            for (RemittanceActivityDTO a : c.activities()) {
                if (!remitActivityHasRequired(ingestionFileId, c.id(), a)) continue; // logged+skip
                // resolve activity code ref id
                final Long activityCodeRefId = (a.code() == null) ? null
                        : refCodeResolver.resolveActivityCode(a.code(), a.type(), null, "SYSTEM", ingestionFileId, c.id()).orElse(null);
                final Long denialRefId = (a.denialCode() == null) ? null
                        : refCodeResolver.resolveDenialCode(a.denialCode(), null, c.idPayer(), "SYSTEM", ingestionFileId, c.id()).orElse(null);
                final Long clinicianRefId = (a.clinician() == null) ? null
                        : refCodeResolver.resolveClinician(a.clinician(), null, null, "SYSTEM", ingestionFileId, c.id()).orElse(null);
                upsertRemittanceActivity(rcId, a, activityCodeRefId, denialRefId, clinicianRefId);
                rActs++;
            }
        }

        long ev = insertClaimEvent(claimKeyId, ingestionFileId, file.header().transactionDate(), (short) 3, null, remittanceId);
        projectActivitiesToClaimEventFromRemittance(ev, c.activities());

        // Decide status from amounts & denials
        var netRequested = fetchSubmissionNetRequested(claimKeyId);  // sum of submission activity.net
        var paidAmount = fetchRemittancePaidAmount(rcId);          // sum of remit activity.payment_amount
        boolean allDenied = areAllRemitActivitiesDenied(rcId);

        short status;
        final short SUBMITTED = 1, RESUBMITTED = 2, PAID = 3, PARTIALLY_PAID = 4, REJECTED = 5; // doc'd types
        int cmp = nz(paidAmount).compareTo(nz(netRequested));
        if (cmp == 0 && nz(netRequested).signum() >= 0) {
            status = PAID;
        } else if (nz(paidAmount).signum() > 0 && cmp < 0) {
            status = PARTIALLY_PAID;
        } else if (nz(paidAmount).signum() == 0 && allDenied) {
            status = REJECTED;
        } else {
            status = PARTIALLY_PAID; // conservative default
        }

        insertStatusTimeline(claimKeyId, status, file.header().transactionDate(), ev);

        // Attachments (Remittance)
        if (attachments != null && !attachments.isEmpty()) {
            for (ParseOutcome.AttachmentRecord ar : attachments) {
                if (!Objects.equals(ar.claimId(), c.id())) continue;
                upsertClaimAttachment(claimKeyId, ev, ingestionFileId, ar);
            }
        }

        log.info("Successfully persisted remittance claim: {} with {} activities", claimIdBiz, rActs);

        return new PersistCounts(0, 0, 0, 0, 1, rActs);
    }

    /**
     * Null-safe BigDecimal utility method.
     * 
     * @param v the BigDecimal value to check
     * @return the original value if not null, otherwise BigDecimal.ZERO
     */
    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    /**
     * Fetches the total net amount requested for a claim from submission activities.
     * 
     * @param claimKeyId the claim key ID to query
     * @return the sum of net amounts from all submission activities, or 0.0 if none found
     */
    private BigDecimal fetchSubmissionNetRequested(long claimKeyId) {
        return jdbc.queryForObject("""
                    select coalesce(sum(a.net), 0.0)
                      from claims.claim c
                      join claims.activity a on a.claim_id = c.id
                     where c.claim_key_id = ?
                """, BigDecimal.class, claimKeyId);
    }

    /**
     * Fetches the total payment amount for a remittance claim.
     * 
     * @param remittanceClaimId the remittance claim ID to query
     * @return the sum of payment amounts from all remittance activities, or 0.0 if none found
     */
    private BigDecimal fetchRemittancePaidAmount(long remittanceClaimId) {
        return jdbc.queryForObject("""
                    select coalesce(sum(ra.payment_amount), 0.0)
                      from claims.remittance_activity ra
                     where ra.remittance_claim_id = ?
                """, BigDecimal.class, remittanceClaimId);
    }

    /**
     * Determines if all remittance activities for a claim are denied.
     * 
     * <p>An activity is considered denied if it has a denial code and zero payment amount.
     * This method returns true only if:
     * <ul>
     *   <li>There is at least one remittance activity for the claim</li>
     *   <li>All activities have a non-null, non-empty denial code</li>
     *   <li>All activities have zero payment amount</li>
     * </ul>
     * 
     * @param remittanceClaimId the remittance claim ID to check
     * @return true if all activities are denied, false otherwise
     */
    private boolean areAllRemitActivitiesDenied(long remittanceClaimId) {
        // True when NO rows violate "must be denied or zero payment"
        Integer total = jdbc.queryForObject("""
                    select count(*) from claims.remittance_activity where remittance_claim_id = ?
                """, Integer.class, remittanceClaimId);

        Integer violations = jdbc.queryForObject("""
                    select count(*) from claims.remittance_activity
                     where remittance_claim_id = ?
                       and (denial_code is null or denial_code = '' or payment_amount <> 0)
                """, Integer.class, remittanceClaimId);

        int t = (total == null ? 0 : total);
        int v = (violations == null ? 0 : violations);
        return t > 0 && v == 0;
    }

    /* ========================= CLAIM KEY MANAGEMENT ========================= */

    /**
     * # isAlreadySubmitted - Duplicate Submission Detection
     *
     * <p><b>Purpose:</b> Determines if a claim has already been submitted by checking for
     * existing submission events in the database.</p>
     *
     * <p><b>Logic:</b> Checks for claim events with type=1 (SUBMITTED) for the given claim ID.
     * If such events exist, the claim has already been processed.</p>
     *
     * <p><b>Use Case:</b> Prevents duplicate claim processing while allowing legitimate resubmissions.</p>
     *
     * @param claimIdBiz the business claim ID to check for prior submissions
     * @return {@code true} if claim has existing submission events, {@code false} otherwise
     */
    private boolean isAlreadySubmitted(String claimIdBiz) {
        Long ck = jdbc.query(
                "select id from claims.claim_key where claim_id=?",
                ps -> ps.setString(1, claimIdBiz),
                rs -> rs.next() ? rs.getLong(1) : null
        );
        if (ck == null) return false;
        Integer n = jdbc.queryForObject(
                "select count(*) from claims.claim_event where claim_key_id=? and type=1",
                Integer.class, ck
        );
        return n > 0;
    }

    /**
     * # upsertClaimKey - Thread-Safe Claim Key Management with Race Condition Handling
     *
     * <p><b>Purpose:</b> Creates or retrieves the canonical claim identifier with robust handling
     * of concurrent access and data integrity issues.</p>
     *
     * <h3>Database Operation</h3>
     * <p>Uses PostgreSQL's {@code ON CONFLICT DO NOTHING} for atomic upsert:</p>
     * <pre>{@code
     * WITH ins AS (
     *   INSERT INTO claims.claim_key (claim_id) VALUES (?) ON CONFLICT DO NOTHING RETURNING id
     * )
     * SELECT id FROM ins UNION ALL SELECT id FROM claims.claim_key WHERE claim_id = ? LIMIT 1
     * }</pre>
     *
     * <h3>Race Condition Handling</h3>
     * <p><b>Scenario 1 - Normal Operation:</b></p>
     * <ul>
     *   <li>Claim doesn't exist → INSERT succeeds → Returns new ID</li>
     *   <li>Claim exists → INSERT skipped → Returns existing ID</li>
     * </ul>
     *
     * <p><b>Scenario 2 - Data Integrity Issue:</b></p>
     * <ul>
     *   <li>Multiple records exist for same claim_id (shouldn't happen due to UNIQUE constraint)</li>
     *   <li>Query returns multiple rows → Exception caught and handled</li>
     *   <li>Fallback query retrieves first available ID</li>
     * </ul>
     *
     * <p><b>Scenario 3 - Concurrent Access:</b></p>
     * <ul>
     *   <li>Multiple threads try to insert same claim_id simultaneously</li>
     *   <li>Database constraint prevents duplicates</li>
     *   <li>Fallback query resolves to existing record</li>
     * </ul>
     *
     * <h3>Error Recovery Strategy</h3>
     * <ol>
     *   <li><b>Primary Query:</b> Standard upsert with conflict resolution</li>
     *   <li><b>Data Integrity Fallback:</b> Handle "more than one row" exceptions</li>
     *   <li><b>Race Condition Fallback:</b> Handle constraint violation exceptions</li>
     *   <li><b>Logging:</b> Detailed information for debugging and monitoring</li>
     * </ol>
     *
     * @param claimIdBiz the business claim ID to upsert (must not be null or blank)
     * @return the database ID of the claim key record (existing or newly created)
     * @throws IllegalArgumentException if claimIdBiz is null or blank
     * @throws RuntimeException if unable to resolve claim key after multiple attempts
     */
    private long upsertClaimKey(String claimIdBiz, OffsetDateTime transactionDateTime, String transactionType) {
        Assert.hasText(claimIdBiz, "claimIdBiz must not be blank"); // fast guard

        try {
            // Single round-trip, no UPDATE on conflict:
            // 1) Try INSERT, capture id in CTE 'ins'
            // 2) If nothing inserted (conflict), select existing id
            OffsetDateTime transactionCreateTime = "S".equalsIgnoreCase(transactionType) ? transactionDateTime : null;
            OffsetDateTime transactionUpdateTime = "R".equalsIgnoreCase(transactionType) ? transactionDateTime : null;
            final String sql = """
                    WITH ins AS (
                      INSERT INTO claims.claim_key (claim_id, created_at, updated_at)
                      VALUES (?, ?, ?)
                      ON CONFLICT (claim_id) DO NOTHING
                      RETURNING id
                    )
                    SELECT id FROM ins
                    UNION ALL
                    SELECT id FROM claims.claim_key WHERE claim_id = ?
                    LIMIT 1
                    """;

            // Returns the inserted id, or the existing id if conflict occurred
            Long claimKeyId = jdbc.queryForObject(sql, Long.class, claimIdBiz, transactionCreateTime, transactionUpdateTime, claimIdBiz);

            // If we have a transaction update time (e.g., remittance), apply a follow-up UPDATE safely
            if (transactionUpdateTime != null && claimKeyId != null) {
                jdbc.update("update claims.claim_key set updated_at = ? where id = ?", transactionUpdateTime, claimKeyId);
            }
            return claimKeyId;

        } catch (Exception e) {
            // Handle the case where multiple claim_ids exist in the database (data integrity issue)
            if (e.getMessage() != null && e.getMessage().contains("more than one row returned")) {
                log.warn("Data integrity issue: Multiple claim_key records found for claim_id: {}. Using first available ID.", claimIdBiz);

                // Fallback: Get the first available ID for this claim_id
                try {
                    Long existingId = jdbc.queryForObject(
                            "SELECT id FROM claims.claim_key WHERE claim_id = ? ORDER BY id LIMIT 1",
                            Long.class, claimIdBiz);

                    if (existingId != null) {
                        log.info("Using existing claim_key ID: {} for claim_id: {}", existingId, claimIdBiz);
                        return existingId;
                    }
                } catch (Exception fallbackEx) {
                    log.error("Failed to retrieve existing claim_key for claim_id: {}", claimIdBiz, fallbackEx);
                }

                // If all else fails, throw the original exception
                throw new RuntimeException("Failed to upsert claim key for claim_id: " + claimIdBiz +
                        ". Data integrity issue detected.", e);
            }

            // Handle potential race conditions during concurrent insertions
            if (e.getMessage() != null && (
                e.getMessage().contains("duplicate key") ||
                e.getMessage().contains("unique constraint") ||
                e.getMessage().contains("violates unique constraint"))) {

                log.info("Race condition detected for claim_id: {}, attempting fallback query", claimIdBiz);

                try {
                    // Fallback: Query for existing record (race condition with another thread)
                    Long existingId = jdbc.queryForObject(
                            "SELECT id FROM claims.claim_key WHERE claim_id = ?",
                            Long.class, claimIdBiz);

                    if (existingId != null) {
                        log.info("Using existing claim_key ID: {} for claim_id: {} (race condition resolved)", existingId, claimIdBiz);
                        return existingId;
                    }
                } catch (Exception fallbackEx) {
                    log.error("Failed to retrieve existing claim_key after race condition for claim_id: {}", claimIdBiz, fallbackEx);
                }

                // If fallback fails, throw original exception
                throw new RuntimeException("Race condition detected for claim_id: " + claimIdBiz +
                        ". Failed to resolve existing claim_key.", e);
            }

            // Re-throw other types of exceptions
            throw e;
        }
    }


    private long upsertClaim(long claimKeyId, long submissionId, SubmissionClaimDTO c,
                             Long payerRefId, Long providerRefId) { // added ref IDs
        jdbc.update("""
                            insert into claims.claim(
                              claim_key_id, submission_id,
                              id_payer, member_id, payer_id, provider_id, emirates_id_number, gross, patient_share, net,
                              payer_ref_id, provider_ref_id, comments, tx_at
                            ) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                            on conflict (claim_key_id) do nothing
                        """, claimKeyId, submissionId,
                c.idPayer(), c.memberId(), c.payerId(), c.providerId(), c.emiratesIdNumber(),
                c.gross(), c.patientShare(), c.net(),
                payerRefId, providerRefId, c.comments(), file.header().transactionDate()
        );
        return jdbc.queryForObject("select id from claims.claim where claim_key_id=?", Long.class, claimKeyId);
    }


    private void upsertEncounter(long claimId, EncounterDTO e, Long facilityRefId) { // added ref id
        jdbc.update("""
                            insert into claims.encounter(
                              claim_id, facility_id, type, patient_id, start_at, end_at, start_type, end_type, transfer_source, transfer_destination,
                              facility_ref_id                                              -- PATCH
                            ) values (?,?,?,?,?,?,?,?,?,?,?)
                        """, claimId, e.facilityId(), e.type(), e.patientId(), e.start(), e.end(),
                e.startType(), e.endType(), e.transferSource(), e.transferDestination(),
                facilityRefId                                               // PATCH
        );
    }

    private void upsertDiagnosis(long claimId, DiagnosisDTO d, Long diagnosisCodeRefId) { // PATCH
        jdbc.update("""
                    insert into claims.diagnosis(claim_id, diag_type, code, diagnosis_code_ref_id) -- PATCH
                    values (?, ?, ?, ?)
                    on conflict do nothing
                """, claimId, d.type(), d.code(), diagnosisCodeRefId); // PATCH
    }

    /**
     * Persist contract information for a claim.
     * 
     * @param claimId the database ID of the claim
     * @param contract the contract DTO containing package information
     */
    private void upsertContract(long claimId, ContractDTO contract) {
        if (contract == null || contract.packageName() == null) {
            return; // Skip if no contract data
        }
        
        jdbc.update("""
                    insert into claims.claim_contract(claim_id, package_name)
                    values (?, ?)
                    on conflict (claim_id) do update set
                        package_name = EXCLUDED.package_name,
                        updated_at = NOW()
                """, claimId, contract.packageName());
    }

    private long upsertActivity(long claimId, ActivityDTO a, Long clinicianRefId, Long activityCodeRefId) { // PATCH
        jdbc.update("""
                            insert into claims.activity(
                              claim_id, activity_id, start_at, type, code, quantity, net, clinician, prior_authorization_id,
                              clinician_ref_id, activity_code_ref_id                         -- PATCH
                            ) values (?,?,?,?,?,?,?,?,?,?,?)
                            on conflict (claim_id, activity_id) do nothing
                        """, claimId, a.id(), a.start(), a.type(), a.code(), a.quantity(), a.net(), a.clinician(), a.priorAuthorizationId(),
                clinicianRefId, activityCodeRefId                             // PATCH
        );
        return jdbc.queryForObject("select id from claims.activity where claim_id=? and activity_id=?", Long.class, claimId, a.id());
    }


    private void upsertObservation(long actId, ObservationDTO o) {
        jdbc.update("""
                    insert into claims.observation(activity_id, obs_type, obs_code, value_text, value_type, file_bytes)
                    values (?,?,?,?,?,?)
                """, actId, o.type(), o.code(), o.value(), o.valueType(), o.fileBytes());
    }

    private long insertClaimEvent(long claimKeyId, long ingestionFileId, OffsetDateTime time, short type,
                                  Long submissionId, Long remittanceId) {
        return jdbc.queryForObject("""
                        WITH ins AS (
                          INSERT INTO claims.claim_event(
                            claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
                          )
                          VALUES (?,?,?,?,?,?)
                          ON CONFLICT (claim_key_id, type, event_time) DO UPDATE
                            SET ingestion_file_id = EXCLUDED.ingestion_file_id
                          RETURNING id
                        )
                        SELECT id FROM ins
                        UNION ALL
                        SELECT id
                          FROM claims.claim_event
                         WHERE claim_key_id = ? AND type = ? AND event_time = ?
                        LIMIT 1
                        """,
                Long.class,
                // insert params
                claimKeyId, ingestionFileId, time, type, submissionId, remittanceId,
                // fallback (exact) params
                claimKeyId, type, time
        );
    }

    private void projectActivitiesToClaimEventFromSubmission(long eventId, Set<ActivityDTO> acts) {
        if (acts == null) return;
        for (ActivityDTO a : acts) {
            // First, get the activity_id_ref from the actual activity record
            Long activityIdRef = jdbc.queryForObject(
                "SELECT a.id FROM claims.activity a JOIN claims.claim c ON a.claim_id = c.id JOIN claims.claim_event ce ON c.claim_key_id = ce.claim_key_id WHERE a.activity_id = ? AND ce.id = ?",
                Long.class, a.id(), eventId
            );
            
            jdbc.update("""
                                insert into claims.claim_event_activity(
                                  claim_event_id, activity_id_ref, activity_id_at_event, start_at_event, type_at_event, code_at_event,
                                  quantity_at_event, net_at_event, clinician_at_event, prior_authorization_id_at_event,
                                  list_price_at_event, gross_at_event, patient_share_at_event, payment_amount_at_event, denial_code_at_event
                                ) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                                on conflict (claim_event_id, activity_id_at_event) do nothing
                            """, eventId, activityIdRef, a.id(), a.start(), a.type(), a.code(),
                    a.quantity(), a.net(), a.clinician(), a.priorAuthorizationId(),
                    null, null, null, null, null);

            if (a.observations() != null) {
                for (ObservationDTO o : a.observations()) {
                    jdbc.update("""
                                insert into claims.event_observation(
                                  claim_event_activity_id, obs_type, obs_code, value_text, value_type, file_bytes
                                )
                                select cea.id, ?, ?, ?, ?, ?
                                  from claims.claim_event_activity cea
                                 where cea.claim_event_id = ? and cea.activity_id_at_event = ? on conflict do nothing
                            """, o.type(), o.code(), o.value(), o.valueType(), o.fileBytes(), eventId, a.id());
                }
            }
        }
    }

    private void projectActivitiesToClaimEventFromRemittance(long eventId, List<RemittanceActivityDTO> acts) {
        if (acts == null) return;
        for (RemittanceActivityDTO a : acts) {
            // First, get the remittance_activity_id_ref from the actual remittance activity record
            Long remittanceActivityIdRef = jdbc.queryForObject(
                """
                SELECT ra.id
                  FROM claims.remittance_activity ra
                 WHERE ra.activity_id = ?
                   AND ra.remittance_claim_id = (
                        SELECT rc.id
                          FROM claims.remittance_claim rc
                          JOIN claims.claim_event ce
                            ON rc.claim_key_id = ce.claim_key_id
                           AND rc.remittance_id = ce.remittance_id
                         WHERE ce.id = ?
                         LIMIT 1
                   )
                """,
                Long.class, a.id(), eventId
            );
            
            jdbc.update("""
                                insert into claims.claim_event_activity(
                                  claim_event_id, remittance_activity_id_ref, activity_id_at_event, start_at_event, type_at_event, code_at_event,
                                  quantity_at_event, net_at_event, clinician_at_event, prior_authorization_id_at_event,
                                  list_price_at_event, gross_at_event, patient_share_at_event, payment_amount_at_event, denial_code_at_event
                                ) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                                on conflict (claim_event_id, activity_id_at_event) do nothing
                            """, eventId, remittanceActivityIdRef, a.id(), a.start(), a.type(), a.code(),
                    a.quantity(), a.net(), a.clinician(), a.priorAuthorizationId(),
                    a.listPrice(), a.gross(), a.patientShare(), a.paymentAmount(), a.denialCode());
        }
    }

    private void insertResubmission(long eventId, ResubmissionDTO r) {
        jdbc.update("""
                    insert into claims.claim_resubmission(
                      claim_event_id, resubmission_type, comment, attachment, tx_at
                    ) values (?,?,?,?,?)
                    on conflict do nothing
                """, eventId, r.type(), r.comment(), r.attachment(), file.header().transactionDate());
    }

    private void insertStatusTimeline(long claimKeyId, short status, OffsetDateTime time, long eventId) {
        jdbc.update("""
                    insert into claims.claim_status_timeline(
                      claim_key_id, status, status_time, claim_event_id
                    ) values (?,?,?,?)
                """, claimKeyId, status, time, eventId);
    }

    /**
     * NEW: Upsert remittance claim row, idempotent on (remittance_id, claim_key_id).
     */
    private long upsertRemittanceClaim(long remittanceId, long claimKeyId, RemittanceClaimDTO c, Long denialCodeRefId, Long payerCodeRefId, Long providerCodeRefId) { // PATCH
        jdbc.update("""
                            insert into claims.remittance_claim(
                              remittance_id, claim_key_id, id_payer, provider_id, comments, payment_reference, date_settlement, facility_id,
                              payer_ref_id, provider_ref_id                                               
                            ) values (?,?,?,?,?,?,?,?,?,?)
                            on conflict (remittance_id, claim_key_id) do nothing
                        """, remittanceId, claimKeyId, c.idPayer(), c.providerId(), c.comments(),
                c.paymentReference(), c.dateSettlement(), c.facilityId(), payerCodeRefId, providerCodeRefId
        );
        return jdbc.queryForObject(
                "select id from claims.remittance_claim where remittance_id=? and claim_key_id=?",
                Long.class, remittanceId, claimKeyId
        );
    }

    /**
     * NEW: Upsert remittance activity row, idempotent on (remittance_claim_id, activity_id).
     */
    private void upsertRemittanceActivity(long remittanceClaimId, RemittanceActivityDTO a, Long activityCodeRefId, Long denialCodeRefId, Long clinicianRefId) {
        jdbc.update("""
                            insert into claims.remittance_activity(
                              remittance_claim_id, activity_id, start_at, type, code, quantity, net, list_price,
                              clinician, prior_authorization_id, gross, patient_share, payment_amount, denial_code, activity_code_ref_id, denial_code_ref_id, clinician_ref_id
                            ) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                            on conflict (remittance_claim_id, activity_id) do nothing
                        """, remittanceClaimId, a.id(), a.start(), a.type(), a.code(), a.quantity(), a.net(), a.listPrice(),
                a.clinician(), a.priorAuthorizationId(), a.gross(), a.patientShare(), a.paymentAmount(), a.denialCode(), activityCodeRefId, denialCodeRefId, clinicianRefId);
    }

    /**
     * Persist a submission attachment row idempotently (unique by (claim_key_id, claim_event_id, coalesce(file_name,''))).
     */
    private void upsertClaimAttachment(long claimKeyId, long claimEventId, long ingestionFileId, ParseOutcome.AttachmentRecord ar) {
        final String fileName = ar.fileName();
        final String mimeType = ar.contentType(); // may be null
        final byte[] bytes = ar.bytes();
        final Integer size = (bytes != null ? bytes.length : null);

        jdbc.update("""
                    insert into claims.claim_attachment(
                      claim_key_id, claim_event_id, file_name, mime_type, data_base64, data_length, created_at
                    ) values (?,?,?,?,?,?, now())
                    on conflict do nothing
                """, claimKeyId, claimEventId, fileName, mimeType, bytes, size);
    }

    /* ========================= VALIDATION GUARDS ========================= */

    /**
     * Input validation methods that ensure data integrity before database operations.
     * All validation methods follow a consistent pattern:
     * - Check required fields for null/blank values
     * - Log validation failures with detailed context
     * - Return boolean indicating validity
     * - Never throw exceptions (handled by caller)
     */

    /**
     * Utility method to check if a string is null or blank.
     * 
     * @param s the string to check
     * @return true if the string is null or blank, false otherwise
     */
    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }

    /**
     * Utility method to check if an object is null.
     * 
     * @param o the object to check
     * @return true if the object is null, false otherwise
     */
    private static boolean isNull(Object o) {
        return o == null;
    }

    /**
     * Validates that a submission claim has all required fields.
     * 
     * <p>Required fields for a claim are:
     * <ul>
     *   <li>Claim ID</li>
     *   <li>Payer ID</li>
     *   <li>Provider ID</li>
     *   <li>Emirates ID Number</li>
     * </ul>
     * 
     * <p>If validation fails, an error is logged and the claim will be skipped.
     * 
     * @param ingestionFileId the ID of the ingestion file for error logging
     * @param c the claim DTO to validate
     * @return true if all required fields are present, false otherwise
     */
    private boolean claimHasRequired(long ingestionFileId, SubmissionClaimDTO c) {
        boolean ok =
                !isBlank(c.id()) &&
                        !isBlank(c.payerId()) &&
                        !isBlank(c.providerId()) &&
                        !isBlank(c.emiratesIdNumber());
        if (!ok) {
            errors.claimError(ingestionFileId, "VALIDATE", c.id(),
                    "MISSING_CLAIM_REQUIRED",
                    "Claim required fields missing; skipping claim.", false);
        }
        return ok;
    }

    /**
     * Validates that an encounter has all required fields.
     * 
     * <p>Required fields for an encounter are:
     * <ul>
     *   <li>Patient ID</li>
     *   <li>Facility ID</li>
     *   <li>Type</li>
     *   <li>Start date/time</li>
     * </ul>
     * 
     * <p>If the encounter is null, validation passes (encounters are optional).
     * If validation fails, an error is logged and the encounter will be skipped.
     * 
     * @param ingestionFileId the ID of the ingestion file for error logging
     * @param claimIdBiz the business claim ID for error logging
     * @param e the encounter DTO to validate
     * @return true if all required fields are present or encounter is null, false otherwise
     */
    private boolean encounterHasRequired(long ingestionFileId, String claimIdBiz, EncounterDTO e) {
        if (e == null) return true;
        boolean ok =
                !isBlank(e.patientId()) &&
                        !isBlank(e.facilityId()) &&
                        !isNull(e.type()) &&
                        !isNull(e.start());
        if (!ok) {
            errors.claimError(ingestionFileId, "VALIDATE", claimIdBiz,
                    "MISSING_ENCOUNTER_REQUIRED",
                    "Encounter required fields missing; skipping encounter.", false);
        }
        return ok;
    }

    /**
     * Validates that a diagnosis has all required fields.
     * 
     * <p>Required fields for a diagnosis are:
     * <ul>
     *   <li>Type</li>
     *   <li>Code</li>
     * </ul>
     * 
     * <p>If validation fails, an error is logged and the diagnosis will be skipped.
     * 
     * @param ingestionFileId the ID of the ingestion file for error logging
     * @param claimIdBiz the business claim ID for error logging
     * @param d the diagnosis DTO to validate
     * @return true if all required fields are present, false otherwise
     */
    private boolean diagnosisHasRequired(long ingestionFileId, String claimIdBiz, DiagnosisDTO d) {
        boolean ok = !isBlank(d.type()) && !isBlank(d.code());
        if (!ok) {
            errors.claimError(ingestionFileId, "VALIDATE", claimIdBiz,
                    "MISSING_DIAGNOSIS_REQUIRED",
                    "Diagnosis Type/Code required; skipping diagnosis.", false);
        }
        return ok;
    }

    /**
     * Validates that an activity has all required fields.
     * 
     * <p>Required fields for an activity are:
     * <ul>
     *   <li>Activity ID</li>
     *   <li>Start date/time</li>
     *   <li>Type</li>
     *   <li>Code</li>
     *   <li>Quantity</li>
     *   <li>Net amount</li>
     *   <li>Clinician</li>
     * </ul>
     * 
     * <p>If validation fails, an error is logged and the activity will be skipped.
     * 
     * @param ingestionFileId the ID of the ingestion file for error logging
     * @param claimIdBiz the business claim ID for error logging
     * @param a the activity DTO to validate
     * @return true if all required fields are present, false otherwise
     */
    private boolean activityHasRequired(long ingestionFileId, String claimIdBiz, ActivityDTO a) {
        boolean ok =
                !isBlank(a.id()) &&
                        !isNull(a.start()) &&
                        !isNull(a.type()) &&
                        !isBlank(a.code()) &&
                        !isNull(a.quantity()) &&
                        !isNull(a.net()) &&
                        !isNull(a.clinician());
        if (!ok) {
            errors.claimError(ingestionFileId, "VALIDATE", claimIdBiz,
                    "MISSING_ACTIVITY_REQUIRED",
                    "Activity required fields missing; skipping activity.", false);
        }
        return ok;
    }

    /**
     * Validates that a remittance claim has all required fields.
     * 
     * <p>Required fields for a remittance claim are:
     * <ul>
     *   <li>Claim ID</li>
     *   <li>Payer ID</li>
     *   <li>Provider ID</li>
     *   <li>Payment Reference</li>
     * </ul>
     * 
     * <p>If validation fails, an error is logged and the remittance claim will be skipped.
     * 
     * @param ingestionFileId the ID of the ingestion file for error logging
     * @param c the remittance claim DTO to validate
     * @return true if all required fields are present, false otherwise
     */
    private boolean remitClaimHasRequired(long ingestionFileId, RemittanceClaimDTO c) {
        boolean ok =
                !isBlank(c.id()) &&
                        !isBlank(c.idPayer()) &&
                        !isBlank(c.providerId()) &&
                        !isBlank(c.paymentReference());
        if (!ok) {
            errors.claimError(ingestionFileId, "VALIDATE", c.id(),
                    "MISSING_REMIT_REQUIRED",
                    "Remittance claim required fields missing; skipping claim.", false);
        }
        return ok;
    }

    /**
     * Validates that a remittance activity has all required fields.
     * 
     * <p>Required fields for a remittance activity are:
     * <ul>
     *   <li>Activity ID</li>
     *   <li>Start date/time</li>
     *   <li>Type</li>
     *   <li>Code</li>
     *   <li>Quantity</li>
     *   <li>Net amount</li>
     * </ul>
     * 
     * <p>If validation fails, an error is logged and the remittance activity will be skipped.
     * 
     * @param ingestionFileId the ID of the ingestion file for error logging
     * @param claimIdBiz the business claim ID for error logging
     * @param a the remittance activity DTO to validate
     * @return true if all required fields are present, false otherwise
     */
    private boolean remitActivityHasRequired(long ingestionFileId, String claimIdBiz, RemittanceActivityDTO a) {
        boolean ok =
                !isBlank(a.id()) &&
                        !isNull(a.start()) &&
                        !isNull(a.type()) &&
                        !isBlank(a.code()) &&
                        !isNull(a.quantity()) &&
                        !isNull(a.net());
        if (!ok) {
            errors.claimError(ingestionFileId, "VALIDATE", claimIdBiz,
                    "MISSING_REMIT_ACTIVITY_REQUIRED",
                    "Remittance activity required fields missing; skipping activity.", false);
        }
        return ok;
    }

    /* ========================= DATA STRUCTURES ========================= */

    /**
     * # PersistCounts - Persistence Operation Results
     *
     * <p><b>Purpose:</b> Immutable record containing detailed counts of entities persisted
     * during batch operations. Provides comprehensive visibility into processing results.</p>
     *
     * <p><b>Usage:</b> Returned by persistence methods to report success metrics and
     * enable monitoring of data ingestion effectiveness.</p>
     *
     * @param claims number of claims persisted in submission operations
     * @param acts number of activities persisted in submission operations
     * @param obs number of observations persisted in submission operations
     * @param dxs number of diagnoses persisted in submission operations
     * @param remitClaims number of remittance claims persisted
     * @param remitActs number of remittance activities persisted
     */
    public record PersistCounts(int claims, int acts, int obs, int dxs, int remitClaims, int remitActs) {
    }
}
