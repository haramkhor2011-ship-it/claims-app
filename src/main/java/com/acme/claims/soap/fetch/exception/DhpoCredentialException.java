package com.acme.claims.soap.fetch.exception;

/**
 * Exception thrown when credential decryption or validation fails.
 */
public class DhpoCredentialException extends DhpoFetchException {
    
    public DhpoCredentialException(String facilityCode, String message) {
        super(facilityCode, "CREDENTIAL_DECRYPT", "CRED_ERROR", message);
    }

    public DhpoCredentialException(String facilityCode, String message, Throwable cause) {
        super(facilityCode, "CREDENTIAL_DECRYPT", "CRED_ERROR", message, cause);
    }
}
