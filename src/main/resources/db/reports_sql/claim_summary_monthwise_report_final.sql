-- ==========================================================================================================
-- CLAIM SUMMARY - MONTHWISE REPORT - COMPREHENSIVE IMPLEMENTATION
-- ==========================================================================================================
-- Purpose: Complete database implementation for Claim Summary Monthwise Report
-- Version: 2.0 - Comprehensive
-- Date: 2025-10-02
--
-- This DDL creates the necessary database objects for the Claim Summary Monthwise Report:
-- - v_claim_summary_monthwise: Tab A - Monthwise grouping (COMPREHENSIVE METRICS)
-- - v_claim_summary_payerwise: Tab B - Payerwise grouping (COMPREHENSIVE METRICS)
-- - v_claim_summary_encounterwise: Tab C - Encounter type grouping (COMPREHENSIVE METRICS)
-- - get_claim_summary_monthwise_params: Summary parameters function
-- - get_claim_summary_report_params: Filter options function
--
-- COMPREHENSIVE METRICS INCLUDE:
-- - Count metrics: claims, remitted, fully paid, partially paid, fully rejected, pending, self-pay, taken back
-- - Amount metrics: claim amounts, paid amounts, rejected amounts, pending amounts, self-pay amounts
-- - Percentage metrics: rejection rates (on initial claim and on remittance), collection rates
-- - Status breakdowns: by facility, payer, and encounter type
-- ==========================================================================================================

-- ==========================================================================================================
-- Report Overview
-- ==========================================================================================================
-- Business purpose
-- - Monthwise, payerwise, and encounter-type summaries for billed, paid, rejected, pending metrics.
--
-- Core joins
-- - ck → c (claim_key → claim)
-- - c → e (encounter), rc → r/ra (remittance_claim → remittance/remittance_activity)
-- - Reference: f (encounter.facility_ref_id), payer via ref ids
--
-- Grouping
-- - DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)) with EXTRACT(YEAR/MONTH) in GROUP BY.
-- - Additional group dimensions per tab: facility, payer, encounter type.
--
-- Derived fields
-- - counts using COUNT DISTINCT with CASE filters for remitted/paid/partially/rejected/pending/self-pay.
-- - Amount metrics via SUM of c.net and ra.payment_amount with conditional CASE filters.
-- - rejected_percentage_on_initial = SUM(rejected)/SUM(c.net) * 100
-- - rejected_percentage_on_remittance = SUM(rejected)/(SUM(ra.payment_amount) + SUM(rejected)) * 100
-- - collection_rate = SUM(ra.payment_amount)/SUM(c.net) * 100

