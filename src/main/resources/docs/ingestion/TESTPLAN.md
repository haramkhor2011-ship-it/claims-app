# Claims App — Ingestion & Remittance **TEST PLAN**
Version: 1.0 • Date: 2025-09-07 02:16 UTC+05:30 • Owner: Claims Engineering (Ingestion) • SUT: Java 21 + Spring Boot 3.x + PostgreSQL 15+

> Covers: Fetcher → Parser (StAX) → DTO → Validate → Mapper → Persist → Events/Timeline → Verify → Audit → (optional) ACK  
> Roots: **Claim.Submission**, **Remittance.Advice**. Profiles: `ingestion` (`localfs`|`soap`), `api`, `adminjobs`.

---

## 0. References (living docs)
- DDL & schema: `chatgpt_ddl.txt`
- Verification SQL: `claims_verify.sql`
- Strategy & Master Plan: `claims_ingestion_MASTER_plan.pdf`
- API & Deployment Blueprint: `claims_ingestion_api_blueprint.pdf`
- XSD Index for parser/mappers: `XSD Index — ClaimSubmission & RemittanceAdvice.txt`
- Decision Records (ADRs): `decision_records.pdf`
- Metrics & Admin Jobs Plan: `metrics_reports_and_api_plan.pdf`

> Keep these synced with code. If docs change, update tests accordingly.

---

## 1. Scope
**In-scope**
- Ingestion worker (all stages), idempotency, partial failure isolation
- XML parse/validate for both roots (Submission, Remittance)
- Persistence (JDBC/JPA) with uniqueness keys enforcing exactly-once semantics
- Events + Claim Status Timeline projection
- Per-file verification gating for ACK
- Nightly verification exports (cron or `adminjobs` profile)
- Security roles for DB access (RW/RO) and Admin API JWT guards
- Config toggles & profiles behavior

**Out-of-scope (v1)**
- Business UI/Portals, Analytics UI
- External BI dashboards beyond CSV exports
- Full multi-tenant RLS policies (planned later)
- Data warehouse export/archival pipelines

---

## 2. Test Environments & Config
### 2.1 Environments
- **DEV (Local):** Single node app + single Postgres. Profiles: `ingestion,localfs` and `api` separately.
- **SIT (Server/VM):** Two processes (Ingestion Worker, API Server). Optional: `adminjobs` profile for nightly tasks.
- **(Optional) UAT:** Mirrors SIT. SOAP credentials & DHPO endpoint configured.

### 2.2 DB Roles & Users
- `claims_app_rw` (ingestion writes) mapped to `ingestor_user`
- `claims_app_ro` (read-only API/adminjobs) mapped to `report_user`
- `claims_admin` (DDL/migrations) mapped to `migrate_user`

**Checks**
- Grants: USAGE/SELECT/INSERT/UPDATE for RW; SELECT for RO; sequences usage for RW.
- No app running with `claims_admin` in any env.

### 2.3 Config Toggles (must be testable)
- `claims.ack.enabled` (default **false**)
- `claims.ingestion.concurrency.parserWorkers`
- `claims.ingestion.batch.size`
- `claims.ingestion.tx.perFile` vs `claims.ingestion.tx.perChunk`
- `claims.security.hashSensitive` (hash/obfuscate sensitive)
- **Fetcher profiles:** `localfs` vs `soap` (only one active at a time)
- **Stage-to-disk** mode (if present): `true` vs `false` behavior

---

## 3. Test Data Strategy
Prepare canonical XML sets for **both roots**:
- **MIN**: Smallest valid file (1 claim, 0 encounters, 0 observations)
- **TYPICAL**: 25–100 claims with realistic variety
- **MAX**: Large file to hit batching (≥ 5k–50k claims depending on environment)
- **MIXED**: Good + bad claims in the same file (error isolation)
- **EDGE**: Corrupt date, missing required fields, duplicate business keys, huge Observation values, unknown Observation types, base64 attachment corrupt, uncommon timezones
- **CROSS-FILE**: Duplicate `file_id`, duplicate `Claim/ID` in different files, same activities repeated via re-ingest

