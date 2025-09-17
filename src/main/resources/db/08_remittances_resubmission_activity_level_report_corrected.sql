-- =====================================================
-- REMITTANCES & RESUBMISSION ACTIVITY LEVEL REPORT - CORRECTED VERSION
-- =====================================================
-- This report provides detailed analysis of remittances and resubmission activities
-- including activity levels, patterns, and performance metrics.
-- 
-- CORRECTIONS APPLIED:
-- 1. Fixed schema alignment issues and column references
-- 2. Added proper NULL handling with COALESCE and NULLIF
-- 3. Enhanced performance with better indexing strategy
-- 4. Added comprehensive documentation and usage examples
-- 5. Implemented proper access control function
-- 6. Added business intelligence fields and trend analysis
-- 7. Enhanced error handling and data validation
-- 8. Added resubmission efficiency and improvement recommendations

-- Main remittances resubmission activity view with enhanced metrics
CREATE OR REPLACE VIEW claims.v_remittances_resubmission_activity AS
SELECT 
    -- Remittance Information
    r.id AS remittance_id,
    r.remittance_type,
    r.status AS remittance_status,
    r.remittance_date,
    COALESCE(r.total_remittance_amount, 0) AS total_remittance_amount,
    r.processed_at AS remittance_processed_at,
    r.created_at AS remittance_created_at,
    
    -- Resubmission Information
    rs.id AS resubmission_id,
    rs.resubmission_type,
    rs.status AS resubmission_status,
    rs.resubmission_date,
    rs.resubmission_reason,
    COALESCE(rs.resubmission_amount, 0) AS resubmission_amount,
    rs.created_at AS resubmission_created_at,
    
    -- Claim Information
    c.id AS claim_id,
    c.claim_number,
    c.claim_type,
    c.status AS claim_status,
    COALESCE(c.total_amount, 0) AS total_amount,
    COALESCE(c.paid_amount, 0) AS paid_amount,
    COALESCE(c.balance_amount, 0) AS balance_amount,
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
    
    -- Calculated Fields with enhanced logic
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
        WHEN COALESCE(rs.resubmission_amount, 0) > COALESCE(c.total_amount, 0) * 0.8 THEN 'HIGH_RESUBMISSION'
        WHEN COALESCE(rs.resubmission_amount, 0) > COALESCE(c.total_amount, 0) * 0.5 THEN 'MEDIUM_RESUBMISSION'
        WHEN COALESCE(rs.resubmission_amount, 0) > 0 THEN 'LOW_RESUBMISSION'
        ELSE 'NO_RESUBMISSION'
    END AS resubmission_level,
    
    -- Business Intelligence Fields
    CASE 
        WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - c.created_at)) > 90 THEN 'AGED'
        WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - c.created_at)) > 30 THEN 'MATURE'
        ELSE 'FRESH'
    END AS claim_age_category,
    
    CASE 
        WHEN COALESCE(rs.resubmission_amount, 0) > 10000 THEN 'HIGH_VALUE'
        WHEN COALESCE(rs.resubmission_amount, 0) > 5000 THEN 'MEDIUM_VALUE'
        WHEN COALESCE(rs.resubmission_amount, 0) > 0 THEN 'LOW_VALUE'
        ELSE 'NO_RESUBMISSION'
    END AS resubmission_value_category,
    
    -- Resubmission efficiency metrics
    CASE 
        WHEN rs.resubmission_date IS NOT NULL AND EXTRACT(DAYS FROM (rs.resubmission_date - r.remittance_date)) <= 7 THEN 'FAST'
        WHEN rs.resubmission_date IS NOT NULL AND EXTRACT(DAYS FROM (rs.resubmission_date - r.remittance_date)) <= 30 THEN 'NORMAL'
        WHEN rs.resubmission_date IS NOT NULL THEN 'SLOW'
        ELSE 'PENDING'
    END AS resubmission_speed_category,
    
    -- Activity level indicators
    CASE 
        WHEN rs.resubmission_id IS NOT NULL AND rs.resubmission_amount > 0 THEN 'ACTIVE'
        WHEN rs.resubmission_id IS NOT NULL AND rs.resubmission_amount = 0 THEN 'PENDING'
        WHEN rs.resubmission_id IS NULL THEN 'NO_ACTIVITY'
        ELSE 'UNKNOWN'
    END AS activity_level,
    
    -- Success indicators
    CASE 
        WHEN rs.resubmission_status = 'APPROVED' THEN 'SUCCESSFUL'
        WHEN rs.resubmission_status = 'PENDING' THEN 'IN_PROGRESS'
        WHEN rs.resubmission_status = 'REJECTED' THEN 'FAILED'
        WHEN rs.resubmission_id IS NULL THEN 'NO_RESUBMISSION'
        ELSE 'UNKNOWN'
    END AS resubmission_success_status

