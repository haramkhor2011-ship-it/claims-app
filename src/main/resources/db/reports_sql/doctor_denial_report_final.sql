-- ==========================================================================================================
-- DOCTOR DENIAL REPORT - COMPREHENSIVE IMPLEMENTATION
-- ==========================================================================================================
-- Purpose: Complete database implementation for Doctor Denial Report
-- Version: 2.0 - Comprehensive
-- Date: 2025-10-02
--
-- This DDL creates comprehensive database objects for the Doctor Denial Report:
-- - v_doctor_denial_high_denial: Tab A - Doctors with high denial rates
-- - v_doctor_denial_summary: Tab B - Doctor-wise summary
-- - v_doctor_denial_detail: Tab C - Detailed patient and claim information
-- - get_doctor_denial_report: Complex filtering function
-- - get_doctor_denial_summary: Summary metrics function

-- ==========================================================================================================
-- Report Overview
-- ==========================================================================================================
-- Business purpose
-- - Identify clinicians with high denial ratios; provide summaries and drill-down details.
--
-- Core joins
-- - ck → c (claim_key → claim)
-- - c → e (encounter), a (activity for clinician), rc → ra (remittance_claim → remittance_activity)
-- - Reference: f (encounter.facility_ref_id), cl (activity.clinician_ref_id), py via COALESCE(c.payer_ref_id, rc.payer_ref_id)
-- - Top payer subquery correlates by clinician_ref_id.
--
-- Grouping
-- - Group by clinician/facility/health authority and month; EXTRACT year/month included in GROUP BY.
--
-- Derived fields
-- - rejection_percentage = rejected_claims / total_claims * 100
-- - collection_rate = SUM(ra.payment_amount) / SUM(c.net) * 100
-- - avg_claim_value = SUM(c.net) / total_claims
-- - avg_processing_days = AVG(DAYS(COALESCE(rc.date_settlement, c.tx_at) - c.tx_at))

-- ==========================================================================================================
-- COMPREHENSIVE FIELDS INCLUDED:
-- =================================
-- Tab A (Dr With High Denial): Clinician ID, Clinician Name, Total Claims, Claim Amount,
-- Remitted Claims, Remitted Amount, Rejected Claims, Rejected Amount, Pending Claims,
-- Pending Amount, Rejection Percentage, Collection Rate, Denial Rate, Avg Claim Value
--
-- Tab B (Summary): Same as Tab A but aggregated without patient details
--
-- Tab C (Detail): Claim Number, Receiver ID, Receiver Name, Payer ID, Payer Name,
-- ID Payer, Member ID, Emirates ID, Patient ID, Claim Amount, Remitted Amount,
-- Rejected Amount, Pending Amount
-- ==========================================================================================================

