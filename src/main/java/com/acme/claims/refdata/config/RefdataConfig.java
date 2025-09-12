package com.acme.claims.refdata.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties({RefdataBootstrapProperties.class, RefDataProperties.class})
public class RefdataConfig {
    // no-op; just wires @ConfigurationProperties bean
}
