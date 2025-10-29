# Materialized Views Verification

**Generated:** 2025-10-25 18:57:22

## Summary

- **Source Files:** ../src/main/resources/db/reports_sql/sub_second_materialized_views.sql
- **Docker File:** ../docker/db-init/07-materialized-views.sql
- **Total Objects Expected:** 36
- **Total Objects Found:** 26
- **Completeness:** 52.3%
- **Overall Accuracy:** 24.7%

## Objects Overview

| Object Name | Type | Status | Completeness | Accuracy | Notes |
|-------------|------|--------|--------------|----------|-------|
| claims.mv_claims_monthly_agg | MATERIALIZED_VIEW | ⚠ | 10.0% | 7.1% | 5 differences |
| claims.mv_remittances_resubmission_activity_level | MATERIALIZED_VIEW | ⚠ | 5.9% | 7.7% | 9 differences |
| claims.mv_rejected_claims_summary_tab | MATERIALIZED_VIEW | ⚠ | 100.0% | 14.8% | 3 differences |
| refresh_remittance_advice_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_rejected_claims_summary | MATERIALIZED_VIEW | ⚠ | 14.3% | 9.2% | 8 differences |
| claims.mv_claim_summary_encounterwise | MATERIALIZED_VIEW | ⚠ | 17.6% | 8.0% | 9 differences |
| claims.mv_balance_amount_overall | MATERIALIZED_VIEW | ✓ | 100.0% | 91.0% | Perfect match |
| refresh_doctor_denial_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_balance_amount_resubmission | MATERIALIZED_VIEW | ⚠ | 100.0% | 79.7% | 1 differences |
| claims.mv_claim_summary_payerwise | MATERIALIZED_VIEW | ⚠ | 17.6% | 8.7% | 9 differences |
| claims.mv_rejected_claims_by_year | MATERIALIZED_VIEW | ⚠ | 100.0% | 13.3% | 4 differences |
| refresh_payerwise_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_doctor_denial_summary | MATERIALIZED_VIEW | ⚠ | 0.0% | 9.3% | 8 differences |
| claims.mv_doctor_denial_high_denial | MATERIALIZED_VIEW | ⚠ | 100.0% | 84.4% | 1 differences |
| claims.mv_resubmission_cycles | MATERIALIZED_VIEW | ⚠ | 25.0% | 5.2% | 9 differences |
| claims.mv_balance_amount_summary | MATERIALIZED_VIEW | ✓ | 93.9% | 100.0% | Perfect match |
| claims.mv_remittances_resubmission_claim_level | MATERIALIZED_VIEW | ⚠ | 100.0% | 6.8% | 5 differences |
| claims.mv_remittance_advice_summary | MATERIALIZED_VIEW | ✓ | 85.0% | 100.0% | Perfect match |
| refresh_claim_details_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_claim_summary_monthwise | MATERIALIZED_VIEW | ✓ | 100.0% | 91.6% | Perfect match |
| claims.mv_rejected_claims_receiver_payer | MATERIALIZED_VIEW | ⚠ | 100.0% | 18.3% | 3 differences |
| refresh_monthly_agg_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| FUNCTION | COMMENT | ✗ | 0.0% | 0.0% | Missing from Docker |
| refresh_remittances_resubmission_activity_level_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| claims.mv_doctor_denial_detail | MATERIALIZED_VIEW | ⚠ | 100.0% | 7.7% | 4 differences |
| claims.mv_remittance_advice_header | MATERIALIZED_VIEW | ⚠ | 100.0% | 21.3% | 2 differences |
| claims.mv_rejected_claims_claim_wise | MATERIALIZED_VIEW | ⚠ | 100.0% | 12.0% | 4 differences |
| IF | INDEX | ✓ | 100.0% | 62.9% | Perfect match |
| claims.mv_remittance_advice_claim_wise | MATERIALIZED_VIEW | ⚠ | 100.0% | 9.2% | 3 differences |
| claims.mv_balance_amount_initial | MATERIALIZED_VIEW | ⚠ | 100.0% | 74.2% | 1 differences |
| refresh_resubmission_cycles_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| MATERIALIZED | COMMENT | ✓ | 100.0% | 33.3% | Perfect match |
| claims.mv_remittance_advice_activity_wise | MATERIALIZED_VIEW | ⚠ | 100.0% | 8.8% | 2 differences |
| claims.mv_claim_details_complete | MATERIALIZED_VIEW | ⚠ | 12.5% | 3.9% | 9 differences |
| refresh_rejected_claims_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |
| refresh_encounterwise_mv | FUNCTION | ✗ | 0.0% | 0.0% | Missing from Docker |

## Missing Objects

- **refresh_remittance_advice_mv** (FUNCTION)
- **refresh_doctor_denial_mv** (FUNCTION)
- **refresh_payerwise_mv** (FUNCTION)
- **refresh_claim_details_mv** (FUNCTION)
- **refresh_monthly_agg_mv** (FUNCTION)
- **FUNCTION** (COMMENT)
- **refresh_remittances_resubmission_activity_level_mv** (FUNCTION)
- **refresh_resubmission_cycles_mv** (FUNCTION)
- **refresh_rejected_claims_mv** (FUNCTION)
- **refresh_encounterwise_mv** (FUNCTION)

## Issues Found

### claims.mv_claims_monthly_agg

- Missing columns: member_id, emirates_id_number, net, gross, patient_share, payer_id, provider_id, tx_at) as month_bucket
- Extra columns: EXTRACT(YEAR, tx_at)), date_settlement
- GROUP BY clause differs
- Missing ORDER BY clause in Docker
- Extra comments: 4

### claims.mv_remittances_resubmission_activity_level

- Missing columns: 0) as remittance_count, remittance_count, 0::numeric) as total_paid, id as activity_internal_id, denied_amount, net::numeric as submitted_amount, 0::numeric) as rejected_amount, claim_id, submitted_amount, 0::numeric) as total_remitted, -- remittance count, paid_amount
- Extra columns: payment_reference, receiver_name, net, denial_code, denial_reason, remittance_claim_id, claim_key_id, date_settlement, created_at, payment_amount, receiver_id
- Missing CTEs: activity_financials
- Extra CTEs: activity_remittance_summary
- WHERE clause differs
- Missing GROUP BY clause in source
- ORDER BY clause differs
- Missing comments: 41
- Extra comments: 8

### claims.mv_rejected_claims_summary_tab

- Extra columns: total_rejected_amount ELSE 0 END, claim_id, net, 2
  ), claim_id END
- Missing WHERE clause in Docker
- Missing GROUP BY clause in Docker

### refresh_remittance_advice_mv

- Object 'refresh_remittance_advice_mv' exists in source but missing in Docker

### claims.mv_rejected_claims_summary

- Missing columns: claim_id, -- Get latest rejection status, net as activity_net_amount
- Extra columns: payment_reference, receiver_name, net, denial_code, denial_reason, remittance_claim_id, claim_key_id, date_settlement, created_at, receiver_id
- Missing CTEs: activity_rejection_agg
- Extra CTEs: rejected_activities
- WHERE clause differs
- GROUP BY clause differs
- Missing comments: 17
- Extra comments: 7

### claims.mv_claim_summary_encounterwise

- Missing columns: activity_status = 'REJECTED' THEN 1 END, date_settlement IS NULL THEN 1 END, activity_status = 'PARTIALLY_PAID' THEN 1 END, remittance_count, payment_reference IS NOT NULL THEN 1 END, claim_key_id, date_settlement DESC NULLS LAST
- Extra columns: id, 'Unknown'), net, payer_code, tx_at, claim_id, facility_id, name, activity_id, type
- Missing CTEs: remittance_aggregated
- Extra CTEs: base
- Missing WHERE clause in source
- GROUP BY clause differs
- ORDER BY clause differs
- Missing comments: 15
- Extra comments: 5

### refresh_doctor_denial_mv

- Object 'refresh_doctor_denial_mv' exists in source but missing in Docker

### claims.mv_balance_amount_resubmission

- Missing WHERE clause in Docker