-- ==========================================================================================================
-- VIEW: v_doctor_denial_high_denial (Tab A - Doctors with high denial rates)
-- ==========================================================================================================
CREATE OR REPLACE VIEW claims.v_doctor_denial_high_denial AS
WITH payer_rankings AS (
  -- Replace correlated subquery with window function for better performance
  SELECT 
    clinician_ref_id,
    payer_id,
    COUNT(*) as claim_count,
    ROW_NUMBER() OVER (PARTITION BY clinician_ref_id ORDER BY COUNT(*) DESC) as payer_rank
  FROM claims.activity a
  JOIN claims.claim c ON a.claim_id = c.id
  GROUP BY clinician_ref_id, payer_id
)
SELECT
    -- Clinician Information
    a.clinician as clinician_id,
    cl.name as clinician_name,
    cl.specialty as clinician_specialty,
    a.clinician_ref_id as clinician_ref_id,

    -- Facility and Health Authority
    e.facility_id,
    e.facility_ref_id as facility_ref_id,
    f.name as facility_name,
    f.facility_code as facility_group,
    COALESCE(py.payer_code, 'Unknown') as health_authority,
    COALESCE(c.payer_ref_id, rc.payer_ref_id) as payer_ref_id,

    -- Date filtering context
    DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)) as report_month,
    EXTRACT(YEAR FROM COALESCE(rc.date_settlement, c.tx_at)) as report_year,
    EXTRACT(MONTH FROM COALESCE(rc.date_settlement, c.tx_at)) as report_month_num,

    -- Claim Counts (COMPREHENSIVE)
    COUNT(DISTINCT ck.claim_id) as total_claims,
    COUNT(DISTINCT CASE WHEN ra.id IS NOT NULL THEN ck.claim_id END) as remitted_claims,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ck.claim_id END) as rejected_claims,
    COUNT(DISTINCT CASE WHEN rc.date_settlement IS NULL THEN ck.claim_id END) as pending_remittance_claims,

    -- Amount Metrics (COMPREHENSIVE)
    SUM(a.net) as total_claim_amount,
    SUM(COALESCE(ra.payment_amount, 0)) as remitted_amount,
    SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) as rejected_amount,
    SUM(CASE WHEN rc.date_settlement IS NULL THEN a.net ELSE 0 END) as pending_remittance_amount,

    -- Calculated Metrics (COMPREHENSIVE)
    CASE
        WHEN COUNT(DISTINCT ck.claim_id) > 0 THEN
            ROUND((COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ck.claim_id END) * 100.0) / COUNT(DISTINCT ck.claim_id), 2)
        ELSE 0
    END as rejection_percentage,

    CASE
        WHEN SUM(a.net) > 0 THEN
            ROUND((SUM(COALESCE(ra.payment_amount, 0)) / SUM(a.net)) * 100, 2)
        ELSE 0
    END as collection_rate,

    CASE
        WHEN COUNT(DISTINCT ck.claim_id) > 0 THEN
            ROUND((SUM(a.net) / COUNT(DISTINCT ck.claim_id)), 2)
        ELSE 0
    END as avg_claim_value,

    -- Additional insights
    COUNT(DISTINCT c.provider_id) as unique_providers,
    COUNT(DISTINCT e.patient_id) as unique_patients,
    MIN(c.tx_at) as earliest_submission,
    MAX(c.tx_at) as latest_submission,
    AVG(EXTRACT(DAYS FROM (COALESCE(rc.date_settlement, c.tx_at) - c.tx_at))) as avg_processing_days

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer py ON py.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)

GROUP BY
    a.clinician,
    cl.name,
    cl.specialty,
    a.clinician_ref_id,
    e.facility_id,
    e.facility_ref_id,
    f.name,
    f.facility_code,
    COALESCE(py.payer_code, 'Unknown'),
    COALESCE(c.payer_ref_id, rc.payer_ref_id),
    DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)),
    EXTRACT(YEAR FROM COALESCE(rc.date_settlement, c.tx_at)),
    EXTRACT(MONTH FROM COALESCE(rc.date_settlement, c.tx_at))

ORDER BY
    rejection_percentage DESC,
    total_claims DESC,
    clinician_name;

COMMENT ON VIEW claims.v_doctor_denial_high_denial IS 'Doctor Denial Report - Tab A: Doctors with high denial rates showing comprehensive metrics including counts, amounts, percentages, and calculated KPIs';

