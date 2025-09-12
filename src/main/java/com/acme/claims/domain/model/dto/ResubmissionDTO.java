// FILE: src/main/java/com/acme/claims/ingestion/dto/submission/ResubmissionDTO.java
// Version: v1.0.0
// XSD: Resubmission(Type, Comment, Attachment?)  :contentReference[oaicite:9]{index=9}
package com.acme.claims.domain.model.dto;

public record ResubmissionDTO(
        String type,
        String comment,
        byte[] attachment
) {}
