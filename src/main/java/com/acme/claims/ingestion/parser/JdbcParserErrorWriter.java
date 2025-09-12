// file: src/main/java/com/acme/claims/ingestion/parser/JdbcParserErrorWriter.java
package com.acme.claims.ingestion.parser;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Component
@RequiredArgsConstructor
public class JdbcParserErrorWriter implements ParserErrorWriter {
    private final JdbcTemplate jdbc;

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void write(long fileId, ParseProblem p) {
        jdbc.update("""
                        INSERT INTO claims.ingestion_error(ingestion_file_id, stage, object_type, object_key, error_code, error_message, retryable)
                        VALUES (?,?,?,?,?,?,false)
                        """,
                fileId, p.stage(), p.objectType(), p.objectKey(), p.code(), p.message()
        );
    }
}
