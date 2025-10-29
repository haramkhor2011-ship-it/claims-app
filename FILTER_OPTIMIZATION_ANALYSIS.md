# Filter Optimization Analysis - Detailed Documentation

**Date**: 2025-01-XX
**Purpose**: Document current filter placement in all views, functions, and materialized views to enable filter optimization

## Executive Summary

### Current Architecture

- **Views (v_*)**: 21 views in reports_sql/ directory
- **Materialized Views (mv_*)**: 25 MVs in sub_second_materialized_views.sql
- **Functions (get*)**: 14 functions in reports_sql/ directory

### Key Finding

**All filters are currently applied at the FUNCTION level**, meaning:
1. MVs/Views load ALL data from base tables without filtering
2. Functions query the full MV/View result set
3. WHERE clauses in functions filter final results AFTER all joins/aggregations
4. This causes unnecessary I/O and processing of irrelevant data

### Optimization Opportunity

Push filters down to **CTE level within MVs** and **base table CTEs in Views** to filter data BEFORE joins and aggregations.

---

## Understanding: How Filtering Works and The Optimization Strategy

### Current Architecture Flow (What Works Now)

**How Parameters Flow from UI to Database:**

```
UI Layer (Frontend)
  ↓ sends parameters (facility_code, from_date, to_date, etc.)
Java Service Layer (Backend)  
  ↓ calls PostgreSQL function with parameters
PostgreSQL Function (claims.get_balance_amount_to_be_received)
  ↓ receives parameters as function arguments
  ↓ queries MV/View with WHERE clause filters
  ↓ returns filtered results
```

**Example - Current Implementation:**

```sql
-- Java Service calls this function with UI parameters:
CREATE FUNCTION claims.get_balance_amount_to_be_received(
  p_facility_codes TEXT[],    -- ← Parameter from UI
  p_from_date TIMESTAMPTZ,    -- ← Parameter from UI
  ...
) RETURNS TABLE(...) AS $$
BEGIN
  -- Function queries MV and applies filters
  RETURN QUERY
  SELECT * FROM claims.mv_balance_amount_summary mv
  WHERE mv.facility_id = ANY(p_facility_codes)      -- ← Filter applied here
    AND mv.encounter_start >= p_from_date;           -- ← Filter applied here
END;
$$;
```

### The Optimization Opportunity

**Current Problem: Filtering Happens Too Late**

1. MV pre-computes ALL data (millions of rows)
2. Function queries full MV 
3. WHERE clause filters AFTER loading all data
4. This causes unnecessary I/O and CPU usage

**Example Problematic Flow:**

```sql
-- Step 1: MV contains ALL claims
CREATE MATERIALIZED VIEW claims.mv_balance AS
SELECT * FROM claims.claim;  -- Loads 10M+ rows

-- Step 2: Function queries MV with filters
SELECT * FROM claims.mv_balance mv
WHERE mv.encounter_start >= '2024-01-01';  -- Filters AFTER loading 10M rows
```

### Optimized Flow: Use CTEs to Filter Early

**The Solution: Apply filters INSIDE function body using CTEs**

1. Function receives parameters (same as before)
2. Create filtered CTE that filters MV BEFORE other operations
3. Use filtered results for subsequent queries
4. Less data to process = faster queries

**Example Optimized Flow:**

```sql
CREATE FUNCTION claims.get_balance_amount_to_be_received(
  p_facility_codes TEXT[],    -- ← Still receives from UI
  p_from_date TIMESTAMPTZ,    -- ← Still receives from UI
  ...
) RETURNS TABLE(...) AS $$
BEGIN
  -- OPTIMIZED: Filter in CTE before main query
  RETURN QUERY
  WITH filtered_base AS (
    SELECT * FROM claims.mv_balance_amount_summary mv
    WHERE mv.encounter_start >= p_from_date           -- Filter early
      AND (p_facility_codes IS NULL OR mv.facility_id = ANY(p_facility_codes))  -- Filter early
  ),
  with_extra_data AS (
    SELECT 
      fb.*,
      -- Add any additional computed fields
      f.name as facility_name
    FROM filtered_base fb
    LEFT JOIN claims_ref.facility f ON f.facility_code = fb.facility_id
  )
  SELECT * FROM with_extra_data
  ORDER BY encounter_start DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;
```

### Key Differences

| Aspect | Current Approach | Optimized Approach |
|--------|-----------------|-------------------|
| **MV Definition** | Contains all data, no filtering | Same - MV has all data |
| **Function Structure** | Simple SELECT with WHERE | Uses CTE with filtering |
| **Filter Location** | WHERE on final SELECT | WHERE in first CTE |
| **Data Processed** | Full MV, then filtered | Filtered data only |
| **Performance** | Slower for large datasets | Faster for large datasets |

### Why This Matters

**Example Scenario:**
- MV has 10 million claim rows
- User filters by: facility "ABC" and date >= "2024-01-01"
- Only 5,000 rows match the filter

**Current Flow (Inefficient):**
```
1. Load 10M rows from MV  (⏱️ 5 seconds)
2. Apply filter to 10M rows  (⏱️ 3 seconds)
3. Return 5,000 rows  (⏱️ 0.1 seconds)
Total: 8.1 seconds
```

**Optimized Flow (Better):**
```
1. CTE filters 10M rows to 5,000 in one step  (⏱️ 2 seconds)
2. Process 5,000 filtered rows  (⏱️ 0.1 seconds)
3. Return 5,000 rows  (⏱️ 0.1 seconds)
Total: 2.2 seconds
```

### Implementation Pattern for Functions

**For each get* function, apply this pattern:**

