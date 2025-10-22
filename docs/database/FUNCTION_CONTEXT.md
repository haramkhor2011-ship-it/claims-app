# Database Function Context - Claims Backend Application

> Comprehensive documentation of database functions and procedures with Java code references. This document explains what each function calculates, when it's called, and how it's used in the application.

## Overview

The claims-backend application uses PostgreSQL functions and procedures for:

- **Audit and Timestamp Management** - Automatic timestamp updates
- **Claim Payment Calculations** - Complex financial calculations
- **Data Integrity** - Constraint enforcement and validation
- **Performance Optimization** - Pre-computed aggregations

---

## Audit and Timestamp Functions

### 1. `set_updated_at()`

**Purpose**: Automatically updates the `updated_at` timestamp when records are modified.

**Function Definition**:
```sql
CREATE OR REPLACE FUNCTION claims.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW IS DISTINCT FROM OLD THEN
    NEW.updated_at := NOW();
  END IF;
  RETURN NEW;
END$$;
```

**What it does**:
- Triggered before UPDATE operations on tables
- Sets `updated_at` to current timestamp if any field changed
- Prevents unnecessary timestamp updates for unchanged records

**Java Usage**: Automatically triggered by database triggers on all tables.

**Tables using this function**:
- `ingestion_file`
- `submission`
- `claim`
- `encounter`
- `activity`
- `observation`
- `remittance`
- `remittance_claim`

**Example Trigger**:
```sql
CREATE TRIGGER trg_ingestion_file_updated_at
  BEFORE UPDATE ON claims.ingestion_file
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();
```

---

### 2. `set_submission_tx_at()`

**Purpose**: Sets the transaction timestamp for submissions from the ingestion file.

**Function Definition**:
```sql
CREATE OR REPLACE FUNCTION claims.set_submission_tx_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tx_at IS NULL THEN
    SELECT i.transaction_date INTO NEW.tx_at
    FROM claims.ingestion_file i
    WHERE i.id = NEW.ingestion_file_id;
  END IF;
  RETURN NEW;
END$$;
```

**What it does**:
- Triggered before INSERT operations on `submission` table
- Sets `tx_at` from the related `ingestion_file.transaction_date`
- Only sets if `tx_at` is NULL (allows manual override)

**Java Usage**: Automatically triggered when creating submission records.

**Java Code Reference**:
```java
// PersistService.java - Submission creation
@Transactional(propagation = Propagation.REQUIRES_NEW)
public PersistCounts persistSubmission(Long ingestionFileId, SubmissionDTO dto, List<AttachmentDto> attachments) {
    Submission submission = submissionMapper.toEntity(dto);
    submission.setIngestionFileId(ingestionFileId);
    // tx_at will be set automatically by trigger
    submission = submissionRepository.save(submission);
}
```

---

### 3. `set_remittance_tx_at()`

**Purpose**: Sets the transaction timestamp for remittances from the ingestion file.

**Function Definition**:
```sql
CREATE OR REPLACE FUNCTION claims.set_remittance_tx_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tx_at IS NULL THEN
    SELECT i.transaction_date INTO NEW.tx_at
    FROM claims.ingestion_file i
    WHERE i.id = NEW.ingestion_file_id;
  END IF;
  RETURN NEW;
END$$;
```

**What it does**:
- Triggered before INSERT operations on `remittance` table
- Sets `tx_at` from the related `ingestion_file.transaction_date`
- Only sets if `tx_at` is NULL (allows manual override)

**Java Usage**: Automatically triggered when creating remittance records.

---

### 4. `set_claim_tx_at()`

**Purpose**: Sets the transaction timestamp for claims from the submission.

**Function Definition**:
```sql
CREATE OR REPLACE FUNCTION claims.set_claim_tx_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tx_at IS NULL THEN
    SELECT s.tx_at INTO NEW.tx_at
    FROM claims.submission s
    WHERE s.id = NEW.submission_id;
  END IF;
  RETURN NEW;
END$$;
```

**What it does**:
- Triggered before INSERT operations on `claim` table
- Sets `tx_at` from the related `submission.tx_at`
- Maintains transaction timestamp consistency

**Java Usage**: Automatically triggered when creating claim records.

---

### 5. `set_claim_event_activity_tx_at()`

**Purpose**: Sets the transaction timestamp for claim event activities from the claim event.

**Function Definition**:
```sql
CREATE OR REPLACE FUNCTION claims.set_claim_event_activity_tx_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tx_at IS NULL THEN
    SELECT ce.event_time INTO NEW.tx_at
    FROM claims.claim_event ce
    WHERE ce.id = NEW.claim_event_id;
  END IF;
  RETURN NEW;
END$$;
```

