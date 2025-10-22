# Database Schema Context - Claims Backend Application

> Comprehensive documentation of the database schema with Java code references. This document explains the business purpose of each table, key columns, relationships, and how they map to Java entities.

## Overview

The claims-backend application uses a PostgreSQL database with a well-structured schema divided into three main schemas:

- **`claims`** - Core claims processing and business data
- **`claims_ref`** - Reference data (codes, facilities, payers, etc.)
- **`auth`** - Authentication and authorization (reserved for future use)

---

## Schema Architecture

### Database Extensions
```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;     -- Text similarity and trigram indexes
CREATE EXTENSION IF NOT EXISTS citext;      -- Case-insensitive text type
CREATE EXTENSION IF NOT EXISTS pgcrypto;    -- Cryptographic functions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements; -- Query performance monitoring
```

### Key Design Principles
- **Single Source of Truth (SSOT)** for raw XML data
- **Normalized relational model** for processed data
- **Comprehensive reference data management**
- **Event-driven audit trails**
- **Secure credential storage** with encryption

---

## Core Claims Schema (`claims`)

### 1. Raw XML Ingestion (`ingestion_file`)

**Business Purpose**: Single Source of Truth for all raw XML files received by the system.

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `file_id` - Unique file identifier (TEXT, UNIQUE)
- `file_name` - Original filename (TEXT)
- `root_type` - XML root type: 1=Submission, 2=Remittance (SMALLINT)
- `sender_id` - Sender identifier from XML header (TEXT)
- `receiver_id` - Receiver identifier from XML header (TEXT)
- `transaction_date` - Transaction date from XML header (TIMESTAMPTZ)
- `record_count_declared` - Number of records declared in header (INTEGER)
- `disposition_flag` - Disposition flag from XML header (TEXT)
- `xml_bytes` - Raw XML content (BYTEA)
- `created_at` - Record creation timestamp (TIMESTAMPTZ)
- `updated_at` - Record update timestamp (TIMESTAMPTZ)

**Java Entity**: `com.acme.claims.domain.model.entity.IngestionFile`

**Java Usage**:
```java
// Pipeline.java - File registration
@Transactional(propagation = Propagation.REQUIRES_NEW)
public Long insertStub(WorkItem wi, short rootType, byte[] xmlBytes) {
    return jdbc.queryForObject("""
        INSERT INTO claims.ingestion_file
          (file_id, file_name, root_type, sender_id, receiver_id, transaction_date,
           record_count_declared, disposition_flag, xml_bytes)
        VALUES (?, ?, ?, 'UNKNOWN', 'UNKNOWN', now(), 0, 'UNKNOWN', ?)
        ON CONFLICT (file_id) DO UPDATE SET updated_at = now()
        RETURNING id
        """, Long.class, wi.fileId(), wi.fileName(), rootType, xmlBytes);
}
```

**Important Indexes**:
- `idx_ingestion_file_root_type` - Filter by submission/remittance
- `idx_ingestion_file_sender` - Filter by sender
- `idx_ingestion_file_transaction_date` - Date range queries

**Common Queries**:
- Find files by date range for reporting
- Check for duplicate files by file_id
- Retrieve raw XML for reprocessing

---

### 2. Error Tracking (`ingestion_error`)

**Business Purpose**: Track all errors that occur during file processing for debugging and analysis.

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `ingestion_file_id` - Reference to ingestion_file (BIGINT, FK)
- `stage` - Processing stage where error occurred (TEXT)
- `object_type` - Type of object being processed (TEXT)
- `object_key` - Key of the object being processed (TEXT)
- `error_code` - Categorized error code (TEXT)
- `error_message` - Detailed error message (TEXT)
- `stack_excerpt` - Stack trace excerpt (TEXT)
- `retryable` - Whether error is retryable (BOOLEAN)
- `occurred_at` - When error occurred (TIMESTAMPTZ)

**Java Usage**:
```java
// ErrorLogger.java - Error recording
public void fileError(Long fileId, String stage, String errorCode, 
                     String message, boolean isRetryable) {
    jdbc.update("""
        INSERT INTO claims.ingestion_error 
        (ingestion_file_id, stage, error_code, error_message, retryable, occurred_at)
        VALUES (?, ?, ?, ?, ?, now())
        """, fileId, stage, errorCode, message, isRetryable);
}
```