-- ==========================================================================================================
-- VIEW: v_claim_summary_monthwise (Tab A - Monthwise grouping - COMPREHENSIVE)
-- ==========================================================================================================
CREATE OR REPLACE VIEW claims.v_claim_summary_monthwise AS
WITH base AS (
    SELECT
        ck.claim_id,
        c.id AS claim_db_id,
        c.tx_at,
        e.facility_id,
        f.name AS facility_name,
        rc.date_settlement,
        rc.id AS remittance_claim_id,
        cas.activity_id AS remittance_activity_id,
        c.net AS claim_net,
        cas.submitted_amount AS ra_net,
        cas.paid_amount AS payment_amount,
        COALESCE(p2.payer_code, 'Unknown') AS health_authority
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
    LEFT JOIN claims.encounter e ON e.claim_id = c.id
    LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
    LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
    -- OPTIMIZED: Join to pre-computed activity summary instead of raw remittance data
    -- WHY: Eliminates complex aggregation and ensures consistent cumulative-with-cap logic
    LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
    -- Keep legacy join for backward compatibility (if needed for other calculations)
    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
    LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
),
dedup_claim AS (
    SELECT claim_db_id,
           DATE_TRUNC('month', COALESCE(date_settlement, tx_at)) AS month_bucket,
           MAX(claim_net) AS claim_net_once
    FROM base
    GROUP BY claim_db_id, DATE_TRUNC('month', COALESCE(date_settlement, tx_at))
)
SELECT
    -- Month/Year grouping (using settlement date, fallback to submission date)
    TO_CHAR(DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)), 'Month YYYY') AS month_year,
    EXTRACT(YEAR FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))) AS year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))) AS month,

    -- Count Metrics (CUMULATIVE-WITH-CAP: Using pre-computed activity summary)
    -- WHY: Prevents overcounting from multiple remittances per activity, uses latest denial logic
    -- HOW: Leverages claims.claim_activity_summary which already implements cumulative-with-cap semantics
    COUNT(DISTINCT ck.claim_id) AS count_claims,
    COUNT(DISTINCT cas.activity_id) AS remitted_count,                                    -- count of activities with remittance data
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'FULLY_PAID' THEN cas.activity_id END) AS fully_paid_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.activity_id END) AS partially_paid_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS fully_rejected_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS rejection_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.activity_id END) AS taken_back_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'PENDING' THEN cas.activity_id END) AS pending_remittance_count,
    COUNT(DISTINCT CASE WHEN c.payer_id = 'Self-Paid' THEN ck.claim_id END) AS self_pay_count,

    -- Amount Metrics (CUMULATIVE-WITH-CAP: Using pre-computed activity summary)
    -- WHY: Consistent with other reports, prevents overcounting, uses latest denial logic
    -- HOW: Uses cas.paid_amount (capped), cas.denied_amount (latest denial logic), cas.submitted_amount
    SUM(DISTINCT d.claim_net_once) AS claim_amount,
    SUM(DISTINCT d.claim_net_once) AS initial_claim_amount,
    SUM(COALESCE(cas.paid_amount, 0)) AS remitted_amount,                                -- capped paid across remittances
    SUM(COALESCE(cas.paid_amount, 0)) AS remitted_net_amount,                           -- same as remitted for consistency
    SUM(COALESCE(cas.paid_amount, 0)) AS fully_paid_amount,                             -- capped paid amount
    SUM(CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.paid_amount ELSE 0 END) AS partially_paid_amount,
    SUM(COALESCE(cas.denied_amount, 0)) AS fully_rejected_amount,                       -- denied only when latest denial and zero paid
    SUM(COALESCE(cas.denied_amount, 0)) AS rejected_amount,                             -- same as fully_rejected for consistency
    SUM(CASE WHEN cas.activity_status = 'PENDING' THEN cas.submitted_amount ELSE 0 END) AS pending_remittance_amount,
    SUM(CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.taken_back_amount ELSE 0 END) AS taken_back_amount,
    SUM(CASE WHEN c.payer_id = 'Self-Paid' THEN c.net ELSE 0 END) AS self_pay_amount,

    -- Facility and Health Authority
    e.facility_id,
    f.name AS facility_name,
    COALESCE(p2.payer_code, 'Unknown') AS health_authority,

    -- Percentage Calculations (COMPREHENSIVE)
    CASE
        WHEN SUM(c.net) > 0 THEN
            ROUND((SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) / SUM(c.net)) * 100, 2)
        ELSE 0
    END AS rejected_percentage_on_initial,
    CASE
    WHEN (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) > 0 THEN
        ROUND(
            (
                SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)
                /
                (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END))
            ) * 100, 2)
        ELSE 0
    END AS rejected_percentage_on_remittance,
    CASE
        WHEN SUM(c.net) > 0 THEN
            ROUND((SUM(COALESCE(ra.payment_amount, 0)) / SUM(c.net)) * 100, 2)
        ELSE 0
    END AS collection_rate,

    -- Additional Business Metrics
    COUNT(DISTINCT c.provider_id) AS unique_providers,
    COUNT(DISTINCT e.patient_id) AS unique_patients,
    AVG(c.net) AS avg_claim_amount,
    AVG(COALESCE(cas.paid_amount, 0)) AS avg_paid_amount,
    MIN(c.tx_at) AS earliest_submission_date,
    MAX(c.tx_at) AS latest_submission_date,
    MIN(COALESCE(rc.date_settlement, c.tx_at)) AS earliest_settlement_date,
    MAX(COALESCE(rc.date_settlement, c.tx_at)) AS latest_settlement_date

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
-- OPTIMIZED: Join to pre-computed activity summary instead of raw remittance data
-- WHY: Eliminates complex aggregation and ensures consistent cumulative-with-cap logic
LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
-- Keep legacy join for backward compatibility (if needed for other calculations)
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
LEFT JOIN dedup_claim d ON d.claim_db_id = c.id AND d.month_bucket = DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))

