## Claims Data Dictionary (for Report SQL Testing)

Scope: Concise, claim-oriented descriptions for tables and columns used by submissions, remittances, events/timeline, and key reference data. Includes join keys and test tips tailored for validating `src/main/resources/db/reports_sql/*.sql`.

Legend: PK=primary key, FK=foreign key, TX=transactional timestamp, SSOT=single source of truth.

### Core ingestion

- claims.ingestion_file
  - id (PK): Unique file row; parent for submission/remittance. 
  - file_id: External idempotency key; ties logs/audits to the file.
  - file_name: Original filename for traceability.
  - root_type: 1=Submission, 2=Remittance; determines parse path.
  - sender_id: Header sender; used for ops filtering.
  - receiver_id: Header receiver; used for ops filtering.
  - transaction_date (TX): Business transaction time for the file.
  - record_count_declared: Header claim count expected in the file.
  - disposition_flag: Header disposition (informational).
  - xml_bytes (SSOT): Raw XML persisted for audit/replay.
  - created_at, updated_at: Audit timestamps.

- claims.ingestion_error
  - id (PK): Unique error record.
  - ingestion_file_id (FK → ingestion_file.id): Which file encountered the error.
  - stage: Pipeline stage (e.g., PARSE, VALIDATE, PERSIST).
  - object_type: Entity type involved (e.g., Claim, Activity).
  - object_key: Business key (e.g., Claim.ID) when available.
  - error_code: Categorical code for error rollups.
  - error_message: Human-readable message.
  - stack_excerpt: Optional stack details.
  - retryable: Whether retry may succeed.
  - occurred_at: When the error happened.

### Canonical identity and grouping

- claims.claim_key
  - id (PK): Canonical claim spine; links submission and remittance.
  - claim_id: Business Claim.ID from XML.
  - created_at, updated_at: Audit timestamps.

- claims.submission
  - id (PK): One submission row per ingested submission file.
  - ingestion_file_id (FK): Source file for this group.
  - tx_at (TX): Derived from file transaction_date.
  - created_at, updated_at: Audit timestamps.

- claims.remittance
  - id (PK): One remittance row per ingested remittance file.
  - ingestion_file_id (FK): Source file for this group.
  - tx_at (TX): Derived from file transaction_date.
  - created_at, updated_at: Audit timestamps.

### Submission graph (per Claim.ID)

- claims.claim
  - id (PK): Internal claim row for a submission.
  - claim_key_id (FK → claim_key.id): Canonical link to Claim.ID.
  - submission_id (FK → submission.id): Parent submission group.
  - id_payer: Claim header IDPayer (if provided in submission).
  - member_id: Patient/member identifier.
  - payer_id: Payer code from submission claim.
  - provider_id: Provider code from submission claim.
  - emirates_id_number: Emirates ID from submission claim.
  - gross, patient_share, net: Submitted monetary amounts.
  - comments: Free-text claim comments if present.
  - payer_ref_id (FK → claims_ref.payer.id): Resolved payer master.
  - provider_ref_id (FK → claims_ref.provider.id): Resolved provider master.
  - tx_at (TX): Derived from parent submission.tx_at.
  - created_at, updated_at: Audit timestamps.

- claims.encounter
  - id (PK): Encounter record for a submission claim.
  - claim_id (FK → claim.id): Parent claim.
  - facility_id: Facility code from encounter.
  - type: Encounter type (e.g., INPATIENT/OUTPATIENT).
  - patient_id: Patient identifier in encounter.
  - start_at, end_at: Encounter time window.
  - start_type, end_type: Encounter phase types if provided.
  - transfer_source, transfer_destination: Transfer endpoints.
  - facility_ref_id (FK → claims_ref.facility.id): Resolved facility master.
  - created_at, updated_at: Audit timestamps.

- claims.diagnosis
  - id (PK): Diagnosis row for a claim.
  - claim_id (FK → claim.id): Parent claim.
  - diag_type: Diagnosis type (e.g., principal/secondary).
  - code: Diagnosis code.
  - diagnosis_code_ref_id (FK → claims_ref.diagnosis_code.id): Resolved code master.
  - created_at, updated_at: Audit timestamps.

