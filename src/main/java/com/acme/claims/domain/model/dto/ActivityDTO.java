// FILE: src/main/java/com/acme/claims/ingestion/dto/submission/ActivityDTO.java
// Version: v1.0.0
// XSD: Activity(ID, Start, Type, Code, Quantity, Net, Clinician, PriorAuthorizationID?, Observation*)  :contentReference[oaicite:7]{index=7}
package com.acme.claims.domain.model.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.Set;

public record ActivityDTO(
        String id,
        OffsetDateTime start,
        String type,
        String code,
        BigDecimal quantity,
        BigDecimal net,
        String clinician,
        String priorAuthorizationId,
        Set<ObservationDTO> observations
) {}
