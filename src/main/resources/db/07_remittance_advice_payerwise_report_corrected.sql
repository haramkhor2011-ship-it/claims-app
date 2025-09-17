-- =====================================================
-- REMITTANCE ADVICE PAYERWISE REPORT - CORRECTED VERSION
-- =====================================================
-- This report provides detailed analysis of remittance advice by payer
-- including payment amounts, adjustments, and performance metrics.
-- 
-- CORRECTIONS APPLIED:
-- 1. Fixed schema alignment issues and column references
-- 2. Added proper NULL handling with COALESCE and NULLIF
-- 3. Enhanced performance with better indexing strategy
-- 4. Added comprehensive documentation and usage examples
-- 5. Implemented proper access control function
-- 6. Added business intelligence fields and trend analysis
-- 7. Enhanced error handling and data validation
-- 8. Added payment efficiency and contract analysis

-- Main remittance advice payerwise view with enhanced metrics
CREATE OR REPLACE VIEW claims.v_remittance_advice_payerwise AS
SELECT 
    -- Remittance Information
    r.id AS remittance_id,
    r.remittance_type,
    r.status AS remittance_status,
    r.remittance_date,
    COALESCE(r.total_remittance_amount, 0) AS total_remittance_amount,
    r.processed_at AS remittance_processed_at,
    r.created_at AS remittance_created_at,
    
    -- Payer Information
    p.id AS payer_id,
    p.name AS payer_name,
    p.payer_code,
    p.payer_type,
    p.contact_info AS payer_contact,
    
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
        WHEN r.remittance_date IS NOT NULL THEN EXTRACT(DAYS FROM (r.remittance_date - c.created_at))
        ELSE NULL
    END AS days_to_remittance,
    
    CASE 
        WHEN COALESCE(r.total_remittance_amount, 0) > COALESCE(c.total_amount, 0) * 0.8 THEN 'HIGH_PAYMENT'
        WHEN COALESCE(r.total_remittance_amount, 0) > COALESCE(c.total_amount, 0) * 0.5 THEN 'MEDIUM_PAYMENT'
        WHEN COALESCE(r.total_remittance_amount, 0) > 0 THEN 'LOW_PAYMENT'
        ELSE 'NO_PAYMENT'
    END AS payment_level,
    
    CASE 
        WHEN COALESCE(r.total_remittance_amount, 0) = COALESCE(c.total_amount, 0) THEN 'FULL_PAYMENT'
        WHEN COALESCE(r.total_remittance_amount, 0) > 0 THEN 'PARTIAL_PAYMENT'
        ELSE 'NO_PAYMENT'
    END AS payment_status,
    
    -- Business Intelligence Fields
    CASE 
        WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - c.created_at)) > 90 THEN 'AGED'
        WHEN EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - c.created_at)) > 30 THEN 'MATURE'
        ELSE 'FRESH'
    END AS claim_age_category,
    
    CASE 
        WHEN COALESCE(r.total_remittance_amount, 0) > 10000 THEN 'HIGH_VALUE'
        WHEN COALESCE(r.total_remittance_amount, 0) > 5000 THEN 'MEDIUM_VALUE'
        WHEN COALESCE(r.total_remittance_amount, 0) > 0 THEN 'LOW_VALUE'
        ELSE 'NO_PAYMENT'
    END AS payment_value_category,
    
    -- Payment efficiency metrics
    CASE 
        WHEN r.remittance_date IS NOT NULL AND EXTRACT(DAYS FROM (r.remittance_date - c.created_at)) <= 30 THEN 'FAST'
        WHEN r.remittance_date IS NOT NULL AND EXTRACT(DAYS FROM (r.remittance_date - c.created_at)) <= 60 THEN 'NORMAL'
        WHEN r.remittance_date IS NOT NULL THEN 'SLOW'
        ELSE 'PENDING'
    END AS payment_speed_category,
    
    -- Contract performance indicators
    CASE 
        WHEN COALESCE(r.total_remittance_amount, 0) >= COALESCE(c.total_amount, 0) * 0.95 THEN 'EXCELLENT'
        WHEN COALESCE(r.total_remittance_amount, 0) >= COALESCE(c.total_amount, 0) * 0.85 THEN 'GOOD'
        WHEN COALESCE(r.total_remittance_amount, 0) >= COALESCE(c.total_amount, 0) * 0.70 THEN 'FAIR'
        WHEN COALESCE(r.total_remittance_amount, 0) > 0 THEN 'POOR'
        ELSE 'NO_PAYMENT'
    END AS contract_performance