- claims.activity
  - id (PK): Activity row under a submission claim.
  - claim_id (FK → claim.id): Parent claim.
  - activity_id: Business Activity.ID within the claim.
  - start_at: Activity start timestamp.
  - type: Activity type.
  - code: Activity code (e.g., CPT/LOCAL).
  - quantity: Quantity requested.
  - net: Net amount requested.
  - clinician: Clinician code involved.
  - prior_authorization_id: Prior auth id if any.
  - clinician_ref_id (FK → claims_ref.clinician.id): Resolved clinician master.
  - activity_code_ref_id (FK → claims_ref.activity_code.id): Resolved activity code master.
  - created_at, updated_at: Audit timestamps.

- claims.observation
  - id (PK): Observation row tied to a submission activity.
  - activity_id (FK → activity.id): Parent activity.
  - obs_type: Observation type (dictionary-backed); includes File/Text/etc.
  - obs_code: Observation code (dictionary-backed).
  - value_text: Observation value text (if non-file).
  - value_type: Value type/unit (if provided).
  - file_bytes: Binary data if obs_type=File.
  - created_at, updated_at: Audit timestamps.

- claims.claim_contract
  - id (PK): Contract record per claim.
  - claim_id (FK → claim.id): Parent claim.
  - package_name: Contract/package identifier.
  - created_at, updated_at: Audit timestamps.

- claims.claim_resubmission
  - id (PK): Links RESUBMISSION event details.
  - claim_event_id (FK → claim_event.id): The RESUBMISSION event.
  - resubmission_type: Reason/type of resubmission.
  - comment: Resubmission comment.
  - attachment: Optional binary attachment.
  - created_at, updated_at: Audit timestamps.

- claims.claim_attachment
  - id (PK): File attachment row for a claim.
  - claim_key_id (FK → claim_key.id): Which claim.
  - claim_event_id (FK → claim_event.id): Event context for attachment.
  - file_name: Attachment filename.
  - mime_type: Attachment MIME type.
  - data_base64: Attachment bytes (decoded storage).
  - data_length: Byte length for diagnostics.
  - created_at: Audit timestamp.

### Remittance graph (per Claim.ID)

- claims.remittance_claim
  - id (PK): Remittance claim row per Claim.ID per remittance file.
  - remittance_id (FK → remittance.id): Parent remittance group.
  - claim_key_id (FK → claim_key.id): Canonical link to Claim.ID.
  - id_payer: Payer code at remittance level.
  - provider_id: Provider code at remittance level.
  - denial_code: Claim-level denial code (optional).
  - payment_reference: Reference number for payment.
  - date_settlement: Payment settlement date.
  - facility_id: Encounter facility copied on remittance if provided.
  - denial_code_ref_id (FK → claims_ref.denial_code.id): Resolved denial code.
  - payer_ref_id (FK → claims_ref.payer.id): Resolved payer.
  - provider_ref_id (FK → claims_ref.provider.id): Resolved provider.
  - created_at, updated_at: Audit timestamps.

- claims.remittance_activity
  - id (PK): Activity-level adjudication row.
  - remittance_claim_id (FK → remittance_claim.id): Parent remittance claim.
  - activity_id: Business Activity.ID (matches submission activity_id).
  - start_at: Activity start (from remittance).
  - type, code: Activity meta at remittance time.
  - quantity, net: Requested quantities/amounts (remittance record).
  - list_price: Optional list price.
  - clinician, prior_authorization_id: As in remittance.
  - gross, patient_share: Optional adjudicated values.
  - payment_amount: Paid amount for this activity.
  - denial_code: Activity-level denial code.
  - created_at, updated_at: Audit timestamps.

### Events, snapshots, status

