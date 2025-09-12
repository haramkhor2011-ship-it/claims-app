// FILE: src/main/java/com/acme/claims/ingestion/error/ParseException.java
// Version: v1.0.0
package com.acme.claims.error;

public class ParseException extends RuntimeException {
    private final String code;
    private final String objectType;
    private final String objectKey;

    public ParseException(String code, String objectType, String objectKey, String message, Throwable cause) {
        super(message, cause);
        this.code = code; this.objectType = objectType; this.objectKey = objectKey;
    }
    public String getCode(){ return code; }
    public String getObjectType(){ return objectType; }
    public String getObjectKey(){ return objectKey; }
}