-- ==========================================================================================================
-- VIEW: v_doctor_denial_summary (Tab B - Doctor-wise summary)
-- ==========================================================================================================
CREATE OR REPLACE VIEW claims.v_doctor_denial_summary AS
SELECT
    -- Clinician Information
    a.clinician as clinician_id,
    cl.name as clinician_name,
    cl.specialty as clinician_specialty,
    a.clinician_ref_id as clinician_ref_id,

    -- Facility and Health Authority
    e.facility_id,
    e.facility_ref_id as facility_ref_id,
    f.name as facility_name,
    f.facility_code as facility_group,
    COALESCE(py.payer_code, 'Unknown') as health_authority,
    COALESCE(c.payer_ref_id, rc.payer_ref_id) as payer_ref_id,

    -- Date filtering context
    DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)) as report_month,
    EXTRACT(YEAR FROM COALESCE(rc.date_settlement, c.tx_at)) as report_year,
    EXTRACT(MONTH FROM COALESCE(rc.date_settlement, c.tx_at)) as report_month_num,

    -- Claim Counts (AGGREGATED)
    COUNT(DISTINCT ck.claim_id) as total_claims,
    COUNT(DISTINCT CASE WHEN ra.id IS NOT NULL THEN ck.claim_id END) as remitted_claims,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ck.claim_id END) as rejected_claims,
    COUNT(DISTINCT CASE WHEN rc.date_settlement IS NULL THEN ck.claim_id END) as pending_remittance_claims,

    -- Amount Metrics (AGGREGATED)
    SUM(a.net) as total_claim_amount,
    SUM(COALESCE(ra.payment_amount, 0)) as remitted_amount,
    SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) as rejected_amount,
    SUM(CASE WHEN rc.date_settlement IS NULL THEN a.net ELSE 0 END) as pending_remittance_amount,

    -- Net Balance Calculation
    SUM(a.net) - SUM(COALESCE(ra.payment_amount, 0)) as net_balance,

    -- Top Payer (payer with most claims for this clinician)
    (SELECT p2.payer_code FROM (
        SELECT COALESCE(c2.payer_ref_id, rc2.payer_ref_id) as payer_ref_id,
               COUNT(*) as claim_count
        FROM claims.claim_key ck2
        JOIN claims.claim c2 ON c2.claim_key_id = ck2.id
        LEFT JOIN claims.remittance_claim rc2 ON rc2.claim_key_id = ck2.id
        WHERE c2.id IN (
            SELECT c3.id FROM claims.claim c3
            JOIN claims.activity a3 ON a3.claim_id = c3.id
            WHERE a3.clinician_ref_id = cl.id
        )
        GROUP BY COALESCE(c2.payer_ref_id, rc2.payer_ref_id)
        ORDER BY claim_count DESC
        LIMIT 1
    ) top
    JOIN claims_ref.payer p2 ON p2.id = top.payer_ref_id) as top_payer_code,

    -- Calculated Metrics (AGGREGATED)
    CASE
        WHEN COUNT(DISTINCT ck.claim_id) > 0 THEN
            ROUND((COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ck.claim_id END) * 100.0) / COUNT(DISTINCT ck.claim_id), 2)
        ELSE 0
    END as rejection_percentage,

    CASE
        WHEN SUM(a.net) > 0 THEN
            ROUND((SUM(COALESCE(ra.payment_amount, 0)) / SUM(a.net)) * 100, 2)
        ELSE 0
    END as collection_rate,

    CASE
        WHEN COUNT(DISTINCT ck.claim_id) > 0 THEN
            ROUND((SUM(a.net) / COUNT(DISTINCT ck.claim_id)), 2)
        ELSE 0
    END as avg_claim_value,

    -- Additional insights
    COUNT(DISTINCT c.provider_id) as unique_providers,
    COUNT(DISTINCT e.patient_id) as unique_patients,
    MIN(c.tx_at) as earliest_submission,
    MAX(c.tx_at) as latest_submission

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.payer py ON py.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)

GROUP BY
    a.clinician,
    cl.id,
    cl.name,
    cl.specialty,
    a.clinician_ref_id,
    e.facility_id,
    e.facility_ref_id,
    f.name,
    f.facility_code,
    COALESCE(py.payer_code, 'Unknown'),
    COALESCE(c.payer_ref_id, rc.payer_ref_id),
    DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)),
    EXTRACT(YEAR FROM COALESCE(rc.date_settlement, c.tx_at)),
    EXTRACT(MONTH FROM COALESCE(rc.date_settlement, c.tx_at))

ORDER BY
    rejection_percentage DESC,
    total_claims DESC,
    clinician_name;

COMMENT ON VIEW claims.v_doctor_denial_summary IS 'Doctor Denial Report - Tab B: Doctor-wise summary with aggregated metrics, net balance, and top payer information';

