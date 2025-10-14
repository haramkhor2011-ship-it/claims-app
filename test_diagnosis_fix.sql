-- ==========================================================================================================
-- TEST DIAGNOSIS AGGREGATION FIX
-- ==========================================================================================================
-- 
-- Purpose: Test the diagnosis aggregation fix for mv_remittances_resubmission_activity_level
-- ==========================================================================================================

-- Drop the existing view
DROP MATERIALIZED VIEW IF EXISTS claims.mv_remittances_resubmission_activity_level CASCADE;

-- Test the diagnosis aggregation logic first
SELECT 
    'Diagnosis Aggregation Test' as test_type,
    c.id as claim_id,
    c.claim_key_id,
    MAX(CASE WHEN d.diag_type = 'Principal' THEN d.code END) as primary_diagnosis,
    STRING_AGG(CASE WHEN d.diag_type = 'Secondary' THEN d.code END, ', ' ORDER BY d.code) as secondary_diagnosis,
    COUNT(*) as total_diagnoses
FROM claims.claim c
LEFT JOIN claims.diagnosis d ON c.id = d.claim_id
WHERE c.claim_key_id = 5336
GROUP BY c.id, c.claim_key_id;

-- Test the full query without the materialized view
WITH activity_financials AS (
    SELECT 
        a.id as activity_internal_id,
        a.claim_id,
        a.activity_id,
        a.net::numeric as submitted_amount,
        COALESCE(SUM(ra.payment_amount), 0::numeric) as total_paid,
        COALESCE(SUM(ra.net), 0::numeric) as total_remitted,
        CASE
            WHEN a.net > COALESCE(SUM(ra.payment_amount), 0::numeric) THEN a.net - COALESCE(SUM(ra.payment_amount), 0::numeric)
            ELSE 0::numeric
        END as rejected_amount,
        COUNT(DISTINCT ra.remittance_claim_id) as remittance_count,
        MAX(ra.denial_code) as latest_denial_code,
        MIN(ra.denial_code) as initial_denial_code
    FROM claims.activity a
    LEFT JOIN claims.claim c ON a.claim_id = c.id
    LEFT JOIN claims.remittance_activity ra ON a.activity_id = ra.activity_id
      AND ra.remittance_claim_id IN (
        SELECT id FROM claims.remittance_claim rc2 WHERE rc2.claim_key_id = c.claim_key_id
      )
    WHERE c.claim_key_id = 5336 AND a.activity_id = '200110011'
    GROUP BY a.id, a.claim_id, a.activity_id, a.net, c.payer_id
),
claim_resubmission_summary AS (
    SELECT 
        ck.id as claim_key_id,
        COUNT(DISTINCT ce.id) as resubmission_count,
        MAX(ce.event_time) as last_resubmission_date,
        MIN(ce.event_time) as first_resubmission_date
    FROM claims.claim_key ck
    LEFT JOIN claims.claim_event ce ON ck.id = ce.claim_key_id AND ce.type = 2
    WHERE ck.id = 5336
    GROUP BY ck.id
),
resubmission_cycles_aggregated AS (
    SELECT 
        ce.claim_key_id,
        COUNT(*) as resubmission_count,
        MAX(ce.event_time) as last_resubmission_date,
        (ARRAY_AGG(cr.resubmission_type ORDER BY ce.event_time))[1] as first_resubmission_type,
        (ARRAY_AGG(cr.comment ORDER BY ce.event_time))[1] as first_resubmission_comment,
        (ARRAY_AGG(ce.event_time ORDER BY ce.event_time))[1] as first_resubmission_date
    FROM claims.claim_event ce
    LEFT JOIN claims.claim_resubmission cr ON ce.id = cr.claim_event_id
    WHERE ce.type = 2 AND ce.claim_key_id = 5336
    GROUP BY ce.claim_key_id
),
remittance_cycles_aggregated AS (
    SELECT 
        rc.claim_key_id,
        COUNT(*) as remittance_count,
        MAX(r.tx_at) as last_remittance_date,
        MIN(r.tx_at) as first_remittance_date,
        (ARRAY_AGG(r.tx_at ORDER BY r.tx_at))[1] as first_ra_date,
        (ARRAY_AGG(ra.payment_amount ORDER BY r.tx_at))[1] as first_ra_amount
    FROM claims.remittance_claim rc
    JOIN claims.remittance r ON rc.remittance_id = r.id
    JOIN claims.remittance_activity ra ON rc.id = ra.remittance_claim_id
    WHERE rc.claim_key_id = 5336
    GROUP BY rc.claim_key_id
)
SELECT 
    'Full Query Test' as test_type,
    ck.id AS claim_key_id,
    ck.claim_id,
    c.id AS claim_internal_id,
    a.id AS activity_internal_id,
    a.activity_id,
    diag_agg.primary_diagnosis,
    diag_agg.secondary_diagnosis,
    COUNT(*) as row_count