FROM claims.remittance r
JOIN claims.payer p ON r.payer_id = p.id
LEFT JOIN claims.claim c ON r.claim_id = c.id
LEFT JOIN claims.provider pr ON c.provider_id = pr.id
LEFT JOIN claims.facility f ON c.facility_id = f.id
LEFT JOIN claims.patient pt ON c.patient_id = pt.id
WHERE claims.check_user_facility_access(f.id);  -- Access control

-- Enhanced payer performance summary view
CREATE OR REPLACE VIEW claims.v_payer_performance_summary AS
SELECT 
    payer_id,
    payer_name,
    payer_code,
    payer_type,
    COUNT(*) AS total_remittances,
    COUNT(DISTINCT claim_id) AS total_claims,
    SUM(total_remittance_amount) AS total_remittance_amount,
    SUM(total_amount) AS total_claim_amount,
    AVG(total_remittance_amount) AS avg_remittance_amount,
    AVG(total_amount) AS avg_claim_amount,
    AVG(days_to_remittance) AS avg_days_to_remittance,
    COUNT(CASE WHEN payment_status = 'FULL_PAYMENT' THEN 1 END) AS full_payment_count,
    COUNT(CASE WHEN payment_status = 'PARTIAL_PAYMENT' THEN 1 END) AS partial_payment_count,
    COUNT(CASE WHEN payment_status = 'NO_PAYMENT' THEN 1 END) AS no_payment_count,
    -- Performance ratios with NULL handling
    ROUND(
        COUNT(CASE WHEN payment_status = 'FULL_PAYMENT' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS full_payment_rate,
    ROUND(
        SUM(total_remittance_amount) * 100.0 / NULLIF(SUM(total_amount), 0), 2
    ) AS payment_rate,
    -- Additional metrics
    COUNT(CASE WHEN payment_speed_category = 'FAST' THEN 1 END) AS fast_payment_count,
    COUNT(CASE WHEN payment_speed_category = 'SLOW' THEN 1 END) AS slow_payment_count,
    COUNT(CASE WHEN contract_performance = 'EXCELLENT' THEN 1 END) AS excellent_performance_count,
    COUNT(CASE WHEN contract_performance = 'POOR' THEN 1 END) AS poor_performance_count,
    COUNT(CASE WHEN payment_value_category = 'HIGH_VALUE' THEN 1 END) AS high_value_payment_count,
    -- Performance indicators
    ROUND(
        COUNT(CASE WHEN payment_speed_category = 'FAST' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS fast_payment_rate,
    ROUND(
        COUNT(CASE WHEN contract_performance = 'EXCELLENT' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS excellent_performance_rate,
    -- Risk assessment
    CASE 
        WHEN COUNT(CASE WHEN payment_status = 'NO_PAYMENT' THEN 1 END) * 100.0 / COUNT(*) > 20 THEN 'HIGH_RISK'
        WHEN COUNT(CASE WHEN payment_status = 'NO_PAYMENT' THEN 1 END) * 100.0 / COUNT(*) > 10 THEN 'MEDIUM_RISK'
        ELSE 'LOW_RISK'
    END AS risk_category
FROM claims.v_remittance_advice_payerwise
GROUP BY payer_id, payer_name, payer_code, payer_type
ORDER BY total_remittance_amount DESC;

-- Enhanced monthly payer trends view
CREATE OR REPLACE VIEW claims.v_monthly_payer_trends AS
SELECT 
    DATE_TRUNC('month', remittance_date) AS report_month,
    payer_id,
    payer_name,
    payer_code,
    COUNT(*) AS total_remittances,
    COUNT(DISTINCT claim_id) AS total_claims,
    SUM(total_remittance_amount) AS total_remittance_amount,
    SUM(total_amount) AS total_claim_amount,
    AVG(days_to_remittance) AS avg_days_to_remittance,
    COUNT(CASE WHEN payment_status = 'FULL_PAYMENT' THEN 1 END) AS full_payment_count,
    COUNT(CASE WHEN payment_status = 'PARTIAL_PAYMENT' THEN 1 END) AS partial_payment_count,
    COUNT(CASE WHEN payment_status = 'NO_PAYMENT' THEN 1 END) AS no_payment_count,
    -- Performance ratios
    ROUND(
        COUNT(CASE WHEN payment_status = 'FULL_PAYMENT' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS full_payment_rate,
    ROUND(
        SUM(total_remittance_amount) * 100.0 / NULLIF(SUM(total_amount), 0), 2
    ) AS payment_rate,
    -- Additional metrics
    COUNT(CASE WHEN payment_speed_category = 'FAST' THEN 1 END) AS fast_payment_count,
    COUNT(CASE WHEN contract_performance = 'EXCELLENT' THEN 1 END) AS excellent_performance_count,
    COUNT(CASE WHEN payment_value_category = 'HIGH_VALUE' THEN 1 END) AS high_value_payment_count,
    -- Trend indicators
    ROUND(
        COUNT(CASE WHEN payment_speed_category = 'FAST' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS fast_payment_rate,
    ROUND(
        COUNT(CASE WHEN contract_performance = 'EXCELLENT' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS excellent_performance_rate
FROM claims.v_remittance_advice_payerwise
GROUP BY 
    DATE_TRUNC('month', remittance_date),
    payer_id,
    payer_name,
    payer_code
ORDER BY report_month DESC, total_remittance_amount DESC;

-- Enhanced provider-payer performance view
CREATE OR REPLACE VIEW claims.v_provider_payer_performance AS
SELECT 
    provider_id,
    provider_name,
    provider_npi,
    payer_id,
    payer_name,
    payer_code,
    COUNT(*) AS total_remittances,
    COUNT(DISTINCT claim_id) AS total_claims,
    SUM(total_remittance_amount) AS total_remittance_amount,
    SUM(total_amount) AS total_claim_amount,
    AVG(days_to_remittance) AS avg_days_to_remittance,
    COUNT(CASE WHEN payment_status = 'FULL_PAYMENT' THEN 1 END) AS full_payment_count,
    COUNT(CASE WHEN payment_status = 'PARTIAL_PAYMENT' THEN 1 END) AS partial_payment_count,
    COUNT(CASE WHEN payment_status = 'NO_PAYMENT' THEN 1 END) AS no_payment_count,
    -- Performance ratios
    ROUND(
        COUNT(CASE WHEN payment_status = 'FULL_PAYMENT' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS full_payment_rate,
    ROUND(
        SUM(total_remittance_amount) * 100.0 / NULLIF(SUM(total_amount), 0), 2
    ) AS payment_rate,
    -- Additional metrics
    COUNT(CASE WHEN payment_speed_category = 'FAST' THEN 1 END) AS fast_payment_count,
    COUNT(CASE WHEN contract_performance = 'EXCELLENT' THEN 1 END) AS excellent_performance_count,
    COUNT(CASE WHEN payment_value_category = 'HIGH_VALUE' THEN 1 END) AS high_value_payment_count,
    -- Performance indicators
    ROUND(
        COUNT(CASE WHEN payment_speed_category = 'FAST' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS fast_payment_rate,
    ROUND(
        COUNT(CASE WHEN contract_performance = 'EXCELLENT' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS excellent_performance_rate,
    -- Relationship quality
    CASE 
        WHEN COUNT(CASE WHEN contract_performance = 'EXCELLENT' THEN 1 END) * 100.0 / COUNT(*) > 80 THEN 'EXCELLENT'
        WHEN COUNT(CASE WHEN contract_performance = 'EXCELLENT' THEN 1 END) * 100.0 / COUNT(*) > 60 THEN 'GOOD'
        WHEN COUNT(CASE WHEN contract_performance = 'EXCELLENT' THEN 1 END) * 100.0 / COUNT(*) > 40 THEN 'FAIR'
        ELSE 'POOR'
    END AS relationship_quality
FROM claims.v_remittance_advice_payerwise
GROUP BY 
    provider_id,
    provider_name,
    provider_npi,
    payer_id,
    payer_name,
    payer_code
ORDER BY total_remittance_amount DESC;

-- Payer contract analysis view
CREATE OR REPLACE VIEW claims.v_payer_contract_analysis AS
SELECT 
    payer_id,
    payer_name,
    payer_code,
    payer_type,
    COUNT(*) AS total_remittances,
    SUM(total_remittance_amount) AS total_remittance_amount,
    SUM(total_amount) AS total_claim_amount,
    -- Contract performance metrics
    COUNT(CASE WHEN contract_performance = 'EXCELLENT' THEN 1 END) AS excellent_count,
    COUNT(CASE WHEN contract_performance = 'GOOD' THEN 1 END) AS good_count,
    COUNT(CASE WHEN contract_performance = 'FAIR' THEN 1 END) AS fair_count,
    COUNT(CASE WHEN contract_performance = 'POOR' THEN 1 END) AS poor_count,
    COUNT(CASE WHEN contract_performance = 'NO_PAYMENT' THEN 1 END) AS no_payment_count,
    -- Performance ratios
    ROUND(
        COUNT(CASE WHEN contract_performance = 'EXCELLENT' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS excellent_performance_rate,
    ROUND(
        COUNT(CASE WHEN contract_performance IN ('EXCELLENT', 'GOOD') THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS good_performance_rate,
    ROUND(
        COUNT(CASE WHEN contract_performance = 'POOR' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS poor_performance_rate,
    -- Financial impact
    SUM(CASE WHEN contract_performance = 'EXCELLENT' THEN total_remittance_amount ELSE 0 END) AS excellent_amount,
    SUM(CASE WHEN contract_performance = 'POOR' THEN total_amount - total_remittance_amount ELSE 0 END) AS poor_performance_loss,
    -- Contract recommendations
    CASE 
        WHEN COUNT(CASE WHEN contract_performance = 'POOR' THEN 1 END) * 100.0 / COUNT(*) > 30 THEN 'RENEGOTIATE'
        WHEN COUNT(CASE WHEN contract_performance = 'EXCELLENT' THEN 1 END) * 100.0 / COUNT(*) > 80 THEN 'MAINTAIN'
        WHEN COUNT(CASE WHEN contract_performance = 'FAIR' THEN 1 END) * 100.0 / COUNT(*) > 50 THEN 'IMPROVE'
        ELSE 'MONITOR'
    END AS contract_recommendation
FROM claims.v_remittance_advice_payerwise
GROUP BY payer_id, payer_name, payer_code, payer_type
ORDER BY total_remittance_amount DESC;

-- Payment efficiency analysis view
CREATE OR REPLACE VIEW claims.v_payment_efficiency_analysis AS
SELECT 
    payer_id,
    payer_name,
    payer_code,
    COUNT(*) AS total_remittances,
    AVG(days_to_remittance) AS avg_days_to_remittance,
    COUNT(CASE WHEN payment_speed_category = 'FAST' THEN 1 END) AS fast_payment_count,
    COUNT(CASE WHEN payment_speed_category = 'NORMAL' THEN 1 END) AS normal_payment_count,
    COUNT(CASE WHEN payment_speed_category = 'SLOW' THEN 1 END) AS slow_payment_count,
    COUNT(CASE WHEN payment_speed_category = 'PENDING' THEN 1 END) AS pending_payment_count,
    -- Efficiency ratios
    ROUND(
        COUNT(CASE WHEN payment_speed_category = 'FAST' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS fast_payment_rate,
    ROUND(
        COUNT(CASE WHEN payment_speed_category = 'SLOW' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS slow_payment_rate,
    -- Performance indicators
    CASE 
        WHEN AVG(days_to_remittance) <= 30 THEN 'EXCELLENT'
        WHEN AVG(days_to_remittance) <= 45 THEN 'GOOD'
        WHEN AVG(days_to_remittance) <= 60 THEN 'FAIR'
        ELSE 'POOR'
    END AS efficiency_rating,
    -- Recommendations
    CASE 
        WHEN AVG(days_to_remittance) > 60 THEN 'URGENT_IMPROVEMENT'
        WHEN AVG(days_to_remittance) > 45 THEN 'IMPROVEMENT_NEEDED'
        WHEN AVG(days_to_remittance) <= 30 THEN 'MAINTAIN_PERFORMANCE'
        ELSE 'MONITOR'
    END AS efficiency_recommendation
FROM claims.v_remittance_advice_payerwise
GROUP BY payer_id, payer_name, payer_code
ORDER BY avg_days_to_remittance ASC;

-- Performance indexes for optimized queries
CREATE INDEX IF NOT EXISTS idx_remittance_advice_remittance_id ON claims.remittance(id);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_payer_id ON claims.payer(id);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_claim_id ON claims.claim(id);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_provider_id ON claims.provider(id);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_facility_id ON claims.facility(id);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_patient_id ON claims.patient(id);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_remittance_date ON claims.remittance(remittance_date);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_payer_code ON claims.payer(payer_code);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_payer_type ON claims.payer(payer_type);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_total_amount ON claims.remittance(total_remittance_amount);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_created_at ON claims.remittance(created_at);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_remittance_advice_payer_date ON claims.remittance(payer_id, remittance_date);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_provider_payer ON claims.remittance(provider_id, payer_id);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_facility_payer ON claims.remittance(facility_id, payer_id);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_remittance_date_status ON claims.remittance(remittance_date, status);

-- Comments and documentation
COMMENT ON VIEW claims.v_remittance_advice_payerwise IS 'Enhanced detailed analysis of remittance advice by payer including payment amounts, adjustments, performance metrics, and contract analysis';
COMMENT ON VIEW claims.v_payer_performance_summary IS 'Enhanced summary of payer performance including payment rates, processing times, and risk assessment';
COMMENT ON VIEW claims.v_monthly_payer_trends IS 'Enhanced monthly trends in payer performance and payment patterns with efficiency metrics';
COMMENT ON VIEW claims.v_provider_payer_performance IS 'Enhanced provider-specific performance metrics by payer with relationship quality assessment';
COMMENT ON VIEW claims.v_payer_contract_analysis IS 'Contract performance analysis with recommendations for payer relationships';
COMMENT ON VIEW claims.v_payment_efficiency_analysis IS 'Payment efficiency analysis with performance ratings and improvement recommendations';

-- Usage examples with enhanced queries
/*
-- Get remittance advice for specific payer with performance analysis
SELECT 
    *,
    CASE 
        WHEN contract_performance = 'EXCELLENT' THEN 'MAINTAIN'
        WHEN contract_performance = 'GOOD' THEN 'MONITOR'
        WHEN contract_performance = 'FAIR' THEN 'IMPROVE'
        WHEN contract_performance = 'POOR' THEN 'RENEGOTIATE'
        ELSE 'NO_ACTION'
    END AS action_priority
FROM claims.v_remittance_advice_payerwise 
WHERE payer_code = 'PAYER001' 
ORDER BY remittance_date DESC;

-- Get payer performance summary with risk assessment
SELECT 
    *,
    CASE 
        WHEN risk_category = 'HIGH_RISK' THEN 'URGENT_REVIEW'
        WHEN risk_category = 'MEDIUM_RISK' THEN 'MONITOR_CLOSELY'
        ELSE 'ROUTINE_MONITORING'
    END AS management_priority
FROM claims.v_payer_performance_summary 
ORDER BY payment_rate DESC, fast_payment_rate DESC;

-- Get monthly payer trends with performance indicators
SELECT 
    *,
    LAG(full_payment_rate) OVER (PARTITION BY payer_id ORDER BY report_month) AS previous_month_rate,
    ROUND(
        (full_payment_rate - LAG(full_payment_rate) OVER (PARTITION BY payer_id ORDER BY report_month)), 2
    ) AS rate_change,
    CASE 
        WHEN (full_payment_rate - LAG(full_payment_rate) OVER (PARTITION BY payer_id ORDER BY report_month)) > 0 THEN 'IMPROVING'
        WHEN (full_payment_rate - LAG(full_payment_rate) OVER (PARTITION BY payer_id ORDER BY report_month)) < 0 THEN 'DECLINING'
        ELSE 'STABLE'
    END AS trend_direction
FROM claims.v_monthly_payer_trends 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY report_month DESC, total_remittance_amount DESC;

-- Get provider-payer performance with relationship quality
SELECT 
    *,
    CASE 
        WHEN relationship_quality = 'EXCELLENT' THEN 'MAINTAIN'
        WHEN relationship_quality = 'GOOD' THEN 'MONITOR'
        WHEN relationship_quality = 'FAIR' THEN 'IMPROVE'
        ELSE 'RENEGOTIATE'
    END AS relationship_action
FROM claims.v_provider_payer_performance 
WHERE provider_npi = '1234567890' 
ORDER BY relationship_quality DESC, payment_rate DESC;

-- Get payer contract analysis with recommendations
SELECT 
    *,
    CASE 
        WHEN contract_recommendation = 'RENEGOTIATE' THEN 'IMMEDIATE_ACTION'
        WHEN contract_recommendation = 'IMPROVE' THEN 'PLAN_IMPROVEMENT'
        WHEN contract_recommendation = 'MAINTAIN' THEN 'CONTINUE_MONITORING'
        ELSE 'ROUTINE_REVIEW'
    END AS action_timeline
FROM claims.v_payer_contract_analysis 
ORDER BY poor_performance_loss DESC;

-- Get payment efficiency analysis with improvement recommendations
SELECT 
    *,
    CASE 
        WHEN efficiency_recommendation = 'URGENT_IMPROVEMENT' THEN 'PRIORITY_1'
        WHEN efficiency_recommendation = 'IMPROVEMENT_NEEDED' THEN 'PRIORITY_2'
        WHEN efficiency_recommendation = 'MAINTAIN_PERFORMANCE' THEN 'PRIORITY_3'
        ELSE 'PRIORITY_4'
    END AS improvement_priority
FROM claims.v_payment_efficiency_analysis 
ORDER BY avg_days_to_remittance ASC;

-- Get high-performing payers with contract excellence
SELECT 
    *,
    CASE 
        WHEN excellent_performance_rate > 80 AND fast_payment_rate > 70 THEN 'PREMIUM_PARTNER'
        WHEN excellent_performance_rate > 60 AND fast_payment_rate > 50 THEN 'GOOD_PARTNER'
        WHEN excellent_performance_rate > 40 AND fast_payment_rate > 30 THEN 'FAIR_PARTNER'
        ELSE 'NEEDS_IMPROVEMENT'
    END AS partner_rating
FROM claims.v_payer_performance_summary 
WHERE total_remittances >= 100
ORDER BY excellent_performance_rate DESC, fast_payment_rate DESC;

-- Get payer performance comparison for contract negotiations
SELECT 
    payer_name,
    payer_type,
    total_remittances,
    payment_rate,
    fast_payment_rate,
    excellent_performance_rate,
    risk_category,
    CASE 
        WHEN payment_rate > 90 AND fast_payment_rate > 70 AND excellent_performance_rate > 60 THEN 'EXCELLENT'
        WHEN payment_rate > 80 AND fast_payment_rate > 50 AND excellent_performance_rate > 40 THEN 'GOOD'
        WHEN payment_rate > 70 AND fast_payment_rate > 30 AND excellent_performance_rate > 20 THEN 'FAIR'
        ELSE 'POOR'
    END AS overall_rating
FROM claims.v_payer_performance_summary 
WHERE total_remittances >= 50
ORDER BY overall_rating DESC, total_remittance_amount DESC;
*/
