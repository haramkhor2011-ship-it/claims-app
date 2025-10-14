-- ==========================================================================================================
-- TEST SCRIPT FOR MATERIALIZED VIEW FIXES
-- ==========================================================================================================
-- 
-- Purpose: Test the fixed materialized views to ensure they work correctly
-- Run this after applying the fixes to verify no duplicate key violations
-- ==========================================================================================================

-- ==========================================================================================================
-- STEP 1: Test mv_remittances_resubmission_activity_level (CRITICAL FIX)
-- ==========================================================================================================

-- Drop and recreate the fixed view
DROP MATERIALIZED VIEW IF EXISTS claims.mv_remittances_resubmission_activity_level CASCADE;

-- The fixed view definition (copy from sub_second_materialized_views.sql)
CREATE MATERIALIZED VIEW claims.mv_remittances_resubmission_activity_level AS
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
    -- Calculate financial metrics per activity (FIXED)
    SELECT 
        a.id as activity_internal_id,
        a.claim_id,
        a.activity_id,
        a.net::numeric as submitted_amount,
        COALESCE(SUM(ra.payment_amount), 0::numeric) as total_paid,
        COALESCE(SUM(ra.net), 0::numeric) as total_remitted,
        -- FIXED: Enhanced calculation with proper bounds checking
        CASE
            WHEN a.net > COALESCE(SUM(ra.payment_amount), 0::numeric) THEN a.net - COALESCE(SUM(ra.payment_amount), 0::numeric)
            ELSE 0::numeric
        END as rejected_amount,
        COUNT(DISTINCT ra.remittance_claim_id) as remittance_count,
        MAX(ra.denial_code) as latest_denial_code,
        MIN(ra.denial_code) as initial_denial_code,
        -- Additional calculated fields from JSON mapping
        COUNT(CASE WHEN ra.payment_amount = a.net THEN 1 END) as fully_paid_count,
        SUM(CASE WHEN ra.payment_amount = a.net THEN ra.payment_amount ELSE 0::numeric END) as fully_paid_amount,
        COUNT(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN 1 END) as fully_rejected_count,
        SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN a.net ELSE 0::numeric END) as fully_rejected_amount,
        COUNT(CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < a.net THEN 1 END) as partially_paid_count,
        SUM(CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < a.net THEN ra.payment_amount ELSE 0::numeric END) as partially_paid_amount,
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
    c.id_payer,
    a.prior_authorization_id,
    -- REMOVED: rc.payment_reference, rc.date_settlement (caused duplicates)
    -- These fields are available in remittance_cycles CTE if needed
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
LEFT JOIN claims.diagnosis d2 ON c.id = d2.claim_id AND d2.diag_type = 'Secondary';
-- REMOVED: LEFT JOIN claims.remittance_claim rc ON ck.id = rc.claim_key_id;
-- This JOIN was causing duplicates - remittance data is already aggregated in activity_financials CTE

-- Create the unique index
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_remittances_resubmission_unique 
ON claims.mv_remittances_resubmission_activity_level(claim_key_id, activity_id);

-- ==========================================================================================================
-- STEP 2: Test the fixed view
-- ==========================================================================================================

-- Check row count
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

-- ==========================================================================================================
-- STEP 3: Test other fixed views
-- ==========================================================================================================

-- Test payerwise view
SELECT 'mv_claim_summary_payerwise' as view_name, COUNT(*) as row_count 
FROM claims.mv_claim_summary_payerwise;

-- Test encounterwise view  
SELECT 'mv_claim_summary_encounterwise' as view_name, COUNT(*) as row_count 
FROM claims.mv_claim_summary_encounterwise;

-- ==========================================================================================================
-- STEP 4: Summary
-- ==========================================================================================================

SELECT 'TEST COMPLETED' as status, 
       'All fixed materialized views should now work without duplicate key violations' as message;
