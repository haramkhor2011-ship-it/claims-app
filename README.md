# Claims App — README (SSOT)

> **Single Source of Truth (SSOT)** for developers, architects, and operators working on the Claims App. This file explains the system in simple but complete terms.

---

## 1. Project Overview

The **Claims App** is a healthcare claims ingestion and processing system. It ingests claim submission and remittance XML files, validates them against XSD schemas, maps them to database entities, persists them safely (idempotent design), projects claim events and timelines, verifies correctness, audits the process, and (optionally) sends acknowledgments (ACK).

**Key goals:**

* Process both **Claim.Submission** and **Remittance.Advice** XML formats.
* Ensure **idempotency**: the same file or claim cannot be processed twice.
* Capture a **full event history** (submission, resubmission, remittance) for each claim.
* Provide **status timelines** (e.g., SUBMITTED → RESUBMITTED → PAID).
* Run with flexible profiles: **localfs** (local folder), **soap** (remote fetch), **api** (REST APIs), **adminjobs** (nightly verification).
* Support **secure deployment** on both servers and cloud.

**Ingestion flow:**

```
Fetcher → Parser → DTO → Validate → Mapper → Persist → Events/Timeline → Verify → Audit → (optional) ACK
```

---

## 2. Architecture (Simple Terms)

* **Fetcher**: Collects XML files (from folder in `localfs` mode, or SOAP in `soap` mode).
* **Parser**: Reads XML stream using StAX (efficient, memory-safe). Converts data into DTO objects.
* **DTO → Validate → Mapper**: DTOs are validated against XSD rules, then mapped (via MapStruct) into database entities.
* **Persist**: Entities are inserted into PostgreSQL. Uniqueness constraints make ingestion idempotent.
* **Events & Timeline**: Each claim action (submission, resubmission, remittance) is recorded as an event. The claim status timeline is updated accordingly.
* **Verify**: Lightweight SQL checks confirm there are no duplicates, missing links, or orphan rows.
* **Audit**: File-level audit tracks parsed vs persisted counts and errors.
* **ACK**: If enabled, system sends a best-effort acknowledgment back after successful processing.

**Profiles:**

* `localfs`: Files from folder, NoopAcker.
* `soap`: Fetch via SOAP, SOAP Acker.
* `api`: REST API mode (read-only, secure).
* `adminjobs`: Nightly verification exports.

---

## 3. Database Design

**Schemas:**

* `claims` → Core ingestion and processing schema.
* `auth` → Reserved for future user/role management.

**Key Tables (simplified explanation):**

* **ingestion\_file** → One row per XML file. Stores header fields (SenderID, ReceiverID, TransactionDate, RecordCount, DispositionFlag) and the raw XML.
* **submission** → Groups all claims from one submission file.
* **claim** → Core claim details (payer, provider, member, amounts, Emirates ID).
* **encounter** → Hospital/clinic encounter details (facility, patient, start/end dates).
* **diagnosis** → Diagnosis codes for an encounter.
* **activity** → Individual procedures or services performed.
* **observation** → Extra observations for activities (de-duplicated by type/code/value hash).
* **claim\_resubmission** → Records resubmission details (type, comment, optional attachment).
* **claim\_contract** → Optional contract/package name for a claim.

**Remittance side:**

* **remittance** → Groups all remittance claims from one file.
* **remittance\_claim** → Adjudication result for a claim (denials, payments, reference IDs).
* **remittance\_activity** → Line items for adjudicated activities with payment amounts.

**Events & Timeline:**

* **claim\_event** → Event stream (submission, resubmission, remittance) tied to a claim.
* **claim\_event\_activity** → Snapshot of activity state at event time.
* **event\_observation** → Snapshot of observations at event time.
* **claim\_status\_timeline** → Derived statuses over time (SUBMITTED, RESUBMITTED, PAID, etc.).

**Monitoring & Audit:**

* **ingestion\_run** → Summary of each orchestrator run.
* **ingestion\_file\_audit** → Per-file audit: counts of parsed vs persisted claims, activities, errors.
* **ingestion\_error** → Detailed error log.
* **ingestion\_batch\_metric** → Performance metrics per batch.
* **verification\_rule / run / result** → Configurable SQL rules and their results.

**Attachments:**

