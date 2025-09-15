// src/main/java/com/acme/claims/soap/util/XmlPayloads.java
package com.acme.claims.soap.util;

import javax.xml.stream.XMLInputFactory;
import javax.xml.stream.XMLStreamConstants;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.HexFormat;
import java.util.zip.GZIPInputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

public final class XmlPayloads {
    private XmlPayloads() {}

    /** Normalize arbitrary DHPO payload bytes into BOM-less UTF-8 XML bytes, or throw with a helpful message. */
    public static byte[] normalizeToUtf8OrThrow(byte[] in) {
        if (in == null || in.length == 0) throw new IllegalArgumentException("empty payload");

        byte[] b = in;

        // 1) decompress if needed
        if (looksLikeGzip(b)) b = gunzip(b);
        else if (looksLikeZip(b)) b = unzipFirstEntry(b);

        // 2) re-encode if UTF-16
        if (looksLikeUtf16LE(b)) {
            b = new String(b, StandardCharsets.UTF_16LE).getBytes(StandardCharsets.UTF_8);
        } else if (looksLikeUtf16BE(b)) {
            b = new String(b, StandardCharsets.UTF_16BE).getBytes(StandardCharsets.UTF_8);
        }

        // 3) strip UTF-8 BOM and skip ASCII spaces before '<'
        b = stripUtf8Bom(b);
        int i = skipAsciiSpace(b);
        if (i >= b.length) throw bad("only whitespace");

        // 4) require an XML start; fallback to a quick StAX parse to be certain
        if (b[i] != '<') {
            tryQuickParseOrThrow(b);
        }
        return b;
    }

    public static String headHex(byte[] b, int n) {
        if (b == null) return "<null>";
        return HexFormat.of().formatHex(Arrays.copyOf(b, Math.min(n, b.length)));
    }
    public static String headUtf8(byte[] b, int n) {
        if (b == null) return "<null>";
        int k = Math.min(n, b.length);
        return new String(b, 0, k, StandardCharsets.UTF_8).replaceAll("\\p{C}"," ").trim();
    }

    private static void tryQuickParseOrThrow(byte[] b) {
        try {
            var xr = XMLInputFactory.newFactory().createXMLStreamReader(new ByteArrayInputStream(b));
            while (xr.hasNext()) {
                if (xr.next() == XMLStreamConstants.START_ELEMENT) return;
            }
            throw bad("no start element found");
        } catch (Exception ex) {
            throw bad("stax parse failed: " + ex.getMessage());
        }
    }

    private static boolean looksLikeGzip(byte[] b) {
        return b.length >= 2 && (b[0] & 0xFF) == 0x1F && (b[1] & 0xFF) == 0x8B;
    }
    private static boolean looksLikeZip(byte[] b) {
        return b.length >= 2 && b[0] == 'P' && b[1] == 'K';
    }
    private static boolean looksLikeUtf16LE(byte[] b) {
        return b.length >= 2 && b[0] == 0x3C && b[1] == 0x00; // "<" = 3C 00
    }
    private static boolean looksLikeUtf16BE(byte[] b) {
        return b.length >= 2 && b[0] == 0x00 && b[1] == 0x3C; // "<" = 00 3C
    }
    private static byte[] stripUtf8Bom(byte[] b) {
        if (b.length >= 3 && (b[0] & 0xFF) == 0xEF && (b[1] & 0xFF) == 0xBB && (b[2] & 0xFF) == 0xBF) {
            return Arrays.copyOfRange(b, 3, b.length);
        }
        return b;
    }
    private static int skipAsciiSpace(byte[] b) {
        int i = 0;
        while (i < b.length) {
            byte c = b[i];
            if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) i++; else break;
        }
        return i;
    }

    private static byte[] gunzip(byte[] b) {
        try (var in = new GZIPInputStream(new ByteArrayInputStream(b));
             var out = new ByteArrayOutputStream(Math.max(1024, b.length * 2))) {
            in.transferTo(out);
            return out.toByteArray();
        } catch (Exception e) {
            throw bad("gunzip failed: " + e.getMessage());
        }
    }
    private static byte[] unzipFirstEntry(byte[] b) {
        try (var in = new ZipInputStream(new ByteArrayInputStream(b));
             var out = new ByteArrayOutputStream(Math.max(1024, b.length * 2))) {
            ZipEntry e = in.getNextEntry();
            if (e == null) throw bad("zip has no entries");
            in.transferTo(out);
            return out.toByteArray();
        } catch (Exception e) {
            throw bad("unzip failed: " + e.getMessage());
        }
    }

    private static IllegalArgumentException bad(String why) { return new IllegalArgumentException("not-xml: " + why); }
}
