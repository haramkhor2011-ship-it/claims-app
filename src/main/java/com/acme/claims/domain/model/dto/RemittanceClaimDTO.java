// FILE: src/main/java/com/acme/claims/ingestion/dto/remittance/RemittanceClaimDTO.java
// Version: v1.0.0
// XSD: Claim(ID, IDPayer, ProviderID?, DenialCode?, PaymentReference, DateSettlement?, Encounter/FacilityID?) + Activity+  :contentReference[oaicite:13]{index=13}
package com.acme.claims.domain.model.dto;

import java.time.OffsetDateTime;
import java.util.List;

public record RemittanceClaimDTO(
        String id,
        String idPayer,
        String providerId,
        String denialCode,
        String paymentReference,
        OffsetDateTime dateSettlement,
        String facilityId, // Encounter/FacilityID flattened per SSOT
        List<RemittanceActivityDTO> activities
) {}
