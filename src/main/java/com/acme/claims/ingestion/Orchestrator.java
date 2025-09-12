/*
 * SSOT NOTICE — Orchestrator
 * Flow: Fetcher → Queue → Executor → Pipeline → VerifyService → (optional ACK)
 * Fix: IngestionProperties is now a single bean (no @Component on the properties class).
 */
package com.acme.claims.ingestion;

import com.acme.claims.ingestion.ack.Acker;
import com.acme.claims.ingestion.config.IngestionProperties;
import com.acme.claims.ingestion.fetch.Fetcher;
import com.acme.claims.ingestion.fetch.WorkItem;
import com.acme.claims.ingestion.verify.VerifyService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.annotation.Profile;
import org.springframework.context.event.EventListener;
import org.springframework.core.task.TaskExecutor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.concurrent.BlockingQueue;

@Component
@Profile("ingestion")
public class Orchestrator {

    private static final Logger log = LoggerFactory.getLogger(Orchestrator.class);

    private final Fetcher fetcher;
    private final IngestionProperties props; // single bean now
    private final BlockingQueue<WorkItem> queue;
    private final TaskExecutor executor;
    private final Pipeline pipeline;
    private final VerifyService verifyService;
    private final Acker acker;


    public Orchestrator(@Qualifier("soapFetcherAdapter") Fetcher fetcher,
                        IngestionProperties props,
                        @Qualifier("ingestionQueue") BlockingQueue<WorkItem> queue,
                        @Qualifier("ingestionExecutor") TaskExecutor executor,
                        Pipeline pipeline,
                        VerifyService verifyService, @Qualifier("soapAckerAdapter") Acker acker) {
        this.fetcher = fetcher;
        this.props = props;
        this.queue = queue;
        this.executor = executor;
        this.pipeline = pipeline;
        this.verifyService = verifyService;
        this.acker = acker;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void onReady() {
        log.info("Orchestrator starting — mode={}, stageToDisk={}, workers={}",
                props.getMode(), props.isStageToDisk(), props.getConcurrency().getParserWorkers());
        fetcher.start(this::enqueue);
    }

    private void enqueue(WorkItem wi) {
        if (!queue.offer(wi)) {
            log.debug("Queue full (size={}); pausing fetcher", queue.size());
            fetcher.pause();
        }
    }

    @Scheduled(initialDelayString = "0", fixedDelayString = "${claims.ingestion.poll.fixedDelayMs}")
    public void drain() {
        log.debug("Drain cycle start; queued={}", queue.size());
        int burst = Math.max(1, props.getConcurrency().getParserWorkers());
        int submitted = 0;
        while (submitted < burst) {
            WorkItem wi = queue.poll();
            if (wi == null) break;
            submitted++;
            executor.execute(() -> processOne(wi));
        }
        if (queue.remainingCapacity() > 0) fetcher.resume();
        log.debug("Drain cycle end; dispatched={}", submitted);
    }

    private void processOne(WorkItem wi) {
        boolean success = false;
        try {
            var result = pipeline.process(wi);
            boolean verified = verifyService.verifyFile(result.ingestionFileId());
            success = verified;
            log.info("INGEST OK fileId={} rootType={} parsed[claims={},acts={}] persisted[claims={},acts={}] verified={}",
                    wi.fileId(), result.rootType(), result.parsedClaims(), result.parsedActivities(),
                    result.persistedClaims(), result.persistedActivities(), verified);

        } catch (Exception ex) {
            log.error("INGEST FAIL fileId={} source={} : {}", wi.fileId(), wi.source(), ex.getMessage(), ex);
            success = false;
        } finally {
            if (props.getAck().isEnabled() && acker != null) {
                try {
                    acker.maybeAck(wi.fileId(), success);
                } catch (Exception ackEx) {
                    log.warn("ACK(success) failed fileId={}: {}", wi.fileId(), ackEx.getMessage());
                }
            }
        }
    }
}