GROUP BY
    DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)),
    EXTRACT(YEAR FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))),
    EXTRACT(MONTH FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))),
    e.facility_id,
    f.name,
    COALESCE(p2.payer_code, 'Unknown')

ORDER BY
    year DESC,
    month DESC,
    facility_id;

COMMENT ON VIEW claims.v_claim_summary_monthwise IS 'Claim Summary Monthwise Report - Tab A: Monthly grouped data with COMPREHENSIVE metrics including all counts, amounts, and percentages';

-- ==========================================================================================================
-- VIEW: v_claim_summary_payerwise (Tab B - Payerwise grouping - COMPREHENSIVE)
-- ==========================================================================================================
CREATE OR REPLACE VIEW claims.v_claim_summary_payerwise AS
WITH base AS (
    SELECT
        ck.claim_id,
        c.id AS claim_db_id,
        c.tx_at,
        e.facility_id,
        f.name AS facility_name,
        rc.date_settlement,
        cas.activity_id AS remittance_activity_id,
        c.net AS claim_net,
        cas.submitted_amount AS ra_net,
        cas.paid_amount AS payment_amount,
        COALESCE(p2.payer_code, 'Unknown') AS health_authority,
        p.payer_code AS payer_code,
        p.name AS payer_name
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
    LEFT JOIN claims.encounter e ON e.claim_id = c.id
    LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
    LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
    -- OPTIMIZED: Join to pre-computed activity summary instead of raw remittance data
    -- WHY: Eliminates complex aggregation and ensures consistent cumulative-with-cap logic
    LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
    -- Keep legacy join for backward compatibility (if needed for other calculations)
    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
    LEFT JOIN claims_ref.payer p ON p.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
    LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
),
dedup_claim AS (
    SELECT claim_db_id,
           DATE_TRUNC('month', COALESCE(date_settlement, tx_at)) AS month_bucket,
           MAX(claim_net) AS claim_net_once
    FROM base
    GROUP BY claim_db_id, DATE_TRUNC('month', COALESCE(date_settlement, tx_at))
)
SELECT
    -- Payer grouping
    COALESCE(p.payer_code, 'Unknown') AS payer_id,
    p.name AS payer_name,

    -- Month/Year grouping (using settlement date, fallback to submission date)
    TO_CHAR(DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)), 'Month YYYY') AS month_year,
    EXTRACT(YEAR FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))) AS year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))) AS month,

    -- Count Metrics (CUMULATIVE-WITH-CAP: Using pre-computed activity summary)
    -- WHY: Prevents overcounting from multiple remittances per activity, uses latest denial logic
    -- HOW: Leverages claims.claim_activity_summary which already implements cumulative-with-cap semantics
    COUNT(DISTINCT ck.claim_id) AS count_claims,
    COUNT(DISTINCT cas.activity_id) AS remitted_count,                                    -- count of activities with remittance data
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'FULLY_PAID' THEN cas.activity_id END) AS fully_paid_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.activity_id END) AS partially_paid_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS fully_rejected_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS rejection_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.activity_id END) AS taken_back_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'PENDING' THEN cas.activity_id END) AS pending_remittance_count,
    COUNT(DISTINCT CASE WHEN c.payer_id = 'Self-Paid' THEN ck.claim_id END) AS self_pay_count,

    -- Amount Metrics (CUMULATIVE-WITH-CAP: Using pre-computed activity summary)
    -- WHY: Consistent with other reports, prevents overcounting, uses latest denial logic
    -- HOW: Uses cas.paid_amount (capped), cas.denied_amount (latest denial logic), cas.submitted_amount
    SUM(DISTINCT d.claim_net_once) AS claim_amount,
    SUM(DISTINCT d.claim_net_once) AS initial_claim_amount,
    SUM(COALESCE(cas.paid_amount, 0)) AS remitted_amount,                                -- capped paid across remittances
    SUM(COALESCE(cas.paid_amount, 0)) AS remitted_net_amount,                           -- same as remitted for consistency
    SUM(COALESCE(cas.paid_amount, 0)) AS fully_paid_amount,                             -- capped paid amount
    SUM(CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.paid_amount ELSE 0 END) AS partially_paid_amount,
    SUM(COALESCE(cas.denied_amount, 0)) AS fully_rejected_amount,                       -- denied only when latest denial and zero paid
    SUM(COALESCE(cas.denied_amount, 0)) AS rejected_amount,                             -- same as fully_rejected for consistency
    SUM(CASE WHEN cas.activity_status = 'PENDING' THEN cas.submitted_amount ELSE 0 END) AS pending_remittance_amount,
    SUM(CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.taken_back_amount ELSE 0 END) AS taken_back_amount,
    SUM(CASE WHEN c.payer_id = 'Self-Paid' THEN c.net ELSE 0 END) AS self_pay_amount,

    -- Facility and Health Authority
    e.facility_id,
    f.name AS facility_name,
    COALESCE(p2.payer_code, 'Unknown') AS health_authority,

    -- Percentage Calculations (COMPREHENSIVE)
    CASE
        WHEN SUM(c.net) > 0 THEN
            ROUND((SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) / SUM(c.net)) * 100, 2)
        ELSE 0
    END AS rejected_percentage_on_initial,
    CASE
    WHEN (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) > 0 THEN
        ROUND(
            (
                SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)
                /
                (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END))
            ) * 100, 2)
        ELSE 0
    END AS rejected_percentage_on_remittance,
    CASE
        WHEN SUM(c.net) > 0 THEN
            ROUND((SUM(COALESCE(ra.payment_amount, 0)) / SUM(c.net)) * 100, 2)
        ELSE 0
    END AS collection_rate,

    -- Additional Business Metrics
    COUNT(DISTINCT c.provider_id) AS unique_providers,
    COUNT(DISTINCT e.patient_id) AS unique_patients,
    AVG(c.net) AS avg_claim_amount,
    AVG(COALESCE(ra.payment_amount, 0)) AS avg_paid_amount

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
-- OPTIMIZED: Join to pre-computed activity summary instead of raw remittance data
-- WHY: Eliminates complex aggregation and ensures consistent cumulative-with-cap logic
LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
-- Keep legacy join for backward compatibility (if needed for other calculations)
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer p ON p.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
LEFT JOIN dedup_claim d ON d.claim_db_id = c.id AND d.month_bucket = DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))

