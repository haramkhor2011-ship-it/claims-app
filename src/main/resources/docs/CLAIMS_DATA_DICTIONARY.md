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
  - transaction_date (TX): **Business transaction time from XML header** - Single Source of Truth for all tx_at columns.
  - record_count_declared: Header claim count expected in the file.
  - disposition_flag: Header disposition (informational).
  - xml_bytes (SSOT): Raw XML persisted for audit/replay.
  - created_at, updated_at: **Audit timestamps** - When file was processed by system.

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
  - created_at: **Business transaction time from XML header** (populated via PersistService.upsertClaimKey).
  - updated_at: **Business transaction time from XML header** (populated via PersistService.upsertClaimKey).

- claims.submission
  - id (PK): One submission row per ingested submission file.
  - ingestion_file_id (FK): Source file for this group.
  - tx_at (TX): **Business transaction time from XML header** (via trigger: set_submission_tx_at).
  - created_at, updated_at: **Audit timestamps** - When submission was processed by system.

- claims.remittance
  - id (PK): One remittance row per ingested remittance file.
  - ingestion_file_id (FK): Source file for this group.
  - tx_at (TX): **Business transaction time from XML header** (via trigger: set_remittance_tx_at).
  - created_at, updated_at: **Audit timestamps** - When remittance was processed by system.

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
  - tx_at (TX): **Business transaction time from XML header** (via trigger: set_claim_tx_at).
  - created_at, updated_at: **Audit timestamps** - When claim was processed by system.

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
  - denial_code: **Claim-level denial code from remittance advice (optional)** - indicates entire claim denial vs activity-level denials.
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

### Denial Code Distinction

**Claim-Level Denial** (`remittance_claim.denial_code`):
- **Purpose**: Entire claim is denied/rejected
- **Scope**: Affects all activities in the claim
- **Example**: "Invalid member ID", "Provider not credentialed"
- **XML Source**: `<Claim><DenialCode>` element
- **Usage**: Claim-level rejection analysis, member/provider issues

**Activity-Level Denial** (`remittance_activity.denial_code`):
- **Purpose**: Specific activity within claim is denied
- **Scope**: Affects only that specific activity
- **Example**: "Procedure not covered", "Prior authorization required"
- **XML Source**: `<Activity><DenialCode>` element
- **Usage**: Activity-level rejection analysis, partial payments, clinician performance

**Important**: Existing reports use activity-level denials. Claim-level denials are for new functionality requiring entire claim rejection analysis.

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
  - status_time: **Business transaction time from XML header** (populated via PersistService.insertStatusTimeline).
  - claim_event_id (FK): Event producing this status.
  - created_at: **Audit timestamp** - When status timeline entry was created by system.

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

### Payer ID Field Mapping and Consistency

#### **Critical Understanding: Payer ID Fields**
- **`claims.claim.payer_id`**: Real payer code from submission claim (business payer identifier)
- **`claims.remittance_claim.id_payer`**: Real payer code from remittance claim - **This should match `claims.claim.payer_id`**
- **`claims.claim.id_payer`**: Claim header IDPayer (different field, not the main payer code)

#### **Correct Payer Matching Logic**
When looking for the same payer across submission and remittance:
```sql
-- CORRECT: Match submission and remittance payers
COALESCE(rc.id_payer, c.payer_id, 'Unknown') as payer_id

-- INCORRECT: Using wrong submission field
COALESCE(rc.id_payer, c.id_payer, 'Unknown') as payer_id  -- ❌ Wrong field mapping
```

#### **Materialized View Payer ID Usage Patterns**
**✅ Correct Usage (Consistent)**:
- `mv_remittance_advice_summary`: Uses `rc.id_payer` (remittance level)
- `mv_doctor_denial_summary`: Uses `rc.id_payer` (remittance level)  
- `mv_balance_amount_summary`: Uses `c.payer_id` (submission level)
- `mv_claims_monthly_agg`: Uses `c.payer_id` (submission level)

**⚠️ Inconsistent Usage (Needs Review)**:
- `mv_rejected_claims_summary`: Uses `c.id_payer` (should use `c.payer_id`)
- `mv_claim_summary_payerwise`: Uses `COALESCE(rc.id_payer, c.id_payer, 'Unknown')` (should use `c.payer_id`)
- `mv_claim_summary_encounterwise`: Uses `COALESCE(rc.id_payer, c.id_payer, 'Unknown')` (should use `c.payer_id`)

#### **Best Practice for Payer ID in MVs**
1. **For remittance-focused reports**: Use `rc.id_payer` (remittance level)
2. **For submission-focused reports**: Use `c.payer_id` (submission level)  
3. **For comprehensive reports**: Use `COALESCE(rc.id_payer, c.payer_id, 'Unknown')` (prefer remittance, fallback to submission)
4. **Never use**: `c.id_payer` - this is a different field (claim header IDPayer)

### Transaction Date Handling (TX vs Audit Timestamps)

#### **Business Transaction Time (TX) - From XML Headers**
**Source**: `file.header().transactionDate()` from parsed XML files
**Storage**: `claims.ingestion_file.transaction_date` (Single Source of Truth)
**Purpose**: Represents when the business transaction actually occurred

**Tables with TX timestamps**:
- `claims.submission.tx_at` ← `ingestion_file.transaction_date` (via trigger)
- `claims.remittance.tx_at` ← `ingestion_file.transaction_date` (via trigger)  
- `claims.claim.tx_at` ← `submission.tx_at` (via trigger)
- `claims.claim_key.created_at/updated_at` ← `file.header().transactionDate()` (via PersistService)
- `claims.claim_status_timeline.status_time` ← `file.header().transactionDate()` (via PersistService)

