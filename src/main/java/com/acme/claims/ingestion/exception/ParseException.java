// ParseException.java - Enhanced parse errors
package com.acme.claims.ingestion.exception;

public class ParseException extends IngestionException {
    private final String objectType;
    private final String objectKey;
    private final int lineNumber;
    private final int columnNumber;

    public ParseException(String fileId, String fileName, String objectType,
                          String objectKey, String errorCode, String message,
                          int lineNumber, int columnNumber) {
        super(fileId, fileName, "PARSE", errorCode, message, false);
        this.objectType = objectType;
        this.objectKey = objectKey;
        this.lineNumber = lineNumber;
        this.columnNumber = columnNumber;
    }

    // Getters...

    public String getObjectType() {
        return objectType;
    }

    public String getObjectKey() {
        return objectKey;
    }

    public int getLineNumber() {
        return lineNumber;
    }

    public int getColumnNumber() {
        return columnNumber;
    }
}