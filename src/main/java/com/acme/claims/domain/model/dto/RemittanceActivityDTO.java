// FILE: src/main/java/com/acme/claims/ingestion/dto/remittance/RemittanceActivityDTO.java
// Version: v1.0.0
// XSD: Activity(ID, Start, Type, Code, Quantity, Net, List?, Clinician, PriorAuthorizationID?, Gross?, PatientShare?, PaymentAmount, DenialCode?)  :contentReference[oaicite:14]{index=14}
package com.acme.claims.domain.model.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record RemittanceActivityDTO(
        String id,
        OffsetDateTime start,
        String type,
        String code,
        BigDecimal quantity,
        BigDecimal net,
        BigDecimal listPrice,           // List
        String clinician,
        String priorAuthorizationId,
        BigDecimal gross,
        BigDecimal patientShare,
        BigDecimal paymentAmount,
        String denialCode
) {}
