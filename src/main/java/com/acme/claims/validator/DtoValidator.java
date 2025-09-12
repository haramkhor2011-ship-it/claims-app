// FILE: src/main/java/com/acme/claims/ingestion/validate/DtoValidator.java
// Version: v1.0.0
// Validates required XSD fields and cross-record rules (counts, uniqueness).
// Sources: DHPO XSDs for required minOccurs=1 fields. :contentReference[oaicite:6]{index=6} :contentReference[oaicite:7]{index=7}
package com.acme.claims.validator;

import com.acme.claims.domain.model.dto.*;
import org.springframework.util.CollectionUtils;


import java.util.*;

public class DtoValidator {

    // --- Submission ---
    public void validate(SubmissionDTO dto) {
        if (dto == null) throw new IllegalArgumentException("SubmissionDTO is null");
        var h = dto.header();
        require(h.senderId(), "Header.SenderID");
        require(h.receiverId(), "Header.ReceiverID");
        require(h.transactionDate(), "Header.TransactionDate");
        require(h.dispositionFlag(), "Header.DispositionFlag");

        List<SubmissionClaimDTO> claims = orEmpty(dto.claims());
        if (claims.isEmpty()) fail("RecordCount>0 expected but claims list is empty");
        // if (h.recordCount() != claims.size()) fail("Header.RecordCount != number of Claim elements");

        for (SubmissionClaimDTO c : claims) {
            require(c.id(), "Claim.ID");
            require(c.payerId(), "Claim.PayerID");
            require(c.providerId(), "Claim.ProviderID");
            require(c.emiratesIdNumber(), "Claim.EmiratesIDNumber");
            require(c.gross(), "Claim.Gross");
            require(c.patientShare(), "Claim.PatientShare");
            require(c.net(), "Claim.Net");

            if (c.encounter() != null) {
                var e = c.encounter();
                require(e.facilityId(), "Encounter.FacilityID");
                require(e.type(), "Encounter.Type");
                require(e.patientId(), "Encounter.PatientID");
                require(e.start(), "Encounter.Start");
            }

            if(!CollectionUtils.isEmpty(c.diagnoses())){
                for(var d : c.diagnoses()){
                    require(d.code(), "Diagnoses.Code");
                    require(d.type(), "Diagnoses.Type");
                }
            }

            // Activities (minOccurs=1)
            var acts = orEmpty(c.activities().stream().toList());
            if (acts.isEmpty()) fail("Claim.Activity must have at least one entry for Claim.ID=" + c.id());
            // ensureUnique(acts.stream().map(ActivityDTO::id).toList(), "Activity.ID duplicate in Claim.ID=" + c.id());

            for (ActivityDTO a : acts) {
                require(a.id(), "Activity.ID");
                require(a.start(), "Activity.Start");
                require(a.type(), "Activity.Type");
                require(a.code(), "Activity.Code");
                require(a.quantity(), "Activity.Quantity");
                require(a.net(), "Activity.Net");
                require(a.clinician(), "Activity.Clinician");
                // Observations are optional; when present, Type & Code are required
                for (ObservationDTO o : orEmpty(a.observations().stream().toList())) {
                    require(o.type(), "Observation.Type");
                    require(o.code(), "Observation.Code");
                }
            }
            if (c.resubmission() != null) {
                require(c.resubmission().type(), "Resubmission.Type");
                require(c.resubmission().comment(), "Resubmission.Comment");
                // require(c.resubmission().attachment(), "Resubmission.Attachment");
            }
        }
    }

    // --- Remittance ---
    public void validate(RemittanceAdviceDTO dto) {
        if (dto == null) throw new IllegalArgumentException("RemittanceAdviceDTO is null");
        var h = dto.header();
        require(h.senderId(), "Header.SenderID");
        require(h.receiverId(), "Header.ReceiverID");
        require(h.transactionDate(), "Header.TransactionDate");
        require(h.dispositionFlag(), "Header.DispositionFlag");

        List<RemittanceClaimDTO> claims = orEmpty(dto.claims());
        if (claims.isEmpty()) fail("RecordCount>0 expected but remittance claims list is empty");
        // if (h.recordCount() != claims.size()) fail("Header.RecordCount != number of Remittance Claim elements");

        for (RemittanceClaimDTO c : claims) {
            require(c.id(), "Claim.ID");
            require(c.idPayer(), "Claim.IDPayer");
            require(c.paymentReference(), "Claim.PaymentReference");
            // facilityId is optional per XSD (Encounter/FacilityID is 0..1)  :contentReference[oaicite:8]{index=8}

            var acts = orEmpty(c.activities());
            if (acts.isEmpty()) fail("Remittance Claim.Activity must have at least one entry for Claim.ID=" + c.id());
            ensureUnique(acts.stream().map(RemittanceActivityDTO::id).toList(), "Remittance Activity.ID duplicate in Claim.ID=" + c.id());

            for (RemittanceActivityDTO a : acts) {
                require(a.id(), "Activity.ID");
                require(a.start(), "Activity.Start");
                require(a.type(), "Activity.Type");
                require(a.code(), "Activity.Code");
                require(a.quantity(), "Activity.Quantity");
                require(a.net(), "Activity.Net");
                require(a.clinician(), "Activity.Clinician");
                require(a.paymentAmount(), "Activity.PaymentAmount");
            }
        }
    }

    // --- helpers ---
    private static <T> List<T> orEmpty(List<T> l){ return l==null? List.of() : l; }
    private static void require(Object v, String path){
        if (v==null || (v instanceof String s && s.isBlank()))
            throw new IllegalArgumentException("Required field missing: " + path);
    }
    private static void ensureUnique(List<String> keys, String context){
        Set<String> seen = new HashSet<>();
        for (String k: keys){
            if (k==null) continue;
            if (!seen.add(k)) throw new IllegalArgumentException("Duplicate key: " + k + " (" + context + ")");
        }
    }
    private static void fail(String m){ throw new IllegalArgumentException(m); }
}
