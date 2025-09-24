-- =====================================================
-- CLAIM DETAILS WITH ACTIVITY REPORT
-- =====================================================
-- This report provides comprehensive claim details along with all related activities
-- including submissions, remittances, events, and status changes.

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
    c.total_amount,
    c.paid_amount,
    c.balance_amount,
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
    r.total_remittance_amount,
    r.processed_at AS remittance_processed_at,
    
    -- Event Information
    e.id AS event_id,
    e.event_type,
    e.status AS event_status,
    e.start_at AS event_start,
    e.end_at AS event_end,
    e.description AS event_description,
    e.created_at AS event_created_at,
    
    -- Activity Information
    ce.id AS claim_event_id,
    ce.event_type AS activity_type,
    ce.status AS activity_status,
    ce.amount AS activity_amount,
    ce.comment AS activity_comment,
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
        ELSE 'UNKNOWN'
    END AS claim_lifecycle_status,
    
    CASE 
        WHEN c.balance_amount > 0 THEN 'OUTSTANDING'
        WHEN c.balance_amount = 0 THEN 'SETTLED'
        ELSE 'OVERPAID'
    END AS payment_status,
    
    -- Date Calculations
    EXTRACT(DAYS FROM (COALESCE(c.updated_at, CURRENT_TIMESTAMP) - c.created_at)) AS days_since_creation,
    EXTRACT(DAYS FROM (COALESCE(s.processed_at, CURRENT_TIMESTAMP) - s.submitted_at)) AS days_to_process_submission,
    EXTRACT(DAYS FROM (COALESCE(r.processed_at, CURRENT_TIMESTAMP) - r.remittance_date)) AS days_to_process_remittance

FROM claims.claim c
LEFT JOIN claims.submission s ON c.submission_id = s.id
LEFT JOIN claims.remittance r ON c.remittance_id = r.id
LEFT JOIN claims.event e ON c.id = e.claim_id
LEFT JOIN claims.claim_event ce ON c.id = ce.claim_id
LEFT JOIN claims.provider p ON c.provider_id = p.id
LEFT JOIN claims.facility f ON c.facility_id = f.id
LEFT JOIN claims.patient pt ON c.patient_id = pt.id
WHERE claims.check_user_facility_access(f.id);

-- Summary view for dashboard
CREATE OR REPLACE VIEW claims.v_claim_activity_summary AS
SELECT 
    DATE_TRUNC('month', claim_created_at) AS report_month,
    claim_status,
    COUNT(*) AS claim_count,
    SUM(total_amount) AS total_claim_amount,
    SUM(paid_amount) AS total_paid_amount,
    SUM(balance_amount) AS total_balance_amount,
    AVG(days_since_creation) AS avg_days_since_creation,
    AVG(days_to_process_submission) AS avg_days_to_process_submission,
    AVG(days_to_process_remittance) AS avg_days_to_process_remittance
FROM claims.v_claim_details_with_activity
GROUP BY DATE_TRUNC('month', claim_created_at), claim_status
ORDER BY report_month DESC, claim_status;

-- Activity timeline view
CREATE OR REPLACE VIEW claims.v_claim_activity_timeline AS
SELECT 
    claim_id,
    claim_number,
    activity_type,
    activity_status,
    activity_amount,
    activity_comment,
    activity_created_at,
    ROW_NUMBER() OVER (PARTITION BY claim_id ORDER BY activity_created_at) AS activity_sequence
FROM claims.v_claim_details_with_activity
WHERE activity_type IS NOT NULL
ORDER BY claim_id, activity_created_at;

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_claim_id ON claims.claim(id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_submission_id ON claims.submission(id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_remittance_id ON claims.remittance(id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_event_id ON claims.event(claim_id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_claim_event_id ON claims.claim_event(claim_id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_provider_id ON claims.provider(id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_facility_id ON claims.facility(id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_patient_id ON claims.patient(id);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_created_at ON claims.claim(created_at);
CREATE INDEX IF NOT EXISTS idx_claim_details_activity_status ON claims.claim(status);

-- Comments and documentation
COMMENT ON VIEW claims.v_claim_details_with_activity IS 'Comprehensive view showing claim details with all related activities including submissions, remittances, events, and status changes';
COMMENT ON VIEW claims.v_claim_activity_summary IS 'Monthly summary of claim activities for dashboard reporting';
COMMENT ON VIEW claims.v_claim_activity_timeline IS 'Chronological timeline of activities for each claim';

-- Usage examples
/*
-- Get all claims with activities for a specific provider
SELECT * FROM claims.v_claim_details_with_activity 
WHERE provider_npi = '1234567890' 
ORDER BY claim_created_at DESC;

-- Get monthly summary for dashboard
SELECT * FROM claims.v_claim_activity_summary 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY report_month DESC;

-- Get activity timeline for a specific claim
SELECT * FROM claims.v_claim_activity_timeline 
WHERE claim_id = 12345 
ORDER BY activity_sequence;

-- Get claims with outstanding balances
SELECT claim_id, claim_number, total_amount, balance_amount, days_since_creation
FROM claims.v_claim_details_with_activity 
WHERE balance_amount > 0 
ORDER BY days_since_creation DESC;
*/
