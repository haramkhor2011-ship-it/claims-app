package com.acme.claims.ingestion.parser;


import com.acme.claims.domain.model.dto.RemittanceAdviceDTO;
import com.acme.claims.domain.model.dto.SubmissionDTO;

import java.util.List;

public final class ParseOutcome {
    public enum RootType { SUBMISSION, REMITTANCE }

    private final RootType rootType;
    private final SubmissionDTO submission;                 // non-null when SUBMISSION
    private final RemittanceAdviceDTO remittance;           // non-null when REMITTANCE
    private final List<ParseProblem> problems;
    private final List<AttachmentRecord> attachments;       // per-claim attachments (submission only)

    public ParseOutcome(RootType t, SubmissionDTO s, RemittanceAdviceDTO r,
                        List<ParseProblem> p, List<AttachmentRecord> a) {
        this.rootType = t; this.submission = s; this.remittance = r; this.problems = p; this.attachments = a;
    }

    public RootType getRootType() { return rootType; }
    public SubmissionDTO getSubmission() { return submission; }
    public RemittanceAdviceDTO getRemittance() { return remittance; }
    public List<ParseProblem> getProblems() { return problems; }
    public List<AttachmentRecord> getAttachments() { return attachments; }
    public boolean isValid() {
        return problems.stream().noneMatch(pp -> pp.severity() == ParseProblem.Severity.ERROR);
    }

    // Side-channel attachment info for PersistService
    public static record AttachmentRecord(
            String claimId, String externalId, String fileName, String contentType,
            byte[] bytes, byte[] sha256, int size
    ) {}
}
