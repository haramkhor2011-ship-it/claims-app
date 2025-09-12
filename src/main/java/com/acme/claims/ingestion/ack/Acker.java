package com.acme.claims.ingestion.ack;

public interface Acker {
    void maybeAck(String fileId, boolean success);
}
