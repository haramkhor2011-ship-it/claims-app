package com.acme.claims.sim.ingestion;

import com.acme.claims.domain.model.dto.*;
import com.acme.claims.ingestion.audit.ErrorLogger;
import com.acme.claims.ingestion.persist.PersistService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.PreparedStatementSetter;
import org.springframework.jdbc.core.ResultSetExtractor;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class IngestionPersistServiceRemittanceAdvancedTest {

    @Mock private JdbcTemplate jdbc;
    @Mock private ErrorLogger errors;
    @InjectMocks private PersistService service;

    private RemittanceAdviceDTO remit;

    @BeforeEach
    void setUp() {
        var header = new RemittanceHeaderDTO("TPA004","DHA-F-0045446",
                OffsetDateTime.parse("2025-02-24T18:11:00Z"),1,"PRODUCTION");

        // Activity with full financials populated
        var a = new RemittanceActivityDTO("RA-1",
                OffsetDateTime.parse("2025-02-01T10:18:00Z"),
                "3","83036",
                new BigDecimal("1"),
                new BigDecimal("214.13"),          // net
                new BigDecimal("214.13"),          // list
                "DHA-P-0228312", null,
                new BigDecimal("214.13"),          // gross
                new BigDecimal("0.00"),            // patientShare
                new BigDecimal("214.13"),          // paymentAmount
                "DN001"                             // denialCode
        );

        var claim = new RemittanceClaimDTO(
                "C-REM","IDP-1","DHA-F-0045446", null,
                "PAY-REF-1", OffsetDateTime.parse("2025-02-21T00:00:00Z"),
                "DHA-F-0045446",
                List.of(a)
        );

        remit = new RemittanceAdviceDTO(header, List.of(claim));
    }

    private void arrangeCommonRemittanceStubs(long remittanceId, long claimKeyId, long rcId, long eventId) {
        // remittance insert -> id
        when(jdbc.queryForObject(
                startsWith("insert into claims.remittance"),
                eq(Long.class), any())
        ).thenReturn(remittanceId);

        // claim_key select -> id
        when(jdbc.queryForObject(
                eq("select id from claims.claim_key where claim_id=?"),
                eq(Long.class), any())
        ).thenReturn(claimKeyId);

        // remittance_claim select -> id
        when(jdbc.queryForObject(
                eq("select id from claims.remittance_claim where remittance_id=? and claim_key_id=?"),
                eq(Long.class), any(), any())
        ).thenReturn(rcId);

        // claim_event select -> id
        when(jdbc.queryForObject(
                argThat((String s) -> s.contains("select id from claims.claim_event")),
                eq(Long.class), any(), any())
        ).thenReturn(eventId);

        // all updates succeed
        when(jdbc.update(anyString(), any(Object[].class))).thenReturn(1);
    }

    @Test
    void remittance_projection_maps_financial_fields_into_claim_event_activity() {
        arrangeCommonRemittanceStubs(900L, 800L, 910L, 820L);

        service.persistRemittance(40L, remit);

        // Capture the args of inserts into claim_event_activity
        @SuppressWarnings("unchecked")
        ArgumentCaptor<Object[]> argsCap = ArgumentCaptor.forClass(Object[].class);

        // Should be called once (one activity)
        verify(jdbc, times(1))
                .update(argThat((String s) -> s.contains("insert into claims.claim_event_activity")),
                        argsCap.capture());

        Object[] args = argsCap.getValue();
        // Column order (after claim_event_id..prior_authorization_id_at_event):
        //  9: list_price_at_event
        // 10: gross_at_event
        // 11: patient_share_at_event
        // 12: payment_amount_at_event
        // 13: denial_code_at_event
        // (0-based indexes)
        assertThat(args[9]).isEqualTo(new BigDecimal("214.13"));  // list
        assertThat(args[10]).isEqualTo(new BigDecimal("214.13")); // gross
        assertThat(args[11]).isEqualTo(new BigDecimal("0.00"));   // patientShare
        assertThat(args[12]).isEqualTo(new BigDecimal("214.13")); // paymentAmount
        assertThat(args[13]).isEqualTo("DN001");                  // denialCode
    }

    @Test
    void remittance_idempotency_second_run_same_dto_succeeds_and_counts_are_stable() {
        arrangeCommonRemittanceStubs(901L, 801L, 911L, 821L);

        var first = service.persistRemittance(41L, remit);
        // same stubs again (simulate DB returning same ids / ON CONFLICT DO NOTHING)
        var second = service.persistRemittance(41L, remit);

        assertThat(first.remitClaims()).isEqualTo(1);
        assertThat(first.remitActs()).isEqualTo(1);
        assertThat(second.remitClaims()).isEqualTo(1);
        assertThat(second.remitActs()).isEqualTo(1);
    }

    @Test
    void submission_with_no_attachments_does_not_insert_claim_attachment() {
        // Build a tiny submission with no attachments
        var header = new SubmissionHeaderDTO("PROV","PAYER",
                OffsetDateTime.parse("2025-02-10T00:00:00Z"),1,"PRODUCTION");

        var enc = new EncounterDTO("FAC","1","PAT",
                OffsetDateTime.parse("2025-02-01T10:00:00Z"),
                OffsetDateTime.parse("2025-02-01T10:10:00Z"),
                "1","1",null,null);

        var act = new ActivityDTO("A-1",
                OffsetDateTime.parse("2025-02-01T10:00:00Z"),
                "3","83036",
                new BigDecimal("1.0"), new BigDecimal("100.00"),
                "DOC-1", null,
                List.of(new ObservationDTO("Result","A1C","5","Date")));

        var claim = new SubmissionClaimDTO("C-NO-ATT", "IDP","MEM","PAYER","PROV","784-...",
                new BigDecimal("100.00"), new BigDecimal("0.00"), new BigDecimal("100.00"),
                enc, List.of(new DiagnosisDTO("Principal","E78.5")), List.of(act),
                null, null);

        var submission = new SubmissionDTO(header, List.of(claim));

        // --- minimal stubs for submission path ---
        when(jdbc.queryForObject(
                startsWith("insert into claims.submission"),
                eq(Long.class), any(), any(), any())
        ).thenReturn(1000L);

        // isAlreadySubmitted -> false (no claim_key yet)
        when(jdbc.query(
                startsWith("select id from claims.claim_key"),
                any(PreparedStatementSetter.class),
                any(ResultSetExtractor.class))
        ).thenReturn((Long) null);

        when(jdbc.queryForObject(
                eq("select id from claims.claim_key where claim_id=?"),
                eq(Long.class), any())
        ).thenReturn(1200L);

        when(jdbc.queryForObject(
                eq("select id from claims.claim where claim_key_id=?"),
                eq(Long.class), any())
        ).thenReturn(1300L);

        when(jdbc.queryForObject(
                eq("select id from claims.activity where claim_id=? and activity_id=?"),
                eq(Long.class), any(), any())
        ).thenReturn(1400L);

        when(jdbc.queryForObject(
                argThat((String s) -> s.contains("select id from claims.claim_event")),
                eq(Long.class), any(), any())
        ).thenReturn(1500L);

        when(jdbc.update(anyString(), any(Object[].class))).thenReturn(1);

        // --- act ---
        var out = service.persistSubmission(55L, submission, List.of());

        assertThat(out.claims()).isEqualTo(1);
        assertThat(out.acts()).isEqualTo(1);
        assertThat(out.obs()).isEqualTo(1);
        assertThat(out.dxs()).isEqualTo(1);

        // verify: no claim_attachment inserts happened
        verify(jdbc, never())
                .update(argThat((String s) -> s.contains("insert into claims.claim_attachment")),
                        any(Object[].class));
    }
}
