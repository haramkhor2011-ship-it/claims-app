# CUMULATIVE-WITH-CAP IMPLEMENTATION PLAN

## Overview

This document outlines the exact implementation of the "cumulative-with-cap" approach for remittance activity calculations in the claims processing system. This approach prevents overcounting of financial totals when multiple remittances exist for the same claim activities.

## Problem Statement

Previously, the system aggregated all remittance activities without considering that:
1. Multiple remittances for the same activity could lead to overcounting payments
2. Denial logic was applied to each remittance occurrence rather than the latest state
3. Financial totals could exceed the original submitted amounts

## Solution: Cumulative-with-Cap Approach

### Core Logic

1. **Cumulative Payments**: Sum all payment amounts across remittances for each activity
2. **Cap at Submitted**: Limit cumulative paid amount to the activity's original submitted net amount
3. **Latest Denial Logic**: Use the most recent denial code (by settlement date) to determine rejection status
4. **Conditional Denial**: Only count as denied if latest denial exists AND capped paid amount is zero

### Mathematical Formula

For each activity:
```
paid_amount = LEAST(SUM(remittance_payments), submitted_net)
denied_amount = CASE 
  WHEN latest_denial_code IS NOT NULL AND paid_amount = 0 
  THEN submitted_net 
  ELSE 0 
END
rejected_amount = denied_amount  -- Same logic for this implementation
```

## Implementation Details

### 1. Updated Functions

#### `claims.recalculate_activity_summary(p_claim_key_id BIGINT)`

**File**: `src/main/resources/db/claim_payment_functions.sql` and `docker/db-init/08-functions-procedures.sql`

**Changes**:
- Replaced simple SUM aggregations with cumulative-with-cap logic
- Added latest denial determination using `ARRAY_AGG` with ordering
- Implemented conditional denial logic based on latest denial and zero paid

**Key Code Changes**:
```sql
-- OLD: Simple aggregation
COALESCE(SUM(ra.payment_amount), 0) as paid_amount,
COALESCE(SUM(CASE WHEN ra.denial_code IS NOT NULL THEN a.net ELSE 0 END), 0) as denied_amount,

-- NEW: Cumulative-with-cap
LEAST(COALESCE(SUM(ra.payment_amount), 0), a.net) AS paid_amount,
CASE 
  WHEN (ARRAY_AGG(ra.denial_code ORDER BY rc.date_settlement DESC NULLS LAST, ra.id DESC))[1] IS NOT NULL
       AND LEAST(COALESCE(SUM(ra.payment_amount), 0), a.net) = 0 
  THEN a.net 
  ELSE 0 
END AS denied_amount,
```

#### `claims.recalculate_claim_payment(p_claim_key_id BIGINT)`

**File**: `src/main/resources/db/claim_payment_functions.sql` and `docker/db-init/08-functions-procedures.sql`

**Changes**:
- Updated to read from `claims.claim_activity_summary` instead of raw remittance data
- Uses pre-computed cumulative-with-cap values for all financial metrics

**Key Code Changes**:
```sql
-- OLD: Direct aggregation from remittance_activity
FROM claims.claim c
JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = c.claim_key_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id 

-- NEW: Read from pre-computed summary
FROM claims.claim_activity_summary cas
LEFT JOIN claims.claim c ON c.claim_key_id = cas.claim_key_id
```

### 2. Updated Materialized Views

#### Balance Amount Summary MV

**File**: `src/main/resources/db/reports_sql/sub_second_materialized_views.sql` and `docker/db-init/06-materialized-views.sql`

**Changes**:
- Updated `rem_agg` LEFT JOIN to use `claims.claim_activity_summary`
- Replaced direct remittance_activity aggregation with pre-computed values

#### Remittance Advice Summary MV

**File**: `src/main/resources/db/reports_sql/sub_second_materialized_views.sql` and `docker/db-init/06-materialized-views.sql`

**Changes**:
- Updated `claim_remittance_agg` CTE to use `claims.claim_activity_summary`
- Changed activity counting and financial aggregations to use capped values

### 3. Updated Report Views

#### Balance Amount Report

**File**: `src/main/resources/db/reports_sql/balance_amount_report_implementation_final.sql`

**Changes**:
- Updated `remittance_summary` CTE to use `claims.claim_activity_summary`
- Replaced raw remittance aggregations with pre-computed capped values

#### Remittance Advice Payerwise Report

**File**: `src/main/resources/db/reports_sql/remittance_advice_payerwise_report_final.sql`

**Changes**:
- Updated `activity_aggregates` CTE to use `claims.claim_activity_summary`
- Changed activity-level aggregations to use cumulative-with-cap values

#### Claim Details Report

**File**: `src/main/resources/db/reports_sql/claim_details_with_activity_final.sql`

**Changes**:
- Added JOIN to `claims.claim_activity_summary`
- Updated financial calculations to use pre-computed values
- Changed denial code logic to use latest from activity summary

