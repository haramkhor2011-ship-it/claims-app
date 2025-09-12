// FILE: src/main/java/com/acme/claims/ingestion/dto/submission/SubmissionHeaderDTO.java
// Version: v1.0.0 (XSD Header)
// XSD: SenderID, ReceiverID, TransactionDate, RecordCount, DispositionFlag  :contentReference[oaicite:2]{index=2}
package com.acme.claims.domain.model.dto;

import java.time.OffsetDateTime;

public record SubmissionHeaderDTO(
        String senderId,
        String receiverId,
        OffsetDateTime transactionDate,
        int recordCount,
        String dispositionFlag
) {}