### claims.mv_claim_summary_payerwise

- Missing columns: activity_status = 'REJECTED' THEN 1 END, date_settlement IS NULL THEN 1 END, activity_status = 'PARTIALLY_PAID' THEN 1 END, remittance_count, payment_reference IS NOT NULL THEN 1 END, claim_key_id, date_settlement DESC NULLS LAST
- Extra columns: id, 'Unknown'), net, payer_code, tx_at, claim_id, facility_id, activity_id, name
- Missing CTEs: remittance_aggregated
- Extra CTEs: base
- Missing WHERE clause in source
- GROUP BY clause differs
- ORDER BY clause differs
- Missing comments: 14
- Extra comments: 5

### claims.mv_rejected_claims_by_year

- Extra columns: EXTRACT(YEAR
- Missing WHERE clause in Docker
- Missing GROUP BY clause in Docker
- Missing ORDER BY clause in Docker

### refresh_payerwise_mv

- Object 'refresh_payerwise_mv' exists in source but missing in Docker

### claims.mv_doctor_denial_summary

- Missing columns: activity_status = 'REJECTED' THEN 1 END, activity_status = 'PARTIALLY_PAID' THEN 1 END, remittance_count, claim_key_id, submitted_amount, date_settlement, date_settlement DESC NULLS LAST, paid_amount
- Extra columns: id, net ELSE 0 END, net, claim_id END, specialty, clinician, claim_id, id END, 2
    ), name, clinician_code
- Missing CTEs: remittance_aggregated
- Extra CTEs: doctor_denial_stats
- WHERE clause differs
- GROUP BY clause differs
- ORDER BY clause differs
- Missing comments: 6

### claims.mv_doctor_denial_high_denial

- Missing WHERE clause in Docker

### claims.mv_resubmission_cycles

- Missing columns: date_settlement ORDER BY ABS(EXTRACT(EPOCH, type
- Extra columns: activity_id, resubmission_type, comment
- Missing CTEs: event_remittance_agg
- Extra CTEs: resubmission_cycles
- WHERE clause differs
- Missing GROUP BY clause in source
- ORDER BY clause differs
- Missing comments: 6
- Extra comments: 3

### claims.mv_remittances_resubmission_claim_level

- Extra columns: payment_reference, id, receiver_name, net ELSE 0 END, claim_key_id, date_settlement, payment_amount, receiver_id
- Extra CTEs: claim_remittance_summary
- Missing WHERE clause in Docker
- Missing GROUP BY clause in Docker
- Extra comments: 7

### refresh_claim_details_mv

- Object 'refresh_claim_details_mv' exists in source but missing in Docker

### claims.mv_rejected_claims_receiver_payer

- Extra columns: receiver_name, net ELSE 0 END, net, claim_id END, payer_id, claim_id, 2
  ), name, receiver_id
- Missing GROUP BY clause in Docker
- Missing ORDER BY clause in Docker

### refresh_monthly_agg_mv

- Object 'refresh_monthly_agg_mv' exists in source but missing in Docker

### FUNCTION

- Object 'FUNCTION' exists in source but missing in Docker

### refresh_remittances_resubmission_activity_level_mv

- Object 'refresh_remittances_resubmission_activity_level_mv' exists in source but missing in Docker

### claims.mv_doctor_denial_detail

- Extra columns: payment_reference, id, member_id, emirates_id_number, start_at, tx_at, payer_id, description, date_settlement, provider_id, created_at, type, name, clinician_code, receiver_id, receiver_name, net, denial_code, specialty, clinician, facility_id, claim_id, end_at, code, denial_reason
- Missing WHERE clause in Docker
- Missing ORDER BY clause in Docker
- Extra comments: 4

### claims.mv_remittance_advice_header

- Extra columns: payment_reference, id, receiver_name, net ELSE 0 END, net, created_at, payment_amount, receiver_id
- Missing GROUP BY clause in Docker

### claims.mv_rejected_claims_claim_wise

- Extra columns: payment_reference, id, member_id, emirates_id_number, start_at, tx_at, payer_id, description, date_settlement, provider_id, created_at, type, receiver_id, name, receiver_name, net, denial_code, facility_id, claim_id, denial_reason, activity_id
- Missing WHERE clause in Docker
- Missing ORDER BY clause in Docker
- Extra comments: 3

### claims.mv_remittance_advice_claim_wise

- Extra columns: payment_reference, id, member_id, emirates_id_number, start_at, gross, tx_at, payer_id, description, date_settlement, provider_id, created_at, type, receiver_id, name, receiver_name, net ELSE 0 END, net, patient_share, facility_id, claim_id, end_at, payment_amount
- Missing GROUP BY clause in Docker
- Extra comments: 3

### claims.mv_balance_amount_initial

- Missing WHERE clause in Docker

### refresh_resubmission_cycles_mv

- Object 'refresh_resubmission_cycles_mv' exists in source but missing in Docker

### claims.mv_remittance_advice_activity_wise

- Extra columns: payment_reference, id, member_id, emirates_id_number, start_at, tx_at, payer_id, description, date_settlement, provider_id, created_at, type, receiver_id, name, receiver_name, net, denial_code, clinician, facility_id, claim_id, end_at, code, denial_reason, activity_id, payment_amount
- Extra comments: 4

### claims.mv_claim_details_complete

- Missing columns: 0) as total_payment_amount, -- latest denial, denial_codes, paid_amount, activity_id
- Extra columns: payment_reference, id, receiver_name, comment, resubmission_type, net, denial_code, clinician, denial_code IS NOT NULL THEN 'DENIED'
      ELSE 'PENDING'
    END, description, date_settlement, code, denial_reason, created_at, payment_amount, receiver_id, event_time
- Missing CTEs: activity_remittance_agg
- Extra CTEs: activity_timeline
- Missing WHERE clause in Docker
- Missing GROUP BY clause in source
- Missing ORDER BY clause in Docker
- Missing comments: 10
- Extra comments: 10

### refresh_rejected_claims_mv

- Object 'refresh_rejected_claims_mv' exists in source but missing in Docker

### refresh_encounterwise_mv

- Object 'refresh_encounterwise_mv' exists in source but missing in Docker

## Detailed Comparisons

### claims.mv_claims_monthly_agg

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 10.0%
**Accuracy:** 7.1%

**Missing Components:**
- Missing column: member_id
- Missing column: emirates_id_number
- Missing column: net
- Missing column: gross
- Missing column: patient_share
- Missing column: payer_id
- Missing column: provider_id
- Missing column: tx_at) as month_bucket

**Extra Components:**
- Extra column: EXTRACT(YEAR
- Extra column: tx_at))
- Extra column: date_settlement

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,13 +1,75 @@
 CREATE MATERIALIZED VIEW claims.mv_claims_monthly_agg AS
 SELECT 
