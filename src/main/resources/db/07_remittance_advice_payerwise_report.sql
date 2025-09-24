-- =====================================================
-- REMITTANCE ADVICE PAYERWISE REPORT
-- =====================================================
-- This report provides detailed analysis of remittance advice by payer
-- including payment amounts, adjustments, and performance metrics.

-- Main remittance advice payerwise view
CREATE OR REPLACE VIEW claims.v_remittance_advice_payerwise AS
SELECT 
    -- Remittance Information
    r.id AS remittance_id,
    r.remittance_type,
    r.status AS remittance_status,
    r.remittance_date,
    r.total_remittance_amount,
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
    c.total_amount,
    c.paid_amount,
    c.balance_amount,
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
    
    -- Calculated Fields
    CASE 
        WHEN r.remittance_date IS NOT NULL THEN EXTRACT(DAYS FROM (r.remittance_date - c.created_at))
        ELSE NULL
    END AS days_to_remittance,
    
    CASE 
        WHEN r.total_remittance_amount > c.total_amount * 0.8 THEN 'HIGH_PAYMENT'
        WHEN r.total_remittance_amount > c.total_amount * 0.5 THEN 'MEDIUM_PAYMENT'
        WHEN r.total_remittance_amount > 0 THEN 'LOW_PAYMENT'
        ELSE 'NO_PAYMENT'
    END AS payment_level,
    
    CASE 
        WHEN r.total_remittance_amount = c.total_amount THEN 'FULL_PAYMENT'
        WHEN r.total_remittance_amount > 0 THEN 'PARTIAL_PAYMENT'
        ELSE 'NO_PAYMENT'
    END AS payment_status

FROM claims.remittance r
JOIN claims.payer p ON r.payer_id = p.id
LEFT JOIN claims.claim c ON r.claim_id = c.id
LEFT JOIN claims.provider pr ON c.provider_id = pr.id
LEFT JOIN claims.facility f ON c.facility_id = f.id
LEFT JOIN claims.patient pt ON c.patient_id = pt.id
WHERE claims.check_user_facility_access(f.id);

-- Payer performance summary view
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
    ROUND(
        COUNT(CASE WHEN payment_status = 'FULL_PAYMENT' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS full_payment_rate,
    ROUND(
        SUM(total_remittance_amount) * 100.0 / SUM(total_amount), 2
    ) AS payment_rate
FROM claims.v_remittance_advice_payerwise
GROUP BY payer_id, payer_name, payer_code, payer_type
ORDER BY total_remittance_amount DESC;

-- Monthly payer trends view
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
    ROUND(
        COUNT(CASE WHEN payment_status = 'FULL_PAYMENT' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS full_payment_rate,
    ROUND(
        SUM(total_remittance_amount) * 100.0 / SUM(total_amount), 2
    ) AS payment_rate
FROM claims.v_remittance_advice_payerwise
GROUP BY 
    DATE_TRUNC('month', remittance_date),
    payer_id,
    payer_name,
    payer_code
ORDER BY report_month DESC, total_remittance_amount DESC;

-- Provider-payer performance view
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
    ROUND(
        COUNT(CASE WHEN payment_status = 'FULL_PAYMENT' THEN 1 END) * 100.0 / COUNT(*), 2
    ) AS full_payment_rate,
    ROUND(
        SUM(total_remittance_amount) * 100.0 / SUM(total_amount), 2
    ) AS payment_rate
FROM claims.v_remittance_advice_payerwise
GROUP BY 
    provider_id,
    provider_name,
    provider_npi,
    payer_id,
    payer_name,
    payer_code
ORDER BY total_remittance_amount DESC;

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_remittance_advice_remittance_id ON claims.remittance(id);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_payer_id ON claims.payer(id);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_claim_id ON claims.claim(id);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_provider_id ON claims.provider(id);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_facility_id ON claims.facility(id);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_patient_id ON claims.patient(id);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_remittance_date ON claims.remittance(remittance_date);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_payer_code ON claims.payer(payer_code);
CREATE INDEX IF NOT EXISTS idx_remittance_advice_payer_type ON claims.payer(payer_type);

-- Comments and documentation
COMMENT ON VIEW claims.v_remittance_advice_payerwise IS 'Detailed analysis of remittance advice by payer including payment amounts, adjustments, and performance metrics';
COMMENT ON VIEW claims.v_payer_performance_summary IS 'Summary of payer performance including payment rates and processing times';
COMMENT ON VIEW claims.v_monthly_payer_trends IS 'Monthly trends in payer performance and payment patterns';
COMMENT ON VIEW claims.v_provider_payer_performance IS 'Provider-specific performance metrics by payer';

-- Usage examples
/*
-- Get remittance advice for specific payer
SELECT * FROM claims.v_remittance_advice_payerwise 
WHERE payer_code = 'PAYER001' 
ORDER BY remittance_date DESC;

-- Get payer performance summary
SELECT * FROM claims.v_payer_performance_summary 
ORDER BY payment_rate DESC;

-- Get monthly payer trends
SELECT * FROM claims.v_monthly_payer_trends 
WHERE report_month >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months')
ORDER BY report_month DESC, total_remittance_amount DESC;

-- Get provider-payer performance
SELECT * FROM claims.v_provider_payer_performance 
WHERE provider_npi = '1234567890' 
ORDER BY payment_rate DESC;

-- Get high-performing payers
SELECT * FROM claims.v_payer_performance_summary 
WHERE full_payment_rate > 80 
    AND payment_rate > 90
ORDER BY total_remittance_amount DESC;
*/
