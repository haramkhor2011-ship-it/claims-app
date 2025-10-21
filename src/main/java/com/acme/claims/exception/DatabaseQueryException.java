package com.acme.claims.exception;

/**
 * Exception thrown when database query execution fails.
 * 
 * This exception is thrown when:
 * - SQL execution fails
 * - Database connection issues occur
 * - Query timeout happens
 * - Data access errors occur
 * 
 * Results in HTTP 500 (Internal Server Error) response.
 * 
 * This exception wraps underlying SQLException or DataAccessException
 * to provide consistent error handling across the application.
 */
public class DatabaseQueryException extends ReportServiceException {
    
    private final String queryName;
    private final String sqlState;
    
    /**
     * Constructs a new database query exception.
     * 
     * @param message the detail message explaining the database error
     * @param cause the underlying database exception
     */
    public DatabaseQueryException(String message, Throwable cause) {
        super(message, cause);
        this.queryName = null;
        this.sqlState = null;
    }
    
    /**
     * Constructs a new database query exception with query context.
     * 
     * @param message the detail message
     * @param queryName the name or identifier of the query that failed
     * @param cause the underlying database exception
     */
    public DatabaseQueryException(String message, String queryName, Throwable cause) {
        super(message, cause);
        this.queryName = queryName;
        this.sqlState = null;
    }
    
    /**
     * Constructs a new database query exception with full context.
     * 
     * @param message the detail message
     * @param queryName the name or identifier of the query that failed
     * @param sqlState the SQL state code from the database
     * @param cause the underlying database exception
     */
    public DatabaseQueryException(String message, String queryName, String sqlState, Throwable cause) {
        super(message, cause);
        this.queryName = queryName;
        this.sqlState = sqlState;
    }
    
    /**
     * Gets the name of the query that failed.
     * 
     * @return the query name, or null if not specified
     */
    public String getQueryName() {
        return queryName;
    }
    
    /**
     * Gets the SQL state code from the database.
     * 
     * @return the SQL state, or null if not available
     */
    public String getSqlState() {
        return sqlState;
    }
}

