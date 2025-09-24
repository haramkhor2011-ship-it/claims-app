-- =====================================================
-- DOCTOR DENIAL REPORT
-- =====================================================
-- This report provides detailed analysis of claim denials by doctors/providers
-- including denial reasons, patterns, and performance metrics.

-- Main doctor denial view
CREATE OR REPLACE VIEW claims.v_doctor_denial_report AS
SELECT 
    -- Provider Information
    p.id AS provider_id,
    p.name AS provider_name,
    p.npi AS provider_npi,
    p.specialty AS provider_specialty,
    p.license_number,
    p.phone AS provider_phone,
    p.email AS provider_email,
    
    -- Claim Information
    c.id AS claim_id,
    c.claim_number,
    c.claim_type,
    c.status AS claim_status,
    c.total_amount,
    c.paid_amount,
    c.balance_amount,
    c.created_at AS claim_created_at,
    c.updated_at AS claim_updated_at,
    
    -- Denial Information
    d.id AS denial_id,
    d.denial_reason,
    d.denial_code,
    d.denial_date,
    d.denial_amount,
    d.denial_category,
    d.denial_description,
    d.created_at AS denial_created_at,
    
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
        WHEN d.denial_date IS NOT NULL THEN EXTRACT(DAYS FROM (d.denial_date - c.created_at))
        ELSE NULL
    END AS days_to_denial,
    
    CASE 
        WHEN d.denial_amount > c.total_amount * 0.8 THEN 'HIGH_DENIAL'
        WHEN d.denial_amount > c.total_amount * 0.5 THEN 'MEDIUM_DENIAL'
        WHEN d.denial_amount > 0 THEN 'LOW_DENIAL'
        ELSE 'NO_DENIAL'
    END AS denial_severity,
    
    CASE 
        WHEN d.denial_category = 'MEDICAL_NECESSITY' THEN 'MEDICAL'
        WHEN d.denial_category = 'AUTHORIZATION' THEN 'AUTHORIZATION'
        WHEN d.denial_category = 'CODING' THEN 'CODING'
        WHEN d.denial_category = 'ELIGIBILITY' THEN 'ELIGIBILITY'
        ELSE 'OTHER'
    END AS denial_type_category

FROM claims.claim c
JOIN claims.provider p ON c.provider_id = p.id
LEFT JOIN claims.denial d ON c.id = d.claim_id
LEFT JOIN claims.patient pt ON c.patient_id = pt.id
LEFT JOIN claims.facility f ON c.facility_id = f.id
WHERE claims.check_user_facility_access(f.id)
    AND (c.status = 'REJECTED' OR d.id IS NOT NULL);

-- Doctor denial summary view
CREATE OR REPLACE VIEW claims.v_doctor_denial_summary AS
SELECT 
    provider_id,
    provider_name,
    provider_npi,
    provider_specialty,
    COUNT(*) AS total_claims,
    COUNT(CASE WHEN denial_id IS NOT NULL THEN 1 END) AS denied_claims,
    COUNT(CASE WHEN denial_id IS NULL THEN 1 END) AS non_denied_claims,
    SUM(total_amount) AS total_claim_amount,
    SUM(COALESCE(denial_amount, 0)) AS total_denial_amount,
    AVG(COALESCE(denial_amount, 0)) AS avg_denial_amount,
    ROUND(
        COUNT(CASE WHEN denial_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS denial_rate,
    ROUND(
        SUM(COALESCE(denial_amount, 0)) * 100.0 / SUM(total_amount), 2
    ) AS denial_amount_percentage,
    AVG(COALESCE(days_to_denial, 0)) AS avg_days_to_denial
FROM claims.v_doctor_denial_report
GROUP BY provider_id, provider_name, provider_npi, provider_specialty
ORDER BY denial_rate DESC;

-- Denial reason analysis view
CREATE OR REPLACE VIEW claims.v_denial_reason_analysis AS
SELECT 
    denial_reason,
    denial_code,
    denial_category,
    denial_type_category,
    COUNT(*) AS denial_count,
    COUNT(DISTINCT provider_id) AS affected_providers,
    SUM(denial_amount) AS total_denial_amount,
    AVG(denial_amount) AS avg_denial_amount,
    AVG(days_to_denial) AS avg_days_to_denial,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS denial_percentage
FROM claims.v_doctor_denial_report
WHERE denial_id IS NOT NULL
GROUP BY denial_reason, denial_code, denial_category, denial_type_category
ORDER BY denial_count DESC;

-- Provider denial patterns view
CREATE OR REPLACE VIEW claims.v_provider_denial_patterns AS
SELECT 
    provider_id,
    provider_name,
    provider_npi,
    provider_specialty,
    denial_type_category,
    COUNT(*) AS denial_count,
    SUM(denial_amount) AS total_denial_amount,
    AVG(denial_amount) AS avg_denial_amount,
    AVG(days_to_denial) AS avg_days_to_denial,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY provider_id), 2) AS provider_denial_percentage