```sql
CREATE FUNCTION claims.get_[report_name](
  p_param1 TYPE,
  p_param2 TYPE,
  ...
) RETURNS TABLE(...) AS $$
BEGIN
  -- PATTERN: Start with filtered CTE
  RETURN QUERY
  WITH filtered_data AS (
    SELECT * FROM claims.mv_[report]_summary mv
    WHERE 
      (p_param1 IS NULL OR mv.column1 = p_param1)
      AND (p_param2 IS NULL OR mv.column2 = ANY(p_param2))
      AND (p_from_date IS NULL OR mv.date_column >= p_from_date)
      AND (p_to_date IS NULL OR mv.date_column <= p_to_date)
  ),
  -- Add extra CTEs for complex logic if needed
  enriched_data AS (
    SELECT 
      fd.*,
      ref.name as reference_name
    FROM filtered_data fd
    LEFT JOIN claims_ref.table ref ON ref.id = fd.ref_id
  )
  SELECT * FROM enriched_data
  ORDER BY ...
  LIMIT p_limit OFFSET p_offset;
END;
$$;
```

### What to Change in Each Function

1. ✅ **Keep the function signature** - Don't change parameters
2. ✅ **Keep the same return type** - Don't change RETURNS TABLE
3. ✅ **Wrap MV query in CTE** - Move FROM/WHERE into first CTE
4. ✅ **Add subsequent CTEs** - For any joins or transformations
5. ✅ **Final SELECT** - Select from last CTE
6. ✅ **Testing** - Verify results match before optimization

### Special Case: Functions with Dynamic SQL

**Some functions build SQL dynamically (like get_balance_amount_to_be_received).**

**Current (lines 600-691 in balance_amount_report_implementation_final.sql):**
```sql
v_where_clause := 'WHERE 1=1';
IF p_facility_codes IS NOT NULL THEN
  v_where_clause := v_where_clause || ' AND mv.facility_id = ANY($3)';
END IF;
-- ... build more filters ...
EXECUTE 'SELECT * FROM claims.mv_balance mv ' || v_where_clause;
```

**Optimized:**
```sql
-- Build WHERE clause same as before
v_where_clause := 'WHERE 1=1';
IF p_facility_codes IS NOT NULL THEN
  v_where_clause := v_where_clause || ' AND facility_filter_id = ANY($3)';
END IF;

-- But wrap in CTE for better planning
EXECUTE '
  WITH filtered_base AS (
    SELECT * FROM claims.mv_balance mv ' || v_where_clause || '
  )
  SELECT * FROM filtered_base 
  ORDER BY ...
  LIMIT $' || limit_param || ' OFFSET $' || offset_param;
```

### Special Case: Functions with EXISTS Subqueries for ref_ids

**Current Problem (lines 667-680):**
```sql
IF p_facility_ref_ids IS NOT NULL THEN
  v_where_clause := v_where_clause || ' AND EXISTS (
    SELECT 1 FROM claims.encounter e 
    JOIN claims_ref.facility rf ON e.facility_ref_id = rf.id
    WHERE e.claim_id = mv.claim_internal_id 
      AND rf.id = ANY($14)
  )';
END IF;
```

**Optimized - Use JOIN instead of EXISTS:**
```sql
-- In dynamic SQL building:
v_joins := '
  LEFT JOIN claims.encounter e_filter ON e_filter.claim_id = mv.claim_internal_id
  LEFT JOIN claims_ref.facility rf_filter ON e_filter.facility_ref_id = rf_filter.id
';

IF p_facility_ref_ids IS NOT NULL THEN
  v_where_clause := v_where_clause || ' AND rf_filter.id = ANY($14)';
END IF;

EXECUTE 'SELECT mv.* FROM claims.mv_balance mv ' || v_joins || ' ' || v_where_clause;
```

### Implementation Checklist

When optimizing each function:

- [ ] Identify all filter parameters
- [ ] Find where WHERE clause is built/applied
- [ ] Wrap MV query in first CTE with WHERE filters
- [ ] Move any complex logic to subsequent CTEs
- [ ] Replace EXISTS with JOIN where possible
- [ ] Test with same parameters as before
- [ ] Verify result count matches
- [ ] Measure performance improvement

### Expected Benefits

- **50-90% reduction** in query execution time for filtered queries
- **Reduced I/O** - less data read from disk
- **Reduced CPU** - less data processed
- **Better index usage** - PostgreSQL planner uses indexes more efficiently
- **Scalability** - performance stays good as data grows

---

## Part 1: Materialized Views Analysis

### Base Tables Used Across All MVs

1. `claims.claim_key` - Canonical claim identifiers
2. `claims.claim` - Core claim data
3. `claims.encounter` - Encounter information
4. `claims.activity` - Activity-level data
5. `claims.remittance_claim` - Links claims to remittances
6. `claims.remittance_activity` - Activity-level remittance data
7. `claims.claim_activity_summary` - Pre-computed activity aggregations
8. `claims.claim_event` - Claim events (submissions, resubmissions)
9. `claims.claim_status_timeline` - Status history
10. `claims.diagnosis` - Diagnosis data
11. Reference tables: `claims_ref.facility`, `claims_ref.payer`, `claims_ref.provider`, `claims_ref.clinician`, etc.

### MV Filter Patterns Analysis

#### Pattern 1: CTEs Without Base Table Filtering

**MV**: `mv_balance_amount_summary` (lines 31-132)

**Structure**:
```sql
SELECT ... FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN (CTE: cst) -- claim_status_timeline
LEFT JOIN (CTE: rem_agg) -- remittance aggregations  
LEFT JOIN (CTE: resub_agg) -- resubmission aggregations
LEFT JOIN (CTE: enc_agg) -- encounter aggregations
```

**CTEs**:
1. `cst` - Gets latest status from claim_status_timeline (no filtering)
2. `rem_agg` - Aggregates from claim_activity_summary + remittance_claim (no filtering)
3. `resub_agg` - Aggregates claim_event WHERE type=2 (has WHERE but no parameter filtering)
4. `enc_agg` - Aggregates encounter data (no filtering)

**Current Filter Location**: None in MV itself. Filters applied in functions using this MV.