**What it does**:
- Triggered before INSERT operations on `claim_event_activity` table
- Sets `tx_at` from the related `claim_event.event_time`
- Ensures event activity timestamps match event timestamps

---

### 6. `set_event_observation_tx_at()`

**Purpose**: Sets the transaction timestamp for event observations from the claim event activity.

**Function Definition**:
```sql
CREATE OR REPLACE FUNCTION claims.set_event_observation_tx_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tx_at IS NULL THEN
    SELECT cea.tx_at INTO NEW.tx_at
    FROM claims.claim_event_activity cea
    WHERE cea.id = NEW.claim_event_activity_id;
  END IF;
  RETURN NEW;
END$$;
```

**What it does**:
- Triggered before INSERT operations on `event_observation` table
- Sets `tx_at` from the related `claim_event_activity.tx_at`
- Maintains timestamp consistency across event hierarchy

---

## Claim Payment Functions

### 1. `recalculate_claim_payment(p_claim_key_id BIGINT)`

**Purpose**: Recalculates comprehensive payment metrics for a specific claim.

**Function Definition**:
```sql
CREATE OR REPLACE FUNCTION claims.recalculate_claim_payment(p_claim_key_id BIGINT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  v_metrics RECORD;
  v_payment_status VARCHAR(20);
  v_payment_references TEXT[];
  v_first_submission_date DATE;
  v_last_submission_date DATE;
  v_first_remittance_date DATE;
  v_last_remittance_date DATE;
  v_first_payment_date DATE;
  v_last_payment_date DATE;
  v_latest_settlement_date DATE;
  v_days_to_first_payment INTEGER;
  v_days_to_final_settlement INTEGER;
  v_processing_cycles INTEGER;
  v_resubmission_count INTEGER;
  v_latest_payment_reference VARCHAR(100);
  v_tx_at TIMESTAMPTZ;
BEGIN
  -- Calculate all financial metrics from claim_activity_summary
  SELECT 
    COALESCE(SUM(cas.submitted_amount), 0) AS total_submitted,
    COALESCE(SUM(cas.paid_amount), 0) AS total_paid,
    COALESCE(SUM(cas.submitted_amount), 0) AS total_remitted,
    COALESCE(SUM(cas.rejected_amount), 0) AS total_rejected,
    COALESCE(SUM(cas.denied_amount), 0) AS total_denied,
    COUNT(cas.activity_id) AS total_activities,
    COUNT(CASE WHEN cas.activity_status = 'FULLY_PAID' THEN 1 END) AS paid_activities,
    COUNT(CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN 1 END) AS partially_paid_activities,
    COUNT(CASE WHEN cas.activity_status = 'REJECTED' THEN 1 END) AS rejected_activities,
    COUNT(CASE WHEN cas.activity_status = 'PENDING' THEN 1 END) AS pending_activities,
    COALESCE(MAX(cas.remittance_count), 0) AS remittance_count
  INTO v_metrics
  FROM claims.claim_activity_summary cas
  WHERE cas.claim_key_id = p_claim_key_id;
  
  -- Calculate payment status
  v_payment_status := CASE 
    WHEN v_metrics.total_paid = v_metrics.total_submitted AND v_metrics.total_submitted > 0 THEN 'FULLY_PAID'
    WHEN v_metrics.total_paid > 0 THEN 'PARTIALLY_PAID'
    WHEN v_metrics.total_rejected > 0 THEN 'REJECTED'
    ELSE 'PENDING'
  END;
  
  -- Calculate dates and processing metrics
  -- ... (additional calculations)
  
  -- Upsert claim_payment record
  INSERT INTO claims.claim_payment (
    claim_key_id, 
    total_submitted_amount, 
    total_paid_amount, 
    total_remitted_amount,
    total_rejected_amount,
    total_denied_amount,
    total_activities,
    paid_activities,
    partially_paid_activities,
    rejected_activities,
    pending_activities,
    remittance_count,
    resubmission_count,
    payment_status,
    first_submission_date,
    last_submission_date,
    first_remittance_date,
    last_remittance_date,
    first_payment_date,
    last_payment_date,
    latest_settlement_date,
    days_to_first_payment,
    days_to_final_settlement,
    processing_cycles,
    latest_payment_reference,
    payment_references,
    tx_at,
    updated_at
  ) VALUES (
    p_claim_key_id,
    v_metrics.total_submitted,
    v_metrics.total_paid,
    v_metrics.total_remitted,
    v_metrics.total_rejected,
    v_metrics.total_denied,
    v_metrics.total_activities,
    v_metrics.paid_activities,
    v_metrics.partially_paid_activities,
    v_metrics.rejected_activities,
    v_metrics.pending_activities,
    v_metrics.remittance_count,
    v_resubmission_count,
    v_payment_status,
    v_first_submission_date,
    v_last_submission_date,
    v_first_remittance_date,
    v_last_remittance_date,
    v_first_payment_date,
    v_last_payment_date,
    v_latest_settlement_date,
    v_days_to_first_payment,
    v_days_to_final_settlement,
    v_processing_cycles,
    v_latest_payment_reference,
    v_payment_references,
    v_tx_at,
    NOW()
  )
  ON CONFLICT (claim_key_id) DO UPDATE SET
    total_submitted_amount = EXCLUDED.total_submitted_amount,
    total_paid_amount = EXCLUDED.total_paid_amount,
    total_remitted_amount = EXCLUDED.total_remitted_amount,
    total_rejected_amount = EXCLUDED.total_rejected_amount,
    total_denied_amount = EXCLUDED.total_denied_amount,
    total_activities = EXCLUDED.total_activities,
    paid_activities = EXCLUDED.paid_activities,
    partially_paid_activities = EXCLUDED.partially_paid_activities,
    rejected_activities = EXCLUDED.rejected_activities,
    pending_activities = EXCLUDED.pending_activities,
    remittance_count = EXCLUDED.remittance_count,
    resubmission_count = EXCLUDED.resubmission_count,
    payment_status = EXCLUDED.payment_status,
    first_submission_date = EXCLUDED.first_submission_date,
    last_submission_date = EXCLUDED.last_submission_date,
    first_remittance_date = EXCLUDED.first_remittance_date,
    last_remittance_date = EXCLUDED.last_remittance_date,
    first_payment_date = EXCLUDED.first_payment_date,
    last_payment_date = EXCLUDED.last_payment_date,
    latest_settlement_date = EXCLUDED.latest_settlement_date,
    days_to_first_payment = EXCLUDED.days_to_first_payment,
    days_to_final_settlement = EXCLUDED.days_to_final_settlement,
    processing_cycles = EXCLUDED.processing_cycles,
    latest_payment_reference = EXCLUDED.latest_payment_reference,
    payment_references = EXCLUDED.payment_references,
    tx_at = EXCLUDED.tx_at,
    updated_at = NOW();
END$$;
```

