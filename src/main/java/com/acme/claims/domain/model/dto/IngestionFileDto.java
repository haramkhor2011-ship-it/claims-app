package com.acme.claims.domain.model.dto;

import java.time.LocalDateTime;

public record IngestionFileDto(
        String fileId,               // TEXT
        String fileName,             // TEXT
        String senderId,             // TEXT
        String receiverId,           // TEXT
        LocalDateTime transactionDate, // TIMESTAMPTZ
        Integer recordCountHint,     // INTEGER
        byte[] xmlBytes,             // BYTEA
        byte[] pdfBytes,             // BYTEA
        LocalDateTime downloadedAt, // TIMESTAMPTZ
        Short downloadMarked         // SMALLINT (0=success,1=fail)
) {}
