package com.acme.claims.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.ThreadPoolExecutor;

@Configuration
@EnableAsync
public class AsyncConfig {

    @Bean(name = "soapExecutor")
    public ThreadPoolTaskExecutor soapExecutor() {
        ThreadPoolTaskExecutor ex = new ThreadPoolTaskExecutor();
        ex.setThreadNamePrefix("soap-");
        ex.setCorePoolSize(16);        // start here; tune up/down
        ex.setMaxPoolSize(64);         // upper bound under load
        ex.setQueueCapacity(5000);     // large enough to avoid bursts rejecting
        ex.setKeepAliveSeconds(60);
        // When full, run task on caller thread instead of throwing:
        ex.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        ex.setWaitForTasksToCompleteOnShutdown(true);
        ex.setAwaitTerminationSeconds(30);
        ex.initialize();
        return ex;
    }
}
