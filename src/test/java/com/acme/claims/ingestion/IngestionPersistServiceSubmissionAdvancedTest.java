package com.acme.claims.ingestion;

import com.acme.claims.domain.model.dto.*;
import com.acme.claims.ingestion.audit.ErrorLogger;
import com.acme.claims.ingestion.persist.PersistService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.PreparedStatementSetter;
import org.springframework.jdbc.core.ResultSetExtractor;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Covers 3 scenarios:
 * 1) Duplicate Activity IDs within the same claim (DB idempotency surface; service should not explode)
 * 2) Diagnosis insert path (one row per diagnosis)
 * 3) Observation persistence + projection (base + event snapshot)
 */
@ExtendWith(MockitoExtension.class)
class IngestionPersistServiceSubmissionAdvancedTest {

    @Mock private JdbcTemplate jdbc;
    @Mock private ErrorLogger errors;
    @InjectMocks private PersistService service;

    private SubmissionDTO dto;

    @BeforeEach
    void setUp() {
        var tx = OffsetDateTime.parse("2025-02-14T12:00:00Z");
        var header = new SubmissionHeaderDTO("PROV1","PAYER1", tx, 1,"PRODUCTION");

        var enc = new EncounterDTO("FAC1","1","PAT1",
                OffsetDateTime.parse("2025-02-01T09:00:00Z"),
                OffsetDateTime.parse("2025-02-01T09:30:00Z"),
                "1","1",null,null);

        // two diagnoses -> test #2
        var diagnoses = Set.of(
                new DiagnosisDTO("Principal","E78.5"),
                new DiagnosisDTO("Secondary","R03.0")
        );

        // Activity #1 with two observations -> test #3
        var obs1 = Set.of(
                new ObservationDTO("Result","A1C","5","Date", null),
                new ObservationDTO("Text","Description","Hemoglobin glycosylated A1C","Other", null)
        );
        var a1 = new ActivityDTO("A-1",
                OffsetDateTime.parse("2025-02-01T09:05:00Z"),
                "3","83036",
                new BigDecimal("1.0"), new BigDecimal("214.13"),
                "DHA-P-1","PA-1", obs1);

        // Activity #2 with SAME activity id "A-1" (duplicate in same claim) + one observation -> test #1 + #3
        var obs2 = Set.of(new ObservationDTO("Result","BPS","120","Date", null));
        var a2 = new ActivityDTO("A-1",
                OffsetDateTime.parse("2025-02-01T09:10:00Z"),
                "8","10",
                new BigDecimal("1.0"), new BigDecimal("289.81"),
                "DHA-P-1",null, obs2);

        var claim = new SubmissionClaimDTO(
                "C-ADV","IDP-1","MEM-1","PAYER1","PROV1","784-1993-9685935-9",
                new BigDecimal("600.00"), new BigDecimal("50.00"), new BigDecimal("550.00"), "comments",
                enc, diagnoses, Set.of(a1, a2), null, null
        );

        dto = new SubmissionDTO(header, List.of(claim));
    }

    private void arrangeCommonFreshSubmissionStubs() {
        // submission insert -> id
        when(jdbc.queryForObject(
                startsWith("insert into claims.submission"),
                eq(Long.class), any())
        ).thenReturn(100L);

        // isAlreadySubmitted -> false (no claim_key yet)
        when(jdbc.query(
                startsWith("select id from claims.claim_key"),
                any(PreparedStatementSetter.class),
                any(ResultSetExtractor.class))
        ).thenReturn((Long) null);

        // claim_key upsert -> select id
        when(jdbc.queryForObject(
                eq("select id from claims.claim_key where claim_id=?"),
                eq(Long.class), any())
        ).thenReturn(200L);

        // claim upsert -> select id
        when(jdbc.queryForObject(
                eq("select id from claims.claim where claim_key_id=?"),
                eq(Long.class), any())
        ).thenReturn(300L);

        // activity upsert -> select id (called twice; duplicate id allowed at service level; DB handles ON CONFLICT)
        when(jdbc.queryForObject(
                eq("select id from claims.activity where claim_id=? and activity_id=?"),
                eq(Long.class), any(), any())
        ).thenReturn(400L, 400L); // same id both times

        // claim_event (type=1) select -> id
        when(jdbc.queryForObject(
                argThat((String s) -> s.contains("select id from claims.claim_event")),
                eq(Long.class), any(), any())
        ).thenReturn(500L);

        // generic updates succeed
        when(jdbc.update(anyString(), any(Object[].class))).thenReturn(1);
    }

    @Test
    void duplicateActivityIds_doNotExplode_andServiceCountsBothIterations() {
        arrangeCommonFreshSubmissionStubs();

        PersistService.PersistCounts out = service.persistSubmission(42L, dto, List.of());

        // service-level counters (loop-based) count both activities
        assertThat(out.claims()).isEqualTo(1);
        assertThat(out.acts()).isEqualTo(2);
        assertThat(out.obs()).isEqualTo(3); // 2 + 1
        assertThat(out.dxs()).isEqualTo(2);

        // activity id lookup executed twice for same (claim, activity_id)
        verify(jdbc, times(2)).queryForObject(
                eq("select id from claims.activity where claim_id=? and activity_id=?"),
                eq(Long.class), any(), any()
        );

        // projection to claim_event_activity executed once per activity (2 total)
        verify(jdbc, times(2)).update(
                argThat((String s) -> s.contains("insert into claims.claim_event_activity")),
                any(Object[].class)
        );
    }

    @Test
    void diagnosisIsInsertedOncePerDiagnosis() {
        arrangeCommonFreshSubmissionStubs();

        service.persistSubmission(43L, dto, List.of());

        // verify two diagnosis inserts (subquery form)
        verify(jdbc, times(2)).update(
                argThat((String s) -> s.contains("insert into claims.diagnosis")),
                any(Object[].class)
        );
    }

    @Test
    void observationsPersistToBaseAndProjectedToEventSnapshot() {
        arrangeCommonFreshSubmissionStubs();

        service.persistSubmission(44L, dto, List.of());

        // base table: 3 observations inserted (2 + 1)
        verify(jdbc, times(3)).update(
                argThat((String s) -> s.contains("insert into claims.observation")),
                any(Object[].class)
        );

        // snapshot: 3 event_observation inserts tied to claim_event_activity
        verify(jdbc, times(3)).update(
                argThat((String s) -> s.contains("insert into claims.event_observation")),
                any(Object[].class)
        );
    }
}