- claims.claim_event
  - id (PK): Event row for lifecycle milestones.
  - claim_key_id (FK → claim_key.id): Which claim.
  - ingestion_file_id (FK): Provenance file for this event.
  - event_time: Event business time (submission/remittance time).
  - type: 1=SUBMITTED, 2=RESUBMITTED, 3=REMITTANCE/PAID.
  - submission_id / remittance_id (FK): Optional back-links.
  - created_at: Audit timestamp.

- claims.claim_event_activity
  - id (PK): Activity snapshot captured at event time.
  - claim_event_id (FK → claim_event.id): Parent event.
  - activity_id_ref (FK → activity.id): Reference to submission activity (if known).
  - remittance_activity_id_ref (FK → remittance_activity.id): Reference to remittance activity (if known).
  - activity_id_at_event: Activity.ID at the time of event.
  - start_at_event, type_at_event, code_at_event: Activity meta snapshot.
  - quantity_at_event, net_at_event: Amounts snapshot.
  - clinician_at_event, prior_authorization_id_at_event: Clinician/meta snapshot.
  - list_price_at_event, gross_at_event, patient_share_at_event, payment_amount_at_event, denial_code_at_event: Remittance-only metrics.
  - created_at: Audit timestamp.

- claims.event_observation
  - id (PK): Observation snapshot row at event time.
  - claim_event_activity_id (FK → claim_event_activity.id): Parent snapshot activity.
  - obs_type, obs_code: Observation dictionary fields.
  - value_text, value_type: Observation values if any.
  - file_bytes: Observation binary, if present.
  - created_at: Audit timestamp.

- claims.claim_status_timeline
  - id (PK): Status timeline entry.
  - claim_key_id (FK → claim_key.id): Which claim.
  - status: 1=SUBMITTED, 2=RESUBMITTED, 3=PAID, 4=PARTIALLY_PAID, 5=REJECTED.
  - status_time: Business time for status transition.
  - claim_event_id (FK): Event producing this status.
  - created_at: Audit timestamp.

### Reference data (keys used by reports)

- claims_ref.payer
  - id (PK): Payer master row.
  - payer_code: External payer identifier (joins from claim/remittance).
  - name, status: Human label/state.
  - created_at, updated_at: Audit timestamps.

- claims_ref.provider
  - id (PK): Provider organization row.
  - provider_code: External provider identifier.
  - name, status: Human label/state.
  - created_at, updated_at: Audit timestamps.

- claims_ref.facility
  - id (PK): Facility master row.
  - facility_code: External facility identifier.
  - name, city, country, status: Facility descriptors.
  - created_at, updated_at: Audit timestamps.

- claims_ref.clinician
  - id (PK): Clinician master row.
  - clinician_code: External clinician identifier.
  - name, specialty, status: Clinician descriptors.
  - created_at, updated_at: Audit timestamps.

- claims_ref.activity_code
  - id (PK): Activity code master.
  - code, code_system: Procedure code + system (LOCAL/CPT/etc.).
  - description, status: Human label/state.
  - created_at, updated_at: Audit timestamps.

- claims_ref.diagnosis_code
  - id (PK): Diagnosis code master.
  - code, code_system: Diagnosis code + system (ICD-10/etc.).
  - description, status: Human label/state.
  - created_at, updated_at: Audit timestamps.

- claims_ref.denial_code
  - id (PK): Denial code master.
  - code: Denial code; optionally payer-scoped.
  - description: Human label.
  - payer_code: Payer context (optional).
  - created_at, updated_at: Audit timestamps.

### Joins cheat sheet (quick reference)

- Claim spine
  - Submission claim → claim_key: `claim.claim_key_id = claim_key.id`
  - Remittance claim → claim_key: `remittance_claim.claim_key_id = claim_key.id`
  - Tie submission to remittance on Claim.ID: via `claim_key`

- Submission details
  - Claim → Encounter: `encounter.claim_id = claim.id`
  - Claim → Activity: `activity.claim_id = claim.id`
  - Activity → Observation: `observation.activity_id = activity.id`
  - Claim → Diagnosis: `diagnosis.claim_id = claim.id`