**Important Indexes**:
- `idx_ingestion_error_file` - Find all errors for a file
- `idx_ingestion_error_stage` - Filter by processing stage
- `idx_ingestion_error_time` - Time-based error analysis

---

### 3. Canonical Claim Key (`claim_key`)

**Business Purpose**: Provides a canonical identifier for claims that appear in both submissions and remittances.

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `claim_id` - Canonical claim identifier (TEXT, UNIQUE)
- `created_at` - When claim was first seen (TIMESTAMPTZ)
- `updated_at` - When claim was last updated (TIMESTAMPTZ)

**Java Usage**:
```java
// ClaimKeyService.java - Get or create claim key
public ClaimKey getOrCreateClaimKey(String claimId) {
    return claimKeyRepository.findByClaimId(claimId)
        .orElseGet(() -> {
            ClaimKey newKey = new ClaimKey();
            newKey.setClaimId(claimId);
            return claimKeyRepository.save(newKey);
        });
}
```

**Important Indexes**:
- `idx_claim_key_claim_id` - Fast lookup by claim ID

---

### 4. Submission Processing (`submission`)

**Business Purpose**: Groups all claims from a single submission file.

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `ingestion_file_id` - Reference to ingestion_file (BIGINT, FK)
- `created_at` - Record creation timestamp (TIMESTAMPTZ)
- `updated_at` - Record update timestamp (TIMESTAMPTZ)
- `tx_at` - Transaction timestamp from XML header (TIMESTAMPTZ)

**Java Entity**: `com.acme.claims.domain.model.entity.Submission`

**Java Usage**:
```java
// PersistService.java - Submission persistence
@Transactional(propagation = Propagation.REQUIRES_NEW)
public PersistCounts persistSubmission(Long ingestionFileId, SubmissionDTO dto, List<AttachmentDto> attachments) {
    Submission submission = submissionMapper.toEntity(dto);
    submission.setIngestionFileId(ingestionFileId);
    submission = submissionRepository.save(submission);
    // ... process claims
}
```

**Important Indexes**:
- `idx_submission_file` - Find submission by file
- `idx_submission_tx_at` - Date-based queries

---

### 5. Core Claim Data (`claim`)

**Business Purpose**: Stores the core claim information from submissions.

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `claim_key_id` - Reference to claim_key (BIGINT, FK)
- `submission_id` - Reference to submission (BIGINT, FK)
- `id_payer` - Payer identifier (TEXT)
- `member_id` - Member identifier (TEXT)
- `payer_id` - Payer ID (TEXT)
- `provider_id` - Provider ID (TEXT)
- `emirates_id_number` - Emirates ID number (TEXT)
- `gross` - Gross amount (NUMERIC(14,2))
- `patient_share` - Patient share amount (NUMERIC(14,2))
- `net` - Net amount (NUMERIC(14,2))
- `comments` - Claim comments (TEXT)
- `payer_ref_id` - Reference to payer table (BIGINT)
- `provider_ref_id` - Reference to provider table (BIGINT)
- `created_at` - Record creation timestamp (TIMESTAMPTZ)
- `updated_at` - Record update timestamp (TIMESTAMPTZ)
- `tx_at` - Transaction timestamp (TIMESTAMPTZ)

**Java Entity**: `com.acme.claims.domain.model.entity.Claim`

**Java Usage**:
```java
// PersistService.java - Claim persistence
for (SubmissionClaimDto claimDto : dto.claims()) {
    Claim claim = claimMapper.toEntity(claimDto);
    claim.setSubmissionId(submission.getId());
    claim = claimRepository.save(claim);
    claimCount++;
}
```

**Important Indexes**:
- `idx_claim_claim_key` - Find claim by canonical key
- `idx_claim_payer` - Filter by payer
- `idx_claim_provider` - Filter by provider
- `idx_claim_emirates` - Filter by Emirates ID

**Constraints**:
- `uq_claim_per_key` - One claim per claim_key_id
- `uq_claim_submission_claimkey` - Unique per submission

---

### 6. Encounter Data (`encounter`)