**What it calculates**:
- **Financial Metrics**: Total submitted, paid, rejected, denied amounts
- **Activity Counts**: Total activities and their status breakdown
- **Payment Status**: FULLY_PAID, PARTIALLY_PAID, REJECTED, PENDING
- **Date Metrics**: First/last submission, remittance, payment dates
- **Processing Metrics**: Days to payment, processing cycles, resubmissions
- **Payment References**: All payment references and latest reference

**Java Usage**:
```java
// ClaimPaymentService.java
@Service
public class ClaimPaymentService {
    
    @Autowired
    private JdbcTemplate jdbcTemplate;
    
    public void recalculateClaimPayment(Long claimKeyId) {
        jdbcTemplate.update("SELECT claims.recalculate_claim_payment(?)", claimKeyId);
    }
    
    public List<ClaimPayment> getClaimPayments(Long claimKeyId) {
        return jdbcTemplate.query("""
            SELECT * FROM claims.claim_payment 
            WHERE claim_key_id = ?
            """, new ClaimPaymentRowMapper(), claimKeyId);
    }
}
```

**When it's called**:
- After remittance processing
- During batch recalculation jobs
- When payment data needs to be refreshed

---

### 2. `trigger_recalculate_claim_payment()`

**Purpose**: Trigger function that automatically recalculates payment metrics when remittance data changes.

**Function Definition**:
```sql
CREATE OR REPLACE FUNCTION claims.trigger_recalculate_claim_payment()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Recalculate for the affected claim
  PERFORM claims.recalculate_claim_payment(NEW.claim_key_id);
  RETURN NEW;
END$$;
```

**What it does**:
- Triggered after INSERT/UPDATE/DELETE on `remittance_claim` table
- Automatically recalculates payment metrics for the affected claim
- Ensures payment data is always current

**Java Usage**: Automatically triggered by database triggers.

**Example Trigger**:
```sql
CREATE TRIGGER trg_remittance_claim_recalculate
  AFTER INSERT OR UPDATE OR DELETE ON claims.remittance_claim
  FOR EACH ROW EXECUTE FUNCTION claims.trigger_recalculate_claim_payment();
```

---

## Utility Functions

### 1. `get_claim_status_timeline(p_claim_key_id BIGINT)`

**Purpose**: Calculates the status timeline for a claim based on its events.

**Function Definition**:
```sql
CREATE OR REPLACE FUNCTION claims.get_claim_status_timeline(p_claim_key_id BIGINT)
RETURNS TABLE(
  status TEXT,
  status_date TIMESTAMPTZ,
  event_type SMALLINT
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT 
    CASE 
      WHEN ce.type = 1 THEN 'SUBMITTED'
      WHEN ce.type = 2 THEN 'RESUBMITTED'
      WHEN ce.type = 3 THEN 'PAID'
      ELSE 'UNKNOWN'
    END as status,
    ce.event_time as status_date,
    ce.type as event_type
  FROM claims.claim_event ce
  WHERE ce.claim_key_id = p_claim_key_id
  ORDER BY ce.event_time;
END$$;
```

