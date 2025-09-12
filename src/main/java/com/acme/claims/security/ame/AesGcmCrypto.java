package com.acme.claims.security.ame;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import java.security.SecureRandom;
import java.util.HexFormat;

public final class AesGcmCrypto {
    private static final SecureRandom RNG = new SecureRandom();
    private AesGcmCrypto(){}

    public record Blob(byte[] iv, byte[] ct, int tagBits, String keyId){}

    public static Blob encrypt(SecretKey key, byte[] plain, byte[] aad, int tagBits, String keyId) {
        try {
            byte[] iv = new byte[12]; RNG.nextBytes(iv);
            Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
            c.init(Cipher.ENCRYPT_MODE, key, new GCMParameterSpec(tagBits, iv));
            if (aad != null) c.updateAAD(aad);
            byte[] out = c.doFinal(plain);
            return new Blob(iv, out, tagBits, keyId);
        } catch (Exception e) {
            throw new IllegalStateException("GCM encrypt failed", e);
        }
    }

    public static byte[] decrypt(SecretKey key, Blob blob, byte[] aad) {
        try {
            Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
            c.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(blob.tagBits(), blob.iv()));
            if (aad != null) c.updateAAD(aad);
            return c.doFinal(blob.ct());
        } catch (Exception e) {
            throw new IllegalStateException("GCM decrypt failed (keyId="+blob.keyId()+")", e);
        }
    }

    public static String ivHex(byte[] iv){ return HexFormat.of().formatHex(iv); }
}
