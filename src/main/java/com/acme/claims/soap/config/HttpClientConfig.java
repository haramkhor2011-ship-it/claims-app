// src/main/java/com/acme/claims/soap/transport/HttpClientConfig.java
package com.acme.claims.soap.config;


import com.acme.claims.soap.SoapProperties;
import org.apache.hc.client5.http.config.RequestConfig;
import org.apache.hc.client5.http.impl.classic.CloseableHttpClient;
import org.apache.hc.client5.http.impl.classic.HttpClients;
import org.apache.hc.core5.util.Timeout;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.context.annotation.Profile;

@Configuration
@Profile("soap")
public class HttpClientConfig {

    @Bean
    @Primary
    public CloseableHttpClient dhpoHttpClient(SoapProperties props) {
        var rc = RequestConfig.custom()
                .setConnectTimeout(Timeout.ofMilliseconds(props.connectTimeoutMs()))
                .setResponseTimeout(Timeout.ofMilliseconds(props.readTimeoutMs()))
                .build();

        return HttpClients.custom()
                .setDefaultRequestConfig(rc)
                .evictExpiredConnections()
                .evictIdleConnections(Timeout.ofSeconds(30))
                .build();
    }
}