**What it calculates**:
- Status progression: SUBMITTED → RESUBMITTED → PAID
- Status dates based on event timestamps
- Event types for detailed analysis

**Java Usage**:
```java
// ClaimStatusService.java
@Service
public class ClaimStatusService {
    
    public List<ClaimStatusTimeline> getClaimStatusTimeline(Long claimKeyId) {
        return jdbcTemplate.query("""
            SELECT * FROM claims.get_claim_status_timeline(?)
            """, new ClaimStatusTimelineRowMapper(), claimKeyId);
    }
}
```

---

### 2. `calculate_claim_payment(p_claim_key_id BIGINT)`

**Purpose**: Calculates payment amounts for a specific claim.

**Function Definition**:
```sql
CREATE OR REPLACE FUNCTION claims.calculate_claim_payment(p_claim_key_id BIGINT)
RETURNS TABLE(
  activity_id TEXT,
  submitted_amount NUMERIC,
  paid_amount NUMERIC,
  rejected_amount NUMERIC,
  denied_amount NUMERIC,
  payment_status TEXT
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cas.activity_id,
    cas.submitted_amount,
    cas.paid_amount,
    cas.rejected_amount,
    cas.denied_amount,
    cas.activity_status
  FROM claims.claim_activity_summary cas
  WHERE cas.claim_key_id = p_claim_key_id
  ORDER BY cas.activity_id;
END$$;
```

**What it calculates**:
- Per-activity payment breakdown
- Submitted vs paid amounts
- Rejected and denied amounts
- Activity-level payment status

**Java Usage**:
```java
// ClaimPaymentService.java
public List<ClaimPaymentDetail> getClaimPaymentDetails(Long claimKeyId) {
    return jdbcTemplate.query("""
        SELECT * FROM claims.calculate_claim_payment(?)
        """, new ClaimPaymentDetailRowMapper(), claimKeyId);
}
```

---

## Performance Characteristics

### Function Execution
- **Audit Functions**: Very fast (microseconds)
- **Payment Calculations**: Moderate (milliseconds to seconds)
- **Timeline Calculations**: Fast (milliseconds)

### Optimization Strategies
- **Pre-computed Summaries**: Uses `claim_activity_summary` for fast calculations
- **Indexed Lookups**: All functions use indexed columns
- **Batch Processing**: Functions can be called in batches
- **Caching**: Results can be cached for frequently accessed claims

### Monitoring
- **Execution Time**: Tracked via `pg_stat_statements`
- **Error Handling**: Functions include error handling
- **Logging**: Important operations are logged

---

## Error Handling

### Function Error Handling
```sql
-- Example error handling in functions
BEGIN
  -- Function logic
EXCEPTION
  WHEN OTHERS THEN
    -- Log error
    RAISE LOG 'Error in function: %', SQLERRM;
    -- Re-raise exception
    RAISE;
END;
```

### Java Error Handling
```java
// Java error handling for function calls
try {
    jdbcTemplate.update("SELECT claims.recalculate_claim_payment(?)", claimKeyId);
} catch (DataAccessException e) {
    log.error("Failed to recalculate claim payment for claim: {}", claimKeyId, e);
    throw new ClaimPaymentException("Payment calculation failed", e);
}
```

---

## Testing Functions

### Unit Testing
```sql
-- Test function with sample data
SELECT claims.recalculate_claim_payment(1);
SELECT * FROM claims.claim_payment WHERE claim_key_id = 1;
```

### Integration Testing
```java
@Test
void testRecalculateClaimPayment() {
    // Setup test data
    Long claimKeyId = createTestClaim();
    
    // Call function
    claimPaymentService.recalculateClaimPayment(claimKeyId);
    
    // Verify results
    ClaimPayment payment = claimPaymentService.getClaimPayment(claimKeyId);
    assertThat(payment.getTotalSubmittedAmount()).isGreaterThan(0);
}
```

---

## Related Documentation

- [Schema Context](SCHEMA_CONTEXT.md) - Database schema documentation
- [Class Index](../quick-ref/CLASS_INDEX.md) - Complete list of all classes
- [Finding Code Guide](../quick-ref/FINDING_CODE_GUIDE.md) - How to find specific functionality
- [Common Patterns](../quick-ref/COMMON_PATTERNS.md) - Recurring patterns in codebase
- [Component Map](../architecture/COMPONENT_MAP.md) - High-level architecture overview
