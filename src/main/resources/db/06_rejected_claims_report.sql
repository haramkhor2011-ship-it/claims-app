-- =====================================================
-- REJECTED CLAIMS REPORT
-- =====================================================
-- This report provides comprehensive analysis of rejected claims
-- including rejection reasons, patterns, and recovery opportunities.

-- Main rejected claims view
CREATE OR REPLACE VIEW claims.v_rejected_claims_report AS
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
    
    -- Rejection Information
    r.id AS rejection_id,
    r.rejection_reason,
    r.rejection_code,
    r.rejection_date,
    r.rejection_amount,
    r.rejection_category,
    r.rejection_description,
    r.created_at AS rejection_created_at,
    
    -- Provider Information
    p.name AS provider_name,
    p.npi AS provider_npi,
    p.specialty AS provider_specialty,
    
    -- Patient Information
    pt.first_name AS patient_first_name,
    pt.last_name AS patient_last_name,
    pt.date_of_birth,
    pt.insurance_id,
    
    -- Facility Information
    f.name AS facility_name,
    f.facility_code,
    f.address AS facility_address,
    
    -- Calculated Fields
    CASE 
        WHEN r.rejection_date IS NOT NULL THEN EXTRACT(DAYS FROM (r.rejection_date - c.created_at))
        ELSE NULL
    END AS days_to_rejection,
    
    CASE 
        WHEN r.rejection_amount > c.total_amount * 0.8 THEN 'HIGH_REJECTION'
        WHEN r.rejection_amount > c.total_amount * 0.5 THEN 'MEDIUM_REJECTION'
        WHEN r.rejection_amount > 0 THEN 'LOW_REJECTION'
        ELSE 'NO_REJECTION'
    END AS rejection_severity,
    
    CASE 
        WHEN r.rejection_category = 'MEDICAL_NECESSITY' THEN 'MEDICAL'
        WHEN r.rejection_category = 'AUTHORIZATION' THEN 'AUTHORIZATION'
        WHEN r.rejection_category = 'CODING' THEN 'CODING'
        WHEN r.rejection_category = 'ELIGIBILITY' THEN 'ELIGIBILITY'
        WHEN r.rejection_category = 'COVERAGE' THEN 'COVERAGE'
        ELSE 'OTHER'
    END AS rejection_type_category

FROM claims.claim c
LEFT JOIN claims.rejection r ON c.id = r.claim_id
LEFT JOIN claims.provider p ON c.provider_id = p.id
LEFT JOIN claims.patient pt ON c.patient_id = pt.id
LEFT JOIN claims.facility f ON c.facility_id = f.id
WHERE claims.check_user_facility_access(f.id)
    AND c.status = 'REJECTED';

-- Rejected claims summary view
CREATE OR REPLACE VIEW claims.v_rejected_claims_summary AS
SELECT 
    COUNT(*) AS total_rejected_claims,
    COUNT(CASE WHEN rejection_id IS NOT NULL THEN 1 END) AS claims_with_rejection_details,
    SUM(total_amount) AS total_rejected_amount,
    SUM(COALESCE(rejection_amount, 0)) AS total_rejection_amount,
    AVG(COALESCE(rejection_amount, 0)) AS avg_rejection_amount,
    COUNT(DISTINCT provider_id) AS affected_providers,
    COUNT(DISTINCT facility_id) AS affected_facilities,
    COUNT(DISTINCT patient_id) AS affected_patients,
    AVG(COALESCE(days_to_rejection, 0)) AS avg_days_to_rejection
FROM claims.v_rejected_claims_report;

-- Provider rejection analysis view
CREATE OR REPLACE VIEW claims.v_provider_rejection_analysis AS
SELECT 
    provider_id,
    provider_name,
    provider_npi,
    provider_specialty,
    COUNT(*) AS total_rejected_claims,
    SUM(total_amount) AS total_rejected_amount,
    SUM(COALESCE(rejection_amount, 0)) AS total_rejection_amount,
    AVG(COALESCE(rejection_amount, 0)) AS avg_rejection_amount,
    AVG(COALESCE(days_to_rejection, 0)) AS avg_days_to_rejection,
    COUNT(CASE WHEN rejection_severity = 'HIGH_REJECTION' THEN 1 END) AS high_severity_rejections,
    COUNT(CASE WHEN rejection_severity = 'MEDIUM_REJECTION' THEN 1 END) AS medium_severity_rejections,
    COUNT(CASE WHEN rejection_severity = 'LOW_REJECTION' THEN 1 END) AS low_severity_rejections
FROM claims.v_rejected_claims_report
GROUP BY provider_id, provider_name, provider_npi, provider_specialty
ORDER BY total_rejected_amount DESC;

-- Rejection reason analysis view
CREATE OR REPLACE VIEW claims.v_rejection_reason_analysis AS
SELECT 
    rejection_reason,
    rejection_code,
    rejection_category,
    rejection_type_category,
    COUNT(*) AS rejection_count,
    COUNT(DISTINCT provider_id) AS affected_providers,
    COUNT(DISTINCT facility_id) AS affected_facilities,
    SUM(rejection_amount) AS total_rejection_amount,
    AVG(rejection_amount) AS avg_rejection_amount,
    AVG(days_to_rejection) AS avg_days_to_rejection,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS rejection_percentage
