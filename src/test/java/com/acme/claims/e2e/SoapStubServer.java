package com.acme.claims.e2e;

import com.github.tomakehurst.wiremock.WireMockServer;

import static com.github.tomakehurst.wiremock.client.WireMock.*;

/** Property-driven SOAP stub. Adjust mappings to match your fetcher endpoints. */
public final class SoapStubServer {
    private SoapStubServer() {}

    public static WireMockServer start(int port) {
        WireMockServer wm = new WireMockServer(port);
        wm.start();

        // [Inference] Generic SOAP action placeholders; align to your fetcher properties at runtime
        wm.stubFor(post(urlPathMatching("/soap/.*"))
                .withHeader("SOAPAction", matching(".*GetNewTransactions.*"))
                .willReturn(aResponse().withStatus(200).withHeader("Content-Type","text/xml")
                        .withBodyFile("soap/GetNewTransactionsResponse.xml")));

        wm.stubFor(post(urlPathMatching("/soap/.*"))
                .withHeader("SOAPAction", matching(".*Search.*"))
                .willReturn(aResponse().withStatus(200).withHeader("Content-Type","text/xml")
                        .withBodyFile("soap/SearchResponse.xml")));

        wm.stubFor(post(urlPathMatching("/soap/.*"))
                .withHeader("SOAPAction", matching(".*SetDownloaded.*"))
                .willReturn(aResponse().withStatus(200).withHeader("Content-Type","text/xml")
                        .withBody("<ok/>")));

        return wm;
    }
}