**Business Purpose**: Stores encounter information for claims (hospital/clinic visits).

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `claim_id` - Reference to claim (BIGINT, FK)
- `facility_id` - Facility identifier (TEXT)
- `encounter_type` - Type of encounter (TEXT)
- `patient_id` - Patient identifier (TEXT)
- `start_at` - Encounter start time (TIMESTAMPTZ)
- `end_at` - Encounter end time (TIMESTAMPTZ)
- `created_at` - Record creation timestamp (TIMESTAMPTZ)
- `updated_at` - Record update timestamp (TIMESTAMPTZ)
- `tx_at` - Transaction timestamp (TIMESTAMPTZ)

**Java Entity**: `com.acme.claims.domain.model.entity.Encounter`

**Java Usage**:
```java
// PersistService.java - Encounter persistence
for (EncounterDto encounterDto : claimDto.encounters()) {
    Encounter encounter = encounterMapper.toEntity(encounterDto);
    encounter.setClaimId(claim.getId());
    encounter = encounterRepository.save(encounter);
    
    // Process diagnoses
    for (DiagnosisDto diagnosisDto : encounterDto.diagnoses()) {
        Diagnosis diagnosis = diagnosisMapper.toEntity(diagnosisDto);
        diagnosis.setEncounterId(encounter.getId());
        diagnosisRepository.save(diagnosis);
    }
}
```

**Important Indexes**:
- `idx_encounter_claim` - Find encounters by claim
- `idx_encounter_facility` - Filter by facility
- `idx_encounter_start` - Date-based queries

---

### 7. Activity Data (`activity`)

**Business Purpose**: Stores individual procedures or services performed.

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `claim_id` - Reference to claim (BIGINT, FK)
- `activity_id` - Activity identifier (TEXT)
- `start_at` - Activity start time (TIMESTAMPTZ)
- `activity_type` - Type of activity (TEXT)
- `code` - Activity code (TEXT)
- `quantity` - Quantity performed (NUMERIC(10,3))
- `net` - Net amount (NUMERIC(14,2))
- `clinician` - Clinician identifier (TEXT)
- `prior_auth_id` - Prior authorization ID (TEXT)
- `created_at` - Record creation timestamp (TIMESTAMPTZ)
- `updated_at` - Record update timestamp (TIMESTAMPTZ)
- `tx_at` - Transaction timestamp (TIMESTAMPTZ)

**Java Entity**: `com.acme.claims.domain.model.entity.Activity`

**Java Usage**:
```java
// PersistService.java - Activity persistence
for (ActivityDto activityDto : claimDto.activities()) {
    Activity activity = activityMapper.toEntity(activityDto);
    activity.setClaimId(claim.getId());
    activity = activityRepository.save(activity);
    activityCount++;
    
    // Process observations
    for (ObservationDto obsDto : activityDto.observations()) {
        Observation observation = observationMapper.toEntity(obsDto);
        observation.setActivityId(activity.getId());
        observationRepository.save(observation);
    }
}
```

**Important Indexes**:
- `idx_activity_claim` - Find activities by claim
- `idx_activity_code` - Filter by activity code
- `idx_activity_clinician` - Filter by clinician

---

### 8. Observation Data (`observation`)

**Business Purpose**: Stores additional observations for activities (de-duplicated by hash).

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `activity_id` - Reference to activity (BIGINT, FK)
- `obs_type` - Observation type (TEXT)
- `obs_code` - Observation code (TEXT)
- `value_text` - Observation value (TEXT)
- `value_type` - Value type (TEXT)
- `value_hash` - Hash of value for deduplication (TEXT)
- `created_at` - Record creation timestamp (TIMESTAMPTZ)
- `updated_at` - Record update timestamp (TIMESTAMPTZ)
- `tx_at` - Transaction timestamp (TIMESTAMPTZ)

**Java Entity**: `com.acme.claims.domain.model.entity.Observation`

**Important Indexes**:
- `idx_observation_activity` - Find observations by activity
- `idx_observation_hash` - Deduplication by hash

**Constraints**:
- `uq_observation_dedup` - Unique by activity, type, code, and hash

---

### 9. Remittance Processing (`remittance`)

**Business Purpose**: Groups all remittance claims from a single remittance file.

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `ingestion_file_id` - Reference to ingestion_file (BIGINT, FK)
- `created_at` - Record creation timestamp (TIMESTAMPTZ)
- `updated_at` - Record update timestamp (TIMESTAMPTZ)
- `tx_at` - Transaction timestamp from XML header (TIMESTAMPTZ)

**Java Entity**: `com.acme.claims.domain.model.entity.Remittance`

