// FILE: src/main/java/com/acme/claims/ingestion/mapper/RemittanceGraphMapper.java
// Version: v1.0.0
// Maps: Remittance aggregate → Remittance/RemittanceClaim/RemittanceActivity entities
package com.acme.claims.mapper;

import com.acme.claims.domain.model.dto.*;
import com.acme.claims.domain.model.entity.*;
import org.mapstruct.*;

@Mapper(config = MapStructCentralConfig.class)
public interface RemittanceGraphMapper {

    // group row per file
    @Mapping(target="id", ignore = true)
    @Mapping(target="ingestionFile", source="file")
    @Mapping(target = "txAt", ignore = true)
    Remittance toRemittance(RemittanceAdviceDTO dto, IngestionFile file);

    // claim adjudication (requires ClaimKey + Remittance)
    @Mapping(target="id", ignore = true)
    @Mapping(target="remittance", source="remittance")
    @Mapping(target="claimKey", source="key")
    @Mapping(target="idPayer", source="dto.idPayer")
    @Mapping(target="providerId", source="dto.providerId")
    @Mapping(target="denialCode", source="dto.denialCode")
    @Mapping(target="paymentReference", source="dto.paymentReference")
    @Mapping(target="dateSettlement", source="dto.dateSettlement")
    @Mapping(target="facilityId", source="dto.facilityId") // flattened Encounter.FacilityID per SSOT
    @Mapping(target="createdAt", expression = "java(java.time.OffsetDateTime.now())")
    @Mapping(target = "denialCodeRefId", ignore = true)
    @Mapping(target = "payerRefId", ignore = true)
    @Mapping(target = "providerRefId", ignore = true)
    RemittanceClaim toRemittanceClaim(RemittanceClaimDTO dto, Remittance remittance, ClaimKey key);

    // activity adjudication
    @Mapping(target="id", ignore = true)
    @Mapping(target="remittanceClaim", source="rc")
    @Mapping(target="activityId", source="dto.id")
    @Mapping(target="startAt", source="dto.start")
    @Mapping(target="type", source="dto.type")
    @Mapping(target="code", source="dto.code")
    @Mapping(target="quantity", source="dto.quantity")
    @Mapping(target="net", source="dto.net")
    @Mapping(target="listPrice", source="dto.listPrice")
    @Mapping(target="clinician", source="dto.clinician")
    @Mapping(target="priorAuthorizationId", source="dto.priorAuthorizationId")
    @Mapping(target="gross", source="dto.gross")
    @Mapping(target="patientShare", source="dto.patientShare")
    @Mapping(target="paymentAmount", source="dto.paymentAmount")
    @Mapping(target="denialCode", source="dto.denialCode")
    @Mapping(target="createdAt", expression = "java(java.time.OffsetDateTime.now())")
    RemittanceActivity toRemittanceActivity(RemittanceActivityDTO dto, RemittanceClaim rc);
}