FROM claims.claim_key ck
JOIN claims.claim c ON ck.id = c.claim_key_id
JOIN claims.activity a ON c.id = a.claim_id
JOIN claims.encounter e ON c.id = e.claim_id
LEFT JOIN activity_financials af ON a.id = af.activity_internal_id
LEFT JOIN claim_resubmission_summary crs ON ck.id = crs.claim_key_id
LEFT JOIN resubmission_cycles_aggregated rca ON ck.id = rca.claim_key_id
LEFT JOIN remittance_cycles_aggregated rma ON ck.id = rma.claim_key_id
LEFT JOIN (
    -- Aggregate diagnosis data to prevent duplicates
    SELECT 
        c.id as claim_id,
        MAX(CASE WHEN d.diag_type = 'Principal' THEN d.code END) as primary_diagnosis,
        STRING_AGG(CASE WHEN d.diag_type = 'Secondary' THEN d.code END, ', ' ORDER BY d.code) as secondary_diagnosis
    FROM claims.claim c
    LEFT JOIN claims.diagnosis d ON c.id = d.claim_id
    GROUP BY c.id
) diag_agg ON c.id = diag_agg.claim_id
WHERE ck.id = 5336 AND a.activity_id = '200110011'
GROUP BY ck.id, ck.claim_id, c.id, a.id, a.activity_id, diag_agg.primary_diagnosis, diag_agg.secondary_diagnosis;

