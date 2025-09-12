package com.acme.claims.ingestion.parser;

import org.w3c.dom.ls.LSInput;
import org.w3c.dom.ls.LSResourceResolver;

import java.io.InputStream;

final class ClasspathResourceResolver implements LSResourceResolver {

    private final String base; // e.g. "/xsd/"

    ClasspathResourceResolver(String base) {
        this.base = base.endsWith("/") ? base : base + "/";
    }

    @Override
    public LSInput resolveResource(String type, String ns, String publicId, String systemId, String baseURI) {
        InputStream is = open(systemId);
        if (is == null && systemId != null) {
            int i = systemId.lastIndexOf('/');
            if (i >= 0 && i + 1 < systemId.length()) is = open(systemId.substring(i + 1));
        }
        return is == null ? null : new SimpleLSInput(publicId, systemId, is);
    }

    private InputStream open(String name) {
        if (name == null || name.isBlank()) return null;
        String path = name.startsWith("/") ? name : base + name;
        return getClass().getResourceAsStream(path);
    }

    private static final class SimpleLSInput implements LSInput {
        private final String publicId, systemId;
        private final InputStream in;
        SimpleLSInput(String publicId, String systemId, InputStream in) {
            this.publicId = publicId; this.systemId = systemId; this.in = in;
        }
        @Override public java.io.Reader getCharacterStream() { return null; }
        @Override public void setCharacterStream(java.io.Reader r) { }
        @Override public InputStream getByteStream() { return in; }
        @Override public void setByteStream(InputStream byteStream) { }
        @Override public String getStringData() { return null; }
        @Override public void setStringData(String stringData) { }
        @Override public String getSystemId() { return systemId; }
        @Override public void setSystemId(String systemId) { }
        @Override public String getPublicId() { return publicId; }
        @Override public void setPublicId(String publicId) { }
        @Override public String getBaseURI() { return null; }
        @Override public void setBaseURI(String baseURI) { }
        @Override public String getEncoding() { return null; }
        @Override public void setEncoding(String encoding) { }
        @Override public boolean getCertifiedText() { return false; }
        @Override public void setCertifiedText(boolean certifiedText) { }
    }
}
