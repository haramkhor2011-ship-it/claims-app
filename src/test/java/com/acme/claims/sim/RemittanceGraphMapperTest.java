// FILE: src/test/java/com/acme/claims/ingestion/mapper/RemittanceGraphMapperTest.java
// Version: v2.0.0
package com.acme.claims.sim;

import com.acme.claims.domain.model.dto.RemittanceActivityDTO;
import com.acme.claims.domain.model.dto.RemittanceAdviceDTO;
import com.acme.claims.domain.model.dto.RemittanceClaimDTO;
import com.acme.claims.domain.model.dto.RemittanceHeaderDTO;
import com.acme.claims.domain.model.entity.*;
import com.acme.claims.mapper.RemittanceGraphMapper;
import org.junit.jupiter.api.Test;
import org.mapstruct.factory.Mappers;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

final class RemittanceGraphMapperTest {
    private final RemittanceGraphMapper mapper = Mappers.getMapper(RemittanceGraphMapper.class);

    @Test
    void mapsRemittanceAggregateToEntities() {
        var hdr = new RemittanceHeaderDTO("SENDER","RECEIVER", OffsetDateTime.parse("2024-02-01T10:00:00Z"),1,"NONE");
        var dto = new RemittanceAdviceDTO(hdr, List.of(
                new RemittanceClaimDTO(
                        "CLAIM-1","IDP","PROV",null,"PR-1", null, "FAC-9",
                        List.of(new RemittanceActivityDTO("A1", OffsetDateTime.parse("2024-02-01T10:15:00Z"),"PROC","C1",
                                new BigDecimal("1"), new BigDecimal("80"), null, "DRX", null, null, null, new BigDecimal("70"), null))
                )
        ));

        IngestionFile file = new IngestionFile(); file.setId(11L);
        Remittance remit = mapper.toRemittance(dto, file);
        ClaimKey key = new ClaimKey(); key.setId(21L); key.setClaimId("CLAIM-1");
        RemittanceClaim rc = mapper.toRemittanceClaim(dto.claims().get(0), remit, key);
        assertEquals("PR-1", rc.getPaymentReference());
        assertEquals("FAC-9", rc.getFacilityId());
        RemittanceActivity ra = mapper.toRemittanceActivity(dto.claims().get(0).activities().get(0), rc);
        assertEquals("A1", ra.getActivityId());
        assertEquals(new BigDecimal("70"), ra.getPaymentAmount());
    }
}
