-- =====================================================
-- CLAIM SUMMARY MONTHWISE REPORT
-- =====================================================
-- This report provides monthly summaries of claims including counts, amounts,
-- status distributions, and performance metrics.

-- Main monthly summary view
CREATE OR REPLACE VIEW claims.v_claim_summary_monthwise AS
SELECT 
    -- Time dimensions
    DATE_TRUNC('month', c.created_at) AS report_month,
    EXTRACT(YEAR FROM c.created_at) AS report_year,
    EXTRACT(MONTH FROM c.created_at) AS report_month_num,
    TO_CHAR(c.created_at, 'Month') AS report_month_name,
    
    -- Claim counts and amounts
    COUNT(*) AS total_claims,
    COUNT(CASE WHEN c.status = 'PAID' THEN 1 END) AS paid_claims,
    COUNT(CASE WHEN c.status = 'PENDING' THEN 1 END) AS pending_claims,
    COUNT(CASE WHEN c.status = 'REJECTED' THEN 1 END) AS rejected_claims,
    COUNT(CASE WHEN c.status = 'SUBMITTED' THEN 1 END) AS submitted_claims,
    
    -- Financial metrics
    SUM(c.total_amount) AS total_claim_amount,
    SUM(c.paid_amount) AS total_paid_amount,
    SUM(c.balance_amount) AS total_balance_amount,
    AVG(c.total_amount) AS avg_claim_amount,
    AVG(c.paid_amount) AS avg_paid_amount,
    AVG(c.balance_amount) AS avg_balance_amount,
    
    -- Provider and facility metrics
    COUNT(DISTINCT c.provider_id) AS unique_providers,
    COUNT(DISTINCT c.facility_id) AS unique_facilities,
    COUNT(DISTINCT c.patient_id) AS unique_patients,
    
    -- Performance metrics
    AVG(EXTRACT(DAYS FROM (COALESCE(c.updated_at, CURRENT_TIMESTAMP) - c.created_at))) AS avg_claim_age_days,
    MIN(c.created_at) AS earliest_claim_date,
    MAX(c.created_at) AS latest_claim_date,
    MAX(c.updated_at) AS latest_update_date

FROM claims.claim c
JOIN claims.facility f ON c.facility_id = f.id
WHERE claims.check_user_facility_access(f.id)
GROUP BY 
    DATE_TRUNC('month', c.created_at),
    EXTRACT(YEAR FROM c.created_at),
    EXTRACT(MONTH FROM c.created_at),
    TO_CHAR(c.created_at, 'Month')
ORDER BY report_month DESC;

-- Monthly status distribution view
CREATE OR REPLACE VIEW claims.v_monthly_status_distribution AS
SELECT 
    DATE_TRUNC('month', c.created_at) AS report_month,
    c.status AS claim_status,
    COUNT(*) AS claim_count,
    SUM(c.total_amount) AS total_amount,
    SUM(c.paid_amount) AS paid_amount,
    SUM(c.balance_amount) AS balance_amount,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY DATE_TRUNC('month', c.created_at)), 2) AS status_percentage
FROM claims.claim c
JOIN claims.facility f ON c.facility_id = f.id
WHERE claims.check_user_facility_access(f.id)
GROUP BY 
    DATE_TRUNC('month', c.created_at),
    c.status
ORDER BY report_month DESC, claim_count DESC;