-- ==========================================================================================================
-- VIEW: v_doctor_denial_detail (Tab C - Detailed patient and claim information)
-- ==========================================================================================================
CREATE OR REPLACE VIEW claims.v_doctor_denial_detail AS
SELECT
    -- Claim Information
    ck.claim_id,
    c.id as claim_db_id,
    c.payer_id,
    c.provider_id,
    c.member_id,
    c.emirates_id_number,
    c.gross,
    c.patient_share,
    c.net as claim_amount,

    -- Provider and Payer Information
    pr.name as provider_name,
    pr.provider_code as receiver_id,
    py.name as payer_name,
    py.payer_code as payer_code,
    COALESCE(c.payer_ref_id, rc.payer_ref_id) as payer_ref_id,
    rc.id_payer as id_payer,

    -- Patient Information
    e.patient_id,

    -- Clinician Information
    a.clinician as clinician_id,
    cl.name as clinician_name,
    a.clinician_ref_id as clinician_ref_id,
    a.activity_id as claim_activity_number,

    -- Facility Information
    e.facility_id,
    e.facility_ref_id as facility_ref_id,
    f.name as facility_name,
    f.facility_code as facility_group,

    -- Remittance Information
    rc.id as remittance_claim_id,
    rc.payment_reference,
    rc.date_settlement,
    COALESCE(ra.payment_amount, 0) as remitted_amount,
    CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END as rejected_amount,
    CASE WHEN rc.date_settlement IS NULL THEN c.net ELSE 0 END as pending_remittance_amount,

    -- Activity Information
    a.start_at as activity_start_date,
    a.type as activity_type,
    a.code as cpt_code,
    a.quantity,

    -- Date filtering context
    DATE_TRUNC('month', COALESCE(rc.date_settlement, c.tx_at)) as report_month,
    EXTRACT(YEAR FROM COALESCE(rc.date_settlement, c.tx_at)) as report_year,
    EXTRACT(MONTH FROM COALESCE(rc.date_settlement, c.tx_at)) as report_month_num,

    -- Calculated fields for the view
    c.tx_at as submission_date,
    r.tx_at as remittance_date,
    c.created_at,
    c.updated_at

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims_ref.provider pr ON pr.id = c.provider_ref_id
LEFT JOIN claims_ref.payer py ON py.id = COALESCE(c.payer_ref_id, rc.payer_ref_id)

ORDER BY
    ck.claim_id,
    c.created_at DESC;

COMMENT ON VIEW claims.v_doctor_denial_detail IS 'Doctor Denial Report - Tab C: Detailed patient and claim information with line-level data for auditing';

