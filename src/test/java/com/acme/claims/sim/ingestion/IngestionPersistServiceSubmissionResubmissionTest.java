package com.acme.claims.sim.ingestion;

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

@ExtendWith(MockitoExtension.class)
class IngestionPersistServiceSubmissionResubmissionTest {

    @Mock private JdbcTemplate jdbc;
    @Mock private ErrorLogger errors;
    @InjectMocks private PersistService service;

    private SubmissionDTO submissionDTO;

    @BeforeEach
    void setUp() {
        var tx = OffsetDateTime.parse("2025-02-14T12:00:00Z");
        var header = new SubmissionHeaderDTO("PROV1","PAYER1", tx, 1,"PRODUCTION");

        var enc = new EncounterDTO("FAC1","1","PAT1",
                OffsetDateTime.parse("2025-02-01T09:34:00Z"),
                OffsetDateTime.parse("2025-02-01T10:04:00Z"),
                "1","1",null,null);

        var act = new ActivityDTO("A-1",
                OffsetDateTime.parse("2025-02-01T09:34:00Z"),
                "3","83036",
                new BigDecimal("1.0"), new BigDecimal("214.13"),
                "DHA-P-123","PA-1",
                Set.of(new ObservationDTO("Result","A1C","5","Date", new byte[2])));

        var resub = new ResubmissionDTO("Correction","Fixed fields", "QkFTRTY0".getBytes()); // any bytes OK

        var claim = new SubmissionClaimDTO(
                "C-RES","IDP-1","MEM-1","PAYER1","PROV1","784-...",
                new BigDecimal("10"), new BigDecimal("0"), new BigDecimal("10"), "comments",
                enc, Set.of(new DiagnosisDTO("Principal","E78.5")), Set.of(act),
                resub, null
        );
        submissionDTO = new SubmissionDTO(header, List.of(claim));
    }

    @Test
    void persistSubmission_withResubmission_createsTwoEvents_andTimeline_andStoresResubmission() {
        long fileId = 77L;

        // submission insert -> id
        when(jdbc.queryForObject(startsWith("insert into claims.submission"), eq(Long.class), any(), any(), any()))
                .thenReturn(9000L);

        // isAlreadySubmitted -> treat as already submitted so we still allow because resubmission != null
        when(jdbc.query(startsWith("select id from claims.claim_key"),
                any(PreparedStatementSetter.class), any(ResultSetExtractor.class)))
                .thenReturn(222L); // existing claim_key id
        when(jdbc.queryForObject(eq("select count(*) from claims.claim_event where claim_key_id=? and type=1"),
                eq(Integer.class), any()))
                .thenReturn(1);

        // claim_key select
        when(jdbc.queryForObject(eq("select id from claims.claim_key where claim_id=?"),
                eq(Long.class), any()))
                .thenReturn(3000L);

        // claim select
        when(jdbc.queryForObject(eq("select id from claims.claim where claim_key_id=?"),
                eq(Long.class), any()))
                .thenReturn(4000L);

        // activity select
        when(jdbc.queryForObject(eq("select id from claims.activity where claim_id=? and activity_id=?"),
                eq(Long.class), any(), any()))
                .thenReturn(5000L);

        // claim_event select (twice: SUBMISSION type=1, RESUBMISSION type=2)
        when(jdbc.queryForObject(argThat((String s) -> s.contains("select id from claims.claim_event")),
                eq(Long.class), any(), any()))
                .thenReturn(6000L) // for type=1
                .thenReturn(6001L); // for type=2

        // generic updates succeed
        when(jdbc.update(anyString(), any(Object[].class))).thenReturn(1);

        PersistService.PersistCounts out = service.persistSubmission(fileId, submissionDTO);

        // we persisted one claim/act/obs/dx
        assertThat(out.claims()).isEqualTo(1);
        assertThat(out.acts()).isEqualTo(1);
        assertThat(out.obs()).isEqualTo(1);
        assertThat(out.dxs()).isEqualTo(1);

        // resubmission row inserted
        verify(jdbc).update(argThat((String s) -> s.contains("insert into claims.claim_resubmission")), any(Object[].class));

        // status timeline inserted twice: SUBMITTED (1) and RESUBMITTED (2)
        verify(jdbc, atLeast(2)).update(argThat((String s) -> s.contains("insert into claims.claim_status_timeline")), any(Object[].class));

        // project activities twice into claim_event_activity (for both events)
        verify(jdbc, atLeast(2)).update(argThat((String s) -> s.contains("insert into claims.claim_event_activity")), any(Object[].class));

        // observations projected into event_observation
        verify(jdbc, atLeastOnce()).update(argThat((String s) -> s.contains("insert into claims.event_observation")), any(Object[].class));

        // no duplicate error logged because resubmission present
        verifyNoInteractions(errors);
    }
}