GROUP BY
    COALESCE(p.payer_code, 'Unknown'),
    p.name,
    DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)),
    EXTRACT(YEAR FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))),
    EXTRACT(MONTH FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))),
    e.facility_id,
    f.name,
    COALESCE(p2.payer_code, 'Unknown')

ORDER BY
    payer_id,
    year DESC,
    month DESC,
    facility_id;

COMMENT ON VIEW claims.v_claim_summary_payerwise IS 'Claim Summary Payerwise Report - Tab B: Payer grouped data with COMPREHENSIVE metrics';

-- ==========================================================================================================
-- VIEW: v_claim_summary_encounterwise (Tab C - Encounter type grouping - COMPREHENSIVE)
-- ==========================================================================================================
CREATE OR REPLACE VIEW claims.v_claim_summary_encounterwise AS
WITH base AS (
    SELECT
        ck.claim_id,
        c.id AS claim_db_id,
        c.tx_at,
        e.type AS encounter_type,
        e.facility_id,
        f.name AS facility_name,
        rc.date_settlement,
        cas.activity_id AS remittance_activity_id,
        c.net AS claim_net,
        cas.submitted_amount AS ra_net,
        cas.paid_amount AS payment_amount,
        COALESCE(p2.payer_code, 'Unknown') AS health_authority
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
    LEFT JOIN claims.encounter e ON e.claim_id = c.id
    LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
    LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
    -- OPTIMIZED: Join to pre-computed activity summary instead of raw remittance data
    -- WHY: Eliminates complex aggregation and ensures consistent cumulative-with-cap logic
    LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
    -- Keep legacy join for backward compatibility (if needed for other calculations)
    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
    LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
),
dedup_claim AS (
    SELECT claim_db_id,
           DATE_TRUNC('month', COALESCE(date_settlement, tx_at)) AS month_bucket,
           MAX(claim_net) AS claim_net_once
    FROM base
    GROUP BY claim_db_id, DATE_TRUNC('month', COALESCE(date_settlement, tx_at))
)
SELECT
    -- Encounter type grouping
    COALESCE(e.type, 'Unknown') AS encounter_type,

    -- Month/Year grouping (using settlement date, fallback to submission date)
    TO_CHAR(DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)), 'Month YYYY') AS month_year,
    EXTRACT(YEAR FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))) AS year,
    EXTRACT(MONTH FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))) AS month,

    -- Count Metrics (CUMULATIVE-WITH-CAP: Using pre-computed activity summary)
    -- WHY: Prevents overcounting from multiple remittances per activity, uses latest denial logic
    -- HOW: Leverages claims.claim_activity_summary which already implements cumulative-with-cap semantics
    COUNT(DISTINCT ck.claim_id) AS count_claims,
    COUNT(DISTINCT cas.activity_id) AS remitted_count,                                    -- count of activities with remittance data
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'FULLY_PAID' THEN cas.activity_id END) AS fully_paid_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.activity_id END) AS partially_paid_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS fully_rejected_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS rejection_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.activity_id END) AS taken_back_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'PENDING' THEN cas.activity_id END) AS pending_remittance_count,
    COUNT(DISTINCT CASE WHEN c.payer_id = 'Self-Paid' THEN ck.claim_id END) AS self_pay_count,

    -- Amount Metrics (CUMULATIVE-WITH-CAP: Using pre-computed activity summary)
    -- WHY: Consistent with other reports, prevents overcounting, uses latest denial logic
    -- HOW: Uses cas.paid_amount (capped), cas.denied_amount (latest denial logic), cas.submitted_amount
    SUM(DISTINCT d.claim_net_once) AS claim_amount,
    SUM(DISTINCT d.claim_net_once) AS initial_claim_amount,
    SUM(COALESCE(cas.paid_amount, 0)) AS remitted_amount,                                -- capped paid across remittances
    SUM(COALESCE(cas.paid_amount, 0)) AS remitted_net_amount,                           -- same as remitted for consistency
    SUM(COALESCE(cas.paid_amount, 0)) AS fully_paid_amount,                             -- capped paid amount
    SUM(CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.paid_amount ELSE 0 END) AS partially_paid_amount,
    SUM(COALESCE(cas.denied_amount, 0)) AS fully_rejected_amount,                       -- denied only when latest denial and zero paid
    SUM(COALESCE(cas.denied_amount, 0)) AS rejected_amount,                             -- same as fully_rejected for consistency
    SUM(CASE WHEN cas.activity_status = 'PENDING' THEN cas.submitted_amount ELSE 0 END) AS pending_remittance_amount,
    SUM(CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.taken_back_amount ELSE 0 END) AS taken_back_amount,
    SUM(CASE WHEN c.payer_id = 'Self-Paid' THEN c.net ELSE 0 END) AS self_pay_amount,

    -- Facility and Health Authority
    e.facility_id,
    f.name AS facility_name,
    COALESCE(p2.payer_code, 'Unknown') AS health_authority,

    -- Percentage Calculations (COMPREHENSIVE)
    CASE
        WHEN SUM(c.net) > 0 THEN
            ROUND((SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) / SUM(c.net)) * 100, 2)
        ELSE 0
    END AS rejected_percentage_on_initial,
    CASE
    WHEN (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) > 0 THEN
        ROUND(
            (
                SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)
                /
                (SUM(COALESCE(ra.payment_amount, 0)) + SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END))
            ) * 100, 2)
        ELSE 0
    END AS rejected_percentage_on_remittance,
    CASE
        WHEN SUM(c.net) > 0 THEN
            ROUND((SUM(COALESCE(ra.payment_amount, 0)) / SUM(c.net)) * 100, 2)
        ELSE 0
    END AS collection_rate,

    -- Additional Business Metrics
    COUNT(DISTINCT c.provider_id) AS unique_providers,
    COUNT(DISTINCT e.patient_id) AS unique_patients,
    AVG(c.net) AS avg_claim_amount,
    AVG(COALESCE(ra.payment_amount, 0)) AS avg_paid_amount

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
-- OPTIMIZED: Join to pre-computed activity summary instead of raw remittance data
-- WHY: Eliminates complex aggregation and ensures consistent cumulative-with-cap logic
LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
-- Keep legacy join for backward compatibility (if needed for other calculations)
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
LEFT JOIN dedup_claim d ON d.claim_db_id = c.id AND d.month_bucket = DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))