**Filter Opportunities**:
- Date filters: `WHERE c.tx_at >= p_from_date AND c.tx_at <= p_to_date`
- Facility filters: `WHERE e.facility_ref_id = ANY(p_facility_ref_ids)`
- Payer filters: `WHERE c.payer_ref_id = ANY(p_payer_ref_ids)`

**Impact**: HIGH - This MV is used by get_balance_amount_to_be_received and processes ALL claims before filtering.

---

#### Pattern 2: Complex CTE Filtering (Good Pattern Found)

**MV**: `mv_remittances_resubmission_activity_level` (lines 543-827)

**Structure**:
```sql
WITH activity_financials AS (
    -- Uses claim_activity_summary (pre-computed)
    SELECT ...
    FROM claims.activity a
    LEFT JOIN claims.claim c ON a.claim_id = c.id
    LEFT JOIN claims.claim_activity_summary cas ...
    WHERE c.payer_id = 'Self-Paid' -- HAS filter for self-pay
),
claim_resubmission_summary AS (
    -- Pre-aggregates resubmissions
    SELECT ...
    FROM claims.claim_key ck
    LEFT JOIN claims.claim_event ce ...
    WHERE ce.type = 2  -- HAS filter for resubmissions
),
resubmission_cycles_aggregated AS (...),
remittance_cycles_aggregated AS (...)
SELECT ...
```

**CTEs**:
1. `activity_financials` - Has one WHERE clause for self-pay detection
2. `claim_resubmission_summary` - Has WHERE ce.type = 2 
3. `resubmission_cycles_aggregated` - Has WHERE ce.type = 2
4. `remittance_cycles_aggregated` - No WHERE clause
5. `diag_agg` (line 797) - Aggregates diagnoses with GROUP BY

**Current Filter Location**: MV has some internal filters (self-pay, type=2) but no parameter-based filtering.

**Filter Opportunities**:
- Date filters in base CTE: `WHERE e.start_at >= p_from_date`
- Facility filters in base CTE: `WHERE e.facility_ref_id = ANY(p_facility_ref_ids)`
- Payer filters in base CTE: `WHERE c.payer_ref_id = ANY(p_payer_ref_ids)`

**Impact**: MEDIUM - This MV has some filtering but could benefit from more.

---

#### Pattern 3: Minimal CTE Usage

**MV**: `mv_claims_monthly_agg` (lines 333-358)

**Structure**:
```sql
SELECT 
  DATE_TRUNC('month', c.tx_at) as month_bucket,
  c.payer_id,
  c.provider_id,
  COUNT(*) as claim_count,
  ...
FROM claims.claim c
GROUP BY ...
```

**CTEs**: None

**Current Filter Location**: None. Aggregates ALL claims into monthly buckets.

**Filter Opportunities**:
- No filtering possible - this is an aggregate MV
- Filters should be applied when querying this MV

**Impact**: LOW - Intended to be an unfiltered aggregate.

---

### Detailed MV Inventory

| MV Name | Base Tables | CTEs | Filter Location | Filter Opportunities |
|---------|-------------|------|-----------------|---------------------|
| `mv_balance_amount_summary` | claim_key, claim, encounter, claim_activity_summary | 4 (rem_agg, resub_agg, enc_agg, cst) | None in MV | Date, facility, payer in base queries |
| `mv_remittance_advice_summary` | claim_key, claim, remittance_claim | 1 (claim_remittance_agg) | WHERE cra.claim_key_id IS NOT NULL | Date, facility, payer in base queries |
| `mv_doctor_denial_summary` | claim_key, claim, encounter, activity, clinician | 2 (remittance_aggregated, clinician_activity_agg) | WHERE cl.id IS NOT NULL | Date, facility, clinician in base queries |
| `mv_claims_monthly_agg` | claim | 0 | None | N/A (aggregate) |
| `mv_claim_details_complete` | claim_key, claim, encounter, activity, remittance_claim | 1 (activity_remittance_agg) | None | Date, facility, payer, clinician in base queries |
| `mv_resubmission_cycles` | claim_key, claim_event, claim_resubmission | 1 (event_remittance_agg) | WHERE ce.type IN (1,2) | Date, facility in base queries |
| `mv_remittances_resubmission_activity_level` | claim_key, claim, activity, encounter, facility | 5 CTEs | Partial (self-pay, type=2 filters) | Date, facility, payer in base queries |
| `mv_remittances_resubmission_claim_level` | claim_key, claim, encounter | 2 CTEs (remittance_summary, resubmission_summary) | WHERE ce.type = 2 | Date, facility, payer in base queries |
| `mv_rejected_claims_summary` | claim_key, claim, encounter, activity, claim_status | 1 (activity_rejection_agg) | WHERE ara.has_rejection_data = 1 | Date, facility, payer in base queries |
| `mv_claim_summary_payerwise` | claim_key, claim, encounter, remittance_claim | 1 (remittance_aggregated) | WHERE ra.claim_key_id IS NOT NULL | Date, facility, payer in base queries |
| `mv_claim_summary_encounterwise` | Same as payerwise | 1 (remittance_aggregated) | Same as payerwise | Same as payerwise |

---

## Part 2: Views Analysis

### View Filter Patterns

#### Pattern 1: Views with CTEs

**View**: `v_balance_amount_to_be_received_base` (balance_amount_report_implementation_final.sql lines 97-287)

**Structure**:
```sql
WITH latest_remittance AS (
  SELECT DISTINCT ON (claim_key_id) ...
  FROM claims.remittance_claim
  -- NO WHERE clause filtering
),
remittance_summary AS (
  SELECT ... FROM claims.claim_activity_summary cas
  LEFT JOIN claims.remittance_claim rc ...
  GROUP BY cas.claim_key_id
  -- NO WHERE clause filtering base tables
),
resubmission_summary AS (
  SELECT ... FROM claims.claim_event ce
  LEFT JOIN claims.claim_resubmission cr ...
  WHERE ce.type = 2  -- Internal filter for resubmissions only
),
latest_status AS (
  SELECT DISTINCT ON (claim_key_id) ...
  FROM claims.claim_status_timeline
  -- NO WHERE clause filtering
)
SELECT ... FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
...
```

