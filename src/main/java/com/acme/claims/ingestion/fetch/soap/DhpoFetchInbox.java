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
@Profile({"ingestion","soap"})
public class DhpoFetchInbox {

    private final BlockingQueue<WorkItem> queue = new LinkedBlockingQueue<>(1024);
    private final BlockingQueue<WorkItem> ingestionQueue;

    public DhpoFetchInbox(@Qualifier("ingestionQueue") BlockingQueue<WorkItem> ingestionQueue) {
        this.ingestionQueue = ingestionQueue;
    }

    /** Generic submit allowing explicit source/sourcePath. */
    public void submit(String fileId, byte[] xmlBytes, Path sourcePath, String source, String fileName) {
        WorkItem workItem = new WorkItem(fileId, xmlBytes, sourcePath, source, fileName);
        queue.offer(workItem);
        ingestionQueue.offer(workItem); // Also put in shared ingestion queue for orchestrator
    }

    /** Convenience for SOAP (sourcePath=null, source="soap"). */
    public void submitSoap(String fileId, byte[] xmlBytes, String fileName) {
        submit(fileId, xmlBytes, null, "soap", fileName);
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