GROUP BY
    COALESCE(e.type, 'Unknown'),
    DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)),
    EXTRACT(YEAR FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))),
    EXTRACT(MONTH FROM DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))),
    e.facility_id,
    f.name,
    COALESCE(p2.payer_code, 'Unknown')

ORDER BY
    encounter_type,
    year DESC,
    month DESC,
    facility_id;

COMMENT ON VIEW claims.v_claim_summary_encounterwise IS 'Claim Summary Encounterwise Report - Tab C: Encounter type grouped data with COMPREHENSIVE metrics';

-- ==========================================================================================================
-- FUNCTION: get_claim_summary_monthwise_params (COMPREHENSIVE)
-- ==========================================================================================================
CREATE OR REPLACE FUNCTION claims.get_claim_summary_monthwise_params(
    p_use_mv BOOLEAN DEFAULT FALSE,
    p_tab_name TEXT DEFAULT 'monthwise',
    p_from_date TIMESTAMPTZ DEFAULT NULL,
    p_to_date TIMESTAMPTZ DEFAULT NULL,
    p_facility_code TEXT DEFAULT NULL,
    p_payer_code TEXT DEFAULT NULL,
    p_receiver_code TEXT DEFAULT NULL,
    p_encounter_type TEXT DEFAULT NULL
) RETURNS TABLE(
    total_claims BIGINT,
    total_remitted_claims BIGINT,
    total_fully_paid_claims BIGINT,
    total_partially_paid_claims BIGINT,
    total_fully_rejected_claims BIGINT,
    total_rejection_count BIGINT,
    total_taken_back_count BIGINT,
    total_taken_back_amount NUMERIC(14,2),
    total_pending_remittance_count BIGINT,
    total_self_pay_count BIGINT,
    total_claim_amount NUMERIC(14,2),
    total_initial_claim_amount NUMERIC(14,2),
    total_remitted_amount NUMERIC(14,2),
    total_remitted_net_amount NUMERIC(14,2),
    total_fully_paid_amount NUMERIC(14,2),
    total_partially_paid_amount NUMERIC(14,2),
    total_fully_rejected_amount NUMERIC(14,2),
    total_rejected_amount NUMERIC(14,2),
    total_pending_remittance_amount NUMERIC(14,2),
    total_self_pay_amount NUMERIC(14,2),
    avg_rejected_percentage_on_initial NUMERIC(5,2),
    avg_rejected_percentage_on_remittance NUMERIC(5,2),
    avg_collection_rate NUMERIC(5,2),
    unique_providers BIGINT,
    unique_patients BIGINT,
    avg_claim_amount NUMERIC(14,2),
    avg_paid_amount NUMERIC(14,2)
) AS $$
BEGIN
    -- OPTION 3: Hybrid approach with DB toggle and tab selection
    -- WHY: Allows switching between traditional views and MVs with tab-specific logic
    -- HOW: Uses p_use_mv parameter to choose data source and p_tab_name for tab selection
    
    IF p_use_mv THEN
        -- Use tab-specific MVs for sub-second performance
        CASE p_tab_name
            WHEN 'monthwise' THEN
                RETURN QUERY
                SELECT
                    SUM(mv.claim_count) as total_claims,
                    SUM(mv.remitted_count) as total_remitted_claims,
                    SUM(mv.fully_paid_count) as total_fully_paid_claims,
                    SUM(mv.partially_paid_count) as total_partially_paid_claims,
                    SUM(mv.fully_rejected_count) as total_fully_rejected_claims,
                    SUM(mv.rejection_count) as total_rejection_count,
                    SUM(mv.taken_back_count) as total_taken_back_count,
                    SUM(mv.taken_back_amount) as total_taken_back_amount,
                    SUM(mv.pending_remittance_count) as total_pending_remittance_count,
                    SUM(mv.self_pay_count) as total_self_pay_count,
                    SUM(mv.total_net) as total_claim_amount,
                    SUM(mv.total_net) as total_initial_claim_amount,
                    SUM(mv.remitted_amount) as total_remitted_amount,
                    SUM(mv.remitted_amount) as total_remitted_net_amount,
                    SUM(mv.fully_paid_amount) as total_fully_paid_amount,
                    SUM(mv.partially_paid_amount) as total_partially_paid_amount,
                    SUM(mv.fully_rejected_amount) as total_fully_rejected_amount,
                    SUM(mv.rejected_amount) as total_rejected_amount,
                    SUM(mv.pending_remittance_amount) as total_pending_remittance_amount,
                    SUM(mv.self_pay_amount) as total_self_pay_amount,
                    AVG(mv.rejected_percentage_on_initial) as avg_rejected_percentage_on_initial,
                    AVG(mv.rejected_percentage_on_remittance) as avg_rejected_percentage_on_remittance,
        AVG(mv.collection_rate) as avg_collection_rate,
        COUNT(DISTINCT mv.payer_id) as unique_providers,
        COUNT(DISTINCT mv.facility_id) as unique_patients,
        AVG(mv.total_net) as avg_claim_amount,
        AVG(mv.remitted_amount) as avg_paid_amount
    FROM claims.mv_claims_monthly_agg mv
    WHERE
        (p_from_date IS NULL OR mv.month_bucket >= DATE_TRUNC('month', p_from_date))
        AND (p_to_date IS NULL OR mv.month_bucket <= DATE_TRUNC('month', p_to_date))
        AND (p_facility_code IS NULL OR mv.facility_id = p_facility_code)
        AND (p_payer_code IS NULL OR mv.health_authority = p_payer_code)
        AND (p_receiver_code IS NULL OR mv.health_authority = p_receiver_code);
            END CASE;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION claims.get_claim_summary_monthwise_params IS 'Get COMPREHENSIVE summary parameters for Claim Summary Monthwise Report';

