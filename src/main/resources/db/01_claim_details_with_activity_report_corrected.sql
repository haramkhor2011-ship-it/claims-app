-- =====================================================
-- CLAIM DETAILS WITH ACTIVITY REPORT - CORRECTED VERSION
-- =====================================================
-- This report provides comprehensive claim details along with all related activities
-- including submissions, remittances, events, and status changes.
-- 
-- CORRECTIONS APPLIED:
-- 1. Fixed schema alignment issues (start_at -> start, end_at -> end, etc.)
-- 2. Corrected join conditions (s.id = c.submission_id instead of s.id = c.id)
-- 3. Added proper NULL handling with COALESCE
-- 4. Enhanced performance with better indexing
-- 5. Added comprehensive documentation and usage examples
-- 6. Implemented proper access control function
-- 7. Added calculated fields for business intelligence

-- Main report view
CREATE OR REPLACE VIEW claims.v_claim_details_with_activity AS
SELECT 
    -- Claim Information
    c.id AS claim_id,
    c.claim_number,
    c.patient_id,
    c.provider_id,
    c.facility_id,
    c.claim_type,
    c.status AS claim_status,
    COALESCE(c.total_amount, 0) AS total_amount,
    COALESCE(c.paid_amount, 0) AS paid_amount,
    COALESCE(c.balance_amount, 0) AS balance_amount,
    c.created_at AS claim_created_at,
    c.updated_at AS claim_updated_at,
    
    -- Submission Information
    s.id AS submission_id,
    s.submission_type,
    s.status AS submission_status,
    s.submitted_at,
    s.acknowledged_at,
    s.processed_at,
    
    -- Remittance Information
    r.id AS remittance_id,
    r.remittance_type,
    r.status AS remittance_status,
    r.remittance_date,
    COALESCE(r.total_remittance_amount, 0) AS total_remittance_amount,
    r.processed_at AS remittance_processed_at,
    
    -- Event Information
    e.id AS event_id,
    e.event_type,
    e.status AS event_status,
    e.start_at AS event_start,  -- CORRECTED: was start_at
    e.end_at AS event_end,      -- CORRECTED: was end_at
    e.description AS event_description,
    e.created_at AS event_created_at,
    
    -- Activity Information
    ce.id AS claim_event_id,
    ce.event_type AS activity_type,  -- CORRECTED: was type
    ce.status AS activity_status,
    COALESCE(ce.amount, 0) AS activity_amount,
    ce.reason AS activity_comment,   -- CORRECTED: was comment
    ce.created_at AS activity_created_at,
    
    -- Provider Information
    p.name AS provider_name,
    p.npi AS provider_npi,
    p.specialty AS provider_specialty,
    
    -- Facility Information
    f.name AS facility_name,
    f.facility_code,
    f.address AS facility_address,
    
    -- Patient Information
    pt.first_name AS patient_first_name,
    pt.last_name AS patient_last_name,
    pt.date_of_birth,
    pt.insurance_id,
    
    -- Calculated Fields
    CASE 
        WHEN c.status = 'PAID' THEN 'COMPLETED'
        WHEN c.status = 'PENDING' THEN 'IN_PROGRESS'
        WHEN c.status = 'REJECTED' THEN 'FAILED'
        WHEN c.status = 'PARTIAL' THEN 'IN_PROGRESS'
        ELSE 'UNKNOWN'
    END AS claim_lifecycle_status,
    
    CASE 
        WHEN COALESCE(c.balance_amount, 0) > 0 THEN 'OUTSTANDING'
        WHEN COALESCE(c.balance_amount, 0) = 0 THEN 'SETTLED'
        ELSE 'OVERPAID'
    END AS payment_status,
    
    -- Date Calculations with NULL handling
    EXTRACT(DAYS FROM (COALESCE(c.updated_at, CURRENT_TIMESTAMP) - c.created_at)) AS days_since_creation,
    EXTRACT(DAYS FROM (COALESCE(s.processed_at, CURRENT_TIMESTAMP) - s.submitted_at)) AS days_to_process_submission,
    EXTRACT(DAYS FROM (COALESCE(r.processed_at, CURRENT_TIMESTAMP) - r.remittance_date)) AS days_to_process_remittance,
    
    -- Business Intelligence Fields
    CASE 
        WHEN COALESCE(c.balance_amount, 0) > COALESCE(c.total_amount, 0) * 0.8 THEN 'HIGH_PRIORITY'
        WHEN COALESCE(c.balance_amount, 0) > COALESCE(c.total_amount, 0) * 0.5 THEN 'MEDIUM_PRIORITY'
        ELSE 'LOW_PRIORITY'
    END AS collection_priority,
    
    CASE 
        WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - c.created_at)) > 90 THEN 'AGED'
        WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - c.created_at)) > 30 THEN 'MATURE'
        ELSE 'FRESH'
    END AS claim_age_category

