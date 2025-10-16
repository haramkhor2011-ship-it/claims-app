## Run Discrepancies Report (2025-10-15)

### Scope
- Source log: `opConsole.txt`
- Window: 2025-10-15 23:04:39 to 23:08:41 (approx. based on snippets)

### High-Severity

- Data integrity errors while auditing already-processed files (null header_sender_id)
  - Impact: Audit trail incomplete; database exceptions per file re-check; potential retry storms.
  - Evidence:
```1996:2000:opConsole.txt
2025-10-15 23:08:35.454 [ingest-1] ERROR [...] c.a.c.ingestion.audit.IngestionAudit - Failed to audit file already processed: runId=653, fileId=3088
org.springframework.dao.DataIntegrityViolationException: ...
]; ERROR: null value in column "header_sender_id" of relation "ingestion_file_audit" violates not-null constraint
  Detail: Failing row contains (..., ALREADY, null, ...)
```
```2091:2095:opConsole.txt
2025-10-15 23:08:35.940 [ingest-5] ERROR [...] IngestionAudit - Failed to audit file already processed: runId=654, fileId=3086
org.springframework.dao.DataIntegrityViolationException: ...
]; ERROR: null value in column "header_sender_id" ... violates not-null constraint
```
  - Likely cause: Audit insert for reason 'ALREADY' omits header fields; schema enforces NOT NULL for `header_sender_id`.
  - Recommendation: Populate header fields for ALREADY status (from existing ingestion_file header) or relax NOT NULL for audit-only columns; add defensive null checks.

### Medium-Severity

- DB monitoring queries failing (pg_stat_statements not enabled)
  - Impact: Monitoring gaps; NPEs in health checks.
  - Evidence:
```36:41:opConsole.txt
2025-10-15 23:05:08.843 [main] WARN  ... DatabaseMonitoringService - Failed to collect query performance metrics (pg_stat_statements may not be enabled)
org.springframework.jdbc.BadSqlGrammarException: ... FROM pg_stat_statements ...
```
```108:110:opConsole.txt
Caused by: org.postgresql.util.PSQLException: ERROR: relation "pg_stat_statements" does not exist
```
  - Recommendation: Enable `pg_stat_statements` in Postgres (shared_preload_libraries), create extension, or feature-flag/skip gracefully when unavailable; guard against nulls to avoid NPEs in health metrics aggregation.

- DB monitoring query uses non-existent column `tablename` in `pg_stat_user_tables`
  - Impact: Table stats not collected.
  - Evidence:
```149:151:opConsole.txt
Caused by: org.postgresql.util.PSQLException: ERROR: column "tablename" does not exist
```
  - Recommendation: Replace with correct column (e.g., `relname`) or query `information_schema.tables` appropriately; adjust mappings accordingly.

### Operational Warnings

- Orchestrator queue saturation
  - Impact: Backpressure; items dequeued while queue at capacity (size=512).
  - Evidence:
```1612:1613:opConsole.txt
WARN  ... Orchestrator - ORCHESTRATOR_QUEUE_FULL fileId=... queueSize=512 capacity=0
```
  - Recommendation: Increase worker capacity, tune queue limits, or throttle fetchers.

- SOAP acknowledgements skipped due to facility not found
  - Impact: No ACK to source for some files.
  - Evidence:
```2681:2683:opConsole.txt
WARN  ... SoapAckerAdapter - SOAP_ACK_SKIPPED ... reason=FACILITY_NOT_FOUND
```
  - Recommendation: Ensure facility reference data loaded; add retry with refdata re-sync; alert on misses.

- Flexible XSD validation warnings (non-standard element order)
  - Impact: Parser tolerates out-of-order `Comments/Attachment`; may mask upstream schema drift.
  - Evidence:
```5615:5617:opConsole.txt
WARN  ... ClaimXmlParserStax - Flexible XSD validation: Allowing Comments/Attachment in non-standard position for fileId: 3120
```
  - Recommendation: Track count; consider strict mode in UAT to push partners to fix ordering.

- Ingestion verification found missing `claim_event` rows after submission persisted
  - Impact: Partial persistence; downstream reporting may miss events.
  - Evidence:
```6013:6014:opConsole.txt
INFO  ... submission persisted
WARN  ... VerifyService - Verify: no claim_event rows for ingestion_file_id=6921
```
  - Recommendation: Investigate `claim_event` upsert failure path; add transactional boundary and error surfacing; retry or dead-letter handling.

### Immediate Actions
- Fix audit insert for ALREADY files to include `header_sender_id` (or relax constraint for audit-only records).
- Add null guards in `DatabaseMonitoringService` and handle absent `pg_stat_statements` gracefully.
- Correct table stats SQL (`relname` vs `tablename`).
- Validate refdata presence before ACK; add metrics and alerting.
- Assess orchestrator worker/queue sizing; enable backpressure-aware fetch throttling.
- Investigate `claim_event` insertion failure path and ensure consistency checks.

### Notes
- Evidence snippets reference `opConsole.txt` line ranges for quick lookup.

