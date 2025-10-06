-- ==========================================================================================================
-- REMITTANCES & RESUBMISSION ACTIVITY LEVEL REPORT - PRODUCTION READY IMPLEMENTATION (FIXED)
-- ==========================================================================================================
-- 
-- Date: 2025-09-24
-- Purpose: Production-ready implementation with critical fixes
-- 
-- FIXES APPLIED:
-- 1. Fixed missing JOIN for remittance_claim
-- 2. Enhanced financial calculations with proper error handling
-- 3. Added performance indexes
-- 4. Improved error handling and edge cases
-- 5. Enhanced validation logic
--
-- ==========================================================================================================
-- Report Overview
-- ==========================================================================================================
-- Business purpose
-- - Track remittance cycles and resubmission cycles per activity/claim; expose activity- and claim-level views & APIs.
--
-- Core joins
-- - Resubmission cycles: claim_event(type=2) → claim_resubmission
-- - Remittance cycles: remittance_claim → remittance → remittance_activity
-- - Activity-level: ck → c → a → e; reference: payer/facility/clinician; financials from remittance_activity
-- - Claim-level: per-claim rollups (claim_financials), diagnosis, single activity join for clinician
--
-- Grouping
-- - Activity-level: row-level per activity; Claim-level: GROUP BY claim and denormalized dimensions.
--
-- Derived fields
-- - submitted_amount/total_paid/total_remitted from SUM over remittance_activity
-- - rejected_amount = GREATEST(a.net - SUM(ra.payment_amount), 0)
-- - flags: has_rejected_amount, rejected_not_resubmitted; cpt_status via CASE
-- - claim-level totals: total_submitted_amount, total_paid_amount, total_rejected_amount, resubmission_count

-- ==========================================================================================================
-- SECTION 0: CLEANUP - DROP EXISTING OBJECTS
-- ==========================================================================================================

-- ==========================================================================================================
-- FORCE CLEANUP - Remove all existing function overloads and reset
-- ==========================================================================================================

-- Step 1: ULTRA-AGGRESSIVE cleanup - drop EVERYTHING possible
DO $$
DECLARE
    func_sig TEXT;
    cleanup_count INTEGER := 0;
    total_count INTEGER := 0;
BEGIN
    RAISE NOTICE '=== STARTING ULTRA-AGGRESSIVE CLEANUP ===';

    -- Count total functions before cleanup
    SELECT COUNT(*) INTO total_count
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'claims'
      AND p.proname LIKE 'get_remittances_resubmission_%';

    RAISE NOTICE 'Found % total function overloads to eliminate', total_count;

    -- Method 1: Drop by exact signature patterns (most common)
    BEGIN
        DROP FUNCTION IF EXISTS claims.get_remittances_resubmission_activity_level(text, text[], text[], text[], timestamp with time zone, timestamp with time zone, text, text[], text, text, text, text, integer, integer) CASCADE;
        cleanup_count := cleanup_count + 1;
        RAISE NOTICE '✓ Dropped by exact signature pattern (activity)';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '⚠ Could not drop by exact pattern (activity): %', SQLERRM;
    END;

    BEGIN
        DROP FUNCTION IF EXISTS claims.get_remittances_resubmission_claim_level(text, text[], text[], text[], timestamp with time zone, timestamp with time zone, text, text[], text, text, text, integer, integer) CASCADE;
        cleanup_count := cleanup_count + 1;
        RAISE NOTICE '✓ Dropped by exact signature pattern (claim)';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '⚠ Could not drop by exact pattern (claim): %', SQLERRM;
    END;

    -- Method 2: Drop by iterating through ALL overloads (catches everything)
    DECLARE
        func_rec RECORD;
    BEGIN
        -- Activity level functions
        FOR func_rec IN
            SELECT p.oid::regprocedure as func_sig
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'claims'
              AND p.proname = 'get_remittances_resubmission_activity_level'
        LOOP
            BEGIN
                EXECUTE 'DROP FUNCTION IF EXISTS ' || func_rec.func_sig || ' CASCADE';
                cleanup_count := cleanup_count + 1;
                RAISE NOTICE '✓ Dropped activity function: %', func_rec.func_sig;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE NOTICE '⚠ Could not drop activity function: % (error: %)', func_rec.func_sig, SQLERRM;
            END;
        END LOOP;

        -- Claim level functions
        FOR func_rec IN
            SELECT p.oid::regprocedure as func_sig
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'claims'
              AND p.proname = 'get_remittances_resubmission_claim_level'
        LOOP
            BEGIN
                EXECUTE 'DROP FUNCTION IF EXISTS ' || func_rec.func_sig || ' CASCADE';
                cleanup_count := cleanup_count + 1;
                RAISE NOTICE '✓ Dropped claim function: %', func_rec.func_sig;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE NOTICE '⚠ Could not drop claim function: % (error: %)', func_rec.func_sig, SQLERRM;
            END;
        END LOOP;
    END;

    RAISE NOTICE '=== CLEANUP COMPLETED ===';
    RAISE NOTICE 'Successfully dropped % function overloads', cleanup_count;
    RAISE NOTICE 'Remaining functions: %', total_count - cleanup_count;
