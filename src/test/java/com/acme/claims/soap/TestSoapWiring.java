package com.acme.claims.soap;

import com.acme.claims.ingestion.fetch.Fetcher;
import com.acme.claims.ingestion.fetch.WorkItem;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;

import java.nio.charset.StandardCharsets;
import java.util.function.Consumer;

import static org.assertj.core.api.Assertions.assertThat;

class TestSoapWiring {

    @Test
    void testSoapFetcher() {
        Fetcher f = new TestFetcher(); // anonymous classes must implement start(Consumer<WorkItem>)
        var holder = new Object(){ WorkItem wi; };
        f.start(wi -> holder.wi = wi);

        assertThat(holder.wi).isNotNull();
        assertThat(holder.wi.fileId()).isEqualTo("FILE_SOAP_001");
        assertThat(new String(holder.wi.xmlBytes(), StandardCharsets.UTF_8)).contains("<Claim.Submission");
    }

    /** minimal fake fetcher that satisfies the SPI */
    static class TestFetcher implements Fetcher {
        @Override public void start(Consumer<WorkItem> onReady) {
            byte[] xml = "<Claim.Submission/>".getBytes(StandardCharsets.UTF_8);
            onReady.accept(new WorkItem("FILE_SOAP_001", xml, null, "soap"));
        }
        @Override public void pause() {}
        @Override public void resume() {}
    }

    @TestConfiguration
    static class Cfg {
        @Bean Fetcher testFetcherBean() { return new TestFetcher(); }
    }
}
