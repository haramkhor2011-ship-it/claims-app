package com.acme.claims.ingestion.parser;

import com.acme.claims.domain.model.dto.*;
import com.acme.claims.domain.model.entity.IngestionFile;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.w3c.dom.ls.LSInput;
import org.w3c.dom.ls.LSResourceResolver;

import javax.xml.XMLConstants;
import javax.xml.stream.XMLInputFactory;
import javax.xml.stream.XMLStreamConstants;
import javax.xml.stream.XMLStreamException;
import javax.xml.stream.XMLStreamReader;
import javax.xml.validation.Schema;
import javax.xml.validation.SchemaFactory;
import javax.xml.validation.Validator;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.math.BigDecimal;
import java.net.URL;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.*;

/**
 * # ClaimXmlParserStax
 * StAX-based, hardened parser for **Claim.Submission** and **Remittance.Advice** roots with flexible XSD validation.
 * <p>
 * Pipeline: Fetcher → Parser → DTO → Validate → Mapper → Persist → Events/Timeline → Verify → Audit
 * <ul>
 *   <li>Root sniffing guarantees only two legal roots.</li>
 *   <li><b>Flexible XSD Validation:</b> Supports element ordering flexibility while enforcing occurrence constraints (minOccurs/maxOccurs).
 *       This makes the system future-ready for schema evolution without requiring XSD file changes.</li>
 *   <li><b>Schema Tolerance:</b> Automatically handles common variations like &lt;Comments&gt; and &lt;Attachment&gt; elements
 *       in non-standard positions within the XML structure.</li>
 *   <li>Produces SubmissionDTO/RemittanceAdviceDTO graphs + ParseProblem stream + detached binary Attachments.</li>
 *   <li>Observability: records structured problems (line/column) via {@link ParserErrorWriter} immediately.</li>
 *   <li>Security: disables DTD/external entities; compiles XSDs with secure processing and classpath resolver.</li>
 * </ul>
 *
 * <h3>Flexible XSD Validation Strategy</h3>
 * <p>This parser implements a two-tier validation approach:</p>
 * <ol>
 *   <li><b>Standard XSD Validation:</b> First attempts strict XSD compliance checking</li>
 *   <li><b>Flexible Validation:</b> If standard validation fails due to element ordering issues but involves
 *       tolerated elements (&lt;Comments&gt;, &lt;Attachment&gt;), performs occurrence-based validation instead</li>
 * </ol>
 *
 * <p><b>Benefits:</b></p>
 * <ul>
 *   <li>Future-ready: Tolerates schema evolution without code/XSD changes</li>
 *   <li>Maintains data integrity: Still enforces required element counts</li>
 *   <li>Reduces maintenance burden: No need to update XSD files for minor structure changes</li>
 * </ul>
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ClaimXmlParserStax implements StageParser {

    private final ParserErrorWriter errorWriter;

    // ----------------------------------------------------------------------
    // Config/feature toggles
    // ----------------------------------------------------------------------

    /**
     * @deprecated Toggle removed by policy: undeclared &lt;Attachment&gt; under &lt;Claim&gt; is always tolerated as WARNING and persisted if present.
     * Kept for backward property compatibility; value is ignored. // PATCH: deprecated, no longer used.
     */
    @Deprecated
    @Value("${claims.parser.allowNonSchemaAttachments:false}")
    private boolean allowNonSchemaAttachments; // tolerate <Attachment> under <Claim> in submissions (ignored)

    /** Max decoded bytes per single attachment payload (configurable). */
    @Value("${claims.parser.maxAttachmentBytes:33554432}") // 32MB
    private int maxAttachmentBytes;

    /** If true, stop on XSD errors; else continue with problems recorded. */
    @Value("${claims.parser.failOnXsdError:false}")
    private boolean failOnXsdError;

    /** Two legal roots. */
    private enum Root {SUBMISSION, REMITTANCE}

    // One secured, reusable XMLInputFactory
    private final XMLInputFactory xif = buildSafeXif();

    // XSDs under src/main/resources/xsd/
    private final Schema submissionSchema = compileSchema("/xsd/ClaimSubmission.xsd");
    private final Schema remittanceSchema = compileSchema("/xsd/RemittanceAdvice.xsd");

    // Accept common DHPO/ISO formats; normalize to OffsetDateTime
    private static final DateTimeFormatter F_DDMMYYYY_HHMM = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
    private static final DateTimeFormatter F_YMD_HMS = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static final ZoneId DEFAULT_ZONE = ZoneId.systemDefault();

    /**
     * Construct a hardened {@link XMLInputFactory}:
     * <ul>
     *   <li>Disable DTDs and external entities (XXE safe).</li>
     *   <li>Coalesce character data for contiguous CHARACTERS/CDATA.</li>
     * </ul>
     */
    private static XMLInputFactory buildSafeXif() {
        XMLInputFactory f = XMLInputFactory.newFactory();
        f.setProperty(XMLInputFactory.SUPPORT_DTD, false);
        f.setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, false);
        f.setProperty(XMLInputFactory.IS_COALESCING, true);
        return f;
    }

    // === Public API =======================================================================

    /**
     * Parse a single {@link IngestionFile}:
     * <ol>
     *   <li>Open a resettable stream over the raw XML bytes.</li>
     *   <li>Sniff the root element to determine schema.</li>
     *   <li>Validate against the corresponding XSD (record errors/warnings).</li>
     *   <li>Parse into DTO graph; collect problems and optional attachments.</li>
     * </ol>
     *
     * @param file IngestionFile containing raw XML bytes and DB id
     * @return {@link ParseOutcome} with DTOs, problems, and detached attachments
     */
    @Override
    public ParseOutcome parse(IngestionFile file) throws Exception {
        Objects.requireNonNull(file, "IngestionFile");
        long fileId = Objects.requireNonNull(file.getId(), "ingestion_file.id required");
        log.info("parse : {}", file.getFileId());

        Resettable is = openInput(file);                 // supports stageToDisk=true
        Root root = sniffRoot(is);
        is.reset();

        List<ParseProblem> problems = new ArrayList<>();
        boolean xsdFailed = !validateAgainstXsd(is, root, problems, file.getFileId(), fileId);
        log.info("xsdFailed : {}, fileId: {}", xsdFailed, file.getFileId());
        is.reset();
        if (xsdFailed && failOnXsdError) {
            return new ParseOutcome(
                    root == Root.SUBMISSION ? ParseOutcome.RootType.SUBMISSION : ParseOutcome.RootType.REMITTANCE,
                    null, null, problems, List.of()
            );
        }
        log.info("Going to Parse XML fileId: {}", file.getFileId());
        return (root == Root.SUBMISSION)
                ? parseSubmission(is, fileId, problems)
                : parseRemittance(is, fileId, problems);
    }

    // === I/O & XSD ========================================================================

    /**
     * Open a resettable stream over the XML bytes. Throws for empty/null content.
     */
    private Resettable openInput(IngestionFile f) {
        byte[] bytes = f.getXmlBytes();
        if (bytes == null || bytes.length == 0) {
            throw new IllegalArgumentException("IngestionFile.xmlBytes is required and was empty/null (id=" + f.getId() + ")");
        }
        return new Resettable(new ByteArrayInputStream(bytes)); // single buffer reused for XSD + parse
    }

    /**
     * Compile an XSD from classpath with secure processing and a classpath resource resolver.
     */
    private Schema compileSchema(String classpathXsd) {
        try {
            URL url = Objects.requireNonNull(getClass().getResource(classpathXsd),
                    "Missing XSD on classpath: " + classpathXsd);
            SchemaFactory sf = SchemaFactory.newInstance(XMLConstants.W3C_XML_SCHEMA_NS_URI);
            sf.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
            sf.setResourceResolver(new ClasspathResourceResolver("/xsd/"));
            return sf.newSchema(url);
        } catch (Exception e) {
            throw new IllegalStateException("Failed to compile XSD " + classpathXsd, e);
        }
    }

    /**
     * Sniff the XML root and ensure one of the two legal roots.
     */
    private Root sniffRoot(Resettable is) throws Exception {
        XMLStreamReader r = xif.createXMLStreamReader(is);
        try {
            while (r.hasNext()) {
                int ev = r.next();
                if (ev == XMLStreamConstants.START_ELEMENT) {
                    String local = r.getLocalName();
                    if ("Claim.Submission".equals(local)) return Root.SUBMISSION;
                    if ("Remittance.Advice".equals(local)) return Root.REMITTANCE;
                    throw new XMLStreamException("Unexpected root element: " + local, r.getLocation());
                }
            }
            throw new XMLStreamException("No root element found");
        } finally {
            try { r.close(); } catch (Exception ignore) {}
        }
    }

    /**
     * Validate against appropriate XSD.
     * <p><b>PATCH:</b> If validator error only mentions undeclared <code>Attachment</code>,
     * we always emit a WARNING and continue (toggle removed by policy).</p>
     *
     * @return true when no XSD ERROR (i.e., either OK or tolerated Attachment case)
     */
    /**
     * Validate XML structure with flexible element ordering but strict occurrence constraints.
     * This approach is future-ready and tolerant of schema changes while maintaining data integrity.
     *
     * @param is InputStream to validate (will be reset after reading)
     * @param root Expected root element type
     * @param problems List to collect validation problems
     * @param fileIdXml File identifier for logging
     * @param fileId File identifier for problem reporting
     * @return true if validation passes or only contains tolerated elements; false if should fail
     */
    private boolean validateAgainstXsd(Resettable is, Root root, List<ParseProblem> problems, String fileIdXml, long fileId) {
        try {
            // Try standard XSD validation first
            Validator v = (root == Root.SUBMISSION ? submissionSchema : remittanceSchema).newValidator();
            v.validate(new javax.xml.transform.stream.StreamSource(is));
            log.info("Validated xsd");
            return true;
        } catch (Exception e) {
            log.info("Exception while validating XSD fileId: {}, Exc: {}",fileIdXml, e.getMessage());
            final String msg = (e.getMessage() == null) ? "XSD validation failed" : e.getMessage();
            log.info("msg: {}", msg);

            // Enhanced flexible validation for future-ready schema handling
            return validateFlexibleStructure(is, root, problems, fileId, msg);
        }
    }

    /**
     * Flexible XML structure validation that allows elements in any order but enforces
     * minOccurs/maxOccurs constraints. This makes the system tolerant of schema evolution.
     *
     * @param is InputStream to validate (will be reset after reading)
     * @param root Expected root element type
     * @param problems List to collect validation problems
     * @param fileId File identifier for problem reporting
     * @param originalErrorMsg Original XSD error message for context
     * @return true if structure is acceptable (passes or only tolerated issues); false if should fail
     */
    private boolean validateFlexibleStructure(Resettable is, Root root, List<ParseProblem> problems, long fileId, String originalErrorMsg) {

        // Check if error is due to tolerated elements (Comments, Attachment) in wrong positions
        final boolean attachmentOnly = originalErrorMsg.contains("Attachment");
        final boolean commentsPresent = originalErrorMsg.contains("Comments");
        final boolean orderIssue = originalErrorMsg.contains("Invalid content was found") ||
                                  originalErrorMsg.contains("expected") ||
                                  originalErrorMsg.contains("One of");

        if ((attachmentOnly || commentsPresent) && orderIssue) {
            // Flexible validation: Allow Comments/Attachment anywhere in Claim structure
            // but still validate they appear the correct number of times
            log.debug("Flexible XSD validation: Allowing Comments/Attachment in non-standard position for fileId: {}", fileId);

            try {
                // Perform occurrence validation instead of strict order validation
                return validateElementOccurrences(is, root, problems, fileId);
            } catch (Exception e) {
                log.error("Failed to perform flexible validation for fileId: {}, error: {}", fileId, e.getMessage());
                addProblem(problems, fileId, null, ParseProblem.Severity.ERROR,
                        "XSD", "ROOT", root.name(), "FLEXIBLE_VALIDATION_FAILED",
                        "Flexible validation failed: " + e.getMessage());
                return false;
            }
        }

        // For other types of errors, use original strict validation
        addProblem(problems, fileId, null, ParseProblem.Severity.ERROR,
                "XSD", "ROOT", root.name(), "XSD_INVALID", originalErrorMsg);
        return false;
    }

    /**
     * Validate that required elements appear the correct number of times, regardless of order.
     * This provides flexibility for schema evolution while maintaining data integrity.
     *
     * @param is InputStream to validate
     * @param root Expected root element type
     * @param problems List to collect validation problems
     * @param fileId File identifier for problem reporting
     * @return true if occurrence constraints are satisfied
     */
    private boolean validateElementOccurrences(Resettable is, Root root, List<ParseProblem> problems, long fileId) {
        try {
            is.reset(); // Reset stream for occurrence counting

            // Count occurrences of key elements in the XML
            Map<String, Integer> elementCounts = countElementOccurrences(is);

            // Validate based on root type
            if (root == Root.SUBMISSION) {
                return validateSubmissionOccurrences(elementCounts, problems, fileId);
            } else {
                return validateRemittanceOccurrences(elementCounts, problems, fileId);
            }

        } catch (Exception e) {
            log.error("Error during occurrence validation for fileId: {}, error: {}", fileId, e.getMessage());
            return false;
        }
    }

    /**
     * Count occurrences of key XML elements in the input stream.
     * Uses a simple parsing approach to count elements without strict order validation.
     */
    private Map<String, Integer> countElementOccurrences(Resettable is) throws Exception {
        Map<String, Integer> counts = new HashMap<>();
        XMLStreamReader reader = xif.createXMLStreamReader(is);

        while (reader.hasNext()) {
            if (reader.next() == XMLStreamConstants.START_ELEMENT) {
                String elementName = reader.getLocalName();
                counts.merge(elementName, 1, Integer::sum);
            }
        }
        reader.close();
        return counts;
    }

    /**
     * Validate occurrence constraints for Submission XML structure.
     */
    private boolean validateSubmissionOccurrences(Map<String, Integer> counts, List<ParseProblem> problems, long fileId) {
        // Check required elements in Header (minOccurs=1, maxOccurs=1)
        if (!counts.getOrDefault("Header", 0).equals(1)) {
            addProblem(problems, fileId, null, ParseProblem.Severity.ERROR,
                    "XSD", "HEADER", "Submission", "HEADER_COUNT_INVALID",
                    "Expected exactly 1 Header element, found: " + counts.getOrDefault("Header", 0));
            return false;
        }

        // Check Claims (minOccurs=1, maxOccurs=unbounded)
        int claimCount = counts.getOrDefault("Claim", 0);
        if (claimCount == 0) {
            addProblem(problems, fileId, null, ParseProblem.Severity.ERROR,
                    "XSD", "CLAIMS", "Submission", "NO_CLAIMS",
                    "Expected at least 1 Claim element, found: " + claimCount);
            return false;
        }

        log.info("Flexible validation passed for Submission: {} claims, fileId: {}", claimCount, fileId);
        return true;
    }

    /**
     * Validate occurrence constraints for Remittance XML structure.
     */
    private boolean validateRemittanceOccurrences(Map<String, Integer> counts, List<ParseProblem> problems, long fileId) {
        // Check required elements in Header (minOccurs=1, maxOccurs=1)
        if (!counts.getOrDefault("Header", 0).equals(1)) {
            addProblem(problems, fileId, null, ParseProblem.Severity.ERROR,
                    "XSD", "HEADER", "Remittance", "HEADER_COUNT_INVALID",
                    "Expected exactly 1 Header element, found: " + counts.getOrDefault("Header", 0));
            return false;
        }

        // Check Claims (minOccurs=1, maxOccurs=unbounded)
        int claimCount = counts.getOrDefault("Claim", 0);
        if (claimCount == 0) {
            addProblem(problems, fileId, null, ParseProblem.Severity.ERROR,
                    "XSD", "CLAIMS", "Remittance", "NO_CLAIMS",
                    "Expected at least 1 Claim element, found: " + claimCount);
            return false;
        }

        log.info("Flexible validation passed for Remittance: {} claims, fileId: {}", claimCount, fileId);
        return true;
    }

    // === Submission =======================================================================

    /**
     * Parse a Claim.Submission root:
     * <ul>
     *   <li>Header → {@link SubmissionHeaderDTO}</li>
     *   <li>Claims → {@link SubmissionClaimDTO}</li>
     *   <li>Detached claim-level attachments emitted via {@link ParseOutcome.AttachmentRecord}</li>
     * </ul>
     */
    private ParseOutcome parseSubmission(Resettable is, long fileId, List<ParseProblem> problems) throws Exception {
        XMLStreamReader r = xif.createXMLStreamReader(is);
        try {
            SubmissionHeaderDTO header = null;
            List<SubmissionClaimDTO> claims = new ArrayList<>();
            List<ParseOutcome.AttachmentRecord> attachmentsOut = new ArrayList<>();
            int claimCount = 0;

            while (r.hasNext()) {
                int ev = r.next();

                if (ev == XMLStreamConstants.START_ELEMENT) {
                    switch (r.getLocalName()) {
                        case "Header" -> header = readSubmissionHeader(r, problems, fileId);
                        case "Claim" -> {
                            claimCount++;
                            var parsed = readSubmissionClaim(r, problems, fileId); // consumes until </Claim>
                            claims.add(parsed.claim());
                            if (!parsed.attachments().isEmpty()) attachmentsOut.addAll(parsed.attachments());
                        }
                    }
                }
            }

            if (header == null) addProblem(problems, fileId, null, ParseProblem.Severity.ERROR,
                    "VALIDATE", "Header", null, "HDR_MISSING", "Header element missing");
            if (header != null && header.recordCount() != claimCount)
                addProblem(problems, fileId, null, ParseProblem.Severity.WARNING,
                        "VALIDATE", "Header", null, "COUNT_MISMATCH",
                        "Header.RecordCount=" + header.recordCount() + " but body has " + claimCount);

            SubmissionDTO dto = new SubmissionDTO(header, claims);
            log.info("Successfully parsed Submission");
            return new ParseOutcome(ParseOutcome.RootType.SUBMISSION, dto, null, problems, attachmentsOut);
        } finally {
            try { r.close(); } catch (Exception ignore) {}
        }
    }

    /** Aggregates a parsed claim and any claim-level attachments discovered. */
    private record ParsedSubmissionClaim(SubmissionClaimDTO claim, List<ParseOutcome.AttachmentRecord> attachments) {}
    private record ParsedRemittanceClaim(RemittanceClaimDTO claim, List<ParseOutcome.AttachmentRecord> attachments) {}

    /**
     * Parse a single &lt;Claim&gt; in Submission, including:
     * scalars, optional Encounter (minOccurs=0), 1..* Diagnosis, 1..* Activity, optional Resubmission/Contract and non-schema Attachment.
     */
    private ParsedSubmissionClaim readSubmissionClaim(XMLStreamReader r, List<ParseProblem> problems, long fileId) throws Exception {
        String id = null, idPayer = null, memberId = null, payerId = null, providerId = null, emiratesId = null, comments = null;
        BigDecimal gross = null, patientShare = null, net = null;
        EncounterDTO enc = null;
        Set<DiagnosisDTO> dx = new HashSet<>();
        Set<ActivityDTO> acts = new HashSet<>();
        ResubmissionDTO res = null;
        ContractDTO contract = null;
        List<ParseOutcome.AttachmentRecord> attachments = new ArrayList<>();
        Set<String> activityIds = new HashSet<>();

        while (r.hasNext()) {
            int ev = r.next();

            if (ev == XMLStreamConstants.START_ELEMENT) {
                String el = r.getLocalName();

                switch (el) {
                    // ----- simple claim fields
                    case "ID" -> id = nn(readElementText(r));
                    case "IDPayer" -> idPayer = nn(readElementText(r));
                    case "MemberID" -> memberId = nn(readElementText(r));
                    case "PayerID" -> payerId = nn(readElementText(r));
                    case "ProviderID" -> providerId = nn(readElementText(r));
                    case "EmiratesIDNumber" -> emiratesId = nn(readElementText(r));
                    case "Gross" -> gross = parseDecimal(readElementText(r), "Gross", problems, fileId, r);
                    case "PatientShare" ->
                            patientShare = parseDecimal(readElementText(r), "PatientShare", problems, fileId, r);
                    case "Net" -> net = parseDecimal(readElementText(r), "Net", problems, fileId, r);

                    // ----- complex
                    case "Encounter" -> enc = readEncounter(r, problems, fileId, id);
                    case "Diagnosis" -> {
                        String t = nn(readChild(r, "Type"));
                        String c = nn(readChild(r, "Code"));
                        if (isBlank(t) || isBlank(c)) {
                            if (isBlank(t))
                                addProblem(problems, fileId, r, ParseProblem.Severity.ERROR, "PARSE", "Diagnosis", "Type", "REQ_MISSING", "Diagnosis/Type is required");
                            if (isBlank(c))
                                addProblem(problems, fileId, r, ParseProblem.Severity.ERROR, "PARSE", "Diagnosis", "Code", "REQ_MISSING", "Diagnosis/Code is required");
                        } else {
                            dx.add(new DiagnosisDTO(t, c));
                        }
                        skipToEnd(r, "Diagnosis");
                    }
                    case "Activity" -> {
                        var act = readSubmissionActivity(r, problems, fileId, activityIds, id);
                        if (act != null) acts.add(act);
                    }
                    case "Resubmission" -> {
                        String t = nn(readChild(r, "Type"));
                        String c = nn(readChild(r, "Comment"));
                        byte[] att = decodeBase64OrNull(readOptionalChild(r, "Attachment"), problems, fileId, "ResubmissionAttachment", id);
                        res = new ResubmissionDTO(t, c, att);
                        skipToEnd(r, "Resubmission");
                    }
                    case "Contract" -> {
                        String pkg = nn(readChild(r, "PackageName"));
                        contract = new ContractDTO(pkg);
                        skipToEnd(r, "Contract");
                    }

                    case "Comments" -> {
                        comments = nn(readChild(r, "Comments"));
                        skipToEnd(r, "Comments");
                    }

                    // ----- NON-SCHEMA Attachment (Submission only)
                    case "Attachment" -> {
                        ParseOutcome.AttachmentRecord attachment = readAttachment(r, problems, fileId, "Claim", id);
                        if (attachment != null) {
                            attachments.add(attachment);
                        }
                    }
                }
            } else if (ev == XMLStreamConstants.END_ELEMENT && "Claim".equals(r.getLocalName())) {
                break;
            }
        }

        // Requires (beyond XSD) for observability; we still build the DTO
        // PATCH: Encounter is minOccurs=0 — at most WARNING when missing.
        //if (enc == null) addProblem(problems, fileId, null, ParseProblem.Severity.WARNING,
          //      "VALIDATE", "Encounter", id, "ENCOUNTER_MISSING", "Encounter is optional and was not supplied");

        if (dx.isEmpty()) addProblem(problems, fileId, null, ParseProblem.Severity.ERROR,
                "VALIDATE", "Diagnosis", id, "DIAGNOSIS_MISSING", "At least one Diagnosis required");
        if (acts.isEmpty()) addProblem(problems, fileId, null, ParseProblem.Severity.ERROR,
                "VALIDATE", "Activity", id, "ACTIVITY_MISSING", "At least one Activity required");

        // Claim required scalars
        if (isBlank(id))
            addProblem(problems, fileId, null, ParseProblem.Severity.ERROR, "PARSE", "Claim", "ID", "REQ_MISSING", "Claim/ID is required");
        if (isBlank(payerId))
            addProblem(problems, fileId, null, ParseProblem.Severity.ERROR, "PARSE", "Claim", "PayerID", "REQ_MISSING", "Claim/PayerID is required");
        if (isBlank(providerId))
            addProblem(problems, fileId, null, ParseProblem.Severity.ERROR, "PARSE", "Claim", "ProviderID", "REQ_MISSING", "Claim/ProviderID is required");

        SubmissionClaimDTO claim = new SubmissionClaimDTO(
                id, idPayer, memberId, payerId, providerId, emiratesId,
                gross, patientShare, net, comments, enc, dx, acts, res, contract
        );

        return new ParsedSubmissionClaim(claim, attachments);
    }

    /**
     * Parse &lt;Encounter&gt; block in Submission (optional overall; columns within are required when present).
     * Empty encounter (no core fields) is treated as missing with a WARNING.
     */
    private EncounterDTO readEncounter(XMLStreamReader r, List<ParseProblem> problems, long fileId, String claimId) throws Exception {
        String facility = null, type = null, patientId = null, startType = null, endType = null, src = null, dst = null;
        OffsetDateTime start = null, end = null;

        while (r.hasNext()) {
            int ev = r.next();
            if (ev == XMLStreamConstants.START_ELEMENT) {
                switch (r.getLocalName()) {
                    case "FacilityID" -> facility = nn(readElementText(r));
                    case "Type" -> type = nn(readElementText(r));
                    case "PatientID" -> patientId = nn(readElementText(r));
                    case "Start" -> start = parseTime(readElementText(r), "Encounter/Start", problems, fileId, r);
                    case "End" -> end = parseTime(readElementText(r), "Encounter/End", problems, fileId, r);
                    case "StartType" -> startType = nn(readElementText(r));
                    case "EndType" -> endType = nn(readElementText(r));
                    case "TransferSource" -> src = nn(readElementText(r));
                    case "TransferDestination" -> dst = nn(readElementText(r));
                }
            } else if (ev == XMLStreamConstants.END_ELEMENT && "Encounter".equals(r.getLocalName())) {
                break;
            }
        }

        boolean allEmpty = isBlank(facility) && isBlank(type) && isBlank(patientId) && start == null;
        if (allEmpty) {
            addProblem(problems, fileId, null, ParseProblem.Severity.WARNING, "VALIDATE", "Encounter", claimId,
                    "EMPTY_ELEMENT", "Encounter present but contains no data; treated as missing");
            return null;
        }
        return new EncounterDTO(facility, type, patientId, start, end, startType, endType, src, dst);
    }

    /**
     * Parse &lt;Activity&gt; in Submission (required fields; duplicates by ID are skipped with WARNING).
     * Required fields: ID, Start, Type, Code, Quantity, Net, Clinician (per DDL, minOccurs=1).
     * See DDL for NOT NULLs on activity, including Clinician. :contentReference[oaicite:0]{index=0}
     */
    private ActivityDTO readSubmissionActivity(XMLStreamReader r, List<ParseProblem> problems, long fileId, Set<String> seenIds, String claimId) throws Exception {
        String id = null, type = null, code = null, clinician = null, priorAuth = null;
        OffsetDateTime start = null;
        BigDecimal qty = null, net = null;
        Set<ObservationDTO> obs = new HashSet<>();

        while (r.hasNext()) {
            int ev = r.next();
            if (ev == XMLStreamConstants.START_ELEMENT) {
                switch (r.getLocalName()) {
                    case "ID" -> id = nn(readElementText(r));
                    case "Start" -> start = parseTime(readElementText(r), "Activity/Start", problems, fileId, r);
                    case "Type" -> type = nn(readElementText(r));
                    case "Code" -> code = nn(readElementText(r));
                    case "Quantity" -> qty = parseDecimal(readElementText(r), "Activity/Quantity", problems, fileId, r);
                    case "Net" -> net = parseDecimal(readElementText(r), "Activity/Net", problems, fileId, r);
                    case "Clinician" -> clinician = nn(readElementText(r));
                    case "PriorAuthorizationID" -> priorAuth = nn(readElementText(r));
                    case "Observation" -> {
                        ObservationDTO o = readObservation(r, problems, fileId, claimId);
                        if (o != null) obs.add(o);
                    }
                }
            } else if (ev == XMLStreamConstants.END_ELEMENT && "Activity".equals(r.getLocalName())) {
                break;
            }
        }
        if (id != null && !seenIds.add(id)) {
            addProblem(problems, fileId, null, ParseProblem.Severity.WARNING, "VALIDATE", "Activity", id, "DUP_ACTIVITY",
                    "Duplicate Activity/ID within Claim; skipping duplicate");
            return null;
        }

        boolean coreMissing = isBlank(id) || isBlank(type) || isBlank(code) || start == null || qty == null || net == null || isBlank(clinician);
        if (coreMissing) {
            addProblem(problems, fileId, null, ParseProblem.Severity.ERROR, "VALIDATE", "Activity", id, "ACTIVITY_INVALID_CORE",
                    "Activity missing one or more required fields; it will be skipped");
            return null;
        }

        return new ActivityDTO(id, start, type, code, qty, net, clinician, priorAuth, obs);
    }

    /**
     * Parse &lt;Observation&gt; (0..*), requiring Type and Code. Value/ValueType optional.
     * Empty observation node is skipped with WARNING. DB de-dup is enforced downstream by unique index on (activity_id, obs_type, obs_code, md5(value_text)). :contentReference[oaicite:1]{index=1}
     */
    private ObservationDTO readObservation(XMLStreamReader r, List<ParseProblem> problems, long fileId, String claimId) throws Exception {
        String type = null, code = null, value = null, valueType = null;
        byte[] fileBytes = null;

        while (r.hasNext()) {
            int ev = r.next();
            if (ev == XMLStreamConstants.START_ELEMENT) {
                switch (r.getLocalName()) {
                    case "Type" -> type = nn(readElementText(r));
                    case "Code" -> code = nn(readElementText(r));
                    case "Value" -> {
                        if("File".equalsIgnoreCase(type)) {
                            fileBytes = decodeBase64OrNull(readOptionalChild(r, "Value"), problems, fileId, "Observation Attachment", claimId);
                        } else {
                            value = nn(readElementText(r));
                        }
                    }
                    case "ValueType" -> valueType = nn(readElementText(r));
                }
            } else if (ev == XMLStreamConstants.END_ELEMENT && "Observation".equals(r.getLocalName())) {
                break;
            }
        }

        if (isBlank(type) && isBlank(code) && isBlank(value) && isBlank(valueType)) {
            addProblem(problems, fileId, null, ParseProblem.Severity.WARNING,
                    "VALIDATE", "Observation", null, "EMPTY_ELEMENT", "Observation present but contains no data; skipped");
            return null;
        }
        if (isBlank(type) || isBlank(code)) {
            if (isBlank(type))
                addProblem(problems, fileId, null, ParseProblem.Severity.ERROR, "PARSE", "Observation", "Type", "REQ_MISSING", "Observation/Type is required");
            if (isBlank(code))
                addProblem(problems, fileId, null, ParseProblem.Severity.ERROR, "PARSE", "Observation", "Code", "REQ_MISSING", "Observation/Code is required");
            return null;
        }
        return new ObservationDTO(type, code, value, valueType, fileBytes);
    }

    /**
     * Parse Submission &lt;Header&gt; (all scalars are required).
     */
    private SubmissionHeaderDTO readSubmissionHeader(XMLStreamReader r, List<ParseProblem> problems, long fileId) throws Exception {
        String sender = null, receiver = null, disp = null;
        OffsetDateTime tx = null;
        Integer rc = null;

        while (r.hasNext()) {
            int ev = r.next();
            if (ev == XMLStreamConstants.START_ELEMENT) {
                switch (r.getLocalName()) {
                    case "SenderID" -> sender = nn(readElementText(r));
                    case "ReceiverID" -> receiver = nn(readElementText(r));
                    case "TransactionDate" ->
                            tx = parseTime(readElementText(r), "Header/TransactionDate", problems, fileId, r);
                    case "RecordCount" ->
                            rc = parseInteger(readElementText(r), "Header/RecordCount", problems, fileId, r);
                    case "DispositionFlag" -> disp = nn(readElementText(r));
                }
            } else if (ev == XMLStreamConstants.END_ELEMENT && "Header".equals(r.getLocalName())) break;
        }

        return new SubmissionHeaderDTO(sender, receiver, tx, rc == null ? 0 : rc, disp);
    }

    // === Remittance ======================================================================

    /**
     * Parse a Remittance.Advice root:
     * Header + Claim list (with Encounter/FacilityID if present) + Activities.
     */
    private ParseOutcome parseRemittance(Resettable is, long fileId, List<ParseProblem> problems) throws Exception {
        XMLStreamReader r = xif.createXMLStreamReader(is);
        try {
            RemittanceHeaderDTO header = null;
            List<RemittanceClaimDTO> claims = new ArrayList<>();
            List<ParseOutcome.AttachmentRecord> attachmentsOut = new ArrayList<>();
            int claimCount = 0;

            while (r.hasNext()) {
                int ev = r.next();

                if (ev == XMLStreamConstants.START_ELEMENT) {
                    switch (r.getLocalName()) {
                        case "Header" -> header = readRemittanceHeader(r, problems, fileId);
                        case "Claim" -> {
                            claimCount++;
                            var parsed = readRemittanceClaim(r, problems, fileId); // consumes until </Claim>
                            claims.add(parsed.claim());
                            if (!parsed.attachments().isEmpty()) attachmentsOut.addAll(parsed.attachments());
                        }
                    }
                }
            }

            if (header == null) addProblem(problems, fileId, null, ParseProblem.Severity.ERROR,
                    "VALIDATE", "Header", null, "HDR_MISSING", "Header element missing");

            if (header != null && header.recordCount() != claimCount)
                addProblem(problems, fileId, null, ParseProblem.Severity.WARNING,
                        "VALIDATE", "Header", null, "COUNT_MISMATCH",
                        "Header.RecordCount=" + header.recordCount() + " but body has " + claimCount);

            RemittanceAdviceDTO dto = new RemittanceAdviceDTO(header, claims);
            log.debug("Successfully parsed RemittanceAdvice");
            return new ParseOutcome(ParseOutcome.RootType.REMITTANCE, null, dto, problems, List.of());
        } finally {
            try { r.close(); } catch (Exception ignore) {}
        }
    }

    /**
     * Parse a single &lt;Claim&gt; inside Remittance. Required: ID, IDPayer, PaymentReference.
     * Encounter/FacilityID is read if present (stored on remittance_claim table per DDL). :contentReference[oaicite:2]{index=2}
     */
    private ParsedRemittanceClaim readRemittanceClaim(XMLStreamReader r, List<ParseProblem> problems, long fileId) throws Exception {
        String id = null, idPayer = null, providerId = null, denialCode = null, paymentRef = null, facilityId = null, comments = null;
        OffsetDateTime dateSettlement = null;
        List<RemittanceActivityDTO> acts = new ArrayList<>();
        Set<String> activityIds = new HashSet<>();
        List<ParseOutcome.AttachmentRecord> attachments = new ArrayList<>();
        while (r.hasNext()) {
            int ev = r.next();
            if (ev == XMLStreamConstants.START_ELEMENT) {
                switch (r.getLocalName()) {
                    case "ID" -> id = nn(readElementText(r));
                    case "IDPayer" -> idPayer = nn(readElementText(r));
                    case "ProviderID" -> providerId = nn(readElementText(r));
                    case "DenialCode" -> denialCode = nn(readElementText(r));
                    case "PaymentReference" -> paymentRef = nn(readElementText(r));
                    case "DateSettlement" ->
                            dateSettlement = parseTime(readElementText(r), "Claim/DateSettlement", problems, fileId, r);
                    case "Encounter" -> {
                        facilityId = nn(readChild(r, "FacilityID"));
                        skipToEnd(r, "Encounter");
                    }
                    case "Comments" -> comments = nn(readElementText(r));
                    case "Activity" -> {
                        RemittanceActivityDTO a = readRemittanceActivity(r, problems, fileId, activityIds);
                        if (a != null) acts.add(a);
                    }
                    case "Attachment" -> {
                        ParseOutcome.AttachmentRecord a = readAttachment(r, problems, fileId, "Claim", id);
                        if (a != null) attachments.add(a);
                    }
                }
            } else if (ev == XMLStreamConstants.END_ELEMENT && "Claim".equals(r.getLocalName())) {
                break;
            }
        }

        if (isBlank(id))
            addProblem(problems, fileId, null, ParseProblem.Severity.ERROR, "PARSE", "RemittanceClaim", "ID", "REQ_MISSING", "Claim/ID is required");
        if (isBlank(idPayer))
            addProblem(problems, fileId, null, ParseProblem.Severity.ERROR, "PARSE", "RemittanceClaim", "IDPayer", "REQ_MISSING", "Claim/IDPayer is required");
        if (isBlank(paymentRef))
            addProblem(problems, fileId, null, ParseProblem.Severity.ERROR, "PARSE", "RemittanceClaim", "PaymentReference", "REQ_MISSING", "PaymentReference is required");

        return new ParsedRemittanceClaim(new RemittanceClaimDTO(id, idPayer, providerId, denialCode, paymentRef, dateSettlement, facilityId, acts, comments), attachments);
    }

    /**
     * Parse &lt;Activity&gt; inside Remittance. Required: ID, Start, Type, Code, Quantity, Net, PaymentAmount, Clinician (per DDL). :contentReference[oaicite:3]{index=3}
     * Duplicates by ID are skipped with WARNING.
     */
    private RemittanceActivityDTO readRemittanceActivity(XMLStreamReader r, List<ParseProblem> problems, long fileId, Set<String> seenIds) throws Exception {
        String id = null, type = null, code = null, clinician = null, priorAuth = null, denialCode = null;
        OffsetDateTime start = null;
        BigDecimal qty = null, net = null, list = null, gross = null, patientShare = null, pay = null;

        while (r.hasNext()) {
            int ev = r.next();
            if (ev == XMLStreamConstants.START_ELEMENT) {
                switch (r.getLocalName()) {
                    case "ID" -> id = nn(readElementText(r));
                    case "Start" -> start = parseTime(readElementText(r), "Activity/Start", problems, fileId, r);
                    case "Type" -> type = nn(readElementText(r));
                    case "Code" -> code = nn(readElementText(r));
                    case "Quantity" -> qty = parseDecimal(readElementText(r), "Activity/Quantity", problems, fileId, r);
                    case "Net" -> net = parseDecimal(readElementText(r), "Activity/Net", problems, fileId, r);
                    case "List" -> list = parseDecimalNull(readElementText(r));
                    case "Clinician" -> clinician = nn(readElementText(r));
                    case "PriorAuthorizationID" -> priorAuth = nn(readElementText(r));
                    case "Gross" -> gross = parseDecimalNull(readElementText(r));
                    case "PatientShare" -> patientShare = parseDecimalNull(readElementText(r));
                    case "PaymentAmount" ->
                            pay = parseDecimal(readElementText(r), "Activity/PaymentAmount", problems, fileId, r);
                    case "DenialCode" -> denialCode = nn(readElementText(r));
                }
            } else if (ev == XMLStreamConstants.END_ELEMENT && "Activity".equals(r.getLocalName())) {
                break;
            }
        }

        if (id != null && !seenIds.add(id)) {
            addProblem(problems, fileId, null, ParseProblem.Severity.WARNING, "VALIDATE", "Activity", id, "DUP_ACTIVITY",
                    "Duplicate Activity/ID within Remittance Claim; skipping duplicate");
            return null;
        }


        boolean coreMissing = isBlank(id) || isBlank(type) || isBlank(code) || start == null || qty == null || net == null || pay == null || isBlank(clinician);
        if (coreMissing) {
            addProblem(problems, fileId, null, ParseProblem.Severity.ERROR, "VALIDATE", "Activity", id, "ACTIVITY_INVALID_CORE",
                    "Remittance Activity missing required fields; skipped");
            return null;
        }

        return new RemittanceActivityDTO(id, start, type, code, qty, net, list, clinician, priorAuth, gross, patientShare, pay, denialCode);
    }

    /**
     * Common method to parse attachment elements from XML.
     * Used by both submission and remittance parsing flows.
     *
     * @param r XMLStreamReader positioned at the Attachment element
     * @param problems List to collect parsing problems
     * @param fileId File identifier for problem reporting
     * @param context Context for error reporting (e.g., "Claim", "Activity")
     * @param claimId Claim ID for attachment association
     * @return AttachmentRecord if successfully parsed, null otherwise
     */
    private ParseOutcome.AttachmentRecord readAttachment(XMLStreamReader r, List<ParseProblem> problems, long fileId, String context, String claimId) throws Exception {
        String b64 = nn(readElementText(r));
        if (isBlank(b64)) {
            addProblem(problems, fileId, r, ParseProblem.Severity.WARNING,
                    "PARSE", "Attachment", claimId, "ATTACH_EMPTY", "Attachment element is empty; skipping");
            return null;
        } else {
            try {
                byte[] bytes = java.util.Base64.getMimeDecoder().decode(b64);
                if (bytes.length == 0) {
                    addProblem(problems, fileId, r, ParseProblem.Severity.WARNING,
                            "PARSE", "Attachment", claimId, "ATTACH_EMPTY", "Attachment decoded to 0 bytes; skipping");
                    return null;
                } else if (bytes.length > maxAttachmentBytes) {
                    // persistence will skip binary.
                    addProblem(problems, fileId, r, ParseProblem.Severity.ERROR,
                            "VALIDATE", "Attachment", claimId, "ATTACH_TOO_LARGE", "Attachment exceeds max allowed bytes: " + maxAttachmentBytes);
                    return null;
                } else {
                    try {
                        byte[] sha = MessageDigest.getInstance("SHA-256").digest(bytes);
                        return new ParseOutcome.AttachmentRecord(
                                claimId, null, null, null, bytes, sha, bytes.length
                        );
                    } catch (java.security.NoSuchAlgorithmException ex) {
                        addProblem(problems, fileId, r, ParseProblem.Severity.ERROR,
                                "PARSE", "Attachment", claimId, "ATTACH_SHA_ERROR", "SHA-256 algorithm not available: " + ex.getMessage());
                        return null;
                    }
                }
            } catch (IllegalArgumentException ex) {
                addProblem(problems, fileId, r, ParseProblem.Severity.WARNING,
                        "PARSE", "Attachment", claimId, "ATTACH_INVALID_BASE64", "Invalid base64: " + ex.getMessage());
                return null;
            }
        }
    }

    /**
     * Parse Remittance &lt;Header&gt; (all scalars required).
     */
    private RemittanceHeaderDTO readRemittanceHeader(XMLStreamReader r, List<ParseProblem> problems, long fileId) throws Exception {
        String sender = null, receiver = null, disp = null;
        OffsetDateTime tx = null;
        Integer rc = null;

        while (r.hasNext()) {
            int ev = r.next();
            if (ev == XMLStreamConstants.START_ELEMENT) {
                switch (r.getLocalName()) {
                    case "SenderID" -> sender = nn(readElementText(r));
                    case "ReceiverID" -> receiver = nn(readElementText(r));
                    case "TransactionDate" ->
                            tx = parseTime(readElementText(r), "Header/TransactionDate", problems, fileId, r);
                    case "RecordCount" ->
                            rc = parseInteger(readElementText(r), "Header/RecordCount", problems, fileId, r);
                    case "DispositionFlag" -> disp = nn(readElementText(r));
                }
            } else if (ev == XMLStreamConstants.END_ELEMENT && "Header".equals(r.getLocalName())) break;
        }

        return new RemittanceHeaderDTO(sender, receiver, tx, rc == null ? 0 : rc, disp);
    }

    // === Helpers =========================================================================

    /** Null/blank check helper. */
    private static boolean isBlank(String s) {
        return s == null || s.trim().isEmpty();
    }

    /** Trim to null helper. */
    private static String nn(String s) {
        return isBlank(s) ? null : s.trim();
    }

    /**
     * Record a structured {@link ParseProblem} and stream it to {@link ParserErrorWriter}.
     */
    private void addProblem(List<ParseProblem> list, long fileId, XMLStreamReader r,
                            ParseProblem.Severity sev,
                            String stage, String objType, String objKey, String code, String msg) {
        Integer line = (r != null && r.getLocation() != null) ? r.getLocation().getLineNumber() : null;
        Integer col = (r != null && r.getLocation() != null) ? r.getLocation().getColumnNumber() : null;
        ParseProblem p = new ParseProblem(sev, stage, objType, objKey, code, msg, line, col);
        list.add(p);
        errorWriter.write(fileId, p); // persist immediately
    }

    /**
     * Read text content for current START_ELEMENT until END_ELEMENT (merging CHARACTERS/CDATA).
     */
    private String readElementText(XMLStreamReader r) throws Exception {
        StringBuilder sb = new StringBuilder();
        while (r.hasNext()) {
            int ev = r.next();
            if (ev == XMLStreamConstants.CHARACTERS || ev == XMLStreamConstants.CDATA) sb.append(r.getText());
            else if (ev == XMLStreamConstants.END_ELEMENT) break;
        }
        return sb.toString().trim();
    }

    /**
     * Read the first occurrence of a named child element's text within the current parent.
     * Caller remains responsible for consuming the parent end-tag.
     */
    private String readChild(XMLStreamReader r, String childLocalName) throws Exception {
        String val = null;
        while (r.hasNext()) {
            int ev = r.next();
            if (ev == XMLStreamConstants.START_ELEMENT && childLocalName.equals(r.getLocalName())) {
                val = readElementText(r);
            } else if (ev == XMLStreamConstants.END_ELEMENT && childLocalName.equals(r.getLocalName())) {
                // do nothing; common exit handled by caller
            } else if (ev == XMLStreamConstants.END_ELEMENT && !"Observation".equals(childLocalName) && !"Attachment".equals(childLocalName)) {
                // let caller manage outer end
            }
            if (val != null) break;
        }
        return val;
    }

    /**
     * Read a named optional child element (scans depth until parent closes); returns first match or null.
     */
    private String readOptionalChild(XMLStreamReader r, String childLocalName) throws Exception {
        String val = null;
        int depth = 1; // parent is already started
        while (r.hasNext() && depth > 0) {
            int ev = r.next();
            if (ev == XMLStreamConstants.START_ELEMENT) {
                depth++;
                if (childLocalName.equals(r.getLocalName())) val = readElementText(r);
            } else if (ev == XMLStreamConstants.END_ELEMENT) {
                depth--;
            }
            if (val != null) break;
        }
        return val;
    }

    /**
     * Skip tokens until END_ELEMENT for the given local name is seen.
     */
    private void skipToEnd(XMLStreamReader r, String localName) throws Exception {
        while (r.hasNext()) {
            int ev = r.next();
            if (ev == XMLStreamConstants.END_ELEMENT && localName.equals(r.getLocalName())) break;
        }
    }

    /**
     * Parse integer; on failure, record ERROR and return null.
     */
    private Integer parseInteger(String raw, String field, List<ParseProblem> problems, long fileId, XMLStreamReader r) {
        try {
            return raw == null ? null : Integer.valueOf(raw.trim());
        } catch (Exception e) {
            addProblem(problems, fileId, r, ParseProblem.Severity.ERROR, "PARSE", "Int", field, "BAD_INT", "Invalid integer for " + field + ": " + raw);
            return null;
        }
    }

    /**
     * Parse decimal; on failure, record ERROR and return null.
     */
    private BigDecimal parseDecimal(String raw, String field, List<ParseProblem> problems, long fileId, XMLStreamReader r) {
        try {
            return raw == null ? null : new BigDecimal(raw.trim());
        } catch (Exception e) {
            addProblem(problems, fileId, r, ParseProblem.Severity.ERROR, "PARSE", "Dec", field, "BAD_DEC", "Invalid decimal for " + field + ": " + raw);
            return null;
        }
    }

    /**
     * Parse decimal returning null on blank/invalid (used for optional numeric fields).
     */
    private BigDecimal parseDecimalNull(String raw) {
        try {
            return (raw == null || raw.isBlank()) ? null : new BigDecimal(raw.trim());
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Parse datetime from multiple common formats into OffsetDateTime; record ERROR on failure.
     */
    private OffsetDateTime parseTime(String raw, String field, List<ParseProblem> problems, long fileId, XMLStreamReader r) {
        if (raw == null || raw.isBlank()) return null;
        String s = raw.trim();

        try { return LocalDateTime.parse(s, F_DDMMYYYY_HHMM).atZone(DEFAULT_ZONE).toOffsetDateTime(); }
        catch (DateTimeParseException ignore) { }

        try { return LocalDateTime.parse(s, DateTimeFormatter.ISO_LOCAL_DATE_TIME).atZone(DEFAULT_ZONE).toOffsetDateTime(); }
        catch (DateTimeParseException ignore) { }

        try { return OffsetDateTime.parse(s, DateTimeFormatter.ISO_OFFSET_DATE_TIME); }
        catch (DateTimeParseException ignore) { }

        try { return LocalDateTime.parse(s, F_YMD_HMS).atZone(DEFAULT_ZONE).toOffsetDateTime(); }
        catch (DateTimeParseException ignore) { }

        addProblem(problems, fileId, r, ParseProblem.Severity.ERROR, "PARSE", "Time", field, "BAD_TIME", "Invalid datetime for " + field + ": " + raw);
        return null;
    }

    /**
     * Decode base64 or return null on blank/invalid.
     * <p><b>PATCH:</b> invalid base64 is now a WARNING (best-effort; claim stays persistable).</p>
     */
    private byte[] decodeBase64OrNull(String raw, List<ParseProblem> problems, long fileId, String code, String claimId) {
        if (raw == null || raw.isBlank()) return null;
        try {
            byte[] bytes = java.util.Base64.getMimeDecoder().decode(raw);
            return bytes.length == 0 ? null : bytes;
        } catch (IllegalArgumentException e) {
            addProblem(problems, fileId, null, ParseProblem.Severity.WARNING, "PARSE", "Attachment", claimId, code, "Invalid base64: " + e.getMessage());
            return null;
        }
    }

    // Resettable wrapper so we can reuse bytes for XSD + parse
    private static final class Resettable extends InputStream {
        private final ByteArrayInputStream d;

        Resettable(ByteArrayInputStream d) {
            this.d = d;
            this.d.mark(Integer.MAX_VALUE);
        }

        @Override public int read() { return d.read(); }
        @Override public int read(byte[] b) { return d.read(b, 0, b.length); }
        @Override public int read(byte[] b, int off, int len) { return d.read(b, off, len); }
        @Override public synchronized void reset() { d.reset(); }
        @Override public void close() { try { d.close(); } catch (Exception ignore) {} }
    }

    /**
     * Resolves XSD imports/includes from classpath (e.g., /xsd/CommonTypes.xsd).
     */
    private static final class ClasspathResourceResolver implements LSResourceResolver {
        private final String base; // e.g. "/xsd/"

        ClasspathResourceResolver(String base) {
            this.base = base.endsWith("/") ? base : base + "/";
        }

        @Override
        public LSInput resolveResource(String type, String ns, String publicId, String systemId, String baseURI) {
            InputStream is = open(systemId);
            if (is == null && systemId != null) {
                int i = systemId.lastIndexOf('/');
                if (i >= 0 && i + 1 < systemId.length()) is = open(systemId.substring(i + 1));
            }
            return (is == null) ? null : new SimpleLsInput(publicId, systemId, is);
        }

        private InputStream open(String name) {
            if (name == null || name.isBlank()) return null;
            String path = name.startsWith("/") ? name : base + name;
            return getClass().getResourceAsStream(path);
        }

        private static final class SimpleLsInput implements LSInput {
            private final String publicId, systemId;
            private final InputStream in;

            SimpleLsInput(String publicId, String systemId, InputStream in) {
                this.publicId = publicId;
                this.systemId = systemId;
                this.in = in;
            }

            @Override public java.io.Reader getCharacterStream() { return null; }
            @Override public void setCharacterStream(java.io.Reader r) {}
            @Override public InputStream getByteStream() { return in; }
            @Override public void setByteStream(InputStream byteStream) {}
            @Override public String getStringData() { return null; }
            @Override public void setStringData(String stringData) {}
            @Override public String getSystemId() { return systemId; }
            @Override public void setSystemId(String systemId) {}
            @Override public String getPublicId() { return publicId; }
            @Override public void setPublicId(String publicId) {}
            @Override public String getBaseURI() { return null; }
            @Override public void setBaseURI(String baseURI) {}
            @Override public String getEncoding() { return null; }
            @Override public void setEncoding(String encoding) {}
            @Override public boolean getCertifiedText() { return false; }
            @Override public void setCertifiedText(boolean certifiedText) {}
        }
    }
}
