-- =====================================================
-- REMITTANCES & RESUBMISSION ACTIVITY LEVEL REPORT
-- =====================================================
-- This report provides detailed analysis of remittances and resubmission activities
-- including activity levels, patterns, and performance metrics.

-- Main remittances resubmission activity view
CREATE OR REPLACE VIEW claims.v_remittances_resubmission_activity AS
SELECT 
    -- Remittance Information
    r.id AS remittance_id,
    r.remittance_type,
    r.status AS remittance_status,
    r.remittance_date,
    r.total_remittance_amount,
    r.processed_at AS remittance_processed_at,
    r.created_at AS remittance_created_at,
    
    -- Resubmission Information
    rs.id AS resubmission_id,
    rs.resubmission_type,
    rs.status AS resubmission_status,
    rs.resubmission_date,
    rs.resubmission_reason,
    rs.resubmission_amount,
    rs.created_at AS resubmission_created_at,
    
    -- Claim Information
    c.id AS claim_id,
    c.claim_number,
    c.claim_type,
    c.status AS claim_status,
    c.total_amount,
    c.paid_amount,
    c.balance_amount,
    c.created_at AS claim_created_at,
    
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
        WHEN r.remittance_date IS NOT NULL THEN EXTRACT(DAYS FROM (r.remittance_date - c.created_at))
        ELSE NULL
    END AS days_to_remittance,
    
    CASE 
        WHEN rs.resubmission_date IS NOT NULL THEN EXTRACT(DAYS FROM (rs.resubmission_date - c.created_at))
        ELSE NULL
    END AS days_to_resubmission,
    
    CASE 
        WHEN rs.resubmission_date IS NOT NULL AND r.remittance_date IS NOT NULL THEN 
            EXTRACT(DAYS FROM (rs.resubmission_date - r.remittance_date))
        ELSE NULL
    END AS days_between_remittance_resubmission,
    
    CASE 
        WHEN rs.resubmission_amount > c.total_amount * 0.8 THEN 'HIGH_RESUBMISSION'
        WHEN rs.resubmission_amount > c.total_amount * 0.5 THEN 'MEDIUM_RESUBMISSION'
        WHEN rs.resubmission_amount > 0 THEN 'LOW_RESUBMISSION'
        ELSE 'NO_RESUBMISSION'
    END AS resubmission_level

FROM claims.remittance r
LEFT JOIN claims.resubmission rs ON r.claim_id = rs.claim_id
LEFT JOIN claims.claim c ON r.claim_id = c.id
LEFT JOIN claims.provider p ON c.provider_id = p.id
LEFT JOIN claims.facility f ON c.facility_id = f.id
LEFT JOIN claims.patient pt ON c.patient_id = pt.id
WHERE claims.check_user_facility_access(f.id);

-- Resubmission activity summary view
CREATE OR REPLACE VIEW claims.v_resubmission_activity_summary AS
SELECT 
    COUNT(*) AS total_remittances,
    COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END) AS remittances_with_resubmission,
    COUNT(CASE WHEN resubmission_id IS NULL THEN 1 END) AS remittances_without_resubmission,
    SUM(total_remittance_amount) AS total_remittance_amount,
    SUM(COALESCE(resubmission_amount, 0)) AS total_resubmission_amount,
    AVG(COALESCE(resubmission_amount, 0)) AS avg_resubmission_amount,
    AVG(days_to_remittance) AS avg_days_to_remittance,
    AVG(days_to_resubmission) AS avg_days_to_resubmission,
    AVG(days_between_remittance_resubmission) AS avg_days_between_remittance_resubmission,
    COUNT(DISTINCT provider_id) AS affected_providers,
    COUNT(DISTINCT facility_id) AS affected_facilities
FROM claims.v_remittances_resubmission_activity;

