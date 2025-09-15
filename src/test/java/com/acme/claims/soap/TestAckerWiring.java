package com.acme.claims.soap;

import com.acme.claims.ingestion.ack.Acker;
import com.acme.claims.ingestion.ack.NoopAcker;
import com.acme.claims.ingestion.ack.soap.SoapAckerAdapter;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import static org.assertj.core.api.Assertions.assertThat;

class TestAckerWiring {

    @Nested
    @SpringBootTest
    @ActiveProfiles({"localfs"}) // matches @Profile("localfs") on NoopAcker
    class LocalFsProfile {
        @Autowired Acker acker;
        @Test void resolves_noop_acker() {
            assertThat(acker).isInstanceOf(NoopAcker.class);
        }
    }

    @Nested
    @SpringBootTest
    @ActiveProfiles({"ingestion","soap"}) // matches @Profile({"ingestion","soap"}) on SoapAckerAdapter
    class SoapProfile {
        @Autowired Acker acker;
        @Test void resolves_soap_acker() {
            assertThat(acker).isInstanceOf(SoapAckerAdapter.class);
        }
    }
}