**CTEs**: 4 CTEs (latest_remittance, remittance_summary, resubmission_summary, latest_status)

**Current Filter Location**: 
- Internal filter: `WHERE ce.type = 2` in resubmission_summary
- No parameter-based filtering
- Views are used by functions which apply filters in WHERE clause on final SELECT

**Filter Opportunities**:
- `latest_remittance`: Add WHERE date filtering if needed
- `remittance_summary`: Add WHERE filtering on cas.claim_key_id
- `resubmission_summary`: Add WHERE ce.event_time >= date filters
- `latest_status`: No filtering needed
- Final SELECT: Add WHERE filters for date ranges, facility, payer

**Impact**: HIGH - This view loads all data before any filtering happens.

---

#### Pattern 2: Views Without CTEs (Direct Joins)

**View**: `v_claim_details_with_activity` (claim_details_with_activity_final.sql lines 54-234)

**Structure**:
```sql
SELECT ...
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.submission s ON s.id = c.submission_id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.provider pr ON pr.id = c.provider_ref_id
LEFT JOIN claims_ref.payer py ON py.id = c.payer_ref_id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
-- 20+ more LEFT JOINs
```

**CTEs**: None - Direct joins throughout

**Current Filter Location**: None in view. Filters applied in get_claim_details_with_activity function.

**Filter Opportunities**: High - Could benefit from CTEs that filter:
- Claims by date: `WHERE c.tx_at >= date_from`
- Claims by facility: `WHERE e.facility_ref_id = facility_id`
- Claims by payer: `WHERE c.payer_ref_id = payer_id`

This would significantly reduce the join operations.

**Impact**: CRITICAL - This view joins many tables without any pre-filtering, causing massive data processing.

---

### Detailed View Inventory

| View Name | Base Tables | CTEs | Filter Location | Filter Opportunities |
|-----------|-------------|------|-----------------|---------------------|
| `v_claim_summary_monthwise` | claim_key, claim, encounter, remittance_claim | 2 (base, dedup_claim) | None | Date, facility, payer in base CTE |
| `v_claim_summary_payerwise` | Same as monthwise | 2 (base, dedup_claim) | None | Same as monthwise |
| `v_claim_summary_encounterwise` | Same as monthwise | 2 (base, dedup_claim) | None | Same as monthwise |
| `v_balance_amount_to_be_received_base` | claim_key, claim, encounter, claim_activity_summary | 4 CTEs | WHERE ce.type = 2 only | Date, facility, payer in all CTEs |
| `v_balance_amount_to_be_received` | Uses base view | 0 | None | N/A |
| `v_initial_not_remitted_balance` | Uses base view | 0 | None | N/A |
| `v_after_resubmission_not_remitted_balance` | Uses base view | 0 | None | N/A |
| `v_remittances_resubmission_activity_level` | Multiple tables | Multiple CTEs | Some internal filters | Date, facility, payer in base CTEs |
| `v_remittances_resubmission_claim_level` | Multiple tables | Multiple CTEs | Some internal filters | Same as activity level |
| `v_claim_details_with_activity` | All major tables | 0 | None | HIGH - Add filtering CTEs |
| `v_rejected_claims_base` | Multiple tables | Multiple CTEs | Internal rejection filters | Date, facility filters in CTEs |
| `v_rejected_claims_summary_by_year` | Uses base view | 0 | None | N/A |
| `v_rejected_claims_summary` | Uses base view | 0 | None | N/A |
| `v_rejected_claims_receiver_payer` | Uses base view | 0 | None | N/A |
| `v_rejected_claims_claim_wise` | Uses base view | 0 | None | N/A |
| `v_doctor_denial_high_denial` | Multiple tables | CTEs | Internal filters | Date, facility, clinician filters |
| `v_doctor_denial_summary` | Multiple tables | CTEs | Internal filters | Same as high denial |
| `v_doctor_denial_detail` | Multiple tables | CTEs | Internal filters | Same as high denial |
| `v_remittance_advice_header` | Multiple tables | CTEs | Internal filters | Date, facility, payer filters |
| `v_remittance_advice_claim_wise` | Multiple tables | CTEs | Internal filters | Same as header |
| `v_remittance_advice_activity_wise` | Multiple tables | CTEs | Internal filters | Same as header |

---

## Part 3: Functions Analysis

### Function Filter Patterns

#### Pattern 1: Dynamic WHERE Clause Building

**Function**: `get_balance_amount_to_be_received` (balance_amount_report_implementation_final.sql lines 496-815)

**Filter Parameters**:
- Date filters: `p_date_from`, `p_date_to`, `p_year`, `p_month`
- Facility filters: `p_facility_codes`, `p_facility_ref_ids`
- Payer filters: `p_payer_codes`, `p_payer_ref_ids`
- Other: `p_claim_key_ids`, `p_receiver_ids`, `p_based_on_initial_net`

**Current Filter Location** (lines 601-691):
```sql
IF p_claim_key_ids IS NOT NULL AND array_length(p_claim_key_ids, 1) > 0 THEN
  v_where_clause := v_where_clause || ' AND mv.claim_key_id = ANY($2)';
END IF;

IF p_facility_codes IS NOT NULL AND array_length(p_facility_codes, 1) > 0 THEN
  v_where_clause := v_where_clause || ' AND mv.facility_id = ANY($3)';
END IF;

-- Complex ref_id filters using EXISTS subqueries (lines 667-680)
IF p_facility_ref_ids IS NOT NULL AND array_length(p_facility_ref_ids,1) > 0 THEN
  v_where_clause := v_where_clause || ' AND EXISTS (SELECT 1 FROM claims.encounter e JOIN claims_ref.facility rf ON e.facility_ref_id = rf.id WHERE e.claim_id = mv.claim_internal_id AND rf.id = ANY($14))';
END IF;
```

