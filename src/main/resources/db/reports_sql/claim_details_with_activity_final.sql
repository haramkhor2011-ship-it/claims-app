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

-- ==========================================================================================================
-- Report Overview
-- ==========================================================================================================
-- Business purpose
-- - One-stop, row-wise view of claim + encounter + activities + remittance + status + resubmission.
-- - Filtered accessors (get_claim_details_with_activity), summary KPIs (get_claim_details_summary), and filters.
--
-- Core joins
-- - ck → c (claim_key → claim)
-- - c → s (submission), e (encounter), a (activity), cst (latest status), if_submission/if_remittance
-- - rc → r (remittance_claim → remittance), ra (remittance_activity) via claim_key_id and rc.id
-- - Resubmission via claim_event(type=2) → claim_resubmission
-- - Reference: f (encounter.facility_ref_id), py (claim.payer_ref_id), cl (activity.clinician_ref_id), ac (activity.code)
-- - Diagnosis: principal/secondary per claim
--
-- Derived fields
-- - payment_status via CASE (paid/partially/rejected/pending).
-- - remitted_amount/settled_amount = COALESCE(ra.payment_amount, 0)
-- - rejected_amount = CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0
-- - unprocessed_amount = CASE WHEN rc.date_settlement IS NULL THEN c.net ELSE 0
-- - net_collection_rate = (ra.payment_amount / c.net) * 100  (guard zero)
-- - denial_rate = (rejected_amount / c.net) * 100  (guard zero)
-- - turnaround_time_days = EXTRACT(DAYS FROM (r.tx_at - e.start_at))
-- - resubmission_effectiveness = (ra.payment_amount / rejected_amount) * 100 when applicable

-- ==========================================================================================================
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
    rc.payer_ref_id as remittance_payer_ref_id,
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
    a.clinician_ref_id as clinician_ref_id,
    cl.name as clinician_name,
    ac.description as activity_description,
    a.activity_code_ref_id as activity_code_ref_id,

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

    -- Financial Calculations (CUMULATIVE-WITH-CAP: Using pre-computed activity summary)
    COALESCE(cas.paid_amount, 0) as remitted_amount,                    -- capped paid across remittances
    COALESCE(cas.paid_amount, 0) as settled_amount,                    -- same as remitted for this report
    COALESCE(cas.rejected_amount, 0) as rejected_amount,               -- rejected only when latest denial and zero paid
    COALESCE(cas.submitted_amount, 0) - COALESCE(cas.paid_amount, 0) - COALESCE(cas.denied_amount, 0) as unprocessed_amount,  -- remaining after paid/denied
    COALESCE(cas.denied_amount, 0) as initial_rejected_amount,         -- denied amount from latest denial logic

    -- Denial Information (CUMULATIVE-WITH-CAP: Using latest denial from activity summary)
    (cas.denial_codes)[1] as last_denial_code,  -- first element of denial codes array (latest)
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
        WHEN (COALESCE(ra.payment_amount, 0) + (CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)) > 0 THEN
            ROUND(
                ((CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END)
                 /
                 (COALESCE(ra.payment_amount, 0) + (CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN ra.net ELSE 0 END))) * 100, 2)
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
LEFT JOIN claims_ref.facility f ON f.id = e.facility_ref_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
LEFT JOIN claims.claim_status_timeline cst ON cst.claim_key_id = ck.id
    AND cst.id = (
        SELECT cst2.id
        FROM claims.claim_status_timeline cst2
        WHERE cst2.claim_key_id = ck.id
        ORDER BY cst2.status_time DESC, cst2.id DESC
        LIMIT 1
    )
