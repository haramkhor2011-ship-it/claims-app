package com.acme.claims.exception;

import java.util.ArrayList;
import java.util.List;

/**
 * Exception thrown when report request parameters are invalid.
 * 
 * This exception is thrown when:
 * - Required parameters are missing
 * - Parameter values are out of valid range
 * - Parameter combinations are invalid
 * - Business logic validation fails
 * 
 * Results in HTTP 400 (Bad Request) response.
 */
public class InvalidReportParametersException extends ReportServiceException {
    
    private final List<String> parameterErrors;
    
    /**
     * Constructs a new invalid parameters exception with a single error message.
     * 
     * @param message the detail message explaining the parameter error
     */
    public InvalidReportParametersException(String message) {
        super(message);
        this.parameterErrors = new ArrayList<>();
        this.parameterErrors.add(message);
    }
    
    /**
     * Constructs a new invalid parameters exception with multiple parameter errors.
     * 
     * @param message the summary message
     * @param parameterErrors the list of specific parameter validation errors
     */
    public InvalidReportParametersException(String message, List<String> parameterErrors) {
        super(message);
        this.parameterErrors = parameterErrors != null ? new ArrayList<>(parameterErrors) : new ArrayList<>();
    }
    
    /**
     * Gets the list of parameter validation errors.
     * 
     * @return the list of parameter errors
     */
    public List<String> getParameterErrors() {
        return new ArrayList<>(parameterErrors);
    }
}

