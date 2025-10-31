// src/main/java/com/acme/claims/soap/SoapProperties.java
package com.acme.claims.soap;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "claims.soap")
public record SoapProperties(
        String endpoint,
        Boolean soap12, // false => SOAP 1.1
        Integer connectTimeoutMs,
        Integer readTimeoutMs,
        RetryProps retry,
        PollProps poll,
        String transport,
        Integer downloadConcurrency,
        FacilityPollProps facilityPoll,
        MetricsToggles metrics
) {
    public record RetryProps(Integer maxAttempts, Long backoffMs) {}
    public record PollProps(Integer fixedDelayMs) {}
    public record FacilityPollProps(String strategy, Long staggerIntervalMs, Integer maxConcurrent, Boolean enableAdvanced) {}
    public record MetricsToggles(Boolean facilityQueueEnabled) {}
}
