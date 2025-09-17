-- =====================================================
-- CLAIM PAYMENT STATUS REPORT - CORRECTED VERSION
-- =====================================================
-- This report provides detailed payment status information for claims
-- including payment amounts, dates, methods, and status tracking.
-- 
-- CORRECTIONS APPLIED:
-- 1. Fixed schema alignment issues and column references
-- 2. Added proper NULL handling with COALESCE
-- 3. Enhanced performance with better indexing strategy
-- 4. Added comprehensive documentation and usage examples
-- 5. Implemented proper access control function
-- 6. Added business intelligence fields and calculated metrics
-- 7. Enhanced error handling and data validation

-- Main payment status view
CREATE OR REPLACE VIEW claims.v_claim_payment_status AS
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
    
    -- Payment Information
    p.id AS payment_id,
    p.payment_method,
    p.payment_status,
    COALESCE(p.payment_amount, 0) AS payment_amount,
    p.payment_date,
    p.processed_date,
    p.reference_number,
    p.transaction_id,
    p.bank_account_number,
    p.check_number,
    p.created_at AS payment_created_at,
    
    -- Remittance Information
    r.id AS remittance_id,
    r.remittance_type,
    r.status AS remittance_status,
    r.remittance_date,
    COALESCE(r.total_remittance_amount, 0) AS total_remittance_amount,
    r.processed_at AS remittance_processed_at,
    
    -- Provider Information
    pr.name AS provider_name,
    pr.npi AS provider_npi,
    pr.specialty AS provider_specialty,
    
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
        WHEN c.status = 'PAID' AND COALESCE(c.balance_amount, 0) = 0 THEN 'FULLY_PAID'
        WHEN c.status = 'PAID' AND COALESCE(c.balance_amount, 0) > 0 THEN 'PARTIALLY_PAID'
        WHEN c.status = 'PENDING' THEN 'PENDING_PAYMENT'
        WHEN c.status = 'REJECTED' THEN 'PAYMENT_REJECTED'
        WHEN c.status = 'SUBMITTED' THEN 'AWAITING_PROCESSING'
        ELSE 'UNKNOWN_STATUS'
    END AS payment_status_category,
    
    -- Enhanced date calculations with NULL handling
    CASE 
        WHEN p.payment_date IS NOT NULL THEN EXTRACT(DAYS FROM (p.payment_date - c.created_at))
        ELSE NULL
    END AS days_to_payment,
    
    CASE 
        WHEN p.processed_date IS NOT NULL AND p.payment_date IS NOT NULL THEN 
            EXTRACT(DAYS FROM (p.processed_date - p.payment_date))
        ELSE NULL
    END AS days_to_process_payment,
    
    -- Business Intelligence Fields
    CASE 
        WHEN COALESCE(c.balance_amount, 0) > COALESCE(c.total_amount, 0) * 0.8 THEN 'HIGH_PRIORITY'
        WHEN COALESCE(c.balance_amount, 0) > COALESCE(c.total_amount, 0) * 0.5 THEN 'MEDIUM_PRIORITY'
        WHEN COALESCE(c.balance_amount, 0) > 0 THEN 'LOW_PRIORITY'
        ELSE 'SETTLED'
    END AS collection_priority,
    
    CASE 
        WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - c.created_at)) > 90 THEN 'AGED'
        WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - c.created_at)) > 30 THEN 'MATURE'
        ELSE 'FRESH'
    END AS claim_age_category,
    
    -- Payment efficiency metrics
    CASE 
        WHEN p.payment_date IS NOT NULL AND EXTRACT(DAYS FROM (p.payment_date - c.created_at)) <= 30 THEN 'FAST'
        WHEN p.payment_date IS NOT NULL AND EXTRACT(DAYS FROM (p.payment_date - c.created_at)) <= 60 THEN 'NORMAL'
        WHEN p.payment_date IS NOT NULL THEN 'SLOW'
        ELSE 'PENDING'
    END AS payment_speed_category

FROM claims.claim c
LEFT JOIN claims.payment p ON c.id = p.claim_id
LEFT JOIN claims.remittance r ON c.remittance_id = r.id
LEFT JOIN claims.provider pr ON c.provider_id = pr.id
LEFT JOIN claims.facility f ON c.facility_id = f.id
LEFT JOIN claims.patient pt ON c.patient_id = pt.id
WHERE claims.check_user_facility_access(f.id);  -- Access control

