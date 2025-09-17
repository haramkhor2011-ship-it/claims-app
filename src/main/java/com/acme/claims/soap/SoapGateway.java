// src/main/java/com/acme/claims/soap/SoapGateway.java
package com.acme.claims.soap;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import org.springframework.ws.client.core.WebServiceMessageCallback;
import org.springframework.ws.client.core.WebServiceTemplate;
import org.springframework.ws.soap.SoapMessage;
import org.springframework.xml.transform.StringSource;

import javax.xml.transform.stream.StreamResult;
import java.io.StringWriter;
import java.nio.charset.StandardCharsets;

@Slf4j
@Component
@Profile("soap")
@RequiredArgsConstructor
public class SoapGateway {
    private final WebServiceTemplate wst;
    private final SoapProperties props;

    public SoapResponse call(SoapRequest req) {
        int max = props.retry().maxAttempts() == null ? 1 : props.retry().maxAttempts();
        long backoff = props.retry().backoffMs() == null ? 0 : props.retry().backoffMs();

        int attempt = 0;
        RuntimeException last = null;
        while (attempt++ < max) {
            long t0 = System.nanoTime();
            try {
                StringWriter out = new StringWriter();
                WebServiceMessageCallback cb = (WebServiceMessageCallback) msg -> {
                    if (!Boolean.TRUE.equals(props.soap12()) && req.soapAction() != null && !req.soapAction().isBlank()) {
                        ((SoapMessage) msg).setSoapAction(req.soapAction()); // SOAP 1.1 only
                    }
                };
                wst.sendSourceAndReceiveToResult(new StringSource(req.envelopeXml()), cb, new StreamResult(out));
                long ms = (System.nanoTime() - t0) / 1_000_000;
                log.debug("SOAP {} ok in {}ms action={}", req.operationName(), ms, req.soapAction());
                return new SoapResponse(req.operationName(), req.soapAction(), out.toString());
            } catch (RuntimeException ex) {
                last = ex;
                log.warn("SOAP transport failure op={} attempt={}/{} : {}", req.operationName(), attempt, max, ex.toString());
                if (attempt < max && backoff > 0) sleep(backoff * attempt);
            }
        }
        throw last != null ? last : new IllegalStateException("SOAP call failed");
    }

    private static void sleep(long ms) { try { Thread.sleep(ms); } catch (InterruptedException ie) { Thread.currentThread().interrupt(); } }

    public record SoapRequest(String operationName, String soapAction, String envelopeXml) {}
    public record SoapResponse(String operationName, String soapAction, String envelopeXml) {
        public byte[] bytes() { return envelopeXml.getBytes(StandardCharsets.UTF_8); }
    }
}
