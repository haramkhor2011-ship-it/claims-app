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

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.mockito.Mockito.atLeastOnce;

@SpringBootTest
@ActiveProfiles({"ingestion","soap","test"})
@TestPropertySource(properties = {
        "claims.ack.enabled=false"  // disbale ACK path
})
public class AckGatingDisbaledTest {
    @Autowired
    Orchestrator orchestrator;
    @Autowired @Qualifier("soapFetcherAdapter") Fetcher fetcher;

    @MockBean
    Pipeline pipeline;
    @MockBean
    AckGatingSuccessTest.StageVerify verifyStage;
    @MockBean
    AckGatingSuccessTest.StageAck ackStage;
    // If your app exposes these as beans; otherwise you can delete these two mocks safely.
    public interface StageVerify { boolean check(String fileId); }
    public interface StageAck { void maybeAck(String fileId); }

    @Test
    void ack_enabled_only_on_verify_green() {
        AtomicReference<Consumer<WorkItem>> onReadyRef = new AtomicReference<>();
        doAnswer(inv -> { onReadyRef.set(inv.getArgument(0)); return null; }).when(fetcher).start(any());
        doNothing().when(pipeline).process(any());


        if (verifyStage != null) {
            when(verifyStage.check("FILE_RED_200")).thenReturn(false);
            when(verifyStage.check("FILE_GRN_201")).thenReturn(true);
        }

        Consumer<WorkItem> onReady = onReadyRef.updateAndGet(c -> c != null ? c : (fid) -> {});
        onReady.accept(new WorkItem("FILE_RED_200", "<Claim.Submission>".getBytes(), null, "soap"));
        onReady.accept(new WorkItem("FILE_GRN_201", "<Claim.Submission>".getBytes(), null, "soap"));

        var wi1 = new WorkItem("FILE_SUB_001", "<Claim.Submission/>".getBytes(), null, "soap");
        var wi2 = new WorkItem("FILE_SUB_001", "<Claim.Submission/>".getBytes(), null, "soap");

        Awaitility.await().atMost(Duration.ofSeconds(3))
                .untilAsserted(() -> {
                    verify(pipeline, atLeastOnce()).process(wi1);
                    verify(pipeline, atLeastOnce()).process(wi2);
                });

        if (ackStage != null) {
            verify(ackStage, never()).maybeAck("FILE_RED_200");
            verify(ackStage, atLeastOnce()).maybeAck("FILE_GRN_201");
        }
    }
}
