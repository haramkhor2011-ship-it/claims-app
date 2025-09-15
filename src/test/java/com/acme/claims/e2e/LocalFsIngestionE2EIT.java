package com.acme.claims.e2e;

import org.awaitility.Awaitility;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledIfEnvironmentVariable;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.Duration;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Boots your real app in profile ingestion,localfs.
 * Copies fixture XMLs into a temp input dir watched by LocalFS fetcher.
 *
 * IMPORTANT: Enable after you drop real XML fixtures conforming to your parser.
 */
@SpringBootTest
@ActiveProfiles({"ingestion","localfs","test"})
@TestPropertySource(properties = {
        "claims.ingestion.poll.ms=200",
        "claims.ingestion.concurrency.parserWorkers=3",
        "claims.ingestion.queue.capacity=16",
        "spring.jpa.hibernate.ddl-auto=none"
})
@ExtendWith(PostgresE2E.class)
@DisabledIfEnvironmentVariable(named = "NO_DOCKER", matches = "true")
@Disabled("Enable after adding real XML fixtures under src/test/resources/e2e/xml/ready/*")
class LocalFsIngestionE2EIT extends SchemaBootstrap {

    private Path tmpReady;

    @BeforeEach
    void setInputDir() throws Exception {
        tmpReady = Files.createTempDirectory("e2e-ready-");
        System.setProperty("claims.fs.inputDir", tmpReady.toString());
        // copy fixtures
        var srcSub = Path.of("src/test/resources/e2e/xml/ready/submission");
        var srcRem = Path.of("src/test/resources/e2e/xml/ready/remittance");
        if (Files.exists(srcSub)) Files.walk(srcSub).filter(Files::isRegularFile).forEach(p -> copyToReady(p));
        if (Files.exists(srcRem)) Files.walk(srcRem).filter(Files::isRegularFile).forEach(p -> copyToReady(p));
    }

    private void copyToReady(Path p) {
        try {
            Files.copy(p, tmpReady.resolve(p.getFileName().toString() + "-" + UUID.randomUUID()), StandardCopyOption.REPLACE_EXISTING);
        } catch (Exception e) { throw new RuntimeException(e); }
    }

    @Test
    void end_to_end_persists_and_projects() {
        // Await some ingestion work to happen (parser→persist→project)
        Awaitility.await().atMost(Duration.ofSeconds(20))
                .untilAsserted(() -> {
                    // Basic sanity: some rows exist (adjust counts as needed)
                    Integer files = jdbc.queryForObject("select count(*) from claims.ingestion_file", Integer.class);
                    assertThat(files).isNotNull();
                    assertThat(files).isGreaterThan(0);

                    Integer claims = jdbc.queryForObject("select count(*) from claims.claim", Integer.class);
                    Integer events = jdbc.queryForObject("select count(*) from claims.claim_event", Integer.class);
                    assertThat(claims).isNotNull();
                    assertThat(events).isNotNull();
                    assertThat(claims + events).isGreaterThan(0);
                });
    }
}
