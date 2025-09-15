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

@Slf4j
@Service
@RequiredArgsConstructor
public class PersistService {

    private final JdbcTemplate jdbc;
    private final ErrorLogger errors;
    private final RefCodeResolver refCodeResolver;

    /* ========================= SUBMISSION PATH ========================= */

    /**
     * Back-compat overload if a caller doesn’t pass attachments.
     */
    @Transactional
    public PersistCounts persistSubmission(long ingestionFileId, SubmissionDTO file) {
        return persistSubmission(ingestionFileId, file, List.of());
    }

    /**
     * Persist a parsed submission file (with optional attachments collected by the parser).
     * Guards ensure we never violate NOT NULL/UNIQUES. Bad rows are logged+skipped, not thrown.
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

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    private BigDecimal fetchSubmissionNetRequested(long claimKeyId) {
        return jdbc.queryForObject("""
                    select coalesce(sum(a.net), 0.0)
                      from claims.claim c
                      join claims.activity a on a.claim_id = c.id
                     where c.claim_key_id = ?
                """, BigDecimal.class, claimKeyId);
    }

    private BigDecimal fetchRemittancePaidAmount(long remittanceClaimId) {
        return jdbc.queryForObject("""
                    select coalesce(sum(ra.payment_amount), 0.0)
                      from claims.remittance_activity ra
                     where ra.remittance_claim_id = ?
                """, BigDecimal.class, remittanceClaimId);
    }

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
                            on conflict do nothing
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
                    on conflict do nothing
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
            jdbc.update("""
                                insert into claims.claim_event_activity(
                                  claim_event_id, activity_id_at_event, start_at_event, type_at_event, code_at_event,
                                  quantity_at_event, net_at_event, clinician_at_event, prior_authorization_id_at_event,
                                  list_price_at_event, gross_at_event, patient_share_at_event, payment_amount_at_event, denial_code_at_event
                                ) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                                on conflict (claim_event_id, activity_id_at_event) do nothing
                            """, eventId, a.id(), a.start(), a.type(), a.code(),
                    a.quantity(), a.net(), a.clinician(), a.priorAuthorizationId(),
                    null, null, null, null, null);

            if (a.observations() != null) {
                for (ObservationDTO o : a.observations()) {
                    jdbc.update("""
                                insert into claims.event_observation(
                                  claim_event_activity_id, obs_type, obs_code, value_text, value_type
                                )
                                select cea.id, ?, ?, ?, ?
                                  from claims.claim_event_activity cea
                                 where cea.claim_event_id = ? and cea.activity_id_at_event = ? on conflict do nothing
                            """, o.type(), o.code(), o.value(), o.valueType(), eventId, a.id());
                }
            }
        }
    }

    private void projectActivitiesToClaimEventFromRemittance(long eventId, List<RemittanceActivityDTO> acts) {
        if (acts == null) return;
        for (RemittanceActivityDTO a : acts) {
            jdbc.update("""
                                insert into claims.claim_event_activity(
                                  claim_event_id, activity_id_at_event, start_at_event, type_at_event, code_at_event,
                                  quantity_at_event, net_at_event, clinician_at_event, prior_authorization_id_at_event,
                                  list_price_at_event, gross_at_event, patient_share_at_event, payment_amount_at_event, denial_code_at_event
                                ) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                                on conflict (claim_event_id, activity_id_at_event) do nothing
                            """, eventId, a.id(), a.start(), a.type(), a.code(),
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
                    on conflict do nothing
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
                    on conflict (claim_key_id, claim_event_id, coalesce(file_name,'')) do nothing
                """, claimKeyId, claimEventId, fileName, mimeType, bytes, size);
    }

    /* ========================= VALIDATION GUARDS ========================= */
    // PATCH: all guards below only check fields you already use in inserts. They log & return false; caller skips row.

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }

    private static boolean isNull(Object o) {
        return o == null;
    }

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

    private boolean diagnosisHasRequired(long ingestionFileId, String claimIdBiz, DiagnosisDTO d) {
        boolean ok = !isBlank(d.type()) && !isBlank(d.code());
        if (!ok) {
            errors.claimError(ingestionFileId, "VALIDATE", claimIdBiz,
                    "MISSING_DIAGNOSIS_REQUIRED",
                    "Diagnosis Type/Code required; skipping diagnosis.", false);
        }
        return ok;
    }

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

    public record PersistCounts(int claims, int acts, int obs, int dxs, int remitClaims, int remitActs) {
    }
}
