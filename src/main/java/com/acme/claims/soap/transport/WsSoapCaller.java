// src/main/java/com/acme/claims/soap/transport/WsSoapCaller.java
package com.acme.claims.soap.transport;


import com.acme.claims.soap.SoapGateway;
import com.acme.claims.soap.SoapProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.ws.WebServiceMessage;
import org.springframework.ws.client.core.WebServiceMessageCallback;
import org.springframework.ws.client.core.WebServiceTemplate;
import org.springframework.ws.soap.SoapMessage;
import org.springframework.xml.transform.StringSource;

import java.time.Duration;

@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "claims.soap.transport", havingValue = "ws", matchIfMissing = true)
public class WsSoapCaller implements SoapCaller {

    private final WebServiceTemplate wst; // your existing WebServiceTemplate bean
    private final SoapProperties props;

    @Override
    public SoapGateway.SoapResponse call(SoapGateway.SoapRequest req) {
        final String url = props.endpoint();

        var src = new StringSource(req.envelopeXml());
        var res = new org.springframework.xml.transform.StringResult();

        final boolean soap12 = Boolean.TRUE.equals(props.soap12());
        final String action = req.soapAction();

        WebServiceMessageCallback cb = (WebServiceMessage msg) -> {
            if (!soap12 && action != null && !action.isBlank()) {
                // Spring-WS SOAP 1.1: set SOAPAction (note: transport header quoting is not exposed here)
                ((SoapMessage) msg).setSoapAction(action);
            }
        };

        int attempt = 0;
        final int max = Math.max(1, props.retry().maxAttempts());
        final long backoffMs = Math.max(0, props.retry().backoffMs());
        Exception last = null;

        while (attempt++ < max) {
            long t0 = System.nanoTime();
            try {
                wst.sendSourceAndReceiveToResult(url, src, cb, res);
                final long tookMs = Duration.ofNanos(System.nanoTime() - t0).toMillis();
                log.info("soap.call transport=ws op={} action={} status={} tookMs={} url={}",
                        req.operationName(), action, 200, tookMs, url);
                return new SoapGateway.SoapResponse(req.operationName(), action, res.toString());
            } catch (Exception ex) {
                last = ex;
                if (attempt < max) {
                    log.warn("soap.call retry op={} attempt={}/{} backoffMs={} cause={}",
                            req.operationName(), attempt, max, backoffMs, ex.getMessage());
                    try { Thread.sleep(backoffMs); } catch (InterruptedException ie) { Thread.currentThread().interrupt(); }
                    continue;
                }
                break;
            }
        }
        throw new IllegalStateException("SOAP call failed op=" + req.operationName() + " url=" + url, last);
    }
}
