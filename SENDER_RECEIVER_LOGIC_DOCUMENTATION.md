# Sender/Receiver Logic Documentation

## Overview
This document explains the sender/receiver relationships in the claims system and how to correctly reference them in views, functions, and materialized views.

## Key Principles

### 1. **For REMITTANCES (Remittance Advice)**
- **Sender** = **Payer** (the insurance company/payer who sends the remittance)
- **Receiver** = **Facility** (the healthcare facility that receives the remittance)

**In Code:**
- Sender info comes from: `claims_ref.payer` table (via `rc.payer_ref_id` or `c.payer_ref_id`)
- Receiver info comes from: `claims_ref.facility` table (via `e.facility_ref_id`)

### 2. **For SUBMISSIONS (Claim Submissions)**
- **Sender** = **Facility** (the healthcare facility that sends the claim)
- **Receiver** = **Payer** (the insurance company/payer that receives the claim)

**In Code:**
- Sender info comes from: `claims_ref.facility` table (via `e.facility_ref_id`)
- Receiver info comes from: `claims_ref.payer` table (via `c.payer_ref_id`)

### 3. **For RESUBMISSIONS**
- Same logic as submissions (sender=facility, receiver=payer)

## Table Structure Context

### Important Notes:
1. The `claims.remittance` table does NOT have `receiver_name` or `receiver_id` columns
2. The `claims.remittance` table does NOT have `payment_reference` column
3. The `claims.remittance_claim` table has `payment_reference` column
4. Receiver/sender information must come from joining to reference tables

## Common Mistakes to Avoid

### ❌ WRONG:
```sql
SELECT r.receiver_name, r.receiver_id, r.payment_reference
FROM claims.remittance r
```
These columns don't exist in the remittance table!

### ✅ CORRECT:
```sql
SELECT 
  f.name AS receiver_name,
  e.facility_id AS receiver_id,
  rc.payment_reference,
  pay.name AS sender_name
FROM claims.remittance r
LEFT JOIN claims.remittance_claim rc ON rc.remittance_id = r.id
LEFT JOIN claims.claim_key ck ON ck.id = rc.claim_key_id
LEFT JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id  -- Receiver
LEFT JOIN claims_ref.payer pay ON pay.id = rc.payer_ref_id   -- Sender
```

## Data Dictionary Updates

### Remittance Transaction Flow
```
Payer (Sender) → [Sends Remittance] → Facility (Receiver)
```

### Submission Transaction Flow  
```
Facility (Sender) → [Sends Claim] → Payer (Receiver)
```

### Key Reference Tables

#### `claims_ref.facility`
- **Purpose**: Master list of healthcare facilities
- **Used As**: Receiver for remittances, Sender for submissions
- **Key Columns**: `id`, `facility_code`, `name`, `city`

#### `claims_ref.payer`
- **Purpose**: Master list of insurance payers
- **Used As**: Sender for remittances, Receiver for submissions
- **Key Columns**: `id`, `payer_code`, `name`

#### `claims_ref.provider`
- **Purpose**: Master list of provider organizations
- **Used As**: Provider information in claims
- **Key Columns**: `id`, `provider_code`, `name`

## Views That Need Fixing

### Already Fixed in 06-report-views.sql:
1. ✅ `v_remittance_advice_header` - Fixed to use facility as receiver
2. ✅ `v_remittance_advice_claim_wise` - Fixed to use facility as receiver
3. ✅ `v_remittance_advice_activity_wise` - Fixed to use facility as receiver
4. ✅ `v_claim_details_with_activity` - Fixed to use facility as receiver
5. ✅ `v_rejected_claims_base` CTE - Fixed to use facility as receiver
6. ✅ `v_rejected_claims_receiver_payer` - Fixed to use facility as receiver
7. ✅ `v_rejected_claims_claim_wise` - Fixed to use facility as receiver
8. ✅ `v_doctor_denial_detail` - Fixed to use facility as receiver

### Needs Fixing in 07-materialized-views.sql:
- Multiple materialized views still have the old `r.receiver_name` references

## Recommendations for Future Development

1. **Always use reference tables** - Never assume sender/receiver info is in core transaction tables
2. **Join pattern for remittances**:
   ```sql
   LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id  -- Receiver
   LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id     -- Sender (from claim)
   ```

3. **Join pattern for submissions**:
   ```sql
   LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id   -- Sender
   LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id     -- Receiver
   ```

4. **Always join through claim_key → claim → encounter** to get facility/payer information

## Migration Notes

When fixing views:
1. Add proper joins to `claims.claim_key`, `claims.claim`, `claims.encounter`
2. Join to `claims_ref.facility` for receiver info in remittances
3. Join to `claims_ref.payer` for sender info in remittances (or receiver in submissions)
4. Use `rc.payment_reference` instead of `r.payment_reference`
5. Update all GROUP BY clauses to match new SELECT columns
