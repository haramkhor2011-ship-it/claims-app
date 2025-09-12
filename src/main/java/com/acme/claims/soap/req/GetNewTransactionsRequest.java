// src/main/java/com/acme/claims/soap/req/GetNewTransactionsRequest.java
package com.acme.claims.soap.req;

import com.acme.claims.soap.SoapGateway.SoapRequest;
import static com.acme.claims.soap.util.Xmls.xe;

public final class GetNewTransactionsRequest {
    private GetNewTransactionsRequest(){}

    private static final String ACTION = "http://www.eClaimLink.ae/GetNewTransactions";

    public static SoapRequest build(String login, String pwd, boolean soap12) {
        String pfx="soap", ns="http://schemas.xmlsoap.org/soap/envelope/";
        if (soap12) { pfx="soap12"; ns="http://www.w3.org/2003/05/soap-envelope"; }
        String body = """
      <%s:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                   xmlns:%s="%s">
        <%s:Body>
          <GetNewTransactions xmlns="http://www.eClaimLink.ae/">
            <login>%s</login><pwd>%s</pwd>
          </GetNewTransactions>
        </%s:Body>
      </%s:Envelope>
    """.formatted(pfx,pfx,ns,pfx,xe(login),xe(pwd),pfx,pfx);
        return new SoapRequest("GetNewTransactions", soap12 ? null : ACTION, body);
    }
}