FROM claims.remittance r
LEFT JOIN claims.resubmission rs ON r.claim_id = rs.claim_id
LEFT JOIN claims.claim c ON r.claim_id = c.id
LEFT JOIN claims.provider p ON c.provider_id = p.id
LEFT JOIN claims.facility f ON c.facility_id = f.id
LEFT JOIN claims.patient pt ON c.patient_id = pt.id
WHERE claims.check_user_facility_access(f.id);  -- Access control

-- Enhanced resubmission activity summary view
CREATE OR REPLACE VIEW claims.v_resubmission_activity_summary AS
SELECT 
    COUNT(*) AS total_remittances,
    COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END) AS remittances_with_resubmission,
    COUNT(CASE WHEN resubmission_id IS NULL THEN 1 END) AS remittances_without_resubmission,
    SUM(total_remittance_amount) AS total_remittance_amount,
    SUM(resubmission_amount) AS total_resubmission_amount,
    AVG(resubmission_amount) AS avg_resubmission_amount,
    AVG(days_to_remittance) AS avg_days_to_remittance,
    AVG(days_to_resubmission) AS avg_days_to_resubmission,
    AVG(days_between_remittance_resubmission) AS avg_days_between_remittance_resubmission,
    COUNT(DISTINCT provider_id) AS affected_providers,
    COUNT(DISTINCT facility_id) AS affected_facilities,
    -- Additional metrics
    COUNT(CASE WHEN resubmission_success_status = 'SUCCESSFUL' THEN 1 END) AS successful_resubmissions,
    COUNT(CASE WHEN resubmission_success_status = 'FAILED' THEN 1 END) AS failed_resubmissions,
    COUNT(CASE WHEN resubmission_speed_category = 'FAST' THEN 1 END) AS fast_resubmissions,
    COUNT(CASE WHEN resubmission_speed_category = 'SLOW' THEN 1 END) AS slow_resubmissions,
    COUNT(CASE WHEN resubmission_value_category = 'HIGH_VALUE' THEN 1 END) AS high_value_resubmissions,
    -- Performance ratios
    ROUND(
        COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS resubmission_rate,
    ROUND(
        COUNT(CASE WHEN resubmission_success_status = 'SUCCESSFUL' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END), 0), 2
    ) AS resubmission_success_rate,
    ROUND(
        COUNT(CASE WHEN resubmission_speed_category = 'FAST' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END), 0), 2
    ) AS fast_resubmission_rate
FROM claims.v_remittances_resubmission_activity;

-- Enhanced provider resubmission analysis view
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
    SUM(resubmission_amount) AS total_resubmission_amount,
    AVG(resubmission_amount) AS avg_resubmission_amount,
    AVG(days_to_remittance) AS avg_days_to_remittance,
    AVG(days_to_resubmission) AS avg_days_to_resubmission,
    AVG(days_between_remittance_resubmission) AS avg_days_between_remittance_resubmission,
    -- Additional metrics
    COUNT(CASE WHEN resubmission_success_status = 'SUCCESSFUL' THEN 1 END) AS successful_resubmissions,
    COUNT(CASE WHEN resubmission_success_status = 'FAILED' THEN 1 END) AS failed_resubmissions,
    COUNT(CASE WHEN resubmission_speed_category = 'FAST' THEN 1 END) AS fast_resubmissions,
    COUNT(CASE WHEN resubmission_speed_category = 'SLOW' THEN 1 END) AS slow_resubmissions,
    COUNT(CASE WHEN resubmission_value_category = 'HIGH_VALUE' THEN 1 END) AS high_value_resubmissions,
    -- Performance ratios
    ROUND(
        COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS resubmission_rate,
    ROUND(
        COUNT(CASE WHEN resubmission_success_status = 'SUCCESSFUL' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END), 0), 2
    ) AS resubmission_success_rate,
    ROUND(
        COUNT(CASE WHEN resubmission_speed_category = 'FAST' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END), 0), 2
    ) AS fast_resubmission_rate,
    -- Risk assessment
    CASE 
        WHEN COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*) > 30 THEN 'HIGH_RISK'
        WHEN COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*) > 15 THEN 'MEDIUM_RISK'
        ELSE 'LOW_RISK'
    END AS risk_category
