// FILE: src/main/java/com/acme/claims/ingestion/dto/submission/SubmissionDTO.java
// Version: v1.0.0
// Aggregate root for Claim.Submission  :contentReference[oaicite:3]{index=3}
package com.acme.claims.domain.model.dto;

import java.util.List;

public record SubmissionDTO(
        SubmissionHeaderDTO header,
        List<SubmissionClaimDTO> claims
) {}