-- ==========================================================================================================
-- FUNCTION: get_doctor_denial_report (Complex filtering for all tabs)
-- ==========================================================================================================
CREATE OR REPLACE FUNCTION claims.get_doctor_denial_report(
    p_facility_code TEXT DEFAULT NULL,
    p_clinician_code TEXT DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NULL,
    p_to_date TIMESTAMPTZ DEFAULT NULL,
    p_year INTEGER DEFAULT NULL,
    p_month INTEGER DEFAULT NULL,
    p_facility_ref_id BIGINT DEFAULT NULL,
    p_clinician_ref_id BIGINT DEFAULT NULL,
    p_payer_ref_id BIGINT DEFAULT NULL,
    p_tab TEXT DEFAULT 'high_denial',
    p_limit INTEGER DEFAULT 1000,
    p_offset INTEGER DEFAULT 0
) RETURNS TABLE(
    -- Common fields for all tabs
    clinician_id TEXT,
    clinician_name TEXT,
    clinician_specialty TEXT,
    facility_id TEXT,
    facility_name TEXT,
    facility_group TEXT,
    health_authority TEXT,
    report_month TIMESTAMPTZ,
    report_year INTEGER,
    report_month_num INTEGER,

    -- Tab A and B fields
    total_claims BIGINT,
    remitted_claims BIGINT,
    rejected_claims BIGINT,
    pending_remittance_claims BIGINT,
    total_claim_amount NUMERIC(14,2),
    remitted_amount NUMERIC(14,2),
    rejected_amount NUMERIC(14,2),
    pending_remittance_amount NUMERIC(14,2),
    rejection_percentage NUMERIC(5,2),
    collection_rate NUMERIC(5,2),
    avg_claim_value NUMERIC(14,2),
    net_balance NUMERIC(14,2),
    top_payer_code TEXT,

    -- Additional fields for Tab A
    unique_providers BIGINT,
    unique_patients BIGINT,
    earliest_submission TIMESTAMPTZ,
    latest_submission TIMESTAMPTZ,
    avg_processing_days NUMERIC(5,2),

    -- Tab C fields
    claim_id TEXT,
    claim_db_id BIGINT,
    payer_id TEXT,
    provider_id TEXT,
    member_id TEXT,
    emirates_id_number TEXT,
    patient_id TEXT,
    claim_amount NUMERIC(14,2),
    provider_name TEXT,
    receiver_id TEXT,
    payer_name TEXT,
    payer_code TEXT,
    id_payer TEXT,
    claim_activity_number TEXT,
    activity_start_date TIMESTAMPTZ,
    activity_type TEXT,
    cpt_code TEXT,
    quantity NUMERIC(14,2),
    remittance_claim_id BIGINT,
    payment_reference TEXT,
    date_settlement TIMESTAMPTZ,
    submission_date TIMESTAMPTZ,
    remittance_date TIMESTAMPTZ
) AS $$
BEGIN
    -- Determine which view to query based on tab parameter
    CASE p_tab
        WHEN 'high_denial' THEN
            RETURN QUERY
            -- Use materialized view for sub-second performance
            SELECT
                mv.clinician_id,
                mv.clinician_name,
                mv.clinician_specialty,
                mv.facility_id,
                mv.facility_name,
                mv.facility_group,
                mv.health_authority,
                mv.report_month,
                mv.report_year,
                mv.report_month_num,
                mv.total_claims,
                mv.remitted_claims,
                mv.rejected_claims,
                mv.pending_remittance_claims,
                mv.total_claim_amount,
                mv.remitted_amount,
                mv.rejected_amount,
                mv.pending_remittance_amount,
                mv.rejection_percentage,
                mv.collection_rate,
                mv.avg_claim_value,
                NULL::NUMERIC(14,2) as net_balance,
                NULL::TEXT as top_payer_code,
                mv.unique_providers,
                mv.unique_patients,
                mv.earliest_submission,
                mv.latest_submission,
                mv.avg_processing_days,
                NULL::TEXT as claim_id,
                NULL::BIGINT as claim_db_id,
                NULL::TEXT as payer_id,
                NULL::TEXT as provider_id,
                NULL::TEXT as member_id,
                NULL::TEXT as emirates_id_number,
                NULL::TEXT as patient_id,
                NULL::NUMERIC(14,2) as claim_amount,
                NULL::TEXT as provider_name,
                NULL::TEXT as receiver_id,
                NULL::TEXT as payer_name,
                NULL::TEXT as payer_code,
                NULL::TEXT as id_payer,
                NULL::TEXT as claim_activity_number,
                NULL::TIMESTAMPTZ as activity_start_date,
                NULL::TEXT as activity_type,
                NULL::TEXT as cpt_code,
                NULL::NUMERIC(14,2) as quantity,
                NULL::BIGINT as remittance_claim_id,
                NULL::TEXT as payment_reference,
                NULL::TIMESTAMPTZ as date_settlement,
                NULL::TIMESTAMPTZ as submission_date,
                NULL::TIMESTAMPTZ as remittance_date
            FROM claims.mv_doctor_denial_summary mv
            WHERE
                (p_facility_code IS NULL OR mv.facility_id = p_facility_code)
                AND (p_clinician_code IS NULL OR mv.clinician_id = p_clinician_code)
                AND (p_facility_ref_id IS NULL OR mv.facility_ref_id = p_facility_ref_id)
                AND (p_clinician_ref_id IS NULL OR mv.clinician_ref_id = p_clinician_ref_id)
                AND (p_payer_ref_id IS NULL OR mv.payer_ref_id = p_payer_ref_id)
                AND (p_from_date IS NULL OR mv.report_month >= DATE_TRUNC('month', p_from_date))
                AND (p_to_date IS NULL OR mv.report_month <= DATE_TRUNC('month', p_to_date))
                AND (p_year IS NULL OR mv.report_year = p_year)
                AND (p_month IS NULL OR mv.report_month_num = p_month)
            ORDER BY mv.rejection_percentage DESC, mv.total_claims DESC
            LIMIT p_limit OFFSET p_offset;

        WHEN 'summary' THEN
            RETURN QUERY
            SELECT
                vds.clinician_id,
                vds.clinician_name,
                vds.clinician_specialty,
                vds.facility_id,
                vds.facility_name,
                vds.facility_group,
                vds.health_authority,
                vds.report_month,
                vds.report_year,
                vds.report_month_num,
                vds.total_claims,
                vds.remitted_claims,
                vds.rejected_claims,
                vds.pending_remittance_claims,
                vds.total_claim_amount,
                vds.remitted_amount,
                vds.rejected_amount,
                vds.pending_remittance_amount,
                vds.rejection_percentage,
                vds.collection_rate,
                vds.avg_claim_value,
                vds.net_balance,
                vds.top_payer_code,
                vds.unique_providers,
                vds.unique_patients,
                vds.earliest_submission,
                vds.latest_submission,
                NULL::NUMERIC(5,2) as avg_processing_days,
                NULL::TEXT as claim_id,
                NULL::BIGINT as claim_db_id,
                NULL::TEXT as payer_id,
                NULL::TEXT as provider_id,
                NULL::TEXT as member_id,
                NULL::TEXT as emirates_id_number,
                NULL::TEXT as patient_id,
                NULL::NUMERIC(14,2) as claim_amount,
                NULL::TEXT as provider_name,
                NULL::TEXT as receiver_id,
                NULL::TEXT as payer_name,
                NULL::TEXT as payer_code,
                NULL::TEXT as id_payer,
                NULL::TEXT as claim_activity_number,
                NULL::TIMESTAMPTZ as activity_start_date,
                NULL::TEXT as activity_type,
                NULL::TEXT as cpt_code,
                NULL::NUMERIC(14,2) as quantity,
                NULL::BIGINT as remittance_claim_id,
                NULL::TEXT as payment_reference,
                NULL::TIMESTAMPTZ as date_settlement,
                NULL::TIMESTAMPTZ as submission_date,
                NULL::TIMESTAMPTZ as remittance_date
            FROM claims.v_doctor_denial_summary vds
            WHERE
                (p_facility_code IS NULL OR vds.facility_id = p_facility_code)
                AND (p_clinician_code IS NULL OR vds.clinician_id = p_clinician_code)
                AND (p_facility_ref_id IS NULL OR vds.facility_ref_id = p_facility_ref_id)
                AND (p_clinician_ref_id IS NULL OR vds.clinician_ref_id = p_clinician_ref_id)
                AND (p_payer_ref_id IS NULL OR vds.payer_ref_id = p_payer_ref_id)
                AND (p_from_date IS NULL OR vds.report_month >= DATE_TRUNC('month', p_from_date))
                AND (p_to_date IS NULL OR vds.report_month <= DATE_TRUNC('month', p_to_date))
                AND (p_year IS NULL OR vds.report_year = p_year)
                AND (p_month IS NULL OR vds.report_month_num = p_month)
            ORDER BY vds.rejection_percentage DESC, vds.total_claims DESC
            LIMIT p_limit OFFSET p_offset;

        WHEN 'detail' THEN
            RETURN QUERY
            SELECT
                NULL::TEXT as clinician_id,
                NULL::TEXT as clinician_name,
                NULL::TEXT as clinician_specialty,
                vdd.facility_id,
                vdd.facility_name,
                vdd.facility_group,
                NULL::TEXT as health_authority,
                vdd.report_month,
                vdd.report_year,
                vdd.report_month_num,
                NULL::BIGINT as total_claims,
                NULL::BIGINT as remitted_claims,
                NULL::BIGINT as rejected_claims,
                NULL::BIGINT as pending_remittance_claims,
                NULL::NUMERIC(14,2) as total_claim_amount,
                NULL::NUMERIC(14,2) as remitted_amount,
                NULL::NUMERIC(14,2) as rejected_amount,
                NULL::NUMERIC(14,2) as pending_remittance_amount,
                NULL::NUMERIC(5,2) as rejection_percentage,
                NULL::NUMERIC(5,2) as collection_rate,
                NULL::NUMERIC(14,2) as avg_claim_value,
                NULL::NUMERIC(14,2) as net_balance,
                NULL::TEXT as top_payer_code,
                NULL::BIGINT as unique_providers,
                NULL::BIGINT as unique_patients,
                NULL::TIMESTAMPTZ as earliest_submission,
                NULL::TIMESTAMPTZ as latest_submission,
                NULL::NUMERIC(5,2) as avg_processing_days,
                vdd.claim_id,
                vdd.claim_db_id,
                vdd.payer_id,
                vdd.provider_id,
                vdd.member_id,
                vdd.emirates_id_number,
                vdd.patient_id,
                vdd.claim_amount,
                vdd.provider_name,
                vdd.receiver_id,
                vdd.payer_name,
                vdd.payer_code,
                vdd.id_payer,
                vdd.claim_activity_number,
                vdd.activity_start_date,
                vdd.activity_type,
                vdd.cpt_code,
                vdd.quantity,
                vdd.remittance_claim_id,
                vdd.payment_reference,
                vdd.date_settlement,
                vdd.submission_date,
                vdd.remittance_date
            FROM claims.v_doctor_denial_detail vdd
            WHERE
                (p_facility_code IS NULL OR vdd.facility_id = p_facility_code)
                AND (p_clinician_code IS NULL OR vdd.clinician_id = p_clinician_code)
                AND (p_facility_ref_id IS NULL OR vdd.facility_ref_id = p_facility_ref_id)
                AND (p_clinician_ref_id IS NULL OR vdd.clinician_ref_id = p_clinician_ref_id)
                AND (p_payer_ref_id IS NULL OR vdd.payer_ref_id = p_payer_ref_id)
                AND (p_from_date IS NULL OR vdd.submission_date >= p_from_date)
                AND (p_to_date IS NULL OR vdd.submission_date <= p_to_date)
                AND (p_year IS NULL OR vdd.report_year = p_year)
                AND (p_month IS NULL OR vdd.report_month_num = p_month)
            ORDER BY vdd.submission_date DESC, vdd.claim_id
            LIMIT p_limit OFFSET p_offset;

        ELSE
            -- Default to high_denial tab
            RETURN QUERY
            SELECT * FROM claims.get_doctor_denial_report(
                p_facility_code, p_clinician_code, p_from_date, p_to_date,
                p_year, p_month, p_facility_ref_id, p_clinician_ref_id, p_payer_ref_id,
                'high_denial', p_limit, p_offset
            );
    END CASE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION claims.get_doctor_denial_report IS 'Get filtered doctor denial report data for all three tabs (high_denial, summary, detail) with optional ref-id filters';

