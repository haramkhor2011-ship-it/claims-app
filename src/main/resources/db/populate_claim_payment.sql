-- ==========================================================================================================
-- CLAIM PAYMENT INITIAL POPULATION SCRIPT
-- ==========================================================================================================
-- 
-- Purpose: Populate claim_payment table with existing data
-- Version: 1.0
-- Date: 2025-01-03
-- 
-- This script should be run after:
-- 1. Creating the claim_payment table (via claims_unified_ddl_fresh.sql)
-- 2. Creating the functions and triggers (via claim_payment_functions.sql)
-- 
-- The script will:
-- - Populate claim_payment for all existing claims
-- - Calculate all financial metrics and lifecycle data
-- - Verify data integrity after population
-- - Create statistics for query optimization
-- 
-- ==========================================================================================================

-- Disable triggers during population for performance
ALTER TABLE claims.claim_payment DISABLE TRIGGER ALL;

-- Log start of population
DO $$
BEGIN
  RAISE NOTICE 'Starting claim_payment table population at %', NOW();
END$$;

-- Populate claim_payment for all existing claims
INSERT INTO claims.claim_payment (
    claim_key_id,
    total_submitted_amount,
    total_paid_amount,
    total_remitted_amount,
    total_rejected_amount,
    total_denied_amount,
    total_activities,
    paid_activities,
    partially_paid_activities,
    rejected_activities,
    pending_activities,
    remittance_count,
    resubmission_count,
    payment_status,
    first_submission_date,
    last_submission_date,
    first_remittance_date,
    last_remittance_date,
    first_payment_date,
    last_payment_date,
    latest_settlement_date,
    days_to_first_payment,
    days_to_final_settlement,
    processing_cycles,
    latest_payment_reference,
    payment_references,
    tx_at,
    created_at,
    updated_at
)
SELECT 
    ck.id as claim_key_id,
    
    -- Financial metrics
    COALESCE(SUM(a.net), 0) as total_submitted_amount,
    COALESCE(SUM(ra.payment_amount), 0) as total_paid_amount,
    COALESCE(SUM(ra.net), 0) as total_remitted_amount,
    COALESCE(SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN a.net ELSE 0 END), 0) as total_rejected_amount,
    COALESCE(SUM(CASE WHEN ra.denial_code IS NOT NULL THEN a.net ELSE 0 END), 0) as total_denied_amount,
    
    -- Activity counts
    COUNT(DISTINCT a.id) as total_activities,
    COUNT(DISTINCT CASE WHEN ra.payment_amount > 0 THEN a.id END) as paid_activities,
    COUNT(DISTINCT CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < a.net THEN a.id END) as partially_paid_activities,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN a.id END) as rejected_activities,
    COUNT(DISTINCT CASE WHEN ra.payment_amount IS NULL THEN a.id END) as pending_activities,
    
    -- Lifecycle tracking
    COUNT(DISTINCT rc.id) as remittance_count,
    COUNT(DISTINCT CASE WHEN ce.type = 2 THEN ce.id END) as resubmission_count,
    
    -- Payment status
    CASE 
        WHEN COALESCE(SUM(ra.payment_amount), 0) = COALESCE(SUM(a.net), 0) AND COALESCE(SUM(a.net), 0) > 0 THEN 'FULLY_PAID'
        WHEN COALESCE(SUM(ra.payment_amount), 0) > 0 THEN 'PARTIALLY_PAID'
        WHEN COALESCE(SUM(CASE WHEN ra.payment_amount = 0 OR ra.denial_code IS NOT NULL THEN a.net ELSE 0 END), 0) > 0 THEN 'REJECTED'
        ELSE 'PENDING'
    END as payment_status,
    
    -- Dates
    MIN(DATE(c.tx_at)) as first_submission_date,
    MAX(DATE(c.tx_at)) as last_submission_date,
    MIN(DATE(r.tx_at)) as first_remittance_date,
    MAX(DATE(r.tx_at)) as last_remittance_date,
    MIN(DATE(rc.date_settlement)) as first_payment_date,
    MAX(DATE(rc.date_settlement)) as last_payment_date,
    MAX(DATE(rc.date_settlement)) as latest_settlement_date,
    
    -- Metrics
    CASE 
        WHEN MIN(DATE(c.tx_at)) IS NOT NULL AND MIN(DATE(rc.date_settlement)) IS NOT NULL 
        THEN MIN(DATE(rc.date_settlement)) - MIN(DATE(c.tx_at))
        ELSE NULL
    END as days_to_first_payment,
    
    CASE 
        WHEN MIN(DATE(c.tx_at)) IS NOT NULL AND MAX(DATE(rc.date_settlement)) IS NOT NULL 
        THEN MAX(DATE(rc.date_settlement)) - MIN(DATE(c.tx_at))
        ELSE NULL
    END as days_to_final_settlement,
    
    COUNT(DISTINCT ce.id) as processing_cycles,
    
    -- Payment references
    (SELECT payment_reference 
     FROM claims.remittance_claim rc2 
     WHERE rc2.claim_key_id = ck.id 
     ORDER BY rc2.date_settlement DESC NULLS LAST 
     LIMIT 1) as latest_payment_reference,
    
    ARRAY_AGG(DISTINCT rc.payment_reference ORDER BY rc.payment_reference) FILTER (WHERE rc.payment_reference IS NOT NULL) as payment_references,
    
    -- Transaction time
    MAX(c.tx_at) as tx_at,
    
    -- Audit timestamps
    NOW() as created_at,
    NOW() as updated_at

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id 
    AND ra.activity_id = a.activity_id
