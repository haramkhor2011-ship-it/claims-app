package com.acme.claims.sql;

import org.junit.jupiter.api.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.testcontainers.containers.PostgreSQLContainer;

import javax.sql.DataSource;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;

/** Smoke: load SSOT DDL, run a subset of claims_verify.sql on empty DB; expect 0 problem rows. */
class VerifySqlIT {

    static PostgreSQLContainer<?> pg = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("claims").withUsername("claimsuser").withPassword("securepass");

    static JdbcTemplate jdbc;

    @BeforeAll static void start() throws Exception {
        pg.start();
        DataSource ds = new DriverManagerDataSource(pg.getJdbcUrl(), pg.getUsername(), pg.getPassword());
        jdbc = new JdbcTemplate(ds);

        String ddl = Files.readString(Path.of("src/test/resources/db/chatgpt_ddl.sql"), StandardCharsets.UTF_8);
        for (String stmt : ddl.split(";\\s*\\n")) {
            if (!stmt.isBlank()) jdbc.execute(stmt + ";");
        }
    }

    @AfterAll static void stop() { pg.stop(); }

    @Test
    void required_tables_exist_and_uniques_clean() throws Exception {
        String verify = Files.readString(Path.of("src/test/resources/db/claims_verify_subset.sql"), StandardCharsets.UTF_8);
        // Run a few checks expecting 0 rows (empty DB)
        int missing = jdbc.queryForList(verify.split("-- SPLIT")[0]).size();
        assertThat(missing).isZero();

        int dupFiles = jdbc.queryForList(verify.split("-- SPLIT")[1]).size();
        assertThat(dupFiles).isZero();
    }
}
