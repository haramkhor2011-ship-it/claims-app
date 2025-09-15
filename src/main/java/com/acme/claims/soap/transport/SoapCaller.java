// src/main/java/com/acme/claims/soap/transport/SoapCaller.java
package com.acme.claims.soap.transport;


import com.acme.claims.soap.SoapGateway;

public interface SoapCaller {
    SoapGateway.SoapResponse call(SoapGateway.SoapRequest req); // preserve existing DTOs
}
