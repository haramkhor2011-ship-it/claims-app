/*
 * SSOT NOTICE — SOAP Fetcher (stub)
 * Profile: soap
 * Purpose: Pull XML from DHPO (or similar), emit WorkItems with bytes in-memory.
 * Notes:
 *   - Only one fetcher active via profiles.
 *   - Implement backpressure via pause()/resume() if streaming in loops.
 */
package com.acme.claims.ingestion.fetch;

import com.acme.claims.ingestion.config.IngestionProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.util.function.Consumer;

@Component
@Profile("soap")
public class SoapFetcher implements Fetcher {
    private static final Logger log = LoggerFactory.getLogger(SoapFetcher.class);

    private final IngestionProperties props;
    private volatile boolean paused = false;

    public SoapFetcher(IngestionProperties props){ this.props = props; }

    @Override
    public void start(Consumer<WorkItem> onReady) {
        // TODO: Call SOAP endpoint (props.getSoap().getEndpoint()/creds), fetch payload bytes per message,
        // then emit: onReady.accept(new WorkItem(remoteMessageId, xmlBytes, null, "soap"));
        log.info("SoapFetcher started (stub) endpoint={}",
                props.getSoap()!=null ? props.getSoap().getEndpoint() : "<unset>");
    }

    @Override public void pause()  { this.paused = true;  }
    @Override public void resume() { this.paused = false; }
}
