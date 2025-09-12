package com.acme.claims.ingestion.parser;

public record ParseProblem(
        Severity severity, String stage, String objectType, String objectKey,
        String code, String message, Integer line, Integer column
) {
    public enum Severity { INFO, WARNING, ERROR }
}
