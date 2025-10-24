-- ==========================================================================================================
-- REPORT VIEWS - SQL VIEWS FOR CLAIMS REPORTING
-- ==========================================================================================================
-- 
-- Purpose: Create all SQL views for claims reporting (not materialized views)
-- Version: 2.0
-- Date: 2025-10-24
-- 
-- This script creates SQL views for:
-- - Claim summary reports (monthwise, payerwise, encounterwise)
-- - Balance amount reports (base, initial, resubmission)
-- - Remittance and resubmission reports
-- - Claim details with activity
-- - Rejected claims reports
-- - Doctor denial reports
-- - Remittance advice reports
--
-- Note: Extensions and schemas are created in 01-init-db.sql
-- Note: Core tables are created in 02-core-tables.sql
-- Note: Reference data is created in 03-ref-data-tables.sql
-- Note: Materialized views are created in 07-materialized-views.sql
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: CLAIM SUMMARY VIEWS
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
LEFT JOIN dedup_claim d ON d.claim_db_id = c.id AND d.month_bucket = DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at))
GROUP BY 
    DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)),
    e.facility_id,
    f.name,
    COALESCE(p2.payer_code, 'Unknown')
ORDER BY 
    DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)) DESC,
    e.facility_id,
    f.name;

COMMENT ON VIEW claims.v_claim_summary_monthwise IS 'Comprehensive monthwise claim summary with cumulative-with-cap logic';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_claim_summary_payerwise (Tab B - Payerwise grouping)
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
    LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id
    LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
    LEFT JOIN claims_ref.payer p2 ON p2.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)
),
dedup_claim AS (
    SELECT claim_db_id,
           health_authority,
           MAX(claim_net) AS claim_net_once
    FROM base
    GROUP BY claim_db_id, health_authority
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
LEFT JOIN dedup_claim d ON d.claim_db_id = c.id AND d.health_authority = COALESCE(p2.payer_code, 'Unknown')
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
-- VIEW: v_claim_summary_encounterwise (Tab C - Encounterwise grouping)
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
-- SECTION 2: BALANCE AMOUNT VIEWS
-- ==========================================================================================================

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
  
  -- Remittance summary (CUMULATIVE-WITH-CAP)
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
-- SECTION 3: REMITTANCE AND RESUBMISSION VIEWS
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_remittances_resubmission_activity_level (Activity-level remittance and resubmission data)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_remittances_resubmission_activity_level AS
WITH activity_remittance_summary AS (
  -- Pre-aggregate remittance data at activity level
  SELECT 
    ra.activity_id,
    ra.remittance_claim_id,
    rc.claim_key_id,
    ra.net AS activity_net,
    ra.payment_amount AS activity_payment,
    ra.denial_code AS activity_denial_code,
    ra.denial_reason AS activity_denial_reason,
    ra.created_at AS remittance_activity_created_at,
    rc.date_settlement,
    rc.payment_reference,
    r.receiver_name,
    r.receiver_id
  FROM claims.remittance_activity ra
  JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
  JOIN claims.remittance r ON r.id = rc.remittance_id
),
activity_resubmission_summary AS (
  -- Pre-aggregate resubmission data at activity level
  SELECT 
    ce.activity_id,
    ce.claim_key_id,
    ce.event_time AS resubmission_date,
    cr.comment AS resubmission_comment,
    cr.resubmission_type,
    COUNT(*) OVER (PARTITION BY ce.activity_id ORDER BY ce.event_time) AS resubmission_sequence
  FROM claims.claim_event ce
  JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce.id
  WHERE ce.type = 2  -- RESUBMISSION events
)
SELECT 
  a.id AS activity_id,
  a.claim_id,
  a.code AS activity_code,
  a.description AS activity_description,
  a.net AS activity_net_amount,
  a.created_at AS activity_created_at,
  
  -- Claim information
  ck.claim_id AS external_claim_id,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  
  -- Encounter information
  e.facility_id,
  e.type AS encounter_type,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  
  -- Remittance information
  ars.activity_payment,
  ars.activity_denial_code,
  ars.activity_denial_reason,
  ars.date_settlement,
  ars.payment_reference,
  ars.receiver_name,
  ars.receiver_id,
  ars.remittance_activity_created_at,
  
  -- Resubmission information
  arss.resubmission_date,
  arss.resubmission_comment,
  arss.resubmission_type,
  arss.resubmission_sequence,
  
  -- Calculated fields
  CASE 
    WHEN ars.activity_payment > 0 THEN 'PAID'
    WHEN ars.activity_denial_code IS NOT NULL THEN 'DENIED'
    ELSE 'PENDING'
  END AS activity_status,
  
  CASE 
    WHEN arss.resubmission_sequence > 0 THEN true
    ELSE false
  END AS has_resubmissions,
  
  -- Reference data
  f.name AS facility_name,
  f.facility_code,
  p.name AS provider_name,
  p.provider_code,
  pay.name AS payer_name,
  pay.payer_code,
  cl.name AS clinician_name,
  cl.clinician_code,
  ac.description AS activity_code_description

FROM claims.activity a
JOIN claims.claim c ON c.id = a.claim_id
JOIN claims.claim_key ck ON ck.id = c.claim_key_id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims_ref.activity_code ac ON ac.id = a.activity_code_ref_id
LEFT JOIN activity_remittance_summary ars ON ars.activity_id = a.id
LEFT JOIN activity_resubmission_summary arss ON arss.activity_id = a.id;

COMMENT ON VIEW claims.v_remittances_resubmission_activity_level IS 'Activity-level view of remittance and resubmission data';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_remittances_resubmission_claim_level (Claim-level remittance and resubmission data)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_remittances_resubmission_claim_level AS
WITH claim_remittance_summary AS (
  -- Pre-aggregate remittance data at claim level
  SELECT 
    rc.claim_key_id,
    COUNT(DISTINCT rc.id) AS remittance_count,
    SUM(ra.payment_amount) AS total_payment_amount,
    SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS total_denied_amount,
    MIN(rc.date_settlement) AS first_remittance_date,
    MAX(rc.date_settlement) AS last_remittance_date,
    MAX(rc.payment_reference) AS last_payment_reference,
    MAX(r.receiver_name) AS receiver_name,
    MAX(r.receiver_id) AS receiver_id
  FROM claims.remittance_claim rc
  JOIN claims.remittance r ON r.id = rc.remittance_id
  LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
  GROUP BY rc.claim_key_id
),
claim_resubmission_summary AS (
  -- Pre-aggregate resubmission data at claim level
  SELECT 
    ce.claim_key_id,
    COUNT(*) AS resubmission_count,
    MIN(ce.event_time) AS first_resubmission_date,
    MAX(ce.event_time) AS last_resubmission_date,
    MAX(cr.comment) AS last_resubmission_comment,
    MAX(cr.resubmission_type) AS last_resubmission_type
  FROM claims.claim_event ce
  JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce.id
  WHERE ce.type = 2  -- RESUBMISSION events
  GROUP BY ce.claim_key_id
)
SELECT 
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
  
  -- Remittance summary
  COALESCE(crs.remittance_count, 0) AS remittance_count,
  COALESCE(crs.total_payment_amount, 0) AS total_payment_amount,
  COALESCE(crs.total_denied_amount, 0) AS total_denied_amount,
  crs.first_remittance_date,
  crs.last_remittance_date,
  crs.last_payment_reference,
  crs.receiver_name,
  crs.receiver_id,
  
  -- Resubmission summary
  COALESCE(crss.resubmission_count, 0) AS resubmission_count,
  crss.first_resubmission_date,
  crss.last_resubmission_date,
  crss.last_resubmission_comment,
  crss.last_resubmission_type,
  
  -- Calculated fields
  c.net - COALESCE(crs.total_payment_amount, 0) AS balance_amount,
  CASE 
    WHEN c.net - COALESCE(crs.total_payment_amount, 0) > 0 THEN 'PENDING'
    WHEN c.net - COALESCE(crs.total_payment_amount, 0) = 0 THEN 'PAID'
    ELSE 'OVERPAID'
  END AS payment_status,
  
  CASE 
    WHEN COALESCE(crss.resubmission_count, 0) > 0 THEN true
    ELSE false
  END AS has_resubmissions,
  
  CASE 
    WHEN COALESCE(crs.remittance_count, 0) > 0 THEN true
    ELSE false
  END AS has_remittances,
  
  -- Reference data
  f.name AS facility_name,
  f.facility_code,
  p.name AS provider_name,
  p.provider_code,
  pay.name AS payer_name,
  pay.payer_code

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claim_remittance_summary crs ON crs.claim_key_id = ck.id
LEFT JOIN claim_resubmission_summary crss ON crss.claim_key_id = ck.id;

COMMENT ON VIEW claims.v_remittances_resubmission_claim_level IS 'Claim-level view of remittance and resubmission data';

-- ==========================================================================================================
-- SECTION 4: CLAIM DETAILS WITH ACTIVITY VIEW
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_claim_details_with_activity (Comprehensive claim details with activity timeline)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_claim_details_with_activity AS
WITH activity_timeline AS (
  -- Get activity timeline with remittance and resubmission data
  SELECT 
    a.id AS activity_id,
    a.claim_id,
    a.code AS activity_code,
    a.description AS activity_description,
    a.net AS activity_net_amount,
    a.created_at AS activity_created_at,
    a.clinician AS activity_clinician,
    
    -- Remittance data for this activity
    ra.payment_amount AS activity_payment_amount,
    ra.denial_code AS activity_denial_code,
    ra.denial_reason AS activity_denial_reason,
    ra.created_at AS remittance_activity_created_at,
    rc.date_settlement AS remittance_date,
    rc.payment_reference,
    r.receiver_name,
    r.receiver_id,
    
    -- Resubmission data for this activity
    cr.comment AS resubmission_comment,
    cr.resubmission_type,
    ce.event_time AS resubmission_date,
    
    -- Activity status
    CASE 
      WHEN ra.payment_amount > 0 THEN 'PAID'
      WHEN ra.denial_code IS NOT NULL THEN 'DENIED'
      ELSE 'PENDING'
    END AS activity_status,
    
    ROW_NUMBER() OVER (PARTITION BY a.id ORDER BY ra.created_at DESC) AS remittance_sequence,
    ROW_NUMBER() OVER (PARTITION BY a.id ORDER BY ce.event_time DESC) AS resubmission_sequence
    
  FROM claims.activity a
  LEFT JOIN claims.remittance_activity ra ON ra.activity_id = a.id
  LEFT JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
  LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
  LEFT JOIN claims.claim_event ce ON ce.activity_id = a.id AND ce.type = 2  -- RESUBMISSION events
  LEFT JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce.id
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
  e.patient_id,
  
  -- Activity information
  at.activity_id,
  at.activity_code,
  at.activity_description,
  at.activity_net_amount,
  at.activity_created_at,
  at.activity_clinician,
  
  -- Remittance information
  at.activity_payment_amount,
  at.activity_denial_code,
  at.activity_denial_reason,
  at.remittance_activity_created_at,
  at.remittance_date,
  at.payment_reference,
  at.receiver_name,
  at.receiver_id,
  
  -- Resubmission information
  at.resubmission_comment,
  at.resubmission_type,
  at.resubmission_date,
  
  -- Status and sequence information
  at.activity_status,
  at.remittance_sequence,
  at.resubmission_sequence,
  
  -- Reference data
  f.name AS facility_name,
  f.facility_code,
  p.name AS provider_name,
  p.provider_code,
  pay.name AS payer_name,
  pay.payer_code,
  cl.name AS clinician_name,
  cl.clinician_code,
  ac.description AS activity_code_description,
  et.description AS encounter_type_description

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
LEFT JOIN activity_timeline at ON at.claim_id = c.id
WHERE at.remittance_sequence = 1 OR at.remittance_sequence IS NULL  -- Get latest remittance per activity
ORDER BY ck.claim_id, at.activity_created_at;

COMMENT ON VIEW claims.v_claim_details_with_activity IS 'Comprehensive claim details with activity timeline and remittance/resubmission data';

-- ==========================================================================================================
-- SECTION 5: REJECTED CLAIMS VIEWS
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
    ra.denial_reason,
    ra.created_at AS rejection_date,
    rc.claim_key_id,
    rc.date_settlement,
    rc.payment_reference,
    r.receiver_name,
    r.receiver_id
  FROM claims.remittance_activity ra
  JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
  JOIN claims.remittance r ON r.id = rc.remittance_id
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
    MAX(ra.denial_reason) AS primary_denial_reason
  FROM claims.remittance_activity ra
  JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
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
  ra.denial_reason,
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
LEFT JOIN claims_ref.denial_code dc ON dc.code = ra.denial_code;

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
  r.receiver_name,
  r.receiver_id,
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
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
GROUP BY r.receiver_name, r.receiver_id, c.payer_id, pay.name
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
  ra.denial_reason,
  ra.created_at AS rejection_date,
  rc.date_settlement,
  rc.payment_reference,
  r.receiver_name,
  r.receiver_id,
  
  -- Reference data
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
LEFT JOIN claims_ref.denial_code dc ON dc.code = ra.denial_code
WHERE ra.denial_code IS NOT NULL  -- Only rejected activities
ORDER BY ck.claim_id, ra.created_at;

COMMENT ON VIEW claims.v_rejected_claims_claim_wise IS 'Claim-wise rejected claims details';

-- ==========================================================================================================
-- SECTION 6: DOCTOR DENIAL VIEWS
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
  LEFT JOIN claims.remittance_activity ra ON ra.activity_id = a.id
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
LEFT JOIN claims.remittance_activity ra ON ra.activity_id = a.id
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
  a.description AS activity_description,
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
  ra.denial_reason,
  ra.created_at AS denial_date,
  rc.date_settlement,
  rc.payment_reference,
  r.receiver_name,
  r.receiver_id,
  
  -- Reference data
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
LEFT JOIN claims_ref.denial_code dc ON dc.code = ra.denial_code
LEFT JOIN claims.remittance_activity ra ON ra.activity_id = a.id
LEFT JOIN claims.remittance_claim rc ON rc.id = ra.remittance_claim_id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
WHERE ra.denial_code IS NOT NULL  -- Only denied activities
  AND a.clinician IS NOT NULL     -- Only activities with clinician
ORDER BY a.clinician, ra.created_at DESC;

COMMENT ON VIEW claims.v_doctor_denial_detail IS 'Detailed doctor denial information with activity and claim details';

-- ==========================================================================================================
-- SECTION 7: REMITTANCE ADVICE VIEWS
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_remittance_advice_header (Remittance advice header information)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_remittance_advice_header AS
SELECT 
  r.id AS remittance_id,
  r.receiver_name,
  r.receiver_id,
  r.created_at AS remittance_date,
  r.payment_reference,
  COUNT(DISTINCT rc.id) AS claim_count,
  COUNT(DISTINCT ra.id) AS activity_count,
  SUM(ra.payment_amount) AS total_payment_amount,
  SUM(CASE WHEN ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) AS total_denied_amount,
  SUM(ra.net) AS total_remittance_amount
FROM claims.remittance r
LEFT JOIN claims.remittance_claim rc ON rc.remittance_id = r.id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
GROUP BY r.id, r.receiver_name, r.receiver_id, r.created_at, r.payment_reference
ORDER BY r.created_at DESC;

COMMENT ON VIEW claims.v_remittance_advice_header IS 'Remittance advice header information with summary statistics';

-- ----------------------------------------------------------------------------------------------------------
-- VIEW: v_remittance_advice_claim_wise (Remittance advice claim-wise details)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_remittance_advice_claim_wise AS
SELECT 
  r.id AS remittance_id,
  r.receiver_name,
  r.receiver_id,
  r.created_at AS remittance_date,
  r.payment_reference,
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
  r.id, r.receiver_name, r.receiver_id, r.created_at, r.payment_reference,
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
  r.receiver_name,
  r.receiver_id,
  r.created_at AS remittance_date,
  r.payment_reference,
  rc.id AS remittance_claim_id,
  rc.date_settlement,
  ra.id AS remittance_activity_id,
  ra.activity_id,
  ra.net AS activity_net_amount,
  ra.payment_amount AS activity_payment_amount,
  ra.denial_code,
  ra.denial_reason,
  ra.created_at AS remittance_activity_created_at,
  
  -- Activity information
  a.code AS activity_code,
  a.description AS activity_description,
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
JOIN claims.activity a ON a.id = ra.activity_id
JOIN claims.claim_key ck ON ck.id = rc.claim_key_id
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims_ref.provider p ON p.id = c.provider_ref_id
LEFT JOIN claims_ref.payer pay ON pay.id = c.payer_ref_id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims_ref.encounter_type et ON et.type_code = e.type
LEFT JOIN claims_ref.activity_code ac ON ac.id = a.activity_code_ref_id
LEFT JOIN claims_ref.denial_code dc ON dc.code = ra.denial_code
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