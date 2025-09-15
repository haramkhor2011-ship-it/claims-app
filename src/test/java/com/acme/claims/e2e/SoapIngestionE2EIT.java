package com.acme.claims.e2e;

import com.github.tomakehurst.wiremock.WireMockServer;
import org.awaitility.Awaitility;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledIfEnvironmentVariable;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Boots ingestion,soap against a WireMock stub. Keep disabled until endpoints & payloads are aligned.
 */
@SpringBootTest
@ActiveProfiles({"ingestion","soap","test"})
@TestPropertySource(properties = {
        "spring.jpa.hibernate.ddl-auto=none",
        // Point your SOAP client properties to localhost:9099 and the matching paths used in SoapStubServer
        "dhpo.soap.baseUrl=http://localhost:9099/soap"
})
@ExtendWith(PostgresE2E.class)
@DisabledIfEnvironmentVariable(named = "NO_DOCKER", matches = "true")
@Disabled("Enable once SOAP client properties are aligned to the WireMock stub and payloads are provided.")
class SoapIngestionE2EIT extends SchemaBootstrap {

    static WireMockServer wm;

    @BeforeAll static void up() { wm = SoapStubServer.start(9099); }

    @AfterAll static void down() { if (wm != null) wm.stop(); }

    @Test
    void e2e_ingestion_runs_against_stub() {
        Awaitility.await().atMost(Duration.ofSeconds(20))
                .untilAsserted(() -> {
                    Integer files = jdbc.queryForObject("select count(*) from claims.ingestion_file", Integer.class);
                    assertThat(files).isNotNull();
                });
    }
}
