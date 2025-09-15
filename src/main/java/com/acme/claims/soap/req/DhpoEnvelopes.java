// src/main/java/com/acme/claims/soap/DhpoEnvelopes.java
package com.acme.claims.soap.req;

public final class DhpoEnvelopes {
    private DhpoEnvelopes() {}

    // Minimal SOAP 1.1 envelope for SearchTransactions (matches your working client)
    public static String searchTransactions(String login, String password, String facilityCode) {
        return """
            <?xml version="1.0" encoding="utf-8"?>
            <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                           xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                           xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
              <soap:Body>
                <SearchTransactions xmlns="http://www.eClaimLink.ae/">
                  <login>%s</login>
                  <pwd>%s</pwd>
                  <FacilityID>%s</FacilityID>
                </SearchTransactions>
              </soap:Body>
            </soap:Envelope>
            """.formatted(escape(login), escape(password), escape(facilityCode));
    }

    // Very basic XML text escaper for credentials/ids
    private static String escape(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"","&quot;")
                .replace("'","&apos;");
    }
}
