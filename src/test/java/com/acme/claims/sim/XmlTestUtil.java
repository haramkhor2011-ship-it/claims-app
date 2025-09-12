package com.acme.claims.sim;

import com.acme.claims.util.XmlUtil;
import org.w3c.dom.Document;

import java.nio.charset.StandardCharsets;

public final class XmlTestUtil {
    private XmlTestUtil() {}

    public static Document load(String cpResource) throws Exception {
        try (var in = XmlTestUtil.class.getResourceAsStream(cpResource)) {
            if (in == null) throw new IllegalArgumentException("Missing resource: " + cpResource);
            var xml = new String(in.readAllBytes(), StandardCharsets.UTF_8);
            return XmlUtil.parse(xml);
        }
    }

    public static byte[] loadBytes(String cpResource) throws Exception {
        try (var in = XmlTestUtil.class.getResourceAsStream(cpResource)) {
            if (in == null) throw new IllegalArgumentException("Missing resource: " + cpResource);
            return in.readAllBytes();
        }
    }
}
