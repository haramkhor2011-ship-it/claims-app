package com.acme.claims.ingestion;

import com.acme.claims.domain.model.dto.*;
import com.acme.claims.ingestion.audit.ErrorLogger;
import com.acme.claims.ingestion.parser.ParseOutcome;
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
class IngestionPersistServiceSubmissionTest {

    @Mock private JdbcTemplate jdbc;
    @Mock private ErrorLogger errors;
    @InjectMocks private PersistService service;

    private SubmissionDTO submissionDTO;

    @BeforeEach
    void setUp() {
        var header = new SubmissionHeaderDTO(
                "PROV1","PAYER1",
                OffsetDateTime.parse("2025-02-14T12:00:00Z"),
                1,"PRODUCTION"
        );

        var enc = new EncounterDTO("FAC1","1","PAT1",
                OffsetDateTime.parse("2025-02-01T09:34:00Z"),
                OffsetDateTime.parse("2025-02-01T10:04:00Z"),
                "1","1",null,null);

        var obs = Set.of(new ObservationDTO("Result","A1C","5","Date", null));
        var act = new ActivityDTO("A-1",
                OffsetDateTime.parse("2025-02-01T09:34:00Z"),
                "3","83036",
                new BigDecimal("1.0"), new BigDecimal("214.13"),
                "DHA-P-123","PA-1", obs);

        var dx = Set.of(new DiagnosisDTO("Principal","E78.5"));

        var claim = new SubmissionClaimDTO(
                "C-1","IDP-1","MEM-1","PAYER1","PROV1","784-1993-9685935-9",
                new BigDecimal("553.94"), new BigDecimal("67.96"), new BigDecimal("485.98"), "comments",
                enc, dx, Set.of(act),
                null, null
        );
        submissionDTO = new SubmissionDTO(header, List.of(claim));
    }

    @Test
    void persistSubmission_happyPath_insertsGraph_events_timeline_andAttachment() {
        long fileId = 10L;

        // submission insert -> id
        when(jdbc.queryForObject(
                startsWith("insert into claims.submission"),
                eq(Long.class), any())
        ).thenReturn(10L);

        // isAlreadySubmitted -> false (first select claim_key returns null)
        when(jdbc.query(
                startsWith("select id from claims.claim_key"),
                any(PreparedStatementSetter.class),
                any(ResultSetExtractor.class))
        ).thenReturn((Long) null);

        // claim_key select -> 200L
        when(jdbc.queryForObject(
                eq("select id from claims.claim_key where claim_id=?"),
                eq(Long.class), any())
        ).thenReturn(200L);

        // claim select -> 300L
        when(jdbc.queryForObject(
                eq("select id from claims.claim where claim_key_id=?"),
                eq(Long.class), any())
        ).thenReturn(300L);

        // activity select -> 400L
        when(jdbc.queryForObject(
                eq("select id from claims.activity where claim_id=? and activity_id=?"),
                eq(Long.class), any(), any())
        ).thenReturn(400L);

        // claim_event (type=1) select -> 500L
        when(jdbc.queryForObject(
                argThat((String sql) -> sql.contains("select id from claims.claim_event")),
                eq(Long.class), any(), any())
        ).thenReturn(500L);

        // generic updates succeed
        when(jdbc.update(anyString(), any(Object[].class))).thenReturn(1);

        // attachments: one matches claim C-1, one does not
        ParseOutcome.AttachmentRecord matching = new ParseOutcome.AttachmentRecord(
                "C-1", null, "file.pdf", "application/pdf",
                "BYTES".getBytes(), new byte[]{1,2,3}, 5
        );
        ParseOutcome.AttachmentRecord other = new ParseOutcome.AttachmentRecord(
                "C-OTHER", null, "file2.pdf", "application/pdf",
                "BYTES2".getBytes(), new byte[]{9,9}, 6
        );

        PersistService.PersistCounts out =
                service.persistSubmission(fileId, submissionDTO, List.of(matching, other));

        // counts
        assertThat(out.claims()).isEqualTo(1);
        assertThat(out.acts()).isEqualTo(1);
        assertThat(out.obs()).isEqualTo(1);
        assertThat(out.dxs()).isEqualTo(1);
        assertThat(out.remitClaims()).isZero();
        assertThat(out.remitActs()).isZero();

        // exactly one attachment insert (only the matching one)
        verify(jdbc, times(1))
                .update(argThat((String sql) -> sql.contains("insert into claims.claim_attachment")),
                        any(Object[].class));

        // no duplicate errors logged
        verify(errors, never()).claimError(anyLong(), anyString(), anyString(),
                eq("DUP_SUBMISSION_NO_RESUB"), anyString(), anyBoolean());
        verify(errors, never()).fileError(anyLong(), anyString(), anyString(), anyString(), anyBoolean());
    }

    @Test
    void persistSubmission_duplicate_without_resubmission_isSkipped_andLogged() {
        long fileId = 11L;

        // submission insert -> id
        when(jdbc.queryForObject(
                startsWith("insert into claims.submission"),
                eq(Long.class), any())
        ).thenReturn(101L);

        // isAlreadySubmitted -> true:
        // 1) claim_key exists (return non-null id)
        when(jdbc.query(
                startsWith("select id from claims.claim_key"),
                any(PreparedStatementSetter.class),
                any(ResultSetExtractor.class))
        ).thenReturn(222L);

        // 2) count(*) for existing SUBMISSION events > 0
        when(jdbc.queryForObject(
                eq("select count(*) from claims.claim_event where claim_key_id=? and type=1"),
                eq(Integer.class), any())
        ).thenReturn(1);

        // generic updates (even if called) succeed
        //when(jdbc.update(anyString(), any(Object[].class))).thenReturn(1);

        PersistService.PersistCounts out =
                service.persistSubmission(fileId, submissionDTO, List.of());

        // no graph persisted
        assertThat(out.claims()).isEqualTo(0);
        assertThat(out.acts()).isEqualTo(0);
        assertThat(out.obs()).isEqualTo(0);
        assertThat(out.dxs()).isEqualTo(0);

        // errors logged
        verify(errors).claimError(eq(fileId), eq("VALIDATE"), eq("C-1"),
                eq("DUP_SUBMISSION_NO_RESUB"),
                contains("Duplicate Claim.Submission without <Resubmission>"), eq(false));
        verify(errors).fileError(eq(fileId), eq("VALIDATE"),
                eq("DUP_SUBMISSION_NO_RESUB_SUMMARY"),
                contains("Skipped 1 duplicate submission"), eq(false));

        // no attachment inserts
        verify(jdbc, never())
                .update(argThat((String sql) -> sql.contains("insert into claims.claim_attachment")),
                        any(Object[].class));
    }
}