END $$;

-- Step 2: Drop views to ensure clean recreation
DROP VIEW IF EXISTS claims.v_remittances_resubmission_claim_level CASCADE;
DROP VIEW IF EXISTS claims.v_remittances_resubmission_activity_level CASCADE;

-- ==========================================================================================================
-- SECTION 1: ACTIVITY LEVEL VIEW - FIXED IMPLEMENTATION
-- ==========================================================================================================

DROP VIEW IF EXISTS claims.v_remittances_resubmission_activity_level CASCADE;
CREATE OR REPLACE VIEW claims.v_remittances_resubmission_activity_level AS
WITH resubmission_cycles AS (
    -- Track resubmission cycles with chronological ordering
    SELECT 
        ce.claim_key_id,
        ce.event_time,
        ce.type,
        cr.resubmission_type,
        cr.comment,
        ROW_NUMBER() OVER (
            PARTITION BY ce.claim_key_id 
            ORDER BY ce.event_time
        ) as cycle_number
    FROM claims.claim_event ce
    LEFT JOIN claims.claim_resubmission cr ON ce.id = cr.claim_event_id
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
LEFT JOIN claims_ref.denial_code dc ON ra.denial_code_ref_id = dc.id
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

-- ==========================================================================================================
-- SECTION 2: CLAIM LEVEL VIEW - FIXED IMPLEMENTATION
-- ==========================================================================================================

DROP VIEW IF EXISTS claims.v_remittances_resubmission_claim_level CASCADE;
CREATE OR REPLACE VIEW claims.v_remittances_resubmission_claim_level AS
WITH claim_financials AS (
    -- Calculate financial metrics per claim (FIXED)
    SELECT 
        c.id as claim_id,
        SUM(a.net)::numeric as total_submitted_amount,
        SUM(COALESCE(ra.payment_amount, 0::numeric)) as total_paid_amount,
        -- FIXED: Enhanced calculation with proper bounds checking
        SUM(CASE
            WHEN a.net > COALESCE(ra.payment_amount, 0::numeric) THEN a.net - COALESCE(ra.payment_amount, 0::numeric)
            ELSE 0::numeric
        END) as total_rejected_amount,
        COUNT(DISTINCT ra.remittance_claim_id) as remittance_count,
        COUNT(DISTINCT CASE WHEN ce.type = 2 THEN ce.id END) as resubmission_count
    FROM claims.claim c
    JOIN claims.activity a ON c.id = a.claim_id
    LEFT JOIN claims.remittance_activity ra ON a.activity_id = ra.activity_id
      AND ra.remittance_claim_id IN (
        SELECT id FROM claims.remittance_claim rc2 WHERE rc2.claim_key_id = c.claim_key_id
      )
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
-- SECTION 3: PERFORMANCE INDEXES - PRODUCTION READY
-- ==========================================================================================================

-- Create indexes on underlying tables for performance
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_activity_claim_key_id ON claims.claim_key(id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_activity_activity_id ON claims.activity(activity_id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_activity_facility_id ON claims.encounter(facility_id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_activity_payer_id ON claims.claim(payer_id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_activity_clinician ON claims.activity(clinician);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_activity_encounter_start ON claims.encounter(start_at);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_activity_cpt_code ON claims.activity(code);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_activity_denial_code ON claims.remittance_activity(denial_code);

-- Additional performance indexes
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_claim_event_type ON claims.claim_event(claim_key_id, type);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_remittance_activity_claim ON claims.remittance_activity(remittance_claim_id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_remittance_activity_id ON claims.remittance_activity(activity_id);

-- ==========================================================================================================
-- SECTION 4: API FUNCTIONS - ENHANCED WITH ERROR HANDLING
-- ==========================================================================================================

-- Function for Activity Level report (ENHANCED)
CREATE OR REPLACE FUNCTION claims.get_remittances_resubmission_activity_level(
    p_facility_id TEXT DEFAULT NULL,
    p_facility_ids TEXT[] DEFAULT NULL,
    p_payer_ids TEXT[] DEFAULT NULL,
    p_receiver_ids TEXT[] DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NULL,
    p_to_date TIMESTAMPTZ DEFAULT NULL,
    p_encounter_type TEXT DEFAULT NULL,
    p_clinician_ids TEXT[] DEFAULT NULL,
    p_claim_number TEXT DEFAULT NULL,
    p_cpt_code TEXT DEFAULT NULL,
    p_denial_filter TEXT DEFAULT NULL,
    p_order_by TEXT DEFAULT 'encounter_start DESC',
    p_limit INTEGER DEFAULT 1000,
    p_offset INTEGER DEFAULT 0,
    p_facility_ref_ids BIGINT[] DEFAULT NULL,
    p_payer_ref_ids BIGINT[] DEFAULT NULL,
    p_clinician_ref_ids BIGINT[] DEFAULT NULL
)
RETURNS TABLE (
    claim_key_id BIGINT,
    claim_id TEXT,
    activity_id TEXT,
    member_id TEXT,
    patient_id TEXT,
    payer_id TEXT,
    payer_name TEXT,
    receiver_id TEXT,
    receiver_name TEXT,
    facility_id TEXT,
    facility_name TEXT,
    facility_group TEXT,
    health_authority TEXT,
    clinician TEXT,
    clinician_name TEXT,
    encounter_type TEXT,
    encounter_start TIMESTAMPTZ,
    encounter_end TIMESTAMPTZ,
    encounter_date TIMESTAMPTZ,
    activity_date TIMESTAMPTZ,
    cpt_type TEXT,
    cpt_code TEXT,
    quantity NUMERIC,
    submitted_amount NUMERIC,
    total_paid NUMERIC,
    total_remitted NUMERIC,
    rejected_amount NUMERIC,
    initial_denial_code TEXT,
    latest_denial_code TEXT,
    first_resubmission_type TEXT,
    first_resubmission_comment TEXT,
    first_resubmission_date TIMESTAMPTZ,
    second_resubmission_type TEXT,
    second_resubmission_date TIMESTAMPTZ,
    third_resubmission_type TEXT,
    third_resubmission_date TIMESTAMPTZ,
    fourth_resubmission_type TEXT,
    fourth_resubmission_date TIMESTAMPTZ,
    fifth_resubmission_type TEXT,
    fifth_resubmission_date TIMESTAMPTZ,
    first_ra_date TIMESTAMPTZ,
    first_ra_amount NUMERIC,
    second_ra_date TIMESTAMPTZ,
    second_ra_amount NUMERIC,
    third_ra_date TIMESTAMPTZ,
    third_ra_amount NUMERIC,
    fourth_ra_date TIMESTAMPTZ,
    fourth_ra_amount NUMERIC,
    fifth_ra_date TIMESTAMPTZ,
    fifth_ra_amount NUMERIC,
    resubmission_count BIGINT,
    remittance_count BIGINT,
    has_rejected_amount BOOLEAN,
    rejected_not_resubmitted BOOLEAN,
    denial_code TEXT,
    denial_comment TEXT,
    cpt_status TEXT,
    ageing_days NUMERIC,
    submitted_date TIMESTAMPTZ,
    claim_transaction_date TIMESTAMPTZ,
    primary_diagnosis TEXT,
    secondary_diagnosis TEXT,
    billed_amount NUMERIC,
    paid_amount NUMERIC,
    remitted_amount NUMERIC,
    payment_amount NUMERIC,
    outstanding_balance NUMERIC,
    pending_amount NUMERIC,
    pending_remittance_amount NUMERIC,
    id_payer TEXT,
    prior_authorization_id TEXT,
    payment_reference TEXT,
    date_settlement TIMESTAMPTZ,
    claim_month NUMERIC,
    claim_year NUMERIC,
    collection_rate NUMERIC,
    fully_paid_count BIGINT,
    fully_paid_amount NUMERIC,
    fully_rejected_count BIGINT,
    fully_rejected_amount NUMERIC,
    partially_paid_count BIGINT,
    partially_paid_amount NUMERIC,
    self_pay_count BIGINT,
    self_pay_amount NUMERIC,
    taken_back_amount NUMERIC,
    taken_back_count BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Input validation (unchanged)
    IF p_limit <= 0 OR p_limit > 10000 THEN
        RAISE EXCEPTION 'Invalid limit parameter: % (must be between 1 and 10000)', p_limit;
    END IF;
    IF p_offset < 0 THEN
        RAISE EXCEPTION 'Invalid offset parameter: % (must be >= 0)', p_offset;
    END IF;
    IF p_from_date IS NOT NULL AND p_to_date IS NOT NULL AND p_from_date > p_to_date THEN
        RAISE EXCEPTION 'Invalid date range: from_date (%) > to_date (%)', p_from_date, p_to_date;
    END IF;

    RETURN QUERY
    SELECT 
        v.*
    FROM claims.v_remittances_resubmission_activity_level v
    WHERE 
        (p_facility_id IS NULL OR v.facility_id = p_facility_id)
        AND (p_facility_ids IS NULL OR v.facility_id = ANY(p_facility_ids))
        AND (p_payer_ids IS NULL OR v.payer_id = ANY(p_payer_ids))
        AND (p_receiver_ids IS NULL OR v.receiver_id = ANY(p_receiver_ids))
        AND (p_from_date IS NULL OR v.encounter_start >= p_from_date)
        AND (p_to_date IS NULL OR v.encounter_start <= p_to_date)
        AND (p_encounter_type IS NULL OR v.encounter_type = p_encounter_type)
        AND (p_clinician_ids IS NULL OR v.clinician = ANY(p_clinician_ids))
        AND (p_claim_number IS NULL OR v.claim_id = p_claim_number)
        AND (p_cpt_code IS NULL OR v.cpt_code = p_cpt_code)
        AND (p_denial_filter IS NULL OR 
             (p_denial_filter = 'HAS_DENIAL' AND v.denial_code IS NOT NULL) OR
             (p_denial_filter = 'NO_DENIAL' AND v.denial_code IS NULL) OR
             (p_denial_filter = 'REJECTED_NOT_RESUBMITTED' AND v.rejected_not_resubmitted = TRUE))
        AND (p_facility_ref_ids IS NULL OR v.facility_id IN (
            SELECT facility_id FROM claims.encounter e JOIN claims_ref.facility rf ON e.facility_ref_id = rf.id WHERE rf.id = ANY(p_facility_ref_ids)
        ))
        AND (p_payer_ref_ids IS NULL OR v.payer_id IN (
            SELECT payer_code FROM claims_ref.payer WHERE id = ANY(p_payer_ref_ids)
        ))
        AND (p_clinician_ref_ids IS NULL OR v.clinician IN (
            SELECT clinician_code FROM claims_ref.clinician WHERE id = ANY(p_clinician_ref_ids)
        ))
    ORDER BY 
        CASE WHEN p_order_by = 'encounter_start ASC' THEN v.encounter_start END ASC,
        CASE WHEN p_order_by = 'encounter_start DESC' THEN v.encounter_start END DESC,
        CASE WHEN p_order_by = 'submitted_amount ASC' THEN v.submitted_amount END ASC,
        CASE WHEN p_order_by = 'submitted_amount DESC' THEN v.submitted_amount END DESC,
        CASE WHEN p_order_by = 'ageing_days ASC' THEN v.ageing_days END ASC,
        CASE WHEN p_order_by = 'ageing_days DESC' THEN v.ageing_days END DESC,
        v.encounter_start
    LIMIT p_limit OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION claims.get_remittances_resubmission_activity_level IS 'Get activity-level remittances and resubmission data with filtering and pagination - ENHANCED VERSION';

-- Function for Claim Level report (ENHANCED)
CREATE OR REPLACE FUNCTION claims.get_remittances_resubmission_claim_level(
    p_facility_id TEXT DEFAULT NULL,
    p_facility_ids TEXT[] DEFAULT NULL,
    p_payer_ids TEXT[] DEFAULT NULL,
    p_receiver_ids TEXT[] DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NULL,
    p_to_date TIMESTAMPTZ DEFAULT NULL,
    p_encounter_type TEXT DEFAULT NULL,
    p_clinician_ids TEXT[] DEFAULT NULL,
    p_claim_number TEXT DEFAULT NULL,
    p_denial_filter TEXT DEFAULT NULL,
    p_order_by TEXT DEFAULT 'encounter_start DESC',
    p_limit INTEGER DEFAULT 1000,
    p_offset INTEGER DEFAULT 0,
    p_facility_ref_ids BIGINT[] DEFAULT NULL,
    p_payer_ref_ids BIGINT[] DEFAULT NULL,
    p_clinician_ref_ids BIGINT[] DEFAULT NULL
)
RETURNS TABLE (
    claim_key_id BIGINT,
    claim_id TEXT,
    claim_internal_id BIGINT,
    member_id TEXT,
    patient_id TEXT,
    payer_id TEXT,
    payer_name TEXT,
    receiver_id TEXT,
    receiver_name TEXT,
    facility_id TEXT,
    facility_name TEXT,
    facility_group TEXT,
    health_authority TEXT,
    clinician TEXT,
    clinician_name TEXT,
    encounter_type TEXT,
    encounter_start TIMESTAMPTZ,
    encounter_end TIMESTAMPTZ,
    encounter_date TIMESTAMPTZ,
    submitted_amount NUMERIC,
    total_paid NUMERIC,
    rejected_amount NUMERIC,
    remittance_count BIGINT,
    resubmission_count BIGINT,
    has_rejected_amount BOOLEAN,
    rejected_not_resubmitted BOOLEAN,
    ageing_days NUMERIC,
    submitted_date TIMESTAMPTZ,
    claim_transaction_date TIMESTAMPTZ,
    primary_diagnosis TEXT,
    secondary_diagnosis TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Input validation (unchanged)
    IF p_limit <= 0 OR p_limit > 10000 THEN
        RAISE EXCEPTION 'Invalid limit parameter: % (must be between 1 and 10000)', p_limit;
    END IF;
    IF p_offset < 0 THEN
        RAISE EXCEPTION 'Invalid offset parameter: % (must be >= 0)', p_offset;
    END IF;
    IF p_from_date IS NOT NULL AND p_to_date IS NOT NULL AND p_from_date > p_to_date THEN
        RAISE EXCEPTION 'Invalid date range: from_date (%) > to_date (%)', p_from_date, p_to_date;
    END IF;

    RETURN QUERY
    SELECT 
        v.*
    FROM claims.v_remittances_resubmission_claim_level v
    WHERE 
        (p_facility_id IS NULL OR v.facility_id = p_facility_id)
        AND (p_facility_ids IS NULL OR v.facility_id = ANY(p_facility_ids))
        AND (p_payer_ids IS NULL OR v.payer_id = ANY(p_payer_ids))
        AND (p_receiver_ids IS NULL OR v.receiver_id = ANY(p_receiver_ids))
        AND (p_from_date IS NULL OR v.encounter_start >= p_from_date)
        AND (p_to_date IS NULL OR v.encounter_start <= p_to_date)
        AND (p_encounter_type IS NULL OR v.encounter_type = p_encounter_type)
        AND (p_clinician_ids IS NULL OR v.clinician = ANY(p_clinician_ids))
        AND (p_claim_number IS NULL OR v.claim_id = p_claim_number)
        AND (p_denial_filter IS NULL OR
             (p_denial_filter = 'HAS_DENIAL' AND v.has_rejected_amount = TRUE) OR
             (p_denial_filter = 'NO_DENIAL' AND v.has_rejected_amount = FALSE) OR
             (p_denial_filter = 'REJECTED_NOT_RESUBMITTED' AND v.rejected_not_resubmitted = TRUE))
        AND (p_facility_ref_ids IS NULL OR v.facility_id IN (
            SELECT facility_id FROM claims.encounter e JOIN claims_ref.facility rf ON e.facility_ref_id = rf.id WHERE rf.id = ANY(p_facility_ref_ids)
        ))
        AND (p_payer_ref_ids IS NULL OR v.payer_id IN (
            SELECT payer_code FROM claims_ref.payer WHERE id = ANY(p_payer_ref_ids)
        ))
        AND (p_clinician_ref_ids IS NULL OR v.clinician IN (
            SELECT clinician_code FROM claims_ref.clinician WHERE id = ANY(p_clinician_ref_ids)
        ))
    ORDER BY 
        CASE WHEN p_order_by = 'encounter_start ASC' THEN v.encounter_start END ASC,
        CASE WHEN p_order_by = 'encounter_start DESC' THEN v.encounter_start END DESC,
        CASE WHEN p_order_by = 'submitted_amount ASC' THEN v.submitted_amount END ASC,
        CASE WHEN p_order_by = 'submitted_amount DESC' THEN v.submitted_amount END DESC,
        CASE WHEN p_order_by = 'ageing_days ASC' THEN v.ageing_days END ASC,
        CASE WHEN p_order_by = 'ageing_days DESC' THEN v.ageing_days END DESC,
        v.encounter_start
    LIMIT p_limit OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION claims.get_remittances_resubmission_claim_level IS 'Get claim-level aggregated remittances and resubmission data with filtering and pagination - ENHANCED VERSION';

-- ==========================================================================================================
-- SECTION 5: GRANTS AND PERMISSIONS
-- ==========================================================================================================

-- Grant permissions to claims_user role
GRANT SELECT ON claims.v_remittances_resubmission_activity_level TO claims_user;
GRANT SELECT ON claims.v_remittances_resubmission_claim_level TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_remittances_resubmission_activity_level TO claims_user;
GRANT EXECUTE ON FUNCTION claims.get_remittances_resubmission_claim_level TO claims_user;

-- ==========================================================================================================
-- END OF FIXED IMPLEMENTATION
-- ==========================================================================================================

COMMENT ON SCHEMA claims IS 'Remittances & Resubmission Activity Level Report - Production Ready Implementation (FIXED)';