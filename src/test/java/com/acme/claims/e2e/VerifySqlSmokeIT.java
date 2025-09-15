package com.acme.claims.e2e;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledIfEnvironmentVariable;
import org.junit.jupiter.api.extension.ExtendWith;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;

/** Ensures schema is loaded and verify subset runs clean on an empty DB. */
@ExtendWith(PostgresE2E.class)
@DisabledIfEnvironmentVariable(named = "NO_DOCKER", matches = "true")
class VerifySqlSmokeIT extends com.acme.claims.e2e.SchemaBootstrap {

    @Test
    void schema_and_uniques_ok() throws Exception {
        var subset = Files.readString(Path.of("src/test/resources/db/claims_verify_subset.sql"), StandardCharsets.UTF_8);
        var parts = subset.split("-- SPLIT");

        var missing = jdbc.queryForList(parts[0]);
        assertThat(missing).isEmpty();

        var dupFiles = jdbc.queryForList(parts[1]);
        assertThat(dupFiles).isEmpty();
    }
}