-  DATE_TRUNC('month', c.tx_at) as month_bucket,
-  c.payer_id,
-  c.provider_id,
-  COUNT(*) as claim_count,
-  SUM(c.net) as total_net,
-  SUM(c.gross) as total_gross,
-  SUM(c.patient_share) as total_patient_share,
-  COUNT(DISTINCT c.member_id) as unique_members,
-  COUNT(DISTINCT c.emirates_id_number) as unique_emirates_ids
-FROM claims.claim c
-GROUP BY DATE_TRUNC('month', c.tx_at), c.payer_id, c.provider_id;
+  DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)) AS month_year,
+  EXTRACT(YEAR FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))) AS year,
+  EXTRACT(MONTH FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))) AS month,
+  
+  -- Count Metrics
+  COUNT(DISTINCT ck.claim_id) AS count_claims,
+  COUNT(DISTINCT cas.activity_id) AS remitted_count,
+  COUNT(DISTINCT CASE WHEN cas.activity_status = 'FULLY_PAID' THEN cas.activity_id END) AS fully_paid_count,
+  COUNT(DISTINCT CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.activity_id END) AS partially_paid_count,
+  COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS fully_rejected_count,
+  COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS rejection_count,
+  COUNT(DISTINCT CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.activity_id END) AS taken_back_count,
+  COUNT(DISTINCT CASE WHEN cas.activity_status = 'PENDING' THEN cas.activity_id END) AS pending_remittance_count,
+  COUNT(DISTINCT CASE WHEN c.payer_id = 'Self-Paid' THEN ck.claim_id END) AS self_pay_count,
+
+  -- Amount Metrics
+  SUM(DISTINCT c.net) AS claim_amount,
+  SUM(DISTINCT c.net) AS initial_claim_amount,
+  SUM(COALESCE(cas.paid_amount, 0)) AS remitted_amount,
+  SUM(COALESCE(cas.paid_amount, 0)) AS remitted_net_amount,
+  SUM(COALESCE(cas.paid_amount, 0)) AS fully_paid_amount,
+  SUM(CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.paid_amount ELSE 0 END) AS partially_paid_amount,
+  SUM(COALESCE(cas.denied_amount, 0)) AS fully_rejected_amount,
+  SUM(COALESCE(cas.denied_amount, 0)) AS rejected_amount,
+  SUM(CASE WHEN cas.activity_status = 'PENDING' THEN cas.submitted_amount ELSE 0 END) AS pending_remittance_amount,
+  SUM(CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.taken_back_amount ELSE 0 END) AS taken_back_amount,
+  SUM(CASE WHEN c.payer_id = 'Self-Paid' THEN c.net ELSE 0 END) AS self_pay_amount,
+
+  -- Facility and Health Authority
+  e.facility_id,
+  f.name AS facility_name,
+  COALESCE(p2.payer_code, 'Unknown') AS health_authority,
+
+  -- Percentage Calculations
... (truncated)
```

### claims.mv_remittances_resubmission_activity_level

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 5.9%
**Accuracy:** 7.7%

**Missing Components:**
- Missing column: 0) as remittance_count
- Missing column: remittance_count
- Missing column: 0::numeric) as total_paid
- Missing column: id as activity_internal_id
- Missing column: denied_amount
- Missing column: net::numeric as submitted_amount
- Missing column: 0::numeric) as rejected_amount
- Missing column: claim_id
- Missing column: submitted_amount
- Missing column: 0::numeric) as total_remitted
- Missing column: -- remittance count
- Missing column: paid_amount
- Missing CTE: activity_financials

**Extra Components:**
- Extra column: payment_reference
- Extra column: receiver_name
- Extra column: net
- Extra column: denial_code
- Extra column: denial_reason
- Extra column: remittance_claim_id
- Extra column: claim_key_id
- Extra column: date_settlement
- Extra column: created_at
- Extra column: payment_amount
- Extra column: receiver_id
- Extra CTE: activity_remittance_summary

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,261 +1,104 @@
 CREATE MATERIALIZED VIEW claims.mv_remittances_resubmission_activity_level AS
-WITH activity_financials AS (
-    -- CUMULATIVE-WITH-CAP: Calculate financial metrics per activity using claim_activity_summary
-    -- WHY: Prevents overcounting from multiple remittances per activity, uses latest denial logic
-    -- HOW: Leverages claims.claim_activity_summary which already implements cumulative-with-cap semantics
-    SELECT 
-        a.id as activity_internal_id,
-        a.claim_id,
-        a.activity_id,
-        a.net::numeric as submitted_amount,
-        COALESCE(cas.paid_amount, 0::numeric) as total_paid,                    -- capped paid across remittances
-        COALESCE(cas.submitted_amount, 0::numeric) as total_remitted,          -- submitted as remitted baseline
-        COALESCE(cas.denied_amount, 0::numeric) as rejected_amount,            -- denied only when latest denial and zero paid
-        COALESCE(cas.remittance_count, 0) as remittance_count,                 -- remittance count from pre-computed summary
-        (cas.denial_codes)[1] as latest_denial_code,                           -- latest denial from pre-computed summary
-        (cas.denial_codes)[array_length(cas.denial_codes, 1)] as initial_denial_code,  -- first denial from pre-computed summary
-        -- Additional calculated fields using pre-computed activity status
-        CASE WHEN cas.activity_status = 'FULLY_PAID' THEN 1 ELSE 0 END as fully_paid_count,
-        CASE WHEN cas.activity_status = 'FULLY_PAID' THEN cas.paid_amount ELSE 0::numeric END as fully_paid_amount,
-        CASE WHEN cas.activity_status = 'REJECTED' THEN 1 ELSE 0 END as fully_rejected_count,
-        CASE WHEN cas.activity_status = 'REJECTED' THEN cas.denied_amount ELSE 0::numeric END as fully_rejected_amount,
-        CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN 1 ELSE 0 END as partially_paid_count,
-        CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.paid_amount ELSE 0::numeric END as partially_paid_amount,
-        -- Self-pay detection
-        COUNT(CASE WHEN c.payer_id = 'Self-Paid' THEN 1 END) as self_pay_count,
-        SUM(CASE WHEN c.payer_id = 'Self-Paid' THEN a.net ELSE 0::numeric END) as self_pay_amount,
-        -- Taken back amounts (from raw remittance data as this is not in summary)
-        COALESCE(SUM(CASE WHEN ra.payment_amount < 0 THEN ABS(ra.payment_amount) ELSE 0::numeric END), 0::numeric) as taken_back_amount,
-        COALESCE(COUNT(CASE WHEN ra.payment_amount < 0 THEN 1 END), 0) as taken_back_count
-    FROM claims.activity a
-    LEFT JOIN claims.claim c ON a.claim_id = c.id
-    LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = c.claim_key_id AND cas.activity_id = a.activity_id
-    LEFT JOIN claims.remittance_activity ra ON a.activity_id = ra.activity_id
-      AND ra.remittance_claim_id IN (
-        SELECT id FROM claims.remittance_claim rc2 WHERE rc2.claim_key_id = c.claim_key_id
-      )
-    GROUP BY a.id, a.claim_id, a.activity_id, a.net, c.payer_id, cas.paid_amount, cas.submitted_amount, cas.denied_amount, cas.remittance_count, cas.denial_codes, cas.activity_status
+WITH activity_remittance_summary AS (
+  -- Pre-aggregate remittance data at activity level
+  SELECT 
+    ra.activity_id,
+    ra.remittance_claim_id,
+    rc.claim_key_id,
+    ra.net AS activity_net,
+    ra.payment_amount AS activity_payment,
+    ra.denial_code AS activity_denial_code,
+    ra.denial_reason AS activity_denial_reason,
... (truncated)
```

### claims.mv_rejected_claims_summary_tab

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 100.0%
**Accuracy:** 14.8%

**Extra Components:**
- Extra column: total_rejected_amount ELSE 0 END
- Extra column: claim_id
- Extra column: net
- Extra column: 2
  )
- Extra column: claim_id END

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,2 +1,26 @@
 CREATE MATERIALIZED VIEW claims.mv_rejected_claims_summary_tab AS