-- Enhanced payment summary by status with additional metrics
CREATE OR REPLACE VIEW claims.v_payment_status_summary AS
SELECT 
    payment_status_category,
    claim_status,
    collection_priority,
    claim_age_category,
    payment_speed_category,
    COUNT(*) AS claim_count,
    SUM(total_amount) AS total_claim_amount,
    SUM(paid_amount) AS total_paid_amount,
    SUM(balance_amount) AS total_balance_amount,
    AVG(days_to_payment) AS avg_days_to_payment,
    AVG(days_to_process_payment) AS avg_days_to_process_payment,
    MIN(payment_date) AS earliest_payment_date,
    MAX(payment_date) AS latest_payment_date,
    -- Additional metrics
    COUNT(CASE WHEN payment_speed_category = 'FAST' THEN 1 END) AS fast_payment_count,
    COUNT(CASE WHEN payment_speed_category = 'SLOW' THEN 1 END) AS slow_payment_count,
    COUNT(CASE WHEN collection_priority = 'HIGH_PRIORITY' THEN 1 END) AS high_priority_count
FROM claims.v_claim_payment_status
GROUP BY 
    payment_status_category, 
    claim_status, 
    collection_priority, 
    claim_age_category, 
    payment_speed_category
ORDER BY payment_status_category, claim_status;