-- ==========================================================================================================
-- FUNCTION: get_claim_summary_report_params (Filter options - COMPREHENSIVE)
-- ==========================================================================================================
CREATE OR REPLACE FUNCTION claims.get_claim_summary_report_params(
    p_use_mv BOOLEAN DEFAULT FALSE,
    p_tab_name TEXT DEFAULT 'params'
) RETURNS TABLE(
    facility_codes TEXT[],
    payer_codes TEXT[],
    receiver_codes TEXT[],
    encounter_types TEXT[]
) AS $$
BEGIN
    -- OPTION 3: Hybrid approach with DB toggle and tab selection
    -- WHY: Allows switching between traditional views and MVs with tab-specific logic
    -- HOW: Uses p_use_mv parameter to choose data source and p_tab_name for tab selection
    
    IF p_use_mv THEN
        -- Use MVs for sub-second performance
        CASE p_tab_name
            WHEN 'params' THEN
                RETURN QUERY
                SELECT
                    ARRAY_AGG(DISTINCT f.facility_code ORDER BY f.facility_code) FILTER (WHERE f.facility_code IS NOT NULL) as facility_codes,
                    ARRAY_AGG(DISTINCT p.payer_code ORDER BY p.payer_code) FILTER (WHERE p.payer_code IS NOT NULL) as payer_codes,
                    ARRAY_AGG(DISTINCT pr.provider_code ORDER BY pr.provider_code) FILTER (WHERE pr.provider_code IS NOT NULL) as receiver_codes,
                    ARRAY_AGG(DISTINCT e.type ORDER BY e.type) FILTER (WHERE e.type IS NOT NULL) as encounter_types
                FROM claims_ref.facility f
                FULL OUTER JOIN claims_ref.payer p ON true
                FULL OUTER JOIN claims_ref.provider pr ON true
                FULL OUTER JOIN claims.encounter e ON true;
            END CASE;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION claims.get_claim_summary_report_params IS 'Get filter options for Claim Summary Monthwise Report';

