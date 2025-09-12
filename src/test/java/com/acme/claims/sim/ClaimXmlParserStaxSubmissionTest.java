// FILE: src/test/java/com/acme/claims/ingestion/parse/ClaimXmlParserStaxSubmissionTest.java
// Version: v2.1.0 (aligns with final parser API)
package com.acme.claims.sim;

import com.acme.claims.domain.model.dto.SubmissionDTO;
import com.acme.claims.domain.model.entity.IngestionFile;
import com.acme.claims.ingestion.parser.*;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

final class ClaimXmlParserStaxSubmissionTest {

    private static final class StubErrorWriter implements ParserErrorWriter {
        final List<ParseProblem> problems = new ArrayList<>();
        @Override public void write(long ingestionFileId, ParseProblem p) { problems.add(p); }
    }

    private static IngestionFile file(short rootType, String fileId, byte[] bytes) {
        IngestionFile f = new IngestionFile();
        f.setId(2L);
        f.setFileId(fileId);
        f.setRootType(rootType);
        f.setSenderId("SENDER"); f.setReceiverId("RECEIVER");
        f.setTransactionDate(OffsetDateTime.parse("2024-01-01T10:00:00Z"));
        f.setRecordCountDeclared(1); f.setDispositionFlag("NONE");
        f.setXmlBytes(bytes);
        return f;
    }

    @Test
    void parsesSubmissionFromResource() throws Exception {
        // default: xml/submission.xml (override via -Dtest.submission.xml=xml/yourfile.xml)
        String cp = Resources.propOrDefault("test1.xml", "xml/test1.xml");
        byte[] bytes = Resources.readBytes(cp);

        StubErrorWriter er = new StubErrorWriter();
        ClaimXmlParserStax parser = new ClaimXmlParserStax(er);
        ReflectionTestUtils.setField(parser, "allowNonSchemaAttachments", true);
        ReflectionTestUtils.setField(parser, "maxAttachmentBytes", 10 * 1024 * 1024);
        ReflectionTestUtils.setField(parser, "failOnXsdError", false);

        IngestionFile f = file((short)1, cp, bytes);

        ParseOutcome out = parser.parse(f);
        assertEquals(ParseOutcome.RootType.SUBMISSION, out.getRootType());
        SubmissionDTO dto = out.getSubmission();
        assertNotNull(dto, "Submission DTO must be returned");
        assertNotNull(dto.header(), "Header required by XSD");
        assertTrue(dto.header().recordCount() >= 1, "RecordCount should be >= 1");
        assertFalse(dto.claims().isEmpty(), "At least one Claim expected");

        var c0 = dto.claims().get(0);
        assertNotNull(c0.id(), "Claim.ID");
        assertNotNull(c0.payerId(), "Claim.PayerID");
        assertNotNull(c0.providerId(), "Claim.ProviderID");
        assertNotNull(c0.emiratesIdNumber(), "Claim.EmiratesIDNumber");
        assertFalse(c0.activities().isEmpty(), "Claim must have >=1 Activity");

        // No ERROR-severity problems expected on a clean file
        assertTrue(er.problems.stream().noneMatch(p -> p.severity() == ParseProblem.Severity.ERROR),
                "No ERROR problems expected, got: " + er.problems);
    }

    @Test
    void recordsErrors_whenHeaderRemoved() throws Exception {
        String cp = Resources.propOrDefault("test1.xml", "xml/test1.xml");
        String xml = Resources.readString(cp);

        // Remove Header entirely to trigger XSD + business errors
        String corrupted = xml.replaceFirst("<Header>[\\s\\S]*?</Header>", "")
                .replaceFirst("<RecordCount>\\d+</RecordCount>", "<RecordCount>0</RecordCount>");

        StubErrorWriter er = new StubErrorWriter();
        ClaimXmlParserStax parser = new ClaimXmlParserStax(er);
        ReflectionTestUtils.setField(parser, "allowNonSchemaAttachments", true);
        ReflectionTestUtils.setField(parser, "maxAttachmentBytes", 10 * 1024 * 1024);
        ReflectionTestUtils.setField(parser, "failOnXsdError", false);

        IngestionFile f = file((short)1, cp + "#corrupt", corrupted.getBytes());

        ParseOutcome out = parser.parse(f);

        // Expect at least XSD_INVALID or HDR_MISSING (we log both in many cases)
        boolean hasXsdInvalid = er.problems.stream().anyMatch(p -> "XSD_INVALID".equals(p.code()));
        boolean hasHdrMissing = er.problems.stream().anyMatch(p -> "HDR_MISSING".equals(p.code()));
        assertTrue(hasXsdInvalid || hasHdrMissing, "Expected XSD_INVALID or HDR_MISSING");

        // Outcome may still exist (for full error ledger), because failOnXsdError=false
        assertNotNull(out.getSubmission());
    }
}
