package com.acme.claims.ingestion.ack;

import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Profile("localfs")
@Slf4j
public class NoopAcker implements Acker {
    @Override
    public void maybeAck(String fileId, boolean success) {
        log.trace("Noop ACK (localfs) fileId={} success={}", fileId, success);
    }
}
