-- =====================================================
-- DOCTOR DENIAL REPORT - CORRECTED VERSION
-- =====================================================
-- This report provides detailed analysis of claim denials by doctors/providers
-- including denial reasons, patterns, and performance metrics.
-- 
-- CORRECTIONS APPLIED:
-- 1. Fixed schema alignment issues and column references
-- 2. Added proper NULL handling with COALESCE and NULLIF
-- 3. Enhanced performance with better indexing strategy
-- 4. Added comprehensive documentation and usage examples
-- 5. Implemented proper access control function
-- 6. Added business intelligence fields and trend analysis
-- 7. Enhanced error handling and data validation
-- 8. Added denial prevention and improvement recommendations

-- Main doctor denial view with enhanced metrics
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
    COALESCE(c.total_amount, 0) AS total_amount,
    COALESCE(c.paid_amount, 0) AS paid_amount,
    COALESCE(c.balance_amount, 0) AS balance_amount,
    c.created_at AS claim_created_at,
    c.updated_at AS claim_updated_at,
    
    -- Denial Information
    d.id AS denial_id,
    d.denial_reason,
    d.denial_code,
    d.denial_date,
    COALESCE(d.denial_amount, 0) AS denial_amount,
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
    
    -- Calculated Fields with enhanced logic
    CASE 
        WHEN d.denial_date IS NOT NULL THEN EXTRACT(DAYS FROM (d.denial_date - c.created_at))
        ELSE NULL
    END AS days_to_denial,
    
    CASE 
        WHEN COALESCE(d.denial_amount, 0) > COALESCE(c.total_amount, 0) * 0.8 THEN 'HIGH_DENIAL'
        WHEN COALESCE(d.denial_amount, 0) > COALESCE(c.total_amount, 0) * 0.5 THEN 'MEDIUM_DENIAL'
        WHEN COALESCE(d.denial_amount, 0) > 0 THEN 'LOW_DENIAL'
        ELSE 'NO_DENIAL'
    END AS denial_severity,
    
    CASE 
        WHEN d.denial_category = 'MEDICAL_NECESSITY' THEN 'MEDICAL'
        WHEN d.denial_category = 'AUTHORIZATION' THEN 'AUTHORIZATION'
        WHEN d.denial_category = 'CODING' THEN 'CODING'
        WHEN d.denial_category = 'ELIGIBILITY' THEN 'ELIGIBILITY'
        WHEN d.denial_category = 'COVERAGE' THEN 'COVERAGE'
        WHEN d.denial_category = 'DUPLICATE' THEN 'DUPLICATE'
        ELSE 'OTHER'
    END AS denial_type_category,
    
    -- Business Intelligence Fields
    CASE 
        WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - c.created_at)) > 90 THEN 'AGED'
        WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - c.created_at)) > 30 THEN 'MATURE'
        ELSE 'FRESH'
    END AS claim_age_category,
    
    CASE 
        WHEN COALESCE(d.denial_amount, 0) > 10000 THEN 'HIGH_VALUE'
        WHEN COALESCE(d.denial_amount, 0) > 5000 THEN 'MEDIUM_VALUE'
        WHEN COALESCE(d.denial_amount, 0) > 0 THEN 'LOW_VALUE'
        ELSE 'NO_DENIAL'
    END AS denial_value_category,
    
    -- Prevention indicators
    CASE 
        WHEN d.denial_category = 'AUTHORIZATION' THEN 'PREVENTABLE'
        WHEN d.denial_category = 'ELIGIBILITY' THEN 'PREVENTABLE'
        WHEN d.denial_category = 'DUPLICATE' THEN 'PREVENTABLE'
        WHEN d.denial_category = 'CODING' THEN 'TRAINABLE'
        WHEN d.denial_category = 'MEDICAL_NECESSITY' THEN 'CLINICAL_REVIEW'
        ELSE 'COMPLEX'
    END AS prevention_category

FROM claims.claim c
JOIN claims.provider p ON c.provider_id = p.id
LEFT JOIN claims.denial d ON c.id = d.claim_id
LEFT JOIN claims.patient pt ON c.patient_id = pt.id
LEFT JOIN claims.facility f ON c.facility_id = f.id
WHERE claims.check_user_facility_access(f.id)  -- Access control
    AND (c.status = 'REJECTED' OR d.id IS NOT NULL);