## Example: Single Claim Lifecycle

### Scenario
- Claim submitted with 2 activities: Activity A ($100), Activity B ($200)
- First remittance: Activity A paid $50, Activity B denied with code "CO-50"
- Second remittance: Activity A paid $30, Activity B paid $100
- Third remittance: Activity A denied with code "CO-25", Activity B paid $50

### Raw Data Storage
```
remittance_activity table:
- Remittance 1: Activity A, payment_amount=50, denial_code=NULL
- Remittance 1: Activity B, payment_amount=0, denial_code="CO-50"
- Remittance 2: Activity A, payment_amount=30, denial_code=NULL
- Remittance 2: Activity B, payment_amount=100, denial_code=NULL
- Remittance 3: Activity A, payment_amount=0, denial_code="CO-25"
- Remittance 3: Activity B, payment_amount=50, denial_code=NULL
```

### Cumulative-with-Cap Calculation

#### Activity A ($100 submitted)
- Cumulative payments: $50 + $30 + $0 = $80
- Capped paid: LEAST($80, $100) = $80
- Latest denial: "CO-25" (from remittance 3)
- Since latest denial exists but capped paid > 0: denied_amount = $0
- Status: PARTIALLY_PAID

#### Activity B ($200 submitted)
- Cumulative payments: $0 + $100 + $50 = $150
- Capped paid: LEAST($150, $200) = $150
- Latest denial: NULL (no denial in latest remittance)
- denied_amount = $0
- Status: PARTIALLY_PAID

### Final Summary
```
claim_activity_summary:
- Activity A: submitted=$100, paid=$80, denied=$0, status=PARTIALLY_PAID
- Activity B: submitted=$200, paid=$150, denied=$0, status=PARTIALLY_PAID

claim_payment:
- total_submitted=$300, total_paid=$230, total_denied=$0, status=PARTIALLY_PAID
```

## Data Persistence Strategy

### Existing Table Usage
- **`claims.claim_activity_summary`**: Pre-existing table used to store per-activity financial summaries
- **Triggers**: Existing triggers on `claims.remittance_activity` automatically update the summary table
- **Functions**: Updated functions maintain the cumulative-with-cap logic

### Trigger Chain
1. `INSERT/UPDATE/DELETE` on `claims.remittance_activity`
2. Triggers `claims.update_activity_summary_on_remittance_activity()`
3. Calls `claims.recalculate_activity_summary(claim_key_id)`
4. Updates `claims.claim_activity_summary` with cumulative-with-cap values
5. Triggers `claims.update_claim_payment_on_remittance_activity()`
6. Calls `claims.recalculate_claim_payment(claim_key_id)`
7. Updates `claims.claim_payment` with aggregated values

## Validation and Testing

### Validation Queries
The implementation includes validation queries to ensure:
1. Capped totals are always <= raw totals
2. Latest denial logic is working correctly
3. Activity status distribution is reasonable

### Sample Validation Results
```sql
-- Check capped vs raw totals
SELECT 
  claim_id,
  capped_paid_total,
  raw_paid_total,
  CASE WHEN capped_paid_total <= raw_paid_total THEN 'PASS' ELSE 'FAIL' END as validation
FROM validation_results;
```

## Performance Impact

### Benefits
- **Accurate Financial Totals**: Prevents overcounting from multiple remittances
- **Consistent Denial Logic**: Uses latest denial state for each activity
- **Pre-computed Aggregations**: Materialized views and summary tables provide sub-second performance
- **Real-time Updates**: Triggers maintain accuracy as new remittances arrive

### Considerations
- **Storage**: Additional storage for `claim_activity_summary` table
- **Processing**: Slightly more complex calculations during ingestion
- **Maintenance**: Triggers add overhead to remittance_activity operations

## Deployment Steps

1. **Update Functions**: Deploy updated `recalculate_activity_summary` and `recalculate_claim_payment` functions
2. **Refresh Summary Data**: Run initial population of `claim_activity_summary` with new logic
3. **Update Materialized Views**: Deploy updated MV definitions
4. **Refresh MVs**: Execute `REFRESH MATERIALIZED VIEW CONCURRENTLY` statements
5. **Update Report Views**: Deploy updated report view definitions
6. **Validate Results**: Run validation queries to ensure accuracy
7. **Monitor Performance**: Track query performance and trigger overhead

## Rollback Plan

If issues arise, the system can be rolled back by:
1. Reverting function definitions to previous versions
2. Refreshing materialized views with old logic
3. Reverting report view definitions
4. Re-running MV refresh operations

## Conclusion

The cumulative-with-cap approach provides accurate financial calculations while maintaining the existing data model and performance characteristics. The implementation leverages the existing `claims.claim_activity_summary` table and trigger system, ensuring minimal disruption to the current architecture.
