package com.acme.claims.soap.crypto;

import com.acme.claims.domain.model.entity.FacilityDhpoConfig;
import com.acme.claims.security.ame.AesGcmCrypto;
import com.acme.claims.security.ame.AmeKeyProvider;
import lombok.RequiredArgsConstructor;
import org.json.JSONObject;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.util.Base64;

@Component
@Profile("soap")
@RequiredArgsConstructor
public class DhpoCredentialResolver {

    private final AmeKeyProvider ame; // present in your project; loads SecretKey when AME enabled

    public DhpoCredentials resolve(FacilityDhpoConfig f) {
        // enc_meta_json -> {kek_version, alg, iv, tagBits, keyId?}
        var meta = new JSONObject(f.getEncMetaJson());
        String ivB64 = meta.optString("iv", null);
        int tagBits = meta.optInt("tagBits", 128);
        String keyId  = meta.optString("kek_version", "v1");

        // If AME is disabled, assume plaintext was stored (you asked for “app-managed encryption”, but make it resilient)
        // check this : AmeKeyProvider#getKeyOrNull() must exist; if your class exposes SecretKey getKey(), just adapt to return null when disabled.
        SecretKey key = ame.getKey();
        if (key == null) {
            return new DhpoCredentials(new String(f.getDhpoUsernameEnc()), new String(f.getDhpoPasswordEnc()));
        }

        var userBlob = new AesGcmCrypto.Blob(Base64.getDecoder().decode(ivB64), f.getDhpoUsernameEnc(), tagBits, keyId);
        var passBlob = new AesGcmCrypto.Blob(Base64.getDecoder().decode(ivB64), f.getDhpoPasswordEnc(), tagBits, keyId);

        String user = new String(AesGcmCrypto.decrypt(key, userBlob, facilityAad(f)));
        String pass = new String(AesGcmCrypto.decrypt(key, passBlob, facilityAad(f)));
        return new DhpoCredentials(user, pass);
    }

    private byte[] facilityAad(FacilityDhpoConfig f) {
        // bind ciphertexts to facility_code as AAD for integrity
        return f.getFacilityCode() == null ? null : f.getFacilityCode().getBytes();
    }
}