-- ==========================================================================================================
-- FUNCTION: get_doctor_denial_summary (Dashboard metrics)
-- ==========================================================================================================
CREATE OR REPLACE FUNCTION claims.get_doctor_denial_summary(
    p_facility_code TEXT DEFAULT NULL,
    p_clinician_code TEXT DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NULL,
    p_to_date TIMESTAMPTZ DEFAULT NULL,
    p_year INTEGER DEFAULT NULL,
    p_month INTEGER DEFAULT NULL
) RETURNS TABLE(
    total_doctors BIGINT,
    total_claims BIGINT,
    total_claim_amount NUMERIC(14,2),
    total_remitted_amount NUMERIC(14,2),
    total_rejected_amount NUMERIC(14,2),
    total_pending_amount NUMERIC(14,2),
    avg_rejection_rate NUMERIC(5,2),
    avg_collection_rate NUMERIC(5,2),
    doctors_with_high_denial BIGINT,
    high_risk_doctors BIGINT,
    improvement_potential NUMERIC(14,2)
) AS $$
BEGIN
    RETURN QUERY
    WITH filtered_data AS (
        SELECT
            vhd.clinician_id,
            vhd.total_claims,
            vhd.total_claim_amount,
            vhd.remitted_amount,
            vhd.rejected_amount,
            vhd.pending_remittance_amount,
            vhd.rejection_percentage,
            vhd.collection_rate
        FROM claims.v_doctor_denial_high_denial vhd
        WHERE
            (p_facility_code IS NULL OR vhd.facility_id = p_facility_code)
            AND (p_clinician_code IS NULL OR vhd.clinician_id = p_clinician_code)
            AND (p_from_date IS NULL OR vhd.report_month >= DATE_TRUNC('month', p_from_date))
            AND (p_to_date IS NULL OR vhd.report_month <= DATE_TRUNC('month', p_to_date))
            AND (p_year IS NULL OR vhd.report_year = p_year)
            AND (p_month IS NULL OR vhd.report_month_num = p_month)
    )
    SELECT
        COUNT(DISTINCT clinician_id) as total_doctors,
        SUM(total_claims) as total_claims,
        SUM(total_claim_amount) as total_claim_amount,
        SUM(remitted_amount) as total_remitted_amount,
        SUM(rejected_amount) as total_rejected_amount,
        SUM(pending_remittance_amount) as total_pending_amount,
        ROUND(AVG(rejection_percentage), 2) as avg_rejection_rate,
        ROUND(AVG(collection_rate), 2) as avg_collection_rate,
        COUNT(DISTINCT CASE WHEN rejection_percentage > 20 THEN clinician_id END) as doctors_with_high_denial,
        COUNT(DISTINCT CASE WHEN rejection_percentage > 50 THEN clinician_id END) as high_risk_doctors,
        SUM(CASE WHEN rejection_percentage > 20 THEN rejected_amount ELSE 0 END) as improvement_potential
    FROM filtered_data;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION claims.get_doctor_denial_summary IS 'Get summary metrics for Doctor Denial Report dashboard';