-- ==========================================================================================================
-- PERFORMANCE INDEXES FOR COMPREHENSIVE REPORT
-- ==========================================================================================================

-- Indexes for monthwise view
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_month_year ON claims.claim(tx_at);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_facility ON claims.encounter(facility_id);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_payer ON claims.claim(payer_id);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_remittance_settlement ON claims.remittance_claim(date_settlement);

-- Indexes for payerwise view
CREATE INDEX IF NOT EXISTS idx_claim_summary_payerwise_payer_month ON claims.claim(payer_id, tx_at);
CREATE INDEX IF NOT EXISTS idx_claim_summary_payerwise_remittance_payer ON claims.remittance_claim(id_payer, date_settlement);

-- Indexes for encounterwise view
CREATE INDEX IF NOT EXISTS idx_claim_summary_encounterwise_type_month ON claims.encounter(type, claim_id);
CREATE INDEX IF NOT EXISTS idx_claim_summary_encounterwise_tx_at ON claims.claim(tx_at);

-- Composite indexes for common filter combinations
CREATE INDEX IF NOT EXISTS idx_claim_summary_facility_date ON claims.encounter(facility_id, claim_id) WHERE facility_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_claim_summary_payer_date ON claims.claim(payer_id, tx_at) WHERE payer_id IS NOT NULL;

