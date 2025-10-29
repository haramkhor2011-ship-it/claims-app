-- ==========================================================================================================
-- REPORT VIEWS - SQL VIEWS FOR CLAIMS REPORTING
-- ==========================================================================================================
-- 
-- Purpose: Create all SQL views for claims reporting (not materialized views)
-- Version: 3.0 - CORRECTED FROM SOURCE FILES
-- Date: 2025-10-24
-- 
-- This script creates SQL views extracted from the actual source files:
-- - Claim summary reports (monthwise, payerwise, encounterwise) from claim_summary_monthwise_report_final.sql
-- - Balance amount reports (base, initial, resubmission) from balance_amount_report_implementation_final.sql
-- - Remittance and resubmission reports from remittances_resubmission_report_final.sql
-- - Claim details with activity from claim_details_with_activity_final.sql
-- - Rejected claims reports from rejected_claims_report_final.sql
-- - Doctor denial reports from doctor_denial_report_final.sql
-- - Remittance advice reports from remittance_advice_payerwise_report_final.sql
--
-- Note: Extensions and schemas are created in 01-init-db.sql
-- Note: Core tables are created in 02-core-tables.sql
-- Note: Reference data is created in 03-ref-data-tables.sql
-- Note: Materialized views are created in 07-materialized-views.sql
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: CLAIM SUMMARY VIEWS (from claim_summary_monthwise_report_final.sql)
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_claim_summary_monthwise (Tab A - Monthwise grouping - COMPREHENSIVE)
-- ----------------------------------------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_claim_summary_payerwise (Tab B - Payerwise grouping - COMPREHENSIVE)
-- ----------------------------------------------------------------------------------------------------------
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
    LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
    LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
    LEFT JOIN claims_ref.payer p ON p.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
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
    COALESCE(p2.payer_code, 'Unknown') AS health_authority,
    p2.name AS payer_name,

    -- Count Metrics
    COUNT(DISTINCT ck.claim_id) AS count_claims,
    COUNT(DISTINCT cas.activity_id) AS remitted_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'FULLY_PAID' THEN cas.activity_id END) AS fully_paid_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.activity_id END) AS partially_paid_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS fully_rejected_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS rejection_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.activity_id END) AS taken_back_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'PENDING' THEN cas.activity_id END) AS pending_remittance_count,
    COUNT(DISTINCT CASE WHEN c.payer_id = 'Self-Paid' THEN ck.claim_id END) AS self_pay_count,

    -- Amount Metrics
    SUM(DISTINCT d.claim_net_once) AS claim_amount,
    SUM(DISTINCT d.claim_net_once) AS initial_claim_amount,
    SUM(COALESCE(cas.paid_amount, 0)) AS remitted_amount,
    SUM(COALESCE(cas.paid_amount, 0)) AS remitted_net_amount,
    SUM(COALESCE(cas.paid_amount, 0)) AS fully_paid_amount,
    SUM(CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.paid_amount ELSE 0 END) AS partially_paid_amount,
    SUM(COALESCE(cas.denied_amount, 0)) AS fully_rejected_amount,
    SUM(COALESCE(cas.denied_amount, 0)) AS rejected_amount,
    SUM(CASE WHEN cas.activity_status = 'PENDING' THEN cas.submitted_amount ELSE 0 END) AS pending_remittance_amount,
    SUM(CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.taken_back_amount ELSE 0 END) AS taken_back_amount,
    SUM(CASE WHEN c.payer_id = 'Self-Paid' THEN c.net ELSE 0 END) AS self_pay_amount,

    -- Facility information
    e.facility_id,
    f.name AS facility_name,

    -- Percentage Calculations
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
    END AS collection_rate

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
LEFT JOIN dedup_claim d ON d.claim_db_id = c.id
GROUP BY 
    COALESCE(p2.payer_code, 'Unknown'),
    p2.name,
    e.facility_id,
    f.name
ORDER BY 
    COALESCE(p2.payer_code, 'Unknown'),
    e.facility_id,
    f.name;