-SELECT * FROM claims.v_rejected_claims_summary;
+SELECT 
+  COUNT(DISTINCT ck.claim_id) AS total_claims,
+  COUNT(DISTINCT CASE WHEN crs.rejected_activity_count > 0 THEN ck.claim_id END) AS rejected_claims,
+  SUM(c.net) AS total_claim_amount,
+  SUM(CASE WHEN crs.rejected_activity_count > 0 THEN crs.total_rejected_amount ELSE 0 END) AS total_rejected_amount,
+  ROUND(
+    (COUNT(DISTINCT CASE WHEN crs.rejected_activity_count > 0 THEN ck.claim_id END)::DECIMAL / 
+     COUNT(DISTINCT ck.claim_id)) * 100, 2
+  ) AS rejection_rate_percentage,
+  ROUND(
+    (SUM(CASE WHEN crs.rejected_activity_count > 0 THEN crs.total_rejected_amount ELSE 0 END)::DECIMAL / 
+     SUM(c.net)) * 100, 2
+  ) AS rejection_amount_percentage
+FROM claims.claim_key ck
+JOIN claims.claim c ON c.claim_key_id = ck.id
+LEFT JOIN (
+  SELECT 
+    rc.claim_key_id,
+    COUNT(DISTINCT ra.activity_id) AS rejected_activity_count,
+    SUM(ra.net) AS total_rejected_amount
+  FROM claims.remittance_activity ra
+  JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
+  WHERE ra.denial_code IS NOT NULL
+  GROUP BY rc.claim_key_id
+) crs ON crs.claim_key_id = ck.id;
```

### refresh_remittance_advice_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_rejected_claims_summary

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 14.3%
**Accuracy:** 9.2%

**Missing Components:**
- Missing column: claim_id
- Missing column: -- Get latest rejection status
- Missing column: net as activity_net_amount
- Missing CTE: activity_rejection_agg

**Extra Components:**
- Extra column: payment_reference
- Extra column: receiver_name
- Extra column: net
- Extra column: denial_code
- Extra column: denial_reason
- Extra column: remittance_claim_id
- Extra column: claim_key_id
- Extra column: date_settlement
- Extra column: created_at
- Extra column: receiver_id
- Extra CTE: rejected_activities

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,108 +1,107 @@
 CREATE MATERIALIZED VIEW claims.mv_rejected_claims_summary AS
-WITH activity_rejection_agg AS (
-  -- CUMULATIVE-WITH-CAP: Pre-aggregate rejection data per activity using claim_activity_summary
-  -- WHY: Prevents overcounting from multiple remittances per activity, uses latest denial logic
-  -- HOW: Leverages claims.claim_activity_summary which already implements cumulative-with-cap semantics
+WITH rejected_activities AS (
+  -- Get activities that have been rejected (denied)
   SELECT 
-    a.activity_id,
-    a.claim_id,
-    a.net as activity_net_amount,
-    -- Get latest rejection status from pre-computed activity summary
-    (cas.denial_codes)[1] as latest_denial_code,                       -- latest denial from pre-computed summary
-    MAX(rc.date_settlement) as latest_settlement_date,
-    MAX(rc.payment_reference) as latest_payment_reference,
-    MAX(rc.id) as latest_remittance_claim_id,
-    -- Use pre-computed rejection amount and type
-    COALESCE(cas.denied_amount, 0) as rejected_amount,                 -- denied only when latest denial and zero paid
-    CASE 
-      WHEN cas.activity_status = 'REJECTED' THEN 'Fully Rejected'
-      WHEN cas.activity_status = 'PARTIALLY_PAID' THEN 'Partially Rejected'
-      WHEN cas.activity_status = 'PENDING' THEN 'No Payment'
-      ELSE 'Unknown'
-    END as rejection_type,
-    -- Additional metrics from pre-computed summary
-    COALESCE(cas.remittance_count, 0) as remittance_count,             -- remittance count from pre-computed summary
-    COALESCE(cas.paid_amount, 0) as total_payment_amount,              -- capped paid across remittances
-    COALESCE(cas.paid_amount, 0) as max_payment_amount,                -- capped paid across remittances
-    -- Flag to indicate if this activity has rejection data
-    CASE 
-      WHEN cas.activity_status = 'REJECTED' OR cas.activity_status = 'PARTIALLY_PAID' OR cas.denied_amount > 0
-      THEN 1 
-      ELSE 0 
-    END as has_rejection_data
-  FROM claims.activity a
-  LEFT JOIN claims.claim c ON c.id = a.claim_id
-  LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = c.claim_key_id AND cas.activity_id = a.activity_id
-  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = c.claim_key_id
-  GROUP BY a.activity_id, a.claim_id, a.net, cas.denial_codes, cas.denied_amount, cas.activity_status, cas.remittance_count, cas.paid_amount
+    ra.activity_id,
+    ra.remittance_claim_id,
+    ra.net AS activity_net,
+    ra.denial_code,
+    ra.denial_reason,
+    ra.created_at AS rejection_date,
+    rc.claim_key_id,
+    rc.date_settlement,
... (truncated)
```

### claims.mv_claim_summary_encounterwise

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 17.6%
**Accuracy:** 8.0%

**Missing Components:**
- Missing column: activity_status = 'REJECTED' THEN 1 END
- Missing column: date_settlement IS NULL THEN 1 END
- Missing column: activity_status = 'PARTIALLY_PAID' THEN 1 END
- Missing column: remittance_count
- Missing column: payment_reference IS NOT NULL THEN 1 END
- Missing column: claim_key_id
- Missing column: date_settlement DESC NULLS LAST
- Missing CTE: remittance_aggregated

**Extra Components:**
- Extra column: id
- Extra column: 'Unknown')
- Extra column: net
- Extra column: payer_code
- Extra column: tx_at
- Extra column: claim_id
- Extra column: facility_id
- Extra column: name
- Extra column: activity_id
- Extra column: type
- Extra CTE: base

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,94 +1,110 @@
 CREATE MATERIALIZED VIEW claims.mv_claim_summary_encounterwise AS