For Remittance:
- Claims with **positive payments** (fully paid, partially paid), **denials with zero payment**, and **missing DateSettlement**.

Artifacts:
- Expected DTO counts (per file), expected totals for persistence, and expected final statuses per claim.

---

## 4. Pre-Checks (Preconditions)
1. **DDL bootstrap** applied cleanly (all tables, indexes, triggers, views).
2. **Extensions** present: `pg_trgm`, `citext`, `pgcrypto`.
3. **Roles & grants** created and validated.
4. **LocalFS input directories** exist for `ready/` watcher (DEV).
5. **SOAP credentials** (SIT/UAT) available & masked in logs.
6. **Verification SQL** accessible for manual execution.
7. **Profiles** set per process (no dual fetchers/ackers active simultaneously).

---

## 5. Test Cases
Each test includes: **ID, Pre, Steps, Expected, Notes**.

### 5.1 Header & Record Count (Both Roots)
- **TC-HDR-001:** Valid header parses & persists to `ingestion_file` (sender/receiver/txnDate/recordCount/disposition).
- **TC-HDR-002:** RecordCount equals parsed `Claim` count — mismatch triggers validation error, file marked FAIL, no ACK.
- **TC-HDR-003:** TransactionDate timezone normalization to UTC; event_time uses header date.

### 5.2 Submission — Required Fields & Structure
- **TC-SUB-REQ-001:** Claim with all required fields persists (`payer_id`, `provider_id`, `emirates_id_number`, `gross`, `patient_share`, `net`).
- **TC-SUB-REQ-002:** Missing any required field → claim-level validation error; other claims in file still persist.
- **TC-SUB-ENC-001:** Encounter requireds when present (`facility_id`, `type`, `patient_id`, `start`).
- **TC-SUB-DX-001:** Diagnosis requireds when present (`type`, `code`).
- **TC-SUB-ACT-001:** Activity requireds (ID, Start, Type, Code, Quantity, Net, Clinician).
- **TC-SUB-OBS-001:** Observation dedupe: identical `(activity_id, type, code, md5(value))` is ignored by unique index.
- **TC-SUB-RES-001:** Resubmission present → create RESUBMISSION event + `claim_resubmission` row; attachment base64 decoded to `claim_attachment` (corrupt → logged & skipped only).

### 5.3 Remittance — Requireds & Payments
- **TC-REM-REQ-001:** Claim requireds (`ID`, `IDPayer`, `PaymentReference`) persist; optional fields tolerated.
- **TC-REM-ACT-001:** Activity requireds including `PaymentAmount` persist; duplicates by `(remittance_claim_id, activity_id)` are ignored.
- **TC-REM-FAC-001:** Optional `Encounter/FacilityID` stored on `remittance_claim.facility_id`.

### 5.4 Idempotency & Uniqueness
- **TC-UNIQ-001:** Re-ingest same `file_id` → ingestion_file unique prevents duplicates; file marked ALREADY.
- **TC-UNIQ-002:** Duplicate `(submission_id, claim_id)`/`(claim_id, activity_id)` ignored (no second row) — conflicts counted.
- **TC-UNIQ-003:** Observation unique index prevents duplicate Observation rows.
- **TC-UNIQ-004:** Remittance pairs `(remittance_id, claim_key_id)` and `(remittance_claim_id, activity_id)` enforce idempotency.
- **TC-UNIQ-005:** Event uniqueness `(claim_key_id, type, event_time)` and SUBMISSION one-per-claim enforced.

### 5.5 Events & Status Timeline
- **TC-EVT-001:** SUBMISSION event written with `event_time` from header.
- **TC-EVT-002:** REMITTANCE event written per remittance claim.
- **TC-STAT-001:** Status derived as:
  - **PAID** when sum(payment) == claim.net
  - **PARTIALLY_PAID** when 0 < sum(payment) < claim.net
  - **REJECTED** when denial & sum(payment) == 0
  - **UNKNOWN** otherwise