LEFT JOIN claims.claim_event ce_resub ON ce_resub.claim_key_id = ck.id AND ce_resub.type = 2
LEFT JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce_resub.id
LEFT JOIN claims_ref.provider pr ON pr.id = c.provider_ref_id
LEFT JOIN claims_ref.payer py ON py.id = c.payer_ref_id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims_ref.clinician cl ON cl.id = a.clinician_ref_id
LEFT JOIN claims_ref.activity_code ac ON ac.id = a.activity_code_ref_id
-- CUMULATIVE-WITH-CAP: Join to pre-computed activity summary for accurate financial calculations
LEFT JOIN claims.claim_activity_summary cas ON cas.claim_key_id = ck.id AND cas.activity_id = a.activity_id
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
    p_use_mv BOOLEAN DEFAULT FALSE,
    p_tab_name TEXT DEFAULT 'details',
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
    p_payer_ref_id BIGINT DEFAULT NULL,
    p_provider_ref_id BIGINT DEFAULT NULL,
    p_facility_ref_id BIGINT DEFAULT NULL,
    p_clinician_ref_id BIGINT DEFAULT NULL,
    p_activity_code_ref_id BIGINT DEFAULT NULL,
    p_denial_code_ref_id BIGINT DEFAULT NULL,
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
    -- OPTION 3: Hybrid approach with DB toggle and tab selection
    -- WHY: Allows switching between traditional views and MVs with tab-specific logic
    -- HOW: Uses p_use_mv parameter to choose data source and p_tab_name for tab selection
    
    IF p_use_mv THEN
        -- Use MVs for sub-second performance
        CASE p_tab_name
            WHEN 'details' THEN
                RETURN QUERY
                SELECT
                    mv.claim_id,
                    mv.claim_db_id,
                    mv.payer_id,
                    mv.provider_id,
                    mv.member_id,
                    mv.emirates_id_number,
                    mv.gross,
                    mv.patient_share,
                    mv.initial_net_amount,
                    mv.comments,
                    mv.submission_date,
                    mv.provider_name,
                    mv.receiver_id,
                    mv.payer_name,
                    mv.payer_code,
                    mv.facility_id,
                    mv.encounter_type,
                    mv.patient_id,
        mv.encounter_start,
        mv.encounter_end_date,
        mv.facility_name,
        mv.facility_group,
        mv.submission_id,
        mv.submission_transaction_date,
        mv.remittance_claim_id,
        mv.id_payer,
        mv.payment_reference,
        mv.initial_date_settlement,
        mv.initial_denial_code,
        mv.remittance_date,
        mv.remittance_id,
        mv.claim_activity_number,
        mv.activity_start_date,
        mv.activity_type,
        mv.cpt_code,
        mv.quantity,
        mv.activity_net_amount,
        mv.clinician,
        mv.prior_authorization_id,
        mv.clinician_name,
        mv.activity_description,
        mv.primary_diagnosis,
        mv.secondary_diagnosis,
        mv.last_submission_file,
        mv.last_submission_transaction_date,
        mv.last_remittance_file,
        mv.last_remittance_transaction_date,
        mv.claim_status,
        mv.claim_status_time,
        mv.payment_status,
        mv.remitted_amount,
        mv.settled_amount,
        mv.rejected_amount,
        mv.unprocessed_amount,
        mv.initial_rejected_amount,
        mv.last_denial_code,
        mv.remittance_comments,
        mv.denial_comment,
        mv.resubmission_type,
        mv.resubmission_comment,
        mv.net_collection_rate,
        mv.denial_rate,
        mv.turnaround_time_days,
        mv.resubmission_effectiveness,
        mv.created_at,
        mv.updated_at
    FROM claims.mv_claim_details_complete mv
    WHERE
        (p_facility_code IS NULL OR mv.facility_id = p_facility_code)
        AND (p_receiver_id IS NULL OR mv.receiver_id = p_receiver_id)
        AND (p_payer_code IS NULL OR mv.payer_code = p_payer_code)
        AND (p_clinician IS NULL OR mv.clinician = p_clinician)
        AND (p_claim_id IS NULL OR mv.claim_id = p_claim_id)
        AND (p_patient_id IS NULL OR mv.patient_id = p_patient_id)
        AND (p_cpt_code IS NULL OR mv.cpt_code = p_cpt_code)
        AND (p_claim_status IS NULL OR mv.claim_status = p_claim_status)
        AND (p_payment_status IS NULL OR mv.payment_status = p_payment_status)
        AND (p_encounter_type IS NULL OR mv.encounter_type = p_encounter_type)
        AND (p_resub_type IS NULL OR mv.resubmission_type = p_resub_type)
        AND (p_denial_code IS NULL OR mv.last_denial_code = p_denial_code)
        AND (p_member_id IS NULL OR mv.member_id = p_member_id)
        AND (p_payer_ref_id IS NULL OR mv.payer_ref_id = p_payer_ref_id)
        AND (p_provider_ref_id IS NULL OR mv.provider_ref_id = p_provider_ref_id OR mv.remittance_provider_ref_id = p_provider_ref_id)
        AND (p_facility_ref_id IS NULL OR mv.facility_ref_id = p_facility_ref_id)
        AND (p_clinician_ref_id IS NULL OR mv.clinician_ref_id = p_clinician_ref_id)
        AND (p_activity_code_ref_id IS NULL OR mv.activity_code_ref_id = p_activity_code_ref_id)
        AND (p_denial_code_ref_id IS NULL OR mv.denial_code_ref_id = p_denial_code_ref_id)
        AND (p_from_date IS NULL OR mv.submission_date >= p_from_date)
        AND (p_to_date IS NULL OR mv.submission_date <= p_to_date)
    ORDER BY mv.submission_date DESC, mv.claim_id
    LIMIT p_limit OFFSET p_offset;
            ELSE
                -- Default to details
                RETURN QUERY
                SELECT
                    mv.claim_id,
                    mv.claim_db_id,
                    mv.payer_id,
                    mv.provider_id,
                    mv.member_id,
                    mv.emirates_id_number,
                    mv.gross,
                    mv.patient_share,
                    mv.initial_net_amount,
                    mv.comments,
                    mv.submission_date,
                    mv.provider_name,
                    mv.receiver_id,
                    mv.payer_name,
                    mv.payer_code,
                    mv.facility_id,
                    mv.encounter_type,
                    mv.patient_id,
                    mv.encounter_start,
                    mv.encounter_end_date,
                    mv.facility_name,
                    mv.facility_group,
                    mv.submission_id,
                    mv.submission_transaction_date,
                    mv.remittance_claim_id,
                    mv.id_payer,
                    mv.payment_reference,
                    mv.initial_date_settlement,
                    mv.initial_denial_code,
                    mv.remittance_date,
                    mv.remittance_id,
                    mv.claim_activity_number,
                    mv.activity_start_date,
                    mv.activity_type,
                    mv.cpt_code,
                    mv.quantity,
                    mv.activity_net_amount,
                    mv.clinician,
                    mv.prior_authorization_id,
                    mv.clinician_name,
                    mv.activity_description,
                    mv.primary_diagnosis,
                    mv.secondary_diagnosis,
                    mv.last_submission_file,
                    mv.last_submission_transaction_date,
                    mv.last_remittance_file,
                    mv.last_remittance_transaction_date,
                    mv.claim_status,
                    mv.claim_status_time,
                    mv.payment_status,
                    mv.remitted_amount,
                    mv.settled_amount,
                    mv.rejected_amount,
                    mv.unprocessed_amount,
                    mv.initial_rejected_amount,
                    mv.last_denial_code,
                    mv.remittance_comments,
                    mv.denial_comment,
                    mv.resubmission_type,
                    mv.resubmission_comment,
                    mv.net_collection_rate,
                    mv.denial_rate,
                    mv.turnaround_time_days,
                    mv.resubmission_effectiveness,
                    mv.created_at,
                    mv.updated_at
                FROM claims.mv_claim_details_complete mv
                WHERE
                    (p_facility_code IS NULL OR mv.facility_id = p_facility_code)
                    AND (p_receiver_id IS NULL OR mv.receiver_id = p_receiver_id)
                    AND (p_payer_code IS NULL OR mv.payer_code = p_payer_code)
                    AND (p_clinician IS NULL OR mv.clinician = p_clinician)
                    AND (p_claim_id IS NULL OR mv.claim_id = p_claim_id)
                    AND (p_patient_id IS NULL OR mv.patient_id = p_patient_id)
                    AND (p_cpt_code IS NULL OR mv.cpt_code = p_cpt_code)
                    AND (p_claim_status IS NULL OR mv.claim_status = p_claim_status)
                    AND (p_payment_status IS NULL OR mv.payment_status = p_payment_status)
                    AND (p_encounter_type IS NULL OR mv.encounter_type = p_encounter_type)
                    AND (p_resub_type IS NULL OR mv.resubmission_type = p_resub_type)
                    AND (p_denial_code IS NULL OR mv.last_denial_code = p_denial_code)
                    AND (p_member_id IS NULL OR mv.member_id = p_member_id)
                    AND (p_payer_ref_id IS NULL OR mv.payer_ref_id = p_payer_ref_id)
                    AND (p_provider_ref_id IS NULL OR mv.provider_ref_id = p_provider_ref_id OR mv.remittance_provider_ref_id = p_provider_ref_id)
                    AND (p_facility_ref_id IS NULL OR mv.facility_ref_id = p_facility_ref_id)
                    AND (p_clinician_ref_id IS NULL OR mv.clinician_ref_id = p_clinician_ref_id)
                    AND (p_activity_code_ref_id IS NULL OR mv.activity_code_ref_id = p_activity_code_ref_id)
                    AND (p_denial_code_ref_id IS NULL OR mv.denial_code_ref_id = p_denial_code_ref_id)
                    AND (p_from_date IS NULL OR mv.submission_date >= p_from_date)
                    AND (p_to_date IS NULL OR mv.submission_date <= p_to_date)
                ORDER BY mv.submission_date DESC, mv.claim_id
                LIMIT p_limit OFFSET p_offset;
        END CASE;
    ELSE
        -- Use traditional views for real-time data
        CASE p_tab_name
            WHEN 'details' THEN
                RETURN QUERY
                SELECT
                    cda.claim_id,
                    cda.claim_db_id,
                    cda.payer_id,
                    cda.provider_id,
                    cda.member_id,
                    cda.emirates_id_number,
                    cda.gross,
                    cda.patient_share,
                    cda.initial_net_amount,
                    cda.comments,
                    cda.submission_date,
                    cda.provider_name,
                    cda.receiver_id,
                    cda.payer_name,
                    cda.payer_code,
                    cda.facility_id,
                    cda.encounter_type,
                    cda.patient_id,
                    cda.encounter_start,
                    cda.encounter_end_date,
                    cda.facility_name,
                    cda.facility_group,
                    cda.submission_id,
                    cda.submission_transaction_date,
                    cda.remittance_claim_id,
                    cda.id_payer,
                    cda.payment_reference,
                    cda.initial_date_settlement,
                    cda.initial_denial_code,
                    cda.remittance_date,
                    cda.remittance_id,
                    cda.claim_activity_number,
                    cda.activity_start_date,
                    cda.activity_type,
                    cda.cpt_code,
                    cda.quantity,
                    cda.activity_net_amount,
                    cda.clinician,
                    cda.prior_authorization_id,
                    cda.clinician_name,
                    cda.activity_description,
                    cda.primary_diagnosis,
                    cda.secondary_diagnosis,
                    cda.last_submission_file,
                    cda.last_submission_transaction_date,
                    cda.last_remittance_file,
                    cda.last_remittance_transaction_date,
                    cda.claim_status,
                    cda.claim_status_time,
                    cda.payment_status,
                    cda.remitted_amount,
                    cda.settled_amount,
                    cda.rejected_amount,
                    cda.unprocessed_amount,
                    cda.initial_rejected_amount,
                    cda.last_denial_code,
                    cda.remittance_comments,
                    cda.denial_comment,
                    cda.resubmission_type,
                    cda.resubmission_comment,
                    cda.net_collection_rate,
                    cda.denial_rate,
                    cda.turnaround_time_days,
                    cda.resubmission_effectiveness,
                    cda.created_at,
                    cda.updated_at
                FROM claims.v_claim_details_with_activity cda
                WHERE
                    (p_facility_code IS NULL OR cda.facility_id = p_facility_code)
                    AND (p_receiver_id IS NULL OR cda.receiver_id = p_receiver_id)
                    AND (p_payer_code IS NULL OR cda.payer_code = p_payer_code)
                    AND (p_clinician IS NULL OR cda.clinician = p_clinician)
                    AND (p_claim_id IS NULL OR cda.claim_id = p_claim_id)
                    AND (p_patient_id IS NULL OR cda.patient_id = p_patient_id)
                    AND (p_cpt_code IS NULL OR cda.cpt_code = p_cpt_code)
                    AND (p_claim_status IS NULL OR cda.claim_status = p_claim_status)
                    AND (p_payment_status IS NULL OR cda.payment_status = p_payment_status)
                    AND (p_encounter_type IS NULL OR cda.encounter_type = p_encounter_type)
                    AND (p_resub_type IS NULL OR cda.resubmission_type = p_resub_type)
                    AND (p_denial_code IS NULL OR cda.last_denial_code = p_denial_code)
                    AND (p_member_id IS NULL OR cda.member_id = p_member_id)
                    AND (p_payer_ref_id IS NULL OR cda.payer_ref_id = p_payer_ref_id)
                    AND (p_provider_ref_id IS NULL OR cda.provider_ref_id = p_provider_ref_id OR cda.remittance_provider_ref_id = p_provider_ref_id)
                    AND (p_facility_ref_id IS NULL OR cda.facility_ref_id = p_facility_ref_id)
                    AND (p_clinician_ref_id IS NULL OR cda.clinician_ref_id = p_clinician_ref_id)
                    AND (p_activity_code_ref_id IS NULL OR cda.activity_code_ref_id = p_activity_code_ref_id)
                    AND (p_denial_code_ref_id IS NULL OR cda.denial_code_ref_id = p_denial_code_ref_id)
                    AND (p_from_date IS NULL OR cda.submission_date >= p_from_date)
                    AND (p_to_date IS NULL OR cda.submission_date <= p_to_date)
                ORDER BY cda.submission_date DESC, cda.claim_id
                LIMIT p_limit OFFSET p_offset;
            ELSE
                -- Default to details
                RETURN QUERY
                SELECT
                    cda.claim_id,
                    cda.claim_db_id,
                    cda.payer_id,
                    cda.provider_id,
                    cda.member_id,
                    cda.emirates_id_number,
                    cda.gross,
                    cda.patient_share,
                    cda.initial_net_amount,
                    cda.comments,
                    cda.submission_date,
                    cda.provider_name,
                    cda.receiver_id,
                    cda.payer_name,
                    cda.payer_code,
                    cda.facility_id,
                    cda.encounter_type,
                    cda.patient_id,
                    cda.encounter_start,
                    cda.encounter_end_date,
                    cda.facility_name,
                    cda.facility_group,
                    cda.submission_id,
                    cda.submission_transaction_date,
                    cda.remittance_claim_id,
                    cda.id_payer,
                    cda.payment_reference,
                    cda.initial_date_settlement,
                    cda.initial_denial_code,
                    cda.remittance_date,
                    cda.remittance_id,
                    cda.claim_activity_number,
                    cda.activity_start_date,
                    cda.activity_type,
                    cda.cpt_code,
                    cda.quantity,
                    cda.activity_net_amount,
                    cda.clinician,
                    cda.prior_authorization_id,
                    cda.clinician_name,
                    cda.activity_description,
                    cda.primary_diagnosis,
                    cda.secondary_diagnosis,
                    cda.last_submission_file,
                    cda.last_submission_transaction_date,
                    cda.last_remittance_file,
                    cda.last_remittance_transaction_date,
                    cda.claim_status,
                    cda.claim_status_time,
                    cda.payment_status,
                    cda.remitted_amount,
                    cda.settled_amount,
                    cda.rejected_amount,
                    cda.unprocessed_amount,
                    cda.initial_rejected_amount,
                    cda.last_denial_code,
                    cda.remittance_comments,
                    cda.denial_comment,
                    cda.resubmission_type,
                    cda.resubmission_comment,
                    cda.net_collection_rate,
                    cda.denial_rate,
                    cda.turnaround_time_days,
                    cda.resubmission_effectiveness,
                    cda.created_at,
                    cda.updated_at
                FROM claims.v_claim_details_with_activity cda
                WHERE
                    (p_facility_code IS NULL OR cda.facility_id = p_facility_code)
                    AND (p_receiver_id IS NULL OR cda.receiver_id = p_receiver_id)
                    AND (p_payer_code IS NULL OR cda.payer_code = p_payer_code)
                    AND (p_clinician IS NULL OR cda.clinician = p_clinician)
                    AND (p_claim_id IS NULL OR cda.claim_id = p_claim_id)
                    AND (p_patient_id IS NULL OR cda.patient_id = p_patient_id)
                    AND (p_cpt_code IS NULL OR cda.cpt_code = p_cpt_code)
                    AND (p_claim_status IS NULL OR cda.claim_status = p_claim_status)
                    AND (p_payment_status IS NULL OR cda.payment_status = p_payment_status)
                    AND (p_encounter_type IS NULL OR cda.encounter_type = p_encounter_type)
                    AND (p_resub_type IS NULL OR cda.resubmission_type = p_resub_type)
                    AND (p_denial_code IS NULL OR cda.last_denial_code = p_denial_code)
                    AND (p_member_id IS NULL OR cda.member_id = p_member_id)
                    AND (p_payer_ref_id IS NULL OR cda.payer_ref_id = p_payer_ref_id)
                    AND (p_provider_ref_id IS NULL OR cda.provider_ref_id = p_provider_ref_id OR cda.remittance_provider_ref_id = p_provider_ref_id)
                    AND (p_facility_ref_id IS NULL OR cda.facility_ref_id = p_facility_ref_id)
                    AND (p_clinician_ref_id IS NULL OR cda.clinician_ref_id = p_clinician_ref_id)
                    AND (p_activity_code_ref_id IS NULL OR cda.activity_code_ref_id = p_activity_code_ref_id)
                    AND (p_denial_code_ref_id IS NULL OR cda.denial_code_ref_id = p_denial_code_ref_id)
                    AND (p_from_date IS NULL OR cda.submission_date >= p_from_date)
                    AND (p_to_date IS NULL OR cda.submission_date <= p_to_date)
                ORDER BY cda.submission_date DESC, cda.claim_id
                LIMIT p_limit OFFSET p_offset;
        END CASE;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION claims.get_claim_details_with_activity IS 'Get filtered claim details with activity data for comprehensive reporting';

