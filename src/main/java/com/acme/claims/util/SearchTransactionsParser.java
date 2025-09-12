package com.acme.claims.util;


import lombok.Getter;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

import javax.xml.parsers.DocumentBuilderFactory;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Parses the SOAP response from SearchTransactions.
 */
public class SearchTransactionsParser {

    private static final String NS_ECLAIM = "http://www.eClaimLink.ae/";

    @Getter
    public static class ParseResult {
        public final Map<String, String> fileIds;
        public final String rawFoundTransactionsXml; // the unescaped inner XML (optional, handy for logging)
        public ParseResult(Map<String, String> fileIds, String rawFoundTransactionsXml) {
            this.fileIds = fileIds;
            this.rawFoundTransactionsXml = rawFoundTransactionsXml;
        }

    }

    public static ParseResult parseFileIds(String soapXml) {
        try {
            // Parse SOAP envelope with namespaces
            DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
            dbf.setNamespaceAware(true);
            Document doc = dbf.newDocumentBuilder()
                    .parse(new java.io.ByteArrayInputStream(soapXml.getBytes(java.nio.charset.StandardCharsets.UTF_8)));

            // Find <SearchTransactionsResponse> by local-name (defensive to prefixes)
            Element responseEl = findFirstByLocalName(doc.getDocumentElement(), "SearchTransactionsResponse");
            if (responseEl == null) {
                throw new IllegalStateException("SearchTransactionsResponse not found in SOAP body.");
            }

            // Read <errorMessage> (if present and non-empty -> fail fast)
            String errorMessage = getChildTextContent(responseEl, "errorMessage");
            if (errorMessage != null && !errorMessage.isBlank()) {
                throw new IllegalStateException("eClaimLink error: " + errorMessage.trim());
            }

            // Read <SearchTransactionsResult> (expect "0" for success per your sample)
            String resultCode = getChildTextContent(responseEl, "SearchTransactionsResult");
            if (resultCode == null) {
                throw new IllegalStateException("SearchTransactionsResult missing.");
            }
            if (!"0".equals(resultCode.trim())) {
                throw new IllegalStateException("SearchTransactionsResult != 0 (got " + resultCode + ")");
            }

            // Read <foundTransactions> text (this is ESCAPED XML like &lt;Files&gt;...&lt;/Files&gt;)
            String foundTxEscaped = getChildTextContent(responseEl, "foundTransactions");
            if (foundTxEscaped == null || foundTxEscaped.isBlank()) {
                return new ParseResult(java.util.Collections.emptyMap(), "");
            }

            // Unescape XML entities (&lt;, &gt;, &amp;, &apos;, &quot;)
            String foundTxXml = xmlUnescape(foundTxEscaped.trim());

            // Parse the inner XML (<Files><File .../></Files>)
            Document inner = dbf.newDocumentBuilder()
                    .parse(new java.io.ByteArrayInputStream(foundTxXml.getBytes(java.nio.charset.StandardCharsets.UTF_8)));

            // Collect FileID from all <File ...> elements
            NodeList files = inner.getElementsByTagName("File");
            Map<String, String> filesWithIdName = new LinkedHashMap<>();
            for (int i = 0; i < files.getLength(); i++) {
                Element fileEl = (Element) files.item(i);
                String id = fileEl.getAttribute("FileID");
                String name = fileEl.getAttribute("FileName");
                if (!id.isBlank() && !name.isBlank()) {
                    filesWithIdName.put(id.trim().replace("'", ""), name.trim().replace("'", ""));
                }
            }

            return new ParseResult(filesWithIdName, foundTxXml);
        } catch (Exception ex) {
            throw new RuntimeException("Failed to parse SearchTransactions SOAP response: " + ex.getMessage(), ex);
        }
    }

    // ---------- helpers ----------

    private static Element findFirstByLocalName(Element root, String localName) {
        if (root == null) return null;
        if (localName.equals(root.getLocalName())) return root;

        NodeList children = root.getChildNodes();
        for (int i = 0; i < children.getLength(); i++) {
            Node n = children.item(i);
            if (n instanceof Element el) {
                Element hit = findFirstByLocalName(el, localName);
                if (hit != null) return hit;
            }
        }
        return null;
    }

    private static String getChildTextContent(Element parent, String childLocalName) {
        NodeList children = parent.getChildNodes();
        for (int i = 0; i < children.getLength(); i++) {
            Node n = children.item(i);
            if (n instanceof Element el) {
                // Match by local-name to be prefix-agnostic
                if (childLocalName.equals(el.getLocalName())) {
                    return el.getTextContent();
                }
            }
        }
        return null;
    }

    private static String xmlUnescape(String s) {
        // Minimal XML unescape (covers entities used in your payload)
        return s.replace("&lt;", "<")
                .replace("&gt;", ">")
                .replace("&amp;", "&")
                .replace("&apos;", "'")
                .replace("&quot;", "\"");
    }
}
