// src/main/java/com/acme/claims/soap/transport/HttpSoapCaller.java
package com.acme.claims.soap.transport;


import com.acme.claims.soap.SoapGateway;
import com.acme.claims.soap.SoapProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.hc.client5.http.classic.methods.HttpPost;
import org.apache.hc.client5.http.impl.classic.CloseableHttpClient;
import org.apache.hc.core5.http.ClassicHttpResponse;
import org.apache.hc.core5.http.ContentType;
import org.apache.hc.core5.http.HttpHeaders;
import org.apache.hc.core5.http.io.entity.StringEntity;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.time.Duration;

@Slf4j
@Component
@RequiredArgsConstructor
@Profile("soap")
@ConditionalOnProperty(name = "claims.soap.transport", havingValue = "http")
public class HttpSoapCaller implements SoapCaller {

    private final CloseableHttpClient httpClient;      // define a @Bean elsewhere
    private final SoapProperties props;                // your existing properties holder

    @Override
    public SoapGateway.SoapResponse call(SoapGateway.SoapRequest req) {
        final String url = props.endpoint();

        final boolean soap12 = Boolean.TRUE.equals(props.soap12());
        final String action = req.soapAction(); // may be null for SOAP 1.2

        int attempt = 0;
        final int max = Math.max(1, props.retry().maxAttempts());
        final long backoffMs = Math.max(0, props.retry().backoffMs());

        Exception last = null;
        while (attempt++ < max) {
            long t0 = System.nanoTime();
            try {
                HttpPost post = new HttpPost(url);

                if (soap12) {
                    // SOAP 1.2 → action lives in Content-Type param; SOAPAction header MUST NOT be sent
                    String ct = ContentType.create("application/soap+xml", StandardCharsets.UTF_8).toString();
                    if (action != null && !action.isBlank()) {
                        ct = ct + "; action=\"" + action + "\"";
                    }
                    post.setHeader(HttpHeaders.CONTENT_TYPE, ct);
                    post.setHeader(HttpHeaders.ACCEPT, "application/soap+xml, text/xml");
                } else {
                    // SOAP 1.1 → must send quoted SOAPAction header + text/xml content-type
                    post.setHeader(HttpHeaders.CONTENT_TYPE, "text/xml; charset=utf-8");
                    post.setHeader(HttpHeaders.ACCEPT, "text/xml");
                    if (action != null && !action.isBlank()) {
                        post.setHeader("SOAPAction", "\"" + action + "\"");
                    }
                }

                post.setEntity(new StringEntity(req.envelopeXml(), StandardCharsets.UTF_8));

                String body = httpClient.execute(post, (ClassicHttpResponse resp) -> {
                    final int sc = resp.getCode();
                    final String respXml = (resp.getEntity() == null)
                            ? ""
                            : new String(resp.getEntity().getContent().readAllBytes(), StandardCharsets.UTF_8);
                    final long tookMs = Duration.ofNanos(System.nanoTime() - t0).toMillis();
                    log.info("soap.call transport=http op={} action={} status={} tookMs={} url={}",
                            req.operationName(), action, sc, tookMs, url);

                    if (sc >= 200 && sc < 300) return respXml;

                    // Retry on transient statuses
                    if (sc == 408 || sc == 429 || sc == 500 || sc == 502 || sc == 503 || sc == 504) {
                        throw new TransientStatusException("HTTP " + sc);
                    }
                    // Non-retryable: surface as-is
                    throw new NonRetryableStatusException("HTTP " + sc + " body=" + excerpt(respXml));
                });

                return new SoapGateway.SoapResponse(req.operationName(), action, body);

            } catch (TransientStatusException | java.io.IOException e) {
                last = e;
                if (attempt < max) {
                    log.warn("soap.call retryable op={} attempt={}/{} backoffMs={} cause={}",
                            req.operationName(), attempt, max, backoffMs, e.getMessage());
                    sleep(backoffMs);
                    continue;
                }
            } catch (NonRetryableStatusException e) {
                throw new IllegalStateException("SOAP non-retryable op=" + req.operationName() + " url=" + url + " : " + e.getMessage(), e);
            } catch (Exception e) {
                last = e;
                if (attempt < max) {
                    log.warn("soap.call retry op={} attempt={}/{} backoffMs={} cause={}",
                            req.operationName(), attempt, max, backoffMs, e.getMessage());
                    sleep(backoffMs);
                    continue;
                }
            }
            break;
        }
        throw new IllegalStateException("SOAP call failed op=" + req.operationName() + " url=" + url, last);
    }

    private static void sleep(long ms) {
        try { Thread.sleep(ms); } catch (InterruptedException ie) { Thread.currentThread().interrupt(); }
    }

    private static String excerpt(String s) {
        if (s == null) return "";
        return s.length() <= 512 ? s : s.substring(0, 512) + "...";
    }

    private static final class TransientStatusException extends RuntimeException {
        TransientStatusException(String m){ super(m); }
    }
    private static final class NonRetryableStatusException extends RuntimeException {
        NonRetryableStatusException(String m){ super(m); }
    }
}
