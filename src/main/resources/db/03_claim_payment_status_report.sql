-- =====================================================
-- CLAIM PAYMENT STATUS REPORT
-- =====================================================
-- This report provides detailed payment status information for claims
-- including payment amounts, dates, methods, and status tracking.

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
    c.total_amount,
    c.paid_amount,
    c.balance_amount,
    c.created_at AS claim_created_at,
    c.updated_at AS claim_updated_at,
    
    -- Payment Information
    p.id AS payment_id,
    p.payment_method,
    p.payment_status,
    p.payment_amount,
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
    r.total_remittance_amount,
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
    
    -- Calculated Fields
    CASE 
        WHEN c.status = 'PAID' AND c.balance_amount = 0 THEN 'FULLY_PAID'
        WHEN c.status = 'PAID' AND c.balance_amount > 0 THEN 'PARTIALLY_PAID'
        WHEN c.status = 'PENDING' THEN 'PENDING_PAYMENT'
        WHEN c.status = 'REJECTED' THEN 'PAYMENT_REJECTED'
        ELSE 'UNKNOWN_STATUS'
    END AS payment_status_category,
    
    CASE 
        WHEN p.payment_date IS NOT NULL THEN EXTRACT(DAYS FROM (p.payment_date - c.created_at))
        ELSE NULL
    END AS days_to_payment,
    
    CASE 
        WHEN p.processed_date IS NOT NULL THEN EXTRACT(DAYS FROM (p.processed_date - p.payment_date))
        ELSE NULL
    END AS days_to_process_payment

FROM claims.claim c
LEFT JOIN claims.payment p ON c.id = p.claim_id
LEFT JOIN claims.remittance r ON c.remittance_id = r.id
LEFT JOIN claims.provider pr ON c.provider_id = pr.id
LEFT JOIN claims.facility f ON c.facility_id = f.id
LEFT JOIN claims.patient pt ON c.patient_id = pt.id
WHERE claims.check_user_facility_access(f.id);

-- Payment summary by status
CREATE OR REPLACE VIEW claims.v_payment_status_summary AS
SELECT 
    payment_status_category,
    claim_status,
    COUNT(*) AS claim_count,
    SUM(total_amount) AS total_claim_amount,
    SUM(paid_amount) AS total_paid_amount,
    SUM(balance_amount) AS total_balance_amount,
    AVG(days_to_payment) AS avg_days_to_payment,
    AVG(days_to_process_payment) AS avg_days_to_process_payment,
    MIN(payment_date) AS earliest_payment_date,
    MAX(payment_date) AS latest_payment_date
FROM claims.v_claim_payment_status
GROUP BY payment_status_category, claim_status
ORDER BY payment_status_category, claim_status;

-- Payment method analysis
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
    COUNT(CASE WHEN payment_status = 'PENDING' THEN 1 END) AS pending_payments
FROM claims.v_claim_payment_status
WHERE payment_method IS NOT NULL
GROUP BY payment_method
ORDER BY total_payment_amount DESC;

-- Provider payment performance
CREATE OR REPLACE VIEW claims.v_provider_payment_performance AS
SELECT 
    provider_id,
    provider_name,
    provider_npi,
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
        SUM(paid_amount) * 100.0 / SUM(total_amount), 2
    ) AS payment_collection_rate
FROM claims.v_claim_payment_status
GROUP BY provider_id, provider_name, provider_npi
ORDER BY total_claim_amount DESC;

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_claim_id ON claims.claim(id);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_payment_id ON claims.payment(claim_id);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_remittance_id ON claims.remittance(id);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_provider_id ON claims.provider(id);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_facility_id ON claims.facility(id);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_patient_id ON claims.patient(id);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_payment_date ON claims.payment(payment_date);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_payment_method ON claims.payment(payment_method);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_payment_status ON claims.payment(payment_status);

-- Comments and documentation
COMMENT ON VIEW claims.v_claim_payment_status IS 'Detailed payment status information for claims including payment amounts, dates, methods, and status tracking';
COMMENT ON VIEW claims.v_payment_status_summary IS 'Summary of payment status categories with counts and amounts';
COMMENT ON VIEW claims.v_payment_method_analysis IS 'Analysis of payment methods with performance metrics';
COMMENT ON VIEW claims.v_provider_payment_performance IS 'Provider payment performance metrics including success rates and collection rates';

-- Usage examples
/*
-- Get payment status for specific provider
SELECT * FROM claims.v_claim_payment_status 
WHERE provider_npi = '1234567890' 
ORDER BY payment_date DESC;

-- Get payment summary by status
SELECT * FROM claims.v_payment_status_summary 
ORDER BY total_claim_amount DESC;

-- Get payment method analysis
SELECT * FROM claims.v_payment_method_analysis 
ORDER BY total_payment_amount DESC;

-- Get provider payment performance
SELECT * FROM claims.v_provider_payment_performance 
WHERE total_claims >= 10 
ORDER BY payment_collection_rate DESC;

-- Get outstanding payments
SELECT claim_id, claim_number, provider_name, total_amount, balance_amount, days_to_payment
FROM claims.v_claim_payment_status 
WHERE balance_amount > 0 
ORDER BY days_to_payment DESC;
*/
