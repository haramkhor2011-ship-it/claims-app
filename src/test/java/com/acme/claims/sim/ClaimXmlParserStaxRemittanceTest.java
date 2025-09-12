// FILE: src/test/java/com/acme/claims/ingestion/parse/ClaimXmlParserStaxRemittanceTest.java
// Version: v2.1.0 (aligns with final parser API)
package com.acme.claims.sim;

import com.acme.claims.domain.model.dto.RemittanceAdviceDTO;
import com.acme.claims.domain.model.entity.IngestionFile;
import com.acme.claims.ingestion.parser.*;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

final class ClaimXmlParserStaxRemittanceTest {

    private static final class StubErrorWriter implements ParserErrorWriter {
        final List<ParseProblem> problems = new ArrayList<>();
        @Override public void write(long ingestionFileId, ParseProblem p) { problems.add(p); }
    }

    private static IngestionFile file(short rootType, String fileId, byte[] bytes) {
        IngestionFile f = new IngestionFile();
        f.setId(1L); // harmless for tests
        f.setFileId(fileId);
        f.setRootType(rootType);
        f.setSenderId("SENDER"); f.setReceiverId("RECEIVER");
        f.setTransactionDate(OffsetDateTime.parse("2024-02-01T10:00:00Z"));
        f.setRecordCountDeclared(1); f.setDispositionFlag("NONE");
        f.setXmlBytes(bytes);
        return f;
    }

    @Test
    void parsesRemittanceFromResource() throws Exception {
        // default resource: xml/remittance.xml (override via -Dtest.remittance.xml=xml/yourfile.xml)
        String cp = Resources.propOrDefault("test2.xml", "xml/test2.xml");
        byte[] bytes = Resources.readBytes(cp);

        StubErrorWriter er = new StubErrorWriter();
        ClaimXmlParserStax parser = new ClaimXmlParserStax(er);
        // Optional toggles for tests
        ReflectionTestUtils.setField(parser, "allowNonSchemaAttachments", true);
        ReflectionTestUtils.setField(parser, "maxAttachmentBytes", 10 * 1024 * 1024);
        ReflectionTestUtils.setField(parser, "failOnXsdError", false);

        IngestionFile f = file((short)2, cp, bytes);

        ParseOutcome out = parser.parse(f);
        assertEquals(ParseOutcome.RootType.REMITTANCE, out.getRootType(), "Root must be Remittance");
        RemittanceAdviceDTO dto = out.getRemittance();
        assertNotNull(dto, "Remittance DTO must be returned");
        assertNotNull(dto.header(), "Header required by XSD");
        assertTrue(dto.header().recordCount() >= 1, "RecordCount should be >= 1");
        assertFalse(dto.claims().isEmpty(), "At least one Claim expected");
        var c0 = dto.claims().get(0);
        assertNotNull(c0.id(), "Claim.ID");
        assertNotNull(c0.idPayer(), "Claim.IDPayer");
        assertNotNull(c0.paymentReference(), "Claim.PaymentReference");
        assertFalse(c0.activities().isEmpty(), "Claim must have >=1 Activity");
        var a0 = c0.activities().get(0);
        assertNotNull(a0.id(), "Activity.ID");
        assertNotNull(a0.paymentAmount(), "Activity.PaymentAmount");

        // No ERROR-severity problems expected on a clean file
        assertTrue(er.problems.stream().noneMatch(p -> p.severity() == ParseProblem.Severity.ERROR),
                "No ERROR problems expected, got: " + er.problems);
    }

    @Test
    void recordsErrors_whenActivityIdMissing() throws Exception {
        String cp = Resources.propOrDefault("test2.xml", "xml/test2.xml");
        String xml = Resources.readString(cp);
        // remove only first Activity.ID to violate required child (exercise XSD/business guards)
        String corrupted = xml.replaceFirst("<Activity>\\s*<ID>[^<]+</ID>", "<Activity>");

        StubErrorWriter er = new StubErrorWriter();
        ClaimXmlParserStax parser = new ClaimXmlParserStax(er);
        ReflectionTestUtils.setField(parser, "allowNonSchemaAttachments", true);
        ReflectionTestUtils.setField(parser, "maxAttachmentBytes", 10 * 1024 * 1024);
        ReflectionTestUtils.setField(parser, "failOnXsdError", false);

        IngestionFile f = file((short)2, cp + "#corrupt", corrupted.getBytes());

        ParseOutcome out = parser.parse(f);

        // We expect either XSD_INVALID (schema missing required <ID>) and/or ACTIVITY_INVALID_CORE
        boolean hasXsdInvalid = er.problems.stream().anyMatch(p -> "XSD_INVALID".equals(p.code()));
        boolean hasActInvalid = er.problems.stream().anyMatch(p -> "ACTIVITY_INVALID_CORE".equals(p.code()));
        assertTrue(hasXsdInvalid || hasActInvalid, "Expected XSD_INVALID or ACTIVITY_INVALID_CORE");

        // The outcome still returns a DTO tree (failOnXsdError=false), but may have fewer activities
        assertNotNull(out.getRemittance(), "DTO may still be produced for full-ledger analysis");
    }
}