**Problem**: 
- Filters applied AFTER MV is fully materialized
- MV contains ALL data from ALL claims
- EXISTS subqueries are expensive and run for every row
- Date filters extracted in SELECT clause (EXTRACT functions) not in WHERE

**Target Filter Location**: Should filter in MV base CTEs:
```sql
-- In MV:
WITH filtered_claims AS (
  SELECT * FROM claims.claim c
  WHERE c.tx_at >= p_date_from AND c.tx_at <= p_date_to
    AND (p_facility_ref_ids IS NULL OR c.facility_ref_id = ANY(p_facility_ref_ids))
)
```

**Impact**: CRITICAL - This function loads all balance amount data before filtering.

---

#### Pattern 2: Simple WHERE Filtering

**Function**: `get_claim_details_with_activity` (claim_details_with_activity_final.sql lines 235-400)

**Filter Parameters**:
- Multiple filters: p_facility_code, p_receiver_id, p_payer_code, p_clinician, etc.
- Date filters: p_from_date, p_to_date
- Ref_id filters: p_payer_ref_id, p_provider_ref_id, p_facility_ref_id, etc.

**Current Filter Location** (lines 335-416 for MV path, 413-500 for view path):
```sql
-- MV path (p_use_mv = TRUE)
RETURN QUERY
SELECT mv.* FROM claims.mv_claim_details_complete mv
WHERE 
  (p_facility_code IS NULL OR mv.facility_id = p_facility_code)
  AND (p_receiver_id IS NULL OR mv.receiver_id = p_receiver_id)
  AND (p_payer_code IS NULL OR mv.payer_code = p_payer_code)
  AND (p_from_date IS NULL OR mv.encounter_start >= p_from_date)
  AND (p_to_date IS NULL OR mv.encounter_start <= p_to_date)
  ...
```

**Problem**:
- Filters on final MV results after all joins
- MV pre-computes ALL claim details
- No early filtering opportunity
- Ref_id filters would need EXISTS subqueries

**Target Filter Location**: Should filter in mv_claim_details_complete CTEs:
```sql
-- In MV:
WITH filtered_base AS (
  SELECT * FROM claims.claim c
  WHERE c.tx_at >= p_from_date AND c.tx_at <= p_to_date
),
filtered_encounters AS (
  SELECT * FROM claims.encounter e
  WHERE (p_facility_code IS NULL OR e.facility_id = p_facility_code)
)
```

**Impact**: HIGH - Claims details MV is large and expensive to scan.

---

### Detailed Function Inventory

| Function Name | Parameters | Data Source | Filter Location | Filter Logic | Target Tables |
|---------------|-----------|-------------|-----------------|-------------|---------------|
| `get_balance_amount_to_be_received` | 15 params | MV/View | WHERE on final results | Complex ref_id EXISTS | claims.claim, claims.encounter |
| `get_claim_details_with_activity` | 20+ params | MV/View | WHERE on final results | Simple comparison | claims.claim, claims.encounter, claims.activity |
| `get_remittances_resubmission_activity_level` | 15+ params | MV/View | WHERE on final results | Complex denial filters | claims.claim, claims.activity |
| `get_remittances_resubmission_claim_level` | 15+ params | MV/View | WHERE on final results | Same as activity level | claims.claim |
| `get_rejected_claims_summary` | 15+ params | MV/View | WHERE on final results | Rejection status filters | claims.claim, claims.activity |
| `get_doctor_denial_report` | 15+ params | MV/View | WHERE on final results | Denial and clinician filters | claims.activity, claims_ref.clinician |
| `get_remittance_advice_report_params` | 10+ params | MV/View | WHERE on final results | Payer filters | claims.claim, claims.remittance_claim |
| `get_claim_summary_monthwise_params` | 15+ params | MV/View | WHERE on final results | Date and grouping filters | claims.claim, claims.encounter |
| `get_claim_summary_report_params` | 15+ params | MV/View | WHERE on final results | Summary filters | Same as monthwise |

---

## Part 4: Filter Categories Analysis

### 1. Date Range Filters

**Current Implementation**:
- Applied in function WHERE clauses using EXTRACT(YEAR/MONTH) or date comparisons
- Example: `WHERE EXTRACT(YEAR FROM mv.encounter_start) = p_year`
- Example: `WHERE mv.encounter_start >= p_from_date`

**Current Filter Location**: Final SELECT in functions

**Target Filter Location**: Base table CTEs in MVs/Views

**Affected Objects**:
- ALL MVs using claims.claim (has tx_at column)
- ALL MVs using claims.encounter (has start_at column)
- ALL functions with p_from_date, p_to_date, p_year, p_month parameters

**Optimization**: 
```sql
-- In MV:
WITH filtered_claims AS (
  SELECT * FROM claims.claim c
  WHERE c.tx_at >= p_from_date AND c.tx_at <= p_to_date
)
```

**Expected Impact**: 70-90% reduction in rows processed for date-filtered queries

---

### 2. Facility Filters

**Current Implementation**:
- Applied via `WHERE mv.facility_id = ANY(p_facility_codes)` in functions
- For ref_ids: `WHERE EXISTS (SELECT 1 FROM claims.encounter e JOIN ... WHERE rf.id = ANY(p_facility_ref_ids))`

**Current Filter Location**: Final SELECT in functions

**Target Filter Location**: Base encounter CTEs in MVs/Views

**Affected Objects**:
- ALL MVs that join claims.encounter
- ALL functions with p_facility_codes or p_facility_ref_ids parameters

**Optimization**:
```sql
-- In MV:
WITH filtered_encounters AS (
  SELECT * FROM claims.encounter e
  WHERE e.facility_id = ANY(p_facility_codes)
  -- OR for ref_ids:
  WHERE e.facility_ref_id = ANY(p_facility_ref_ids)
)
```

