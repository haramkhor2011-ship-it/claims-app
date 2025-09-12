package com.acme.claims.security.ame;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "claims.security.ame")
public record AmeProperties(
        boolean enabled,
        Keystore keystore,
        Crypto crypto
) {
    public record Keystore(String type, String path, String alias, String passwordEnv) {}
    public record Crypto(Integer gcmTagBits, String keyId) {}
}
