// FILE: src/main/java/com/acme/claims/ingestion/dto/remittance/RemittanceHeaderDTO.java
// Version: v1.0.0 (XSD Header)
// XSD: Header fields same as submission  :contentReference[oaicite:11]{index=11}
package com.acme.claims.domain.model.dto;

import java.time.OffsetDateTime;

public record RemittanceHeaderDTO(
        String senderId,
        String receiverId,
        OffsetDateTime transactionDate,
        int recordCount,
        String dispositionFlag
) {}
