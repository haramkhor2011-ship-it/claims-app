package com.acme.claims.ingestion.persist;

import com.acme.claims.domain.model.dto.*;
import com.acme.claims.ingestion.audit.ErrorLogger;
import com.acme.claims.ingestion.parser.ParseOutcome;
import com.acme.claims.refdata.RefCodeResolver;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.Assert;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Objects;
import java.util.Set;

/**
 * Service responsible for persisting claims data into the database.
 * 
 * <p>This service handles two main data flows:
 * <ul>
 *   <li><strong>Submission Path:</strong> Persists claim submissions with activities, diagnoses, and encounters</li>
 *   <li><strong>Remittance Path:</strong> Persists remittance advice data and updates claim statuses</li>
 * </ul>
 * 
 * <p>The service ensures data integrity by:
 * <ul>
 *   <li>Validating required fields before persistence</li>
 *   <li>Resolving reference data codes to foreign key IDs</li>
 *   <li>Handling duplicate submissions gracefully</li>
 *   <li>Maintaining audit trails for all operations</li>
 *   <li>Using transactional boundaries to ensure consistency</li>
 * </ul>
 * 
 * <p>Key features:
 * <ul>
 *   <li>Idempotent operations using ON CONFLICT clauses</li>
 *   <li>Automatic reference data resolution and insertion</li>
 *   <li>Comprehensive error logging and validation</li>
 *   <li>Status timeline tracking for claims</li>
 *   <li>Support for attachments and resubmissions</li>
 * </ul>
 * 
 * @author Claims Team
 * @since 1.0
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
     * Persists a parsed submission file with optional attachments.
     * 
     * <p>This method processes a complete claim submission including:
     * <ul>
     *   <li>Claim header information</li>
     *   <li>Activities with observations</li>
     *   <li>Diagnoses</li>
     *   <li>Encounters</li>
     *   <li>Resubmissions (if present)</li>
     *   <li>Attachments (if provided)</li>
     * </ul>
     * 
     * <p>The method ensures data integrity by:
     * <ul>
     *   <li>Validating required fields before persistence</li>
     *   <li>Resolving reference data codes to database IDs</li>
     *   <li>Handling duplicate submissions appropriately</li>
     *   <li>Logging errors for invalid data without failing the entire batch</li>
     * </ul>
     * 
     * <p>All operations are performed within a single transaction to ensure consistency.
     * If any individual claim fails, it is logged and skipped, allowing other claims to proceed.
     * 
     * @param ingestionFileId the ID of the ingestion file being processed
     * @param file the parsed submission data containing claims and metadata
     * @param attachments optional list of attachments associated with the submission
     * @return PersistCounts containing the number of entities persisted
     * @throws IllegalArgumentException if required parameters are null or invalid
     */
    @Transactional
    public PersistCounts persistSubmission(long ingestionFileId, SubmissionDTO file, List<ParseOutcome.AttachmentRecord> attachments) {
        final OffsetDateTime now = OffsetDateTime.now();

        final Long submissionId = jdbc.queryForObject(
                "insert into claims.submission(ingestion_file_id) values (?) returning id",
                Long.class, ingestionFileId
        );

        int claims = 0, acts = 0, obs = 0, dxs = 0;
        int skippedDup = 0, skippedInvalidClaim = 0;

        for (SubmissionClaimDTO c : file.claims()) {
            final String claimIdBiz = c.id();
            try {
                // hard guard at claim level (before any DB writes)
                if (!claimHasRequired(ingestionFileId, c)) {
                    skippedInvalidClaim++;
                    continue; // skip this claim entirely; logged above
                }

                // Duplicate prior SUBMISSION and current has no <Resubmission> → skip & log
                if (isAlreadySubmitted(claimIdBiz) && c.resubmission() == null) {
                    log.info("Claim already submitted : {}", claimIdBiz);
                    errors.claimError(ingestionFileId, "VALIDATE", claimIdBiz, "DUP_SUBMISSION_NO_RESUB",
                            "Duplicate Claim.Submission without <Resubmission>; skipped.", false);
                    skippedDup++;
                    continue;
                }

                // Upsert core graph
                final long claimKeyId = upsertClaimKey(claimIdBiz);

                // resolve ref IDs (inserting into ref tables + auditing if missing)
                final Long payerRefId = (c.payerId() == null) ? null
                        : refCodeResolver.resolvePayer(c.payerId(), null, "SYSTEM", ingestionFileId, c.id()).orElse(null);
                final Long providerRefId = (c.providerId() == null) ? null
                        : refCodeResolver.resolveProvider(c.providerId(), null, "SYSTEM", ingestionFileId, c.id()).orElse(null);

                final long claimId = upsertClaim(claimKeyId, submissionId, c, payerRefId, providerRefId); // PATCH: new params

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
                    upsertEncounter(claimId, c.encounter(), facilityRefId); // PATCH: pass ref id
                }

                // Diagnoses (optional)
                if (c.diagnoses() != null) {
                    for (DiagnosisDTO d : c.diagnoses()) {
                        if (diagnosisHasRequired(ingestionFileId, claimIdBiz, d)) {
                            // PATCH: resolve diagnosis ref id
                            final Long diagnosisRefId = (d.code() == null) ? null
                                    : refCodeResolver.resolveDiagnosisCode(d.code(), null, null, "SYSTEM", ingestionFileId, c.id()).orElse(null);
                            upsertDiagnosis(claimId, d, diagnosisRefId); // PATCH
                            dxs++;

                        }
                    }
                }

                // Activities (optional)
                if (c.activities() != null) {
                    for (ActivityDTO a : c.activities()) {
                        if (!activityHasRequired(ingestionFileId, claimIdBiz, a)) continue; // logged+skip
                        // resolve activity/clinician refs
                        final Long activityCodeRefId = (a.code() == null) ? null
                                : refCodeResolver.resolveActivityCode(a.code(), null, null, "SYSTEM", ingestionFileId, c.id()).orElse(null);
                        final Long clinicianRefId = (a.clinician() == null) ? null
                                : refCodeResolver.resolveClinician(a.clinician(), null, null, "SYSTEM", ingestionFileId, c.id()).orElse(null);

                        long actId = upsertActivity(claimId, a, clinicianRefId, activityCodeRefId); // PATCH

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
                projectActivitiesToClaimEventFromSubmission(ev1, c.activities());
                insertStatusTimeline(claimKeyId, (short) 1, file.header().transactionDate(), ev1);

                if (c.resubmission() != null) {
                    long ev2 = insertClaimEvent(claimKeyId, ingestionFileId, file.header().transactionDate(), (short) 2, submissionId, null);
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

                claims++; // count only persisted claims
            } catch (Exception claimEx) {
                // NEW: contain the blast radius to this claim
                errors.claimError(ingestionFileId, "PERSIST", claimIdBiz,
                        "CLAIM_PERSIST_FAIL", claimEx.getMessage(), false);
                // optionally log debug stack:
                log.debug("claim persist failed claimId={} : ", claimIdBiz, claimEx);
                // continue with next claim
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

    /* ========================= REMITTANCE PATH ========================= */

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
     * @return PersistCounts containing the number of remittance entities persisted
     * @throws IllegalArgumentException if required parameters are null or invalid
     */
    @Transactional
    public PersistCounts persistRemittance(long ingestionFileId, RemittanceAdviceDTO file) {
        final Long remittanceId = jdbc.queryForObject(
                "insert into claims.remittance(ingestion_file_id) values (?) returning id",
                Long.class, ingestionFileId
        );

        int rClaims = 0, rActs = 0, skippedInvalidRemitClaim = 0;

        for (RemittanceClaimDTO c : file.claims()) {
            // guard remittance-claim level (ID, IDPayer, ProviderID, PaymentReference as used)
            if (!remitClaimHasRequired(ingestionFileId, c)) {
                skippedInvalidRemitClaim++;
                continue; // logged above
            }

            final long claimKeyId = upsertClaimKey(c.id());
            try {
                // resolve denial code ref id for the claim scope (if any denial present at claim level)
                final Long denialRefId = (c.denialCode() == null) ? null
                        : refCodeResolver.resolveDenialCode(c.denialCode(), null, c.idPayer(), "SYSTEM", ingestionFileId, c.id())
                        .orElse(null);
                final Long payerRefId = (c.idPayer() == null) ? null
                        : refCodeResolver.resolvePayer(c.idPayer(), null, "SYSTEM", ingestionFileId, c.id())
                        .orElse(null);
                final Long providerRefId = (c.providerId() == null) ? null
                        : refCodeResolver.resolveProvider(c.providerId(), null, "SYSTEM", ingestionFileId, c.id())
                        .orElse(null);

                final long rcId = upsertRemittanceClaim(remittanceId, claimKeyId, c, denialRefId, payerRefId, providerRefId); // PATCH


                if (c.activities() != null) {
                    for (RemittanceActivityDTO a : c.activities()) {
                        if (!remitActivityHasRequired(ingestionFileId, c.id(), a)) continue; // logged+skip
                        upsertRemittanceActivity(rcId, a);
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
                final short SUBMITTED = 1, RESUBMITTED = 2, PAID = 3, PARTIALLY_PAID = 4, REJECTED = 5; // doc’d types
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

                rClaims++;
            } catch (Exception claimEx) {
                // NEW: contain the blast radius to this claim
                errors.claimError(ingestionFileId, "PERSIST", c.id(),
                        "CLAIM_PERSIST_FAIL", claimEx.getMessage(), false);
                // optionally log debug stack:
                log.info(" Remittance claim persist failed claimId={} : ", c.id(), claimEx);
                // continue with next claim
            }
        }

        if (skippedInvalidRemitClaim > 0) {
            errors.fileError(ingestionFileId, "VALIDATE", "MISSING_REMIT_REQUIRED_SUMMARY",
                    "Skipped " + skippedInvalidRemitClaim + " invalid remittance claim(s) due to missing requireds.", false);
        }

        return new PersistCounts(0, 0, 0, 0, rClaims, rActs);
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

    /* ========================= HELPERS (UPserts & Inserts) ========================= */

    /**
     * Checks if a claim has already been submitted (has a submission event).
     * 
     * <p>This method determines if a claim with the given business ID has
     * already been submitted by checking for the existence of a claim event
     * with type 1 (SUBMITTED).
     * 
     * @param claimIdBiz the business claim ID to check
     * @return true if the claim has already been submitted, false otherwise
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
     * Creates or retrieves a claim key record for the given business claim ID.
     * 
     * <p>This method performs an idempotent upsert operation using PostgreSQL's
     * ON CONFLICT clause. It will either insert a new claim key record or
     * return the ID of an existing one.
     * 
     * <p>The operation uses a single database round-trip with a CTE (Common Table Expression)
     * to handle the insert-or-select logic efficiently.
     * 
     * @param claimIdBiz the business claim ID to upsert
     * @return the database ID of the claim key record
     * @throws IllegalArgumentException if claimIdBiz is null or blank
     */
    private long upsertClaimKey(String claimIdBiz) {
        Assert.hasText(claimIdBiz, "claimIdBiz must not be blank"); // fast guard

        // Single round-trip, no UPDATE on conflict:
        // 1) Try INSERT, capture id in CTE 'ins'
        // 2) If nothing inserted (conflict), select existing id
        final String sql = """
                WITH ins AS (
                  INSERT INTO claims.claim_key (claim_id)
                  VALUES (?)
                  ON CONFLICT (claim_id) DO NOTHING
                  RETURNING id
                )
                SELECT id FROM ins
                UNION ALL
                SELECT id FROM claims.claim_key WHERE claim_id = ?
                LIMIT 1
                """;

        // Returns the inserted id, or the existing id if conflict occurred
        return jdbc.queryForObject(sql, Long.class, claimIdBiz, claimIdBiz);
    }


    private long upsertClaim(long claimKeyId, long submissionId, SubmissionClaimDTO c,
                             Long payerRefId, Long providerRefId) { // added ref IDs
        jdbc.update("""
                            insert into claims.claim(
                              claim_key_id, submission_id,
                              id_payer, member_id, payer_id, provider_id, emirates_id_number, gross, patient_share, net,
                              payer_ref_id, provider_ref_id, comments                                 -- PATCH: new columns
                            ) values (?,?,?,?,?,?,?,?,?,?,?,?,?)
                            on conflict (claim_key_id) do nothing
                        """, claimKeyId, submissionId,
                c.idPayer(), c.memberId(), c.payerId(), c.providerId(), c.emiratesIdNumber(),
                c.gross(), c.patientShare(), c.net(),
                payerRefId, providerRefId, c.comments()                                     // PATCH: new args
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
                "SELECT id FROM claims.remittance_activity WHERE activity_id = ? AND remittance_claim_id = (SELECT rc.id FROM claims.remittance_claim rc JOIN claims.claim_event ce ON rc.claim_key_id = ce.claim_key_id WHERE ce.id = ?)",
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
                      claim_event_id, resubmission_type, comment, attachment
                    ) values (?,?,?,?)
                    on conflict do nothing
                """, eventId, r.type(), r.comment(), r.attachment());
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
                              remittance_id, claim_key_id, id_payer, provider_id, denial_code, payment_reference, date_settlement, facility_id,
                              denial_code_ref_id,payer_ref_id,provider_ref_id                                               -- PATCH
                            ) values (?,?,?,?,?,?,?,?,?,?,?)
                            on conflict (remittance_id, claim_key_id) do nothing
                        """, remittanceId, claimKeyId, c.idPayer(), c.providerId(), c.denialCode(),
                c.paymentReference(), c.dateSettlement(), c.facilityId(),
                denialCodeRefId, payerCodeRefId, providerCodeRefId
        );
        return jdbc.queryForObject(
                "select id from claims.remittance_claim where remittance_id=? and claim_key_id=?",
                Long.class, remittanceId, claimKeyId
        );
    }

    /**
     * NEW: Upsert remittance activity row, idempotent on (remittance_claim_id, activity_id).
     */
    private void upsertRemittanceActivity(long remittanceClaimId, RemittanceActivityDTO a) {
        jdbc.update("""
                            insert into claims.remittance_activity(
                              remittance_claim_id, activity_id, start_at, type, code, quantity, net, list_price,
                              clinician, prior_authorization_id, gross, patient_share, payment_amount, denial_code
                            ) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                            on conflict (remittance_claim_id, activity_id) do nothing
                        """, remittanceClaimId, a.id(), a.start(), a.type(), a.code(), a.quantity(), a.net(), a.listPrice(),
                a.clinician(), a.priorAuthorizationId(), a.gross(), a.patientShare(), a.paymentAmount(), a.denialCode());
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
    // PATCH: all guards below only check fields you already use in inserts. They log & return false; caller skips row.

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

    /* ========================= COUNTS ========================= */

    /**
     * Record containing counts of persisted entities for reporting purposes.
     * 
     * <p>This record tracks the number of various entities that were successfully
     * persisted during a batch operation, allowing callers to understand the
     * scope and success of the persistence operation.
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