-- Provider resubmission analysis view
CREATE OR REPLACE VIEW claims.v_provider_resubmission_analysis AS
SELECT 
    provider_id,
    provider_name,
    provider_npi,
    provider_specialty,
    COUNT(*) AS total_remittances,
    COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END) AS remittances_with_resubmission,
    COUNT(CASE WHEN resubmission_id IS NULL THEN 1 END) AS remittances_without_resubmission,
    SUM(total_remittance_amount) AS total_remittance_amount,
    SUM(COALESCE(resubmission_amount, 0)) AS total_resubmission_amount,
    AVG(COALESCE(resubmission_amount, 0)) AS avg_resubmission_amount,
    AVG(days_to_remittance) AS avg_days_to_remittance,
    AVG(days_to_resubmission) AS avg_days_to_resubmission,
    AVG(days_between_remittance_resubmission) AS avg_days_between_remittance_resubmission,
    ROUND(
        COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS resubmission_rate
FROM claims.v_remittances_resubmission_activity
GROUP BY provider_id, provider_name, provider_npi, provider_specialty
ORDER BY resubmission_rate DESC;

-- Resubmission reason analysis view
CREATE OR REPLACE VIEW claims.v_resubmission_reason_analysis AS
SELECT 
    resubmission_reason,
    resubmission_type,
    COUNT(*) AS resubmission_count,
    COUNT(DISTINCT provider_id) AS affected_providers,
    COUNT(DISTINCT facility_id) AS affected_facilities,
    SUM(resubmission_amount) AS total_resubmission_amount,
    AVG(resubmission_amount) AS avg_resubmission_amount,
    AVG(days_to_resubmission) AS avg_days_to_resubmission,
    AVG(days_between_remittance_resubmission) AS avg_days_between_remittance_resubmission,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS resubmission_percentage
FROM claims.v_remittances_resubmission_activity
WHERE resubmission_id IS NOT NULL
GROUP BY resubmission_reason, resubmission_type
ORDER BY resubmission_count DESC;

-- Monthly resubmission trends view
CREATE OR REPLACE VIEW claims.v_monthly_resubmission_trends AS
SELECT 
    DATE_TRUNC('month', remittance_date) AS report_month,
    COUNT(*) AS total_remittances,
    COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END) AS remittances_with_resubmission,
    SUM(total_remittance_amount) AS total_remittance_amount,
    SUM(COALESCE(resubmission_amount, 0)) AS total_resubmission_amount,
    AVG(days_to_remittance) AS avg_days_to_remittance,
    AVG(days_to_resubmission) AS avg_days_to_resubmission,
    AVG(days_between_remittance_resubmission) AS avg_days_between_remittance_resubmission,
    COUNT(DISTINCT provider_id) AS affected_providers,
    COUNT(DISTINCT resubmission_reason) AS unique_resubmission_reasons,
    ROUND(
        COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS resubmission_rate
FROM claims.v_remittances_resubmission_activity
GROUP BY DATE_TRUNC('month', remittance_date)
ORDER BY report_month DESC;

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_remittance_id ON claims.remittance(id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_resubmission_id ON claims.resubmission(claim_id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_claim_id ON claims.claim(id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_provider_id ON claims.provider(id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_facility_id ON claims.facility(id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_patient_id ON claims.patient(id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_remittance_date ON claims.remittance(remittance_date);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_resubmission_date ON claims.resubmission(resubmission_date);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_resubmission_reason ON claims.resubmission(resubmission_reason);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_resubmission_type ON claims.resubmission(resubmission_type);

-- Comments and documentation
COMMENT ON VIEW claims.v_remittances_resubmission_activity IS 'Detailed analysis of remittances and resubmission activities including activity levels, patterns, and performance metrics';
COMMENT ON VIEW claims.v_resubmission_activity_summary IS 'Summary statistics of resubmission activities';
COMMENT ON VIEW claims.v_provider_resubmission_analysis IS 'Provider-specific resubmission analysis and patterns';
COMMENT ON VIEW claims.v_resubmission_reason_analysis IS 'Analysis of resubmission reasons with frequency and impact metrics';
COMMENT ON VIEW claims.v_monthly_resubmission_trends IS 'Monthly trends in resubmission activities';

-- Usage examples
/*
-- Get remittances resubmission activity for specific provider
SELECT * FROM claims.v_remittances_resubmission_activity 
WHERE provider_npi = '1234567890' 
ORDER BY remittance_date DESC;

-- Get resubmission activity summary
SELECT * FROM claims.v_resubmission_activity_summary;

-- Get provider resubmission analysis
SELECT * FROM claims.v_provider_resubmission_analysis 
WHERE total_remittances >= 10 
ORDER BY resubmission_rate DESC;

-- Get resubmission reason analysis
SELECT * FROM claims.v_resubmission_reason_analysis 
ORDER BY resubmission_count DESC;

-- Get monthly resubmission trends
SELECT * FROM claims.v_monthly_resubmission_trends 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY report_month DESC;

-- Get high-resubmission cases
SELECT * FROM claims.v_remittances_resubmission_activity 
WHERE resubmission_level IN ('HIGH_RESUBMISSION', 'MEDIUM_RESUBMISSION')
ORDER BY resubmission_amount DESC;
*/
