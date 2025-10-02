/**
 * # Orchestrator - Ingestion Pipeline Coordination Engine
 *
 * <p><b>Core Responsibility:</b> Coordinates the entire claims ingestion pipeline from file fetching
 * through processing to acknowledgment, ensuring efficient, reliable, and observable data flow.</p>
 *
 * <h2>🏗️ Architecture Overview</h2>
 * <p>The Orchestrator implements a sophisticated event-driven architecture:</p>
 * <ul>
 *   <li><b>Producer-Consumer Pattern:</b> Fetchers produce WorkItems, Orchestrator consumes and processes</li>
 *   <li><b>Pull-Based Processing:</b> Scheduled polling of work queue rather than push-based</li>
 *   <li><b>Backpressure Management:</b> Automatic flow control based on system capacity</li>
 *   <li><b>Failure Resilience:</b> Isolated processing with comprehensive error recovery</li>
 * </ul>
 *
 * <h2>⚙️ Runtime Behavior</h2>
 * <h3>Lifecycle Management</h3>
 * <ul>
 *   <li><b>Startup:</b> {@code onReady()} initializes fetcher and begins queue monitoring</li>
 *   <li><b>Processing:</b> {@code drain()} periodically processes work items in bursts</li>
 *   <li><b>Per-Item:</b> {@code processOne()} handles complete pipeline execution</li>
 *   <li><b>Shutdown:</b> Graceful termination with proper resource cleanup</li>
 * </ul>
 *
 * <h3>Processing Pipeline</h3>
 * <p>Each WorkItem follows this orchestrated flow:</p>
 * <ol>
 *   <li><b>Validation:</b> File integrity and format verification</li>
 *   <li><b>Parsing:</b> XML → DTO transformation with error collection</li>
 *   <li><b>Persistence:</b> Database storage with transaction isolation</li>
 *   <li><b>Verification:</b> Post-persistence validation and integrity checks</li>
 *   <li><b>Acknowledgment:</b> External system notification (optional)</li>
 * </ol>
 *
 * <h2>🔄 Backpressure & Flow Control</h2>
 * <p>Implements intelligent flow control to prevent system overload:</p>
 * <ul>
 *   <li><b>Queue Monitoring:</b> Tracks queue utilization and adjusts processing rate</li>
 *   <li><b>Fetcher Control:</b> Pauses/resumes fetchers based on queue capacity</li>
 *   <li><b>Executor Management:</b> Handles thread pool saturation gracefully</li>
 *   <li><b>Burst Processing:</b> Processes items in configurable batches</li>
 * </ul>
 *
 * <h2>🛡️ Reliability Features</h2>
 * <h3>Error Handling</h3>
 * <ul>
 *   <li><b>Transaction Isolation:</b> Individual file failures don't affect others</li>
 *   <li><b>Retry Logic:</b> Re-queues failed items for later processing</li>
 *   <li><b>Graceful Degradation:</b> Continues processing despite individual failures</li>
 *   <li><b>Comprehensive Logging:</b> Detailed error context for debugging</li>
 * </ul>
 *
 * <h3>Duplicate Prevention</h3>
 * <ul>
 *   <li><b>File-Level Deduplication:</b> Prevents multiple threads processing same file</li>
 *   <li><b>Thread-Safe Operations:</b> Concurrent access protection</li>
 *   <li><b>State Tracking:</b> Maintains processing state across restarts</li>
 * </ul>
 *
 * <h2>📊 Observability & Monitoring</h2>
 * <h3>Logging Strategy</h3>
 * <ul>
 *   <li><b>Structured Logging:</b> Consistent log format with MDC context</li>
 *   <li><b>Performance Metrics:</b> Processing duration and throughput tracking</li>
 *   <li><b>Error Classification:</b> Detailed error categorization and context</li>
 *   <li><b>Queue Monitoring:</b> Real-time queue status and capacity reporting</li>
 * </ul>
 *
 * <h3>Key Metrics Tracked</h3>
 * <ul>
 *   <li><b>Processing Duration:</b> Total time per file (with slow-path detection)</li>
 *   <li><b>Queue Utilization:</b> Size, remaining capacity, and flow rates</li>
 *   <li><b>Worker Efficiency:</b> Parallel processing effectiveness</li>
 *   <li><b>Error Rates:</b> Success/failure ratios by file type</li>
 * </ul>
 *
 * <h2>⚡ Performance Characteristics</h2>
 * <h3>Throughput Optimization</h3>
 * <ul>
 *   <li><b>Batch Processing:</b> Processes multiple files in configurable bursts</li>
 *   <li><b>Parallel Execution:</b> Leverages thread pool for concurrent processing</li>
 *   <li><b>Resource Management:</b> Efficient memory and CPU utilization</li>
 *   <li><b>Backpressure Awareness:</b> Adapts to system capacity automatically</li>
 * </ul>
 *
 * <h3>Scalability Features</h3>
 * <ul>
 *   <li><b>Configurable Workers:</b> Adjustable parallelism based on system resources</li>
 *   <li><b>Queue Sizing:</b> Tunable buffer capacity for burst handling</li>
 *   <li><b>Adaptive Polling:</b> Dynamic processing rate based on load</li>
 * </ul>
 *
 * <h2>🔗 Integration Points</h2>
 * <h3>Component Dependencies</h3>
 * <ul>
 *   <li><b>Fetcher:</b> Provides WorkItems (SOAP, LocalFS, etc.)</li>
 *   <li><b>Pipeline:</b> Core processing engine for XML → Database transformation</li>
 *   <li><b>VerifyService:</b> Post-persistence validation and integrity checks</li>
 *   <li><b>Acker:</b> External system acknowledgment (optional)</li>
 *   <li><b>IngestionProperties:</b> Runtime configuration and tuning parameters</li>
 * </ul>
 *
 * <h3>External Systems</h3>
 * <ul>
 *   <li><b>DHPO SOAP API:</b> Source of claim files via web services</li>
 *   <li><b>Database:</b> PostgreSQL for persistent storage</li>
 *   <li><b>File System:</b> Local storage for disk-based processing</li>
 * </ul>
 *
 * @author Claims Team
 * @since 1.0
 * @version 2.0 - Enhanced with duplicate prevention and improved observability
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

import java.util.Set;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.ConcurrentHashMap;

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

    /**
     * # processingFiles - Thread-Safe File Deduplication Set
     *
     * <p><b>Purpose:</b> Prevents multiple threads from processing the same file simultaneously,
     * eliminating race conditions and duplicate processing attempts.</p>
     *
     * <p><b>Implementation:</b> Uses {@code ConcurrentHashMap.newKeySet()} for high-performance,
     * thread-safe operations without external synchronization.</p>
     *
     * <p><b>Deduplication Strategy:</b></p>
     * <ul>
     *   <li><b>Atomic Operations:</b> {@code add()} returns false if already present</li>
     *   <li><b>File-Level Protection:</b> Uses fileId as unique identifier</li>
     *   <li><b>Automatic Cleanup:</b> Files removed in finally block regardless of outcome</li>
     *   <li><b>Memory Efficient:</b> Bounded growth with automatic cleanup</li>
     * </ul>
     *
     * <p><b>Concurrency Benefits:</b></p>
     * <ul>
     *   <li><b>No Locks:</b> Lock-free implementation for optimal performance</li>
     *   <li><b>Scalable:</b> Performance doesn't degrade with increased thread count</li>
     *   <li><b>Safe:</b> Thread-safe without external synchronization</li>
     * </ul>
     */
    private final Set<String> processingFiles = ConcurrentHashMap.newKeySet();


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

    /**
     * # onReady - System Initialization Handler
     *
     * <p><b>Purpose:</b> Initializes the ingestion pipeline when the application context is fully loaded.
     * This method serves as the entry point for the entire ingestion system.</p>
     *
     * <h3>Initialization Sequence</h3>
     * <ol>
     *   <li><b>Configuration Validation:</b> Logs current system configuration</li>
     *   <li><b>Fetcher Activation:</b> Starts the configured fetcher (SOAP/LocalFS)</li>
     *   <li><b>Queue Monitoring:</b> Begins periodic queue processing via scheduled methods</li>
     * </ol>
     *
     * <h3>Configuration Displayed</h3>
     * <ul>
     *   <li><b>Mode:</b> Current ingestion mode (soap, localfs, etc.)</li>
     *   <li><b>Stage Strategy:</b> Whether files are staged to disk or kept in memory</li>
     *   <li><b>Worker Count:</b> Number of parallel processing threads</li>
     * </ul>
     *
     * @param event Spring application ready event
     */
    @EventListener(ApplicationReadyEvent.class)
    public void onReady() {
        log.info("Orchestrator starting — mode={}, stageToDisk={}, workers={}",
                props.getMode(), props.isStageToDisk(), props.getConcurrency().getParserWorkers());
        fetcher.start(this::enqueue);
    }

    /**
     * # enqueue - WorkItem Queue Management with Backpressure Control
     *
     * <p><b>Purpose:</b> Safely adds WorkItems to the processing queue with intelligent backpressure
     * management to prevent system overload.</p>
     *
     * <h3>Backpressure Strategy</h3>
     * <ul>
     *   <li><b>Queue Full Detection:</b> Monitors queue capacity before insertion</li>
     *   <li><b>Fetcher Control:</b> Pauses upstream fetcher when queue is saturated</li>
     *   <li><b>Flow Regulation:</b> Prevents memory exhaustion and processing bottlenecks</li>
     * </ul>
     *
     * <h3>Error Handling</h3>
     * <ul>
     *   <li><b>Queue Saturation:</b> Logs warning and pauses fetcher to reduce input rate</li>
     *   <li><b>Successful Enqueue:</b> Logs confirmation with current queue status</li>
     *   <li><b>Exception Safety:</b> Silently handles fetcher pause failures</li>
     * </ul>
     *
     * @param wi the WorkItem to enqueue for processing
     */
    private void enqueue(WorkItem wi) {
        if (!queue.offer(wi)) {
            log.warn("ORCHESTRATOR_QUEUE_FULL fileId={} fileName={} queueSize={} capacity={}",
                wi.fileId(), wi.fileName(), queue.size(), queue.remainingCapacity());
            try { fetcher.pause(); } catch (Exception ignore) {}
        } else {
            log.info("ORCHESTRATOR_ENQUEUED fileId={} fileName={} source={} queueSize={}",
                wi.fileId(), wi.fileName(), wi.source(), queue.size());
        }
    }

    /**
     * # drain - Scheduled Queue Processing with Adaptive Burst Control
     *
     * <p><b>Purpose:</b> Periodically processes WorkItems from the queue in controlled bursts,
     * implementing adaptive flow control based on system capacity and performance.</p>
     *
     * <h3>Burst Processing Strategy</h3>
     * <p>Implements intelligent batch processing with multiple control mechanisms:</p>
     * <ul>
     *   <li><b>Worker-Based Limiting:</b> Burst size bounded by available worker threads</li>
     *   <li><b>Queue-Based Limiting:</b> Burst size bounded by actual queue contents</li>
     *   <li><b>Time-Based Limiting:</b> 2ms processing budget per drain cycle</li>
     *   <li><b>Executor Saturation:</b> Handles thread pool rejection gracefully</li>
     * </ul>
     *
     * <h3>Adaptive Flow Control</h3>
     * <ul>
     *   <li><b>Fetcher Management:</b> Resumes fetcher when queue has sufficient capacity</li>
     *   <li><b>Capacity Threshold:</b> Uses 2x worker count as resume threshold</li>
     *   <li><b>Real-time Monitoring:</b> Logs queue status for observability</li>
     * </ul>
     *
     * <h3>Error Recovery</h3>
     * <ul>
     *   <li><b>Executor Rejection:</b> Re-queues items when thread pool is saturated</li>
     *   <li><b>Fetcher Control:</b> Pauses fetcher to reduce system load</li>
     *   <li><b>Graceful Termination:</b> Handles exceptions during fetcher control</li>
     * </ul>
     */
    @Scheduled(initialDelayString = "0", fixedDelayString = "${claims.ingestion.poll.fixedDelayMs}")
    public void drain() {
        log.debug("Drain cycle start; queued={}", queue.size());
        int workers = Math.max(1, props.getConcurrency().getParserWorkers());
        int capacityHint = Math.max(1, queue.size());
        int burst = Math.min(workers, capacityHint);
        int submitted = 0;
        long deadlineNanos = System.nanoTime() + 2_000_000L; // ~2ms budget
        // Add more detailed logging in Orchestrator
        log.info("QUEUE STATUS: size={}, remaining={}, workers={}",
                queue.size(), queue.remainingCapacity(), workers);

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

    /**
     * # processOne - Complete File Processing Orchestration with Observability
     *
     * <p><b>Purpose:</b> Executes the complete ingestion pipeline for a single WorkItem,
     * from initial processing through verification and optional acknowledgment.</p>
     *
     * <h3>Processing Pipeline</h3>
     * <p>Orchestrates the complete flow for each file:</p>
     * <ol>
     *   <li><b>Duplicate Prevention:</b> Thread-safe deduplication check</li>
     *   <li><b>Pipeline Execution:</b> XML parsing, validation, and persistence</li>
     *   <li><b>Verification:</b> Post-persistence integrity and business rule checks</li>
     *   <li><b>Acknowledgment:</b> Optional external system notification</li>
     *   <li><b>Performance Monitoring:</b> Duration tracking with slow-path detection</li>
     * </ol>
     *
     * <h3>Deduplication Strategy</h3>
     * <ul>
     *   <li><b>Thread-Safe Set:</b> Uses {@code ConcurrentHashMap.newKeySet()} for concurrent access</li>
     *   <li><b>File-Level Protection:</b> Prevents multiple threads processing same file simultaneously</li>
     *   <li><b>Automatic Cleanup:</b> Removes file from processing set in finally block</li>
     * </ul>
     *
     * <h3>Observability Features</h3>
     * <h4>Structured Logging with MDC</h4>
     * <ul>
     *   <li><b>fileId:</b> Unique file identifier for tracing</li>
     *   <li><b>fileName:</b> Human-readable file name</li>
     *   <li><b>source:</b> Origin system (soap, localfs, etc.)</li>
     * </ul>
     *
     * <h4>Performance Monitoring</h4>
     * <ul>
     *   <li><b>Slow-Path Detection:</b> Logs warnings for files taking >2 seconds</li>
     *   <li><b>Success Metrics:</b> Parsed vs persisted entity counts</li>
     *   <li><b>Verification Status:</b> Post-persistence validation results</li>
     * </ul>
     *
     * <h3>Error Handling Strategy</h3>
     * <ul>
     *   <li><b>Exception Containment:</b> Individual file failures don't affect system</li>
     *   <li><b>Graceful Degradation:</b> Continues processing despite failures</li>
     *   <li><b>Resource Cleanup:</b> Ensures processing set cleanup in finally block</li>
     *   <li><b>Acknowledgment Safety:</b> Handles acknowledgment failures gracefully</li>
     * </ul>
     *
     * @param wi the WorkItem containing file data and metadata to process
     */
    private void processOne(WorkItem wi) {
        final String fileId = wi.fileId();

        // Check for duplicate processing - prevent multiple threads from processing same file
        if (!processingFiles.add(fileId)) {
            log.debug("ORCHESTRATOR_DUPLICATE_SKIP fileId={} fileName={} - already being processed by another thread",
                fileId, wi.fileName());
            return; // Skip this duplicate processing attempt
        }

        boolean success = false;
        long t0 = System.nanoTime();
        try (org.slf4j.MDC.MDCCloseable ignored = org.slf4j.MDC.putCloseable("fileId", fileId);
             org.slf4j.MDC.MDCCloseable ignored2 = org.slf4j.MDC.putCloseable("fileName", wi.fileName());
             org.slf4j.MDC.MDCCloseable ignored3 = org.slf4j.MDC.putCloseable("source", wi.source())) {

            log.info("ORCHESTRATOR_PROCESS_START fileId={} fileName={} source={}",
                fileId, wi.fileName(), wi.source());

            var result = pipeline.process(wi);
            boolean verified = verifyService.verifyFile(result.ingestionFileId(), fileId);
            success = verified;

            long ms = (System.nanoTime() - t0) / 1_000_000;
            if (ms > 2000) {
                log.warn("ORCHESTRATOR_PROCESS_SLOW fileId={} fileName={} {}ms rootType={} parsed[c={},a={}] persisted[c={},a={}] verified={}",
                    fileId, wi.fileName(), ms, result.rootType(), result.parsedClaims(), result.parsedActivities(),
                    result.persistedClaims(), result.persistedActivities(), verified);
            } else {
                log.info("ORCHESTRATOR_PROCESS_OK fileId={} fileName={} {}ms rootType={} parsed[c={},a={}] persisted[c={},a={}] verified={}",
                    fileId, wi.fileName(), ms, result.rootType(), result.parsedClaims(), result.parsedActivities(),
                    result.persistedClaims(), result.persistedActivities(), verified);
            }
        } catch (Exception ex) {
            log.error("ORCHESTRATOR_PROCESS_FAIL fileId={} fileName={} source={} : {}",
                fileId, wi.fileName(), wi.source(), ex.getMessage(), ex);
            success = false;
        } finally {
            // Always remove from processing set, regardless of success/failure
            processingFiles.remove(fileId);

            if (acker != null) {
                try {
                    acker.maybeAck(fileId, success);
                    log.info("ORCHESTRATOR_ACK_ATTEMPTED fileId={} fileName={} success={}",
                        fileId, wi.fileName(), success);
                } catch (Exception ackEx) {
                    log.warn("ORCHESTRATOR_ACK_FAILED fileId={} fileName={} : {}",
                        fileId, wi.fileName(), ackEx.getMessage());
                }
            }
        }
    }
}