-- ==========================================================================================================
-- PERFORMANCE INDEXES
-- ==========================================================================================================

-- Main indexes for doctor denial views
CREATE INDEX IF NOT EXISTS idx_doctor_denial_clinician ON claims.activity(clinician);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_facility ON claims.encounter(facility_id);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_report_month ON claims.claim(tx_at);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_remittance_settlement ON claims.remittance_claim(date_settlement);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_rejection_percentage ON claims.remittance_activity((CASE WHEN payment_amount = 0 OR denial_code IS NOT NULL THEN 1 ELSE 0 END));

-- Composite indexes for common filter combinations
CREATE INDEX IF NOT EXISTS idx_doctor_denial_clinician_facility ON claims.activity(clinician, claim_id) WHERE clinician IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_doctor_denial_facility_month ON claims.encounter(facility_id, claim_id) WHERE facility_id IS NOT NULL;

-- ==========================================================================================================
-- COMMENTS AND DOCUMENTATION
-- ==========================================================================================================

COMMENT ON VIEW claims.v_doctor_denial_high_denial IS 'Doctor Denial Report - Tab A: Doctors with high denial rates showing comprehensive metrics including counts, amounts, percentages, and calculated KPIs';
COMMENT ON VIEW claims.v_doctor_denial_summary IS 'Doctor Denial Report - Tab B: Doctor-wise summary with aggregated metrics, net balance, and top payer information';
COMMENT ON VIEW claims.v_doctor_denial_detail IS 'Doctor Denial Report - Tab C: Detailed patient and claim information with line-level data for auditing';