* **claim\_attachment** → Stores decoded base64 attachments for resubmitted claims.

---

## 4. Database Rules & Idempotency

* **Unique keys** prevent duplicates:

    * `ingestion_file.file_id`
    * `(submission_id, claim_id)`
    * `(claim_id, activity_id)`
    * `observation (activity_id, obs_type, obs_code, md5(value_text))`
    * `(remittance_id, claim_id)`
    * `(remittance_claim_id, activity_id)`
    * `(claim_key_id, type, event_time)` for claim events.

* **Orphan checks**: Every child (claim, encounter, diagnosis, activity, observation) must have a parent.

* **Event history**: Events are append-only; no deletion.

* **Status timeline**: Derived from events, always deterministic.

---

## 5. Decision Records (ADRs)

Important design decisions (see `decision_records.pdf`):

* **Partitioning Strategy** → Only if tables exceed thresholds (100M+ rows).
* **Claim Status Timeline Projection** → Always project into `claim_status_timeline` for fast APIs.
* **Archival Policy** → Keep 18–24 months of hot data, archive older.
* **Reporting Window** → Reports must use date filters within the hot window.
* **Least-Privilege Access** → Separate roles: claims\_app\_rw, claims\_app\_ro, claims\_admin.
* **Sensitive Data Protection** → Emirates ID hashed/masked; encryption optional via pgcrypto.
* **Audit Coverage** → Events serve as audit; mutable tables use row\_updated\_at triggers.

---

## 6. XSD Mapping & DTOs

**Roots:**

* `Claim.Submission` → Incoming claims with encounters, diagnoses, activities, and optional resubmission/contract.
* `Remittance.Advice` → Payment/adjudication info tied to earlier claims.

**Common Header (in both roots):**

* SenderID, ReceiverID, TransactionDate, RecordCount, DispositionFlag.

**Submission Claim:**

* ID (canonical key), payer, provider, member ID, Emirates ID, gross/patient share/net amounts.
* Nested: Encounters (with diagnoses), Activities (with observations), Resubmission (type/comment/attachment), Contract (optional).

**Remittance Claim:**

* ID (canonical key), IDPayer, provider, denial code, payment reference, settlement date.
* Nested: Activities (with net, gross, patient share, payment amount, denial code).

**DTOs (examples):**

* `SubmissionFileDto { header, claims[] }`
* `SubmissionClaimDto { id, payerId, providerId, emiratesIdNumber, gross, patientShare, net, encounters[], activities[], resubmission?, contract? }`
* `EncounterDto { facilityId, type, patientId, start, end?, diagnoses[] }`
* `ActivityDto { id, start, type, code, quantity, net, clinician, priorAuthId?, observations[] }`
* `ObservationDto { type, code, value?, valueType? }`
* `RemittanceFileDto { header, claims[] }`
* `RemittanceClaimDto { id, idPayer, providerId?, denialCode?, paymentReference, dateSettlement?, activities[] }`
* `RemittanceActivityDto { id, start, type, code, quantity, net, gross?, patientShare?, paymentAmount, denialCode? }`

**Mapping:**

* DTOs are mapped to JPA entities using **MapStruct mappers** (`SubmissionGraphMapper`, `RemittanceGraphMapper`, `EventProjectorMapper`).
* **Observation uniqueness** enforced via DB hash index.
* **Claim key** ensured via `ClaimKeyService` (get-or-create on Claim.ID).

**Validation Rules (examples):**

* Header: All 5 fields required.
* Submission Claim: ID, PayerID, ProviderID, EmiratesID, Gross, PatientShare, Net required.
* Encounter: FacilityID, Type, PatientID, Start required.
* Activity: ID, Start, Type, Code, Quantity, Net, Clinician required.
* Remittance Claim: ID, IDPayer, PaymentReference required.
* Remittance Activity: ID, Start, Type, Code, Quantity, Net, Clinician, PaymentAmount required.

**Events Projection:**

* SUBMISSION → SUBMITTED.
* RESUBMISSION → RESUBMITTED.
* REMITTANCE + payment → PAID/PARTIALLY\_PAID.
* REMITTANCE + denial only → REJECTED.
* Else → UNKNOWN.

---

## 7. Orchestrator & Ingestion Flow

The orchestrator coordinates the full ingestion pipeline.

