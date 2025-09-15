package com.acme.claims.soap;

import com.acme.claims.ingestion.Orchestrator;
import com.acme.claims.ingestion.Pipeline;
import com.acme.claims.ingestion.fetch.Fetcher;
import com.acme.claims.ingestion.fetch.WorkItem;
import org.awaitility.Awaitility;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.ActiveProfiles;

import java.time.Duration;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Consumer;

import static org.mockito.Mockito.*;

/**
 * Validates that with profiles ingestion+soap, the Orchestrator consumes fileIds from the fetcher
 * and delegates to Pipeline.process(fileId). DB/persistence is out of scope here.
 */
@SpringBootTest
@ActiveProfiles({"ingestion", "soap", "test"})
class SoapOrchestratorFlowTest {

    @Autowired
    Orchestrator orchestrator; // ensure context wires ingestion beans
    @Autowired
    @Qualifier("soapFetcherAdapter")
    Fetcher fetcher;

    @MockBean
    Pipeline pipeline; // only interaction we assert in this class

    @Test
    void happyPath_submission_then_remittance_processed() {
        // Arrange: capture the consumer Orchestrator supplied to Fetcher.start(...)
        AtomicReference<Consumer<WorkItem>> onReadyRef = new AtomicReference<>();
        doAnswer(inv -> {
            onReadyRef.set(inv.getArgument(0));
            return null;
        })
                .when(fetcher).start(any());

        byte[] subXml = "<Claim.Submission/>".getBytes();
        byte[] remXml = "<Remittance.Advice/>".getBytes();
        var wi1 = new WorkItem("FILE_SUB_001", subXml, null, "soap");
        var wi2 = new WorkItem("FILE_REM_002", remXml, null, "soap"); // see Fix B note below

        // Trigger orchestrator init (already happens via context), then emit tokens:
        Consumer<WorkItem> onReady = onReadyRef.get();
        onReady.accept(wi1);
        onReady.accept(wi2);

        Awaitility.await().atMost(Duration.ofSeconds(3))
                .untilAsserted(() -> {
                    verify(pipeline, atLeastOnce()).process(wi1);
                    verify(pipeline, atLeastOnce()).process(wi2);
                });
    }

    @Test
    void duplicate_fileId_second_attempt_does_not_break_flow() {
        AtomicReference<Consumer<WorkItem>> onReadyRef = new AtomicReference<>();
        doAnswer(inv -> {
            onReadyRef.set(inv.getArgument(0));
            return null;
        })
                .when(fetcher).start(any());
        byte[] subXml = "<Claim.Submission/>".getBytes();
        var wi1 = new WorkItem("FILE_SUB_001", subXml, null, "soap");

        // Simulate first ok, second raise duplicate
        doNothing().doThrow(new RuntimeException("duplicate key")).when(pipeline).process(wi1);

        Consumer<WorkItem> onReady = onReadyRef.updateAndGet(c -> c != null ? c : (fid) -> {
        });
        onReady.accept(new WorkItem("FILE_DUP_003", "<Claim.Submission/>".getBytes(), null, "soap"));
        onReady.accept(new WorkItem("FILE_DUP_003", "<Claim.Submission/>".getBytes(), null, "soap"));

        // First call happens, second throws but orchestrator should survive:
        Awaitility.await().atMost(Duration.ofSeconds(2))
                .untilAsserted(() -> verify(pipeline, times(2)).process(wi1));
    }
}