-- ==========================================================================================================
-- FUNCTION: get_claim_details_summary (Dashboard metrics)
-- ==========================================================================================================
CREATE OR REPLACE FUNCTION claims.get_claim_details_summary(
    p_use_mv BOOLEAN DEFAULT FALSE,
    p_tab_name TEXT DEFAULT 'summary',
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
    -- OPTION 3: Hybrid approach with DB toggle and tab selection
    -- WHY: Allows switching between traditional views and MVs with tab-specific logic
    -- HOW: Uses p_use_mv parameter to choose data source and p_tab_name for tab selection
    
    IF p_use_mv THEN
        -- Use MVs for sub-second performance
        CASE p_tab_name
            WHEN 'summary' THEN
                RETURN QUERY
                WITH filtered_data AS (
                    SELECT
                        mv.claim_id,
                        mv.initial_net_amount,
                        mv.remitted_amount,
                        mv.rejected_amount,
                        mv.unprocessed_amount,
                        mv.net_collection_rate,
                        mv.denial_rate,
                        mv.turnaround_time_days,
                        mv.payment_status,
                        mv.resubmission_type,
                        mv.patient_id,
                        mv.provider_id,
                        mv.facility_id
                    FROM claims.mv_claim_details_complete mv
                    WHERE
                        (p_facility_code IS NULL OR mv.facility_id = p_facility_code)
                        AND (p_receiver_id IS NULL OR mv.receiver_id = p_receiver_id)
                        AND (p_payer_code IS NULL OR mv.payer_code = p_payer_code)
                        AND (p_from_date IS NULL OR mv.submission_date >= p_from_date)
                        AND (p_to_date IS NULL OR mv.submission_date <= p_to_date)
                ),
    claim_level AS (
        SELECT
            claim_id,
            MAX(initial_net_amount) AS initial_net_amount,
            MAX(unprocessed_amount) AS unprocessed_amount
        FROM filtered_data
        GROUP BY claim_id
    )
    SELECT
        COUNT(DISTINCT claim_id) as total_claims,
        (SELECT SUM(initial_net_amount) FROM claim_level) as total_claim_amount,
        SUM(remitted_amount) as total_paid_amount,
        SUM(rejected_amount) as total_rejected_amount,
        (SELECT SUM(unprocessed_amount) FROM claim_level) as total_pending_amount,
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
            ELSE
                -- Default to summary
                RETURN QUERY
                WITH filtered_data AS (
                    SELECT
                        cda.claim_id,
                        cda.initial_net_amount,
                        cda.remitted_amount,
                        cda.rejected_amount,
                        cda.unprocessed_amount,
                        cda.net_collection_rate,
                        cda.denial_rate,
                        cda.turnaround_time_days,
                        cda.payment_status,
                        cda.resubmission_type,
                        cda.patient_id,
                        cda.provider_id,
                        cda.facility_id
                    FROM claims.v_claim_details_with_activity cda
                    WHERE
                        (p_facility_code IS NULL OR cda.facility_id = p_facility_code)
                        AND (p_receiver_id IS NULL OR cda.receiver_id = p_receiver_id)
                        AND (p_payer_code IS NULL OR cda.payer_code = p_payer_code)
                        AND (p_from_date IS NULL OR cda.submission_date >= p_from_date)
                        AND (p_to_date IS NULL OR cda.submission_date <= p_to_date)
                ),
    claim_level AS (
        SELECT
            claim_id,
            MAX(initial_net_amount) AS initial_net_amount,
            MAX(unprocessed_amount) AS unprocessed_amount
        FROM filtered_data
        GROUP BY claim_id
    )
    SELECT
        COUNT(DISTINCT claim_id) as total_claims,
        (SELECT SUM(initial_net_amount) FROM claim_level) as total_claim_amount,
        SUM(remitted_amount) as total_paid_amount,
        SUM(rejected_amount) as total_rejected_amount,
        (SELECT SUM(unprocessed_amount) FROM claim_level) as total_pending_amount,
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
        END CASE;
    ELSE
        -- Use traditional views for real-time data
        CASE p_tab_name
            WHEN 'summary' THEN
                RETURN QUERY
                WITH filtered_data AS (
                    SELECT
                        cda.claim_id,
                        cda.initial_net_amount,
                        cda.remitted_amount,
                        cda.rejected_amount,
                        cda.unprocessed_amount,
                        cda.net_collection_rate,
                        cda.denial_rate,
                        cda.turnaround_time_days,
                        cda.payment_status,
                        cda.resubmission_type,
                        cda.patient_id,
                        cda.provider_id,
                        cda.facility_id
                    FROM claims.v_claim_details_with_activity cda
                    WHERE
                        (p_facility_code IS NULL OR cda.facility_id = p_facility_code)
                        AND (p_receiver_id IS NULL OR cda.receiver_id = p_receiver_id)
                        AND (p_payer_code IS NULL OR cda.payer_code = p_payer_code)
                        AND (p_from_date IS NULL OR cda.submission_date >= p_from_date)
                        AND (p_to_date IS NULL OR cda.submission_date <= p_to_date)
                ),
    claim_level AS (
        SELECT
            claim_id,
            MAX(initial_net_amount) AS initial_net_amount,
            MAX(unprocessed_amount) AS unprocessed_amount
        FROM filtered_data
        GROUP BY claim_id
    )
    SELECT
        COUNT(DISTINCT claim_id) as total_claims,
        (SELECT SUM(initial_net_amount) FROM claim_level) as total_claim_amount,
        SUM(remitted_amount) as total_paid_amount,
        SUM(rejected_amount) as total_rejected_amount,
        (SELECT SUM(unprocessed_amount) FROM claim_level) as total_pending_amount,
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
            ELSE
                -- Default to summary
                RETURN QUERY
                WITH filtered_data AS (
                    SELECT
                        cda.claim_id,
                        cda.initial_net_amount,
                        cda.remitted_amount,
                        cda.rejected_amount,
                        cda.unprocessed_amount,
                        cda.net_collection_rate,
                        cda.denial_rate,
                        cda.turnaround_time_days,
                        cda.payment_status,
                        cda.resubmission_type,
                        cda.patient_id,
                        cda.provider_id,
                        cda.facility_id
                    FROM claims.v_claim_details_with_activity cda
                    WHERE
                        (p_facility_code IS NULL OR cda.facility_id = p_facility_code)
                        AND (p_receiver_id IS NULL OR cda.receiver_id = p_receiver_id)
                        AND (p_payer_code IS NULL OR cda.payer_code = p_payer_code)
                        AND (p_from_date IS NULL OR cda.submission_date >= p_from_date)
                        AND (p_to_date IS NULL OR cda.submission_date <= p_to_date)
                ),
    claim_level AS (
        SELECT
            claim_id,
            MAX(initial_net_amount) AS initial_net_amount,
            MAX(unprocessed_amount) AS unprocessed_amount
        FROM filtered_data
        GROUP BY claim_id
    )
    SELECT
        COUNT(DISTINCT claim_id) as total_claims,
        (SELECT SUM(initial_net_amount) FROM claim_level) as total_claim_amount,
        SUM(remitted_amount) as total_paid_amount,
        SUM(rejected_amount) as total_rejected_amount,
        (SELECT SUM(unprocessed_amount) FROM claim_level) as total_pending_amount,
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
        END CASE;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION claims.get_claim_details_summary IS 'Get summary metrics for Claim Details with Activity Report dashboard';

-- ==========================================================================================================
-- FUNCTION: get_claim_details_filter_options
-- ==========================================================================================================
CREATE OR REPLACE FUNCTION claims.get_claim_details_filter_options(
    p_use_mv BOOLEAN DEFAULT FALSE,
    p_tab_name TEXT DEFAULT 'options'
) RETURNS TABLE(
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
    -- OPTION 3: Hybrid approach with DB toggle and tab selection
    -- WHY: Allows switching between traditional views and MVs with tab-specific logic
    -- HOW: Uses p_use_mv parameter to choose data source and p_tab_name for tab selection
    
    IF p_use_mv THEN
        -- Use MVs for sub-second performance
        CASE p_tab_name
            WHEN 'options' THEN
                RETURN QUERY
                SELECT
                    ARRAY_AGG(DISTINCT mv.facility_id ORDER BY mv.facility_id) FILTER (WHERE mv.facility_id IS NOT NULL) as facility_codes,
                    ARRAY_AGG(DISTINCT mv.receiver_id ORDER BY mv.receiver_id) FILTER (WHERE mv.receiver_id IS NOT NULL) as receiver_codes,
                    ARRAY_AGG(DISTINCT mv.payer_id ORDER BY mv.payer_id) FILTER (WHERE mv.payer_id IS NOT NULL) as payer_codes,
                    ARRAY_AGG(DISTINCT mv.clinician ORDER BY mv.clinician) FILTER (WHERE mv.clinician IS NOT NULL) as clinician_codes,
                    ARRAY_AGG(DISTINCT mv.cpt_code ORDER BY mv.cpt_code) FILTER (WHERE mv.cpt_code IS NOT NULL) as cpt_codes,
                    ARRAY_AGG(DISTINCT mv.claim_status ORDER BY mv.claim_status) FILTER (WHERE mv.claim_status IS NOT NULL) as claim_statuses,
                    ARRAY_AGG(DISTINCT mv.payment_status ORDER BY mv.payment_status) FILTER (WHERE mv.payment_status IS NOT NULL) as payment_statuses,
                    ARRAY_AGG(DISTINCT mv.encounter_type ORDER BY mv.encounter_type) FILTER (WHERE mv.encounter_type IS NOT NULL) as encounter_types,
                    ARRAY_AGG(DISTINCT mv.resubmission_type ORDER BY mv.resubmission_type) FILTER (WHERE mv.resubmission_type IS NOT NULL) as resubmission_types,
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
            ELSE
                -- Default to options
                RETURN QUERY
                SELECT
                    ARRAY_AGG(DISTINCT cda.facility_id ORDER BY cda.facility_id) FILTER (WHERE cda.facility_id IS NOT NULL) as facility_codes,
                    ARRAY_AGG(DISTINCT cda.receiver_id ORDER BY cda.receiver_id) FILTER (WHERE cda.receiver_id IS NOT NULL) as receiver_codes,
                    ARRAY_AGG(DISTINCT cda.payer_id ORDER BY cda.payer_id) FILTER (WHERE cda.payer_id IS NOT NULL) as payer_codes,
                    ARRAY_AGG(DISTINCT cda.clinician ORDER BY cda.clinician) FILTER (WHERE cda.clinician IS NOT NULL) as clinician_codes,
                    ARRAY_AGG(DISTINCT cda.cpt_code ORDER BY cda.cpt_code) FILTER (WHERE cda.cpt_code IS NOT NULL) as cpt_codes,
                    ARRAY_AGG(DISTINCT cda.claim_status ORDER BY cda.claim_status) FILTER (WHERE cda.claim_status IS NOT NULL) as claim_statuses,
                    ARRAY_AGG(DISTINCT cda.payment_status ORDER BY cda.payment_status) FILTER (WHERE cda.payment_status IS NOT NULL) as payment_statuses,
                    ARRAY_AGG(DISTINCT cda.encounter_type ORDER BY cda.encounter_type) FILTER (WHERE cda.encounter_type IS NOT NULL) as encounter_types,
                    ARRAY_AGG(DISTINCT cda.resubmission_type ORDER BY cda.resubmission_type) FILTER (WHERE cda.resubmission_type IS NOT NULL) as resubmission_types,
                    ARRAY_AGG(DISTINCT cda.last_denial_code ORDER BY cda.last_denial_code) FILTER (WHERE cda.last_denial_code IS NOT NULL) as denial_codes
                FROM claims.v_claim_details_with_activity cda;
        END CASE;
    ELSE
        -- Use traditional views for real-time data
        CASE p_tab_name
            WHEN 'options' THEN
                RETURN QUERY
                SELECT
                    ARRAY_AGG(DISTINCT cda.facility_id ORDER BY cda.facility_id) FILTER (WHERE cda.facility_id IS NOT NULL) as facility_codes,
                    ARRAY_AGG(DISTINCT cda.receiver_id ORDER BY cda.receiver_id) FILTER (WHERE cda.receiver_id IS NOT NULL) as receiver_codes,
                    ARRAY_AGG(DISTINCT cda.payer_id ORDER BY cda.payer_id) FILTER (WHERE cda.payer_id IS NOT NULL) as payer_codes,
                    ARRAY_AGG(DISTINCT cda.clinician ORDER BY cda.clinician) FILTER (WHERE cda.clinician IS NOT NULL) as clinician_codes,
                    ARRAY_AGG(DISTINCT cda.cpt_code ORDER BY cda.cpt_code) FILTER (WHERE cda.cpt_code IS NOT NULL) as cpt_codes,
                    ARRAY_AGG(DISTINCT cda.claim_status ORDER BY cda.claim_status) FILTER (WHERE cda.claim_status IS NOT NULL) as claim_statuses,
                    ARRAY_AGG(DISTINCT cda.payment_status ORDER BY cda.payment_status) FILTER (WHERE cda.payment_status IS NOT NULL) as payment_statuses,
                    ARRAY_AGG(DISTINCT cda.encounter_type ORDER BY cda.encounter_type) FILTER (WHERE cda.encounter_type IS NOT NULL) as encounter_types,
                    ARRAY_AGG(DISTINCT cda.resubmission_type ORDER BY cda.resubmission_type) FILTER (WHERE cda.resubmission_type IS NOT NULL) as resubmission_types,
                    ARRAY_AGG(DISTINCT cda.last_denial_code ORDER BY cda.last_denial_code) FILTER (WHERE cda.last_denial_code IS NOT NULL) as denial_codes
                FROM claims.v_claim_details_with_activity cda;
            ELSE
                -- Default to options
                RETURN QUERY
                SELECT
                    ARRAY_AGG(DISTINCT cda.facility_id ORDER BY cda.facility_id) FILTER (WHERE cda.facility_id IS NOT NULL) as facility_codes,
                    ARRAY_AGG(DISTINCT cda.receiver_id ORDER BY cda.receiver_id) FILTER (WHERE cda.receiver_id IS NOT NULL) as receiver_codes,
                    ARRAY_AGG(DISTINCT cda.payer_id ORDER BY cda.payer_id) FILTER (WHERE cda.payer_id IS NOT NULL) as payer_codes,
                    ARRAY_AGG(DISTINCT cda.clinician ORDER BY cda.clinician) FILTER (WHERE cda.clinician IS NOT NULL) as clinician_codes,
                    ARRAY_AGG(DISTINCT cda.cpt_code ORDER BY cda.cpt_code) FILTER (WHERE cda.cpt_code IS NOT NULL) as cpt_codes,
                    ARRAY_AGG(DISTINCT cda.claim_status ORDER BY cda.claim_status) FILTER (WHERE cda.claim_status IS NOT NULL) as claim_statuses,
                    ARRAY_AGG(DISTINCT cda.payment_status ORDER BY cda.payment_status) FILTER (WHERE cda.payment_status IS NOT NULL) as payment_statuses,
                    ARRAY_AGG(DISTINCT cda.encounter_type ORDER BY cda.encounter_type) FILTER (WHERE cda.encounter_type IS NOT NULL) as encounter_types,
                    ARRAY_AGG(DISTINCT cda.resubmission_type ORDER BY cda.resubmission_type) FILTER (WHERE cda.resubmission_type IS NOT NULL) as resubmission_types,
                    ARRAY_AGG(DISTINCT cda.last_denial_code ORDER BY cda.last_denial_code) FILTER (WHERE cda.last_denial_code IS NOT NULL) as denial_codes
                FROM claims.v_claim_details_with_activity cda;
        END CASE;
    END IF;
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
    NULL, -- payer_ref_id
    NULL, -- provider_ref_id
    NULL, -- facility_ref_id
    NULL, -- clinician_ref_id
    NULL, -- activity_code_ref_id
    NULL, -- denial_code_ref_id
    CURRENT_DATE - INTERVAL '90 days', -- from_date
    CURRENT_DATE, -- to_date
    500, -- limit
    0 -- offset
);
*/

-- =====================================================
-- GRANTS
-- =====================================================
GRANT SELECT ON claims.v_claim_details_with_activity TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_claim_details_with_activity(boolean,text,text,text,text,text,text,text,text,text,text,text,text,text,text,bigint,bigint,bigint,bigint,bigint,bigint,timestamptz,timestamptz,integer,integer) TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_claim_details_summary(boolean,text,text,text,text,timestamptz,timestamptz) TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_claim_details_filter_options(boolean,text) TO claims_user;
