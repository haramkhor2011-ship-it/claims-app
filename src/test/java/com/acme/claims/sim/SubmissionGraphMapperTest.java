// FILE: src/test/java/com/acme/claims/ingestion/mapper/SubmissionGraphMapperTest.java
// Version: v2.0.0
package com.acme.claims.sim;

import com.acme.claims.domain.model.dto.*;
import com.acme.claims.domain.model.entity.*;
import com.acme.claims.mapper.SubmissionGraphMapper;
import org.junit.jupiter.api.Test;
import org.mapstruct.factory.Mappers;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

final class SubmissionGraphMapperTest {
    private final SubmissionGraphMapper mapper = Mappers.getMapper(SubmissionGraphMapper.class);

    @Test
    void mapsSubmissionAggregateToEntities() {
        var hdr = new SubmissionHeaderDTO("SENDER","RECEIVER", OffsetDateTime.parse("2024-01-01T10:00:00Z"),1,"NONE");
        var dto = new SubmissionDTO(hdr, List.of(
                new SubmissionClaimDTO("CLAIM-1","IDP","MEM","PAYER","PROV","EID",
                        new BigDecimal("100"), new BigDecimal("10"), new BigDecimal("90"),
                        new EncounterDTO("FAC","INPAT","PAT", OffsetDateTime.parse("2024-01-01T10:05:00Z"), null, null, null, null, null),
                        List.of(new DiagnosisDTO("PRINCIPAL","D1")),
                        List.of(new ActivityDTO("A1", OffsetDateTime.parse("2024-01-01T10:10:00Z"), "PROC","C1",
                                new BigDecimal("1"), new BigDecimal("90"), "DRX", null, List.of())),
                        null, new ContractDTO("PKG")
                )
        ));

        IngestionFile file = new IngestionFile(); file.setId(10L);
        Submission submission = mapper.toSubmission(dto, file);
        assertNotNull(submission.getIngestionFile());

        ClaimKey key = new ClaimKey(); key.setId(20L); key.setClaimId("CLAIM-1");
        Claim claim = mapper.toClaim(dto.claims().get(0), key, submission);
        assertEquals(key, claim.getClaimKey());
        Encounter enc = mapper.toEncounter(dto.claims().get(0).encounter(), claim);
        assertEquals("FAC", enc.getFacilityId());
        Activity act = mapper.toActivity(dto.claims().get(0).activities().get(0), claim);
        assertEquals("A1", act.getActivityId());
        Observation obs = mapper.toObservation(new ObservationDTO("L","O2","v","t"), act);
        assertEquals("O2", obs.getObsCode());
    }
}
