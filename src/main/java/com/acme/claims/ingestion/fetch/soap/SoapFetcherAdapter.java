// src/main/java/com/acme/claims/ingestion/fetch/soap/SoapFetcherAdapter.java
package com.acme.claims.ingestion.fetch.soap;

import com.acme.claims.ingestion.fetch.Fetcher;
import com.acme.claims.ingestion.fetch.WorkItem;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

/**
 * Thin adapter that bridges DHPO downloads (via DhpoFetchInbox) to the generic Fetcher SPI.
 * Non-blocking: runs its own loop thread that forwards WorkItems to the pipeline.
 */
@Slf4j
@Component
@Profile({"ingestion","soap"})
@RequiredArgsConstructor
public class SoapFetcherAdapter implements Fetcher {

    private final DhpoFetchInbox inbox; // coordinator pushes into this
    private final AtomicBoolean paused = new AtomicBoolean(false);
    private final ExecutorService loop = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "soap-fetch-loop");
        t.setDaemon(true);
        return t;
    });

    @Override
    public void start(Consumer<WorkItem> onReady) {
        log.debug("[SOAP] Fetcher adapter starting");
        loop.submit(() -> {
            while (!Thread.currentThread().isInterrupted()) {
                try {
                    if (paused.get()) { Thread.sleep(200); continue; } // cheap pause
                    WorkItem wi = inbox.takeInterruptibly();          // blocks until item arrives
                    onReady.accept(wi);                                // push downstream
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                } catch (Throwable t) {
                    log.warn("[SOAP] Fetcher loop error: {}", t.toString());
                }
            }
        });
    }

    @Override public void pause()  { paused.set(true);  log.debug("[SOAP] Fetcher paused"); }
    @Override public void resume() { paused.set(false); log.debug("[SOAP] Fetcher resumed"); }
}
