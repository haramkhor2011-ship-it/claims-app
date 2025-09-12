Code: DUP_SUBMISSION_NO_RESUB
Stage: VALIDATE
Object: CLAIM
When: A claim appears again in Claim.Submission without <Resubmission>.
Action: Skip claim; file continues. No ACK for file if any hard failure occurs.
Ops Resolution: Verify if resend was accidental; request remitter to include <Resubmission> if intended.
Logged Fields: ingestion_file_id, claim_id (object_key), message.

Code: PARSE_DATE_INVALID
Stage: PARSE
Object: CLAIM or ACTIVITY
When: Date value not parseable (DHPO/ISO variants supported).
Action: Log error with claim/activity id; skip offending node; continue file if safe.
