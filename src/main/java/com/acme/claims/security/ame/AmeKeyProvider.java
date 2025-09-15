package com.acme.claims.security.ame;

import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;
import java.util.Base64;

@Slf4j
@Component
@RequiredArgsConstructor
@Profile("soap")
public class AmeKeyProvider {

    private final com.acme.claims.security.ame.AmeProperties props;
    private SecretKey key;

    @PostConstruct
    void init() {
        if (!props.enabled()) {
            log.warn("AME disabled; falling back to plaintext creds (not recommended).");
            return;
        }
        String type = props.keystore().type();
        if ("FILE".equalsIgnoreCase(type)) {
            loadFromFile(props.keystore().path());
        } else {
            loadFromKeyStore(type, props.keystore().path(), props.keystore().alias(), props.keystore().passwordEnv());
        }
        if (key == null) throw new IllegalStateException("AME key load failed");
        log.info("AME key loaded: type={}, id={}", props.keystore().type(), props.crypto().keyId());
    }

    private void loadFromKeyStore(String ksType, String path, String alias, String passEnv) {
        try (InputStream in = resolve(path)) {
            var ks = KeyStore.getInstance(ksType == null ? "JKS" : ksType);
            log.debug("CLAIMS_AME_STORE_PASS present? {}", System.getenv(props.keystore().passwordEnv()) != null);
            char[] pass = System.getenv(passEnv) != null ? System.getenv(passEnv).toCharArray() : new char[0];
            ks.load(in, pass);
            var sk = (KeyStore.SecretKeyEntry) ks.getEntry(alias, new KeyStore.PasswordProtection(pass));
            this.key = sk.getSecretKey();
        } catch (Exception e) {
            throw new IllegalStateException("Load keystore failed: " + e.getMessage(), e);
        }
    }

    private void loadFromFile(String path) {
        try (InputStream in = resolve(path)) {
            byte[] raw = in.readAllBytes();
            // accept either base64 or raw 32 bytes
            byte[] material = raw.length == 32 ? raw : Base64.getDecoder().decode(raw);
            if (material.length != 32) throw new IllegalStateException("FILE key must be 32 bytes (AES-256)");
            this.key = new SecretKeySpec(material, "AES");
        } catch (Exception e) {
            throw new IllegalStateException("Load file key failed: " + e.getMessage(), e);
        }
    }

    private static InputStream resolve(String location) throws Exception {
        if (location.startsWith("file:")) {
            return Files.newInputStream(Path.of(location.substring("file:".length())));
        }
        // classpath:… support if you want
        return Files.newInputStream(Path.of(location));
    }

    public SecretKey getKey() {
        if (key == null) throw new IllegalStateException("AME key not initialized");
        return key;
    }
}