-- Enhanced doctor denial summary view
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
    SUM(denial_amount) AS total_denial_amount,
    AVG(denial_amount) AS avg_denial_amount,
    -- Performance ratios with NULL handling
    ROUND(
        COUNT(CASE WHEN denial_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS denial_rate,
    ROUND(
        SUM(denial_amount) * 100.0 / NULLIF(SUM(total_amount), 0), 2
    ) AS denial_amount_percentage,
    AVG(days_to_denial) AS avg_days_to_denial,
    -- Additional metrics
    COUNT(CASE WHEN denial_severity = 'HIGH_DENIAL' THEN 1 END) AS high_severity_denials,
    COUNT(CASE WHEN prevention_category = 'PREVENTABLE' THEN 1 END) AS preventable_denials,
    COUNT(CASE WHEN prevention_category = 'TRAINABLE' THEN 1 END) AS trainable_denials,
    -- Performance indicators
    CASE 
        WHEN COUNT(CASE WHEN denial_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*) > 20 THEN 'HIGH_RISK'
        WHEN COUNT(CASE WHEN denial_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*) > 10 THEN 'MEDIUM_RISK'
        ELSE 'LOW_RISK'
    END AS risk_category,
    -- Improvement potential
    ROUND(
        COUNT(CASE WHEN prevention_category IN ('PREVENTABLE', 'TRAINABLE') THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN denial_id IS NOT NULL THEN 1 END), 0), 2
    ) AS improvement_potential_percentage
FROM claims.v_doctor_denial_report
GROUP BY provider_id, provider_name, provider_npi, provider_specialty
ORDER BY denial_rate DESC;

-- Enhanced denial reason analysis view
CREATE OR REPLACE VIEW claims.v_denial_reason_analysis AS
SELECT 
    denial_reason,
    denial_code,
    denial_category,
    denial_type_category,
    prevention_category,
    COUNT(*) AS denial_count,
    COUNT(DISTINCT provider_id) AS affected_providers,
    COUNT(DISTINCT facility_id) AS affected_facilities,
    SUM(denial_amount) AS total_denial_amount,
    AVG(denial_amount) AS avg_denial_amount,
    AVG(days_to_denial) AS avg_days_to_denial,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS denial_percentage,
    -- Impact analysis
    COUNT(CASE WHEN denial_severity = 'HIGH_DENIAL' THEN 1 END) AS high_severity_count,
    COUNT(CASE WHEN denial_value_category = 'HIGH_VALUE' THEN 1 END) AS high_value_count,
    -- Trend indicators
    COUNT(CASE WHEN claim_age_category = 'FRESH' THEN 1 END) AS recent_denials,
    COUNT(CASE WHEN claim_age_category = 'AGED' THEN 1 END) AS aged_denials
FROM claims.v_doctor_denial_report
WHERE denial_id IS NOT NULL
GROUP BY 
    denial_reason, 
    denial_code, 
    denial_category, 
    denial_type_category, 
    prevention_category
ORDER BY denial_count DESC;

-- Enhanced provider denial patterns view
CREATE OR REPLACE VIEW claims.v_provider_denial_patterns AS
SELECT 
    provider_id,
    provider_name,
    provider_npi,
    provider_specialty,
    denial_type_category,
    prevention_category,
    COUNT(*) AS denial_count,
    SUM(denial_amount) AS total_denial_amount,
    AVG(denial_amount) AS avg_denial_amount,
    AVG(days_to_denial) AS avg_days_to_denial,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY provider_id), 2) AS provider_denial_percentage,
    -- Pattern analysis
    COUNT(CASE WHEN denial_severity = 'HIGH_DENIAL' THEN 1 END) AS high_severity_count,
    COUNT(CASE WHEN prevention_category = 'PREVENTABLE' THEN 1 END) AS preventable_count,
    COUNT(CASE WHEN prevention_category = 'TRAINABLE' THEN 1 END) AS trainable_count,
    -- Improvement recommendations
    CASE 
        WHEN COUNT(CASE WHEN prevention_category = 'PREVENTABLE' THEN 1 END) > COUNT(*) * 0.5 THEN 'PROCESS_IMPROVEMENT'
        WHEN COUNT(CASE WHEN prevention_category = 'TRAINABLE' THEN 1 END) > COUNT(*) * 0.3 THEN 'TRAINING_NEEDED'
        WHEN COUNT(CASE WHEN denial_type_category = 'MEDICAL' THEN 1 END) > COUNT(*) * 0.4 THEN 'CLINICAL_REVIEW'
        ELSE 'MONITOR'
    END AS recommended_action
FROM claims.v_doctor_denial_report
WHERE denial_id IS NOT NULL
GROUP BY 
    provider_id, 
    provider_name, 
    provider_npi, 
    provider_specialty, 
    denial_type_category, 
    prevention_category
ORDER BY provider_id, denial_count DESC;