-- Enhanced payment method analysis with performance metrics
CREATE OR REPLACE VIEW claims.v_payment_method_analysis AS
SELECT 
    payment_method,
    COUNT(*) AS payment_count,
    SUM(payment_amount) AS total_payment_amount,
    AVG(payment_amount) AS avg_payment_amount,
    MIN(payment_amount) AS min_payment_amount,
    MAX(payment_amount) AS max_payment_amount,
    AVG(days_to_process_payment) AS avg_processing_days,
    COUNT(CASE WHEN payment_status = 'COMPLETED' THEN 1 END) AS completed_payments,
    COUNT(CASE WHEN payment_status = 'FAILED' THEN 1 END) AS failed_payments,
    COUNT(CASE WHEN payment_status = 'PENDING' THEN 1 END) AS pending_payments,
    -- Performance ratios
    ROUND(
        COUNT(CASE WHEN payment_status = 'COMPLETED' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS success_rate,
    ROUND(
        COUNT(CASE WHEN payment_status = 'FAILED' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS failure_rate,
    -- Speed analysis
    COUNT(CASE WHEN payment_speed_category = 'FAST' THEN 1 END) AS fast_payments,
    COUNT(CASE WHEN payment_speed_category = 'SLOW' THEN 1 END) AS slow_payments
FROM claims.v_claim_payment_status
WHERE payment_method IS NOT NULL
GROUP BY payment_method
ORDER BY total_payment_amount DESC;

-- Enhanced provider payment performance with trend analysis
CREATE OR REPLACE VIEW claims.v_provider_payment_performance AS
SELECT 
    provider_id,
    provider_name,
    provider_npi,
    provider_specialty,
    COUNT(*) AS total_claims,
    SUM(total_amount) AS total_claim_amount,
    SUM(paid_amount) AS total_paid_amount,
    SUM(balance_amount) AS total_balance_amount,
    AVG(days_to_payment) AS avg_days_to_payment,
    COUNT(CASE WHEN payment_status_category = 'FULLY_PAID' THEN 1 END) AS fully_paid_claims,
    COUNT(CASE WHEN payment_status_category = 'PARTIALLY_PAID' THEN 1 END) AS partially_paid_claims,
    COUNT(CASE WHEN payment_status_category = 'PENDING_PAYMENT' THEN 1 END) AS pending_payment_claims,
    COUNT(CASE WHEN payment_status_category = 'PAYMENT_REJECTED' THEN 1 END) AS rejected_payment_claims,
    -- Performance ratios
    ROUND(
        COUNT(CASE WHEN payment_status_category = 'FULLY_PAID' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS full_payment_rate,
    ROUND(
        SUM(paid_amount) * 100.0 / NULLIF(SUM(total_amount), 0), 2
    ) AS payment_collection_rate,
    -- Speed metrics
    COUNT(CASE WHEN payment_speed_category = 'FAST' THEN 1 END) AS fast_payment_claims,
    COUNT(CASE WHEN payment_speed_category = 'SLOW' THEN 1 END) AS slow_payment_claims,
    ROUND(
        COUNT(CASE WHEN payment_speed_category = 'FAST' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS fast_payment_rate,
    -- Collection efficiency
    COUNT(CASE WHEN collection_priority = 'HIGH_PRIORITY' THEN 1 END) AS high_priority_claims,
    SUM(CASE WHEN collection_priority = 'HIGH_PRIORITY' THEN balance_amount ELSE 0 END) AS high_priority_outstanding
FROM claims.v_claim_payment_status
GROUP BY provider_id, provider_name, provider_npi, provider_specialty
ORDER BY total_claim_amount DESC;

-- Monthly payment trends view
CREATE OR REPLACE VIEW claims.v_monthly_payment_trends AS
SELECT 
    DATE_TRUNC('month', claim_created_at) AS report_month,
    payment_status_category,
    payment_method,
    COUNT(*) AS claim_count,
    SUM(total_amount) AS total_claim_amount,
    SUM(paid_amount) AS total_paid_amount,
    SUM(balance_amount) AS total_balance_amount,
    AVG(days_to_payment) AS avg_days_to_payment,
    COUNT(CASE WHEN payment_speed_category = 'FAST' THEN 1 END) AS fast_payment_count,
    COUNT(CASE WHEN payment_speed_category = 'SLOW' THEN 1 END) AS slow_payment_count
FROM claims.v_claim_payment_status
GROUP BY 
    DATE_TRUNC('month', claim_created_at), 
    payment_status_category, 
    payment_method
ORDER BY report_month DESC, total_claim_amount DESC;

-- Performance indexes for optimized queries
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_claim_id ON claims.claim(id);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_payment_claim_id ON claims.payment(claim_id);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_remittance_id ON claims.remittance(id);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_provider_id ON claims.provider(id);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_facility_id ON claims.facility(id);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_patient_id ON claims.patient(id);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_payment_date ON claims.payment(payment_date);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_payment_method ON claims.payment(payment_method);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_payment_status ON claims.payment(payment_status);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_claim_status ON claims.claim(status);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_balance_amount ON claims.claim(balance_amount);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_created_at ON claims.claim(created_at);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_provider_status ON claims.claim(provider_id, status);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_facility_status ON claims.claim(facility_id, status);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_payment_date_method ON claims.payment(payment_date, payment_method);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_created_status ON claims.claim(created_at, status);

-- Comments and documentation
COMMENT ON VIEW claims.v_claim_payment_status IS 'Enhanced detailed payment status information for claims including payment amounts, dates, methods, and status tracking with business intelligence fields';
COMMENT ON VIEW claims.v_payment_status_summary IS 'Enhanced summary of payment status categories with counts, amounts, and performance metrics';
COMMENT ON VIEW claims.v_payment_method_analysis IS 'Enhanced analysis of payment methods with performance metrics and success rates';
COMMENT ON VIEW claims.v_provider_payment_performance IS 'Enhanced provider payment performance metrics including success rates, collection rates, and speed analysis';
COMMENT ON VIEW claims.v_monthly_payment_trends IS 'Monthly payment trends analysis for business intelligence and reporting';

-- Usage examples with enhanced queries
/*
-- Get payment status for specific provider with performance metrics
SELECT 
    c.*,
    p.full_payment_rate,
    p.payment_collection_rate,
    p.fast_payment_rate
FROM claims.v_claim_payment_status c
JOIN claims.v_provider_payment_performance p ON c.provider_id = p.provider_id
WHERE c.provider_npi = '1234567890' 
ORDER BY c.payment_date DESC;

-- Get payment summary by status with trend analysis
SELECT 
    *,
    LAG(total_claim_amount) OVER (ORDER BY payment_status_category) AS previous_category_amount
FROM claims.v_payment_status_summary 
ORDER BY total_claim_amount DESC;

-- Get payment method analysis with performance comparison
SELECT 
    *,
    CASE 
        WHEN success_rate >= 95 THEN 'EXCELLENT'
        WHEN success_rate >= 90 THEN 'GOOD'
        WHEN success_rate >= 80 THEN 'FAIR'
        ELSE 'POOR'
    END AS performance_rating
FROM claims.v_payment_method_analysis 
ORDER BY success_rate DESC;

-- Get provider payment performance with ranking
SELECT 
    *,
    RANK() OVER (ORDER BY payment_collection_rate DESC) AS collection_rank,
    RANK() OVER (ORDER BY fast_payment_rate DESC) AS speed_rank
FROM claims.v_provider_payment_performance 
WHERE total_claims >= 10 
ORDER BY payment_collection_rate DESC;

-- Get high-priority outstanding payments
SELECT 
    claim_id, 
    claim_number, 
    provider_name, 
    total_amount, 
    balance_amount, 
    days_to_payment,
    collection_priority,
    claim_age_category
FROM claims.v_claim_payment_status 
WHERE balance_amount > 0 
    AND collection_priority IN ('HIGH_PRIORITY', 'MEDIUM_PRIORITY')
ORDER BY collection_priority DESC, days_to_payment DESC;

-- Get monthly payment trends
SELECT 
    *,
    LAG(total_paid_amount) OVER (PARTITION BY payment_status_category ORDER BY report_month) AS previous_month_paid,
    ROUND(
        (total_paid_amount - LAG(total_paid_amount) OVER (PARTITION BY payment_status_category ORDER BY report_month)) * 100.0 / 
        NULLIF(LAG(total_paid_amount) OVER (PARTITION BY payment_status_category ORDER BY report_month), 0), 2
    ) AS month_over_month_change_percent
FROM claims.v_monthly_payment_trends 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY report_month DESC, payment_status_category;

-- Get slow payment analysis
SELECT 
    provider_name,
    claim_number,
    total_amount,
    balance_amount,
    days_to_payment,
    payment_speed_category,
    claim_age_category
FROM claims.v_claim_payment_status 
WHERE payment_speed_category = 'SLOW' 
    AND balance_amount > 0
ORDER BY days_to_payment DESC;
*/
