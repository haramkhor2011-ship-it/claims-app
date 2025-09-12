// FILE: src/main/java/com/acme/claims/ingestion/dto/submission/ObservationDTO.java
// Version: v1.0.0
// XSD: Observation(Type, Code, Value?, ValueType?)  :contentReference[oaicite:8]{index=8}
package com.acme.claims.domain.model.dto;

public record ObservationDTO(
        String type,  // this will be enum type RONIC, FILE, TEXT & others..
        String code, // will be FILE when type is FILE
        String value, // will be aBase64 string if type is FILE, else string for type: TEXT
        String valueType,// will be FILE when type is FILE
        byte[] fileBytes
) {}
