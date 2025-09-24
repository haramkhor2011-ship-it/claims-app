/*
 * SSOT NOTICE — LocalFS Fetcher
 * Profile: localfs
 * Purpose: Watch a directory for *.xml and emit WorkItems with bytes in-memory.
 * Guarantees:
 *   - Initial sweep picks up existing files at startup.
 *   - WatchService listens for new files.
 *   - Backpressure-aware (pause/resume).
 */
package com.acme.claims.ingestion.fetch;

import com.acme.claims.ingestion.config.IngestionProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.nio.file.*;
import java.util.function.Consumer;

@Component
@Profile("localfs")
public class LocalFsFetcher implements Fetcher {
    private static final Logger log = LoggerFactory.getLogger(LocalFsFetcher.class);

    private final IngestionProperties props;
    private volatile boolean paused = false;

    public LocalFsFetcher(IngestionProperties props) {
        this.props = props;
    }

    @Override
    public void start(Consumer<WorkItem> onReady) {
        final Path ready = Paths.get(props.getLocalfs().getReadyDir());
        try { Files.createDirectories(ready); }
        catch (IOException e) { log.error("Ready dir create failed: {}", ready, e); return; }

        Thread t = new Thread(() -> {
            try {
                // Initial sweep
                try (DirectoryStream<Path> ds = Files.newDirectoryStream(ready, "*.xml")) {
                    for (Path p : ds) emit(onReady, p);
                } catch (Exception e) {
                    log.warn("Initial sweep error: {}", e.getMessage());
                }

                // Watch loop
                try (WatchService ws = FileSystems.getDefault().newWatchService()) {
                    ready.register(ws, StandardWatchEventKinds.ENTRY_CREATE);
                    for (;;) {
                        if (paused) { Thread.sleep(150L); continue; }
                        WatchKey key = ws.take();
                        for (WatchEvent<?> ev : key.pollEvents()) {
                            if (ev.kind() == StandardWatchEventKinds.OVERFLOW) continue;
                            Path rel = (Path) ev.context();
                            Path file = ready.resolve(rel);
                            if (file.toString().toLowerCase().endsWith(".xml")) emit(onReady, file);
                        }
                        key.reset();
                    }
                }
            } catch (InterruptedException ie) {
                Thread.currentThread().interrupt();
            } catch (Exception e) {
                log.error("LocalFS watch loop terminated: {}", e.getMessage(), e);
            }
        }, "fetch-localfs");

        t.setDaemon(true);
        t.start();
        log.info("LocalFsFetcher started; watching {}", ready);
    }

    private void emit(Consumer<WorkItem> onReady, Path file) {
        try {
            byte[] bytes = Files.readAllBytes(file);      // in-memory parse by pipeline
            String fileId = file.getFileName().toString();// stable id for idempotency/audit
            onReady.accept(new WorkItem(fileId, bytes, file, "localfs", file.getFileName().toString()));
        } catch (Exception e) {
            log.warn("Unreadable file {}: {}", file, e.toString());
        }
    }

    @Override public void pause() { this.paused = true; }
    @Override public void resume() { this.paused = false; }
}
