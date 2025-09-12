package com.acme.claims.util;

import lombok.extern.slf4j.Slf4j;

import java.time.Duration;
import java.time.Instant;
import java.util.function.Supplier;

/**
 * Measures and logs elapsed time for a task without leaking exceptions.
 */
@Slf4j
public final class StopWatchLog {

    private StopWatchLog() { }

    public static <T> T time(String label, Supplier<T> task) {
        final Instant start = Instant.now();
        try {
            T result = task.get();
            log.info("[STOPWATCH] {} took {} ms", label, Duration.between(start, Instant.now()).toMillis());
            return result;
        } catch (RuntimeException ex) {
            log.warn("[STOPWATCH] {} failed after {} ms: {}", label,
                    Duration.between(start, Instant.now()).toMillis(), ex.getMessage());
            throw ex; // rethrow for upstream handling
        }
    }

    public static void run(String label, Runnable task) {
        time(label, () -> { task.run(); return null; });
    }
}
