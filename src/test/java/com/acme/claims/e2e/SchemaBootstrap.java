package com.acme.claims.e2e;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.TestInstance;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

import javax.sql.DataSource;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

@TestInstance(TestInstance.Lifecycle.PER_CLASS)
public abstract class SchemaBootstrap {

    protected JdbcTemplate jdbc;

    @BeforeAll
    void initSchema() throws Exception {
        // Reuse container props resolved by Spring Boot tests; for pure JUnit we re-read env
        String url  = System.getProperty("spring.datasource.rw.url", System.getenv("SPRING_DATASOURCE_RW_URL"));
        String user = System.getProperty("spring.datasource.rw.username", System.getenv("SPRING_DATASOURCE_RW_USERNAME"));
        String pwd  = System.getProperty("spring.datasource.rw.password", System.getenv("SPRING_DATASOURCE_RW_PASSWORD"));

        DataSource ds = new DriverManagerDataSource(url, user, pwd);
        jdbc = new JdbcTemplate(ds);

        var ddl = Files.readString(Path.of("src/test/resources/db/claims_ddl.sql"), StandardCharsets.UTF_8);
        for (String stmt : ddl.split(";\\s*\\n")) {
            if (!stmt.isBlank()) jdbc.execute(stmt + ";");
        }
    }
}