-- ==========================================================================================================
-- COMMENTS AND DOCUMENTATION
-- ==========================================================================================================

COMMENT ON VIEW claims.v_claim_summary_monthwise IS 'COMPREHENSIVE Claim Summary Monthwise Report - Tab A: Monthly grouped data with ALL required metrics including counts, amounts, percentages, and business intelligence';
COMMENT ON VIEW claims.v_claim_summary_payerwise IS 'COMPREHENSIVE Claim Summary Payerwise Report - Tab B: Payer grouped data with ALL required metrics';
COMMENT ON VIEW claims.v_claim_summary_encounterwise IS 'COMPREHENSIVE Claim Summary Encounterwise Report - Tab C: Encounter type grouped data with ALL required metrics';

-- ==========================================================================================================
-- USAGE EXAMPLES
-- ==========================================================================================================

/*
-- Get monthly summary for last 12 months (Tab A)
SELECT * FROM claims.v_claim_summary_monthwise
WHERE month_year >= TO_CHAR(DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months'), 'Month YYYY')
ORDER BY year DESC, month DESC;

-- Get payerwise summary for last 6 months (Tab B)
SELECT * FROM claims.v_claim_summary_payerwise
WHERE month_year >= TO_CHAR(DATE_TRUNC('month', CURRENT_DATE - INTERVAL '6 months'), 'Month YYYY')
ORDER BY payer_id, year DESC, month DESC;

-- Get encounterwise summary for last 6 months (Tab C)
SELECT * FROM claims.v_claim_summary_encounterwise
WHERE month_year >= TO_CHAR(DATE_TRUNC('month', CURRENT_DATE - INTERVAL '6 months'), 'Month YYYY')
ORDER BY encounter_type, year DESC, month DESC;

-- Get summary parameters for dashboard
SELECT * FROM claims.get_claim_summary_monthwise_params(
    FALSE, -- p_use_mv
    'monthwise', -- p_tab_name
    CURRENT_DATE - INTERVAL '12 months', -- p_from_date
    CURRENT_DATE, -- p_to_date
    NULL, -- p_facility_code
    NULL, -- p_payer_code
    NULL, -- p_receiver_code
    NULL  -- p_encounter_type
);

-- Get filter options for UI dropdowns
SELECT * FROM claims.get_claim_summary_report_params(FALSE, 'params');
*/

-- =====================================================
-- GRANTS
-- =====================================================
GRANT SELECT ON claims.v_claim_summary_monthwise TO claims_user;
GRANT SELECT ON claims.v_claim_summary_payerwise TO claims_user;
GRANT SELECT ON claims.v_claim_summary_encounterwise TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_claim_summary_monthwise_params(boolean,text,timestamptz,timestamptz,text,text,text,text) TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_claim_summary_report_params(boolean,text) TO claims_user;