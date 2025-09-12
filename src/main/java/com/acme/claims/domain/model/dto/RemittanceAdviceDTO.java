// FILE: src/main/java/com/acme/claims/ingestion/dto/remittance/RemittanceAdviceDTO.java
// Version: v1.0.0
// Aggregate root for Remittance.Advice  :contentReference[oaicite:12]{index=12}
package com.acme.claims.domain.model.dto;

import java.util.List;

public record RemittanceAdviceDTO(
        RemittanceHeaderDTO header,
        List<RemittanceClaimDTO> claims
) {}
