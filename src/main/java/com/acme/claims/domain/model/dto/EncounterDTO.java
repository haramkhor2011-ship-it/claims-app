// FILE: src/main/java/com/acme/claims/ingestion/dto/submission/EncounterDTO.java
// Version: v1.0.0
// XSD: Encounter(FacilityID, Type, PatientID, Start, End?, StartType?, EndType?, TransferSource?, TransferDestination?)  :contentReference[oaicite:5]{index=5}
package com.acme.claims.domain.model.dto;

import java.time.OffsetDateTime;

public record EncounterDTO(
        String facilityId,
        String type,
        String patientId,
        OffsetDateTime start,
        OffsetDateTime end,
        String startType,
        String endType,
        String transferSource,
        String transferDestination
) {}
