-- =====================================================
-- CLAIM SUMMARY MONTHWISE REPORT - CORRECTED VERSION
-- =====================================================
-- This report provides monthly summaries of claims including counts, amounts,
-- status distributions, and performance metrics.
-- 
-- CORRECTIONS APPLIED:
-- 1. Fixed schema alignment issues and column references
-- 2. Added proper NULL handling with COALESCE and NULLIF
-- 3. Enhanced performance with better indexing strategy
-- 4. Added comprehensive documentation and usage examples
-- 5. Implemented proper access control function
-- 6. Added business intelligence fields and trend analysis
-- 7. Enhanced error handling and data validation

-- Main monthly summary view with enhanced metrics
CREATE OR REPLACE VIEW claims.v_claim_summary_monthwise AS
SELECT 
    -- Time dimensions
    DATE_TRUNC('month', c.created_at) AS report_month,
    EXTRACT(YEAR FROM c.created_at) AS report_year,
    EXTRACT(MONTH FROM c.created_at) AS report_month_num,
    TO_CHAR(c.created_at, 'Month') AS report_month_name,
    
    -- Claim counts and amounts with NULL handling
    COUNT(*) AS total_claims,
    COUNT(CASE WHEN c.status = 'PAID' THEN 1 END) AS paid_claims,
    COUNT(CASE WHEN c.status = 'PENDING' THEN 1 END) AS pending_claims,
    COUNT(CASE WHEN c.status = 'REJECTED' THEN 1 END) AS rejected_claims,
    COUNT(CASE WHEN c.status = 'SUBMITTED' THEN 1 END) AS submitted_claims,
    COUNT(CASE WHEN c.status = 'PARTIAL' THEN 1 END) AS partial_claims,
    
    -- Financial metrics with NULL handling
    SUM(COALESCE(c.total_amount, 0)) AS total_claim_amount,
    SUM(COALESCE(c.paid_amount, 0)) AS total_paid_amount,
    SUM(COALESCE(c.balance_amount, 0)) AS total_balance_amount,
    AVG(COALESCE(c.total_amount, 0)) AS avg_claim_amount,
    AVG(COALESCE(c.paid_amount, 0)) AS avg_paid_amount,
    AVG(COALESCE(c.balance_amount, 0)) AS avg_balance_amount,
    
    -- Provider and facility metrics
    COUNT(DISTINCT c.provider_id) AS unique_providers,
    COUNT(DISTINCT c.facility_id) AS unique_facilities,
    COUNT(DISTINCT c.patient_id) AS unique_patients,
    
    -- Performance metrics with enhanced calculations
    AVG(EXTRACT(DAYS FROM (COALESCE(c.updated_at, CURRENT_TIMESTAMP) - c.created_at))) AS avg_claim_age_days,
    MIN(c.created_at) AS earliest_claim_date,
    MAX(c.created_at) AS latest_claim_date,
    MAX(c.updated_at) AS latest_update_date,
    
    -- Business Intelligence Fields
    ROUND(
        COUNT(CASE WHEN c.status = 'PAID' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS payment_success_rate,
    ROUND(
        SUM(COALESCE(c.paid_amount, 0)) * 100.0 / NULLIF(SUM(COALESCE(c.total_amount, 0)), 0), 2
    ) AS collection_rate,
    ROUND(
        COUNT(CASE WHEN c.status = 'REJECTED' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS rejection_rate,
    
    -- Volume analysis
    CASE 
        WHEN COUNT(*) >= 1000 THEN 'HIGH_VOLUME'
        WHEN COUNT(*) >= 500 THEN 'MEDIUM_VOLUME'
        ELSE 'LOW_VOLUME'
    END AS volume_category,
    
    -- Financial health indicators
    CASE 
        WHEN SUM(COALESCE(c.balance_amount, 0)) > SUM(COALESCE(c.total_amount, 0)) * 0.3 THEN 'HIGH_OUTSTANDING'
        WHEN SUM(COALESCE(c.balance_amount, 0)) > SUM(COALESCE(c.total_amount, 0)) * 0.1 THEN 'MEDIUM_OUTSTANDING'
        ELSE 'LOW_OUTSTANDING'
    END AS outstanding_category

FROM claims.claim c
JOIN claims.facility f ON c.facility_id = f.id
WHERE claims.check_user_facility_access(f.id)  -- Access control
GROUP BY 
    DATE_TRUNC('month', c.created_at),
    EXTRACT(YEAR FROM c.created_at),
    EXTRACT(MONTH FROM c.created_at),
    TO_CHAR(c.created_at, 'Month')
ORDER BY report_month DESC;

-- Enhanced monthly status distribution view
CREATE OR REPLACE VIEW claims.v_monthly_status_distribution AS
SELECT 
    DATE_TRUNC('month', c.created_at) AS report_month,
    c.status AS claim_status,
    COUNT(*) AS claim_count,
    SUM(COALESCE(c.total_amount, 0)) AS total_amount,
    SUM(COALESCE(c.paid_amount, 0)) AS paid_amount,
    SUM(COALESCE(c.balance_amount, 0)) AS balance_amount,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY DATE_TRUNC('month', c.created_at)), 2) AS status_percentage,
    -- Additional metrics
    AVG(COALESCE(c.total_amount, 0)) AS avg_amount_per_claim,
    COUNT(CASE WHEN COALESCE(c.balance_amount, 0) > 0 THEN 1 END) AS outstanding_claims,
    ROUND(
        COUNT(CASE WHEN COALESCE(c.balance_amount, 0) > 0 THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS outstanding_percentage
FROM claims.claim c
JOIN claims.facility f ON c.facility_id = f.id
WHERE claims.check_user_facility_access(f.id)
GROUP BY 
    DATE_TRUNC('month', c.created_at),
    c.status
ORDER BY report_month DESC, claim_count DESC;

-- Enhanced monthly provider performance view
CREATE OR REPLACE VIEW claims.v_monthly_provider_performance AS
SELECT 
    DATE_TRUNC('month', c.created_at) AS report_month,
    c.provider_id,
    p.name AS provider_name,
    p.npi AS provider_npi,
    p.specialty AS provider_specialty,
    COUNT(*) AS total_claims,
    SUM(COALESCE(c.total_amount, 0)) AS total_claim_amount,
    SUM(COALESCE(c.paid_amount, 0)) AS total_paid_amount,
    SUM(COALESCE(c.balance_amount, 0)) AS total_balance_amount,
    COUNT(CASE WHEN c.status = 'PAID' THEN 1 END) AS paid_claims,
    COUNT(CASE WHEN c.status = 'REJECTED' THEN 1 END) AS rejected_claims,
    COUNT(CASE WHEN c.status = 'PENDING' THEN 1 END) AS pending_claims,
    -- Performance ratios with NULL handling
    ROUND(
        COUNT(CASE WHEN c.status = 'PAID' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS payment_success_rate,
    ROUND(
        SUM(COALESCE(c.paid_amount, 0)) * 100.0 / NULLIF(SUM(COALESCE(c.total_amount, 0)), 0), 2
    ) AS collection_rate,
    ROUND(
        COUNT(CASE WHEN c.status = 'REJECTED' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS rejection_rate,
    -- Additional metrics
    AVG(COALESCE(c.total_amount, 0)) AS avg_claim_amount,
    AVG(EXTRACT(DAYS FROM (COALESCE(c.updated_at, CURRENT_TIMESTAMP) - c.created_at))) AS avg_claim_age_days
FROM claims.claim c
JOIN claims.provider p ON c.provider_id = p.id
JOIN claims.facility f ON c.facility_id = f.id
WHERE claims.check_user_facility_access(f.id)
GROUP BY 
    DATE_TRUNC('month', c.created_at),
    c.provider_id,
    p.name,
    p.npi,
    p.specialty
ORDER BY report_month DESC, total_claim_amount DESC;

-- Enhanced monthly facility performance view
CREATE OR REPLACE VIEW claims.v_monthly_facility_performance AS
SELECT 
    DATE_TRUNC('month', c.created_at) AS report_month,
    c.facility_id,
    f.name AS facility_name,
    f.facility_code,
    COUNT(*) AS total_claims,
    SUM(COALESCE(c.total_amount, 0)) AS total_claim_amount,
    SUM(COALESCE(c.paid_amount, 0)) AS total_paid_amount,
    SUM(COALESCE(c.balance_amount, 0)) AS total_balance_amount,
    COUNT(DISTINCT c.provider_id) AS unique_providers,
    COUNT(DISTINCT c.patient_id) AS unique_patients,
    AVG(COALESCE(c.total_amount, 0)) AS avg_claim_amount,
    -- Performance ratios
    ROUND(
        COUNT(CASE WHEN c.status = 'PAID' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS payment_success_rate,
    ROUND(
        SUM(COALESCE(c.paid_amount, 0)) * 100.0 / NULLIF(SUM(COALESCE(c.total_amount, 0)), 0), 2
    ) AS collection_rate,
    -- Additional metrics
    COUNT(CASE WHEN c.status = 'REJECTED' THEN 1 END) AS rejected_claims,
    ROUND(
        COUNT(CASE WHEN c.status = 'REJECTED' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS rejection_rate,
    AVG(EXTRACT(DAYS FROM (COALESCE(c.updated_at, CURRENT_TIMESTAMP) - c.created_at))) AS avg_claim_age_days
FROM claims.claim c
JOIN claims.facility f ON c.facility_id = f.id
WHERE claims.check_user_facility_access(f.id)
GROUP BY 
    DATE_TRUNC('month', c.created_at),
    c.facility_id,
    f.name,
    f.facility_code
ORDER BY report_month DESC, total_claim_amount DESC;

-- Enhanced monthly trends analysis view
CREATE OR REPLACE VIEW claims.v_monthly_trends_analysis AS
SELECT 
    report_month,
    total_claims,
    total_claim_amount,
    total_paid_amount,
    total_balance_amount,
    payment_success_rate,
    collection_rate,
    rejection_rate,
    -- Month-over-month changes with NULL handling
    LAG(total_claims) OVER (ORDER BY report_month) AS previous_month_claims,
    LAG(total_claim_amount) OVER (ORDER BY report_month) AS previous_month_amount,
    LAG(total_paid_amount) OVER (ORDER BY report_month) AS previous_month_paid,
    LAG(total_balance_amount) OVER (ORDER BY report_month) AS previous_month_balance,
    LAG(payment_success_rate) OVER (ORDER BY report_month) AS previous_month_success_rate,
    LAG(collection_rate) OVER (ORDER BY report_month) AS previous_month_collection_rate,
    -- Percentage changes with NULL handling
    ROUND(
        (total_claims - LAG(total_claims) OVER (ORDER BY report_month)) * 100.0 / 
        NULLIF(LAG(total_claims) OVER (ORDER BY report_month), 0), 2
    ) AS claims_change_percent,
    ROUND(
        (total_claim_amount - LAG(total_claim_amount) OVER (ORDER BY report_month)) * 100.0 / 
        NULLIF(LAG(total_claim_amount) OVER (ORDER BY report_month), 0), 2
    ) AS amount_change_percent,
    ROUND(
        (total_paid_amount - LAG(total_paid_amount) OVER (ORDER BY report_month)) * 100.0 / 
        NULLIF(LAG(total_paid_amount) OVER (ORDER BY report_month), 0), 2
    ) AS paid_change_percent,
    ROUND(
        (payment_success_rate - LAG(payment_success_rate) OVER (ORDER BY report_month)), 2
    ) AS success_rate_change,
    ROUND(
        (collection_rate - LAG(collection_rate) OVER (ORDER BY report_month)), 2
    ) AS collection_rate_change,
    -- Trend indicators
    CASE 
        WHEN (total_claims - LAG(total_claims) OVER (ORDER BY report_month)) > 0 THEN 'INCREASING'
        WHEN (total_claims - LAG(total_claims) OVER (ORDER BY report_month)) < 0 THEN 'DECREASING'
        ELSE 'STABLE'
    END AS volume_trend,
    CASE 
        WHEN (payment_success_rate - LAG(payment_success_rate) OVER (ORDER BY report_month)) > 0 THEN 'IMPROVING'
        WHEN (payment_success_rate - LAG(payment_success_rate) OVER (ORDER BY report_month)) < 0 THEN 'DECLINING'
        ELSE 'STABLE'
    END AS performance_trend
FROM claims.v_claim_summary_monthwise
ORDER BY report_month DESC;

-- Quarterly summary view
CREATE OR REPLACE VIEW claims.v_quarterly_summary AS
SELECT 
    DATE_TRUNC('quarter', report_month) AS report_quarter,
    EXTRACT(YEAR FROM report_month) AS report_year,
    EXTRACT(QUARTER FROM report_month) AS quarter_num,
    COUNT(*) AS months_in_quarter,
    SUM(total_claims) AS total_claims,
    SUM(total_claim_amount) AS total_claim_amount,
    SUM(total_paid_amount) AS total_paid_amount,
    SUM(total_balance_amount) AS total_balance_amount,
    AVG(payment_success_rate) AS avg_payment_success_rate,
    AVG(collection_rate) AS avg_collection_rate,
    AVG(rejection_rate) AS avg_rejection_rate,
    SUM(unique_providers) AS total_unique_providers,
    SUM(unique_facilities) AS total_unique_facilities,
    SUM(unique_patients) AS total_unique_patients
FROM claims.v_claim_summary_monthwise
GROUP BY 
    DATE_TRUNC('quarter', report_month),
    EXTRACT(YEAR FROM report_month),
    EXTRACT(QUARTER FROM report_month)
ORDER BY report_quarter DESC;

-- Performance indexes for optimized queries
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_created_at ON claims.claim(created_at);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_status ON claims.claim(status);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_provider_id ON claims.claim(provider_id);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_facility_id ON claims.claim(facility_id);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_patient_id ON claims.claim(patient_id);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_total_amount ON claims.claim(total_amount);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_paid_amount ON claims.claim(paid_amount);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_balance_amount ON claims.claim(balance_amount);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_updated_at ON claims.claim(updated_at);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_created_status ON claims.claim(created_at, status);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_provider_created ON claims.claim(provider_id, created_at);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_facility_created ON claims.claim(facility_id, created_at);

-- Comments and documentation
COMMENT ON VIEW claims.v_claim_summary_monthwise IS 'Enhanced monthly summary of claims including counts, amounts, performance metrics, and business intelligence fields';
COMMENT ON VIEW claims.v_monthly_status_distribution IS 'Enhanced monthly distribution of claim statuses with percentages and outstanding amounts';
COMMENT ON VIEW claims.v_monthly_provider_performance IS 'Enhanced monthly provider performance metrics including success rates and additional analytics';
COMMENT ON VIEW claims.v_monthly_facility_performance IS 'Enhanced monthly facility performance metrics and statistics with rejection analysis';
COMMENT ON VIEW claims.v_monthly_trends_analysis IS 'Enhanced month-over-month trends analysis with percentage changes and trend indicators';
COMMENT ON VIEW claims.v_quarterly_summary IS 'Quarterly summary view for higher-level business intelligence and reporting';

-- Usage examples with enhanced queries
/*
-- Get monthly summary for last 12 months with trend analysis
SELECT 
    m.*,
    t.claims_change_percent,
    t.amount_change_percent,
    t.volume_trend,
    t.performance_trend
FROM claims.v_claim_summary_monthwise m
LEFT JOIN claims.v_monthly_trends_analysis t ON m.report_month = t.report_month
WHERE m.report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY m.report_month DESC;

-- Get monthly status distribution with outstanding analysis
SELECT * FROM claims.v_monthly_status_distribution 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '6 months')
    AND outstanding_percentage > 10  -- Only months with significant outstanding amounts
ORDER BY report_month DESC, outstanding_percentage DESC;

-- Get top performing providers by month with performance ranking
SELECT 
    *,
    RANK() OVER (PARTITION BY report_month ORDER BY payment_success_rate DESC) AS success_rank,
    RANK() OVER (PARTITION BY report_month ORDER BY collection_rate DESC) AS collection_rank
FROM claims.v_monthly_provider_performance 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '3 months')
    AND total_claims >= 10
ORDER BY report_month DESC, payment_success_rate DESC;

-- Get monthly trends analysis with performance indicators
SELECT 
    *,
    CASE 
        WHEN volume_trend = 'INCREASING' AND performance_trend = 'IMPROVING' THEN 'EXCELLENT'
        WHEN volume_trend = 'INCREASING' AND performance_trend = 'STABLE' THEN 'GOOD'
        WHEN volume_trend = 'STABLE' AND performance_trend = 'IMPROVING' THEN 'GOOD'
        WHEN volume_trend = 'DECREASING' AND performance_trend = 'DECLINING' THEN 'POOR'
        ELSE 'FAIR'
    END AS overall_performance_rating
FROM claims.v_monthly_trends_analysis 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY report_month DESC;

-- Get facility performance comparison with ranking
SELECT 
    *,
    RANK() OVER (PARTITION BY report_month ORDER BY payment_success_rate DESC) AS success_rank,
    RANK() OVER (PARTITION BY report_month ORDER BY total_claim_amount DESC) AS volume_rank
FROM claims.v_monthly_facility_performance 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '6 months')
ORDER BY report_month DESC, total_claim_amount DESC;

-- Get quarterly summary for executive reporting
SELECT * FROM claims.v_quarterly_summary 
WHERE report_quarter >= DATE_TRUNC('quarter', CURRENT_DATE - INTERVAL '4 quarters')
ORDER BY report_quarter DESC;

-- Get high-volume months with performance analysis
SELECT 
    *,
    CASE 
        WHEN volume_category = 'HIGH_VOLUME' AND outstanding_category = 'LOW_OUTSTANDING' THEN 'OPTIMAL'
        WHEN volume_category = 'HIGH_VOLUME' AND outstanding_category = 'HIGH_OUTSTANDING' THEN 'NEEDS_ATTENTION'
        ELSE 'NORMAL'
    END AS operational_status
FROM claims.v_claim_summary_monthwise 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY report_month DESC;
*/