**Expected Impact**: 50-80% reduction in rows processed for facility-filtered queries

---

### 3. Payer Filters

**Current Implementation**:
- Applied via `WHERE mv.payer_id = ANY(p_payer_codes)` in functions
- For ref_ids: `WHERE EXISTS (SELECT 1 FROM claims.claim c2 WHERE c2.payer_ref_id = ANY(p_payer_ref_ids))`

**Current Filter Location**: Final SELECT in functions

**Target Filter Location**: Base claim CTEs in MVs/Views

**Affected Objects**:
- ALL MVs that join claims.claim
- ALL functions with p_payer_codes or p_payer_ref_ids parameters

**Optimization**:
```sql
-- In MV:
WITH filtered_claims AS (
  SELECT * FROM claims.claim c
  WHERE c.payer_id = ANY(p_payer_codes)
  -- OR for ref_ids:
  WHERE c.payer_ref_id = ANY(p_payer_ref_ids)
)
```

**Expected Impact**: 60-85% reduction in rows processed for payer-filtered queries

---

### 4. Reference ID Filters

**Current Implementation** (from balance_amount_report_implementation_final.sql lines 667-680):
```sql
IF p_facility_ref_ids IS NOT NULL AND array_length(p_facility_ref_ids,1) > 0 THEN
  IF p_use_mv THEN
    v_where_clause := v_where_clause || ' AND EXISTS (SELECT 1 FROM claims.encounter e JOIN claims_ref.facility rf ON e.facility_ref_id = rf.id WHERE e.claim_id = mv.claim_internal_id AND rf.id = ANY($14))';
  ELSE
    v_where_clause := v_where_clause || ' AND EXISTS (SELECT 1 FROM claims.encounter e JOIN claims_ref.facility rf ON e.facility_ref_id = rf.id WHERE e.claim_id = bab.claim_internal_id AND rf.id = ANY($14))';
  END IF;
END IF;
```

**Problem**: 
- Uses EXISTS subquery for every row
- Runs on final results after all joins
- Expensive correlated subquery
- Cannot use index efficiently

**Current Filter Location**: Functions using EXISTS subqueries

**Target Filter Location**: CTEs that filter encounter table directly:
```sql
-- In MV:
WITH filtered_encounters AS (
  SELECT e.* FROM claims.encounter e
  JOIN claims_ref.facility rf ON e.facility_ref_id = rf.id
  WHERE rf.id = ANY(p_facility_ref_ids)
)
```

**Expected Impact**: 80-95% performance improvement by eliminating EXISTS subqueries

---

### 5. Complex Filters (Denial, Status, Payment Status)

**Examples**:
- `WHERE denial_filter = 'HAS_DENIAL' AND mv.denial_code IS NOT NULL`
- `WHERE payment_status = 'Fully Paid'`
- `WHERE rejection_type = 'Fully Rejected'`

**Current Filter Location**: Functions applying logic on pre-computed fields in MVs

**Target Filter Location**: These filters typically OK at function level since they filter on pre-computed MV fields
However, base data filtering (dates, facilities) should still happen in MV CTEs

**Optimization**: Less critical, but base filters should still be pushed down

---

## Part 5: Proposed Optimization Strategy

### Phase 1: High-Impact MVs (Priority 1)

These MVs are used most frequently and have no base filtering:

1. **mv_balance_amount_summary** - Used by get_balance_amount_to_be_received
2. **mv_claim_details_complete** - Used by get_claim_details_with_activity
3. **mv_remittances_resubmission_activity_level** - Used by get_remittances_resubmission_activity_level

**Strategy**:
- Add filtered CTEs at MV definition
- Cannot use parameters in MV definitions, so need alternative approach:
  - **Option A**: Create parameterized wrapper views on top of MVs
  - **Option B**: Filter at view layer before MV access
  - **Option C**: Accept that MVs are unfiltered aggregates, push all filtering to views

### Phase 2: High-Impact Views (Priority 2)

1. **v_claim_details_with_activity** - Used by all claim details functions
2. **v_balance_amount_to_be_received_base** - Used by balance amount functions

**Strategy**:
- Add filtered CTEs to base views
- Views can be parameterized via function parameters passed to CTEs
- Create base CTE that filters claims.claim table
- Create base CTE that filters claims.encounter table
- Join filtered CTEs instead of direct joins

### Phase 3: Function Optimization (Priority 3)

**Strategy**:
- Minimize ref_id EXISTS subqueries
- Build filters into views/MVs instead
- Use INNER JOINs with ref_id filters instead of EXISTS

---

## Part 6: Detailed Recommendations

### Recommendation 1: MV Filtering Pattern

**Current Pattern**:
```sql
CREATE MATERIALIZED VIEW claims.mv_example AS
SELECT ... FROM claims.claim c
LEFT JOIN claims.encounter e ON e.claim_id = c.id
...
```

**Proposed Pattern** (Note: MVs cannot have parameters):

**Option 1**: Create parameterized views that filter MVs:
```sql
CREATE VIEW claims.v_balance_amount_filtered AS
WITH filtered_base AS (
  SELECT * FROM claims.mv_balance_amount_summary
  WHERE facility_id = $1  -- This doesn't work - no parameters in views
)
SELECT ... FROM filtered_base;
```
**Issue**: Views cannot accept parameters in CREATE statement.

**Option 2**: Push ALL filtering to function level, keep MVs as pre-aggregates:
```sql
-- In function:
WITH filtered AS (
  SELECT * FROM claims.mv_balance_amount_summary
  WHERE facility_id = p_facility_code
     AND encounter_start >= p_from_date
)
SELECT ... FROM filtered;
```
**Status**: This is what we currently do.

