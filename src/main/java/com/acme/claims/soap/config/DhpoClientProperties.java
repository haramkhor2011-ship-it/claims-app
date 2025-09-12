package com.acme.claims.soap.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "dhpo.client")
public record DhpoClientProperties(
        boolean getNewEnabled,            // toggle GetNewTransactions
        int searchDaysBack,               // usually 100
        int retriesOnMinus4,              // agreed: 3
        int connectTimeoutMs,
        int readTimeoutMs,
        int downloadTimeoutMs,
        int stageToDiskThresholdMb        // when >= switch to disk
) {
    public DhpoClientProperties {
        if (retriesOnMinus4 < 0 || retriesOnMinus4 > 5) throw new IllegalArgumentException("retriesOnMinus4 out of range");
    }
}
