// src/main/java/com/acme/claims/soap/SoapConfig.java
package com.acme.claims.soap;

import lombok.RequiredArgsConstructor;
import org.apache.hc.client5.http.config.RequestConfig;
import org.apache.hc.client5.http.impl.classic.CloseableHttpClient;
import org.apache.hc.client5.http.impl.classic.HttpClients;
import org.apache.hc.core5.util.Timeout;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.ws.client.core.WebServiceTemplate;
import org.springframework.ws.soap.SoapVersion;
import org.springframework.ws.soap.saaj.SaajSoapMessageFactory;
import org.springframework.ws.transport.http.HttpComponents5MessageSender;

@Profile("soap")
@Configuration
@RequiredArgsConstructor
@EnableConfigurationProperties(SoapProperties.class)
public class SoapConfig {

    private final SoapProperties props; // @ConfigurationProperties(prefix="claims.soap")

    @Bean
    public SaajSoapMessageFactory messageFactory() {
        // Choose SOAP version via config; default to 1.1 if null/false
        SaajSoapMessageFactory mf = new SaajSoapMessageFactory();
        mf.setSoapVersion(Boolean.TRUE.equals(props.soap12())
                ? SoapVersion.SOAP_12
                : SoapVersion.SOAP_11);
        mf.afterPropertiesSet(); // initialize internal SAAJ MessageFactory
        return mf;
    }

    @Bean
    public CloseableHttpClient httpClient() {
        // HttpClient 5 requires Timeout objects (not int milliseconds)
        RequestConfig rc = RequestConfig.custom()
                .setConnectTimeout(Timeout.ofMilliseconds(props.connectTimeoutMs()))
                .setResponseTimeout(Timeout.ofMilliseconds(props.readTimeoutMs()))
                .build();

        return HttpClients.custom()
                .setDefaultRequestConfig(rc)
                .evictExpiredConnections()
                .build();
    }

    @Bean
    public HttpComponents5MessageSender httpSender(CloseableHttpClient httpClient) {
        HttpComponents5MessageSender sender = new HttpComponents5MessageSender();
        sender.setHttpClient(httpClient); // matches 5.x CloseableHttpClient
        return sender;
    }

    @Bean
    public WebServiceTemplate webServiceTemplate(
            SaajSoapMessageFactory messageFactory,
            HttpComponents5MessageSender httpSender
    ) {
        WebServiceTemplate tpl = new WebServiceTemplate();
        tpl.setMessageFactory(messageFactory);
        tpl.setMessageSender(httpSender);
        tpl.setDefaultUri(props.endpoint()); // base endpoint; per-call override allowed
        return tpl;
    }
}
