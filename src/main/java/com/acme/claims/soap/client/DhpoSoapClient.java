// src/main/java/com/acme/claims/soap/DhpoSoapClient.java
package com.acme.claims.soap.client;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.hc.client5.http.classic.methods.HttpPost;
import org.apache.hc.client5.http.impl.classic.CloseableHttpClient;
import org.apache.hc.core5.http.ClassicHttpResponse;
import org.apache.hc.core5.http.io.entity.StringEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.context.annotation.Profile;

import java.nio.charset.StandardCharsets;

@Slf4j
@Component
@RequiredArgsConstructor
@Profile("soap")
public class DhpoSoapClient {

    private final CloseableHttpClient http;

    public String callSoap11(String endpoint, String soapAction, String envelopeXml) {
        var req = new HttpPost(endpoint);
        req.setHeader(HttpHeaders.CONTENT_TYPE, "text/xml; charset=utf-8"); // SOAP 1.1
        req.setHeader(HttpHeaders.ACCEPT, "text/xml");
        if (soapAction != null && !soapAction.isBlank()) {
            // .asmx requires SOAPAction **quoted**
            req.setHeader("SOAPAction", "\"" + soapAction + "\"");
        }
        req.setEntity(new StringEntity(envelopeXml, StandardCharsets.UTF_8));

        try {
            return http.execute(req, (ClassicHttpResponse resp) -> {
                var sc = resp.getCode();
                var body = resp.getEntity() == null ? "" :
                        new String(resp.getEntity().getContent().readAllBytes(), StandardCharsets.UTF_8);
                log.info("soap.call status={} action={} endpoint={}", sc, soapAction, endpoint);
                if (sc >= 200 && sc < 300) return body;
                throw new IllegalStateException("SOAP HTTP " + sc + " body=" + body);
            });
        } catch (Exception e) {
            throw new IllegalStateException("SOAP call failed action=" + soapAction + " endpoint=" + endpoint, e);
        }
    }
}