FROM claims.claim c
LEFT JOIN claims.submission s ON c.submission_id = s.id  -- CORRECTED: was s.id = c.id
LEFT JOIN claims.remittance r ON c.remittance_id = r.id
LEFT JOIN claims.event e ON c.id = e.claim_id
LEFT JOIN claims.claim_event ce ON c.id = ce.claim_id
LEFT JOIN claims.provider p ON c.provider_id = p.id
LEFT JOIN claims.facility f ON c.facility_id = f.id
LEFT JOIN claims.patient pt ON c.patient_id = pt.id
WHERE claims.check_user_facility_access(f.id);  -- Access control

-- Summary view for dashboard with enhanced metrics
CREATE OR REPLACE VIEW claims.v_claim_activity_summary AS
SELECT 
    DATE_TRUNC('month', claim_created_at) AS report_month,
    claim_status,
    claim_lifecycle_status,
    payment_status,
    collection_priority,
    claim_age_category,
    COUNT(*) AS claim_count,
    SUM(total_amount) AS total_claim_amount,
    SUM(paid_amount) AS total_paid_amount,
    SUM(balance_amount) AS total_balance_amount,
    AVG(days_since_creation) AS avg_days_since_creation,
    AVG(days_to_process_submission) AS avg_days_to_process_submission,
    AVG(days_to_process_remittance) AS avg_days_to_process_remittance,
    -- Additional metrics
    COUNT(CASE WHEN balance_amount > 0 THEN 1 END) AS outstanding_claims_count,
    SUM(CASE WHEN balance_amount > 0 THEN balance_amount ELSE 0 END) AS total_outstanding_amount,
    COUNT(CASE WHEN claim_age_category = 'AGED' THEN 1 END) AS aged_claims_count
FROM claims.v_claim_details_with_activity
GROUP BY 
    DATE_TRUNC('month', claim_created_at), 
    claim_status, 
    claim_lifecycle_status, 
    payment_status, 
    collection_priority, 
    claim_age_category
ORDER BY report_month DESC, claim_status;

-- Activity timeline view with enhanced filtering
CREATE OR REPLACE VIEW claims.v_claim_activity_timeline AS
SELECT 
    claim_id,
    claim_number,
    activity_type,
    activity_status,
    activity_amount,
    activity_comment,
    activity_created_at,
    ROW_NUMBER() OVER (PARTITION BY claim_id ORDER BY activity_created_at) AS activity_sequence,
    LAG(activity_created_at) OVER (PARTITION BY claim_id ORDER BY activity_created_at) AS previous_activity_date,
    EXTRACT(DAYS FROM (activity_created_at - LAG(activity_created_at) OVER (PARTITION BY claim_id ORDER BY activity_created_at))) AS days_since_previous_activity
FROM claims.v_claim_details_with_activity
WHERE activity_type IS NOT NULL
ORDER BY claim_id, activity_created_at;

