// ValidationException.java - Business rule violations
package com.acme.claims.ingestion.exception;

public class ValidationException extends IngestionException {
    private final String objectType;
    private final String objectKey;
    private final String ruleViolated;

    public ValidationException(String fileId, String fileName, String objectType,
                               String objectKey, String ruleViolated, String message) {
        super(fileId, fileName, "VALIDATE", "VALIDATION_FAILED", message, false);
        this.objectType = objectType;
        this.objectKey = objectKey;
        this.ruleViolated = ruleViolated;
    }

    // Getters...

    public String getObjectType() {
        return objectType;
    }

    public String getObjectKey() {
        return objectKey;
    }

    public String getRuleViolated() {
        return ruleViolated;
    }
}