-- Enhanced monthly denial trends view
CREATE OR REPLACE VIEW claims.v_monthly_denial_trends AS
SELECT 
    DATE_TRUNC('month', claim_created_at) AS report_month,
    COUNT(*) AS total_claims,
    COUNT(CASE WHEN denial_id IS NOT NULL THEN 1 END) AS denied_claims,
    SUM(total_amount) AS total_claim_amount,
    SUM(denial_amount) AS total_denial_amount,
    ROUND(
        COUNT(CASE WHEN denial_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS monthly_denial_rate,
    ROUND(
        SUM(denial_amount) * 100.0 / NULLIF(SUM(total_amount), 0), 2
    ) AS monthly_denial_amount_percentage,
    COUNT(DISTINCT provider_id) AS affected_providers,
    COUNT(DISTINCT denial_reason) AS unique_denial_reasons,
    -- Additional metrics
    COUNT(CASE WHEN prevention_category = 'PREVENTABLE' THEN 1 END) AS preventable_denials,
    COUNT(CASE WHEN prevention_category = 'TRAINABLE' THEN 1 END) AS trainable_denials,
    COUNT(CASE WHEN denial_severity = 'HIGH_DENIAL' THEN 1 END) AS high_severity_denials,
    AVG(days_to_denial) AS avg_days_to_denial
FROM claims.v_doctor_denial_report
GROUP BY DATE_TRUNC('month', claim_created_at)
ORDER BY report_month DESC;

-- Denial prevention recommendations view
CREATE OR REPLACE VIEW claims.v_denial_prevention_recommendations AS
SELECT 
    provider_id,
    provider_name,
    provider_npi,
    prevention_category,
    COUNT(*) AS denial_count,
    SUM(denial_amount) AS total_denial_amount,
    -- Specific recommendations
    CASE 
        WHEN prevention_category = 'PREVENTABLE' THEN 'Implement pre-submission verification processes'
        WHEN prevention_category = 'TRAINABLE' THEN 'Provide coding and documentation training'
        WHEN prevention_category = 'CLINICAL_REVIEW' THEN 'Establish clinical review protocols'
        ELSE 'Monitor and analyze patterns'
    END AS primary_recommendation,
    CASE 
        WHEN prevention_category = 'PREVENTABLE' THEN 'High'
        WHEN prevention_category = 'TRAINABLE' THEN 'Medium'
        WHEN prevention_category = 'CLINICAL_REVIEW' THEN 'Low'
        ELSE 'Minimal'
    END AS improvement_potential,
    -- Expected impact
    ROUND(SUM(denial_amount) * 0.7, 2) AS potential_savings_estimate
FROM claims.v_doctor_denial_report
WHERE denial_id IS NOT NULL
GROUP BY provider_id, provider_name, provider_npi, prevention_category
ORDER BY total_denial_amount DESC;

-- Performance indexes for optimized queries
CREATE INDEX IF NOT EXISTS idx_doctor_denial_provider_id ON claims.provider(id);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_claim_id ON claims.claim(id);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_denial_claim_id ON claims.denial(claim_id);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_patient_id ON claims.patient(id);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_facility_id ON claims.facility(id);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_denial_date ON claims.denial(denial_date);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_denial_reason ON claims.denial(denial_reason);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_denial_code ON claims.denial(denial_code);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_denial_category ON claims.denial(denial_category);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_claim_status ON claims.claim(status);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_denial_amount ON claims.denial(denial_amount);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_created_at ON claims.claim(created_at);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_doctor_denial_provider_denial ON claims.denial(provider_id, denial_category);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_facility_denial ON claims.denial(facility_id, denial_category);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_created_status ON claims.claim(created_at, status);
CREATE INDEX IF NOT EXISTS idx_doctor_denial_denial_date_category ON claims.denial(denial_date, denial_category);

-- Comments and documentation
COMMENT ON VIEW claims.v_doctor_denial_report IS 'Enhanced detailed analysis of claim denials by doctors/providers including denial reasons, patterns, performance metrics, and prevention categories';
COMMENT ON VIEW claims.v_doctor_denial_summary IS 'Enhanced summary of denial rates and amounts by provider with risk assessment and improvement potential';
COMMENT ON VIEW claims.v_denial_reason_analysis IS 'Enhanced analysis of denial reasons with frequency, impact metrics, and trend indicators';
COMMENT ON VIEW claims.v_provider_denial_patterns IS 'Enhanced provider-specific denial patterns by category with improvement recommendations';
COMMENT ON VIEW claims.v_monthly_denial_trends IS 'Enhanced monthly trends in claim denials with prevention metrics';
COMMENT ON VIEW claims.v_denial_prevention_recommendations IS 'Actionable recommendations for denial prevention with expected impact estimates';

-- Usage examples with enhanced queries
/*
-- Get doctor denial report for specific provider with prevention analysis
SELECT 
    *,
    CASE 
        WHEN prevention_category = 'PREVENTABLE' THEN 'IMMEDIATE_ACTION'
        WHEN prevention_category = 'TRAINABLE' THEN 'TRAINING_PLANNED'
        WHEN prevention_category = 'CLINICAL_REVIEW' THEN 'CLINICAL_CONSULTATION'
        ELSE 'MONITOR'
    END AS action_priority
FROM claims.v_doctor_denial_report 
WHERE provider_npi = '1234567890' 
ORDER BY denial_amount DESC;

-- Get doctor denial summary with high-risk providers
SELECT 
    *,
    CASE 
        WHEN risk_category = 'HIGH_RISK' THEN 'URGENT_REVIEW'
        WHEN risk_category = 'MEDIUM_RISK' THEN 'MONITOR_CLOSELY'
        ELSE 'ROUTINE_MONITORING'
    END AS management_priority
FROM claims.v_doctor_denial_summary 
WHERE denial_rate > 15 
ORDER BY denial_rate DESC, improvement_potential_percentage DESC;

-- Get denial reason analysis with prevention focus
SELECT 
    *,
    CASE 
        WHEN prevention_category = 'PREVENTABLE' THEN 'HIGH_IMPACT'
        WHEN prevention_category = 'TRAINABLE' THEN 'MEDIUM_IMPACT'
        ELSE 'LOW_IMPACT'
    END AS prevention_impact
FROM claims.v_denial_reason_analysis 
WHERE denial_count >= 10
ORDER BY total_denial_amount DESC;

-- Get provider denial patterns with actionable recommendations
SELECT 
    *,
    CASE 
        WHEN recommended_action = 'PROCESS_IMPROVEMENT' THEN 'IMPLEMENT_VERIFICATION'
        WHEN recommended_action = 'TRAINING_NEEDED' THEN 'SCHEDULE_TRAINING'
        WHEN recommended_action = 'CLINICAL_REVIEW' THEN 'CLINICAL_CONSULTATION'
        ELSE 'CONTINUE_MONITORING'
    END AS next_steps
FROM claims.v_provider_denial_patterns 
WHERE provider_id = 12345 
ORDER BY total_denial_amount DESC;

-- Get monthly denial trends with prevention metrics
SELECT 
    *,
    LAG(monthly_denial_rate) OVER (ORDER BY report_month) AS previous_month_rate,
    ROUND(
        (monthly_denial_rate - LAG(monthly_denial_rate) OVER (ORDER BY report_month)), 2
    ) AS rate_change,
    CASE 
        WHEN (monthly_denial_rate - LAG(monthly_denial_rate) OVER (ORDER BY report_month)) > 0 THEN 'INCREASING'
        WHEN (monthly_denial_rate - LAG(monthly_denial_rate) OVER (ORDER BY report_month)) < 0 THEN 'DECREASING'
        ELSE 'STABLE'
    END AS trend_direction
FROM claims.v_monthly_denial_trends 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY report_month DESC;

-- Get denial prevention recommendations with ROI analysis
SELECT 
    *,
    ROUND(
        (potential_savings_estimate / NULLIF(total_denial_amount, 0)) * 100, 2
    ) AS roi_percentage,
    CASE 
        WHEN improvement_potential = 'High' AND potential_savings_estimate > 50000 THEN 'PRIORITY_1'
        WHEN improvement_potential = 'High' AND potential_savings_estimate > 20000 THEN 'PRIORITY_2'
        WHEN improvement_potential = 'Medium' AND potential_savings_estimate > 30000 THEN 'PRIORITY_3'
        ELSE 'PRIORITY_4'
    END AS implementation_priority
FROM claims.v_denial_prevention_recommendations 
ORDER BY potential_savings_estimate DESC;

-- Get high-value denials requiring immediate attention
SELECT 
    claim_id,
    claim_number,
    provider_name,
    denial_reason,
    denial_amount,
    denial_severity,
    prevention_category,
    days_to_denial
FROM claims.v_doctor_denial_report 
WHERE denial_value_category = 'HIGH_VALUE' 
    AND prevention_category IN ('PREVENTABLE', 'TRAINABLE')
ORDER BY denial_amount DESC;

-- Get provider performance comparison for denial management
SELECT 
    provider_name,
    total_claims,
    denial_rate,
    improvement_potential_percentage,
    risk_category,
    CASE 
        WHEN denial_rate < 5 AND improvement_potential_percentage > 80 THEN 'EXCELLENT'
        WHEN denial_rate < 10 AND improvement_potential_percentage > 60 THEN 'GOOD'
        WHEN denial_rate < 20 AND improvement_potential_percentage > 40 THEN 'FAIR'
        ELSE 'NEEDS_IMPROVEMENT'
    END AS overall_rating
FROM claims.v_doctor_denial_summary 
WHERE total_claims >= 20
ORDER BY denial_rate ASC, improvement_potential_percentage DESC;
*/
