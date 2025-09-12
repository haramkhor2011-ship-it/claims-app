// src/main/java/com/acme/claims/soap/req/SearchTransactionsRequest.java
package com.acme.claims.soap.req;

import com.acme.claims.soap.SoapGateway.SoapRequest;
import static com.acme.claims.soap.util.Xmls.xe;

public final class SearchTransactionsRequest {
    private SearchTransactionsRequest(){}

    private static final String ACTION = "http://www.eClaimLink.ae/SearchTransactions";

    public static SoapRequest build(
            String login, String pwd, int direction, String callerLicense, String ePartner,
            int transactionID, Integer transactionStatus, String from, String to,
            Integer minRecordCount, Integer maxRecordCount, boolean soap12
    ) {
        String pfx="soap", ns="http://schemas.xmlsoap.org/soap/envelope/";
        if (soap12) { pfx="soap12"; ns="http://www.w3.org/2003/05/soap-envelope"; }
        String body = """
      <%s:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                   xmlns:%s="%s">
        <%s:Body>
          <SearchTransactions xmlns="http://www.eClaimLink.ae/">
            <login>%s</login><pwd>%s</pwd>
            <direction>%d</direction>
            <callerLicense>%s</callerLicense>
            <ePartner>%s</ePartner>
            <transactionID>%d</transactionID>
            <TransactionStatus>%s</TransactionStatus>
            <transactionFileName></transactionFileName>
            <transactionFromDate>%s</transactionFromDate>
            <transactionToDate>%s</transactionToDate>
            <minRecordCount>%s</minRecordCount>
            <maxRecordCount>%s</maxRecordCount>
          </SearchTransactions>
        </%s:Body>
      </%s:Envelope>
    """.formatted(pfx,pfx,ns,pfx,
                xe(login), xe(pwd),
                direction, xe(callerLicense), xe(ePartner),
                transactionID,
                transactionStatus==null?"":transactionStatus.toString(),
                xe(from), xe(to),
                minRecordCount==null?"":minRecordCount.toString(),
                maxRecordCount==null?"":maxRecordCount.toString(),
                pfx,pfx);
        return new SoapRequest("SearchTransactions", soap12 ? null : ACTION, body);
    }
}