COMMENT ON VIEW claims.v_claim_summary_payerwise IS 'Payerwise claim summary with cumulative-with-cap logic';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_claim_summary_encounterwise (Tab C - Encounterwise grouping - COMPREHENSIVE)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_claim_summary_encounterwise AS
WITH base AS (
    SELECT
        ck.claim_id,
        c.id AS claim_db_id,
        c.tx_at,
        e.facility_id,
        f.name AS facility_name,
        e.type AS encounter_type,
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
    LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
    LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
),
dedup_claim AS (
    SELECT claim_db_id,
           encounter_type,
           MAX(claim_net) AS claim_net_once
    FROM base
    GROUP BY claim_db_id, encounter_type
)
SELECT
    -- Encounter type grouping
    e.type AS encounter_type,
    et.description AS encounter_type_description,

    -- Count Metrics
    COUNT(DISTINCT ck.claim_id) AS count_claims,
    COUNT(DISTINCT cas.activity_id) AS remitted_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'FULLY_PAID' THEN cas.activity_id END) AS fully_paid_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.activity_id END) AS partially_paid_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS fully_rejected_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'REJECTED' THEN cas.activity_id END) AS rejection_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.activity_id END) AS taken_back_count,
    COUNT(DISTINCT CASE WHEN cas.activity_status = 'PENDING' THEN cas.activity_id END) AS pending_remittance_count,
    COUNT(DISTINCT CASE WHEN c.payer_id = 'Self-Paid' THEN ck.claim_id END) AS self_pay_count,

    -- Amount Metrics
    SUM(DISTINCT d.claim_net_once) AS claim_amount,
    SUM(DISTINCT d.claim_net_once) AS initial_claim_amount,
    SUM(COALESCE(cas.paid_amount, 0)) AS remitted_amount,
    SUM(COALESCE(cas.paid_amount, 0)) AS remitted_net_amount,
    SUM(COALESCE(cas.paid_amount, 0)) AS fully_paid_amount,
    SUM(CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.paid_amount ELSE 0 END) AS partially_paid_amount,
    SUM(COALESCE(cas.denied_amount, 0)) AS fully_rejected_amount,
    SUM(COALESCE(cas.denied_amount, 0)) AS rejected_amount,
    SUM(CASE WHEN cas.activity_status = 'PENDING' THEN cas.submitted_amount ELSE 0 END) AS pending_remittance_amount,
    SUM(CASE WHEN cas.activity_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK') THEN cas.taken_back_amount ELSE 0 END) AS taken_back_amount,
    SUM(CASE WHEN c.payer_id = 'Self-Paid' THEN c.net ELSE 0 END) AS self_pay_amount,

    -- Facility and Health Authority
    e.facility_id,
    f.name AS facility_name,
    COALESCE(p2.payer_code, 'Unknown') AS health_authority,

    -- Percentage Calculations
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
    END AS collection_rate

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
LEFT JOIN dedup_claim d ON d.claim_db_id = c.id AND d.encounter_type = e.type
GROUP BY 
    e.type,
    et.description,
    e.facility_id,
    f.name,
    COALESCE(p2.payer_code, 'Unknown')
ORDER BY 
    e.type,
    e.facility_id,
    f.name;

COMMENT ON VIEW claims.v_claim_summary_encounterwise IS 'Encounterwise claim summary with cumulative-with-cap logic';

-- ==========================================================================================================
-- SECTION 2: BALANCE AMOUNT VIEWS (from balance_amount_report_implementation_final.sql)
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- STATUS MAPPING FUNCTION
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claims.map_status_to_text(p_status SMALLINT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE p_status
    WHEN 1 THEN 'SUBMITTED'        -- Initial claim submission
    WHEN 2 THEN 'RESUBMITTED'      -- Claim was resubmitted after rejection
    WHEN 3 THEN 'PAID'             -- Claim fully paid
    WHEN 4 THEN 'PARTIALLY_PAID'   -- Claim partially paid
    WHEN 5 THEN 'REJECTED'         -- Claim rejected/denied
    WHEN 6 THEN 'UNKNOWN'          -- Status unclear
    ELSE 'UNKNOWN'                 -- Default fallback
  END;
END;
$$;

COMMENT ON FUNCTION claims.map_status_to_text IS 'Maps claim status SMALLINT to readable text for display purposes. Used in claim_status_timeline to show current claim status.';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_balance_amount_to_be_received_base (Enhanced base balance amount view)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_balance_amount_to_be_received_base AS
WITH latest_remittance AS (
  -- Replace LATERAL JOIN with CTE for better performance
  SELECT DISTINCT ON (claim_key_id) 
    claim_key_id,
    date_settlement,
    payment_reference
  FROM claims.remittance_claim
  ORDER BY claim_key_id, date_settlement DESC
),
remittance_summary AS (
  -- CUMULATIVE-WITH-CAP: Pre-aggregate remittance data using claim_activity_summary
  -- Using cumulative-with-cap semantics to prevent overcounting from multiple remittances per activity
  SELECT 
    cas.claim_key_id,
    SUM(cas.paid_amount) as total_payment_amount,                    -- capped paid across activities
    SUM(cas.denied_amount) as total_denied_amount,                   -- denied only when latest denial and zero paid
    MAX(cas.remittance_count) as remittance_count,                   -- max across activities
    MIN(rc.date_settlement) as first_remittance_date,
    MAX(rc.date_settlement) as last_remittance_date,
    MAX(rc.payment_reference) as last_payment_reference
  FROM claims.claim_activity_summary cas
  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = cas.claim_key_id
  GROUP BY cas.claim_key_id
),
resubmission_summary AS (
  -- Pre-aggregate resubmission data
  SELECT 
    ce.claim_key_id,
    COUNT(*) as resubmission_count,
    MAX(ce.event_time) as last_resubmission_date,
    MAX(cr.comment) as last_resubmission_comment,
    MAX(cr.resubmission_type) as last_resubmission_type
  FROM claims.claim_event ce
  LEFT JOIN claims.claim_resubmission cr ON ce.id = cr.claim_event_id
  WHERE ce.type = 2  -- RESUBMISSION events
  GROUP BY ce.claim_key_id
),
latest_status AS (
  -- Get latest status for each claim
  SELECT DISTINCT ON (claim_key_id)
    claim_key_id,
    status,
    status_time
  FROM claims.claim_status_timeline
  ORDER BY claim_key_id, status_time DESC
)
SELECT 
  ck.id AS claim_key_id,
  ck.claim_id,
  c.id AS claim_id_internal,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.gross AS initial_gross_amount,
  c.patient_share AS initial_patient_share,
  c.net AS initial_net_amount,
  c.tx_at AS claim_submission_date,
  c.comments AS claim_comments,  -- For potential write-off extraction
  
  -- Encounter details
  e.facility_id,
  e.type AS encounter_type,
  e.patient_id,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  EXTRACT(YEAR FROM e.start_at) AS encounter_start_year,
  EXTRACT(MONTH FROM e.start_at) AS encounter_start_month,
  TO_CHAR(e.start_at, 'Month') AS encounter_start_month_name,
  
  -- Provider/Facility Group mapping (CORRECTED per JSON mapping)
  -- Business Logic: Use facility_id from encounter (preferred) or provider_id from claim as fallback
  -- This represents the organizational grouping for reporting purposes
  COALESCE(e.facility_id, c.provider_id) AS facility_group_id,  -- JSON: claims.encounter.facility_id (preferred) or claims.claim.provider_id
  
  -- Reference data with fallbacks (hybrid approach for reliability)
  -- Business Logic: Use reference data when available, fallback to IDs for display
  -- Provider information from reference data
  COALESCE(p.name, c.provider_id, 'UNKNOWN') AS provider_name,
  COALESCE(p.provider_code, c.provider_id) AS provider_code,
  
  -- Facility details with fallbacks
  -- Business Logic: Use facility reference data when available, fallback to facility_id
  -- Facility information from reference data
  COALESCE(f.name, e.facility_id, 'UNKNOWN') AS facility_name,
  COALESCE(f.facility_code, e.facility_id) AS facility_code,
  
  -- Payer details with fallbacks (for Receiver_Name mapping)
  -- Business Logic: Use payer reference data when available, fallback to payer_id
  -- This is used for Receiver_Name in Tab B (Initial Not Remitted Balance)
  -- Payer information from reference data
  COALESCE(pay.name, c.payer_id, 'UNKNOWN') AS payer_name,
  COALESCE(pay.payer_code, c.payer_id) AS payer_code,
  
  -- Health Authority mapping (CORRECTED per JSON mapping)
  -- Business Logic: Track health authority for both submission and remittance phases
  -- Used for filtering and grouping in reports
  if_sub.sender_id AS health_authority_submission,  -- JSON: claims.ingestion_file.sender_id for submission
  if_rem.receiver_id AS health_authority_remittance,  -- JSON: claims.ingestion_file.receiver_id for remittance
  
  -- Remittance summary (using CTE instead of LATERAL JOIN)
  -- Business Logic: Aggregate all remittance data for a claim to show payment history
  -- Used for calculating outstanding balances and payment status
  COALESCE(rs.total_payment_amount, 0) AS total_payment_amount,           -- capped paid across activities
  COALESCE(rs.total_denied_amount, 0) AS total_denied_amount,             -- denied only when latest denial and zero paid
  COALESCE(rs.remittance_count, 0) AS remittance_count,                   -- max across activities
  rs.first_remittance_date,
  rs.last_remittance_date,
  rs.last_payment_reference,
  
  -- Resubmission summary
  COALESCE(rss.resubmission_count, 0) AS resubmission_count,
  rss.last_resubmission_date,
  rss.last_resubmission_comment,
  rss.last_resubmission_type,
  
  -- Status information
  lst.status AS current_status,
  lst.status_time AS status_time,
  
  -- Calculated fields
  c.net - COALESCE(rs.total_payment_amount, 0) AS balance_amount,         -- initial net - total paid (capped)
  CASE 
    WHEN c.net - COALESCE(rs.total_payment_amount, 0) > 0 THEN 'PENDING'
    WHEN c.net - COALESCE(rs.total_payment_amount, 0) = 0 THEN 'PAID'
    ELSE 'OVERPAID'
  END AS payment_status,
  
  -- Aging calculations
  CASE 
    WHEN c.net - COALESCE(rs.total_payment_amount, 0) > 0 THEN 
      EXTRACT(DAYS FROM CURRENT_DATE - COALESCE(rs.last_remittance_date, c.tx_at))
    ELSE 0
  END AS days_since_last_remittance,
  
  CASE 
    WHEN c.net - COALESCE(rs.total_payment_amount, 0) > 0 THEN 
      EXTRACT(DAYS FROM CURRENT_DATE - c.tx_at)
    ELSE 0
  END AS days_since_submission,
  
  -- Bucket classifications
  CASE 
    WHEN c.net - COALESCE(rs.total_payment_amount, 0) > 0 AND 
         EXTRACT(DAYS FROM CURRENT_DATE - c.tx_at) <= 30 THEN '0-30 Days'
    WHEN c.net - COALESCE(rs.total_payment_amount, 0) > 0 AND 
         EXTRACT(DAYS FROM CURRENT_DATE - c.tx_at) <= 60 THEN '31-60 Days'
    WHEN c.net - COALESCE(rs.total_payment_amount, 0) > 0 AND 
         EXTRACT(DAYS FROM CURRENT_DATE - c.tx_at) <= 90 THEN '61-90 Days'
    WHEN c.net - COALESCE(rs.total_payment_amount, 0) > 0 AND 
         EXTRACT(DAYS FROM CURRENT_DATE - c.tx_at) > 90 THEN '90+ Days'
    ELSE 'PAID'
  END AS aging_bucket

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims.submission s ON c.submission_id = s.id
LEFT JOIN claims.ingestion_file if_sub ON s.ingestion_file_id = if_sub.id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.ingestion_file if_rem ON r.ingestion_file_id = if_rem.id
LEFT JOIN remittance_summary rs ON rs.claim_key_id = ck.id
LEFT JOIN resubmission_summary rss ON rss.claim_key_id = ck.id
LEFT JOIN latest_status lst ON lst.claim_key_id = ck.id;

COMMENT ON VIEW claims.v_balance_amount_to_be_received_base IS 'Enhanced base balance amount view with optimized CTEs and cumulative-with-cap logic';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_balance_amount_to_be_received (Main balance amount view)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_balance_amount_to_be_received AS
SELECT 
  *,
  -- Additional calculated fields for reporting
  CASE 
    WHEN balance_amount > 0 THEN balance_amount
    ELSE 0
  END AS pending_balance_amount,
  
  CASE 
    WHEN balance_amount < 0 THEN ABS(balance_amount)
    ELSE 0
  END AS overpaid_amount,
  
  -- Status flags
  CASE WHEN balance_amount > 0 THEN true ELSE false END AS has_pending_balance,
  CASE WHEN resubmission_count > 0 THEN true ELSE false END AS has_resubmissions,
  CASE WHEN remittance_count > 0 THEN true ELSE false END AS has_remittances

FROM claims.v_balance_amount_to_be_received_base;

COMMENT ON VIEW claims.v_balance_amount_to_be_received IS 'Main balance amount view with additional calculated fields';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_initial_not_remitted_balance (Initial claims not yet remitted)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_initial_not_remitted_balance AS
SELECT 
  *,
  'INITIAL_NOT_REMITTED' AS balance_type
FROM claims.v_balance_amount_to_be_received_base
WHERE remittance_count = 0  -- No remittances yet
  AND balance_amount > 0;   -- Has pending balance

COMMENT ON VIEW claims.v_initial_not_remitted_balance IS 'Initial claims that have not been remitted yet';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_after_resubmission_not_remitted_balance (Claims with resubmissions but still pending)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_after_resubmission_not_remitted_balance AS
SELECT 
  *,
  'AFTER_RESUBMISSION_NOT_REMITTED' AS balance_type
FROM claims.v_balance_amount_to_be_received_base
WHERE resubmission_count > 0  -- Has resubmissions
  AND balance_amount > 0;     -- Still has pending balance

COMMENT ON VIEW claims.v_after_resubmission_not_remitted_balance IS 'Claims with resubmissions that still have pending balance';

-- ==========================================================================================================
-- SECTION 3: REMITTANCE AND RESUBMISSION VIEWS (from remittances_resubmission_report_final.sql)
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_remittances_resubmission_activity_level (Activity-level remittance and resubmission data)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_remittances_resubmission_activity_level AS
WITH claim_cycles AS (
  -- Optimize window functions - single pass instead of multiple ROW_NUMBER() calls
  SELECT 
    claim_key_id,
    type,
    event_time,
    ROW_NUMBER() OVER (PARTITION BY claim_key_id ORDER BY event_time) as cycle_number
  FROM claims.claim_event
  WHERE type IN (1, 2) -- SUBMISSION, RESUBMISSION
),
resubmission_cycles AS (
    -- Track resubmission cycles with chronological ordering (optimized)
    SELECT 
        ce.claim_key_id,
        ce.event_time,
        ce.type,
        cr.resubmission_type,
        cr.comment,
        cc.cycle_number
    FROM claims.claim_event ce
    LEFT JOIN claims.claim_resubmission cr ON ce.id = cr.claim_event_id
    JOIN claim_cycles cc ON cc.claim_key_id = ce.claim_key_id AND cc.event_time = ce.event_time
    WHERE ce.type = 2  -- Resubmission events
),
remittance_cycles AS (
    -- Track remittance cycles with chronological ordering
    SELECT 
        rc.claim_key_id,
        r.tx_at as remittance_date,
        ra.payment_amount,
        ra.denial_code,
        ra.net as activity_net,
        ra.activity_id,
        ROW_NUMBER() OVER (
            PARTITION BY rc.claim_key_id 
            ORDER BY r.tx_at
        ) as cycle_number
    FROM claims.remittance_claim rc
    JOIN claims.remittance r ON rc.remittance_id = r.id
    JOIN claims.remittance_activity ra ON rc.id = ra.remittance_claim_id
),
activity_financials AS (
    -- CUMULATIVE-WITH-CAP: Calculate financial metrics per activity using pre-computed summary
    -- WHY: Prevents overcounting from multiple remittances per activity, uses latest denial logic
    -- HOW: Leverages claims.claim_activity_summary which already implements cumulative-with-cap semantics
    SELECT 
        a.id as activity_internal_id,
        a.claim_id,
        a.activity_id,
        a.net::numeric as submitted_amount,
        -- OPTIMIZED: Use pre-computed capped paid amount (prevents overcounting)
        COALESCE(cas.paid_amount, 0::numeric) as total_paid,
        -- OPTIMIZED: Use submitted as remitted baseline (consistent with other reports)
        COALESCE(cas.submitted_amount, 0::numeric) as total_remitted,
        -- OPTIMIZED: Use pre-computed rejected amount (latest denial and zero paid logic)
        COALESCE(cas.rejected_amount, 0::numeric) as rejected_amount,
        -- OPTIMIZED: Use pre-computed remittance count
        COALESCE(cas.remittance_count, 0) as remittance_count,
        -- OPTIMIZED: Use latest denial from pre-computed summary
        (cas.denial_codes)[1] as latest_denial_code,
        -- OPTIMIZED: Use first denial from pre-computed summary (if available)
        (cas.denial_codes)[array_length(cas.denial_codes, 1)] as initial_denial_code,
        -- OPTIMIZED: Use pre-computed activity status for counts
        CASE WHEN cas.activity_status = 'FULLY_PAID' THEN 1 ELSE 0 END as fully_paid_count,
        CASE WHEN cas.activity_status = 'FULLY_PAID' THEN cas.paid_amount ELSE 0::numeric END as fully_paid_amount,
        CASE WHEN cas.activity_status = 'REJECTED' THEN 1 ELSE 0 END as fully_rejected_count,
        CASE WHEN cas.activity_status = 'REJECTED' THEN cas.denied_amount ELSE 0::numeric END as fully_rejected_amount,
        CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN 1 ELSE 0 END as partially_paid_count,
        CASE WHEN cas.activity_status = 'PARTIALLY_PAID' THEN cas.paid_amount ELSE 0::numeric END as partially_paid_amount,
        -- Self-pay detection (based on payer_id)
        COUNT(CASE WHEN c.payer_id = 'Self-Paid' THEN 1 END) as self_pay_count,
        SUM(CASE WHEN c.payer_id = 'Self-Paid' THEN a.net ELSE 0::numeric END) as self_pay_amount,
        -- Taken back amounts (negative values in remittance)
        SUM(CASE WHEN ra.payment_amount < 0 THEN ABS(ra.payment_amount) ELSE 0::numeric END) as taken_back_amount,
        COUNT(CASE WHEN ra.payment_amount < 0 THEN 1 END) as taken_back_count,
        -- Write-off amounts (from comments or adjustments)
        0::numeric as write_off_amount,  -- Will be implemented when write-off data is available
        'N/A' as write_off_status,
        NULL as write_off_comment
    FROM claims.activity a
    LEFT JOIN claims.claim c ON a.claim_id = c.id
    -- OPTIMIZED: Join to pre-computed activity summary instead of raw remittance data
    -- WHY: Eliminates complex aggregation and ensures consistent cumulative-with-cap logic
    LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = c.claim_key_id 
      AND cas.activity_id = a.activity_id
    -- Keep legacy join for self-pay and taken-back calculations (these need raw data)
    LEFT JOIN claims.remittance_activity ra ON a.activity_id = ra.activity_id
      AND ra.remittance_claim_id IN (
        SELECT id FROM claims.remittance_claim rc2 WHERE rc2.claim_key_id = c.claim_key_id
      )
    GROUP BY a.id, a.claim_id, a.activity_id, a.net, c.payer_id, 
             cas.paid_amount, cas.submitted_amount, cas.rejected_amount, cas.denied_amount,
             cas.remittance_count, cas.denial_codes, cas.activity_status
),
claim_resubmission_summary AS (
    -- Calculate resubmission metrics per claim
    SELECT 
        ck.id as claim_key_id,
        COUNT(DISTINCT ce.id) as resubmission_count,
        MAX(ce.event_time) as last_resubmission_date,
        MIN(ce.event_time) as first_resubmission_date
    FROM claims.claim_key ck
    LEFT JOIN claims.claim_event ce ON ck.id = ce.claim_key_id AND ce.type = 2
    GROUP BY ck.id
)
SELECT 
    -- Core identifiers
    ck.id AS claim_key_id,
    ck.claim_id,
    c.id AS claim_internal_id,
    a.id AS activity_internal_id,
    a.activity_id,
    
    -- Patient and member information
    c.member_id,
    c.emirates_id_number AS patient_id,
    
    -- Payer and receiver information
    c.payer_id,
    p.name AS payer_name,
    c.provider_id AS receiver_id,
    pr.name AS receiver_name,
    
    -- Facility information
    e.facility_id,
    f.name AS facility_name,
    f.city AS facility_group,
    if_sender.sender_id AS health_authority,
    
    -- Clinical information
    a.clinician,
    cl.name AS clinician_name,
    
    -- Encounter details
    e.type AS encounter_type,
    e.start_at AS encounter_start,
    e.end_at AS encounter_end,
    e.start_at AS encounter_date,
    
    -- Activity details
    a.start_at AS activity_date,
    a.type AS cpt_type,
    a.code AS cpt_code,
    a.quantity,
    
    -- Financial metrics (per JSON mapping)
    af.submitted_amount,
    af.total_paid,
    af.total_remitted,
    af.rejected_amount,
    af.initial_denial_code,
    af.latest_denial_code,
    
    -- Additional financial fields from JSON mapping
    af.submitted_amount AS billed_amount,
    af.total_paid AS paid_amount,
    af.total_paid AS remitted_amount,
    af.total_paid AS payment_amount,
    af.rejected_amount AS outstanding_balance,
    af.rejected_amount AS pending_amount,
    af.rejected_amount AS pending_remittance_amount,
    
    -- Resubmission tracking (1st cycle)
    r1.resubmission_type AS first_resubmission_type,
    r1.comment AS first_resubmission_comment,
    r1.event_time AS first_resubmission_date,
    
    -- Resubmission tracking (2nd cycle)
    r2.resubmission_type AS second_resubmission_type,
    r2.event_time AS second_resubmission_date,
    
    -- Resubmission tracking (3rd cycle)
    r3.resubmission_type AS third_resubmission_type,
    r3.event_time AS third_resubmission_date,
    
    -- Resubmission tracking (4th cycle)
    r4.resubmission_type AS fourth_resubmission_type,
    r4.event_time AS fourth_resubmission_date,
    
    -- Resubmission tracking (5th cycle)
    r5.resubmission_type AS fifth_resubmission_type,
    r5.event_time AS fifth_resubmission_date,
    
    -- Remittance tracking (1st cycle)
    rm1.remittance_date AS first_ra_date,
    rm1.payment_amount AS first_ra_amount,
    
    -- Remittance tracking (2nd cycle)
    rm2.remittance_date AS second_ra_date,
    rm2.payment_amount AS second_ra_amount,
    
    -- Remittance tracking (3rd cycle)
    rm3.remittance_date AS third_ra_date,
    rm3.payment_amount AS third_ra_amount,
    
    -- Remittance tracking (4th cycle)
    rm4.remittance_date AS fourth_ra_date,
    rm4.payment_amount AS fourth_ra_amount,
    
    -- Remittance tracking (5th cycle)
    rm5.remittance_date AS fifth_ra_date,
    rm5.payment_amount AS fifth_ra_amount,
    
    -- Summary metrics
    crs.resubmission_count,
    af.remittance_count,
    af.rejected_amount > 0 AS has_rejected_amount,
    af.rejected_amount > 0 AND crs.resubmission_count = 0 AS rejected_not_resubmitted,
    
    -- Denial tracking
    af.latest_denial_code AS denial_code,
    dc.description AS denial_comment,
    CASE 
        WHEN af.latest_denial_code IS NOT NULL THEN 'Denied'
        WHEN af.total_paid = af.submitted_amount THEN 'Fully Paid'
        WHEN af.total_paid > 0 THEN 'Partially Paid'
        ELSE 'Unpaid'
    END AS cpt_status,
    
    -- Aging calculation
    EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - e.start_at)) AS ageing_days,
    
    -- Timestamps
    c.created_at AS submitted_date,
    c.tx_at AS claim_transaction_date,
    
    -- Diagnosis information
    d1.code AS primary_diagnosis,
    d2.code AS secondary_diagnosis,
    
    -- Additional fields from JSON mapping (derived calculations)
    a.prior_authorization_id,
    -- FIXED: Proper JOIN for remittance_claim
    rc.payment_reference,
    rc.date_settlement,
    -- Derived fields (calculated in CTEs)
    EXTRACT(MONTH FROM c.tx_at) AS claim_month,
    EXTRACT(YEAR FROM c.tx_at) AS claim_year,
    LEAST(100::numeric,
         GREATEST(0::numeric,
             (af.total_paid / NULLIF(af.submitted_amount, 0)) * 100
         )
    ) AS collection_rate,
    -- Additional calculated fields will be added in CTEs
    af.fully_paid_count,
    af.fully_paid_amount,
    af.fully_rejected_count,
    af.fully_rejected_amount,
    af.partially_paid_count,
    af.partially_paid_amount,
    af.self_pay_count,
    af.self_pay_amount,
    af.taken_back_amount,
    af.taken_back_count

