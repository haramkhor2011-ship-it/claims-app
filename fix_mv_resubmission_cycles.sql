-- ==========================================================================================================
-- FIX: mv_resubmission_cycles - Apply Event-Level Remittance Aggregation
-- ==========================================================================================================
-- 
-- Purpose: Fix mv_resubmission_cycles to prevent duplicates from multiple remittances per claim
-- Root Cause: LEFT JOIN to remittance_claim without aggregation creates multiple rows per event
-- Solution: Pre-aggregate remittance data per claim and get closest remittance to each event
-- 
-- Analysis: This MV is for resubmission cycle tracking - event-level view
-- - Business Requirement: Track events with closest remittance information
-- - One-to-Many: claim_key → claim_event (multiple events per claim)
-- - One-to-Many: claim_key → remittance_claim (multiple remittances per claim)
-- - Required: Event-level aggregation with closest remittance info
-- ==========================================================================================================

-- ==========================================================================================================
-- STEP 1: Drop existing materialized view
-- ==========================================================================================================
DROP MATERIALIZED VIEW IF EXISTS claims.mv_resubmission_cycles CASCADE;

-- ==========================================================================================================
-- STEP 2: Create fixed materialized view with event-level remittance aggregation
-- ==========================================================================================================
CREATE MATERIALIZED VIEW claims.mv_resubmission_cycles AS
WITH event_remittance_agg AS (
  -- Pre-aggregate remittance data per claim and get closest remittance to each event
  SELECT 
    ce.claim_key_id,
    ce.event_time,
    ce.type,
    -- Get remittance info closest to this event
    (ARRAY_AGG(rc.date_settlement ORDER BY ABS(EXTRACT(EPOCH FROM (rc.date_settlement - ce.event_time)))))[1] as closest_settlement_date,
    (ARRAY_AGG(rc.payment_reference ORDER BY ABS(EXTRACT(EPOCH FROM (rc.date_settlement - ce.event_time)))))[1] as closest_payment_reference,
    (ARRAY_AGG(rc.id ORDER BY ABS(EXTRACT(EPOCH FROM (rc.date_settlement - ce.event_time)))))[1] as closest_remittance_claim_id,
    -- Additional remittance metrics
    COUNT(DISTINCT rc.id) as total_remittance_count,
    MIN(rc.date_settlement) as earliest_settlement_date,
    MAX(rc.date_settlement) as latest_settlement_date
  FROM claims.claim_event ce
  LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ce.claim_key_id
  WHERE ce.type IN (1, 2) -- SUBMISSION, RESUBMISSION
  GROUP BY ce.claim_key_id, ce.event_time, ce.type
)
SELECT 
  ce.claim_key_id,
  ce.event_time,
  ce.type,
  cr.resubmission_type,
  cr.comment,
  ROW_NUMBER() OVER (PARTITION BY ce.claim_key_id ORDER BY ce.event_time) as cycle_number,
  -- Remittance cycle tracking (closest to event)
  era.closest_settlement_date as date_settlement,
  era.closest_payment_reference as payment_reference,
  era.closest_remittance_claim_id as remittance_claim_id,
  -- Additional remittance metrics
  era.total_remittance_count,
  era.earliest_settlement_date,
  era.latest_settlement_date,
  -- Calculated fields
  EXTRACT(DAYS FROM (ce.event_time - LAG(ce.event_time) OVER (PARTITION BY ce.claim_key_id ORDER BY ce.event_time))) as days_since_last_event,
  -- Days between event and closest remittance
  CASE 
    WHEN era.closest_settlement_date IS NOT NULL THEN
      EXTRACT(DAYS FROM (era.closest_settlement_date - ce.event_time))
    ELSE NULL
  END as days_to_closest_remittance
FROM claims.claim_event ce
LEFT JOIN claims.claim_resubmission cr ON ce.id = cr.claim_event_id
LEFT JOIN event_remittance_agg era ON era.claim_key_id = ce.claim_key_id 
  AND era.event_time = ce.event_time 
  AND era.type = ce.type
WHERE ce.type IN (1, 2); -- SUBMISSION, RESUBMISSION

-- ==========================================================================================================
-- STEP 3: Create performance indexes
-- ==========================================================================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_resubmission_unique 
ON claims.mv_resubmission_cycles(claim_key_id, event_time, type);