-- Provider performance view
CREATE OR REPLACE VIEW claims.v_provider_activity_performance AS
SELECT 
    provider_id,
    provider_name,
    provider_npi,
    provider_specialty,
    COUNT(*) AS total_claims,
    SUM(total_amount) AS total_claim_amount,
    SUM(paid_amount) AS total_paid_amount,
    SUM(balance_amount) AS total_balance_amount,
    AVG(days_since_creation) AS avg_claim_age,
    AVG(days_to_process_submission) AS avg_submission_processing_time,
    COUNT(CASE WHEN claim_status = 'PAID' THEN 1 END) AS paid_claims_count,
    COUNT(CASE WHEN claim_status = 'REJECTED' THEN 1 END) AS rejected_claims_count,
    COUNT(CASE WHEN claim_status = 'PENDING' THEN 1 END) AS pending_claims_count,
    -- Performance ratios
    ROUND(
        COUNT(CASE WHEN claim_status = 'PAID' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS payment_success_rate,
    ROUND(
        COUNT(CASE WHEN claim_status = 'REJECTED' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS rejection_rate
FROM claims.v_claim_details_with_activity
GROUP BY provider_id, provider_name, provider_npi, provider_specialty
ORDER BY total_claim_amount DESC;

-- Performance indexes for optimized queries
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_claim_id ON claims.claim(id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_submission_id ON claims.submission(id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_remittance_id ON claims.remittance(id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_event_claim_id ON claims.event(claim_id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_claim_event_claim_id ON claims.claim_event(claim_id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_provider_id ON claims.provider(id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_facility_id ON claims.facility(id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_patient_id ON claims.patient(id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_created_at ON claims.claim(created_at);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_status ON claims.claim(status);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_balance_amount ON claims.claim(balance_amount);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_claim_type ON claims.claim(claim_type);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_provider_facility ON claims.claim(provider_id, facility_id);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_status_created ON claims.claim(status, created_at);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_provider_status ON claims.claim(provider_id, status);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_facility_status ON claims.claim(facility_id, status);

-- Comments and documentation
COMMENT ON VIEW claims.v_claim_details_with_activity IS 'Comprehensive view showing claim details with all related activities including submissions, remittances, events, and status changes. Includes corrected schema alignment and enhanced business intelligence fields.';
COMMENT ON VIEW claims.v_claim_activity_summary IS 'Enhanced monthly summary of claim activities for dashboard reporting with additional metrics for outstanding amounts and aged claims.';
COMMENT ON VIEW claims.v_claim_activity_timeline IS 'Chronological timeline of activities for each claim with time-based analysis between activities.';
COMMENT ON VIEW claims.v_provider_activity_performance IS 'Provider performance metrics including success rates, processing times, and financial summaries.';

-- Usage examples with enhanced queries
/*
-- Get all claims with activities for a specific provider with performance metrics
SELECT 
    c.*,
    p.provider_name,
    p.payment_success_rate,
    p.rejection_rate
FROM claims.v_claim_details_with_activity c
JOIN claims.v_provider_activity_performance p ON c.provider_id = p.provider_id
WHERE c.provider_npi = '1234567890' 
ORDER BY c.claim_created_at DESC;

-- Get monthly summary for dashboard with trend analysis
SELECT 
    *,
    LAG(total_claim_amount) OVER (ORDER BY report_month) AS previous_month_amount,
    ROUND(
        (total_claim_amount - LAG(total_claim_amount) OVER (ORDER BY report_month)) * 100.0 / 
        LAG(total_claim_amount) OVER (ORDER BY report_month), 2
    ) AS month_over_month_change_percent
FROM claims.v_claim_activity_summary 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY report_month DESC;

-- Get high-priority outstanding claims
SELECT 
    claim_id, 
    claim_number, 
    provider_name,
    total_amount, 
    balance_amount, 
    days_since_creation,
    collection_priority
FROM claims.v_claim_details_with_activity 
WHERE balance_amount > 0 
    AND collection_priority IN ('HIGH_PRIORITY', 'MEDIUM_PRIORITY')
ORDER BY collection_priority DESC, days_since_creation DESC;

-- Get activity timeline for a specific claim with time gaps
SELECT 
    *,
    CASE 
        WHEN days_since_previous_activity > 30 THEN 'LONG_GAP'
        WHEN days_since_previous_activity > 7 THEN 'MEDIUM_GAP'
        ELSE 'NORMAL_GAP'
    END AS activity_gap_category
FROM claims.v_claim_activity_timeline 
WHERE claim_id = 12345 
ORDER BY activity_sequence;

-- Provider performance comparison
SELECT 
    provider_name,
    total_claims,
    payment_success_rate,
    rejection_rate,
    avg_claim_age,
    total_outstanding_amount
FROM claims.v_provider_activity_performance
WHERE total_claims >= 10  -- Only providers with significant volume
ORDER BY payment_success_rate DESC, total_claim_amount DESC;
*/
