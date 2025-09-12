/*
 * SSOT NOTICE — RootDetector
 * Purpose: Lightweight XML root detection to route parsing without a full pass.
 * Contract: Returns SUBMISSION for <Claim.Submission ...> and REMITTANCE for <Remittance.Advice ...>.
 */
package com.acme.claims.ingestion.util;

public final class RootDetector {
    public enum  RootKind { SUBMISSION, REMITTANCE }
    private RootDetector() {}

    public static RootKind detect(byte[] xml) {
        String s = new String(xml, java.nio.charset.StandardCharsets.UTF_8);
        if (s.contains("<Claim.Submission")) return RootKind.SUBMISSION;
        if (s.contains("<Remittance.Advice")) return RootKind.REMITTANCE;
        throw new IllegalArgumentException("Unknown XML root");
    }
}
