/*
 * SSOT NOTICE — SOAP Acker (stub)
 * Profile: soap
 * Purpose: Best-effort SOAP ACK to DHPO (or equivalent) after success/failure.
 * Notes:
 *   - Guard actual calls behind claims.ingestion.ack.enabled=true.
 *   - Caller (Orchestrator) already handles try/catch and logs WARN if this fails.
 */
package com.acme.claims.ingestion.ack;

import com.acme.claims.ingestion.config.IngestionProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Profile("soap-stub")
public class SoapAcker implements Acker {
    private static final Logger log = LoggerFactory.getLogger(SoapAcker.class);
    private final IngestionProperties props;

    public SoapAcker(IngestionProperties props) {
        this.props = props;
    }

    @Override
    public void maybeAck(String fileId, boolean success) {
        // TODO: Implement SOAP call to remote ACK endpoint (props.getSoap().getEndpoint(), creds).
        // Keep it best-effort; do not throw. // inline doc
        log.info("SOAP ACK (stub) fileId={} success={} endpoint={}", fileId, success,
                props.getSoap() != null ? props.getSoap().getEndpoint() : "<unset>");
    }
}
