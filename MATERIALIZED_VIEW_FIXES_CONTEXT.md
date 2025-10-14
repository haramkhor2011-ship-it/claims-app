# Materialized View Fixes - Context for New Chat Window

## Current Status
✅ **COMPLETED**: `mv_remittances_resubmission_activity_level` - Fixed duplicate key violations
✅ **COMPLETED**: `mv_claim_summary_payerwise` - Fixed remittance aggregation duplicates  
✅ **COMPLETED**: `mv_claim_summary_encounterwise` - Fixed remittance aggregation duplicates

## Key Learnings & Approach

### 1. **Claim Lifecycle Understanding**
- **Pattern**: Submission → Remittance → Resubmission → Remittance (can repeat)
- **Activities**: Remain same across submission, resubmission, remittances
- **Snapshots**: `claim_event_activity` stores activity snapshots at event time
- **Aggregation Principle**: Aggregate all remittances per claim in every report

### 2. **Duplicate Root Causes Identified**
1. **Multiple JOINs to same table** (e.g., 5 resubmission cycles, 5 remittance cycles)
2. **Cartesian products from multiple secondary diagnoses**
3. **Redundant JOINs** (e.g., extra `LEFT JOIN claims.remittance_claim`)
4. **Unaggregated remittance data** causing multiple rows per claim

### 3. **Fix Strategy Applied**
- **Aggregation CTEs**: Pre-aggregate data before main JOINs
- **ARRAY_AGG()**: Capture multiple cycles (up to 5) in arrays
- **STRING_AGG()**: Concatenate multiple secondary diagnoses
- **MAX()**: Get single principal diagnosis
- **Remove redundant JOINs**: Eliminate unnecessary table references

## Files Modified
- `src/main/resources/db/reports_sql/sub_second_materialized_views.sql` - Main MV definitions
- `test_diagnosis_fix.sql` - Test script for verification

## Remaining MVs to Fix
Based on analysis, these MVs likely need similar fixes:

### **High Priority** (likely have duplicates):
1. `mv_doctor_denial_summary` - May have diagnosis JOIN duplicates
2. `mv_claim_details_complete` - Complex JOINs, likely duplicates
3. `mv_rejected_claims_summary` - May have remittance/diagnosis duplicates
4. `mv_remittance_advice_summary` - Remittance aggregation needed

### **Medium Priority** (check for issues):
5. `mv_claims_monthly_agg` - Monthly aggregation, check for duplicates
6. `mv_resubmission_cycles` - Cycle-based, may need aggregation

### **Lower Priority** (likely OK):
7. `mv_balance_amount_summary` - Already working, may be fine
8. `mv_claim_summary_payerwise` - ✅ FIXED
9. `mv_claim_summary_encounterwise` - ✅ FIXED
10. `mv_remittances_resubmission_activity_level` - ✅ FIXED

## Diagnostic Tools Available
- `diagnose_duplicates.sql` - Check for duplicate key violations
- `test_diagnosis_fix.sql` - Template for testing fixes
- `MATERIALIZED_VIEWS_ANALYSIS_REPORT.md` - Comprehensive analysis

## Next Steps for New Chat
1. **Run diagnostics** on remaining MVs to identify duplicates
2. **Apply aggregation patterns** learned from successful fixes
3. **Test each fix** before moving to next MV
4. **Document changes** in code comments
5. **Verify claim lifecycle adherence** in each MV

## Key Patterns to Apply

### **Remittance Aggregation Pattern**:
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

### **Diagnosis Aggregation Pattern**:
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

### **Cycle Aggregation Pattern**:
```sql
resubmission_cycles_aggregated AS (
    SELECT 
        ce.claim_key_id,
        (ARRAY_AGG(cr.resubmission_type ORDER BY ce.event_time))[1] as first_resubmission_type,
        (ARRAY_AGG(ce.event_time ORDER BY ce.event_time))[1] as first_resubmission_date,
        -- ... up to 5 cycles
    FROM claims.claim_event ce
    LEFT JOIN claims.claim_resubmission cr ON ce.id = cr.claim_event_id
    WHERE ce.type = 2
    GROUP BY ce.claim_key_id
)
```

## Error Patterns to Watch For
- `ERROR: duplicate key value violates unique constraint`
- `ERROR: could not create unique index`
- Ambiguous column references in CTEs
- Cartesian products from multiple JOINs

## Success Criteria
- All MVs refresh without duplicate key errors
- MVs return expected row counts
- Claim lifecycle properly represented
- Performance maintained through proper aggregation
