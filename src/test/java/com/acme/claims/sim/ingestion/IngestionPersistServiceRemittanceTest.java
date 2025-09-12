package com.acme.claims.sim.ingestion;

import com.acme.claims.domain.model.dto.RemittanceActivityDTO;
import com.acme.claims.domain.model.dto.RemittanceAdviceDTO;
import com.acme.claims.domain.model.dto.RemittanceClaimDTO;
import com.acme.claims.domain.model.dto.RemittanceHeaderDTO;
import com.acme.claims.ingestion.audit.ErrorLogger;
import com.acme.claims.ingestion.persist.PersistService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class IngestionPersistServiceRemittanceTest {

    @Mock private JdbcTemplate jdbc;
    @Mock private ErrorLogger errors;
    @InjectMocks private PersistService service;

    private RemittanceAdviceDTO remit;

    @BeforeEach
    void setUp() {
        var header = new RemittanceHeaderDTO("TPA004","DHA-F-0045446",
                OffsetDateTime.parse("2025-02-24T18:11:00Z"),1,"PRODUCTION");

        var a1 = new RemittanceActivityDTO("RA-1",
                OffsetDateTime.parse("2025-02-01T10:18:00Z"),
                "3","83036",
                new BigDecimal("1"), new BigDecimal("214.13"),
                new BigDecimal("214.13"), "DHA-P-0228312", null,
                new BigDecimal("214.13"), new BigDecimal("0"), new BigDecimal("214.13"), null);

        var a2 = new RemittanceActivityDTO("RA-2",
                OffsetDateTime.parse("2025-02-01T10:18:00Z"),
                "8","10",
                new BigDecimal("1"), new BigDecimal("289.81"),
                new BigDecimal("289.81"), "DHA-P-0228312", null,
                new BigDecimal("339.81"), new BigDecimal("50.00"), new BigDecimal("289.81"), null);

        var claim = new RemittanceClaimDTO("C-1","IDP-1","DHA-F-0045446", null,
                "GC03_REF", OffsetDateTime.parse("2025-02-21T00:00:00Z"), "DHA-F-0045446", List.of(a1,a2));

        remit = new RemittanceAdviceDTO(header, List.of(claim));
    }

    @Test
    void persistRemittance_happyPath_insertsClaimsActivities_andProjectsEventTimeline() {
        long fileId = 20L;

        // remittance insert -> id
        when(jdbc.queryForObject(
                startsWith("insert into claims.remittance"),
                eq(Long.class), any())
        ).thenReturn(900L);

        // claim_key select -> 200L
        when(jdbc.queryForObject(
                eq("select id from claims.claim_key where claim_id=?"),
                eq(Long.class), any())
        ).thenReturn(200L);

        // remittance_claim select -> 910L
        when(jdbc.queryForObject(
                eq("select id from claims.remittance_claim where remittance_id=? and claim_key_id=?"),
                eq(Long.class), any(), any())
        ).thenReturn(910L);

        // claim_event select -> 600L
        when(jdbc.queryForObject(
                argThat((String sql) -> sql.contains("select id from claims.claim_event")),
                eq(Long.class), any(), any())
        ).thenReturn(600L);

        // generic updates succeed
        when(jdbc.update(anyString(), any(Object[].class))).thenReturn(1);

        PersistService.PersistCounts out = service.persistRemittance(fileId, remit);

        assertThat(out.claims()).isZero();
        assertThat(out.acts()).isZero();
        assertThat(out.obs()).isZero();
        assertThat(out.dxs()).isZero();
        assertThat(out.remitClaims()).isEqualTo(1);
        assertThat(out.remitActs()).isEqualTo(2);
    }
}
