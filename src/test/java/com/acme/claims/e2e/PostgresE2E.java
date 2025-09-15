package com.acme.claims.e2e;

import org.junit.jupiter.api.extension.BeforeAllCallback;
import org.junit.jupiter.api.extension.ExtensionContext;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;

public class PostgresE2E implements BeforeAllCallback {

    private static final boolean NO_DOCKER =
            "true".equalsIgnoreCase(System.getenv("NO_DOCKER"));

    public static final PostgreSQLContainer<?> PG = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("claims")
            .withUsername("claims_user")
            .withPassword("securepass");

    @Override
    public void beforeAll(ExtensionContext context) {
        if (NO_DOCKER) return; // skip starting container when NO_DOCKER=true
        if (!PG.isRunning()) PG.start();
    }

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry r) {
        if (NO_DOCKER) {
            // Hard-disable JDBC/JPA if Docker is off (prevents EMF/DS creation)
            r.add("spring.autoconfigure.exclude", () ->
                    "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration," +
                            "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration");
            // Optional: guard against any accidental DataSource usage
            r.add("spring.datasource.url", () -> "jdbc:invalid://disabled");
        } else {
            r.add("spring.datasource.rw.url", PG::getJdbcUrl);
            r.add("spring.datasource.rw.username", PG::getUsername);
            r.add("spring.datasource.rw.password", PG::getPassword);
            r.add("spring.datasource.ro.url", PG::getJdbcUrl);
            r.add("spring.datasource.ro.username", PG::getUsername);
            r.add("spring.datasource.ro.password", PG::getPassword);
            r.add("spring.datasource.url", PG::getJdbcUrl);
            r.add("spring.datasource.username", PG::getUsername);
            r.add("spring.datasource.password", PG::getPassword);
            r.add("spring.jpa.hibernate.ddl-auto", () -> "none");
        }
    }
}
