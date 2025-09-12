/*
 * SSOT NOTICE — Fetcher SPI
 * Roots handled: Claim.Submission, Remittance.Advice
 * Purpose: Abstraction for sources that supply XML files to the ingestion pipeline.
 * Notes:
 *   - Implementations push immutable WorkItem objects to the pipeline callback.
 *   - Exactly one Fetcher is active at a time via Spring profiles (localfs or soap).
 *   - The pipeline parses directly from WorkItem.xmlBytes (in-memory). No temp files required.
 */
package com.acme.claims.ingestion.fetch;

import java.util.function.Consumer;

public interface Fetcher {

    /**
     * Start streaming XML work items to the provided consumer. // inline doc
     * Implementations should be non-blocking (run their own watcher/loop threads). // inline doc
     */
    void start(Consumer<WorkItem> onReady);

    /** Temporarily stop producing new items (used for backpressure). */ // inline doc
    void pause();

    /** Resume producing items after a pause. */ // inline doc
    void resume();
}
