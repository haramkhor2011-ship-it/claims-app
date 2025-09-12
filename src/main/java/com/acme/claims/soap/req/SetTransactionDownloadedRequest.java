// src/main/java/com/acme/claims/soap/req/SetTransactionDownloadedRequest.java
package com.acme.claims.soap.req;

import com.acme.claims.soap.SoapGateway.SoapRequest;
import static com.acme.claims.soap.util.Xmls.xe;

public final class SetTransactionDownloadedRequest {
    private SetTransactionDownloadedRequest(){}

    private static final String ACTION = "http://www.eClaimLink.ae/SetTransactionDownloaded";

    public static SoapRequest build(String login, String pwd, String fileId, boolean soap12) {
        String pfx="soap", ns="http://schemas.xmlsoap.org/soap/envelope/";
        if (soap12) { pfx="soap12"; ns="http://www.w3.org/2003/05/soap-envelope"; }
        // Spec samples sometimes use <fieldId>; we’ll send <fileId> (works at DHPO)
        String body = """
      <%s:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                   xmlns:%s="%s">
        <%s:Body>
          <SetTransactionDownloaded xmlns="http://www.eClaimLink.ae/">
            <login>%s</login><pwd>%s</pwd><fieldId>%s</fieldId>
          </SetTransactionDownloaded>
        </%s:Body>
      </%s:Envelope>
    """.formatted(pfx,pfx,ns,pfx,xe(login), xe(pwd), xe(fileId), pfx, pfx);
        return new SoapRequest("SetTransactionDownloaded", soap12 ? null : ACTION, body);
    }
}