FROM claims.claim_key ck
JOIN claims.claim c ON ck.id = c.claim_key_id
JOIN claims.activity a ON c.id = a.claim_id
JOIN claims.encounter e ON c.id = e.claim_id
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN claims_ref.provider pr ON pr.id = c.provider_ref_id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN activity_financials af ON a.id = af.activity_internal_id
LEFT JOIN claims_ref.denial_code dc ON af.latest_denial_code = dc.code
LEFT JOIN claims.submission s ON c.submission_id = s.id
LEFT JOIN claims.ingestion_file if_sender ON s.ingestion_file_id = if_sender.id
LEFT JOIN claim_resubmission_summary crs ON ck.id = crs.claim_key_id
LEFT JOIN resubmission_cycles r1 ON ck.id = r1.claim_key_id AND r1.cycle_number = 1
LEFT JOIN resubmission_cycles r2 ON ck.id = r2.claim_key_id AND r2.cycle_number = 2
LEFT JOIN resubmission_cycles r3 ON ck.id = r3.claim_key_id AND r3.cycle_number = 3
LEFT JOIN resubmission_cycles r4 ON ck.id = r4.claim_key_id AND r4.cycle_number = 4
LEFT JOIN resubmission_cycles r5 ON ck.id = r5.claim_key_id AND r5.cycle_number = 5
LEFT JOIN remittance_cycles rm1 ON ck.id = rm1.claim_key_id AND rm1.cycle_number = 1
LEFT JOIN remittance_cycles rm2 ON ck.id = rm2.claim_key_id AND rm2.cycle_number = 2
LEFT JOIN remittance_cycles rm3 ON ck.id = rm3.claim_key_id AND rm3.cycle_number = 3
LEFT JOIN remittance_cycles rm4 ON ck.id = rm4.claim_key_id AND rm4.cycle_number = 4
LEFT JOIN remittance_cycles rm5 ON ck.id = rm5.claim_key_id AND rm5.cycle_number = 5
LEFT JOIN claims.diagnosis d1 ON c.id = d1.claim_id AND d1.diag_type = 'Principal'
LEFT JOIN claims.diagnosis d2 ON c.id = d2.claim_id AND d2.diag_type = 'Secondary'
-- FIXED: Proper JOIN for remittance_claim
LEFT JOIN claims.remittance_claim rc ON ck.id = rc.claim_key_id;