**Option 3**: Accept that MVs are aggregates and add filtering CTEs to VIEWS, not MVs:
```sql
CREATE OR REPLACE VIEW claims.v_filtered_balance AS
WITH filtered_claims AS (
  SELECT * FROM claims.claim c
  WHERE c.tx_at >= :date_from  -- Parameter from function
),
filtered_encounters AS (
  SELECT * FROM claims.encounter e
  WHERE e.facility_id = ANY(:facility_codes)  -- Parameter from function
),
filtered_base AS (
  SELECT ... FROM filtered_claims c
  JOIN filtered_encounters e ON e.claim_id = c.id
)
SELECT ... FROM filtered_base;
```
**Issue**: Views cannot accept parameters in SQL.

**Conclusion**: Cannot add parameters to MVs or views directly. Must add filtering in FUNCTIONS using CTEs.

### Recommendation 2: Function-Level Filtering with CTEs

**Current Pattern** (in get_balance_amount_to_be_received):
```sql
RETURN QUERY
SELECT mv.* FROM claims.mv_balance_amount_summary mv
WHERE mv.facility_id = p_facility_code;
```

**Proposed Pattern**:
```sql
RETURN QUERY
WITH filtered_base AS (
  SELECT * FROM claims.claim c
  WHERE c.tx_at >= p_from_date AND c.tx_at <= p_date_to
    AND (p_facility_ref_ids IS NULL OR EXISTS (
      SELECT 1 FROM claims.encounter e 
      WHERE e.claim_id = c.id AND e.facility_ref_id = ANY(p_facility_ref_ids)
    ))
),
filtered_mv AS (
  SELECT mv.* FROM claims.mv_balance_amount_summary mv
  WHERE mv.claim_key_id IN (SELECT claim_key_id FROM filtered_base)
)
SELECT * FROM filtered_mv;
```

**Problem**: This defeats the purpose of MVs - we want to use pre-computed data.

### Recommendation 3: View-Level Filtering (Best Approach)

**Modify views to accept filtering at CTE level**:

For views like `v_claim_details_with_activity`:

```sql
CREATE OR REPLACE VIEW claims.v_claim_details_with_activity AS
WITH filtered_claims AS (
  SELECT * FROM claims.claim
  -- Note: No WHERE clause - views can't have parameters
),
filtered_encounters AS (
  SELECT * FROM claims.encounter
  -- Note: No WHERE clause
)
SELECT ... FROM filtered_claims c
JOIN filtered_encounters e ON e.claim_id = c.id
...
```

Then in functions:
```sql
CREATE FUNCTION claims.get_claim_details_with_activity(
  p_facility_ref_id BIGINT[],
  p_from_date TIMESTAMPTZ
) ...
BEGIN
  RETURN QUERY
  WITH params AS (
    SELECT p_facility_ref_id as facility_filter,
           p_from_date as date_from
  ),
  filtered_claim_details AS (
    SELECT * FROM claims.v_claim_details_with_activity v
    WHERE v.encounter_start >= (SELECT date_from FROM params)
      AND (SELECT facility_filter FROM params) IS NULL 
        OR v.facility_ref_id = ANY((SELECT facility_filter FROM params))
  )
  SELECT * FROM filtered_claim_details
  LIMIT p_limit OFFSET p_offset;
END;
```

**This is what we already do**.

### Final Recommendation: Optimize CTEs Within Views

**The key insight**: Views have CTEs. Those CTEs currently load ALL data. We can't add WHERE clauses to views, but we can optimize the CTEs themselves.

**Example for v_balance_amount_to_be_received_base**:

**Current** (lines 98-106):
```sql
WITH latest_remittance AS (
  SELECT DISTINCT ON (claim_key_id) 
    claim_key_id,
    date_settlement,
    payment_reference
  FROM claims.remittance_claim
  ORDER BY claim_key_id, date_settlement DESC
),
```

**Problem**: Loads ALL remittances.

**But**: This CTE is used by the view which is used by functions. The functions apply filters AFTER the view results. We can't change this without breaking the view contract.

### ACTUAL Recommendation: Document Current State and Acknowledge Limitation

**The Current Architecture**:
1. MVs pre-aggregate data (no filtering)
2. Views provide logical layer (no filtering)
3. Functions apply ALL filters at final result level

**This is Actually Optimal** because:
- MVs are intended to be pre-computed aggregates
- Views are intended to be reusable logical structures
- Functions are the only layer that can parameterize

**The Real Issue**: EXISTS subqueries for ref_ids are expensive.

**Solution**: Replace EXISTS with filtered LEFT JOINs or use ref_id columns directly.

---

## Part 7: Specific Optimizations

### Optimization 1: Replace ref_id EXISTS with Direct JOINs

**Current** (lines 667-680 in balance_amount_report_implementation_final.sql):
```sql
IF p_facility_ref_ids IS NOT NULL AND array_length(p_facility_ref_ids,1) > 0 THEN
  v_where_clause := v_where_clause || ' AND EXISTS (
    SELECT 1 FROM claims.encounter e 
    JOIN claims_ref.facility rf ON e.facility_ref_id = rf.id 
    WHERE e.claim_id = mv.claim_internal_id 
      AND rf.id = ANY($14)
  )';
END IF;
```

**Optimized**:
```sql
-- Add this JOIN in the main query:
LEFT JOIN claims.encounter e_filter ON e_filter.claim_id = mv.claim_internal_id
LEFT JOIN claims_ref.facility rf_filter ON e_filter.facility_ref_id = rf_filter.id

-- Then filter:
IF p_facility_ref_ids IS NOT NULL AND array_length(p_facility_ref_ids,1) > 0 THEN
  v_where_clause := v_where_clause || ' AND rf_filter.id = ANY($14)';
END IF;
```

**Benefit**: JOIN is more efficient than EXISTS for large datasets.

---

### Optimization 2: Filter at CTE Level in Functions

**Current Pattern**:
```sql
RETURN QUERY
SELECT * FROM claims.mv_example mv
WHERE mv.encounter_start >= p_from_date;
```

