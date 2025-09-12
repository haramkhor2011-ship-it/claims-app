// FILE: src/main/java/com/acme/claims/ingestion/dto/submission/SubmissionClaimDTO.java
// Version: v1.0.0
// XSD: Claim(ID, IDPayer?, MemberID?, PayerID, ProviderID, EmiratesIDNumber, Gross, PatientShare, Net, Encounter?, Diagnosis+, Activity+, Resubmission?, Contract?)  :contentReference[oaicite:4]{index=4}
package com.acme.claims.domain.model.dto;

import java.math.BigDecimal;
import java.util.Set;

public record SubmissionClaimDTO(
        String id,
        String idPayer,
        String memberId,
        String payerId,
        String providerId,
        String emiratesIdNumber,
        BigDecimal gross,
        BigDecimal patientShare,
        BigDecimal net,
        String comments,
        EncounterDTO encounter,                     // nullable
        Set<DiagnosisDTO> diagnoses,
        Set<ActivityDTO> activities,
        ResubmissionDTO resubmission,               // nullable
        ContractDTO contract                        // nullable
) {}