**Java Usage**:
```java
// PersistService.java - Remittance persistence
@Transactional(propagation = Propagation.REQUIRES_NEW)
public PersistCounts persistRemittance(Long ingestionFileId, RemittanceAdviceDTO dto, List<AttachmentDto> attachments) {
    Remittance remittance = remittanceMapper.toEntity(dto);
    remittance.setIngestionFileId(ingestionFileId);
    remittance = remittanceRepository.save(remittance);
    // ... process remittance claims
}
```

---

### 10. Remittance Claim Data (`remittance_claim`)

**Business Purpose**: Stores adjudication results for claims.

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `remittance_id` - Reference to remittance (BIGINT, FK)
- `claim_key_id` - Reference to claim_key (BIGINT, FK)
- `id_payer` - Payer identifier (TEXT)
- `provider_id` - Provider identifier (TEXT)
- `denial_code` - Denial code (TEXT)
- `payment_reference` - Payment reference (TEXT)
- `date_settlement` - Settlement date (TIMESTAMPTZ)
- `created_at` - Record creation timestamp (TIMESTAMPTZ)
- `updated_at` - Record update timestamp (TIMESTAMPTZ)
- `tx_at` - Transaction timestamp (TIMESTAMPTZ)

**Java Entity**: `com.acme.claims.domain.model.entity.RemittanceClaim`

**Important Indexes**:
- `idx_remittance_claim_remittance` - Find claims by remittance
- `idx_remittance_claim_key` - Find by claim key
- `idx_remittance_claim_payer` - Filter by payer

---

### 11. Event Tracking (`claim_event`)

**Business Purpose**: Tracks the lifecycle of claims through events.

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `claim_key_id` - Reference to claim_key (BIGINT, FK)
- `type` - Event type: 1=Submission, 2=Resubmission, 3=Remittance (SMALLINT)
- `event_time` - When event occurred (TIMESTAMPTZ)
- `created_at` - Record creation timestamp (TIMESTAMPTZ)
- `updated_at` - Record update timestamp (TIMESTAMPTZ)
- `tx_at` - Transaction timestamp (TIMESTAMPTZ)

**Java Entity**: `com.acme.claims.domain.model.entity.ClaimEvent`

**Java Usage**:
```java
// EventProjectorMapper.java - Event creation
@Mapper
public interface EventProjectorMapper {
    @Mapping(target = "claimKeyId", source = "claimKey.id")
    @Mapping(target = "type", constant = "SUBMISSION")
    @Mapping(target = "eventTime", source = "submission.createdAt")
    ClaimEvent toSubmissionEvent(Submission submission, ClaimKey claimKey);
}
```

**Important Indexes**:
- `idx_claim_event_key` - Find events by claim key
- `idx_claim_event_type` - Filter by event type
- `idx_claim_event_time` - Time-based queries

---

### 12. Status Timeline (`claim_status_timeline`)

**Business Purpose**: Derived status timeline for claims (SUBMITTED → RESUBMITTED → PAID).

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `claim_key_id` - Reference to claim_key (BIGSERIAL, FK)
- `status` - Current status (TEXT)
- `status_date` - When status was set (TIMESTAMPTZ)
- `created_at` - Record creation timestamp (TIMESTAMPTZ)
- `updated_at` - Record update timestamp (TIMESTAMPTZ)

**Java Usage**:
```java
// Status calculation logic
public String calculateStatus(List<ClaimEvent> events) {
    if (events.isEmpty()) return "UNKNOWN";
    
    boolean hasSubmission = events.stream().anyMatch(e -> e.getType() == 1);
    boolean hasResubmission = events.stream().anyMatch(e -> e.getType() == 2);
    boolean hasRemittance = events.stream().anyMatch(e -> e.getType() == 3);
    
    if (hasRemittance) return "PAID";
    if (hasResubmission) return "RESUBMITTED";
    if (hasSubmission) return "SUBMITTED";
    return "UNKNOWN";
}
```

---

## Reference Data Schema (`claims_ref`)

### 1. Facilities (`facility`)

**Business Purpose**: Master list of healthcare facilities.

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `facility_code` - External facility ID (TEXT, UNIQUE)
- `name` - Facility name (TEXT)
- `city` - City location (TEXT)
- `country` - Country location (TEXT)
- `status` - Facility status (TEXT)

**Java Entity**: `com.acme.claims.entity.Facility`

