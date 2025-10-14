-- ==========================================================================================================
-- DIAGNOSTIC QUERY FOR DUPLICATE KEY VIOLATION
-- ==========================================================================================================
-- 
-- Purpose: Identify the exact source of duplicates in mv_remittances_resubmission_activity_level
-- Target: Key (claim_key_id, activity_id)=(5336, 200110011) is duplicated
-- ==========================================================================================================

-- Check the specific claim and activity that's causing duplicates
SELECT 
    'Base Data Check' as check_type,
    ck.id as claim_key_id,
    ck.claim_id,
    a.activity_id,
    COUNT(*) as row_count
FROM claims.claim_key ck
JOIN claims.claim c ON ck.id = c.claim_key_id
JOIN claims.activity a ON c.id = a.claim_id
WHERE ck.id = 5336 AND a.activity_id = '200110011'
GROUP BY ck.id, ck.claim_id, a.activity_id;

-- Check resubmission cycles for this claim
SELECT 
    'Resubmission Cycles' as check_type,
    ce.claim_key_id,
    ce.type,
    ce.event_time,
    ROW_NUMBER() OVER (PARTITION BY ce.claim_key_id ORDER BY ce.event_time) as cycle_number
FROM claims.claim_event ce
WHERE ce.claim_key_id = 5336 AND ce.type IN (1, 2)
ORDER BY ce.event_time;

-- Check remittance cycles for this claim
SELECT 
    'Remittance Cycles' as check_type,
    rc.claim_key_id,
    ra.activity_id,
    r.tx_at as remittance_date,
    ROW_NUMBER() OVER (PARTITION BY rc.claim_key_id ORDER BY r.tx_at) as cycle_number
FROM claims.remittance_claim rc
JOIN claims.remittance r ON rc.remittance_id = r.id
JOIN claims.remittance_activity ra ON rc.id = ra.remittance_claim_id
WHERE rc.claim_key_id = 5336 AND ra.activity_id = '200110011'
ORDER BY r.tx_at;

-- Check diagnosis data for this claim
SELECT 
    'Diagnosis Data' as check_type,
    d.claim_id,
    d.diag_type,
    d.code,
    COUNT(*) as diagnosis_count
FROM claims.diagnosis d
JOIN claims.claim c ON d.claim_id = c.id
WHERE c.claim_key_id = 5336
GROUP BY d.claim_id, d.diag_type, d.code;

-- Check if there are multiple encounters for this claim
SELECT 
    'Encounter Data' as check_type,
    e.claim_id,
    e.id as encounter_id,
    e.facility_id,
    COUNT(*) as encounter_count
FROM claims.encounter e
JOIN claims.claim c ON e.claim_id = c.id
WHERE c.claim_key_id = 5336
GROUP BY e.claim_id, e.id, e.facility_id;

-- Check activity_financials CTE output for this activity
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
)
SELECT 
    'Activity Financials' as check_type,
    af.activity_internal_id,
    af.claim_id,
    af.activity_id,
    af.submitted_amount,
    af.total_paid,
    af.remittance_count
FROM activity_financials af;

-- Check the full query result for this specific claim/activity combination
WITH claim_cycles AS (
  SELECT 
    claim_key_id,
    type,
    event_time,
    ROW_NUMBER() OVER (PARTITION BY claim_key_id ORDER BY event_time) as cycle_number
  FROM claims.claim_event
  WHERE type IN (1, 2) AND claim_key_id = 5336
),
resubmission_cycles AS (
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
    WHERE ce.type = 2 AND ce.claim_key_id = 5336
),
remittance_cycles AS (
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
    WHERE rc.claim_key_id = 5336 AND ra.activity_id = '200110011'
),
activity_financials AS (
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
)
SELECT 
    'Full Query Result' as check_type,
    ck.id AS claim_key_id,
    ck.claim_id,
    c.id AS claim_internal_id,
    a.id AS activity_internal_id,
    a.activity_id,
    -- Count the number of resubmission cycles
    (SELECT COUNT(*) FROM resubmission_cycles WHERE claim_key_id = 5336) as resubmission_cycle_count,
    -- Count the number of remittance cycles
    (SELECT COUNT(*) FROM remittance_cycles WHERE claim_key_id = 5336 AND activity_id = '200110011') as remittance_cycle_count,
    -- Check if there are multiple diagnoses
    (SELECT COUNT(*) FROM claims.diagnosis d JOIN claims.claim c2 ON d.claim_id = c2.id WHERE c2.claim_key_id = 5336) as diagnosis_count,
    -- Check if there are multiple encounters
    (SELECT COUNT(*) FROM claims.encounter e JOIN claims.claim c3 ON e.claim_id = c3.id WHERE c3.claim_key_id = 5336) as encounter_count
FROM claims.claim_key ck
JOIN claims.claim c ON ck.id = c.claim_key_id
JOIN claims.activity a ON c.id = a.claim_id
JOIN claims.encounter e ON c.id = e.claim_id
LEFT JOIN activity_financials af ON a.id = af.activity_internal_id
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
WHERE ck.id = 5336 AND a.activity_id = '200110011';