COMMENT ON VIEW claims.v_remittances_resubmission_activity_level IS 'Activity-level view for remittances and resubmission tracking with up to 5 cycles - FIXED VERSION';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_remittances_resubmission_claim_level (Claim-level remittance and resubmission data)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_remittances_resubmission_claim_level AS
WITH claim_financials AS (
    -- CUMULATIVE-WITH-CAP: Calculate financial metrics per claim using claim_activity_summary
    -- WHY: Prevents overcounting from multiple remittances per activity, uses latest denial logic
    -- HOW: Leverages claims.claim_activity_summary which already implements cumulative-with-cap semantics
    SELECT 
        c.id as claim_id,
        SUM(a.net)::numeric as total_submitted_amount,
        SUM(COALESCE(cas.paid_amount, 0::numeric)) as total_paid_amount,                    -- capped paid across remittances
        SUM(COALESCE(cas.denied_amount, 0::numeric)) as total_rejected_amount,             -- denied only when latest denial and zero paid
        MAX(cas.remittance_count) as remittance_count,                                     -- max across activities
        COUNT(DISTINCT CASE WHEN ce.type = 2 THEN ce.id END) as resubmission_count
    FROM claims.claim c
    JOIN claims.activity a ON c.id = a.claim_id
    LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = c.claim_key_id AND cas.activity_id = a.activity_id
    LEFT JOIN claims.claim_event ce ON c.claim_key_id = ce.claim_key_id AND ce.type = 2
    GROUP BY c.id
),
claim_diagnosis AS (
    -- Get primary and secondary diagnosis per claim
    SELECT 
        claim_id,
        MAX(CASE WHEN diag_type = 'PRIMARY' THEN code END) as primary_diagnosis,
        MAX(CASE WHEN diag_type = 'SECONDARY' THEN code END) as secondary_diagnosis
    FROM claims.diagnosis
    GROUP BY claim_id
)
SELECT 
    -- Core identifiers
    ck.id AS claim_key_id,
    ck.claim_id,
    c.id AS claim_internal_id,
    
    -- Patient and member information
    c.member_id,
    c.emirates_id_number AS patient_id,
    
    -- Payer and receiver information
    c.payer_id,
    p.name AS payer_name,
    c.provider_id AS receiver_id,
    pr.name AS receiver_name,
    
    -- Facility information
    e.facility_id,
    f.name AS facility_name,
    f.city AS facility_group,
    if_sender.sender_id AS health_authority,
    
    -- Clinical information
    a_single.clinician AS clinician,
    cl.name AS clinician_name,
    
    -- Encounter details
    e.type AS encounter_type,
    e.start_at AS encounter_start,
    e.end_at AS encounter_end,
    e.start_at AS encounter_date,
    
    -- Financial metrics
    cf.total_submitted_amount AS submitted_amount,
    cf.total_paid_amount AS total_paid,
    cf.total_rejected_amount AS rejected_amount,
    cf.remittance_count,
    cf.resubmission_count,
    
    -- Status indicators
    cf.total_rejected_amount > 0 AS has_rejected_amount,
    cf.total_rejected_amount > 0 AND cf.resubmission_count = 0 AS rejected_not_resubmitted,
    
    -- Aging calculation
    EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - e.start_at)) AS ageing_days,
    
    -- Timestamps
    c.created_at AS submitted_date,
    c.tx_at AS claim_transaction_date,
    
    -- Diagnosis information
    cd.primary_diagnosis,
    cd.secondary_diagnosis

