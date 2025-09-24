// PersistenceException.java - Database errors
package com.acme.claims.ingestion.exception;

public class PersistenceException extends IngestionException {
    private final String operation;
    private final String tableName;

    public PersistenceException(String fileId, String fileName, String operation,
                                String tableName, String message, Throwable cause) {
        super(fileId, fileName, "PERSIST", "PERSISTENCE_FAILED", message, cause, true);
        this.operation = operation;
        this.tableName = tableName;
    }

    // Getters...

    public String getOperation() {
        return operation;
    }

    public String getTableName() {
        return tableName;
    }
}