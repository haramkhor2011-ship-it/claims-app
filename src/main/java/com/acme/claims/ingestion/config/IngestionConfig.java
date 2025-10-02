/*
 * SSOT NOTICE — Ingestion Config (Beans)
 * Roots handled: Claim.Submission, Remittance.Advice
 * Purpose: Provide shared beans for the pipeline (executor, queue) and enable scheduling.
 * Notes:
 *   - Thread pool is sized via properties.concurrency.parserWorkers.
 *   - Queue capacity is sized for burst scenarios (e.g., ~100 files/30 minutes).
 */
package com.acme.claims.ingestion.config;

import com.acme.claims.ingestion.fetch.WorkItem;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.core.task.TaskExecutor;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;

@Configuration
@EnableScheduling // enables orchestrator @Scheduled poller
@Profile("ingestion")
public class IngestionConfig {

    @Bean(name = "ingestionQueue")
    public BlockingQueue<WorkItem> ingestionQueue(IngestionProperties props) {
        // Bounded queue to apply backpressure if fetchers push faster than we can ingest. // inline doc
        return new ArrayBlockingQueue<>(props.getQueue().getCapacity());
    }

    @Bean(name = "ingestionExecutor")
    public TaskExecutor ingestionExecutor(IngestionProperties props) {
        // Dedicated thread pool for parsing/persisting without blocking scheduler threads. // inline doc
        ThreadPoolTaskExecutor ex = new ThreadPoolTaskExecutor();
        ex.setCorePoolSize(props.getConcurrency().getParserWorkers());
        ex.setMaxPoolSize(props.getConcurrency().getParserWorkers());
        ex.setQueueCapacity(props.getConcurrency().getParserWorkers());
        ex.setThreadNamePrefix("ingest-");
        ex.initialize();
        return ex;
    }
}