FROM claims.claim_key ck
JOIN claims.claim c ON ck.id = c.claim_key_id
JOIN claims.encounter e ON c.id = e.claim_id
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN claims_ref.provider pr ON pr.id = c.provider_ref_id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
-- Join with a single activity per claim to get clinician info (avoiding duplication)
LEFT JOIN (
    SELECT DISTINCT claim_id, clinician, clinician_ref_id
    FROM claims.activity
    WHERE clinician_ref_id IS NOT NULL
) a_single ON c.id = a_single.claim_id
LEFT JOIN claims_ref.clinician cl ON cl.id = a_single.clinician_ref_id
LEFT JOIN claims.submission s ON c.submission_id = s.id
LEFT JOIN claims.ingestion_file if_sender ON s.ingestion_file_id = if_sender.id
LEFT JOIN claim_financials cf ON c.id = cf.claim_id
LEFT JOIN claim_diagnosis cd ON c.id = cd.claim_id
GROUP BY
    ck.id, ck.claim_id, c.id, c.member_id, c.emirates_id_number,
    c.payer_id, p.name, c.provider_id, pr.name,
    e.facility_id, f.name, f.city, if_sender.sender_id,
    e.type, e.start_at, e.end_at,
    a_single.clinician, cl.name,
    cf.total_submitted_amount, cf.total_paid_amount, cf.total_rejected_amount,
    cf.remittance_count, cf.resubmission_count,
    cd.primary_diagnosis, cd.secondary_diagnosis,
    c.created_at, c.tx_at;

COMMENT ON VIEW claims.v_remittances_resubmission_claim_level IS 'Claim-level aggregated view for remittances and resubmission tracking - FIXED VERSION';

-- ==========================================================================================================
-- SECTION 4: CLAIM DETAILS WITH ACTIVITY VIEWS (from claim_details_with_activity_final.sql)
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_claim_details_with_activity (Comprehensive claim details with activity timeline)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_claim_details_with_activity AS
SELECT
    -- Basic Claim Information
    ck.claim_id,
    c.id as claim_db_id,
    c.payer_id,
    c.provider_id,
    c.member_id,
    c.emirates_id_number,
    c.gross,
    c.patient_share,
    c.net as initial_net_amount,
    c.comments,
    c.tx_at as submission_date,

    -- Provider and Payer Information
    pr.name as provider_name,
    pr.provider_code as provider_code,
    c.provider_ref_id as provider_ref_id,
    py.name as payer_name,
    py.payer_code as payer_code,
    c.payer_ref_id as payer_ref_id,

    -- Encounter Information
    e.facility_id,
    e.type as encounter_type,
    e.patient_id,
    e.start_at as encounter_start,
    e.end_at as encounter_end_date,
    e.start_type,
    e.end_type,
    e.facility_ref_id as facility_ref_id,
    f.name as facility_name,
    f.facility_code as facility_group,

    -- Submission Information
    s.id as submission_id,
    s.tx_at as submission_transaction_date,

    -- Remittance Information
    rc.id as remittance_claim_id,
    rc.id_payer,
    rc.payment_reference,
    rc.date_settlement as initial_date_settlement,
    ra.denial_code as initial_denial_code,
    ra.denial_code_ref_id as denial_code_ref_id,
    rc.provider_ref_id as remittance_provider_ref_id,

            -- Activity Information
            a.id as activity_id,
            a.code as activity_code,
            ac.description as activity_description,
            a.type as activity_type,
            a.quantity,
            a.net as activity_net_amount,
    a.clinician as activity_clinician,
    a.clinician_ref_id as activity_clinician_ref_id,
    cl.name as clinician_name,
    cl.clinician_code as clinician_code,
    cl.specialty as clinician_specialty,

    -- Remittance Activity Information
    ra.id as remittance_activity_id,
    ra.payment_amount as remitted_amount,
    ra.net as remittance_activity_net,
    dc.description as denial_reason,
    ra.created_at as remittance_activity_created_at,

    -- Remittance Header Information
    r.id as remittance_id,
    f.name as receiver_name,
    e.facility_id as receiver_id,
    r.tx_at as remittance_date,
    r.created_at as remittance_created_at,

    -- Status Information
    cst.status as current_status,
    cst.status_time as status_time,

    -- Resubmission Information
    cr.id as resubmission_id,
    cr.resubmission_type,
    cr.comment as resubmission_comment,
    ce.event_time as resubmission_date,

    -- Diagnosis Information
    d1.code as primary_diagnosis,
    dc_prim.description as primary_diagnosis_description,
    d2.code as secondary_diagnosis,
    dc_sec.description as secondary_diagnosis_description,

    -- Calculated Fields
    CASE 
        WHEN ra.payment_amount > 0 AND ra.payment_amount = a.net THEN 'FULLY_PAID'
        WHEN ra.payment_amount > 0 AND ra.payment_amount < a.net THEN 'PARTIALLY_PAID'
        WHEN ra.denial_code IS NOT NULL THEN 'REJECTED'
        WHEN rc.date_settlement IS NULL THEN 'PENDING'
        ELSE 'UNKNOWN'
    END as payment_status,

    CASE 
        WHEN ra.payment_amount > 0 THEN ra.payment_amount
        ELSE 0
    END as settled_amount,

    CASE 
        WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN a.net
        ELSE 0
    END as rejected_amount,

    CASE 
        WHEN rc.date_settlement IS NULL THEN a.net
        ELSE 0
    END as unprocessed_amount,

    CASE 
        WHEN a.net > 0 THEN ROUND((ra.payment_amount / a.net) * 100, 2)
        ELSE 0
    END as net_collection_rate,

    CASE 
        WHEN a.net > 0 THEN ROUND(((CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN a.net ELSE 0 END) / a.net) * 100, 2)
        ELSE 0
    END as denial_rate,

    CASE 
        WHEN r.tx_at IS NOT NULL AND e.start_at IS NOT NULL THEN EXTRACT(DAYS FROM (r.tx_at - e.start_at))
        ELSE NULL
    END as turnaround_time_days,

    CASE 
        WHEN ra.payment_amount > 0 AND (CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN a.net ELSE 0 END) > 0 THEN 
            ROUND((ra.payment_amount / (CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN a.net ELSE 0 END)) * 100, 2)
        ELSE NULL
    END as resubmission_effectiveness,

    -- Additional Business Metrics
    EXTRACT(YEAR FROM c.tx_at) as submission_year,
    EXTRACT(MONTH FROM c.tx_at) as submission_month,
    EXTRACT(QUARTER FROM c.tx_at) as submission_quarter,
    EXTRACT(DAYS FROM (CURRENT_DATE - c.tx_at)) as days_since_submission,
    EXTRACT(DAYS FROM (CURRENT_DATE - e.start_at)) as days_since_encounter

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims.submission s ON s.id = c.submission_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id AND ra.activity_id = a.activity_id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.claim_status_timeline cst ON cst.claim_key_id = ck.id
LEFT JOIN claims.claim_event ce ON ce.claim_key_id = ck.id AND ce.type = 2
LEFT JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce.id
LEFT JOIN claims.diagnosis d1 ON d1.claim_id = c.id AND d1.diag_type = 'PRIMARY'
LEFT JOIN claims.diagnosis d2 ON d2.claim_id = c.id AND d2.diag_type = 'SECONDARY'
LEFT JOIN claims_ref.diagnosis_code dc_prim ON dc_prim.id = d1.diagnosis_code_ref_id
LEFT JOIN claims_ref.diagnosis_code dc_sec ON dc_sec.id = d2.diagnosis_code_ref_id
LEFT JOIN claims_ref.provider pr ON pr.id = c.provider_ref_id
LEFT JOIN claims_ref.payer py ON py.id = c.payer_ref_id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims_ref.activity_code ac ON ac.id = a.activity_code_ref_id
LEFT JOIN claims_ref.denial_code dc ON dc.id = ra.denial_code_ref_id
ORDER BY ck.claim_id, a.id, ra.created_at DESC;

