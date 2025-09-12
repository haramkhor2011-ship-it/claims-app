// src/main/java/com/acme/claims/soap/util/Xmls.java
package com.acme.claims.soap.util;

import org.w3c.dom.Document;
import org.w3c.dom.Node;
import javax.xml.parsers.DocumentBuilderFactory;
import java.nio.charset.StandardCharsets;

public final class Xmls {
    private Xmls(){}

    public static Document parse(String xml) throws Exception {
        var dbf = DocumentBuilderFactory.newInstance();
        dbf.setNamespaceAware(true);
        return dbf.newDocumentBuilder().parse(new java.io.ByteArrayInputStream(xml.getBytes(StandardCharsets.UTF_8)));
    }

    public static String gl(Document d, String localName) {
        var nl = d.getElementsByTagNameNS("*", localName);
        Node n = nl.getLength() > 0 ? nl.item(0) : null;
        return n == null ? null : n.getTextContent();
    }

    public static String xe(String s){
        return s == null ? "" : s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;");
    }
}
