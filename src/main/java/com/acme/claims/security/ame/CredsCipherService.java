// src/main/java/com/acme/claims/security/ame/CredsCipherService.java
package com.acme.claims.security.ame;

import com.acme.claims.domain.model.entity.FacilityDhpoConfig;
import com.acme.claims.domain.repo.FacilityDhpoConfigRepo;
import lombok.RequiredArgsConstructor;
import org.json.JSONObject;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

@Service
@Profile("soap")
@RequiredArgsConstructor
public class CredsCipherService {

    private final AmeProperties props;               // crypto defaults (keyId, tag bits)
    private final AmeKeyProvider keyProvider;        // active SecretKey provider
    private final FacilityDhpoConfigRepo facilityRepo;

    public record PlainCreds(String login, String pwd) {}
    public record CipherCreds(byte[] loginCt, byte[] pwdCt, String encMetaJson) {}

    /** Primary entry: resolve plaintext creds for a facility row (used by DHPO coordinator). */
    public PlainCreds decryptFor(FacilityDhpoConfig f) {
        if (!props.enabled())
            throw new IllegalStateException("App-managed encryption is disabled; encrypted creds required.");

        byte[] userCt = f.getDhpoUsernameEnc();
        byte[] pwdCt  = f.getDhpoPasswordEnc();
        String meta   = f.getEncMetaJson();
        String facilityCode = f.getFacilityCode();

        if (userCt == null || pwdCt == null || isBlank(meta))
            throw new IllegalStateException("Facility " + facilityCode + " has missing ciphertext or enc_meta_json.");

        String login = decryptUsername(userCt, meta, facilityCode);
        String pwd   = decryptPassword(pwdCt,  meta, facilityCode);
        return new PlainCreds(login, pwd);
    }

    /** Decrypt a username blob using ivLogin (or fallback to iv). */
    public String decryptUsername(byte[] ct, String encMetaJson, String facilityCode) {
        return decryptWithIvKey(ct, encMetaJson, facilityCode, "ivLogin");
    }

    /** Decrypt a password blob using ivPwd (or fallback to iv). */
    public String decryptPassword(byte[] ct, String encMetaJson, String facilityCode) {
        return decryptWithIvKey(ct, encMetaJson, facilityCode, "ivPwd");
    }

    /** Generic helper; prefers specific iv keyName, falls back to 'iv'. */
    private String decryptWithIvKey(byte[] ct, String encMetaJson, String facilityCode, String ivKeyName) {
        var meta = parseMeta(encMetaJson);
        int tagBits = meta.optInt("gcmTagBits", props.crypto().gcmTagBits());
        String keyId = meta.optString("keyId", props.crypto().keyId());

        String ivB64 = meta.optString(ivKeyName);
        if (isBlank(ivB64)) ivB64 = meta.optString("iv"); // future single-IV variant
        if (isBlank(ivB64)) throw new IllegalStateException("Missing IV in enc_meta_json (" + ivKeyName + "/iv)");

        SecretKey key = keyProvider.getKey();
        var blob = new AesGcmCrypto.Blob(Base64.getDecoder().decode(ivB64), ct, tagBits, keyId);
        byte[] pt = AesGcmCrypto.decrypt(key, blob, aad(facilityCode));
        return new String(pt, StandardCharsets.UTF_8);
    }

    /** Encrypt and produce enc_meta_json with split IVs (ivLogin/ivPwd). */
    public CipherCreds encrypt(String facilityCode, String login, String pwd) {
        if (!props.enabled())
            throw new IllegalStateException("App-managed encryption is disabled; encrypt requested.");

        SecretKey key = keyProvider.getKey();
        int tagBits = props.crypto().gcmTagBits();
        String keyId = props.crypto().keyId();

        var ebLogin = AesGcmCrypto.encrypt(key, bytes(login), aad(facilityCode), tagBits, keyId);
        var ebPwd   = AesGcmCrypto.encrypt(key, bytes(pwd),   aad(facilityCode), tagBits, keyId);

        var meta = new JSONObject();
        meta.put("v", 1);
        meta.put("alg", "AES-256-GCM");
        meta.put("gcmTagBits", tagBits);
        meta.put("keyId", keyId);
        meta.put("ivLogin", Base64.getEncoder().encodeToString(ebLogin.iv()));
        meta.put("ivPwd",   Base64.getEncoder().encodeToString(ebPwd.iv()));
        meta.put("aad", "facility_code");

        return new CipherCreds(ebLogin.ct(), ebPwd.ct(), meta.toString());
    }

    // ---------- helpers

    private static JSONObject parseMeta(String json) {
        if (isBlank(json)) throw new IllegalStateException("enc_meta_json is empty");
        try { return new JSONObject(json); }
        catch (Exception e) { throw new IllegalStateException("Invalid enc_meta_json: " + e.getMessage(), e); }
    }

    private static byte[] aad(String facilityCode) {
        return (facilityCode == null ? "" : facilityCode).getBytes(StandardCharsets.UTF_8);
    }

    private static byte[] bytes(String s) { return (s == null ? "" : s).getBytes(StandardCharsets.UTF_8); }

    private static boolean isBlank(String s){ return s == null || s.isBlank(); }
}