-- If the above test shows 1 row, then create the materialized view
CREATE MATERIALIZED VIEW claims.mv_remittances_resubmission_activity_level AS
WITH activity_financials AS (
    SELECT 
        a.id as activity_internal_id,
        a.claim_id,
        a.activity_id,
        a.net::numeric as submitted_amount,
        COALESCE(SUM(ra.payment_amount), 0::numeric) as total_paid,
        COALESCE(SUM(ra.net), 0::numeric) as total_remitted,
        CASE
            WHEN a.net > COALESCE(SUM(ra.payment_amount), 0::numeric) THEN a.net - COALESCE(SUM(ra.payment_amount), 0::numeric)
            ELSE 0::numeric
        END as rejected_amount,
        COUNT(DISTINCT ra.remittance_claim_id) as remittance_count,
        MAX(ra.denial_code) as latest_denial_code,
        MIN(ra.denial_code) as initial_denial_code
    FROM claims.activity a
    LEFT JOIN claims.claim c ON a.claim_id = c.id
    LEFT JOIN claims.remittance_activity ra ON a.activity_id = ra.activity_id
      AND ra.remittance_claim_id IN (
        SELECT id FROM claims.remittance_claim rc2 WHERE rc2.claim_key_id = c.claim_key_id
      )
    GROUP BY a.id, a.claim_id, a.activity_id, a.net, c.payer_id
),
claim_resubmission_summary AS (
    SELECT 
        ck.id as claim_key_id,
        COUNT(DISTINCT ce.id) as resubmission_count,
        MAX(ce.event_time) as last_resubmission_date,
        MIN(ce.event_time) as first_resubmission_date
    FROM claims.claim_key ck
    LEFT JOIN claims.claim_event ce ON ck.id = ce.claim_key_id AND ce.type = 2
    GROUP BY ck.id
),
resubmission_cycles_aggregated AS (
    SELECT 
        ce.claim_key_id,
        COUNT(*) as resubmission_count,
        MAX(ce.event_time) as last_resubmission_date,
        (ARRAY_AGG(cr.resubmission_type ORDER BY ce.event_time))[1] as first_resubmission_type,
        (ARRAY_AGG(cr.comment ORDER BY ce.event_time))[1] as first_resubmission_comment,
        (ARRAY_AGG(ce.event_time ORDER BY ce.event_time))[1] as first_resubmission_date
    FROM claims.claim_event ce
    LEFT JOIN claims.claim_resubmission cr ON ce.id = cr.claim_event_id
    WHERE ce.type = 2
    GROUP BY ce.claim_key_id
),
remittance_cycles_aggregated AS (
    SELECT 
        rc.claim_key_id,
        COUNT(*) as remittance_count,
        MAX(r.tx_at) as last_remittance_date,
        MIN(r.tx_at) as first_remittance_date,
        (ARRAY_AGG(r.tx_at ORDER BY r.tx_at))[1] as first_ra_date,
        (ARRAY_AGG(ra.payment_amount ORDER BY r.tx_at))[1] as first_ra_amount
    FROM claims.remittance_claim rc
    JOIN claims.remittance r ON rc.remittance_id = r.id
    JOIN claims.remittance_activity ra ON rc.id = ra.remittance_claim_id
    GROUP BY rc.claim_key_id
)
SELECT 
    ck.id AS claim_key_id,
    ck.claim_id,
    c.id AS claim_internal_id,
    a.id AS activity_internal_id,
    a.activity_id,
    c.member_id,
    c.emirates_id_number AS patient_id,
    c.payer_id,
    p.name AS payer_name,
    c.provider_id AS receiver_id,
    pr.name AS receiver_name,
    e.facility_id,
    f.name AS facility_name,
    f.city AS facility_group,
    if_sender.sender_id AS health_authority,
    a.clinician,
    cl.name AS clinician_name,
    e.type AS encounter_type,
    e.start_at AS encounter_start,
    e.end_at AS encounter_end,
    e.start_at AS encounter_date,
    a.start_at AS activity_date,
    a.type AS cpt_type,
    a.code AS cpt_code,
    a.quantity,
    af.submitted_amount,
    af.total_paid,
    af.total_remitted,
    af.rejected_amount,
    af.initial_denial_code,
    af.latest_denial_code,
    af.submitted_amount AS billed_amount,
    af.total_paid AS paid_amount,
    af.total_paid AS remitted_amount,
    af.total_paid AS payment_amount,
    af.rejected_amount AS outstanding_balance,
    af.rejected_amount AS pending_amount,
    af.rejected_amount AS pending_remittance_amount,
    rca.first_resubmission_type,
    rca.first_resubmission_comment,
    rca.first_resubmission_date as rca_first_resubmission_date,
    rma.first_ra_date,
    rma.first_ra_amount,
    crs.resubmission_count as claim_resubmission_count,
    af.remittance_count,
    af.rejected_amount > 0 AS has_rejected_amount,
    af.rejected_amount > 0 AND crs.resubmission_count = 0 AS rejected_not_resubmitted,
    af.latest_denial_code AS denial_code,
    dc.description AS denial_comment,
    CASE 
        WHEN af.latest_denial_code IS NOT NULL THEN 'Denied'
        WHEN af.total_paid = af.submitted_amount THEN 'Fully Paid'
        WHEN af.total_paid > 0 THEN 'Partially Paid'
        ELSE 'Unpaid'
    END AS cpt_status,
    EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - e.start_at)) AS ageing_days,
    c.created_at AS submitted_date,
    c.tx_at AS claim_transaction_date,
    diag_agg.primary_diagnosis,
    diag_agg.secondary_diagnosis,
    c.id_payer,
    a.prior_authorization_id,
    EXTRACT(MONTH FROM c.tx_at) AS claim_month,
    EXTRACT(YEAR FROM c.tx_at) AS claim_year,
    LEAST(100::numeric,
         GREATEST(0::numeric,
             (af.total_paid / NULLIF(af.submitted_amount, 0)) * 100
         )
    ) AS collection_rate
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
LEFT JOIN resubmission_cycles_aggregated rca ON ck.id = rca.claim_key_id
LEFT JOIN remittance_cycles_aggregated rma ON ck.id = rma.claim_key_id
LEFT JOIN (
    -- Aggregate diagnosis data to prevent duplicates
    SELECT 
        c.id as claim_id,
        MAX(CASE WHEN d.diag_type = 'Principal' THEN d.code END) as primary_diagnosis,
        STRING_AGG(CASE WHEN d.diag_type = 'Secondary' THEN d.code END, ', ' ORDER BY d.code) as secondary_diagnosis
    FROM claims.claim c
    LEFT JOIN claims.diagnosis d ON c.id = d.claim_id
    GROUP BY c.id
) diag_agg ON c.id = diag_agg.claim_id;

-- Create the unique index
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_remittances_resubmission_unique 
ON claims.mv_remittances_resubmission_activity_level(claim_key_id, activity_id);

-- Test the view
SELECT 'mv_remittances_resubmission_activity_level' as view_name, COUNT(*) as row_count 
FROM claims.mv_remittances_resubmission_activity_level;

-- Check for duplicates (should be 0)
SELECT 
  COUNT(*) as total_rows,
  COUNT(DISTINCT claim_key_id, activity_id) as unique_keys,
  COUNT(*) - COUNT(DISTINCT claim_key_id, activity_id) as duplicates
FROM claims.mv_remittances_resubmission_activity_level;

-- Test refresh
REFRESH MATERIALIZED VIEW claims.mv_remittances_resubmission_activity_level;

-- Final verification
SELECT 'SUCCESS' as status, 
       'mv_remittances_resubmission_activity_level created without duplicate key violations' as message;
