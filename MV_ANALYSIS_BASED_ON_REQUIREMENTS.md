# Materialized Views Analysis Based on Report Requirements

## Analysis Approach
Instead of blindly applying remittance aggregation, I'm analyzing each MV based on:
1. **Data Dictionary relationships** from `CLAIMS_DATA_DICTIONARY.md`
2. **Report business requirements** from final report SQL files
3. **Specific aggregation needs** for each MV's purpose
4. **Claim lifecycle patterns** and data relationships

## Detailed Analysis of Remaining MVs

### 1. mv_claim_details_complete ❌ CRITICAL

**Purpose**: Comprehensive activity-level view for Claim Details Report
**Current Issues**: 
- Direct JOINs to `remittance_claim` and `remittance_activity` without aggregation
- Multiple remittances per claim create multiple rows per activity
- Violates unique constraint on `(claim_key_id, activity_id)`

**Data Relationships Analysis**:
- **One-to-Many**: `claim_key` → `remittance_claim` (multiple remittances per claim)
- **One-to-Many**: `remittance_claim` → `remittance_activity` (multiple activities per remittance)
- **One-to-One**: `activity` → `remittance_activity` (via `activity_id`)

**Required Aggregation**:
```sql
-- NEEDED: Activity-level remittance aggregation
activity_remittance_agg AS (
  SELECT 
    a.activity_id,
    a.claim_id,
    -- Aggregate all remittances for this activity across all remittance cycles
    SUM(ra.payment_amount) as total_payment_amount,
    MAX(ra.denial_code) as latest_denial_code,
    MAX(rc.date_settlement) as latest_settlement_date,
    COUNT(DISTINCT rc.id) as remittance_count
  FROM claims.activity a
  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = (
    SELECT c.claim_key_id FROM claims.claim c WHERE c.id = a.claim_id
  )
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id 
    AND ra.activity_id = a.activity_id
  GROUP BY a.activity_id, a.claim_id
)
```

**Fix Strategy**: Activity-level aggregation, not claim-level

---

### 2. mv_rejected_claims_summary ❌ CRITICAL

**Purpose**: Pre-aggregated rejected claims data for Rejected Claims Report
**Current Issues**:
- Direct JOINs to `remittance_claim` and `remittance_activity` without aggregation
- Multiple remittances per claim create multiple rows per activity
- Violates unique constraint on `(claim_key_id, activity_id)`

**Data Relationships Analysis**:
- **Filter**: Only shows rejected activities (`ra.payment_amount = 0 OR ra.denial_code IS NOT NULL`)
- **One-to-Many**: `claim_key` → `remittance_claim` (multiple remittances per claim)
- **One-to-Many**: `remittance_claim` → `remittance_activity` (multiple activities per remittance)

**Required Aggregation**:
```sql
-- NEEDED: Activity-level rejection aggregation
activity_rejection_agg AS (
  SELECT 
    a.activity_id,
    a.claim_id,
    -- Get latest rejection status for this activity
    MAX(ra.denial_code) as latest_denial_code,
    MAX(rc.date_settlement) as latest_settlement_date,
    MAX(rc.payment_reference) as latest_payment_reference,
    -- Calculate rejection amount
    CASE 
      WHEN MAX(ra.payment_amount) = 0 AND MAX(ra.denial_code) IS NOT NULL THEN a.net
      WHEN MAX(ra.payment_amount) > 0 AND MAX(ra.payment_amount) < a.net THEN a.net - MAX(ra.payment_amount)
      ELSE 0
    END as rejected_amount
  FROM claims.activity a
  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = (
    SELECT c.claim_key_id FROM claims.claim c WHERE c.id = a.claim_id
  )
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id 
    AND ra.activity_id = a.activity_id
  WHERE ra.payment_amount = 0 OR ra.denial_code IS NOT NULL OR ra.payment_amount < a.net
  GROUP BY a.activity_id, a.claim_id, a.net
)
```

**Fix Strategy**: Activity-level rejection aggregation with latest status

---

### 3. mv_remittance_advice_summary ⚠️ NEEDS ATTENTION

