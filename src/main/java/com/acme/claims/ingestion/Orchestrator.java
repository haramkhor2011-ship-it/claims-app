/**
 * Orchestrator
 *
 * Runtime:
 * - onReady(): starts the active Fetcher which produces WorkItem tokens.
 * - Scheduled drain(): dispatches a small burst of WorkItems to the executor.
 * - processOne(): runs Pipeline → Verify → optionally ACK.
 *
 * Backpressure:
 * - queue.offer() failure pauses fetcher; drain() resumes when capacity is available.
 *
 * Concurrency:
 * - Burst size bounded by parserWorkers; executor controls actual parallelism.
 *
 * Reliability:
 * - RejectedExecution re-queues the item and pauses fetcher.
 * - ACK true only after verification.
 *
 * Observability:
 * - MDC(fileId) surrounds processing; per-file duration logged with slow-path detection.
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
            try { fetcher.pause(); } catch (Exception ignore) {}
        }
    }

    @Scheduled(initialDelayString = "0", fixedDelayString = "${claims.ingestion.poll.fixedDelayMs}")
    public void drain() {
        log.debug("Drain cycle start; queued={}", queue.size());
        int workers = Math.max(1, props.getConcurrency().getParserWorkers());
        int capacityHint = Math.max(1, queue.size());
        int burst = Math.min(workers, capacityHint);
        int submitted = 0;
        long deadlineNanos = System.nanoTime() + 2_000_000L; // ~2ms budget

        while (submitted < burst && System.nanoTime() < deadlineNanos) {
            WorkItem wi = queue.poll();
            if (wi == null) break;
            try {
                executor.execute(() -> processOne(wi));
                submitted++;
            } catch (java.util.concurrent.RejectedExecutionException rex) {
                boolean requeued = queue.offer(wi);
                log.warn("Executor saturated; requeued={}, queueSize={}", requeued, queue.size());
                try { fetcher.pause(); } catch (Exception ignore) {}
                break;
            }
        }

        if (queue.remainingCapacity() > (workers * 2)) {
            try { fetcher.resume(); } catch (Exception ignore) {}
        }
        log.debug("Drain cycle end; dispatched={}", submitted);
    }

    private void processOne(WorkItem wi) {
        boolean success = false;
        long t0 = System.nanoTime();
        try (org.slf4j.MDC.MDCCloseable ignored = org.slf4j.MDC.putCloseable("fileId", wi.fileId())) {
            var result = pipeline.process(wi);
            boolean verified = verifyService.verifyFile(result.ingestionFileId(), wi.fileId());
            success = verified;
            long ms = (System.nanoTime() - t0) / 1_000_000;
            if (ms > 2000) {
                log.info("INGEST SLOW fileId={} {}ms rootType={} parsed[c={},a={}] persisted[c={},a={}] verified={}",
                        wi.fileId(), ms, result.rootType(), result.parsedClaims(), result.parsedActivities(),
                        result.persistedClaims(), result.persistedActivities(), verified);
            } else {
                log.info("INGEST OK fileId={} {}ms rootType={} parsed[c={},a={}] persisted[c={},a={}] verified={}",
                        wi.fileId(), ms, result.rootType(), result.parsedClaims(), result.parsedActivities(),
                        result.persistedClaims(), result.persistedActivities(), verified);
            }
        } catch (Exception ex) {
            log.error("INGEST FAIL fileId={} source={} : {}", wi.fileId(), wi.source(), ex.getMessage(), ex);
            success = false;
        } finally {
            if (acker != null) {
                try {
                    acker.maybeAck(wi.fileId(), success);
                } catch (Exception ackEx) {
                    log.warn("ACK(success) failed fileId={}: {}", wi.fileId(), ackEx.getMessage());
                }
            }
        }
    }
}
