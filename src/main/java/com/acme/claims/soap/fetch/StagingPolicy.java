// src/main/java/com/acme/claims/fetch/StagingPolicy.java
package com.acme.claims.soap.fetch;

public record StagingPolicy(
        boolean forceDisk,
        long sizeThresholdBytes,
        long latencyThresholdMs,
        String readyDir
) {}
