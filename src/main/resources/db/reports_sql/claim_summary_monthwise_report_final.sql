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
        ra.id AS remittance_activity_id,
        c.net AS claim_net,
        ra.net AS ra_net,
        ra.payment_amount,
        COALESCE(p2.payer_code, 'Unknown') AS health_authority
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
    LEFT JOIN claims.encounter e ON e.claim_id = c.id
    LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
    LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
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

    -- Count Metrics (COMPREHENSIVE)
    COUNT(DISTINCT ck.claim_id) AS count_claims,
    COUNT(DISTINCT ra.id) AS remitted_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount > 0 THEN ra.id END) AS fully_paid_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN ra.id END) AS partially_paid_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.id END) AS fully_rejected_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.id END) AS rejection_count,
    COUNT(DISTINCT CASE WHEN rc.payment_reference IS NOT NULL THEN ck.claim_id END) AS taken_back_count,
    COUNT(DISTINCT CASE WHEN rc.date_settlement IS NULL THEN ck.claim_id END) AS pending_remittance_count,
    COUNT(DISTINCT CASE WHEN c.payer_id = 'Self-Paid' THEN ck.claim_id END) AS self_pay_count,

    -- Amount Metrics (COMPREHENSIVE)
    SUM(DISTINCT d.claim_net_once) AS claim_amount,
    SUM(DISTINCT d.claim_net_once) AS initial_claim_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS remitted_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS remitted_net_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS fully_paid_amount,
    SUM(CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN ra.payment_amount ELSE 0 END) AS partially_paid_amount,
    SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS fully_rejected_amount,
    SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS rejected_amount,
    SUM(CASE WHEN rc.date_settlement IS NULL THEN c.net ELSE 0 END) AS pending_remittance_amount,
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
    AVG(COALESCE(ra.payment_amount, 0)) AS avg_paid_amount,
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
        ra.id AS remittance_activity_id,
        c.net AS claim_net,
        ra.net AS ra_net,
        ra.payment_amount,
        COALESCE(p2.payer_code, 'Unknown') AS health_authority,
        p.payer_code AS payer_code,
        p.name AS payer_name
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
    LEFT JOIN claims.encounter e ON e.claim_id = c.id
    LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
    LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
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

    -- Count Metrics (COMPREHENSIVE)
    COUNT(DISTINCT ck.claim_id) AS count_claims,
    COUNT(DISTINCT ra.id) AS remitted_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount > 0 THEN ra.id END) AS fully_paid_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN ra.id END) AS partially_paid_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.id END) AS fully_rejected_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.id END) AS rejection_count,
    COUNT(DISTINCT CASE WHEN rc.payment_reference IS NOT NULL THEN ck.claim_id END) AS taken_back_count,
    COUNT(DISTINCT CASE WHEN rc.date_settlement IS NULL THEN ck.claim_id END) AS pending_remittance_count,
    COUNT(DISTINCT CASE WHEN c.payer_id = 'Self-Paid' THEN ck.claim_id END) AS self_pay_count,

    -- Amount Metrics (COMPREHENSIVE)
    SUM(DISTINCT d.claim_net_once) AS claim_amount,
    SUM(DISTINCT d.claim_net_once) AS initial_claim_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS remitted_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS remitted_net_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS fully_paid_amount,
    SUM(CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN ra.payment_amount ELSE 0 END) AS partially_paid_amount,
    SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS fully_rejected_amount,
    SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS rejected_amount,
    SUM(CASE WHEN rc.date_settlement IS NULL THEN c.net ELSE 0 END) AS pending_remittance_amount,
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
        ra.id AS remittance_activity_id,
        c.net AS claim_net,
        ra.net AS ra_net,
        ra.payment_amount,
        COALESCE(p2.payer_code, 'Unknown') AS health_authority
    FROM claims.claim_key ck
    JOIN claims.claim c ON c.claim_key_id = ck.id
    LEFT JOIN claims.encounter e ON e.claim_id = c.id
    LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
    LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
    LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
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

    -- Count Metrics (COMPREHENSIVE)
    COUNT(DISTINCT ck.claim_id) AS count_claims,
    COUNT(DISTINCT ra.id) AS remitted_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount > 0 THEN ra.id END) AS fully_paid_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN ra.id END) AS partially_paid_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.id END) AS fully_rejected_count,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.id END) AS rejection_count,
    COUNT(DISTINCT CASE WHEN rc.payment_reference IS NOT NULL THEN ck.claim_id END) AS taken_back_count,
    COUNT(DISTINCT CASE WHEN rc.date_settlement IS NULL THEN ck.claim_id END) AS pending_remittance_count,
    COUNT(DISTINCT CASE WHEN c.payer_id = 'Self-Paid' THEN ck.claim_id END) AS self_pay_count,

    -- Amount Metrics (COMPREHENSIVE)
    SUM(DISTINCT d.claim_net_once) AS claim_amount,
    SUM(DISTINCT d.claim_net_once) AS initial_claim_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS remitted_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS remitted_net_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS fully_paid_amount,
    SUM(CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN ra.payment_amount ELSE 0 END) AS partially_paid_amount,
    SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS fully_rejected_amount,
    SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS rejected_amount,
    SUM(CASE WHEN rc.date_settlement IS NULL THEN c.net ELSE 0 END) AS pending_remittance_amount,
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
    RETURN QUERY
    WITH filtered_data AS (
        SELECT
            ck.claim_id,
            c.net as claim_amount,
            CASE WHEN ra.id IS NOT NULL THEN 1 ELSE 0 END as is_remitted,
            CASE WHEN ra.payment_amount > 0 THEN 1 ELSE 0 END as is_fully_paid,
            CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN 1 ELSE 0 END as is_partially_paid,
            CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 1 ELSE 0 END as is_fully_rejected,
            CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 1 ELSE 0 END as rejection_count,
            CASE WHEN rc.payment_reference IS NOT NULL THEN 1 ELSE 0 END as taken_back_count,
            CASE WHEN rc.date_settlement IS NULL THEN 1 ELSE 0 END as pending_remittance_count,
            CASE WHEN c.payer_id = 'Self-Paid' THEN 1 ELSE 0 END as self_pay_count,
            COALESCE(ra.payment_amount, 0) as remitted_amount,
            COALESCE(ra.payment_amount, 0) as remitted_net_amount,
            COALESCE(ra.payment_amount, 0) as fully_paid_amount,
            CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN ra.payment_amount ELSE 0 END as partially_paid_amount,
            CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END as fully_rejected_amount,
            CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END as rejected_amount,
            CASE WHEN rc.date_settlement IS NULL THEN c.net ELSE 0 END as pending_remittance_amount,
            CASE WHEN c.payer_id = 'Self-Paid' THEN c.net ELSE 0 END as self_pay_amount,
            CASE
                WHEN c.net > 0 THEN
                    ROUND((CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END / c.net) * 100, 2)
                ELSE 0
            END as rejected_percentage_on_initial,
            CASE
                WHEN (COALESCE(ra.payment_amount, 0) + (CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) > 0 THEN
                    ROUND(
                        ((CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)
                         /
                         (COALESCE(ra.payment_amount, 0) + (CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END))) * 100, 2)
                ELSE 0
            END as rejected_percentage_on_remittance,
            CASE
                WHEN c.net > 0 THEN
                    ROUND((COALESCE(ra.payment_amount, 0) / c.net) * 100, 2)
                ELSE 0
            END as collection_rate,
            c.provider_id,
            e.patient_id
        FROM claims.claim_key ck
        JOIN claims.claim c ON c.claim_key_id = ck.id
        LEFT JOIN claims.encounter e ON e.claim_id = c.id
        LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
        LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
        WHERE
            (p_from_date IS NULL OR COALESCE(rc.date_settlement, c.tx_at) >= p_from_date)
            AND (p_to_date IS NULL OR COALESCE(rc.date_settlement, c.tx_at) <= p_to_date)
            AND (p_facility_code IS NULL OR e.facility_id = p_facility_code)
            AND (p_payer_code IS NULL OR c.payer_id = p_payer_code OR rc.id_payer = p_payer_code)
            AND (p_receiver_code IS NULL OR rc.provider_id = p_receiver_code)
            AND (p_encounter_type IS NULL OR e.type = p_encounter_type)
    )
    SELECT
        COUNT(DISTINCT claim_id) as total_claims,
        SUM(is_remitted) as total_remitted_claims,
        SUM(is_fully_paid) as total_fully_paid_claims,
        SUM(is_partially_paid) as total_partially_paid_claims,
        SUM(is_fully_rejected) as total_fully_rejected_claims,
        SUM(rejection_count) as total_rejection_count,
        SUM(taken_back_count) as total_taken_back_count,
        SUM(pending_remittance_count) as total_pending_remittance_count,
        SUM(self_pay_count) as total_self_pay_count,
        SUM(claim_amount) as total_claim_amount,
        SUM(claim_amount) as total_initial_claim_amount,
        SUM(remitted_amount) as total_remitted_amount,
        SUM(remitted_net_amount) as total_remitted_net_amount,
        SUM(fully_paid_amount) as total_fully_paid_amount,
        SUM(partially_paid_amount) as total_partially_paid_amount,
        SUM(fully_rejected_amount) as total_fully_rejected_amount,
        SUM(rejected_amount) as total_rejected_amount,
        SUM(pending_remittance_amount) as total_pending_remittance_amount,
        SUM(self_pay_amount) as total_self_pay_amount,
        ROUND(AVG(rejected_percentage_on_initial), 2) as avg_rejected_percentage_on_initial,
        ROUND(AVG(rejected_percentage_on_remittance), 2) as avg_rejected_percentage_on_remittance,
        ROUND(AVG(collection_rate), 2) as avg_collection_rate,
        COUNT(DISTINCT provider_id) as unique_providers,
        COUNT(DISTINCT patient_id) as unique_patients,
        ROUND(AVG(claim_amount), 2) as avg_claim_amount,
        ROUND(AVG(fully_paid_amount), 2) as avg_paid_amount
    FROM filtered_data;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION claims.get_claim_summary_monthwise_params IS 'Get COMPREHENSIVE summary parameters for Claim Summary Monthwise Report';

-- ==========================================================================================================
-- FUNCTION: get_claim_summary_report_params (Filter options - COMPREHENSIVE)
-- ==========================================================================================================
CREATE OR REPLACE FUNCTION claims.get_claim_summary_report_params() RETURNS TABLE(
    facility_codes TEXT[],
    payer_codes TEXT[],
    receiver_codes TEXT[],
    encounter_types TEXT[]
) AS $$
BEGIN
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
    CURRENT_DATE - INTERVAL '12 months',
    CURRENT_DATE,
    NULL, -- facility_code
    NULL, -- payer_code
    NULL, -- receiver_code
    NULL  -- encounter_type
);

-- Get filter options for UI dropdowns
SELECT * FROM claims.get_claim_summary_report_params();
*/

-- =====================================================
-- GRANTS
-- =====================================================
GRANT SELECT ON claims.v_claim_summary_monthwise TO claims_user;
GRANT SELECT ON claims.v_claim_summary_payerwise TO claims_user;
GRANT SELECT ON claims.v_claim_summary_encounterwise TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_claim_summary_monthwise_params(timestamptz,timestamptz,text,text,text,text) TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_claim_summary_report_params() TO claims_user;