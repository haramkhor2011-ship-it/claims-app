package com.acme.claims.soap.fetch.exception;

/**
 * Exception thrown when SOAP operations fail.
 */
public class DhpoSoapException extends DhpoFetchException {
    private final int soapResultCode;

    public DhpoSoapException(String facilityCode, String operation, int soapResultCode, String message) {
        super(facilityCode, operation, String.valueOf(soapResultCode), message, null, isRetryableCode(soapResultCode));
        this.soapResultCode = soapResultCode;
    }

    public DhpoSoapException(String facilityCode, String operation, int soapResultCode, String message, Throwable cause) {
        super(facilityCode, operation, String.valueOf(soapResultCode), message, cause, isRetryableCode(soapResultCode));
        this.soapResultCode = soapResultCode;
    }

    public DhpoSoapException(String facilityCode, String operation, int soapResultCode, String message, boolean retryable) {
        super(facilityCode, operation, String.valueOf(soapResultCode), message, null, retryable);
        this.soapResultCode = soapResultCode;
    }

    public int getSoapResultCode() {
        return soapResultCode;
    }

    private static boolean isRetryableCode(int code) {
        // DHPO -4 is transient error that should be retried
        return code == -4;
    }
}