-- ==========================================================================================================
-- USAGE EXAMPLES
-- ==========================================================================================================

/*
-- Get doctors with high denial rates for a specific facility (Tab A)
SELECT * FROM claims.v_doctor_denial_high_denial
WHERE facility_id = 'FAC001'
  AND report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '6 months')
ORDER BY rejection_percentage DESC;

-- Get doctor-wise summary with net balance (Tab B)
SELECT * FROM claims.v_doctor_denial_summary
WHERE facility_id = 'FAC001'
  AND report_year = 2025
  AND report_month_num = 1
ORDER BY rejection_percentage DESC;

-- Get detailed patient and claim information (Tab C)
SELECT * FROM claims.v_doctor_denial_detail
WHERE clinician_id = 'DR001'
  AND submission_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY submission_date DESC;

-- Get summary metrics for dashboard
SELECT * FROM claims.get_doctor_denial_summary(
    'FAC001', -- facility_code
    NULL, -- clinician_code
    CURRENT_DATE - INTERVAL '12 months', -- from_date
    CURRENT_DATE -- to_date
);

-- Complex filtering across all tabs
SELECT * FROM claims.get_doctor_denial_report(
    'FAC001', -- facility_code
    NULL, -- clinician_code
    CURRENT_DATE - INTERVAL '6 months', -- from_date
    CURRENT_DATE, -- to_date
    2025, -- year
    1, -- month
    'high_denial', -- tab
    500, -- limit
    0 -- offset
);
*/

-- =====================================================
-- GRANTS
-- =====================================================
GRANT SELECT ON claims.v_doctor_denial_high_denial TO claims_user;
GRANT SELECT ON claims.v_doctor_denial_summary TO claims_user;
GRANT SELECT ON claims.v_doctor_denial_detail TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_doctor_denial_report(text,text,timestamptz,timestamptz,integer,integer,bigint,bigint,bigint,text,integer,integer) TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_doctor_denial_summary(text,text,timestamptz,timestamptz,integer,integer) TO claims_user;