**Flow:**

```
Fetcher → Queue → Parser → Batcher → Persist → Verify → ACK
```

**Fetcher:**

* `LocalFsFetcher` (profile: localfs) → watches a folder for new files.
* `SoapFetcher` (profile: soap) → fetches XMLs from SOAP endpoints.
* Only **one fetcher** is active at a time.

Runtime optimizations (soap):

- Facility polling uses structured concurrency with virtual threads for parallelism.
- Per-facility download concurrency is bounded via a semaphore sized by `claims.soap.downloadConcurrency`.
- Reentrancy guards prevent overlapping scheduler runs.
- Facility credentials are decrypted once per batch and reused for all downloads.

**Queue & Backpressure:**

* A bounded queue holds `file_id` tokens.
* If the queue is full, the fetcher is paused.
* When the queue has capacity, the fetcher resumes.

**Parser:**

* Uses StAX to stream XML into DTOs (no DOM, memory efficient).
* Supports Claim.Submission and Remittance.Advice roots.

**Batcher:**

* Groups DTOs into DB insert batches (default size: 1000).
* Large files may use per-chunk transactions (<5s per commit).

**Persist:**

* Applies batches via JPA/JDBC.
* Idempotency enforced by DB unique indexes.
* Conflicts are ignored (safe replays).
* Early short-circuit in the pipeline skips validation/mapping/persist when a file is already projected.

**Verify:**

* Runs lightweight SQL checks after each file.
* If verification passes → file marked OK.
* If fails → file marked FAIL, no ACK.

**ACK:**

* Disabled by default.
* If enabled, system sends best-effort ACK after verification passes.

**Audit:**

* `ingestion_file_audit` tracks per-file counts (parsed vs persisted).
* `ingestion_run` logs poll cycle metrics.
* Errors logged into `ingestion_error` with details.

**Scaling knobs:**

* Parser workers (default 3).
* Batch size (default 1000).
* Per-file vs per-chunk transactions.
* Queue capacity.

**Failure isolation:**

* A single bad claim does not block the rest of the file.
* One bad file does not block ingestion of other files.

**Observability:**

* Metrics (Micrometer) integrated.
* Dashboard view: `claims.v_ingestion_kpis`.

---

## 8. Verification & Metrics

Verification ensures data quality and system correctness. Metrics provide visibility.

**Verification (per-file):**

* Runs immediately after file ingestion.
* Checks:

    * Parsed claim count matches header `RecordCount`.
    * No orphan rows (claims without submission, activities without claims).
    * Unique indexes hold (no duplicate claims/activities/observations/remittances).
    * Required fields are non-null.
* If verification passes → ACK may be sent (if enabled).
* If fails → File marked FAIL; errors logged in `ingestion_error`.

**Verification (nightly):**

* Full integrity checks run daily under `adminjobs` profile or via cron script.
* Exports CSV reports: KPIs, orphans, duplicates, errors, event coverage.
* Stored in `/var/claims/verify/YYYY-MM-DD/` with secure permissions.

**Admin API for Verification & Metrics:**

* `/admin/verify/file/{fileId}` → Per-file summary.
* `/admin/ingestion/requeue/{fileId}` → Requeue a file.
* `/admin/verify/nightly/trigger` → Trigger nightly verification.
* `/admin/verify/artifacts` → List verification CSV artifacts.
* RBAC roles control access (CLAIMS\_ADMIN, CLAIMS\_OPS, CLAIMS\_RO).

**Metrics Dashboard:**

* Database view `claims.v_ingestion_kpis` provides ingestion KPIs by hour.
* Example fields: files processed, claims parsed/persisted, activities parsed/persisted, errors, verified files.
* Can be visualized in Grafana/Looker Studio.

**Observability:**

* Structured logs include file ID, claim ID, error codes.
* Metrics exported via Micrometer.
* Alerts on backlog growth, duplicate failures, DB latency.

---

## 9. Deployment & Security

**Profiles:**

* `ingestion` → Full orchestrator (fetch, parse, persist, verify, audit, ack).
* `localfs` → Local folder mode (simple testing).
* `soap` → Remote SOAP fetcher/acker.
* `api` → REST API server (JWT secured, read-only DB).
* `adminjobs` → Nightly verification & metrics exports.