-- Monthly provider performance view
CREATE OR REPLACE VIEW claims.v_monthly_provider_performance AS
SELECT 
    DATE_TRUNC('month', c.created_at) AS report_month,
    c.provider_id,
    p.name AS provider_name,
    p.npi AS provider_npi,
    COUNT(*) AS total_claims,
    SUM(c.total_amount) AS total_claim_amount,
    SUM(c.paid_amount) AS total_paid_amount,
    SUM(c.balance_amount) AS total_balance_amount,
    COUNT(CASE WHEN c.status = 'PAID' THEN 1 END) AS paid_claims,
    COUNT(CASE WHEN c.status = 'REJECTED' THEN 1 END) AS rejected_claims,
    ROUND(
        COUNT(CASE WHEN c.status = 'PAID' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS payment_success_rate,
    ROUND(
        SUM(c.paid_amount) * 100.0 / NULLIF(SUM(c.total_amount), 0), 2
    ) AS collection_rate
FROM claims.claim c
JOIN claims.provider p ON c.provider_id = p.id
JOIN claims.facility f ON c.facility_id = f.id
WHERE claims.check_user_facility_access(f.id)
GROUP BY 
    DATE_TRUNC('month', c.created_at),
    c.provider_id,
    p.name,
    p.npi
ORDER BY report_month DESC, total_claim_amount DESC;

-- Monthly facility performance view
CREATE OR REPLACE VIEW claims.v_monthly_facility_performance AS
SELECT 
    DATE_TRUNC('month', c.created_at) AS report_month,
    c.facility_id,
    f.name AS facility_name,
    f.facility_code,
    COUNT(*) AS total_claims,
    SUM(c.total_amount) AS total_claim_amount,
    SUM(c.paid_amount) AS total_paid_amount,
    SUM(c.balance_amount) AS total_balance_amount,
    COUNT(DISTINCT c.provider_id) AS unique_providers,
    COUNT(DISTINCT c.patient_id) AS unique_patients,
    AVG(c.total_amount) AS avg_claim_amount,
    ROUND(
        COUNT(CASE WHEN c.status = 'PAID' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS payment_success_rate
FROM claims.claim c
JOIN claims.facility f ON c.facility_id = f.id
WHERE claims.check_user_facility_access(f.id)
GROUP BY 
    DATE_TRUNC('month', c.created_at),
    c.facility_id,
    f.name,
    f.facility_code
ORDER BY report_month DESC, total_claim_amount DESC;

-- Monthly trends analysis view
CREATE OR REPLACE VIEW claims.v_monthly_trends_analysis AS
SELECT 
    report_month,
    total_claims,
    total_claim_amount,
    total_paid_amount,
    total_balance_amount,
    -- Month-over-month changes
    LAG(total_claims) OVER (ORDER BY report_month) AS previous_month_claims,
    LAG(total_claim_amount) OVER (ORDER BY report_month) AS previous_month_amount,
    LAG(total_paid_amount) OVER (ORDER BY report_month) AS previous_month_paid,
    LAG(total_balance_amount) OVER (ORDER BY report_month) AS previous_month_balance,
    -- Percentage changes
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
    ) AS paid_change_percent
FROM claims.v_claim_summary_monthwise
ORDER BY report_month DESC;

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_created_at ON claims.claim(created_at);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_status ON claims.claim(status);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_provider_id ON claims.claim(provider_id);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_facility_id ON claims.claim(facility_id);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_patient_id ON claims.claim(patient_id);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_total_amount ON claims.claim(total_amount);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_paid_amount ON claims.claim(paid_amount);
CREATE INDEX IF NOT EXISTS idx_claim_summary_monthwise_balance_amount ON claims.claim(balance_amount);

-- Comments and documentation
COMMENT ON VIEW claims.v_claim_summary_monthwise IS 'Monthly summary of claims including counts, amounts, and performance metrics';
COMMENT ON VIEW claims.v_monthly_status_distribution IS 'Monthly distribution of claim statuses with percentages';
COMMENT ON VIEW claims.v_monthly_provider_performance IS 'Monthly provider performance metrics including success rates';
COMMENT ON VIEW claims.v_monthly_facility_performance IS 'Monthly facility performance metrics and statistics';
COMMENT ON VIEW claims.v_monthly_trends_analysis IS 'Month-over-month trends analysis with percentage changes';

-- Usage examples
/*
-- Get monthly summary for last 12 months
SELECT * FROM claims.v_claim_summary_monthwise 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY report_month DESC;

-- Get monthly status distribution
SELECT * FROM claims.v_monthly_status_distribution 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '6 months')
ORDER BY report_month DESC, claim_count DESC;

-- Get top performing providers by month
SELECT * FROM claims.v_monthly_provider_performance 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '3 months')
    AND total_claims >= 10
ORDER BY report_month DESC, payment_success_rate DESC;

-- Get monthly trends analysis
SELECT * FROM claims.v_monthly_trends_analysis 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY report_month DESC;

-- Get facility performance comparison
SELECT * FROM claims.v_monthly_facility_performance 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '6 months')
ORDER BY report_month DESC, total_claim_amount DESC;
*/
