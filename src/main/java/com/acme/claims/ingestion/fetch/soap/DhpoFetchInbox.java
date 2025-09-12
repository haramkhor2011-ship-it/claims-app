// src/main/java/com/acme/claims/ingestion/fetch/soap/DhpoFetchInbox.java
package com.acme.claims.ingestion.fetch.soap;

import com.acme.claims.ingestion.fetch.WorkItem;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.nio.file.Path;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;

@Component
@Profile({"ingestion","soap"})
public class DhpoFetchInbox {

    private final BlockingQueue<WorkItem> queue = new LinkedBlockingQueue<>(1024);

    /** Generic submit allowing explicit source/sourcePath. */
    public void submit(String fileId, byte[] xmlBytes, Path sourcePath, String source) {
        queue.offer(new WorkItem(fileId, xmlBytes, sourcePath, source));
    }

    /** Convenience for SOAP (sourcePath=null, source="soap"). */
    public void submitSoap(String fileId, byte[] xmlBytes) {
        submit(fileId, xmlBytes, null, "soap");
    }

    WorkItem takeInterruptibly() throws InterruptedException {
        return queue.take();
    }
}