CREATE INDEX IF NOT EXISTS idx_mv_resubmission_covering 
ON claims.mv_resubmission_cycles(claim_key_id, event_time) 
INCLUDE (cycle_number, resubmission_type);

CREATE INDEX IF NOT EXISTS idx_mv_resubmission_type 
ON claims.mv_resubmission_cycles(type, event_time);

CREATE INDEX IF NOT EXISTS idx_mv_resubmission_remittance 
ON claims.mv_resubmission_cycles(claim_key_id, date_settlement);

-- ==========================================================================================================
-- STEP 4: Add documentation comment
-- ==========================================================================================================
COMMENT ON MATERIALIZED VIEW claims.mv_resubmission_cycles IS 'Pre-computed resubmission cycle tracking for sub-second report performance - FIXED: Event-level remittance aggregation to prevent duplicates';

-- ==========================================================================================================
-- STEP 5: Test the materialized view
-- ==========================================================================================================

-- Test 1: Check row count
SELECT 'mv_resubmission_cycles' as view_name, COUNT(*) as row_count 
FROM claims.mv_resubmission_cycles;

-- Test 2: Check for duplicates (should be 0)
WITH duplicate_check AS (
  SELECT 
    claim_key_id, 
    event_time,
    type,
    COUNT(*) as row_count
  FROM claims.mv_resubmission_cycles
  GROUP BY claim_key_id, event_time, type
)
SELECT 
  COUNT(*) as total_unique_combinations,
  SUM(row_count) as total_rows,
  COUNT(CASE WHEN row_count > 1 THEN 1 END) as duplicate_combinations,
  SUM(CASE WHEN row_count > 1 THEN row_count - 1 ELSE 0 END) as total_duplicate_rows
FROM duplicate_check;

-- Test 3: Verify event-level aggregation is working
SELECT 
  claim_key_id,
  event_time,
  type,
  cycle_number,
  resubmission_type,
  total_remittance_count,
  date_settlement,
  days_to_closest_remittance
FROM claims.mv_resubmission_cycles
WHERE total_remittance_count > 1
ORDER BY total_remittance_count DESC
LIMIT 5;

-- Test 4: Check cycle distribution
SELECT 
  cycle_number,
  COUNT(*) as count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM claims.mv_resubmission_cycles
GROUP BY cycle_number
ORDER BY cycle_number;

-- Test 5: Check event types
SELECT 
  type,
  CASE 
    WHEN type = 1 THEN 'SUBMISSION'
    WHEN type = 2 THEN 'RESUBMISSION'
    ELSE 'UNKNOWN'
  END as event_type_name,
  COUNT(*) as count
FROM claims.mv_resubmission_cycles
GROUP BY type
ORDER BY type;

-- Test 6: Test refresh
REFRESH MATERIALIZED VIEW claims.mv_resubmission_cycles;

-- ==========================================================================================================
-- STEP 7: Final verification
-- ==========================================================================================================
SELECT 'SUCCESS' as status, 
       'mv_resubmission_cycles fixed with event-level remittance aggregation' as message,
       COUNT(*) as total_rows
FROM claims.mv_resubmission_cycles;

-- ==========================================================================================================
-- SUMMARY OF CHANGES
-- ==========================================================================================================
-- 
-- CHANGES MADE:
-- 1. Added event_remittance_agg CTE to pre-aggregate remittance data per event
-- 2. Used ARRAY_AGG() with ORDER BY to get closest remittance to each event
-- 3. Removed direct LEFT JOIN to remittance_claim that was causing duplicates
-- 4. Added additional metrics for remittance tracking
-- 5. Updated documentation comment to indicate fix applied
-- 
-- BENEFITS:
-- - Eliminates duplicate rows from multiple remittances per claim
-- - Ensures one row per event with closest remittance information
-- - Maintains all original functionality and metrics
-- - Improves performance by reducing data duplication
-- - Follows event-level aggregation pattern for resubmission cycle tracking
-- 
-- TESTING:
-- - Row count verification
-- - Duplicate detection
-- - Event-level aggregation verification
-- - Cycle distribution analysis
-- - Refresh testing
-- ==========================================================================================================