**Deployment Modes:**

* **Server (systemd services)**: Separate services for ingestion and API.
* **Docker Compose**: API and ingestion as containers, configurable via env vars.
* **Kubernetes**: Two deployments (claims-api, claims-ingestion) with separate scaling.

**Database Roles:**

* `claims_app_rw` → RW access (ingestion).
* `claims_app_ro` → RO access (API, adminjobs).
* `claims_admin` → DDL/migrations only.
* Separate DB users map to these roles (`ingestor_user`, `report_user`, `migrate_user`).

**Security:**

* REST API uses JWT/OAuth2 Resource Server.
* RBAC roles enforced: CLAIMS\_ADMIN, CLAIMS\_OPS, CLAIMS\_RO.
* Sensitive fields (EmiratesID) hashed or masked when toggle enabled.
* ACK disabled by default (prevent false confirmations).
* TLS termination recommended at ingress/load balancer.

**Production Checklist:**

* ACK off until system stable.
* Verification jobs green for a week before enabling ACK.
* Backups enabled (database + artifacts).
* Monitoring & alerting in place (latency, backlog, verification failures).

---

## 10. Developer Guide

**Run locally:**

* Start Postgres (with claims schema loaded via Flyway or DDL).
* Run app with profiles `ingestion,localfs`.
* Drop XML files into `data/ready/` folder.
* Check database for persisted claims.

**Switch to SOAP mode:**

* Change profile to `ingestion,soap`.
* Configure SOAP endpoint in `application.yml`.

**Enable ACK:**

* Set `claims.ack.enabled=true` in properties.
* ACK sent only when verification passes.

**Run verification manually:**

* Execute queries from `claims_verify.sql`.
* Or trigger via Admin API `/admin/verify/file/{fileId}`.

**Logs & Metrics:**

* Logs show file\_id, claim\_id, errors.
* Metrics in `claims.v_ingestion_kpis`.

**Ref codes:**

* New codes added to `ref_lookup` table.
* Cached in API for fast lookup.

---

## 11. Documentation Structure

This project uses a unified documentation approach with four comprehensive guides:

### **📚 Core Documentation**

* **[Architecture & System Design](ARCHITECTURE_AND_SYSTEM_DESIGN.md)** - Complete technical reference covering system architecture, database design, data flow, security implementation, and technical decisions.

* **[Operations & Deployment Guide](OPERATIONS_AND_DEPLOYMENT.md)** - Comprehensive operational guidance for deploying, monitoring, and maintaining the system in production environments.

* **[Development & Implementation Guide](DEVELOPMENT_AND_IMPLEMENTATION.md)** - Complete development reference covering setup, implementation patterns, testing strategies, and best practices.

* **[Troubleshooting & Analysis Guide](TROUBLESHOOTING_AND_ANALYSIS.md)** - Consolidated problem resolution reference containing all analysis reports, troubleshooting guides, and issue resolution documentation.

### **🔧 Quick Reference**

* **Docker Setup**: See [Operations & Deployment Guide](OPERATIONS_AND_DEPLOYMENT.md#docker-deployment-recommended)
* **Development Setup**: See [Development & Implementation Guide](DEVELOPMENT_AND_IMPLEMENTATION.md#development-environment-setup)
* **Security Configuration**: See [Architecture & System Design](ARCHITECTURE_AND_SYSTEM_DESIGN.md#security-architecture)
* **Performance Issues**: See [Troubleshooting & Analysis Guide](TROUBLESHOOTING_AND_ANALYSIS.md#common-issues--solutions)

### **📋 Legacy References**

* `decision_records.pdf` → ADR-001 to ADR-010 (architectural decisions)
* `claims_verify.sql` → Verification queries
* `XSD Index — ClaimSubmission & RemittanceAdvice.txt` → XSD mapping reference

---

## ✅ Documentation Philosophy

This unified documentation approach provides:

* **Single Source of Truth**: Each area has one comprehensive document
* **Targeted Content**: Each document focuses on its specific audience and use cases
* **Consolidated Knowledge**: All related information is grouped together
* **Easy Navigation**: Clear cross-references between documents
* **Maintainable**: Easier to keep documentation current and accurate

---

> This README serves as the entry point to the Claims Processing System documentation. For detailed information, refer to the specific guides linked above.
