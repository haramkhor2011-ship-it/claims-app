package com.acme.claims;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.core.env.Environment;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
@ConfigurationPropertiesScan(basePackages = "com.acme.claims")
@Slf4j
public class ClaimsBackendApplication {
    @Autowired
    Environment environment;
    public static void main(String[] args) {
        SpringApplication.run(ClaimsBackendApplication.class, args);
    }

    @jakarta.annotation.PostConstruct
    void logBootEnv() {
        log
                .info("boot: profiles={}, url={}, user={}",
                        String.join(",", environment.getActiveProfiles()),
                        environment.getProperty("spring.datasource.url"),
                        environment.getProperty("spring.datasource.username"));
    }
}