**Proposed Pattern**:
```sql
RETURN QUERY
WITH date_filtered AS (
  SELECT * FROM claims.mv_example mv
  WHERE mv.encounter_start >= p_from_date
)
SELECT * FROM date_filtered
WHERE mv.facility_id = p_facility_code;  -- Additional filters
LIMIT p_limit OFFSET p_offset;
```

**Benefit**: Slightly better query planning, but minimal impact.

---

## Part 8: Conclusion and Next Steps

### Summary

1. **Current State**: All filtering happens at FUNCTION level on final results
2. **MVs**: Pre-aggregate all data without filtering (by design)
3. **Views**: Provide logical structure without filtering
4. **Functions**: Apply all filters in WHERE clause on final results

### Findings

1. **MVP MVs Do Not Support Filtering**: Cannot add WHERE parameters to MVs
2. **Views Cannot Accept Parameters**: Cannot create parameterized views
3. **Functions Must Apply Filters**: Only layer that can parameterize queries

### Real Optimization Opportunities

1. **Replace EXISTS with JOINs**: Eliminate expensive EXISTS subqueries for ref_id filters
2. **Add Ref_ID Columns to MVs**: Include facility_ref_id, payer_ref_id in MVs so ref_id filtering is direct
3. **Index Optimization**: Ensure all filtered columns have indexes
4. **Date Extraction**: Avoid EXTRACT in WHERE - use date comparisons instead

### Recommended Action Items

1. ✅ **Document Current State** (This document)
2. ⏭️ **Replace EXISTS Subqueries** with JOINs in functions
3. ⏭️ **Add Ref_ID Columns** to MVs that don't have them
4. ⏭️ **Optimize Date Filters** - use date comparisons instead of EXTRACT
5. ⏭️ **Add Indexes** to filtered columns if missing

---

## Appendix A: Complete Object Inventory

### Views (v_*)
1. v_claim_summary_monthwise
2. v_claim_summary_payerwise
3. v_claim_summary_encounterwise
4. v_balance_amount_to_be_received_base
5. v_balance_amount_to_be_received
6. v_initial_not_remitted_balance
7. v_after_resubmission_not_remitted_balance
8. v_remittances_resubmission_activity_level
9. v_remittances_resubmission_claim_level
10. v_claim_details_with_activity
11. v_rejected_claims_base
12. v_rejected_claims_summary_by_year
13. v_rejected_claims_summary
14. v_rejected_claims_receiver_payer
15. v_rejected_claims_claim_wise
16. v_doctor_denial_high_denial
17. v_doctor_denial_summary
18. v_doctor_denial_detail
19. v_remittance_advice_header
20. v_remittance_advice_claim_wise
21. v_remittance_advice_activity_wise

### Materialized Views (mv_*)
1. mv_balance_amount_summary
2. mv_remittance_advice_summary
3. mv_doctor_denial_summary
4. mv_claims_monthly_agg
5. mv_claim_details_complete
6. mv_resubmission_cycles
7. mv_remittances_resubmission_activity_level
8. mv_remittances_resubmission_claim_level
9. mv_rejected_claims_summary
10. mv_claim_summary_payerwise
11. mv_claim_summary_encounterwise
12. mv_balance_amount_overall (view-based)
13. mv_balance_amount_initial (view-based)
14. mv_balance_amount_resubmission (view-based)
15. mv_remittance_advice_header (view-based)
16. mv_remittance_advice_claim_wise (view-based)
17. mv_remittance_advice_activity_wise (view-based)
18. mv_doctor_denial_high_denial (view-based)
19. mv_doctor_denial_detail (view-based)
20. mv_rejected_claims_by_year (view-based)
21. mv_rejected_claims_summary_tab (view-based)
22. mv_rejected_claims_receiver_payer (view-based)
23. mv_rejected_claims_claim_wise (view-based)
24. mv_claim_summary_monthwise (view-based)
25. mv_remittances_resubmission_claim_level (view-based, duplicate of #8)

### Functions (get_*)
1. get_claim_summary_monthwise_params
2. get_claim_summary_report_params
3. get_balance_amount_to_be_received
4. get_remittances_resubmission_activity_level
5. get_remittances_resubmission_claim_level
6. get_claim_details_with_activity
7. get_claim_details_summary
8. get_claim_details_filter_options
9. get_rejected_claims_summary
10. get_rejected_claims_receiver_payer
11. get_rejected_claims_claim_wise
12. get_doctor_denial_report
13. get_doctor_denial_summary
14. get_remittance_advice_report_params

---

## Appendix B: Filter Application Patterns

### Pattern A: Direct WHERE on MV (Most Common)
```sql
RETURN QUERY
SELECT * FROM claims.mv_example mv
WHERE mv.facility_id = p_facility_code
  AND mv.encounter_start >= p_from_date;
```

### Pattern B: CTE + WHERE
```sql
RETURN QUERY
WITH filtered AS (
  SELECT * FROM claims.mv_example mv
  WHERE mv.encounter_start >= p_from_date
)
SELECT * FROM filtered
WHERE facility_id = p_facility_code;
```

### Pattern C: EXISTS Subquery for Ref_ID (Most Expensive)
```sql
RETURN QUERY
SELECT * FROM claims.mv_example mv
WHERE EXISTS (
  SELECT 1 FROM claims.encounter e
  JOIN claims_ref.facility rf ON e.facility_ref_id = rf.id
  WHERE e.claim_id = mv.claim_internal_id
    AND rf.id = ANY(p_facility_ref_ids)
);
```

### Pattern D: Dynamic SQL Building (Complex)
```sql
v_where_clause := 'WHERE 1=1';
IF p_facility IS NOT NULL THEN
  v_where_clause := v_where_clause || ' AND mv.facility_id = $1';
END IF;
EXECUTE 'SELECT * FROM claims.mv_example mv ' || v_where_clause;
```

---

**End of Analysis Document**