COMMENT ON VIEW claims.v_claim_details_with_activity IS 'Comprehensive claim details with activity timeline and remittance/resubmission data';

-- ==========================================================================================================
-- SECTION 5: REJECTED CLAIMS VIEWS (from rejected_claims_report_final.sql)
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_rejected_claims_base (Base view for rejected claims)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_rejected_claims_base AS
WITH rejected_activities AS (
  -- Get activities that have been rejected (denied)
  SELECT 
    ra.activity_id,
    ra.remittance_claim_id,
    ra.net AS activity_net,
    ra.denial_code,
    ra.denial_code_ref_id,
    dc.description as denial_reason,
    ra.created_at AS rejection_date,
    rc.claim_key_id,
    rc.date_settlement,
    rc.payment_reference,
    f.name as receiver_name,
    e.facility_id as receiver_id
  FROM claims.remittance_activity ra
  JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
  JOIN claims.remittance r ON r.id = rc.remittance_id
  JOIN claims.claim_key ck ON ck.id = rc.claim_key_id
  JOIN claims.claim c ON c.claim_key_id = ck.id
  LEFT JOIN claims.encounter e ON e.claim_id = c.id
  LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
  LEFT JOIN claims_ref.denial_code dc ON dc.id = ra.denial_code_ref_id
  WHERE ra.denial_code IS NOT NULL  -- Rejected activities
),
claim_rejection_summary AS (
  -- Aggregate rejection data at claim level
  SELECT 
    rc.claim_key_id,
    COUNT(DISTINCT ra.activity_id) AS rejected_activity_count,
    SUM(ra.net) AS total_rejected_amount,
    MIN(ra.created_at) AS first_rejection_date,
    MAX(ra.created_at) AS last_rejection_date,
    MAX(ra.denial_code) AS primary_denial_code,
    MAX(dc.description) AS primary_denial_reason
  FROM claims.remittance_activity ra
  JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
  LEFT JOIN claims_ref.denial_code dc ON dc.id = ra.denial_code_ref_id
  WHERE ra.denial_code IS NOT NULL
  GROUP BY rc.claim_key_id
)
SELECT 
  -- Claim information
  ck.id AS claim_key_id,
  ck.claim_id AS external_claim_id,
  c.id AS claim_id_internal,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.gross AS claim_gross_amount,
  c.patient_share AS claim_patient_share,
  c.net AS claim_net_amount,
  c.tx_at AS claim_submission_date,
  c.comments AS claim_comments,
  
  -- Encounter information
  e.facility_id,
  e.type AS encounter_type,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  
  -- Rejection summary
  COALESCE(crs.rejected_activity_count, 0) AS rejected_activity_count,
  COALESCE(crs.total_rejected_amount, 0) AS total_rejected_amount,
  crs.first_rejection_date,
  crs.last_rejection_date,
  crs.primary_denial_code,
  crs.primary_denial_reason,
  
  -- Activity-level rejection details
  ra.activity_id,
  ra.activity_net,
  ra.denial_code,
  dc.description as denial_reason,
  ra.rejection_date,
  ra.date_settlement,
  ra.payment_reference,
  ra.receiver_name,
  ra.receiver_id,
  
  -- Calculated fields
  CASE 
    WHEN COALESCE(crs.rejected_activity_count, 0) > 0 THEN true
    ELSE false
  END AS has_rejections,
  
  CASE 
    WHEN COALESCE(crs.total_rejected_amount, 0) = c.net THEN 'FULLY_REJECTED'
    WHEN COALESCE(crs.total_rejected_amount, 0) > 0 THEN 'PARTIALLY_REJECTED'
    ELSE 'NOT_REJECTED'
  END AS rejection_status,
  
  -- Reference data
  f.name AS facility_name,
  f.facility_code,
  p.name AS provider_name,
  p.provider_code,
  pay.name AS payer_name,
  pay.payer_code,
  et.description AS encounter_type_description,
  dc.description AS denial_code_description

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
LEFT JOIN claim_rejection_summary crs ON crs.claim_key_id = ck.id
LEFT JOIN rejected_activities ra ON ra.claim_key_id = ck.id
LEFT JOIN claims_ref.denial_code dc ON dc.id = ra.denial_code_ref_id;

COMMENT ON VIEW claims.v_rejected_claims_base IS 'Base view for rejected claims with activity-level and claim-level rejection data';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_rejected_claims_summary_by_year (Rejected claims summary by year)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_rejected_claims_summary_by_year AS
SELECT 
  EXTRACT(YEAR FROM c.tx_at) AS year,
  COUNT(DISTINCT ck.claim_id) AS total_claims,
  COUNT(DISTINCT CASE WHEN crs.rejected_activity_count > 0 THEN ck.claim_id END) AS rejected_claims,
  SUM(c.net) AS total_claim_amount,
  SUM(CASE WHEN crs.rejected_activity_count > 0 THEN crs.total_rejected_amount ELSE 0 END) AS total_rejected_amount,
  ROUND(
    (COUNT(DISTINCT CASE WHEN crs.rejected_activity_count > 0 THEN ck.claim_id END)::DECIMAL / 
     COUNT(DISTINCT ck.claim_id)) * 100, 2
  ) AS rejection_rate_percentage,
  ROUND(
    (SUM(CASE WHEN crs.rejected_activity_count > 0 THEN crs.total_rejected_amount ELSE 0 END)::DECIMAL / 
     SUM(c.net)) * 100, 2
  ) AS rejection_amount_percentage
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN (
  SELECT 
    rc.claim_key_id,
    COUNT(DISTINCT ra.activity_id) AS rejected_activity_count,
    SUM(ra.net) AS total_rejected_amount
  FROM claims.remittance_activity ra
  JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
  WHERE ra.denial_code IS NOT NULL
  GROUP BY rc.claim_key_id
) crs ON crs.claim_key_id = ck.id
GROUP BY EXTRACT(YEAR FROM c.tx_at)
ORDER BY year DESC;

