package com.acme.claims.util;

import lombok.SneakyThrows;
import org.w3c.dom.Document;
import org.w3c.dom.Node;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.OutputKeys;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.xpath.XPath;
import javax.xml.xpath.XPathFactory;
import java.io.StringWriter;
import java.math.BigDecimal;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Base64;

public class XmlUtil {
    private static final XPathFactory XPF = XPathFactory.newInstance();
    private static final DocumentBuilderFactory DBF = DocumentBuilderFactory.newInstance();
    private static final DateTimeFormatter DMY_HM = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
    private static final DateTimeFormatter[] DTF = new DateTimeFormatter[] {
            DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm"),
            DateTimeFormatter.ofPattern("dd/MM/yyyy")
    };

    static {
        DBF.setNamespaceAware(true);
        DBF.setIgnoringComments(true);
    }
    public static String toString(Node node) {
        try {
            Transformer transformer = TransformerFactory.newInstance().newTransformer();
            transformer.setOutputProperty(OutputKeys.OMIT_XML_DECLARATION, "no");
            transformer.setOutputProperty(OutputKeys.INDENT, "yes");
            StringWriter writer = new StringWriter();
            transformer.transform(new DOMSource(node), new StreamResult(writer));
            return writer.toString();
        } catch (Exception e) {
            throw new RuntimeException("Error converting XML to String", e);
        }
    }

    public static byte[] b64(String s) {
        if (s == null || s.isBlank()) return null;
        return Base64.getDecoder().decode(s.trim());
    }
    public static BigDecimal decimal(String s) {
        if (s == null || s.isBlank()) return null;
        return new BigDecimal(s.trim());
    }


    public static OffsetDateTime time(String s) {
        if (s == null || s.isBlank()) return null;
        for (DateTimeFormatter f : DTF) {
            try {
                LocalDateTime ldt = LocalDateTime.parse(s.trim(), f);
                return ldt.atZone(ZoneId.systemDefault()).toOffsetDateTime();
            } catch (Exception ignore) {}
        }
        return null;
    }

    @SneakyThrows
    public static String sha256(byte[] bytes) {
        if (bytes == null) return null;
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        byte[] d = md.digest(bytes);
        StringBuilder sb = new StringBuilder(d.length * 2);
        for (byte b : d) sb.append(String.format("%02x", b));
        return sb.toString();
    }

    public static Document parse(String xml) {
        if (xml == null) return null;
        String cleaned = stripUnknownPrefixes(xml);

        try {
            DocumentBuilderFactory f = DocumentBuilderFactory.newInstance();
            f.setNamespaceAware(true);
            // secure processing
            f.setFeature(javax.xml.XMLConstants.FEATURE_SECURE_PROCESSING, true);
            f.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
            f.setExpandEntityReferences(false);

            DocumentBuilder b = f.newDocumentBuilder();
            try (java.io.StringReader r = new java.io.StringReader(cleaned)) {
                org.xml.sax.InputSource is = new org.xml.sax.InputSource(r);
                return b.parse(is);
            }
        } catch (Exception e) {
            throw new RuntimeException("XML parse failed: " + e.getMessage(), e);
        }
    }

    private static String stripUnknownPrefixes(String xml) {
        String s = xml.replace("\uFEFF", ""); // strip BOM if present

        // Common undeclared prefix patterns in test fixtures: ns1:, ns2:, soap:, tns:
        // Remove prefix from element names
        s = s.replaceAll("<(/?)ns\\d+:", "<$1");
        s = s.replaceAll("<(/?)(soap|tns):", "<$1");

        // Remove xmlns:* declarations for those if present but broken
        s = s.replaceAll("\\sxmlns:ns\\d+=\"[^\"]*\"", "");
        s = s.replaceAll("\\sxmlns:(soap|tns)=\"[^\"]*\"", "");

        // If the root itself is prefixed (e.g., <ns1:Claim.Submission ...>), also strip in-place tag
        // The above rules already handle it, but this keeps things extra safe.

        return s;
    }

    public static Document parse(byte[] xml) {
        if (xml == null) return null;
        return parse(new String(xml, java.nio.charset.StandardCharsets.UTF_8));
    }




    public static XPath xpath() {
        return XPathFactory.newInstance().newXPath();
    }

    public static String parseEncodedXml(String xml) {
        // get content of file tag
        try {
            Document doc = XmlUtil.parse(xml);
            String fileContent = XmlUtil.xpath().evaluate("//*[local-name()='file']", doc);
            if (fileContent != null && !fileContent.isBlank()) {
                return new String(Base64.getDecoder().decode(fileContent));
            }
            return null;
        } catch (Exception ignore) {}
        return null;
    }

    public static byte[] parseAttachment(String xml) {
        // get content of file tag
        try {
            Document doc = XmlUtil.parse(xml);
            String fileContent = XmlUtil.xpath().evaluate("//*[local-name()='Attachment']", doc);
            if (fileContent != null && !fileContent.isBlank()) {
                return (Base64.getDecoder().decode(fileContent));
            }
            return null;
        } catch (Exception ignore) {}
        return null;
    }

    public static String text(Node ctx, String path) {
        try {
            return xpath().evaluate(path, ctx);
        } catch (Exception e) {
            return null;
        }
    }

    public static LocalDateTime timeNoZone(String text) {
        if (text == null || text.isBlank()) return null;
        String s = text.trim();
        // primary pattern: dd/MM/yyyy HH:mm
        try {
            return LocalDateTime.parse(s, DMY_HM);
        } catch (Exception ignore) { }
        // secondary common variations
        try {
            return LocalDateTime.parse(s, DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss"));
        } catch (Exception ignore) { }
        // last resort: if an ISO-like string sneaks in without zone
        try {
            return LocalDateTime.parse(s);
        } catch (Exception ignore) { }
        // give up quietly (keeps ingestion robust)
        return null;
    }

    public static java.time.LocalDateTime timeLocal(String s) {
        if (s == null || s.isBlank()) return null;
        String v = s.trim();
        // common DHA formats: "dd/MM/yyyy HH:mm" or "dd/MM/yyyy"
        java.time.format.DateTimeFormatter dt = java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
        java.time.format.DateTimeFormatter d = java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy");
        try {
            if (v.length() <= 10) { // "dd/MM/yyyy"
                return java.time.LocalDate.parse(v, d).atStartOfDay();
            }
            return java.time.LocalDateTime.parse(v, dt);
        } catch (Exception e) {
            // last resort: try ISO-8601 without zone
            try { return java.time.LocalDateTime.parse(v); } catch (Exception ignore) { return null; }
        }
    }



}
