// src/main/java/com/acme/claims/ingestion/fetch/soap/DhpoFetchInbox.java
package com.acme.claims.ingestion.fetch.soap;

import com.acme.claims.ingestion.fetch.WorkItem;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.nio.file.Path;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;

@Component
@Profile("soap")
public class DhpoFetchInbox {

    private final BlockingQueue<WorkItem> queue = new LinkedBlockingQueue<>(1024);
    private final BlockingQueue<WorkItem> ingestionQueue;

    public DhpoFetchInbox(@Qualifier("ingestionQueue") BlockingQueue<WorkItem> ingestionQueue) {
        this.ingestionQueue = ingestionQueue;
    }

    /** Generic submit allowing explicit source/sourcePath. */
    public boolean submit(String fileId, byte[] xmlBytes, Path sourcePath, String source, String fileName) {
        WorkItem workItem = new WorkItem(fileId, xmlBytes, sourcePath, source, fileName);
        boolean enqueued = queue.offer(workItem);
        if (!enqueued) {
            // Queue is full. Block briefly to avoid drops, then retry once non-blocking.
            try {
                // Best-effort: wait up to 250ms before giving up
                return queue.offer(workItem, 250, java.util.concurrent.TimeUnit.MILLISECONDS);
            } catch (InterruptedException ie) {
                Thread.currentThread().interrupt();
                return false;
            }
        }
        // NOTE: ingestionQueue is handled by Orchestrator via SoapFetcherAdapter callback
        return true;
    }

    /** Convenience for SOAP (sourcePath=null, source="soap"). */
    public boolean submitSoap(String fileId, byte[] xmlBytes, String fileName) {
        return submit(fileId, xmlBytes, null, "soap", fileName);
    }

    WorkItem takeInterruptibly() throws InterruptedException {
        return queue.take();
    }

    public int size() {
        return queue.size();
    }

    // ADD this method to expose remaining capacity
    public int remainingCapacity() {
        return queue.remainingCapacity();
    }
}
