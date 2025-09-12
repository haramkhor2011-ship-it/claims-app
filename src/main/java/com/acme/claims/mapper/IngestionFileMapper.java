// FILE: src/main/java/com/acme/claims/ingestion/mapper/IngestionFileMapper.java
// Version: v1.0.0
// Maps: Header DTOs → claims.ingestion_file (SSOT)  (rootType and xmlBytes provided by caller)
// We intentionally map only persisted header fields.  :contentReference[oaicite:15]{index=15} :contentReference[oaicite:16]{index=16}
package com.acme.claims.mapper;


import com.acme.claims.domain.model.dto.RemittanceHeaderDTO;
import com.acme.claims.domain.model.dto.SubmissionHeaderDTO;
import com.acme.claims.domain.model.entity.IngestionFile;
import org.mapstruct.*;

@Mapper(config = MapStructCentralConfig.class)
public interface IngestionFileMapper {
    @Mapping(target="id", ignore = true)
    @Mapping(target="fileId", source="fileId")
    @Mapping(target="rootType", constant = "1") // 1 = Claim.Submission
    @Mapping(target="senderId", source="header.senderId")
    @Mapping(target="receiverId", source="header.receiverId")
    @Mapping(target="transactionDate", source="header.transactionDate")
    @Mapping(target="recordCountDeclared", source="header.recordCount")
    @Mapping(target="dispositionFlag", source="header.dispositionFlag")
    @Mapping(target="xmlBytes", source="xmlBytes")
    @Mapping(target="createdAt", expression = "java(java.time.OffsetDateTime.now())")
    @Mapping(target="updatedAt", expression = "java(java.time.OffsetDateTime.now())")
    IngestionFile fromSubmissionHeader(SubmissionHeaderDTO header, String fileId, byte[] xmlBytes);

    @Mapping(target="id", ignore = true)
    @Mapping(target="fileId", source="fileId")
    @Mapping(target="rootType", constant = "2") // 2 = Remittance.Advice
    @Mapping(target="senderId", source="header.senderId")
    @Mapping(target="receiverId", source="header.receiverId")
    @Mapping(target="transactionDate", source="header.transactionDate")
    @Mapping(target="recordCountDeclared", source="header.recordCount")
    @Mapping(target="dispositionFlag", source="header.dispositionFlag")
    @Mapping(target="xmlBytes", source="xmlBytes")
    @Mapping(target="createdAt", expression = "java(java.time.OffsetDateTime.now())")
    @Mapping(target="updatedAt", expression = "java(java.time.OffsetDateTime.now())")
    IngestionFile fromRemittanceHeader(RemittanceHeaderDTO header, String fileId, byte[] xmlBytes);
}
