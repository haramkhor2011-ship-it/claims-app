// FILE: src/main/java/com/acme/claims/ingestion/mapper/SubmissionGraphMapper.java
// Version: v1.0.0
// Maps: Submission aggregate → Submission/Claim/Encounter/Diagnosis/Activity/Observation entities
package com.acme.claims.mapper;


import com.acme.claims.domain.model.dto.*;
import com.acme.claims.domain.model.entity.*;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

@Mapper(config = MapStructCentralConfig.class, uses = {})
public interface SubmissionGraphMapper {

    // group row per file
    @Mapping(target="id", ignore = true)
    @Mapping(target="ingestionFile", source="file")
    Submission toSubmission(SubmissionDTO dto, IngestionFile file);

    // claim (requires existing ClaimKey + Submission)
    @Mapping(target="id", ignore = true)
    @Mapping(target="claimKey", source="key")
    @Mapping(target="submission", source="submission")
    @Mapping(target="idPayer", source="dto.idPayer")
    @Mapping(target="memberId", source="dto.memberId")
    @Mapping(target="payerId", source="dto.payerId")
    @Mapping(target="providerId", source="dto.providerId")
    @Mapping(target="emiratesIdNumber", source="dto.emiratesIdNumber")
    @Mapping(target="gross", source="dto.gross")
    @Mapping(target="patientShare", source="dto.patientShare")
    @Mapping(target="net", source="dto.net")
    @Mapping(target="createdAt", ignore = true)
    @Mapping(target="updatedAt", ignore = true)
    @Mapping(target="payerRefId", ignore = true)
    @Mapping(target="providerRefId", ignore = true)
    @Mapping(target = "txAt", ignore = true)
    @Mapping(target = "comments", source = "dto.comments")
    Claim toClaim(SubmissionClaimDTO dto, ClaimKey key, Submission submission);

    // encounter (optional)
    @Mapping(target="id", ignore = true)
    @Mapping(target="claim", source="claim")
    @Mapping(target="facilityId", source="dto.facilityId")
    @Mapping(target="type", source="dto.type")
    @Mapping(target="patientId", source="dto.patientId")
    @Mapping(target="startAt", source="dto.start")
    @Mapping(target="endAt", source="dto.end")
    @Mapping(target="startType", source="dto.startType")
    @Mapping(target="endType", source="dto.endType")
    @Mapping(target="transferSource", source="dto.transferSource")
    @Mapping(target="transferDestination", source="dto.transferDestination")
    @Mapping(target = "facilityRefId", ignore = true)
    Encounter toEncounter(EncounterDTO dto, Claim claim);

    // diagnosis
    @Mapping(target="id", ignore = true)
    @Mapping(target="diagType", source="dto.type")
    @Mapping(target = "claim", source = "claim")
    @Mapping(target="code", source="dto.code")
    @Mapping(target = "diagnosisCodeRefId", ignore = true)
    Diagnosis toDiagnosis(DiagnosisDTO dto, Claim claim);

    // activity
    @Mapping(target="id", ignore = true)
    @Mapping(target="claim", source="claim")
    @Mapping(target="activityId", source="dto.id")
    @Mapping(target="startAt", source="dto.start")
    @Mapping(target="type", source="dto.type")
    @Mapping(target="code", source="dto.code")
    @Mapping(target="quantity", source="dto.quantity")
    @Mapping(target="net", source="dto.net")
    @Mapping(target="clinician", source="dto.clinician")
    @Mapping(target="priorAuthorizationId", source="dto.priorAuthorizationId")
    @Mapping(target="createdAt", expression = "java(java.time.OffsetDateTime.now())")
    @Mapping(target="updatedAt", expression = "java(java.time.OffsetDateTime.now())")
    @Mapping(target = "activityCodeRefId", ignore = true)
    @Mapping(target = "clinicianRefId", ignore = true)
    Activity toActivity(ActivityDTO dto, Claim claim);

    // observation
    @Mapping(target="id", ignore = true)
    @Mapping(target="activity", source="activity")
    @Mapping(target="obsType", source="dto.type")
    @Mapping(target="obsCode", source="dto.code")
    @Mapping(target="valueText", source="dto.value")
    @Mapping(target="valueType", source="dto.valueType")
    @Mapping(target="createdAt", ignore = true)
    @Mapping(target = "fileBytes", source = "dto.fileBytes")
    Observation toObservation(ObservationDTO dto, Activity activity);

    @Named("hashOrPlain")
    default String hashOrPlain(String emiratesId, boolean hashEnabled){
        if (!hashEnabled) return emiratesId;
        return sha256(emiratesId.getBytes()).toString() ;
    }

    private static byte[] sha256(byte[] bytes) {
        if (bytes == null) return null;
        try {
            return java.security.MessageDigest.getInstance("SHA-256").digest(bytes);
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }

    private static String md5Hex(String s) {
        try {
            var md = java.security.MessageDigest.getInstance("MD5");
            byte[] input = (s == null) ? new byte[0] : s.getBytes(java.nio.charset.StandardCharsets.UTF_8);
            byte[] dig = md.digest(input);
            // fast hex (no external libs)
            char[] HEX = "0123456789abcdef".toCharArray();
            char[] out = new char[dig.length * 2];
            for (int i = 0, j = 0; i < dig.length; i++) {
                int v = dig[i] & 0xFF;
                out[j++] = HEX[v >>> 4];
                out[j++] = HEX[v & 0x0F];
            }
            return new String(out);
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException("MD5 not available", e);
        }
    }
}