LEFT JOIN claims.claim_event ce ON ce.claim_key_id = ck.id
GROUP BY ck.id
ON CONFLICT (claim_key_id) DO NOTHING;

-- Re-enable triggers
ALTER TABLE claims.claim_payment ENABLE TRIGGER ALL;

-- Log completion of population
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM claims.claim_payment;
  RAISE NOTICE 'Completed claim_payment table population at %. Total records: %', NOW(), v_count;
END$$;

-- Verify population with detailed summary
SELECT 
    'Population Summary' as summary,
    COUNT(*) as total_claims_populated,
    COUNT(CASE WHEN payment_status = 'FULLY_PAID' THEN 1 END) as fully_paid_claims,
    COUNT(CASE WHEN payment_status = 'PARTIALLY_PAID' THEN 1 END) as partially_paid_claims,
    COUNT(CASE WHEN payment_status = 'REJECTED' THEN 1 END) as rejected_claims,
    COUNT(CASE WHEN payment_status = 'PENDING' THEN 1 END) as pending_claims,
    SUM(total_submitted_amount) as total_submitted_amount,
    SUM(total_paid_amount) as total_paid_amount,
    SUM(total_rejected_amount) as total_rejected_amount,
    AVG(days_to_first_payment) as avg_days_to_first_payment,
    AVG(days_to_final_settlement) as avg_days_to_final_settlement,
    MAX(remittance_count) as max_remittance_count,
    MAX(resubmission_count) as max_resubmission_count
FROM claims.claim_payment;

-- Verify data integrity
SELECT 
    'Data Integrity Check' as check_type,
    COUNT(*) as total_claims,
    COUNT(CASE WHEN total_activities = (paid_activities + partially_paid_activities + rejected_activities + pending_activities) THEN 1 END) as activity_count_consistent,
    COUNT(CASE WHEN total_paid_amount >= 0 AND total_submitted_amount >= 0 THEN 1 END) as amounts_positive,
    COUNT(CASE WHEN payment_status IN ('FULLY_PAID', 'PARTIALLY_PAID', 'REJECTED', 'PENDING') THEN 1 END) as status_valid
FROM claims.claim_payment;

-- Check for potential data issues
SELECT 
    'Potential Issues' as issue_type,
    COUNT(CASE WHEN total_submitted_amount = 0 THEN 1 END) as zero_submitted_amount,
    COUNT(CASE WHEN total_activities = 0 THEN 1 END) as zero_activities,
    COUNT(CASE WHEN days_to_first_payment < 0 THEN 1 END) as negative_days_to_payment,
    COUNT(CASE WHEN days_to_final_settlement < 0 THEN 1 END) as negative_days_to_settlement
FROM claims.claim_payment;

-- Create statistics for query optimization
ANALYZE claims.claim_payment;

-- Log final statistics
DO $$
DECLARE
  v_table_size TEXT;
  v_index_size TEXT;
BEGIN
  SELECT pg_size_pretty(pg_total_relation_size('claims.claim_payment')) INTO v_table_size;
  SELECT pg_size_pretty(pg_relation_size('claims.claim_payment')) INTO v_index_size;
  
  RAISE NOTICE 'Table size: %, Index size: %', v_table_size, v_index_size;
  RAISE NOTICE 'Claim payment table population completed successfully!';
END$$;

-- ==========================================================================================================
-- POST-POPULATION VALIDATION QUERIES
-- ==========================================================================================================

-- Sample queries to validate the populated data
-- (These can be run separately for verification)

/*
-- 1. Check payment status distribution
SELECT 
    payment_status,
    COUNT(*) as claim_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM claims.claim_payment
GROUP BY payment_status
ORDER BY claim_count DESC;

-- 2. Check remittance count distribution
SELECT 
    remittance_count,
    COUNT(*) as claim_count
FROM claims.claim_payment
GROUP BY remittance_count
ORDER BY remittance_count;

-- 3. Check resubmission count distribution
SELECT 
    resubmission_count,
    COUNT(*) as claim_count
FROM claims.claim_payment
GROUP BY resubmission_count
ORDER BY resubmission_count;

-- 4. Check processing time distribution
SELECT 
    CASE 
        WHEN days_to_final_settlement IS NULL THEN 'No Settlement'
        WHEN days_to_final_settlement <= 30 THEN '0-30 days'
        WHEN days_to_final_settlement <= 60 THEN '31-60 days'
        WHEN days_to_final_settlement <= 90 THEN '61-90 days'
        ELSE '90+ days'
    END as processing_time_bucket,
    COUNT(*) as claim_count
FROM claims.claim_payment
GROUP BY 
    CASE 
        WHEN days_to_final_settlement IS NULL THEN 'No Settlement'
        WHEN days_to_final_settlement <= 30 THEN '0-30 days'
        WHEN days_to_final_settlement <= 60 THEN '31-60 days'
        WHEN days_to_final_settlement <= 90 THEN '61-90 days'
        ELSE '90+ days'
    END
ORDER BY claim_count DESC;

-- 5. Check financial metrics summary
SELECT 
    'Financial Summary' as metric,
    COUNT(*) as total_claims,
    SUM(total_submitted_amount) as total_submitted,
    SUM(total_paid_amount) as total_paid,
    SUM(total_rejected_amount) as total_rejected,
    ROUND(SUM(total_paid_amount) * 100.0 / NULLIF(SUM(total_submitted_amount), 0), 2) as payment_rate_percentage
FROM claims.claim_payment
WHERE total_submitted_amount > 0;
*/

COMMENT ON SCRIPT populate_claim_payment.sql IS 'Initial population script for claim_payment table - run after table creation and functions setup';
