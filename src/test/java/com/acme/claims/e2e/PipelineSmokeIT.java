package com.acme.claims.e2e;

import com.acme.claims.domain.repo.FacilityDhpoConfigRepo;
import com.acme.claims.domain.repo.IngestionErrorRepository;
import com.acme.claims.ingestion.Pipeline;
import com.acme.claims.ingestion.fetch.WorkItem;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;
import org.springframework.ws.client.core.WebServiceTemplate;

import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles({"ingestion","soap","test"})
@TestPropertySource(properties = {
        "spring.autoconfigure.exclude=" +
                "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration," +
                "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration"
})
@ExtendWith(PostgresE2E.class)
class PipelineSmokeIT extends SchemaBootstrap{

    @Autowired Pipeline pipeline;

    @MockBean org.springframework.jdbc.core.JdbcTemplate jdbcTemplate;
    @MockBean com.acme.claims.security.ame.CredsCipherService credsCipherService;
    @MockBean com.acme.claims.security.ame.ReencryptJob reencryptJob;
    @MockBean
    IngestionErrorRepository ingestionErrorRepository;
    @MockBean WebServiceTemplate webServiceTemplate;
    @MockBean
    FacilityDhpoConfigRepo facilityDhpoConfigRepo;

    @Test
    void process_submission_xml_ok() {
        byte[] xml = "<Claim.Submission/>".getBytes();
        WorkItem wi = new WorkItem("FILE_SUB_001", xml, (Path) null, "test");
        var res = pipeline.process(wi);
        assertThat(res).isNotNull();
        assertThat(res.ingestionFileId()).isPositive();
    }
}
