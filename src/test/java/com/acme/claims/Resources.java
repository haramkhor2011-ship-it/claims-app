// FILE: src/test/java/com/acme/claims/sim/Resources.java
package com.acme.claims;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

public final class Resources {
    private Resources() {}

    public static String propOrDefault(String key, String def) {
        return System.getProperty(key, def);
    }

    public static byte[] readBytes(String cpPath) {
        try (InputStream is = Resources.class.getClassLoader().getResourceAsStream(cpPath)) {
            if (is == null) throw new IllegalArgumentException("Classpath resource not found: " + cpPath);
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            byte[] buf = new byte[8192]; int r;
            while ((r = is.read(buf)) != -1) bos.write(buf, 0, r);
            return bos.toByteArray();
        } catch (Exception e) {
            throw new RuntimeException("Failed to read resource: " + cpPath, e);
        }
    }

    public static String readString(String cpPath) {
        return new String(readBytes(cpPath), StandardCharsets.UTF_8);
    }
}