FROM claims.v_rejected_claims_report
WHERE rejection_id IS NOT NULL
GROUP BY rejection_reason, rejection_code, rejection_category, rejection_type_category
ORDER BY rejection_count DESC;

-- Monthly rejection trends view
CREATE OR REPLACE VIEW claims.v_monthly_rejection_trends AS
SELECT 
    DATE_TRUNC('month', claim_created_at) AS report_month,
    COUNT(*) AS total_rejected_claims,
    SUM(total_amount) AS total_rejected_amount,
    SUM(COALESCE(rejection_amount, 0)) AS total_rejection_amount,
    COUNT(DISTINCT provider_id) AS affected_providers,
    COUNT(DISTINCT rejection_reason) AS unique_rejection_reasons,
    AVG(COALESCE(days_to_rejection, 0)) AS avg_days_to_rejection,
    COUNT(CASE WHEN rejection_severity = 'HIGH_REJECTION' THEN 1 END) AS high_severity_rejections
FROM claims.v_rejected_claims_report
GROUP BY DATE_TRUNC('month', claim_created_at)
ORDER BY report_month DESC;

-- Recovery opportunities view
CREATE OR REPLACE VIEW claims.v_recovery_opportunities AS
SELECT 
    claim_id,
    claim_number,
    provider_name,
    rejection_reason,
    rejection_category,
    rejection_type_category,
    total_amount,
    rejection_amount,
    rejection_severity,
    days_to_rejection,
    CASE 
        WHEN rejection_category = 'AUTHORIZATION' THEN 'RESUBMIT_WITH_AUTH'
        WHEN rejection_category = 'ELIGIBILITY' THEN 'VERIFY_ELIGIBILITY'
        WHEN rejection_category = 'CODING' THEN 'CORRECT_CODING'
        WHEN rejection_category = 'COVERAGE' THEN 'VERIFY_COVERAGE'
        WHEN rejection_category = 'MEDICAL_NECESSITY' THEN 'CLINICAL_REVIEW'
        ELSE 'MANUAL_REVIEW'
    END AS recovery_action,
    CASE 
        WHEN rejection_category IN ('AUTHORIZATION', 'ELIGIBILITY', 'CODING') THEN 'HIGH'
        WHEN rejection_category = 'COVERAGE' THEN 'MEDIUM'
        ELSE 'LOW'
    END AS recovery_probability
FROM claims.v_rejected_claims_report
WHERE rejection_id IS NOT NULL
ORDER BY rejection_amount DESC;

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_rejected_claims_claim_id ON claims.claim(id);
CREATE INDEX IF NOT EXISTS idx_rejected_claims_rejection_id ON claims.rejection(claim_id);
CREATE INDEX IF NOT EXISTS idx_rejected_claims_provider_id ON claims.provider(id);
CREATE INDEX IF NOT EXISTS idx_rejected_claims_facility_id ON claims.facility(id);
CREATE INDEX IF NOT EXISTS idx_rejected_claims_patient_id ON claims.patient(id);
CREATE INDEX IF NOT EXISTS idx_rejected_claims_rejection_date ON claims.rejection(rejection_date);
CREATE INDEX IF NOT EXISTS idx_rejected_claims_rejection_reason ON claims.rejection(rejection_reason);
CREATE INDEX IF NOT EXISTS idx_rejected_claims_rejection_code ON claims.rejection(rejection_code);
CREATE INDEX IF NOT EXISTS idx_rejected_claims_rejection_category ON claims.rejection(rejection_category);
CREATE INDEX IF NOT EXISTS idx_rejected_claims_claim_status ON claims.claim(status);

-- Comments and documentation
COMMENT ON VIEW claims.v_rejected_claims_report IS 'Comprehensive analysis of rejected claims including rejection reasons, patterns, and recovery opportunities';
COMMENT ON VIEW claims.v_rejected_claims_summary IS 'Summary statistics of rejected claims';
COMMENT ON VIEW claims.v_provider_rejection_analysis IS 'Provider-specific rejection analysis and patterns';
COMMENT ON VIEW claims.v_rejection_reason_analysis IS 'Analysis of rejection reasons with frequency and impact metrics';
COMMENT ON VIEW claims.v_monthly_rejection_trends IS 'Monthly trends in claim rejections';
COMMENT ON VIEW claims.v_recovery_opportunities IS 'Identified recovery opportunities for rejected claims';

-- Usage examples
/*
-- Get rejected claims report for specific provider
SELECT * FROM claims.v_rejected_claims_report 
WHERE provider_npi = '1234567890' 
ORDER BY rejection_date DESC;

-- Get rejected claims summary
SELECT * FROM claims.v_rejected_claims_summary;

-- Get provider rejection analysis
SELECT * FROM claims.v_provider_rejection_analysis 
WHERE total_rejected_claims >= 10 
ORDER BY total_rejected_amount DESC;

-- Get rejection reason analysis
SELECT * FROM claims.v_rejection_reason_analysis 
ORDER BY rejection_count DESC;

-- Get monthly rejection trends
SELECT * FROM claims.v_monthly_rejection_trends 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY report_month DESC;

-- Get high-value recovery opportunities
SELECT * FROM claims.v_recovery_opportunities 
WHERE recovery_probability = 'HIGH' 
    AND rejection_amount > 5000
ORDER BY rejection_amount DESC;
*/