**Java Usage**:
```java
// FacilityRepository.java
@Repository
public interface FacilityRepository extends JpaRepository<Facility, Long> {
    Optional<Facility> findByFacilityCode(String facilityCode);
    List<Facility> findByStatus(String status);
}
```

---

### 2. Payers (`payer`)

**Business Purpose**: Master list of insurance payers.

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `payer_code` - External payer ID (TEXT, UNIQUE)
- `name` - Payer name (TEXT)
- `status` - Payer status (TEXT)
- `classification` - Payer classification (TEXT)

**Java Entity**: `com.acme.claims.entity.Payer`

---

### 3. Activity Codes (`activity_code`)

**Business Purpose**: Service/procedure codes used in activities.

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `type` - Code type (TEXT)
- `code` - Activity code (TEXT)
- `code_system` - Code system (TEXT)
- `description` - Code description (TEXT)
- `status` - Code status (TEXT)

**Java Entity**: `com.acme.claims.entity.ActivityCode`

**Java Usage**:
```java
// RefCodeResolver.java - Code resolution
public String resolveCode(String codeType, String code) {
    return activityCodeRepository.findByCodeAndType(code, codeType)
        .map(ActivityCode::getDescription)
        .orElse(code);
}
```

---

### 4. Diagnosis Codes (`diagnosis_code`)

**Business Purpose**: Diagnosis codes (ICD-10) used in encounters.

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `code` - Diagnosis code (TEXT)
- `code_system` - Code system (TEXT)
- `description` - Code description (TEXT)
- `status` - Code status (TEXT)

**Java Entity**: `com.acme.claims.entity.DiagnosisCode`

---

### 5. Denial Codes (`denial_code`)

**Business Purpose**: Adjudication denial codes for remittances.

**Key Columns**:
- `id` - Primary key (BIGSERIAL)
- `code` - Denial code (TEXT, UNIQUE)
- `description` - Code description (TEXT)
- `payer_code` - Payer-specific code (TEXT)

**Java Entity**: `com.acme.claims.entity.DenialCode`

---

## Database Functions

### 1. Audit Functions

**`set_updated_at()`** - Updates the `updated_at` timestamp when records are modified.

**Java Usage**: Automatically triggered by database triggers.

### 2. Transaction Functions

**`set_submission_tx_at()`** - Sets transaction timestamp from ingestion file.

**`set_claim_tx_at()`** - Sets transaction timestamp from submission.

**Java Usage**: Automatically triggered by database triggers.

### 3. Claim Payment Functions

**`calculate_claim_payment()`** - Calculates payment amounts for claims.

**Java Usage**:
```java
// ClaimPaymentService.java
@Query(value = "SELECT * FROM calculate_claim_payment(?1)", nativeQuery = true)
List<ClaimPayment> calculatePayments(Long claimId);
```

---

## Performance Considerations

### Indexing Strategy
- **Primary Keys**: All tables have BIGSERIAL primary keys
- **Foreign Keys**: Indexed for join performance
- **Business Keys**: Unique constraints with indexes
- **Text Search**: Trigram indexes for fuzzy text search
- **Date Ranges**: Indexes on timestamp columns for reporting

### Partitioning
- **Date-based partitioning**: For large tables like `claim_event`
- **Facility-based partitioning**: For multi-tenant scenarios

### Query Optimization
- **Materialized Views**: For complex report queries
- **Connection Pooling**: Efficient database connection management
- **Batch Processing**: Bulk operations for large datasets

---

## Security Considerations

### Data Protection
- **Emirates ID**: Hashed or masked when configured
- **Sensitive Data**: Encrypted using pgcrypto extension
- **Access Control**: Role-based access control

### Audit Trail
- **Event Tracking**: Complete audit trail for all claim events
- **Error Logging**: Comprehensive error tracking
- **Change Tracking**: Updated timestamps for all modifications

---

## Related Documentation

- [Class Index](../quick-ref/CLASS_INDEX.md) - Complete list of all classes
- [Finding Code Guide](../quick-ref/FINDING_CODE_GUIDE.md) - How to find specific functionality
- [Common Patterns](../quick-ref/COMMON_PATTERNS.md) - Recurring patterns in codebase
- [Component Map](../architecture/COMPONENT_MAP.md) - High-level architecture overview
- [Function Context](FUNCTION_CONTEXT.md) - Database functions and procedures