#### **System Audit Timestamps - From Database Operations**
**Source**: `NOW()` function during database operations
**Purpose**: Tracks when records were created/modified in the database

**Tables with audit timestamps**:
- All tables have `created_at` (when record was inserted)
- Most tables have `updated_at` (when record was last modified)

#### **Materialized View Usage Analysis**
**✅ Correct Usage**: MVs primarily use `tx_at` columns for business reporting:
- `c.tx_at` for claim transaction dates
- `s.tx_at` for submission dates  
- `r.tx_at` for remittance dates
- `cst.status_time` for status timeline dates

**⚠️ Fallback Usage**: Some MVs use `ck.created_at` as fallback when `tx_at` is NULL:
```sql
DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at, ck.created_at, CURRENT_DATE))
```

#### **Key Principles**
1. **Business Reporting**: Always use `tx_at` columns for period filters and business logic
2. **System Monitoring**: Use `created_at`/`updated_at` for operational monitoring
3. **Consistency**: All `tx_at` columns contain the same transaction date from XML
4. **Fallback Strategy**: Use audit timestamps only when business timestamps are unavailable

### Testing tips for report SQLs

- Use claim spine to avoid duplication: aggregate at `claim_key` when combining submission and remittance.
- Respect TX windows:
  - Use `submission.tx_at` and `remittance.tx_at` for period filters.
  - For event-based snapshots, use `claim_event.event_time`.
  - **Always prefer `tx_at` over `created_at` for business reporting**.
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

### Materialized View Design Patterns (MV Fixes - 2025)

#### Claim Lifecycle Understanding
- **Pattern**: Submission → Remittance → Resubmission → Remittance (can repeat multiple times)
- **Activities**: Remain consistent across submission, resubmission, and remittances
- **Snapshots**: `claim_event_activity` stores activity snapshots at event time for accurate historical reporting
- **Aggregation Principle**: Aggregate all remittances per claim in every report to prevent duplicates

#### Common Duplicate Issues in MVs
1. **Multiple JOINs to same table**: e.g., 5 resubmission cycles, 5 remittance cycles creating Cartesian products
2. **Multiple secondary diagnoses**: One claim can have multiple secondary diagnoses causing row multiplication
3. **Redundant JOINs**: Extra `LEFT JOIN claims.remittance_claim` when already aggregated
4. **Unaggregated remittance data**: Multiple remittance records per claim causing duplicate rows

#### MV Fix Patterns Applied

**Remittance Aggregation Pattern**:
```sql
remittance_aggregated AS (
    SELECT 
        rc.claim_key_id,
        SUM(rc.payment_amount) as total_payment_amount,
        MAX(rc.date_settlement) as latest_settlement_date,
        COUNT(*) as remittance_count
    FROM claims.remittance_claim rc
    GROUP BY rc.claim_key_id
)
```

**Diagnosis Aggregation Pattern**:
```sql
diag_agg AS (
    SELECT 
        c.id as claim_id,
        MAX(CASE WHEN d.diag_type = 'Principal' THEN d.code END) as primary_diagnosis,
        STRING_AGG(CASE WHEN d.diag_type = 'Secondary' THEN d.code END, ', ' ORDER BY d.code) as secondary_diagnosis
    FROM claims.claim c
    LEFT JOIN claims.diagnosis d ON c.id = d.claim_id
    GROUP BY c.id
)
```

**Cycle Aggregation Pattern**:
```sql
resubmission_cycles_aggregated AS (
    SELECT 
        ce.claim_key_id,
        (ARRAY_AGG(cr.resubmission_type ORDER BY ce.event_time))[1] as first_resubmission_type,
        (ARRAY_AGG(ce.event_time ORDER BY ce.event_time))[1] as first_resubmission_date,
        (ARRAY_AGG(cr.resubmission_type ORDER BY ce.event_time))[2] as second_resubmission_type,
        (ARRAY_AGG(ce.event_time ORDER BY ce.event_time))[2] as second_resubmission_date,
        -- ... up to 5 cycles
    FROM claims.claim_event ce
    LEFT JOIN claims.claim_resubmission cr ON ce.id = cr.claim_event_id
    WHERE ce.type = 2
    GROUP BY ce.claim_key_id
)
```

#### MV Refresh Best Practices
- **Use CONCURRENTLY**: `REFRESH MATERIALIZED VIEW CONCURRENTLY` for non-blocking updates
- **Requires unique index**: Each MV needs a unique index for concurrent refresh
- **Pre-aggregate in CTEs**: Use Common Table Expressions to aggregate data before main JOINs
- **Avoid Cartesian products**: Always aggregate one-to-many relationships before joining
- **Test with diagnostics**: Use diagnostic queries to identify duplicate key violations

#### Error Patterns to Watch
- `ERROR: duplicate key value violates unique constraint` - Indicates MV query produces duplicates
- `ERROR: could not create unique index` - MV definition has logical flaws causing row multiplication
- Ambiguous column references in CTEs - Multiple CTEs defining same column names
- Cartesian products from multiple JOINs - Use aggregation CTEs to prevent

#### Success Criteria for MVs
- All MVs refresh without duplicate key errors
- MVs return expected row counts matching business logic
- Claim lifecycle properly represented with correct aggregation
- Performance maintained through proper pre-aggregation
- Unique indexes can be created successfully for concurrent refresh

---

Owner: Claims Team • Last updated: autogenerated from DDL and code (Pipeline/Parser/Persist) + MV fixes analysis (2025).