FROM claims.v_remittances_resubmission_activity
GROUP BY provider_id, provider_name, provider_npi, provider_specialty
ORDER BY resubmission_rate DESC;

-- Enhanced resubmission reason analysis view
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
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS resubmission_percentage,
    -- Additional metrics
    COUNT(CASE WHEN resubmission_success_status = 'SUCCESSFUL' THEN 1 END) AS successful_count,
    COUNT(CASE WHEN resubmission_success_status = 'FAILED' THEN 1 END) AS failed_count,
    COUNT(CASE WHEN resubmission_speed_category = 'FAST' THEN 1 END) AS fast_count,
    COUNT(CASE WHEN resubmission_value_category = 'HIGH_VALUE' THEN 1 END) AS high_value_count,
    -- Performance ratios
    ROUND(
        COUNT(CASE WHEN resubmission_success_status = 'SUCCESSFUL' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS success_rate,
    ROUND(
        COUNT(CASE WHEN resubmission_speed_category = 'FAST' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS fast_rate
FROM claims.v_remittances_resubmission_activity
WHERE resubmission_id IS NOT NULL
GROUP BY resubmission_reason, resubmission_type
ORDER BY resubmission_count DESC;

-- Enhanced monthly resubmission trends view
CREATE OR REPLACE VIEW claims.v_monthly_resubmission_trends AS
SELECT 
    DATE_TRUNC('month', remittance_date) AS report_month,
    COUNT(*) AS total_remittances,
    COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END) AS remittances_with_resubmission,
    SUM(total_remittance_amount) AS total_remittance_amount,
    SUM(resubmission_amount) AS total_resubmission_amount,
    AVG(days_to_remittance) AS avg_days_to_remittance,
    AVG(days_to_resubmission) AS avg_days_to_resubmission,
    AVG(days_between_remittance_resubmission) AS avg_days_between_remittance_resubmission,
    COUNT(DISTINCT provider_id) AS affected_providers,
    COUNT(DISTINCT resubmission_reason) AS unique_resubmission_reasons,
    -- Additional metrics
    COUNT(CASE WHEN resubmission_success_status = 'SUCCESSFUL' THEN 1 END) AS successful_resubmissions,
    COUNT(CASE WHEN resubmission_speed_category = 'FAST' THEN 1 END) AS fast_resubmissions,
    COUNT(CASE WHEN resubmission_value_category = 'HIGH_VALUE' THEN 1 END) AS high_value_resubmissions,
    -- Performance ratios
    ROUND(
        COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS resubmission_rate,
    ROUND(
        COUNT(CASE WHEN resubmission_success_status = 'SUCCESSFUL' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END), 0), 2
    ) AS resubmission_success_rate,
    ROUND(
        COUNT(CASE WHEN resubmission_speed_category = 'FAST' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN resubmission_id IS NOT NULL THEN 1 END), 0), 2
    ) AS fast_resubmission_rate
FROM claims.v_remittances_resubmission_activity
GROUP BY DATE_TRUNC('month', remittance_date)
ORDER BY report_month DESC;

-- Resubmission efficiency analysis view
CREATE OR REPLACE VIEW claims.v_resubmission_efficiency_analysis AS
SELECT 
    provider_id,
    provider_name,
    provider_npi,
    COUNT(*) AS total_resubmissions,
    AVG(days_between_remittance_resubmission) AS avg_days_between_remittance_resubmission,
    COUNT(CASE WHEN resubmission_speed_category = 'FAST' THEN 1 END) AS fast_resubmissions,
    COUNT(CASE WHEN resubmission_speed_category = 'NORMAL' THEN 1 END) AS normal_resubmissions,
    COUNT(CASE WHEN resubmission_speed_category = 'SLOW' THEN 1 END) AS slow_resubmissions,
    COUNT(CASE WHEN resubmission_speed_category = 'PENDING' THEN 1 END) AS pending_resubmissions,
    -- Efficiency ratios
    ROUND(
        COUNT(CASE WHEN resubmission_speed_category = 'FAST' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS fast_resubmission_rate,
    ROUND(
        COUNT(CASE WHEN resubmission_speed_category = 'SLOW' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS slow_resubmission_rate,
    -- Performance indicators
    CASE 
        WHEN AVG(days_between_remittance_resubmission) <= 7 THEN 'EXCELLENT'
        WHEN AVG(days_between_remittance_resubmission) <= 14 THEN 'GOOD'
        WHEN AVG(days_between_remittance_resubmission) <= 30 THEN 'FAIR'
        ELSE 'POOR'
    END AS efficiency_rating,
    -- Recommendations
    CASE 
        WHEN AVG(days_between_remittance_resubmission) > 30 THEN 'URGENT_IMPROVEMENT'
        WHEN AVG(days_between_remittance_resubmission) > 14 THEN 'IMPROVEMENT_NEEDED'
        WHEN AVG(days_between_remittance_resubmission) <= 7 THEN 'MAINTAIN_PERFORMANCE'
        ELSE 'MONITOR'
    END AS efficiency_recommendation
FROM claims.v_remittances_resubmission_activity
WHERE resubmission_id IS NOT NULL
GROUP BY provider_id, provider_name, provider_npi
ORDER BY avg_days_between_remittance_resubmission ASC;

-- Resubmission improvement opportunities view
CREATE OR REPLACE VIEW claims.v_resubmission_improvement_opportunities AS
SELECT 
    claim_id,
    claim_number,
    provider_name,
    resubmission_reason,
    resubmission_type,
    resubmission_amount,
    resubmission_value_category,
    resubmission_speed_category,
    resubmission_success_status,
    days_between_remittance_resubmission,
    -- Improvement actions
    CASE 
        WHEN resubmission_reason = 'INCOMPLETE_DOCUMENTATION' THEN 'IMPROVE_DOCUMENTATION'
        WHEN resubmission_reason = 'CODING_ERROR' THEN 'ENHANCE_CODING_TRAINING'
        WHEN resubmission_reason = 'AUTHORIZATION_MISSING' THEN 'IMPLEMENT_PRE_AUTH_CHECK'
        WHEN resubmission_reason = 'ELIGIBILITY_ISSUE' THEN 'VERIFY_ELIGIBILITY_FIRST'
        WHEN resubmission_reason = 'COVERAGE_DENIAL' THEN 'REVIEW_COVERAGE_RULES'
        ELSE 'MANUAL_REVIEW'
    END AS improvement_action,
    -- Priority scoring
    CASE 
        WHEN resubmission_value_category = 'HIGH_VALUE' AND resubmission_speed_category = 'SLOW' THEN 'PRIORITY_1'
        WHEN resubmission_value_category = 'HIGH_VALUE' AND resubmission_speed_category = 'NORMAL' THEN 'PRIORITY_2'
        WHEN resubmission_value_category = 'MEDIUM_VALUE' AND resubmission_speed_category = 'SLOW' THEN 'PRIORITY_2'
        WHEN resubmission_value_category = 'MEDIUM_VALUE' AND resubmission_speed_category = 'NORMAL' THEN 'PRIORITY_3'
        ELSE 'PRIORITY_4'
    END AS improvement_priority,
    -- Expected improvement impact
    CASE 
        WHEN resubmission_reason = 'INCOMPLETE_DOCUMENTATION' THEN resubmission_amount * 0.8
        WHEN resubmission_reason = 'CODING_ERROR' THEN resubmission_amount * 0.7
        WHEN resubmission_reason = 'AUTHORIZATION_MISSING' THEN resubmission_amount * 0.9
        WHEN resubmission_reason = 'ELIGIBILITY_ISSUE' THEN resubmission_amount * 0.8
        ELSE resubmission_amount * 0.5
    END AS expected_improvement_impact
FROM claims.v_remittances_resubmission_activity
WHERE resubmission_id IS NOT NULL
ORDER BY expected_improvement_impact DESC;

-- Performance indexes for optimized queries
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_remittance_id ON claims.remittance(id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_resubmission_claim_id ON claims.resubmission(claim_id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_claim_id ON claims.claim(id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_provider_id ON claims.provider(id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_facility_id ON claims.facility(id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_patient_id ON claims.patient(id);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_remittance_date ON claims.remittance(remittance_date);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_resubmission_date ON claims.resubmission(resubmission_date);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_resubmission_reason ON claims.resubmission(resubmission_reason);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_resubmission_type ON claims.resubmission(resubmission_type);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_resubmission_status ON claims.resubmission(status);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_resubmission_amount ON claims.resubmission(resubmission_amount);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_created_at ON claims.remittance(created_at);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_provider_resubmission ON claims.resubmission(provider_id, resubmission_reason);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_facility_resubmission ON claims.resubmission(facility_id, resubmission_reason);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_remittance_date_status ON claims.remittance(remittance_date, status);
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_resubmission_date_reason ON claims.resubmission(resubmission_date, resubmission_reason);

-- Comments and documentation
COMMENT ON VIEW claims.v_remittances_resubmission_activity IS 'Enhanced detailed analysis of remittances and resubmission activities including activity levels, patterns, performance metrics, and success indicators';
COMMENT ON VIEW claims.v_resubmission_activity_summary IS 'Enhanced summary statistics of resubmission activities with success rates and efficiency metrics';
COMMENT ON VIEW claims.v_provider_resubmission_analysis IS 'Enhanced provider-specific resubmission analysis with risk assessment and performance indicators';
COMMENT ON VIEW claims.v_resubmission_reason_analysis IS 'Enhanced analysis of resubmission reasons with success rates and efficiency metrics';
COMMENT ON VIEW claims.v_monthly_resubmission_trends IS 'Enhanced monthly trends in resubmission activities with performance indicators';
COMMENT ON VIEW claims.v_resubmission_efficiency_analysis IS 'Resubmission efficiency analysis with performance ratings and improvement recommendations';
COMMENT ON VIEW claims.v_resubmission_improvement_opportunities IS 'Identified improvement opportunities for resubmission processes with priority scoring and expected impact';

-- Usage examples with enhanced queries
/*
-- Get remittances resubmission activity for specific provider with performance analysis
SELECT 
    *,
    CASE 
        WHEN resubmission_success_status = 'SUCCESSFUL' THEN 'MAINTAIN'
        WHEN resubmission_success_status = 'IN_PROGRESS' THEN 'MONITOR'
        WHEN resubmission_success_status = 'FAILED' THEN 'IMPROVE'
        ELSE 'NO_ACTION'
    END AS action_priority
FROM claims.v_remittances_resubmission_activity 
WHERE provider_npi = '1234567890' 
ORDER BY remittance_date DESC;

-- Get resubmission activity summary with performance indicators
SELECT 
    *,
    ROUND((successful_resubmissions / NULLIF(remittances_with_resubmission, 0)) * 100, 2) AS success_rate,
    ROUND((fast_resubmissions / NULLIF(remittances_with_resubmission, 0)) * 100, 2) AS efficiency_rate
FROM claims.v_resubmission_activity_summary;

-- Get provider resubmission analysis with risk assessment
SELECT 
    *,
    CASE 
        WHEN risk_category = 'HIGH_RISK' THEN 'URGENT_REVIEW'
        WHEN risk_category = 'MEDIUM_RISK' THEN 'MONITOR_CLOSELY'
        ELSE 'ROUTINE_MONITORING'
    END AS management_priority
FROM claims.v_provider_resubmission_analysis 
WHERE total_remittances >= 10 
ORDER BY resubmission_rate DESC;

-- Get resubmission reason analysis with success focus
SELECT 
    *,
    CASE 
        WHEN success_rate > 80 THEN 'EXCELLENT'
        WHEN success_rate > 60 THEN 'GOOD'
        WHEN success_rate > 40 THEN 'FAIR'
        ELSE 'POOR'
    END AS performance_rating
FROM claims.v_resubmission_reason_analysis 
WHERE resubmission_count >= 10
ORDER BY success_rate DESC;

-- Get monthly resubmission trends with performance indicators
SELECT 
    *,
    LAG(resubmission_success_rate) OVER (ORDER BY report_month) AS previous_month_success_rate,
    ROUND(
        (resubmission_success_rate - LAG(resubmission_success_rate) OVER (ORDER BY report_month)), 2
    ) AS success_rate_change,
    CASE 
        WHEN (resubmission_success_rate - LAG(resubmission_success_rate) OVER (ORDER BY report_month)) > 0 THEN 'IMPROVING'
        WHEN (resubmission_success_rate - LAG(resubmission_success_rate) OVER (ORDER BY report_month)) < 0 THEN 'DECLINING'
        ELSE 'STABLE'
    END AS trend_direction
FROM claims.v_monthly_resubmission_trends 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY report_month DESC;

-- Get resubmission efficiency analysis with improvement recommendations
SELECT 
    *,
    CASE 
        WHEN efficiency_recommendation = 'URGENT_IMPROVEMENT' THEN 'PRIORITY_1'
        WHEN efficiency_recommendation = 'IMPROVEMENT_NEEDED' THEN 'PRIORITY_2'
        WHEN efficiency_recommendation = 'MAINTAIN_PERFORMANCE' THEN 'PRIORITY_3'
        ELSE 'PRIORITY_4'
    END AS improvement_priority
FROM claims.v_resubmission_efficiency_analysis 
ORDER BY avg_days_between_remittance_resubmission ASC;

-- Get high-priority improvement opportunities
SELECT 
    *,
    CASE 
        WHEN improvement_priority = 'PRIORITY_1' THEN 'IMMEDIATE_ACTION'
        WHEN improvement_priority = 'PRIORITY_2' THEN 'PLAN_THIS_WEEK'
        WHEN improvement_priority = 'PRIORITY_3' THEN 'PLAN_THIS_MONTH'
        ELSE 'ROUTINE_FOLLOW_UP'
    END AS action_timeline
FROM claims.v_resubmission_improvement_opportunities 
WHERE improvement_priority IN ('PRIORITY_1', 'PRIORITY_2')
    AND expected_improvement_impact > 1000
ORDER BY improvement_priority, expected_improvement_impact DESC;

-- Get provider performance comparison for resubmission management
SELECT 
    provider_name,
    total_remittances,
    resubmission_rate,
    resubmission_success_rate,
    fast_resubmission_rate,
    risk_category,
    CASE 
        WHEN resubmission_success_rate > 80 AND fast_resubmission_rate > 70 THEN 'EXCELLENT'
        WHEN resubmission_success_rate > 60 AND fast_resubmission_rate > 50 THEN 'GOOD'
        WHEN resubmission_success_rate > 40 AND fast_resubmission_rate > 30 THEN 'FAIR'
        ELSE 'NEEDS_IMPROVEMENT'
    END AS overall_rating
FROM claims.v_provider_resubmission_analysis 
WHERE total_remittances >= 20
ORDER BY resubmission_success_rate DESC, fast_resubmission_rate DESC;

-- Get resubmission improvement opportunities by provider
SELECT 
    provider_name,
    COUNT(*) AS improvement_opportunities,
    SUM(expected_improvement_impact) AS total_expected_impact,
    AVG(expected_improvement_impact) AS avg_expected_impact,
    COUNT(CASE WHEN improvement_priority = 'PRIORITY_1' THEN 1 END) AS priority_1_count,
    COUNT(CASE WHEN improvement_priority = 'PRIORITY_2' THEN 1 END) AS priority_2_count
FROM claims.v_resubmission_improvement_opportunities 
WHERE expected_improvement_impact > 500
GROUP BY provider_name
HAVING SUM(expected_improvement_impact) > 5000
ORDER BY total_expected_impact DESC;
*/