- **TC-STAT-002:** Timeline rows ordered by time; last status matches expectations.

### 5.6 Error Isolation (Mixed Files)
- **TC-ISO-001:** One bad claim does **not** fail the whole file; good claims persist.
- **TC-ISO-002:** Validation errors logged to `ingestion_error` with stage/object/context; counts shown in file audit.

### 5.7 Verify & ACK Gating
- **TC-VER-001:** Post-file verify passes (counts, orphans=0, uniques hold) → if `ack.enabled=true` then ACK attempted once.
- **TC-VER-002:** Verify fails → no ACK; file flagged; next poll can retry depending on error type.
- **TC-VER-003:** Nightly verify job produces CSVs (kpis, orphans, duplicates, errors_24h, events_coverage) with correct permissions and retention.

### 5.8 Scheduler & Backpressure
- **TC-SCH-001:** `@Scheduled` poller ticks from start (initialDelay=0) and can be manually kicked.
- **TC-SCH-002:** Bounded queue backpressure pauses fetcher when 75% full, resumes <50% (as implemented).
- **TC-SCH-003:** Parser workers and batch size tunables affect throughput without errors.

### 5.9 Profiles & Acker
- **TC-PROF-001:** `localfs` profile uses LocalFsFetcher & NoopAcker.
- **TC-PROF-002:** `soap` profile uses SOAP fetcher & acker; ensure **only one fetcher/acker** active.
- **TC-ACK-001:** ACK attempts only on success & when enabled; best-effort; failures logged and retried per policy.

### 5.10 Security & Roles
- **TC-SEC-001:** Ingestion uses RW user only; API uses RO only; admin downloads authorized for CLAIMS_ADMIN.
- **TC-SEC-002:** Sensitive fields (Emirates ID) hashed/masked when toggle on; not exposed in API responses (if any).

### 5.11 Stage-to-Disk vs Direct
- **TC-STAGE-001:** With stageToDisk=true, batches are persisted to temp storage before DB; crash does not lose staged data.
- **TC-STAGE-002:** With stageToDisk=false, direct path works and meets integrity guarantees.

### 5.12 Performance & Soak
- **TC-PERF-001:** Throughput baseline: 80–250 claims/sec/worker on typical payloads; tune workers/batch sizes.
- **TC-PERF-002:** DB latency/locks acceptable (< target p95); adjust batch to <= 5s commit time per chunk.
- **TC-SOAK-001:** 6–12h soak run without memory leaks or backlog runaway.
- **TC-CHAOS-001:** Inject transient DB/network failures → retries engage; no data corruption; idempotency holds.

---

## 6. Test Execution Matrices
Provide a table for each test run with **Input File**, **Profile**, **Batch/Workers**, **Result** (OK/FAIL/ALREADY), **Counts** (claims/acts/obs/events), **Verify status**, **ACK status**.

> Use the per-file shape query to summarize outputs and the verification SQL to assert integrity.

---

## 7. Acceptance Criteria Mapping
- LocalFS run persists both Submission & Remittance graphs ✅
- Events & status timeline projected ✅
- Profiles enforce only one fetcher/acker ✅
- Uniques/idempotency green; verification SQL passes ✅
- ACK OFF by default, toggle works ✅

---

## 8. Entry/Exit Criteria
**Entry**: DDL present, roles configured, environment reachable, baseline test data ready.  
**Exit**: All P0/P1 cases pass; soak stable; verification job artifacts correct; no orphan/dup reports; ACK gated correctly.

---

## 9. Artifacts & Evidence
- Logs (structured), CSV exports, DB snapshots of counts & sample rows
- `v_ingestion_kpis` dashboard screenshots for target window
- Test data XMLs and expected-output manifests checked into `/testdata`

---

## 10. Ownership & Scheduling
- Test Lead: Ingestion QA Owner
- Contributors: Parser dev, Persist dev, DB owner, Ops
- Schedule: DEV → SIT → (optional) UAT → Prod readiness review
