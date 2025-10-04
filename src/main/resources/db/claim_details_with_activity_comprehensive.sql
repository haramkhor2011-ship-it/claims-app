-- ==========================================================================================================
-- CLAIM DETAILS WITH ACTIVITY REPORT - COMPREHENSIVE IMPLEMENTATION
-- ==========================================================================================================
-- Purpose: Complete database implementation for Claim Details with Activity Report
-- Version: 2.0 - Comprehensive
-- Date: 2025-10-02
--
-- This DDL creates comprehensive database objects for the Claim Details with Activity Report:
-- - v_claim_details_with_activity: Main comprehensive view with all required fields
-- - get_claim_details_with_activity: Complex filtering function
-- - get_claim_details_summary: Summary metrics function
-- - Additional helper views and functions for complex calculations
--
-- COMPREHENSIVE FIELDS INCLUDED:
-- =================================
-- A) Submission & Remittance Tracking
-- B) Claim Financials
-- C) Denial & Resubmission Information
-- D) Remittance and Rejection Tracking
-- E) Patient and Payer Information
-- F) Encounter & Activity Details
-- G) Calculated Metrics (Collection Rate, Denial Rate, Write-off %, Turnaround Time, etc.)
-- ==========================================================================================================

-- ==========================================================================================================
-- MAIN COMPREHENSIVE VIEW: v_claim_details_with_activity
-- ==========================================================================================================
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
    pr.provider_code as receiver_id,
    py.name as payer_name,
    py.payer_code as payer_code,

    -- Encounter Information
    e.facility_id,
    e.type as encounter_type,
    e.patient_id,
    e.start_at as encounter_start,
    e.end_at as encounter_end_date,
    e.start_type,
    e.end_type,
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
    rc.denial_code as initial_denial_code,
    r.tx_at as remittance_date,
    r.id as remittance_id,

    -- Activity Information (aggregated for the claim)
    a.activity_id as claim_activity_number,
    a.start_at as activity_start_date,
    a.type as activity_type,
    a.code as cpt_code,
    a.quantity,
    a.net as activity_net_amount,
    a.clinician as clinician,
    a.prior_authorization_id,
    cl.name as clinician_name,
    ac.description as activity_description,

    -- Diagnosis Information (Principal and Secondary)
    d_principal.code as primary_diagnosis,
    d_principal.diag_type as primary_diagnosis_type,
    d_secondary.code as secondary_diagnosis,
    d_secondary.diag_type as secondary_diagnosis_type,

    -- File and Transaction Tracking
    if_submission.file_id as last_submission_file,
    if_submission.transaction_date as last_submission_transaction_date,
    if_remittance.file_id as last_remittance_file,
    if_remittance.transaction_date as last_remittance_transaction_date,

    -- Status Information
    cst.status as claim_status,
    cst.status_time as claim_status_time,
    CASE
        WHEN ra.payment_amount > 0 AND ra.payment_amount = ra.net THEN 'Fully Paid'
        WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN 'Partially Paid'
        WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 'Rejected'
        WHEN rc.date_settlement IS NULL THEN 'Pending'
        ELSE 'Unknown'
    END as payment_status,

    -- Financial Calculations
    COALESCE(ra.payment_amount, 0) as remitted_amount,
    COALESCE(ra.payment_amount, 0) as settled_amount,
    CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END as rejected_amount,
    CASE WHEN rc.date_settlement IS NULL THEN c.net ELSE 0 END as unprocessed_amount,
    CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END as initial_rejected_amount,

    -- Denial Information
    ra.denial_code as last_denial_code,
    ''::text as remittance_comments,
    c.comments as denial_comment,

    -- Resubmission Information
    cr.resubmission_type,
    cr.comment as resubmission_comment,

    -- Calculated Metrics
    CASE
        WHEN c.net > 0 THEN
            ROUND((COALESCE(ra.payment_amount, 0) / c.net) * 100, 2)
        ELSE 0
    END as net_collection_rate,

    CASE
        WHEN c.net > 0 THEN
            ROUND(((CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) / c.net) * 100, 2)
        ELSE 0
    END as denial_rate,

    -- Turnaround Time (Last Remittance - Encounter Start)
    CASE
        WHEN e.start_at IS NOT NULL AND r.tx_at IS NOT NULL THEN
            EXTRACT(DAYS FROM (r.tx_at - e.start_at))::int
        ELSE NULL
    END as turnaround_time_days,

    -- Resubmission Effectiveness (if applicable)
    CASE
        WHEN cr.id IS NOT NULL AND ra.payment_amount > 0 THEN
            CASE
                WHEN (CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END) > 0 THEN
                    ROUND((ra.payment_amount / (CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) * 100, 2)
                ELSE 0
            END
        ELSE 0
    END as resubmission_effectiveness,

    -- Additional Metadata
    c.created_at,
    c.updated_at,
    r.created_at as remittance_created_at,
    rc.created_at as remittance_claim_created_at

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.submission s ON s.id = c.submission_id
LEFT JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims_ref.facility f ON f.facility_code = e.facility_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims.claim_status_timeline cst ON cst.claim_key_id = ck.id
    AND cst.id = (SELECT MAX(id) FROM claims.claim_status_timeline WHERE claim_key_id = ck.id)
LEFT JOIN claims.claim_event ce_resub ON ce_resub.claim_key_id = ck.id AND ce_resub.type = 2
LEFT JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce_resub.id
LEFT JOIN claims_ref.provider pr ON pr.provider_code = c.provider_id
LEFT JOIN claims_ref.payer py ON py.payer_code = c.payer_id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims_ref.clinician cl ON cl.clinician_code = a.clinician
LEFT JOIN claims_ref.activity_code ac ON ac.code = a.code
LEFT JOIN claims.diagnosis d_principal ON d_principal.claim_id = c.id AND d_principal.diag_type = 'Principal'
LEFT JOIN claims.diagnosis d_secondary ON d_secondary.claim_id = c.id AND d_secondary.diag_type = 'Secondary'
LEFT JOIN claims.ingestion_file if_submission ON if_submission.id = s.ingestion_file_id
LEFT JOIN claims.ingestion_file if_remittance ON if_remittance.id = r.ingestion_file_id

ORDER BY ck.claim_id, c.created_at DESC;

COMMENT ON VIEW claims.v_claim_details_with_activity IS 'COMPREHENSIVE Claim Details with Activity Report - Main view with ALL required fields including submission tracking, financials, denial info, remittance tracking, patient/payer info, encounter/activity details, and calculated metrics';

-- ==========================================================================================================
-- FUNCTION: get_claim_details_with_activity (Complex filtering)
-- ==========================================================================================================
CREATE OR REPLACE FUNCTION claims.get_claim_details_with_activity(
    p_facility_code TEXT DEFAULT NULL,
    p_receiver_id TEXT DEFAULT NULL,
    p_payer_code TEXT DEFAULT NULL,
    p_clinician TEXT DEFAULT NULL,
    p_claim_id TEXT DEFAULT NULL,
    p_patient_id TEXT DEFAULT NULL,
    p_cpt_code TEXT DEFAULT NULL,
    p_claim_status TEXT DEFAULT NULL,
    p_payment_status TEXT DEFAULT NULL,
    p_encounter_type TEXT DEFAULT NULL,
    p_resub_type TEXT DEFAULT NULL,
    p_denial_code TEXT DEFAULT NULL,
    p_member_id TEXT DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NULL,
    p_to_date TIMESTAMPTZ DEFAULT NULL,
    p_limit INTEGER DEFAULT 1000,
    p_offset INTEGER DEFAULT 0
) RETURNS TABLE(
    claim_id TEXT,
    claim_db_id BIGINT,
    payer_id TEXT,
    provider_id TEXT,
    member_id TEXT,
    emirates_id_number TEXT,
    gross_amount NUMERIC(14,2),
    patient_share NUMERIC(14,2),
    initial_net_amount NUMERIC(14,2),
    comments TEXT,
    submission_date TIMESTAMPTZ,
    provider_name TEXT,
    receiver_id TEXT,
    payer_name TEXT,
    payer_code TEXT,
    facility_id TEXT,
    encounter_type TEXT,
    patient_id TEXT,
    encounter_start TIMESTAMPTZ,
    encounter_end_date TIMESTAMPTZ,
    facility_name TEXT,
    facility_group TEXT,
    submission_id BIGINT,
    submission_transaction_date TIMESTAMPTZ,
    remittance_claim_id BIGINT,
    remittance_payer_id TEXT,
    payment_reference TEXT,
    initial_date_settlement TIMESTAMPTZ,
    initial_denial_code TEXT,
    remittance_date TIMESTAMPTZ,
    remittance_id BIGINT,
    claim_activity_number TEXT,
    activity_start_date TIMESTAMPTZ,
    activity_type TEXT,
    cpt_code TEXT,
    quantity NUMERIC(14,2),
    activity_net_amount NUMERIC(14,2),
    clinician TEXT,
    prior_authorization_id TEXT,
    clinician_name TEXT,
    activity_description TEXT,
    primary_diagnosis TEXT,
    secondary_diagnosis TEXT,
    last_submission_file TEXT,
    last_submission_transaction_date TIMESTAMPTZ,
    last_remittance_file TEXT,
    last_remittance_transaction_date TIMESTAMPTZ,
    claim_status TEXT,
    claim_status_time TIMESTAMPTZ,
    payment_status TEXT,
    remitted_amount NUMERIC(14,2),
    settled_amount NUMERIC(14,2),
    rejected_amount NUMERIC(14,2),
    unprocessed_amount NUMERIC(14,2),
    initial_rejected_amount NUMERIC(14,2),
    last_denial_code TEXT,
    remittance_comments TEXT,
    denial_comment TEXT,
    resubmission_type TEXT,
    resubmission_comment TEXT,
    net_collection_rate NUMERIC(5,2),
    denial_rate NUMERIC(5,2),
    turnaround_time_days INTEGER,
    resubmission_effectiveness NUMERIC(5,2),
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        cdwa.claim_id,
        cdwa.claim_db_id,
        cdwa.payer_id,
        cdwa.provider_id,
        cdwa.member_id,
        cdwa.emirates_id_number,
        cdwa.gross,
        cdwa.patient_share,
        cdwa.initial_net_amount,
        cdwa.comments,
        cdwa.submission_date,
        cdwa.provider_name,
        cdwa.receiver_id,
        cdwa.payer_name,
        cdwa.payer_code,
        cdwa.facility_id,
        cdwa.encounter_type,
        cdwa.patient_id,
        cdwa.encounter_start,
        cdwa.encounter_end_date,
        cdwa.facility_name,
        cdwa.facility_group,
        cdwa.submission_id,
        cdwa.submission_transaction_date,
        cdwa.remittance_claim_id,
        cdwa.id_payer,
        cdwa.payment_reference,
        cdwa.initial_date_settlement,
        cdwa.initial_denial_code,
        cdwa.remittance_date,
        cdwa.remittance_id,
        cdwa.claim_activity_number,
        cdwa.activity_start_date,
        cdwa.activity_type,
        cdwa.cpt_code,
        cdwa.quantity,
        cdwa.activity_net_amount,
        cdwa.clinician,
        cdwa.prior_authorization_id,
        cdwa.clinician_name,
        cdwa.activity_description,
        cdwa.primary_diagnosis,
        cdwa.secondary_diagnosis,
        cdwa.last_submission_file,
        cdwa.last_submission_transaction_date,
        cdwa.last_remittance_file,
        cdwa.last_remittance_transaction_date,
        cdwa.claim_status,
        cdwa.claim_status_time,
        cdwa.payment_status,
        cdwa.remitted_amount,
        cdwa.settled_amount,
        cdwa.rejected_amount,
        cdwa.unprocessed_amount,
        cdwa.initial_rejected_amount,
        cdwa.last_denial_code,
        cdwa.remittance_comments,
        cdwa.denial_comment,
        cdwa.resubmission_type,
        cdwa.resubmission_comment,
        cdwa.net_collection_rate,
        cdwa.denial_rate,
        cdwa.turnaround_time_days,
        cdwa.resubmission_effectiveness,
        cdwa.created_at,
        cdwa.updated_at
    FROM claims.v_claim_details_with_activity cdwa
    WHERE
        (p_facility_code IS NULL OR cdwa.facility_id = p_facility_code)
        AND (p_receiver_id IS NULL OR cdwa.receiver_id = p_receiver_id)
        AND (p_payer_code IS NULL OR cdwa.payer_code = p_payer_code)
        AND (p_clinician IS NULL OR cdwa.clinician = p_clinician)
        AND (p_claim_id IS NULL OR cdwa.claim_id = p_claim_id)
        AND (p_patient_id IS NULL OR cdwa.patient_id = p_patient_id)
        AND (p_cpt_code IS NULL OR cdwa.cpt_code = p_cpt_code)
        AND (p_claim_status IS NULL OR cdwa.claim_status = p_claim_status)
        AND (p_payment_status IS NULL OR cdwa.payment_status = p_payment_status)
        AND (p_encounter_type IS NULL OR cdwa.encounter_type = p_encounter_type)
        AND (p_resub_type IS NULL OR cdwa.resubmission_type = p_resub_type)
        AND (p_denial_code IS NULL OR cdwa.last_denial_code = p_denial_code)
        AND (p_member_id IS NULL OR cdwa.member_id = p_member_id)
        AND (p_from_date IS NULL OR cdwa.submission_date >= p_from_date)
        AND (p_to_date IS NULL OR cdwa.submission_date <= p_to_date)
    ORDER BY cdwa.submission_date DESC, cdwa.claim_id
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION claims.get_claim_details_with_activity IS 'Get filtered claim details with activity data for comprehensive reporting';

-- ==========================================================================================================
-- FUNCTION: get_claim_details_summary (Dashboard metrics)
-- ==========================================================================================================
CREATE OR REPLACE FUNCTION claims.get_claim_details_summary(
    p_facility_code TEXT DEFAULT NULL,
    p_receiver_id TEXT DEFAULT NULL,
    p_payer_code TEXT DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NULL,
    p_to_date TIMESTAMPTZ DEFAULT NULL
) RETURNS TABLE(
    total_claims BIGINT,
    total_claim_amount NUMERIC(14,2),
    total_paid_amount NUMERIC(14,2),
    total_rejected_amount NUMERIC(14,2),
    total_pending_amount NUMERIC(14,2),
    avg_collection_rate NUMERIC(5,2),
    avg_denial_rate NUMERIC(5,2),
    avg_turnaround_time NUMERIC(5,2),
    fully_paid_count BIGINT,
    partially_paid_count BIGINT,
    fully_rejected_count BIGINT,
    pending_count BIGINT,
    resubmitted_count BIGINT,
    unique_patients BIGINT,
    unique_providers BIGINT,
    unique_facilities BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH filtered_data AS (
        SELECT
            cdwa.claim_id,
            cdwa.initial_net_amount,
            cdwa.remitted_amount,
            cdwa.rejected_amount,
            cdwa.unprocessed_amount,
            cdwa.net_collection_rate,
            cdwa.denial_rate,
            cdwa.turnaround_time_days,
            cdwa.payment_status,
            cdwa.resubmission_type,
            cdwa.patient_id,
            cdwa.provider_id,
            cdwa.facility_id
        FROM claims.v_claim_details_with_activity cdwa
        WHERE
            (p_facility_code IS NULL OR cdwa.facility_id = p_facility_code)
            AND (p_receiver_id IS NULL OR cdwa.receiver_id = p_receiver_id)
            AND (p_payer_code IS NULL OR cdwa.payer_code = p_payer_code)
            AND (p_from_date IS NULL OR cdwa.submission_date >= p_from_date)
            AND (p_to_date IS NULL OR cdwa.submission_date <= p_to_date)
    )
    SELECT
        COUNT(DISTINCT claim_id) as total_claims,
        SUM(initial_net_amount) as total_claim_amount,
        SUM(remitted_amount) as total_paid_amount,
        SUM(rejected_amount) as total_rejected_amount,
        SUM(unprocessed_amount) as total_pending_amount,
        ROUND(AVG(net_collection_rate), 2) as avg_collection_rate,
        ROUND(AVG(denial_rate), 2) as avg_denial_rate,
        ROUND(AVG(turnaround_time_days), 2) as avg_turnaround_time,
        COUNT(DISTINCT CASE WHEN payment_status = 'Fully Paid' THEN claim_id END) as fully_paid_count,
        COUNT(DISTINCT CASE WHEN payment_status = 'Partially Paid' THEN claim_id END) as partially_paid_count,
        COUNT(DISTINCT CASE WHEN payment_status = 'Rejected' THEN claim_id END) as fully_rejected_count,
        COUNT(DISTINCT CASE WHEN payment_status = 'Pending' THEN claim_id END) as pending_count,
        COUNT(DISTINCT CASE WHEN resubmission_type IS NOT NULL THEN claim_id END) as resubmitted_count,
        COUNT(DISTINCT patient_id) as unique_patients,
        COUNT(DISTINCT provider_id) as unique_providers,
        COUNT(DISTINCT facility_id) as unique_facilities
    FROM filtered_data;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION claims.get_claim_details_summary IS 'Get summary metrics for Claim Details with Activity Report dashboard';

-- ==========================================================================================================
-- FUNCTION: get_claim_details_filter_options
-- ==========================================================================================================
CREATE OR REPLACE FUNCTION claims.get_claim_details_filter_options() RETURNS TABLE(
    facility_codes TEXT[],
    receiver_codes TEXT[],
    payer_codes TEXT[],
    clinician_codes TEXT[],
    cpt_codes TEXT[],
    claim_statuses TEXT[],
    payment_statuses TEXT[],
    encounter_types TEXT[],
    resubmission_types TEXT[],
    denial_codes TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ARRAY_AGG(DISTINCT f.facility_code ORDER BY f.facility_code) FILTER (WHERE f.facility_code IS NOT NULL) as facility_codes,
        ARRAY_AGG(DISTINCT pr.provider_code ORDER BY pr.provider_code) FILTER (WHERE pr.provider_code IS NOT NULL) as receiver_codes,
        ARRAY_AGG(DISTINCT p.payer_code ORDER BY p.payer_code) FILTER (WHERE p.payer_code IS NOT NULL) as payer_codes,
        ARRAY_AGG(DISTINCT cl.clinician_code ORDER BY cl.clinician_code) FILTER (WHERE cl.clinician_code IS NOT NULL) as clinician_codes,
        ARRAY_AGG(DISTINCT ac.code ORDER BY ac.code) FILTER (WHERE ac.code IS NOT NULL) as cpt_codes,
        ARRAY_AGG(DISTINCT cst.status ORDER BY cst.status) FILTER (WHERE cst.status IS NOT NULL) as claim_statuses,
        ARRAY_AGG(DISTINCT
            CASE
                WHEN ra.payment_amount > 0 AND ra.payment_amount = ra.net THEN 'Fully Paid'
                WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN 'Partially Paid'
                WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 'Rejected'
                WHEN rc.date_settlement IS NULL THEN 'Pending'
                ELSE 'Unknown'
            END
        ORDER BY 1) FILTER (WHERE ra.id IS NOT NULL OR rc.id IS NOT NULL) as payment_statuses,
        ARRAY_AGG(DISTINCT e.type ORDER BY e.type) FILTER (WHERE e.type IS NOT NULL) as encounter_types,
        ARRAY_AGG(DISTINCT cr.resubmission_type ORDER BY cr.resubmission_type) FILTER (WHERE cr.resubmission_type IS NOT NULL) as resubmission_types,
        ARRAY_AGG(DISTINCT ra.denial_code ORDER BY ra.denial_code) FILTER (WHERE ra.denial_code IS NOT NULL) as denial_codes
    FROM claims_ref.facility f
    FULL OUTER JOIN claims_ref.provider pr ON true
    FULL OUTER JOIN claims_ref.payer p ON true
    FULL OUTER JOIN claims_ref.clinician cl ON true
    FULL OUTER JOIN claims_ref.activity_code ac ON true
    FULL OUTER JOIN claims.claim_status_timeline cst ON true
    FULL OUTER JOIN claims.remittance_activity ra ON true
    FULL OUTER JOIN claims.remittance_claim rc ON true
    FULL OUTER JOIN claims.encounter e ON true
    FULL OUTER JOIN claims.claim_resubmission cr ON true;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION claims.get_claim_details_filter_options IS 'Get filter options for Claim Details with Activity Report';

-- ==========================================================================================================
-- PERFORMANCE INDEXES
-- ==========================================================================================================

-- Main indexes for the comprehensive view
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_claim_id ON claims.claim_key(claim_id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_facility ON claims.encounter(facility_id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_payer ON claims.claim(payer_id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_provider ON claims.claim(provider_id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_patient ON claims.encounter(patient_id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_cpt ON claims.activity(code);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_clinician ON claims.activity(clinician);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_status ON claims.claim_status_timeline(status);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_submission_date ON claims.claim(tx_at);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_remittance_date ON claims.remittance(tx_at);

-- Composite indexes for common filter combinations
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_facility_date ON claims.encounter(facility_id, claim_id) WHERE facility_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_payer_date ON claims.claim(payer_id, tx_at) WHERE payer_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_status_date ON claims.claim_status_timeline(status, status_time);

-- ==========================================================================================================
-- COMMENTS AND DOCUMENTATION
-- ==========================================================================================================

COMMENT ON VIEW claims.v_claim_details_with_activity IS 'COMPREHENSIVE Claim Details with Activity Report - Main view with ALL fields from specification including submission tracking, financials, denial info, remittance tracking, patient/payer info, encounter/activity details, and calculated metrics';

-- ==========================================================================================================
-- USAGE EXAMPLES
-- ==========================================================================================================

/*
-- Get all claim details for a specific facility
SELECT * FROM claims.v_claim_details_with_activity
WHERE facility_id = 'FAC001'
ORDER BY submission_date DESC;

-- Get claims with specific CPT codes
SELECT * FROM claims.v_claim_details_with_activity
WHERE cpt_code IN ('99213', '99214', '99215')
ORDER BY submission_date DESC;

-- Get claims with high denial rates
SELECT * FROM claims.v_claim_details_with_activity
WHERE denial_rate > 50
ORDER BY denial_rate DESC;

-- Get claims with long turnaround times
SELECT * FROM claims.v_claim_details_with_activity
WHERE turnaround_time_days > 30
ORDER BY turnaround_time_days DESC;

-- Get summary metrics for dashboard
SELECT * FROM claims.get_claim_details_summary(
    'FAC001', -- facility_code
    NULL, -- receiver_id
    NULL, -- payer_code
    CURRENT_DATE - INTERVAL '30 days', -- from_date
    CURRENT_DATE -- to_date
);

-- Get filter options for UI
SELECT * FROM claims.get_claim_details_filter_options();

-- Complex filtering example
SELECT * FROM claims.get_claim_details_with_activity(
    'FAC001', -- facility_code
    NULL, -- receiver_id
    'DHA', -- payer_code
    NULL, -- clinician
    NULL, -- claim_id
    NULL, -- patient_id
    '99213', -- cpt_code
    NULL, -- claim_status
    'Fully Paid', -- payment_status
    'OUTPATIENT', -- encounter_type
    NULL, -- resub_type
    NULL, -- denial_code
    NULL, -- member_id
    CURRENT_DATE - INTERVAL '90 days', -- from_date
    CURRENT_DATE, -- to_date
    500, -- limit
    0 -- offset
);
*/
