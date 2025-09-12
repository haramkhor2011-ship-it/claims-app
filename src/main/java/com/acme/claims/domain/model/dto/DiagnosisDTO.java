// FILE: src/main/java/com/acme/claims/ingestion/dto/submission/DiagnosisDTO.java
// Version: v1.0.0
// XSD: Diagnosis(Type, Code)  :contentReference[oaicite:6]{index=6}
package com.acme.claims.domain.model.dto;

public record DiagnosisDTO(
        String type,
        String code
) {}