COMMENT ON VIEW claims.v_rejected_claims_summary_by_year IS 'Rejected claims summary grouped by year';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_rejected_claims_summary (Overall rejected claims summary)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_rejected_claims_summary AS
SELECT 
  COUNT(DISTINCT ck.claim_id) AS total_claims,
  COUNT(DISTINCT CASE WHEN crs.rejected_activity_count > 0 THEN ck.claim_id END) AS rejected_claims,
  SUM(c.net) AS total_claim_amount,
  SUM(CASE WHEN crs.rejected_activity_count > 0 THEN crs.total_rejected_amount ELSE 0 END) AS total_rejected_amount,
  ROUND(
    (COUNT(DISTINCT CASE WHEN crs.rejected_activity_count > 0 THEN ck.claim_id END)::DECIMAL / 
     COUNT(DISTINCT ck.claim_id)) * 100, 2
  ) AS rejection_rate_percentage,
  ROUND(
    (SUM(CASE WHEN crs.rejected_activity_count > 0 THEN crs.total_rejected_amount ELSE 0 END)::DECIMAL / 
     SUM(c.net)) * 100, 2
  ) AS rejection_amount_percentage
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN (
  SELECT 
    rc.claim_key_id,
    COUNT(DISTINCT ra.activity_id) AS rejected_activity_count,
    SUM(ra.net) AS total_rejected_amount
  FROM claims.remittance_activity ra
  JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
  WHERE ra.denial_code IS NOT NULL
  GROUP BY rc.claim_key_id
) crs ON crs.claim_key_id = ck.id;

COMMENT ON VIEW claims.v_rejected_claims_summary IS 'Overall rejected claims summary';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_rejected_claims_receiver_payer (Rejected claims by receiver and payer)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_rejected_claims_receiver_payer AS
SELECT 
  f.name AS receiver_name,
  e.facility_id AS receiver_id,
  c.payer_id,
  pay.name AS payer_name,
  COUNT(DISTINCT ck.claim_id) AS total_claims,
  COUNT(DISTINCT CASE WHEN ra.denial_code IS NOT NULL THEN ck.claim_id END) AS rejected_claims,
  SUM(c.net) AS total_claim_amount,
  SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS total_rejected_amount,
  ROUND(
    (COUNT(DISTINCT CASE WHEN ra.denial_code IS NOT NULL THEN ck.claim_id END)::DECIMAL / 
     COUNT(DISTINCT ck.claim_id)) * 100, 2
  ) AS rejection_rate_percentage
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
GROUP BY f.name, e.facility_id, c.payer_id, pay.name
ORDER BY total_rejected_amount DESC;

COMMENT ON VIEW claims.v_rejected_claims_receiver_payer IS 'Rejected claims grouped by receiver and payer';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_rejected_claims_claim_wise (Claim-wise rejected claims details)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_rejected_claims_claim_wise AS
SELECT 
  ck.claim_id AS external_claim_id,
  c.id AS claim_id_internal,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.net AS claim_net_amount,
  c.tx_at AS claim_submission_date,
  
  -- Encounter information
  e.facility_id,
  e.type AS encounter_type,
  e.start_at AS encounter_start,
  
  -- Rejection details
  ra.activity_id,
  ra.net AS rejected_activity_amount,
  ra.denial_code,
  dc.description as denial_reason,
  ra.created_at AS rejection_date,
  rc.date_settlement,
  rc.payment_reference,
  f.name AS receiver_name,
  e.facility_id AS receiver_id,
  
  -- Reference data (already facility_name from encounter join)
  f.name AS facility_name,
  p.name AS provider_name,
  pay.name AS payer_name,
  et.description AS encounter_type_description,
  dc.description AS denial_code_description

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.denial_code dc ON dc.id = ra.denial_code_ref_id
WHERE ra.denial_code IS NOT NULL  -- Only rejected activities
ORDER BY ck.claim_id, ra.created_at;

COMMENT ON VIEW claims.v_rejected_claims_claim_wise IS 'Claim-wise rejected claims details';

-- ==========================================================================================================
-- SECTION 6: DOCTOR DENIAL VIEWS (from doctor_denial_report_final.sql)
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_doctor_denial_high_denial (High denial rate doctors)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_doctor_denial_high_denial AS
WITH doctor_denial_stats AS (
  SELECT 
    a.clinician,
    cl.name AS clinician_name,
    cl.clinician_code,
    COUNT(DISTINCT a.id) AS total_activities,
    COUNT(DISTINCT CASE WHEN ra.denial_code IS NOT NULL THEN a.id END) AS denied_activities,
    SUM(a.net) AS total_activity_amount,
    SUM(CASE WHEN ra.denial_code IS NOT NULL THEN a.net ELSE 0 END) AS denied_activity_amount,
    ROUND(
      (COUNT(DISTINCT CASE WHEN ra.denial_code IS NOT NULL THEN a.id END)::DECIMAL / 
       COUNT(DISTINCT a.id)) * 100, 2
    ) AS denial_rate_percentage
  FROM claims.activity a
  LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
  LEFT JOIN claims.remittance_activity ra ON ra.activity_id = a.activity_id
  WHERE a.clinician IS NOT NULL
  GROUP BY a.clinician, cl.name, cl.clinician_code
)
SELECT 
  clinician,
  clinician_name,
  clinician_code,
  total_activities,
  denied_activities,
  total_activity_amount,
  denied_activity_amount,
  denial_rate_percentage,
  CASE 
    WHEN denial_rate_percentage >= 50 THEN 'HIGH'
    WHEN denial_rate_percentage >= 25 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS denial_risk_level
FROM doctor_denial_stats
WHERE denied_activities > 0  -- Only doctors with denials
ORDER BY denial_rate_percentage DESC, denied_activity_amount DESC;

COMMENT ON VIEW claims.v_doctor_denial_high_denial IS 'High denial rate doctors with risk level classification';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_doctor_denial_summary (Doctor denial summary)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_doctor_denial_summary AS
SELECT 
  a.clinician,
  cl.name AS clinician_name,
  cl.clinician_code,
  cl.specialty AS clinician_specialty,
  COUNT(DISTINCT a.id) AS total_activities,
  COUNT(DISTINCT CASE WHEN ra.denial_code IS NOT NULL THEN a.id END) AS denied_activities,
  COUNT(DISTINCT ck.claim_id) AS total_claims,
  COUNT(DISTINCT CASE WHEN ra.denial_code IS NOT NULL THEN ck.claim_id END) AS denied_claims,
  SUM(a.net) AS total_activity_amount,
  SUM(CASE WHEN ra.denial_code IS NOT NULL THEN a.net ELSE 0 END) AS denied_activity_amount,
  ROUND(
    (COUNT(DISTINCT CASE WHEN ra.denial_code IS NOT NULL THEN a.id END)::DECIMAL / 
     COUNT(DISTINCT a.id)) * 100, 2
  ) AS activity_denial_rate_percentage,
  ROUND(
    (COUNT(DISTINCT CASE WHEN ra.denial_code IS NOT NULL THEN ck.claim_id END)::DECIMAL / 
     COUNT(DISTINCT ck.claim_id)) * 100, 2
  ) AS claim_denial_rate_percentage,
  ROUND(
    (SUM(CASE WHEN ra.denial_code IS NOT NULL THEN a.net ELSE 0 END)::DECIMAL / 
     SUM(a.net)) * 100, 2
  ) AS amount_denial_rate_percentage
