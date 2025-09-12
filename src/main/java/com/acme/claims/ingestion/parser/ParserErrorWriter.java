package com.acme.claims.ingestion.parser;

public interface ParserErrorWriter {
    void write(long ingestionFileId, ParseProblem p);
}