**Purpose**: Pre-aggregated remittance advice data by payer
**Current Issues**:
- Groups by `rc.id` (remittance_claim) instead of `claim_key_id`
- Multiple remittances per claim create multiple rows
- Should aggregate all remittances per claim

**Data Relationships Analysis**:
- **Business Requirement**: Show remittance advice per claim, not per remittance
- **One-to-Many**: `claim_key` → `remittance_claim` (multiple remittances per claim)
- **One-to-Many**: `remittance_claim` → `remittance_activity` (multiple activities per remittance)

**Required Aggregation**:
```sql
-- NEEDED: Claim-level remittance aggregation
claim_remittance_agg AS (
  SELECT 
    rc.claim_key_id,
    -- Aggregate all remittances for this claim
    COUNT(DISTINCT rc.id) as remittance_count,
    SUM(ra.payment_amount) as total_payment,
    SUM(ra.net) as total_remitted,
    COUNT(CASE WHEN ra.denial_code IS NOT NULL THEN 1 END) as denied_count,
    SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) as denied_amount,
    -- Use latest remittance for payer/provider info
    (ARRAY_AGG(rc.id_payer ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_id_payer,
    (ARRAY_AGG(rc.provider_id ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_provider_id,
    MAX(rc.date_settlement) as latest_settlement_date,
    MAX(rc.payment_reference) as latest_payment_reference
  FROM claims.remittance_claim rc
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
)
```

**Fix Strategy**: Claim-level aggregation with latest remittance info

---

### 4. mv_resubmission_cycles ⚠️ NEEDS ATTENTION

**Purpose**: Pre-computed event tracking for resubmission cycles
**Current Issues**:
- LEFT JOIN to `remittance_claim` without aggregation
- Multiple remittances per claim create multiple rows per event

**Data Relationships Analysis**:
- **One-to-Many**: `claim_key` → `claim_event` (multiple events per claim)
- **One-to-Many**: `claim_key` → `remittance_claim` (multiple remittances per claim)
- **Business Requirement**: Track events, not remittances

**Required Aggregation**:
```sql
-- NEEDED: Event-level remittance aggregation (optional)
event_remittance_agg AS (
  SELECT 
    ce.claim_key_id,
    ce.event_time,
    -- Get remittance info closest to this event
    (ARRAY_AGG(rc.date_settlement ORDER BY ABS(EXTRACT(EPOCH FROM (rc.date_settlement - ce.event_time)))))[1] as closest_settlement_date,
    (ARRAY_AGG(rc.payment_reference ORDER BY ABS(EXTRACT(EPOCH FROM (rc.date_settlement - ce.event_time)))))[1] as closest_payment_reference
  FROM claims.claim_event ce
  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ce.claim_key_id
  WHERE ce.type IN (1, 2) -- SUBMISSION, RESUBMISSION
  GROUP BY ce.claim_key_id, ce.event_time
)
```

**Fix Strategy**: Event-level aggregation with closest remittance info

---

## Summary of Required Aggregation Patterns

### 1. Activity-Level Aggregation (mv_claim_details_complete, mv_rejected_claims_summary)
- **Purpose**: One row per activity with aggregated remittance data
- **Key**: `(claim_key_id, activity_id)`
- **Aggregation**: Sum payments, get latest denial codes, count remittances

### 2. Claim-Level Aggregation (mv_remittance_advice_summary)
- **Purpose**: One row per claim with aggregated remittance data
- **Key**: `claim_key_id`
- **Aggregation**: Sum all remittance activities, get latest payer/provider info

### 3. Event-Level Aggregation (mv_resubmission_cycles)
- **Purpose**: One row per event with closest remittance info
- **Key**: `(claim_key_id, event_time, type)`
- **Aggregation**: Get remittance info closest to event time

## Next Steps

1. **Fix mv_claim_details_complete** - Apply activity-level aggregation
2. **Fix mv_rejected_claims_summary** - Apply activity-level rejection aggregation
3. **Fix mv_remittance_advice_summary** - Apply claim-level aggregation
4. **Fix mv_resubmission_cycles** - Apply event-level aggregation

Each fix will be tailored to the specific business requirements and data relationships of that MV.