FROM claims.activity a
JOIN claims.claim c ON c.id = a.claim_id
JOIN claims.claim_key ck ON ck.id = c.claim_key_id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims.remittance_activity ra ON ra.activity_id = a.activity_id
WHERE a.clinician IS NOT NULL
GROUP BY a.clinician, cl.name, cl.clinician_code, cl.specialty
ORDER BY denied_activity_amount DESC, activity_denial_rate_percentage DESC;

COMMENT ON VIEW claims.v_doctor_denial_summary IS 'Comprehensive doctor denial summary with multiple metrics';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_doctor_denial_detail (Detailed doctor denial information)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_doctor_denial_detail AS
SELECT 
  a.clinician,
  cl.name AS clinician_name,
  cl.clinician_code,
  cl.specialty AS clinician_specialty,
  a.id AS activity_id,
  a.code AS activity_code,
  ac.description AS activity_description,
  a.net AS activity_net_amount,
  a.created_at AS activity_created_at,
  
  -- Claim information
  ck.claim_id AS external_claim_id,
  c.id AS claim_id_internal,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.net AS claim_net_amount,
  c.tx_at AS claim_submission_date,
  
  -- Encounter information
  e.facility_id,
  e.type AS encounter_type,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  
  -- Denial information
  ra.denial_code,
  dc.description as denial_reason,
  ra.created_at AS denial_date,
  rc.date_settlement,
  rc.payment_reference,
  f.name AS receiver_name,
  e.facility_id AS receiver_id,
  
  -- Reference data (already facility_name from encounter join)
  f.name AS facility_name,
  p.name AS provider_name,
  pay.name AS payer_name,
  et.description AS encounter_type_description,
  ac.description AS activity_code_description,
  dc.description AS denial_code_description

FROM claims.activity a
JOIN claims.claim c ON c.id = a.claim_id
JOIN claims.claim_key ck ON ck.id = c.claim_key_id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
LEFT JOIN claims_ref.activity_code ac ON ac.id = a.activity_code_ref_id
LEFT JOIN claims.remittance_activity ra ON ra.activity_id = a.activity_id
LEFT JOIN claims_ref.denial_code dc ON dc.id = ra.denial_code_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
WHERE ra.denial_code IS NOT NULL  -- Only denied activities
  AND a.clinician IS NOT NULL     -- Only activities with clinician
ORDER BY a.clinician, ra.created_at DESC;

COMMENT ON VIEW claims.v_doctor_denial_detail IS 'Detailed doctor denial information with activity and claim details';

-- ==========================================================================================================
-- SECTION 7: REMITTANCE ADVICE VIEWS (from remittance_advice_payerwise_report_final.sql)
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_remittance_advice_header (Remittance advice header information)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_remittance_advice_header AS
SELECT 
  r.id AS remittance_id,
  f.name AS receiver_name,
  e.facility_id AS receiver_id,
  r.created_at AS remittance_date,
  rc.payment_reference,
  COUNT(DISTINCT rc.id) AS claim_count,
  COUNT(DISTINCT ra.id) AS activity_count,
  SUM(ra.payment_amount) AS total_payment_amount,
  SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS total_denied_amount,
  SUM(ra.net) AS total_remittance_amount
FROM claims.remittance r
LEFT JOIN claims.remittance_claim rc ON rc.remittance_id = r.id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims.claim_key ck ON ck.id = rc.claim_key_id
LEFT JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
GROUP BY r.id, f.name, e.facility_id, r.created_at, rc.payment_reference
ORDER BY r.created_at DESC;

COMMENT ON VIEW claims.v_remittance_advice_header IS 'Remittance advice header information with summary statistics';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_remittance_advice_claim_wise (Remittance advice claim-wise details)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_remittance_advice_claim_wise AS
SELECT 
  r.id AS remittance_id,
  f.name AS receiver_name,
  e.facility_id AS receiver_id,
  r.created_at AS remittance_date,
  rc.payment_reference,
  rc.id AS remittance_claim_id,
  rc.date_settlement,
  ck.claim_id AS external_claim_id,
  c.id AS claim_id_internal,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.gross AS claim_gross_amount,
  c.patient_share AS claim_patient_share,
  c.net AS claim_net_amount,
  c.tx_at AS claim_submission_date,
  
  -- Encounter information
  e.facility_id,
  e.type AS encounter_type,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  
  -- Remittance claim summary
  COUNT(DISTINCT ra.id) AS activity_count,
  SUM(ra.payment_amount) AS total_payment_amount,
  SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS total_denied_amount,
  SUM(ra.net) AS total_remittance_amount,
  
  -- Reference data
  f.name AS facility_name,
  p.name AS provider_name,
  pay.name AS payer_name,
  et.description AS encounter_type_description

FROM claims.remittance r
JOIN claims.remittance_claim rc ON rc.remittance_id = r.id
JOIN claims.claim_key ck ON ck.id = rc.claim_key_id
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
GROUP BY 
  r.id, f.name, e.facility_id, r.created_at, rc.payment_reference,
  rc.id, rc.date_settlement, ck.claim_id, c.id, c.payer_id, c.provider_id, 
  c.member_id, c.emirates_id_number, c.gross, c.patient_share, c.net, c.tx_at,
  e.facility_id, e.type, e.start_at, e.end_at,
  f.name, p.name, pay.name, et.description
ORDER BY r.created_at DESC, rc.date_settlement DESC;

COMMENT ON VIEW claims.v_remittance_advice_claim_wise IS 'Remittance advice claim-wise details with summary statistics';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_remittance_advice_activity_wise (Remittance advice activity-wise details)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_remittance_advice_activity_wise AS
SELECT 
  r.id AS remittance_id,
  f.name AS receiver_name,
  e.facility_id AS receiver_id,
  r.created_at AS remittance_date,
  rc.payment_reference,
  rc.id AS remittance_claim_id,
  rc.date_settlement,
  ra.id AS remittance_activity_id,
  ra.activity_id,
  ra.net AS activity_net_amount,
  ra.payment_amount AS activity_payment_amount,
  ra.denial_code,
  dc.description as denial_reason,
  ra.created_at AS remittance_activity_created_at,
  
  -- Activity information
  a.code AS activity_code,
  ac.description AS activity_description,
  a.clinician AS activity_clinician,
  a.created_at AS activity_created_at,
  
  -- Claim information
  ck.claim_id AS external_claim_id,
  c.id AS claim_id_internal,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.net AS claim_net_amount,
  c.tx_at AS claim_submission_date,
  
  -- Encounter information
  e.facility_id,
  e.type AS encounter_type,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  
  -- Reference data
  f.name AS facility_name,
  p.name AS provider_name,
  pay.name AS payer_name,
  cl.name AS clinician_name,
  et.description AS encounter_type_description,
  ac.description AS activity_code_description,
  dc.description AS denial_code_description

FROM claims.remittance r
JOIN claims.remittance_claim rc ON rc.remittance_id = r.id
JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
JOIN claims.activity a ON a.activity_id = ra.activity_id
JOIN claims.claim_key ck ON ck.id = rc.claim_key_id
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
LEFT JOIN claims_ref.activity_code ac ON ac.id = a.activity_code_ref_id
LEFT JOIN claims_ref.denial_code dc ON dc.id = ra.denial_code_ref_id
ORDER BY r.created_at DESC, rc.date_settlement DESC, ra.created_at DESC;

COMMENT ON VIEW claims.v_remittance_advice_activity_wise IS 'Remittance advice activity-wise details with comprehensive reference data';

-- ==========================================================================================================
-- SECTION 8: PERMISSIONS AND GRANTS
-- ==========================================================================================================

-- Grant permissions on all views to claims_user
GRANT SELECT ON ALL TABLES IN SCHEMA claims TO claims_user;

-- Set default privileges for future views
ALTER DEFAULT PRIVILEGES IN SCHEMA claims GRANT SELECT ON TABLES TO claims_user;

-- ==========================================================================================================
-- END OF REPORT VIEWS
-- ==========================================================================================================