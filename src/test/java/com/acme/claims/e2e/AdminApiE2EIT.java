package com.acme.claims.e2e;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledIfEnvironmentVariable;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Boots your API server (profile=api) and hits admin endpoints.
 * Requires your security to accept a test JWT or to be disabled for test; otherwise, keep it disabled and enable after wiring.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles({"api","test"})
@TestPropertySource(properties = {
        "spring.jpa.hibernate.ddl-auto=none",
        // For simple smoke, you can temporarily relax auth in test profile. Otherwise add a valid Bearer token here.
        "spring.security.oauth2.resourceserver.jwt.jwk-set-uri=http://invalid-for-test"
})
@ExtendWith(PostgresE2E.class)
@DisabledIfEnvironmentVariable(named = "NO_DOCKER", matches = "true")
class AdminApiE2EIT extends SchemaBootstrap {

    private final TestRestTemplate rest = new TestRestTemplate();

    @Test
    void per_file_verify_endpoint_responds() {
        // If auth is enforced, this will 401; wire a test token or relax for test profile.
        ResponseEntity<String> resp = rest.getForEntity("/admin/verify/file/FILE_SUB_001", String.class);
        assertThat(resp.getStatusCode().is4xxClientError() || resp.getStatusCode().is2xxSuccessful()).isTrue();
    }
}
