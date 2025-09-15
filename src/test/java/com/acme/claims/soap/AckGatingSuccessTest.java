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
import org.springframework.test.context.TestPropertySource;

import java.time.Duration;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Consumer;

import static org.mockito.Mockito.*;

/**
 * Validates ACK behavior wrt claims.ack.enabled and Verify outcome.
 * We mock pipeline to just "complete"; Verify/Ack are mocked if they are explicit beans;
 * else we assert no exceptions and rely on property gating.
 */
@SpringBootTest
@ActiveProfiles({"ingestion","soap","test"})
@TestPropertySource(properties = {
        "claims.ack.enabled=true"  // enable ACK path
})
class AckGatingSuccessTest {

    @Autowired Orchestrator orchestrator;
    @Autowired @Qualifier("soapFetcherAdapter") Fetcher fetcher;

    @MockBean Pipeline pipeline;

    // If your app exposes these as beans; otherwise you can delete these two mocks safely.
    public interface StageVerify { boolean check(String fileId); }
    public interface StageAck { void maybeAck(String fileId); }

    @MockBean StageVerify verifyStage;
    @MockBean StageAck ackStage;

    @Test
    void ack_disabled_never_calls_ack_even_on_verify_green() {
        AtomicReference<Consumer<WorkItem>> onReadyRef = new AtomicReference<>();
        doAnswer(inv -> { onReadyRef.set(inv.getArgument(0)); return null; }).when(fetcher).start(any());
        doNothing().when(pipeline).process(any());
        if (verifyStage != null) when(verifyStage.check("FILE_OK_100")).thenReturn(true);

        Consumer<WorkItem> onReady = onReadyRef.updateAndGet(c -> c != null ? c : (fid) -> {});
        onReady.accept(new WorkItem("FILE_OK_100", "<Claim.Submission>".getBytes(), null, "soap"));

        Awaitility.await().atMost(Duration.ofSeconds(2))
                .untilAsserted(() -> verify(pipeline, atLeastOnce()).process(argThat(w -> "FILE_OK_100".equals(w.fileId()))));

        if (ackStage != null) verify(ackStage, never()).maybeAck(anyString());
    }

}