- Remittance details
  - Remittance claim → Remittance activity: `remittance_activity.remittance_claim_id = remittance_claim.id`
  - Match submission activity to remittance activity: `activity.activity_id = remittance_activity.activity_id` (via same claim_key through events or by correlating on claim_key and activity_id)

- Events and timeline
  - Events for claim: `claim_event.claim_key_id = claim_key.id`
  - Event snapshots from submission: `claim_event_activity.activity_id_ref = activity.id`
  - Event snapshots from remittance: `claim_event_activity.remittance_activity_id_ref = remittance_activity.id`
  - Status history: `claim_status_timeline.claim_key_id = claim_key.id`

- Reference lookups
  - Payer (submission): `claim.payer_ref_id = claims_ref.payer.id` (fallback: `claim.payer_id = claims_ref.payer.payer_code`)
  - Provider (submission): `claim.provider_ref_id = claims_ref.provider.id` (fallback: `claim.provider_id = claims_ref.provider.provider_code`)
  - Facility (encounter): `encounter.facility_ref_id = claims_ref.facility.id` (fallback: `encounter.facility_id = claims_ref.facility.facility_code`)
  - Clinician (activity): `activity.clinician_ref_id = claims_ref.clinician.id` (fallback: `activity.clinician = claims_ref.clinician.clinician_code`)
  - Activity code: `activity.activity_code_ref_id = claims_ref.activity_code.id` (fallback: `activity.code`)
  - Diagnosis code: `diagnosis.diagnosis_code_ref_id = claims_ref.diagnosis_code.id` (fallback: `diagnosis.code`)
  - Denial code (remittance): `remittance_claim.denial_code_ref_id = claims_ref.denial_code.id` (fallback: `remittance_claim.denial_code`)

### Testing tips for report SQLs

- Use claim spine to avoid duplication: aggregate at `claim_key` when combining submission and remittance.
- Respect TX windows:
  - Use `submission.tx_at` and `remittance.tx_at` for period filters.
  - For event-based snapshots, use `claim_event.event_time`.
- Activity reconciliation:
  - Requested vs paid: sum submission `activity.net` vs remittance `remittance_activity.payment_amount` per `claim_key` and `activity_id`.
  - Handle duplicates via uniques: `(claim_id, activity_id)` and `(remittance_claim_id, activity_id)` ensure one row each.
- Encounter presence:
  - Left join `encounter` since it can be optional. Example used in reports: `LEFT JOIN claims.encounter e ON e.claim_id = c.id`.
- Denial logic:
  - Claim-level status (PAID/PARTIALLY_PAID/REJECTED) is reflected in `claim_status_timeline`. For activity breakdown, use `claim_event_activity.denial_code_at_event` or `remittance_activity.denial_code`.
- Header sanity:
  - Compare `ingestion_file.record_count_declared` with counted claims parsed/persisted for file QA.

### Minimal query examples

- Claims with encounters and activities (submission side):
  ```sql
  select ck.claim_id as claim_biz_id, c.payer_id, c.provider_id, e.facility_id,
         a.activity_id, a.code, a.quantity, a.net
  from claims.claim c
  join claims.claim_key ck on ck.id = c.claim_key_id
  left join claims.encounter e on e.claim_id = c.id
  left join claims.activity a on a.claim_id = c.id;
  ```

- Requested vs paid by activity:
  ```sql
  select ck.claim_id as claim_biz_id, a.activity_id,
         sum(a.net) as requested_net,
         sum(coalesce(ra.payment_amount,0)) as paid_amount
  from claims.claim c
  join claims.claim_key ck on ck.id = c.claim_key_id
  join claims.activity a on a.claim_id = c.id
  left join claims.remittance_claim rc on rc.claim_key_id = ck.id
  left join claims.remittance_activity ra on ra.remittance_claim_id = rc.id and ra.activity_id = a.activity_id
  group by ck.claim_id, a.activity_id;
  ```

---

Owner: Claims Team • Last updated: autogenerated from DDL and code (Pipeline/Parser/Persist).


