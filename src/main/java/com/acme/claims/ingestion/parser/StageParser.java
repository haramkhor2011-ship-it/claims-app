package com.acme.claims.ingestion.parser;


import com.acme.claims.domain.model.entity.IngestionFile;

public interface StageParser {
    ParseOutcome parse(IngestionFile file) throws Exception; // XSD + StAX + error recording per stage
}