-WITH remittance_aggregated AS (
-  -- CUMULATIVE-WITH-CAP: Pre-aggregate all remittance data per claim_key_id using claim_activity_summary
-  -- WHY: Prevents overcounting from multiple remittances per activity, uses latest denial logic
-  -- HOW: Leverages claims.claim_activity_summary which already implements cumulative-with-cap semantics
-  SELECT 
-    cas.claim_key_id,
-    MAX(cas.remittance_count) as remittance_count,                    -- max across activities
-    SUM(cas.paid_amount) as total_payment_amount,                     -- capped paid across activities
-    SUM(cas.submitted_amount) as total_remitted_amount,               -- submitted as remitted baseline
-    COUNT(CASE WHEN cas.activity_status = 'FULLY_PAID' OR cas.activity_status = 'PARTIALLY_PAID' THEN 1 END) as paid_activity_count,
-    COUNT(CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN 1 END) as partially_paid_activity_count,
-    COUNT(CASE WHEN cas.activity_status = 'REJECTED' THEN 1 END) as rejected_activity_count,
-    COUNT(CASE WHEN rc.payment_reference IS NOT NULL THEN 1 END) as taken_back_count,
-    COUNT(CASE WHEN rc.date_settlement IS NULL THEN 1 END) as pending_remittance_count,
-    MIN(rc.date_settlement) as first_remittance_date,
-    MAX(rc.date_settlement) as last_remittance_date,
-    -- Use the most recent remittance for payer/provider info
-    (ARRAY_AGG(rc.id_payer ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_id_payer,
-    (ARRAY_AGG(rc.provider_id ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_provider_id
-  FROM claims.claim_activity_summary cas
-  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = cas.claim_key_id
-  GROUP BY cas.claim_key_id
+WITH base AS (
+    SELECT
+        ck.claim_id,
+        c.id AS claim_db_id,
+        c.tx_at,
+        e.facility_id,
+        f.name AS facility_name,
+        e.type AS encounter_type,
+        rc.date_settlement,
+        rc.id AS remittance_claim_id,
+        cas.activity_id AS remittance_activity_id,
+        c.net AS claim_net,
+        cas.submitted_amount AS ra_net,
+        cas.paid_amount AS payment_amount,
+        COALESCE(p2.payer_code, 'Unknown') AS health_authority
+    FROM claims.claim_key ck
+    JOIN claims.claim c ON c.claim_key_id = ck.id
+    LEFT JOIN claims.encounter e ON e.claim_id = c.id
+    LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
+    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
+    LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
+    LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
+    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
+    LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
... (truncated)
```

### refresh_doctor_denial_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_balance_amount_resubmission

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 100.0%
**Accuracy:** 79.7%

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,2 +1,2 @@
 CREATE MATERIALIZED VIEW claims.mv_balance_amount_resubmission AS
-SELECT * FROM claims.v_after_resubmission_not_remitted_balance;
+SELECT * FROM claims.mv_balance_amount_summary WHERE resubmission_count > 0;
```

### claims.mv_claim_summary_payerwise

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 17.6%
**Accuracy:** 8.7%

**Missing Components:**
- Missing column: activity_status = 'REJECTED' THEN 1 END
- Missing column: date_settlement IS NULL THEN 1 END
- Missing column: activity_status = 'PARTIALLY_PAID' THEN 1 END
- Missing column: remittance_count
- Missing column: payment_reference IS NOT NULL THEN 1 END
- Missing column: claim_key_id
- Missing column: date_settlement DESC NULLS LAST
- Missing CTE: remittance_aggregated

**Extra Components:**
- Extra column: id
- Extra column: 'Unknown')
- Extra column: net
- Extra column: payer_code
- Extra column: tx_at
- Extra column: claim_id
- Extra column: facility_id
- Extra column: activity_id
- Extra column: name
- Extra CTE: base

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,85 +1,106 @@
 CREATE MATERIALIZED VIEW claims.mv_claim_summary_payerwise AS
-WITH remittance_aggregated AS (
-  -- CUMULATIVE-WITH-CAP: Pre-aggregate all remittance data per claim_key_id using claim_activity_summary
-  -- WHY: Prevents overcounting from multiple remittances per activity, uses latest denial logic
-  -- HOW: Leverages claims.claim_activity_summary which already implements cumulative-with-cap semantics
-  SELECT 
-    cas.claim_key_id,
-    MAX(cas.remittance_count) as remittance_count,                    -- max across activities
-    SUM(cas.paid_amount) as total_payment_amount,                     -- capped paid across activities
-    SUM(cas.submitted_amount) as total_remitted_amount,               -- submitted as remitted baseline
-    COUNT(CASE WHEN cas.activity_status = 'FULLY_PAID' OR cas.activity_status = 'PARTIALLY_PAID' THEN 1 END) as paid_activity_count,
-    COUNT(CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN 1 END) as partially_paid_activity_count,
-    COUNT(CASE WHEN cas.activity_status = 'REJECTED' THEN 1 END) as rejected_activity_count,
-    COUNT(CASE WHEN rc.payment_reference IS NOT NULL THEN 1 END) as taken_back_count,
-    COUNT(CASE WHEN rc.date_settlement IS NULL THEN 1 END) as pending_remittance_count,
-    MIN(rc.date_settlement) as first_remittance_date,
-    MAX(rc.date_settlement) as last_remittance_date,
-    -- Use the most recent remittance for payer/provider info
-    (ARRAY_AGG(rc.id_payer ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_id_payer,
-    (ARRAY_AGG(rc.provider_id ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_provider_id
-  FROM claims.claim_activity_summary cas
-  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = cas.claim_key_id
-  GROUP BY cas.claim_key_id
+WITH base AS (
+    SELECT
+        ck.claim_id,
+        c.id AS claim_db_id,
+        c.tx_at,
+        e.facility_id,
+        f.name AS facility_name,
+        rc.date_settlement,
+        rc.id AS remittance_claim_id,
+        cas.activity_id AS remittance_activity_id,
+        c.net AS claim_net,
+        cas.submitted_amount AS ra_net,
+        cas.paid_amount AS payment_amount,
+        COALESCE(p2.payer_code, 'Unknown') AS health_authority
+    FROM claims.claim_key ck
+    JOIN claims.claim c ON c.claim_key_id = ck.id
+    LEFT JOIN claims.encounter e ON e.claim_id = c.id
+    LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
+    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
+    LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
+    LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
+    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
+    LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
+),
... (truncated)
```

### claims.mv_rejected_claims_by_year

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 100.0%
**Accuracy:** 13.3%

**Extra Components:**
- Extra column: EXTRACT(YEAR

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,2 +1,29 @@
 CREATE MATERIALIZED VIEW claims.mv_rejected_claims_by_year AS
-SELECT * FROM claims.v_rejected_claims_summary_by_year;
+SELECT 
+  EXTRACT(YEAR FROM c.tx_at) AS year,
+  COUNT(DISTINCT ck.claim_id) AS total_claims,
+  COUNT(DISTINCT CASE WHEN crs.rejected_activity_count > 0 THEN ck.claim_id END) AS rejected_claims,
+  SUM(c.net) AS total_claim_amount,
+  SUM(CASE WHEN crs.rejected_activity_count > 0 THEN crs.total_rejected_amount ELSE 0 END) AS total_rejected_amount,
+  ROUND(
+    (COUNT(DISTINCT CASE WHEN crs.rejected_activity_count > 0 THEN ck.claim_id END)::DECIMAL / 
+     COUNT(DISTINCT ck.claim_id)) * 100, 2
+  ) AS rejection_rate_percentage,
+  ROUND(
+    (SUM(CASE WHEN crs.rejected_activity_count > 0 THEN crs.total_rejected_amount ELSE 0 END)::DECIMAL / 
+     SUM(c.net)) * 100, 2
+  ) AS rejection_amount_percentage
+FROM claims.claim_key ck
+JOIN claims.claim c ON c.claim_key_id = ck.id
+LEFT JOIN (
+  SELECT 
+    rc.claim_key_id,
+    COUNT(DISTINCT ra.activity_id) AS rejected_activity_count,
+    SUM(ra.net) AS total_rejected_amount
+  FROM claims.remittance_activity ra
+  JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
+  WHERE ra.denial_code IS NOT NULL
+  GROUP BY rc.claim_key_id
+) crs ON crs.claim_key_id = ck.id
+GROUP BY EXTRACT(YEAR FROM c.tx_at)
+ORDER BY year DESC;
```

### refresh_payerwise_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_doctor_denial_summary

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 0.0%
**Accuracy:** 9.3%

**Missing Components:**
- Missing column: activity_status = 'REJECTED' THEN 1 END
- Missing column: activity_status = 'PARTIALLY_PAID' THEN 1 END
- Missing column: remittance_count
- Missing column: claim_key_id
- Missing column: submitted_amount
- Missing column: date_settlement
- Missing column: date_settlement DESC NULLS LAST
- Missing column: paid_amount
- Missing CTE: remittance_aggregated

**Extra Components:**
- Extra column: id
- Extra column: net ELSE 0 END
- Extra column: net
- Extra column: claim_id END
- Extra column: specialty
- Extra column: clinician
- Extra column: claim_id
- Extra column: id END
- Extra column: 2
    )
- Extra column: name
- Extra column: clinician_code
- Extra CTE: doctor_denial_stats

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,68 +1,54 @@
 CREATE MATERIALIZED VIEW claims.mv_doctor_denial_summary AS
-WITH remittance_aggregated AS (
-  -- CUMULATIVE-WITH-CAP: Pre-aggregate all remittance data per claim_key_id using claim_activity_summary
-  -- WHY: Prevents overcounting from multiple remittances per activity, uses latest denial logic
-  -- HOW: Leverages claims.claim_activity_summary which already implements cumulative-with-cap semantics
+WITH doctor_denial_stats AS (
   SELECT 
-    cas.claim_key_id,
-    MAX(cas.remittance_count) as remittance_count,                    -- max across activities
-    SUM(cas.paid_amount) as total_payment_amount,                     -- capped paid across activities
-    SUM(cas.submitted_amount) as total_remitted_amount,               -- submitted as remitted baseline
-    COUNT(CASE WHEN cas.activity_status = 'FULLY_PAID' OR cas.activity_status = 'PARTIALLY_PAID' THEN 1 END) as paid_activity_count,
-    COUNT(CASE WHEN cas.activity_status = 'REJECTED' THEN 1 END) as rejected_activity_count,
-    MIN(rc.date_settlement) as first_remittance_date,
-    MAX(rc.date_settlement) as last_remittance_date,
-    -- Use the most recent remittance for payer/provider info
-    (ARRAY_AGG(rc.id_payer ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_id_payer,
-    (ARRAY_AGG(rc.provider_id ORDER BY rc.date_settlement DESC NULLS LAST))[1] as latest_provider_id
-  FROM claims.claim_activity_summary cas
-  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = cas.claim_key_id
-  GROUP BY cas.claim_key_id
-),
-clinician_activity_agg AS (
-  SELECT 
-    cl.id as clinician_id,
-    cl.name as clinician_name,
-    cl.specialty,
-    f.facility_code,
-    f.name as facility_name,
-    DATE_TRUNC('month', COALESCE(ra.last_remittance_date, c.tx_at)) as report_month,
-    -- Pre-computed aggregations (now one row per claim)
-    COUNT(DISTINCT ck.claim_id) as total_claims,
-    COUNT(DISTINCT CASE WHEN ra.claim_key_id IS NOT NULL THEN ck.claim_id END) as remitted_claims,
-    COUNT(DISTINCT CASE WHEN ra.rejected_activity_count > 0 THEN ck.claim_id END) as rejected_claims,
-    SUM(a.net) as total_claim_amount,
-    SUM(COALESCE(ra.total_payment_amount, 0)) as remitted_amount,
-    SUM(CASE WHEN ra.rejected_activity_count > 0 THEN ra.total_remitted_amount ELSE 0 END) as rejected_amount
-  FROM claims.claim_key ck
-  JOIN claims.claim c ON c.claim_key_id = ck.id
-  LEFT JOIN claims.encounter e ON e.claim_id = c.id
-  LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
-  LEFT JOIN claims.activity a ON a.claim_id = c.id
+    a.clinician,
+    cl.name AS clinician_name,
+    cl.clinician_code,
+    cl.specialty AS clinician_specialty,
+    COUNT(DISTINCT a.id) AS total_activities,
... (truncated)
```

### claims.mv_doctor_denial_high_denial

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 100.0%
**Accuracy:** 84.4%

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,2 +1,2 @@
 CREATE MATERIALIZED VIEW claims.mv_doctor_denial_high_denial AS
-SELECT * FROM claims.v_doctor_denial_high_denial;
+SELECT * FROM claims.mv_doctor_denial_summary WHERE denial_risk_level = 'HIGH';
```

### claims.mv_resubmission_cycles

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 25.0%
**Accuracy:** 5.2%

**Missing Components:**
- Missing column: date_settlement ORDER BY ABS(EXTRACT(EPOCH
- Missing column: type
- Missing CTE: event_remittance_agg

**Extra Components:**
- Extra column: activity_id
- Extra column: resubmission_type
- Extra column: comment
- Extra CTE: resubmission_cycles

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,49 +1,54 @@
 CREATE MATERIALIZED VIEW claims.mv_resubmission_cycles AS
-WITH event_remittance_agg AS (
-  -- Pre-aggregate remittance data per claim and get closest remittance to each event
+WITH resubmission_cycles AS (
   SELECT 
     ce.claim_key_id,
-    ce.event_time,
-    ce.type,
-    -- Get remittance info closest to this event
-    (ARRAY_AGG(rc.date_settlement ORDER BY ABS(EXTRACT(EPOCH FROM (rc.date_settlement - ce.event_time)))))[1] as closest_settlement_date,
-    (ARRAY_AGG(rc.payment_reference ORDER BY ABS(EXTRACT(EPOCH FROM (rc.date_settlement - ce.event_time)))))[1] as closest_payment_reference,
-    (ARRAY_AGG(rc.id ORDER BY ABS(EXTRACT(EPOCH FROM (rc.date_settlement - ce.event_time)))))[1] as closest_remittance_claim_id,
-    -- Additional remittance metrics
-    COUNT(DISTINCT rc.id) as total_remittance_count,
-    MIN(rc.date_settlement) as earliest_settlement_date,
-    MAX(rc.date_settlement) as latest_settlement_date
+    ce.activity_id,
+    ce.event_time AS resubmission_date,
+    cr.comment AS resubmission_comment,
+    cr.resubmission_type,
+    ROW_NUMBER() OVER (PARTITION BY ce.claim_key_id ORDER BY ce.event_time) AS resubmission_sequence,
+    COUNT(*) OVER (PARTITION BY ce.claim_key_id) AS total_resubmissions
   FROM claims.claim_event ce
-  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ce.claim_key_id
-  WHERE ce.type IN (1, 2) -- SUBMISSION, RESUBMISSION
-  GROUP BY ce.claim_key_id, ce.event_time, ce.type
+  JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce.id
+  WHERE ce.type = 2  -- RESUBMISSION events
 )
 SELECT 
-  ce.claim_key_id,
-  ce.event_time,
-  ce.type,
-  cr.resubmission_type,
-  cr.comment,
-  ROW_NUMBER() OVER (PARTITION BY ce.claim_key_id ORDER BY ce.event_time) as cycle_number,
-  -- Remittance cycle tracking (closest to event)
-  era.closest_settlement_date as date_settlement,
-  era.closest_payment_reference as payment_reference,
-  era.closest_remittance_claim_id as remittance_claim_id,
-  -- Additional remittance metrics
-  era.total_remittance_count,
-  era.earliest_settlement_date,
-  era.latest_settlement_date,
-  -- Calculated fields
-  EXTRACT(DAYS FROM (ce.event_time - LAG(ce.event_time) OVER (PARTITION BY ce.claim_key_id ORDER BY ce.event_time))) as days_since_last_event,
-  -- Days between event and closest remittance
... (truncated)
```

### claims.mv_remittances_resubmission_claim_level

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 100.0%
**Accuracy:** 6.8%

**Extra Components:**
- Extra column: payment_reference
- Extra column: id
- Extra column: receiver_name
- Extra column: net ELSE 0 END
- Extra column: claim_key_id
- Extra column: date_settlement
- Extra column: payment_amount
- Extra column: receiver_id
- Extra CTE: claim_remittance_summary

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,2 +1,103 @@
 CREATE MATERIALIZED VIEW claims.mv_remittances_resubmission_claim_level AS
-SELECT * FROM claims.v_remittances_resubmission_claim_level;
+WITH claim_remittance_summary AS (
+  -- Pre-aggregate remittance data at claim level
+  SELECT 
+    rc.claim_key_id,
+    COUNT(DISTINCT rc.id) AS remittance_count,
+    SUM(ra.payment_amount) AS total_payment_amount,
+    SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS total_denied_amount,
+    MIN(rc.date_settlement) AS first_remittance_date,
+    MAX(rc.date_settlement) AS last_remittance_date,
+    MAX(rc.payment_reference) AS last_payment_reference,
+    MAX(r.receiver_name) AS receiver_name,
+    MAX(r.receiver_id) AS receiver_id
+  FROM claims.remittance_claim rc
+  JOIN claims.remittance r ON r.id = rc.remittance_id
+  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
+  GROUP BY rc.claim_key_id
+),
+claim_resubmission_summary AS (
+  -- Pre-aggregate resubmission data at claim level
+  SELECT 
+    ce.claim_key_id,
+    COUNT(*) AS resubmission_count,
+    MIN(ce.event_time) AS first_resubmission_date,
+    MAX(ce.event_time) AS last_resubmission_date,
+    MAX(cr.comment) AS last_resubmission_comment,
+    MAX(cr.resubmission_type) AS last_resubmission_type
+  FROM claims.claim_event ce
+  JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce.id
+  WHERE ce.type = 2  -- RESUBMISSION events
+  GROUP BY ce.claim_key_id
+)
+SELECT 
+  ck.id AS claim_key_id,
+  ck.claim_id AS external_claim_id,
+  c.id AS claim_id_internal,
+  c.payer_id,
+  c.provider_id,
+  c.member_id,
+  c.emirates_id_number,
+  c.gross AS claim_gross_amount,
+  c.patient_share AS claim_patient_share,
+  c.net AS claim_net_amount,
+  c.tx_at AS claim_submission_date,
+  c.comments AS claim_comments,
+  
... (truncated)
```

### refresh_claim_details_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_rejected_claims_receiver_payer

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 100.0%
**Accuracy:** 18.3%

**Extra Components:**
- Extra column: receiver_name
- Extra column: net ELSE 0 END
- Extra column: net
- Extra column: claim_id END
- Extra column: payer_id
- Extra column: claim_id
- Extra column: 2
  )
- Extra column: name
- Extra column: receiver_id

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,2 +1,22 @@
 CREATE MATERIALIZED VIEW claims.mv_rejected_claims_receiver_payer AS
-SELECT * FROM claims.v_rejected_claims_receiver_payer;
+SELECT 
+  r.receiver_name,
+  r.receiver_id,
+  c.payer_id,
+  pay.name AS payer_name,
+  COUNT(DISTINCT ck.claim_id) AS total_claims,
+  COUNT(DISTINCT CASE WHEN ra.denial_code IS NOT NULL THEN ck.claim_id END) AS rejected_claims,
+  SUM(c.net) AS total_claim_amount,
+  SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS total_rejected_amount,
+  ROUND(
+    (COUNT(DISTINCT CASE WHEN ra.denial_code IS NOT NULL THEN ck.claim_id END)::DECIMAL / 
+     COUNT(DISTINCT ck.claim_id)) * 100, 2
+  ) AS rejection_rate_percentage
+FROM claims.claim_key ck
+JOIN claims.claim c ON c.claim_key_id = ck.id
+LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
+LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
+LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
+LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
+GROUP BY r.receiver_name, r.receiver_id, c.payer_id, pay.name
+ORDER BY total_rejected_amount DESC;
```

### refresh_monthly_agg_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### FUNCTION

**Type:** COMMENT
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### refresh_remittances_resubmission_activity_level_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_doctor_denial_detail

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 100.0%
**Accuracy:** 7.7%

**Extra Components:**
- Extra column: payment_reference
- Extra column: id
- Extra column: member_id
- Extra column: emirates_id_number
- Extra column: start_at
- Extra column: tx_at
- Extra column: payer_id
- Extra column: description
- Extra column: date_settlement
- Extra column: provider_id
- Extra column: created_at
- Extra column: type
- Extra column: name
- Extra column: clinician_code
- Extra column: receiver_id
- Extra column: receiver_name
- Extra column: net
- Extra column: denial_code
- Extra column: specialty
- Extra column: clinician
- Extra column: facility_id
- Extra column: claim_id
- Extra column: end_at
- Extra column: code
- Extra column: denial_reason

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,2 +1,62 @@
 CREATE MATERIALIZED VIEW claims.mv_doctor_denial_detail AS
-SELECT * FROM claims.v_doctor_denial_detail;
+SELECT 
+  a.clinician,
+  cl.name AS clinician_name,
+  cl.clinician_code,
+  cl.specialty AS clinician_specialty,
+  a.id AS activity_id,
+  a.code AS activity_code,
+  a.description AS activity_description,
+  a.net AS activity_net_amount,
+  a.created_at AS activity_created_at,
+  
+  -- Claim information
+  ck.claim_id AS external_claim_id,
+  c.id AS claim_id_internal,
+  c.payer_id,
+  c.provider_id,
+  c.member_id,
+  c.emirates_id_number,
+  c.net AS claim_net_amount,
+  c.tx_at AS claim_submission_date,
+  
+  -- Encounter information
+  e.facility_id,
+  e.type AS encounter_type,
+  e.start_at AS encounter_start,
+  e.end_at AS encounter_end,
+  
+  -- Denial information
+  ra.denial_code,
+  ra.denial_reason,
+  ra.created_at AS denial_date,
+  rc.date_settlement,
+  rc.payment_reference,
+  r.receiver_name,
+  r.receiver_id,
+  
+  -- Reference data
+  f.name AS facility_name,
+  p.name AS provider_name,
+  pay.name AS payer_name,
+  et.description AS encounter_type_description,
+  ac.description AS activity_code_description,
+  dc.description AS denial_code_description
+
+FROM claims.activity a
... (truncated)
```

### claims.mv_remittance_advice_header

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 100.0%
**Accuracy:** 21.3%

**Extra Components:**
- Extra column: payment_reference
- Extra column: id
- Extra column: receiver_name
- Extra column: net ELSE 0 END
- Extra column: net
- Extra column: created_at
- Extra column: payment_amount
- Extra column: receiver_id

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,2 +1,16 @@
 CREATE MATERIALIZED VIEW claims.mv_remittance_advice_header AS
-SELECT * FROM claims.v_remittance_advice_header;
+SELECT 
+  r.id AS remittance_id,
+  r.receiver_name,
+  r.receiver_id,
+  r.created_at AS remittance_date,
+  r.payment_reference,
+  COUNT(DISTINCT rc.id) AS claim_count,
+  COUNT(DISTINCT ra.id) AS activity_count,
+  SUM(ra.payment_amount) AS total_payment_amount,
+  SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS total_denied_amount,
+  SUM(ra.net) AS total_remittance_amount
+FROM claims.remittance r
+LEFT JOIN claims.remittance_claim rc ON rc.remittance_id = r.id
+LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
+GROUP BY r.id, r.receiver_name, r.receiver_id, r.created_at, r.payment_reference;
```

### claims.mv_rejected_claims_claim_wise

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 100.0%
**Accuracy:** 12.0%

**Extra Components:**
- Extra column: payment_reference
- Extra column: id
- Extra column: member_id
- Extra column: emirates_id_number
- Extra column: start_at
- Extra column: tx_at
- Extra column: payer_id
- Extra column: description
- Extra column: date_settlement
- Extra column: provider_id
- Extra column: created_at
- Extra column: type
- Extra column: receiver_id
- Extra column: name
- Extra column: receiver_name
- Extra column: net
- Extra column: denial_code
- Extra column: facility_id
- Extra column: claim_id
- Extra column: denial_reason
- Extra column: activity_id

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,2 +1,47 @@
 CREATE MATERIALIZED VIEW claims.mv_rejected_claims_claim_wise AS
-SELECT * FROM claims.v_rejected_claims_claim_wise;
+SELECT 
+  ck.claim_id AS external_claim_id,
+  c.id AS claim_id_internal,
+  c.payer_id,
+  c.provider_id,
+  c.member_id,
+  c.emirates_id_number,
+  c.net AS claim_net_amount,
+  c.tx_at AS claim_submission_date,
+  
+  -- Encounter information
+  e.facility_id,
+  e.type AS encounter_type,
+  e.start_at AS encounter_start,
+  
+  -- Rejection details
+  ra.activity_id,
+  ra.net AS rejected_activity_amount,
+  ra.denial_code,
+  ra.denial_reason,
+  ra.created_at AS rejection_date,
+  rc.date_settlement,
+  rc.payment_reference,
+  r.receiver_name,
+  r.receiver_id,
+  
+  -- Reference data
+  f.name AS facility_name,
+  p.name AS provider_name,
+  pay.name AS payer_name,
+  et.description AS encounter_type_description,
+  dc.description AS denial_code_description
+
+FROM claims.claim_key ck
+JOIN claims.claim c ON c.claim_key_id = ck.id
+LEFT JOIN claims.encounter e ON e.claim_id = c.id
+LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
+LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
+LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
+LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
+LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
+LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
+LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
+LEFT JOIN claims_ref.denial_code dc ON dc.code = ra.denial_code
+WHERE ra.denial_code IS NOT NULL  -- Only rejected activities
... (truncated)
```

### claims.mv_remittance_advice_claim_wise

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 100.0%
**Accuracy:** 9.2%

**Extra Components:**
- Extra column: payment_reference
- Extra column: id
- Extra column: member_id
- Extra column: emirates_id_number
- Extra column: start_at
- Extra column: gross
- Extra column: tx_at
- Extra column: payer_id
- Extra column: description
- Extra column: date_settlement
- Extra column: provider_id
- Extra column: created_at
- Extra column: type
- Extra column: receiver_id
- Extra column: name
- Extra column: receiver_name
- Extra column: net ELSE 0 END
- Extra column: net
- Extra column: patient_share
- Extra column: facility_id
- Extra column: claim_id
- Extra column: end_at
- Extra column: payment_amount

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,2 +1,54 @@
 CREATE MATERIALIZED VIEW claims.mv_remittance_advice_claim_wise AS
-SELECT * FROM claims.v_remittance_advice_claim_wise;
+SELECT 
+  r.id AS remittance_id,
+  r.receiver_name,
+  r.receiver_id,
+  r.created_at AS remittance_date,
+  r.payment_reference,
+  rc.id AS remittance_claim_id,
+  rc.date_settlement,
+  ck.claim_id AS external_claim_id,
+  c.id AS claim_id_internal,
+  c.payer_id,
+  c.provider_id,
+  c.member_id,
+  c.emirates_id_number,
+  c.gross AS claim_gross_amount,
+  c.patient_share AS claim_patient_share,
+  c.net AS claim_net_amount,
+  c.tx_at AS claim_submission_date,
+  
+  -- Encounter information
+  e.facility_id,
+  e.type AS encounter_type,
+  e.start_at AS encounter_start,
+  e.end_at AS encounter_end,
+  
+  -- Remittance claim summary
+  COUNT(DISTINCT ra.id) AS activity_count,
+  SUM(ra.payment_amount) AS total_payment_amount,
+  SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS total_denied_amount,
+  SUM(ra.net) AS total_remittance_amount,
+  
+  -- Reference data
+  f.name AS facility_name,
+  p.name AS provider_name,
+  pay.name AS payer_name,
+  et.description AS encounter_type_description
+
+FROM claims.remittance r
+JOIN claims.remittance_claim rc ON rc.remittance_id = r.id
+JOIN claims.claim_key ck ON ck.id = rc.claim_key_id
+JOIN claims.claim c ON c.claim_key_id = ck.id
+LEFT JOIN claims.encounter e ON e.claim_id = c.id
+LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
+LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
+LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
... (truncated)
```

### claims.mv_balance_amount_initial

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 100.0%
**Accuracy:** 74.2%

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,2 +1,2 @@
 CREATE MATERIALIZED VIEW claims.mv_balance_amount_initial AS
-SELECT * FROM claims.v_initial_not_remitted_balance;
+SELECT * FROM claims.mv_balance_amount_summary WHERE remittance_count = 0;
```

### refresh_resubmission_cycles_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### claims.mv_remittance_advice_activity_wise

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 100.0%
**Accuracy:** 8.8%

**Extra Components:**
- Extra column: payment_reference
- Extra column: id
- Extra column: member_id
- Extra column: emirates_id_number
- Extra column: start_at
- Extra column: tx_at
- Extra column: payer_id
- Extra column: description
- Extra column: date_settlement
- Extra column: provider_id
- Extra column: created_at
- Extra column: type
- Extra column: receiver_id
- Extra column: name
- Extra column: receiver_name
- Extra column: net
- Extra column: denial_code
- Extra column: clinician
- Extra column: facility_id
- Extra column: claim_id
- Extra column: end_at
- Extra column: code
- Extra column: denial_reason
- Extra column: activity_id
- Extra column: payment_amount

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,2 +1,62 @@
 CREATE MATERIALIZED VIEW claims.mv_remittance_advice_activity_wise AS
-SELECT * FROM claims.v_remittance_advice_activity_wise;
+SELECT 
+  r.id AS remittance_id,
+  r.receiver_name,
+  r.receiver_id,
+  r.created_at AS remittance_date,
+  r.payment_reference,
+  rc.id AS remittance_claim_id,
+  rc.date_settlement,
+  ra.id AS remittance_activity_id,
+  ra.activity_id,
+  ra.net AS activity_net_amount,
+  ra.payment_amount AS activity_payment_amount,
+  ra.denial_code,
+  ra.denial_reason,
+  ra.created_at AS remittance_activity_created_at,
+  
+  -- Activity information
+  a.code AS activity_code,
+  a.description AS activity_description,
+  a.clinician AS activity_clinician,
+  a.created_at AS activity_created_at,
+  
+  -- Claim information
+  ck.claim_id AS external_claim_id,
+  c.id AS claim_id_internal,
+  c.payer_id,
+  c.provider_id,
+  c.member_id,
+  c.emirates_id_number,
+  c.net AS claim_net_amount,
+  c.tx_at AS claim_submission_date,
+  
+  -- Encounter information
+  e.facility_id,
+  e.type AS encounter_type,
+  e.start_at AS encounter_start,
+  e.end_at AS encounter_end,
+  
+  -- Reference data
+  f.name AS facility_name,
+  p.name AS provider_name,
+  pay.name AS payer_name,
+  cl.name AS clinician_name,
+  et.description AS encounter_type_description,
+  ac.description AS activity_code_description,
... (truncated)
```

### claims.mv_claim_details_complete

**Type:** MATERIALIZED_VIEW
**Status:** DIFFERENT
**Completeness:** 12.5%
**Accuracy:** 3.9%

**Missing Components:**
- Missing column: 0) as total_payment_amount
- Missing column: -- latest denial
- Missing column: denial_codes
- Missing column: paid_amount
- Missing column: activity_id
- Missing CTE: activity_remittance_agg

**Extra Components:**
- Extra column: payment_reference
- Extra column: id
- Extra column: receiver_name
- Extra column: comment
- Extra column: resubmission_type
- Extra column: net
- Extra column: denial_code
- Extra column: clinician
- Extra column: denial_code IS NOT NULL THEN 'DENIED'
      ELSE 'PENDING'
    END
- Extra column: description
- Extra column: date_settlement
- Extra column: code
- Extra column: denial_reason
- Extra column: created_at
- Extra column: payment_amount
- Extra column: receiver_id
- Extra column: event_time
- Extra CTE: activity_timeline

**Line-by-Line Diff:**
```diff
--- source
+++ docker
@@ -1,82 +1,116 @@
 CREATE MATERIALIZED VIEW claims.mv_claim_details_complete AS
-WITH activity_remittance_agg AS (
-  -- CUMULATIVE-WITH-CAP: Pre-aggregate remittance data per activity using claim_activity_summary
-  -- WHY: Prevents overcounting from multiple remittances per activity, uses latest denial logic
-  -- HOW: Leverages claims.claim_activity_summary which already implements cumulative-with-cap semantics
+WITH activity_timeline AS (
+  -- Get activity timeline with remittance and resubmission data
   SELECT 
-    a.activity_id,
+    a.id AS activity_id,
     a.claim_id,
-    -- Use pre-computed activity summary for accurate financial data
-    COALESCE(cas.paid_amount, 0) as total_payment_amount,              -- capped paid across remittances
-    (cas.denial_codes)[1] as latest_denial_code,                       -- latest denial from pre-computed summary
-    MAX(rc.date_settlement) as latest_settlement_date,
-    MAX(rc.payment_reference) as latest_payment_reference,
-    COALESCE(cas.remittance_count, 0) as remittance_count,             -- remittance count from pre-computed summary
-    -- Additional remittance metrics from pre-computed summary
-    COALESCE(cas.submitted_amount, 0) as total_remitted_amount,        -- submitted as remitted baseline
-    CASE WHEN cas.activity_status = 'FULLY_PAID' OR cas.activity_status = 'PARTIALLY_PAID' THEN 1 ELSE 0 END as paid_remittance_count,
-    CASE WHEN cas.activity_status = 'REJECTED' THEN 1 ELSE 0 END as rejected_remittance_count
+    a.code AS activity_code,
+    a.description AS activity_description,
+    a.net AS activity_net_amount,
+    a.created_at AS activity_created_at,
+    a.clinician AS activity_clinician,
+    
+    -- Remittance data for this activity
+    ra.payment_amount AS activity_payment_amount,
+    ra.denial_code AS activity_denial_code,
+    ra.denial_reason AS activity_denial_reason,
+    ra.created_at AS remittance_activity_created_at,
+    rc.date_settlement AS remittance_date,
+    rc.payment_reference,
+    r.receiver_name,
+    r.receiver_id,
+    
+    -- Resubmission data for this activity
+    cr.comment AS resubmission_comment,
+    cr.resubmission_type,
+    ce.event_time AS resubmission_date,
+    
+    -- Activity status
+    CASE 
+      WHEN ra.payment_amount > 0 THEN 'PAID'
+      WHEN ra.denial_code IS NOT NULL THEN 'DENIED'
+      ELSE 'PENDING'
... (truncated)
```

### refresh_rejected_claims_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

### refresh_encounterwise_mv

**Type:** FUNCTION
**Status:** MISSING
**Completeness:** 0.0%
**Accuracy:** 0.0%