FROM claims.v_doctor_denial_report
WHERE denial_id IS NOT NULL
GROUP BY provider_id, provider_name, provider_npi, provider_specialty, denial_type_category
ORDER BY provider_id, denial_count DESC;

-- Monthly denial trends view
CREATE OR REPLACE VIEW claims.v_monthly_denial_trends AS
SELECT 
    DATE_TRUNC('month', claim_created_at) AS report_month,
    COUNT(*) AS total_claims,
    COUNT(CASE WHEN denial_id IS NOT NULL THEN 1 END) AS denied_claims,
    SUM(total_amount) AS total_claim_amount,
    SUM(COALESCE(denial_amount, 0)) AS total_denial_amount,
    ROUND(
        COUNT(CASE WHEN denial_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS monthly_denial_rate,
    ROUND(
        SUM(COALESCE(denial_amount, 0)) * 100.0 / SUM(total_amount), 2
    ) AS monthly_denial_amount_percentage,
    COUNT(DISTINCT provider_id) AS affected_providers,
    COUNT(DISTINCT denial_reason) AS unique_denial_reasons
FROM claims.v_doctor_denial_report
GROUP BY DATE_TRUNC('month', claim_created_at)
ORDER BY report_month DESC;

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_doctor_denial_provider_id ON claims.provider(id);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_claim_id ON claims.claim(id);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_denial_id ON claims.denial(claim_id);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_patient_id ON claims.patient(id);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_facility_id ON claims.facility(id);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_denial_date ON claims.denial(denial_date);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_denial_reason ON claims.denial(denial_reason);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_denial_code ON claims.denial(denial_code);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_denial_category ON claims.denial(denial_category);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_claim_status ON claims.claim(status);

-- Comments and documentation
COMMENT ON VIEW claims.v_doctor_denial_report IS 'Detailed analysis of claim denials by doctors/providers including denial reasons, patterns, and performance metrics';
COMMENT ON VIEW claims.v_doctor_denial_summary IS 'Summary of denial rates and amounts by provider';
COMMENT ON VIEW claims.v_denial_reason_analysis IS 'Analysis of denial reasons with frequency and impact metrics';
COMMENT ON VIEW claims.v_provider_denial_patterns IS 'Provider-specific denial patterns by category';
COMMENT ON VIEW claims.v_monthly_denial_trends IS 'Monthly trends in claim denials';

-- Usage examples
/*
-- Get doctor denial report for specific provider
SELECT * FROM claims.v_doctor_denial_report 
WHERE provider_npi = '1234567890' 
ORDER BY denial_date DESC;

-- Get doctor denial summary with high denial rates
SELECT * FROM claims.v_doctor_denial_summary 
WHERE denial_rate > 20 
ORDER BY denial_rate DESC;

-- Get denial reason analysis
SELECT * FROM claims.v_denial_reason_analysis 
ORDER BY denial_count DESC;

-- Get provider denial patterns
SELECT * FROM claims.v_provider_denial_patterns 
WHERE provider_id = 12345 
ORDER BY denial_count DESC;

-- Get monthly denial trends
SELECT * FROM claims.v_monthly_denial_trends 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY report_month DESC;

-- Get high-severity denials
SELECT * FROM claims.v_doctor_denial_report 
WHERE denial_severity IN ('HIGH_DENIAL', 'MEDIUM_DENIAL')
ORDER BY denial_amount DESC;
*/
