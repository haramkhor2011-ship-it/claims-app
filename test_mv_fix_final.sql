-- ==========================================================================================================
-- FINAL TEST FOR mv_remittances_resubmission_activity_level FIX
-- ==========================================================================================================
-- 
-- Purpose: Test the completely rewritten materialized view to ensure no duplicates
-- ==========================================================================================================

-- Drop the existing view
DROP MATERIALIZED VIEW IF EXISTS claims.mv_remittances_resubmission_activity_level CASCADE;

-- Create the fixed view
CREATE MATERIALIZED VIEW claims.mv_remittances_resubmission_activity_level AS
WITH activity_financials AS (
    -- Calculate financial metrics per activity (SIMPLIFIED)
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
        MIN(ra.denial_code) as initial_denial_code,
        -- Additional calculated fields
        COUNT(CASE WHEN ra.payment_amount = a.net THEN 1 END) as fully_paid_count,
        SUM(CASE WHEN ra.payment_amount = a.net THEN ra.payment_amount ELSE 0::numeric END) as fully_paid_amount,
        COUNT(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 1 END) as fully_rejected_count,
        SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN a.net ELSE 0::numeric END) as fully_rejected_amount,
        COUNT(CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < a.net THEN 1 END) as partially_paid_count,
        SUM(CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < a.net THEN ra.payment_amount ELSE 0::numeric END) as partially_paid_amount,
        -- Self-pay detection
        COUNT(CASE WHEN c.payer_id = 'Self-Paid' THEN 1 END) as self_pay_count,
        SUM(CASE WHEN c.payer_id = 'Self-Paid' THEN a.net ELSE 0::numeric END) as self_pay_amount,
        -- Taken back amounts
        SUM(CASE WHEN ra.payment_amount < 0 THEN ABS(ra.payment_amount) ELSE 0::numeric END) as taken_back_amount,
        COUNT(CASE WHEN ra.payment_amount < 0 THEN 1 END) as taken_back_count
    FROM claims.activity a
    LEFT JOIN claims.claim c ON a.claim_id = c.id
    LEFT JOIN claims.remittance_activity ra ON a.activity_id = ra.activity_id
      AND ra.remittance_claim_id IN (
        SELECT id FROM claims.remittance_claim rc2 WHERE rc2.claim_key_id = c.claim_key_id
      )
    GROUP BY a.id, a.claim_id, a.activity_id, a.net, c.payer_id
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
),
resubmission_cycles_aggregated AS (
    -- Aggregate resubmission cycles to prevent duplicates
    SELECT 
        ce.claim_key_id,
        COUNT(*) as resubmission_count,
        MAX(ce.event_time) as last_resubmission_date,
        MIN(ce.event_time) as first_resubmission_date,
        -- Get first resubmission details
        (ARRAY_AGG(cr.resubmission_type ORDER BY ce.event_time))[1] as first_resubmission_type,
        (ARRAY_AGG(cr.comment ORDER BY ce.event_time))[1] as first_resubmission_comment,
        (ARRAY_AGG(ce.event_time ORDER BY ce.event_time))[1] as first_resubmission_date,
        -- Get second resubmission details
        (ARRAY_AGG(cr.resubmission_type ORDER BY ce.event_time))[2] as second_resubmission_type,
        (ARRAY_AGG(ce.event_time ORDER BY ce.event_time))[2] as second_resubmission_date,
        -- Get third resubmission details
        (ARRAY_AGG(cr.resubmission_type ORDER BY ce.event_time))[3] as third_resubmission_type,
        (ARRAY_AGG(ce.event_time ORDER BY ce.event_time))[3] as third_resubmission_date,
        -- Get fourth resubmission details
        (ARRAY_AGG(cr.resubmission_type ORDER BY ce.event_time))[4] as fourth_resubmission_type,
        (ARRAY_AGG(ce.event_time ORDER BY ce.event_time))[4] as fourth_resubmission_date,
        -- Get fifth resubmission details
        (ARRAY_AGG(cr.resubmission_type ORDER BY ce.event_time))[5] as fifth_resubmission_type,
        (ARRAY_AGG(ce.event_time ORDER BY ce.event_time))[5] as fifth_resubmission_date
    FROM claims.claim_event ce
    LEFT JOIN claims.claim_resubmission cr ON ce.id = cr.claim_event_id
    WHERE ce.type = 2  -- Resubmission events
    GROUP BY ce.claim_key_id
),
remittance_cycles_aggregated AS (
    -- Aggregate remittance cycles to prevent duplicates
    SELECT 
        rc.claim_key_id,
        COUNT(*) as remittance_count,
        MAX(r.tx_at) as last_remittance_date,
        MIN(r.tx_at) as first_remittance_date,
        -- Get first remittance details
        (ARRAY_AGG(r.tx_at ORDER BY r.tx_at))[1] as first_ra_date,
        (ARRAY_AGG(ra.payment_amount ORDER BY r.tx_at))[1] as first_ra_amount,
        -- Get second remittance details
        (ARRAY_AGG(r.tx_at ORDER BY r.tx_at))[2] as second_ra_date,
        (ARRAY_AGG(ra.payment_amount ORDER BY r.tx_at))[2] as second_ra_amount,
        -- Get third remittance details
        (ARRAY_AGG(r.tx_at ORDER BY r.tx_at))[3] as third_ra_date,
        (ARRAY_AGG(ra.payment_amount ORDER BY r.tx_at))[3] as third_ra_amount,
        -- Get fourth remittance details
        (ARRAY_AGG(r.tx_at ORDER BY r.tx_at))[4] as fourth_ra_date,
        (ARRAY_AGG(ra.payment_amount ORDER BY r.tx_at))[4] as fourth_ra_amount,
        -- Get fifth remittance details
        (ARRAY_AGG(r.tx_at ORDER BY r.tx_at))[5] as fifth_ra_date,
        (ARRAY_AGG(ra.payment_amount ORDER BY r.tx_at))[5] as fifth_ra_amount
    FROM claims.remittance_claim rc
    JOIN claims.remittance r ON rc.remittance_id = r.id
    JOIN claims.remittance_activity ra ON rc.id = ra.remittance_claim_id
    GROUP BY rc.claim_key_id
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
    
    -- Financial metrics
    af.submitted_amount,
    af.total_paid,
    af.total_remitted,
    af.rejected_amount,
    af.initial_denial_code,
    af.latest_denial_code,
    
    -- Additional financial fields
    af.submitted_amount AS billed_amount,
    af.total_paid AS paid_amount,
    af.total_paid AS remitted_amount,
    af.total_paid AS payment_amount,
    af.rejected_amount AS outstanding_balance,
    af.rejected_amount AS pending_amount,
    af.rejected_amount AS pending_remittance_amount,
    
    -- Resubmission tracking (aggregated)
    rca.first_resubmission_type,
    rca.first_resubmission_comment,
    rca.first_resubmission_date,
    rca.second_resubmission_type,
    rca.second_resubmission_date,
    rca.third_resubmission_type,
    rca.third_resubmission_date,
    rca.fourth_resubmission_type,
    rca.fourth_resubmission_date,
    rca.fifth_resubmission_type,
    rca.fifth_resubmission_date,
    
    -- Remittance tracking (aggregated)
    rma.first_ra_date,
    rma.first_ra_amount,
    rma.second_ra_date,
    rma.second_ra_amount,
    rma.third_ra_date,
    rma.third_ra_amount,
    rma.fourth_ra_date,
    rma.fourth_ra_amount,
    rma.fifth_ra_date,
    rma.fifth_ra_amount,
    
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
    
    -- Additional fields
    c.id_payer,
    a.prior_authorization_id,
    -- Derived fields
    EXTRACT(MONTH FROM c.tx_at) AS claim_month,
    EXTRACT(YEAR FROM c.tx_at) AS claim_year,
    LEAST(100::numeric,
         GREATEST(0::numeric,
             (af.total_paid / NULLIF(af.submitted_amount, 0)) * 100
         )
    ) AS collection_rate,
    -- Additional calculated fields
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
LEFT JOIN resubmission_cycles_aggregated rca ON ck.id = rca.claim_key_id
LEFT JOIN remittance_cycles_aggregated rma ON ck.id = rma.claim_key_id
LEFT JOIN claims.diagnosis d1 ON c.id = d1.claim_id AND d1.diag_type = 'Principal'
LEFT JOIN claims.diagnosis d2 ON c.id = d2.claim_id AND d2.diag_type = 'Secondary';

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

-- Test refresh (should not fail)
REFRESH MATERIALIZED VIEW claims.mv_remittances_resubmission_activity_level;

-- Final verification
SELECT 'SUCCESS' as status, 
       'mv_remittances_resubmission_activity_level created without duplicate key violations' as message;
