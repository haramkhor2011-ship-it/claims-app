-- =====================================================
-- REMITTANCE ADVICE PAYERWISE REPORT - PRODUCTION READY
-- =====================================================
-- This report provides the exact structure needed for the Remittance Advice – Payerwise Report
-- with three tabs: Header, Claim Wise, and Activity Wise as specified in the requirements.

-- =====================================================
-- TAB A: HEADER LEVEL VIEW (Provider/Authorization Summary)
-- =====================================================

CREATE OR REPLACE VIEW claims.v_remittance_advice_header AS
SELECT
    -- Provider Information
    --COALESCE(cl.name, '') AS ordering_clinician_name,
    --COALESCE(cl.clinician_code, '') AS ordering_clinician,
    COALESCE(act.clinician, '') AS clinician_id,
    COALESCE(cl.name, '') AS clinician_name,

    -- Authorization Information
    COALESCE(act.prior_authorization_id, '') AS prior_authorization_id,

    -- File Information
    COALESCE(ifile.file_name, '') AS xml_file_name,

    -- Remittance Information
    ''::text AS remittance_comments,

    -- Aggregated Metrics
    COUNT(DISTINCT rc.id) AS total_claims,
    COUNT(DISTINCT ra.id) AS total_activities,
    SUM(COALESCE(act.net, 0)) AS total_billed_amount,
    SUM(COALESCE(ra.payment_amount, 0)) AS total_paid_amount,
    SUM(COALESCE(act.net - ra.payment_amount, 0)) AS total_denied_amount,

    -- Calculated Fields
    ROUND(
        CASE
            WHEN SUM(COALESCE(act.net, 0)) > 0
            THEN (SUM(COALESCE(ra.payment_amount, 0)) / SUM(COALESCE(act.net, 0))) * 100
            ELSE 0
        END, 2
    ) AS collection_rate,

    COUNT(CASE WHEN ra.denial_code IS NOT NULL OR ra.payment_amount = 0 THEN 1 END) AS denied_activities_count,

    -- Facility and Organization Info
    COALESCE(f.facility_code, '') AS facility_id,
    COALESCE(f.name, '') AS facility_name,
    COALESCE(p.payer_code, '') AS payer_id,
    COALESCE(p.name, '') AS payer_name,
    COALESCE(rp.payer_code, '') AS receiver_id,
    COALESCE(rp.name, '') AS receiver_name,

    -- Transaction Information
    r.tx_at AS remittance_date,
    COALESCE(ifile.transaction_date, r.tx_at) AS submission_date

FROM claims.remittance r
JOIN claims.remittance_claim rc ON r.id = rc.remittance_id
JOIN claims.remittance_activity ra ON rc.id = ra.remittance_claim_id
LEFT JOIN claims.claim c ON c.claim_key_id = rc.claim_key_id
JOIN claims.activity act ON act.claim_id = c.id AND act.activity_id = ra.activity_id
LEFT JOIN claims_ref.clinician cl ON act.clinician_ref_id = cl.id  -- Ordering clinician
LEFT JOIN claims.encounter enc ON enc.claim_id = c.id
LEFT JOIN claims_ref.facility f ON enc.facility_ref_id = f.id
LEFT JOIN claims_ref.payer p ON rc.payer_ref_id = p.id
LEFT JOIN claims.ingestion_file ifile ON r.ingestion_file_id = ifile.id
LEFT JOIN claims_ref.payer rp ON ifile.receiver_id = rp.payer_code  -- Receiver info from file

GROUP BY
    cl.name, cl.clinician_code, act.clinician,
    act.prior_authorization_id, ifile.file_name,
    f.facility_code, f.name, p.payer_code, p.name, rp.payer_code, rp.name,
    r.tx_at, ifile.transaction_date

ORDER BY total_paid_amount DESC, clinician_name;

-- =====================================================
-- TAB B: CLAIM WISE VIEW (Claim Level Details)
-- =====================================================

CREATE OR REPLACE VIEW claims.v_remittance_advice_claim_wise AS
SELECT
    -- Payer Information
    COALESCE(p.name, '') AS payer_name,

    -- Transaction Information
    r.tx_at AS transaction_date,

    -- Encounter Information
    enc.start_at AS encounter_start,

    -- Claim Information
    ck.claim_id AS claim_number,
    COALESCE(rc.id_payer, '') AS id_payer,
    COALESCE(c.member_id, '') AS member_id,
    COALESCE(rc.payment_reference, '') AS payment_reference,

    -- Activity Information
    COALESCE(ra.activity_id, '') AS claim_activity_number,
    act.start_at AS start_date,

    -- Facility Information
    COALESCE(fac.facility_code, '') AS facility_group,
    COALESCE(ha.payer_code, '') AS health_authority,
    COALESCE(f.facility_code, '') AS facility_id,
    COALESCE(f.name, '') AS facility_name,

    -- Receiver Information
    COALESCE(rec.payer_code, '') AS receiver_id,
    COALESCE(rec.name, '') AS receiver_name,

    -- Payer Information (from claim)
    COALESCE(pc.payer_code, '') AS payer_id,

    -- Financial Information
    COALESCE(c.net, 0) AS claim_amount,
    COALESCE(SUM(ra.payment_amount), 0) AS remittance_amount,

    -- File Information
    COALESCE(ifile.file_name, '') AS xml_file_name,

    -- Aggregated Metrics
    COUNT(ra.id) AS activity_count,
    SUM(COALESCE(ra.payment_amount, 0)) AS total_paid,
    SUM(COALESCE(c.net - ra.payment_amount, 0)) AS total_denied,

    -- Calculated Fields
    ROUND(
        CASE
            WHEN COALESCE(c.net, 0) > 0
            THEN (SUM(COALESCE(ra.payment_amount, 0)) / c.net) * 100
            ELSE 0
        END, 2
    ) AS collection_rate,

    COUNT(CASE WHEN ra.denial_code IS NOT NULL OR ra.payment_amount = 0 THEN 1 END) AS denied_count

FROM claims.remittance r
JOIN claims.remittance_claim rc ON r.id = rc.remittance_id
JOIN claims.claim_key ck ON rc.claim_key_id = ck.id
LEFT JOIN claims.claim c ON ck.id = c.claim_key_id
LEFT JOIN claims.remittance_activity ra ON rc.id = ra.remittance_claim_id
LEFT JOIN claims.activity act ON act.claim_id = c.id AND act.activity_id = ra.activity_id
LEFT JOIN claims.encounter enc ON c.id = enc.claim_id
LEFT JOIN claims_ref.facility f ON enc.facility_ref_id = f.id
LEFT JOIN claims_ref.facility fac ON enc.facility_id = fac.facility_code
LEFT JOIN claims_ref.payer p ON rc.payer_ref_id = p.id
LEFT JOIN claims_ref.payer pc ON c.payer_ref_id = pc.id
LEFT JOIN claims_ref.payer ha ON c.payer_ref_id = ha.id  -- Health authority
LEFT JOIN claims.ingestion_file ifile ON r.ingestion_file_id = ifile.id
LEFT JOIN claims_ref.payer rec ON ifile.receiver_id = rec.payer_code

GROUP BY
    p.name, r.tx_at, enc.start_at, ck.claim_id, rc.id_payer, c.member_id,
    rc.payment_reference, ra.activity_id, act.start_at, fac.facility_code,
    ha.payer_code, f.facility_code, f.name, rec.payer_code, rec.name,
    pc.payer_code, c.net, ifile.file_name, rc.id

ORDER BY transaction_date DESC, claim_number;

-- =====================================================
-- TAB C: ACTIVITY WISE VIEW (Line-item Level Details)
-- =====================================================

CREATE OR REPLACE VIEW claims.v_remittance_advice_activity_wise AS
SELECT
    -- Date Information
    act.start_at AS start_date,

    -- CPT Information
    COALESCE(act.type, '') AS cpt_type,
    COALESCE(act.code, '') AS cpt_code,
    COALESCE(act.quantity, 0) AS quantity,
    COALESCE(act.net, 0) AS net_amount,
    COALESCE(ra.payment_amount, 0) AS payment_amount,

    -- Denial Information
    COALESCE(ra.denial_code, '') AS denial_code,

    -- Clinician Information
    COALESCE(act.clinician, '') AS ordering_clinician,
    COALESCE(cl.name, '') AS ordering_clinician_name,
    COALESCE(act.clinician, '') AS clinician,

    -- File Information
    COALESCE(ifile.file_name, '') AS xml_file_name,

    -- Calculated Fields
    COALESCE(act.net - ra.payment_amount, 0) AS denied_amount,
    ROUND(
        CASE
            WHEN COALESCE(act.net, 0) > 0
            THEN (COALESCE(ra.payment_amount, 0) / act.net) * 100
            ELSE 0
        END, 2
    ) AS payment_percentage,

    CASE
        WHEN ra.denial_code IS NOT NULL OR ra.payment_amount = 0 THEN 'DENIED'
        WHEN ra.payment_amount = act.net THEN 'FULLY_PAID'
        WHEN ra.payment_amount > 0 AND ra.payment_amount < act.net THEN 'PARTIALLY_PAID'
        ELSE 'UNPAID'
    END AS payment_status,

    -- Unit Price Calculation
    ROUND(
        CASE
            WHEN COALESCE(act.quantity, 0) > 0
            THEN (COALESCE(ra.payment_amount, 0) / act.quantity)
            ELSE 0
        END, 2
    ) AS unit_price,

    -- Facility and Payer Information
    COALESCE(f.facility_code, '') AS facility_id,
    COALESCE(p.payer_code, '') AS payer_id,
    ck.claim_id AS claim_number,
    enc.start_at AS encounter_start_date

FROM claims.remittance r
JOIN claims.remittance_claim rc ON r.id = rc.remittance_id
JOIN claims.remittance_activity ra ON rc.id = ra.remittance_claim_id
LEFT JOIN claims.claim c ON c.claim_key_id = rc.claim_key_id
JOIN claims.claim_key ck ON rc.claim_key_id = ck.id
JOIN claims.activity act ON act.claim_id = c.id AND act.activity_id = ra.activity_id
LEFT JOIN claims_ref.clinician cl ON act.clinician_ref_id = cl.id  -- Ordering clinician
LEFT JOIN claims.encounter enc ON c.id = enc.claim_id
LEFT JOIN claims_ref.facility f ON enc.facility_ref_id = f.id
LEFT JOIN claims_ref.payer p ON rc.payer_ref_id = p.id
LEFT JOIN claims.ingestion_file ifile ON r.ingestion_file_id = ifile.id

ORDER BY act.start_at DESC, act.code;

-- =====================================================
-- REPORT PARAMETER FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION claims.get_remittance_advice_report_params(
    p_from_date timestamptz DEFAULT NULL,
    p_to_date timestamptz DEFAULT NULL,
    p_facility_code text DEFAULT NULL,
    p_payer_code text DEFAULT NULL,
    p_receiver_code text DEFAULT NULL,
    p_payment_reference text DEFAULT NULL
)
RETURNS TABLE(
    total_claims bigint,
    total_activities bigint,
    total_billed_amount numeric(14,2),
    total_paid_amount numeric(14,2),
    total_denied_amount numeric(14,2),
    avg_collection_rate numeric(5,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(DISTINCT rc.id) AS total_claims,
        COUNT(DISTINCT ra.id) AS total_activities,
        SUM(COALESCE(act.net, 0)) AS total_billed_amount,
        SUM(COALESCE(ra.payment_amount, 0)) AS total_paid_amount,
        SUM(COALESCE(act.net - ra.payment_amount, 0)) AS total_denied_amount,
        ROUND(
            CASE
                WHEN SUM(COALESCE(act.net, 0)) > 0
                THEN (SUM(COALESCE(ra.payment_amount, 0)) / SUM(COALESCE(act.net, 0))) * 100
                ELSE 0
            END, 2
        ) AS avg_collection_rate

    FROM claims.remittance r
    JOIN claims.remittance_claim rc ON r.id = rc.remittance_id
    JOIN claims.remittance_activity ra ON rc.id = ra.remittance_claim_id
    LEFT JOIN claims.claim c ON c.claim_key_id = rc.claim_key_id
    JOIN claims.activity act ON act.claim_id = c.id AND act.activity_id = ra.activity_id
    LEFT JOIN claims.encounter enc ON c.id = enc.claim_id
    LEFT JOIN claims_ref.facility f ON enc.facility_ref_id = f.id
    LEFT JOIN claims_ref.payer p ON rc.payer_ref_id = p.id
    LEFT JOIN claims.ingestion_file ifile ON r.ingestion_file_id = ifile.id

    WHERE r.tx_at >= COALESCE(p_from_date, r.tx_at - INTERVAL '30 days')
      AND r.tx_at <= COALESCE(p_to_date, r.tx_at)
      AND (p_facility_code IS NULL OR f.facility_code = p_facility_code)
      AND (p_payer_code IS NULL OR p.payer_code = p_payer_code)
      AND (p_receiver_code IS NULL OR ifile.receiver_id = p_receiver_code)
      AND (p_payment_reference IS NULL OR rc.payment_reference = p_payment_reference);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PERFORMANCE INDEXES
-- =====================================================

-- Indexes for Header Tab
CREATE INDEX IF NOT EXISTS idx_remittance_advice_header_clinician
ON claims.activity(clinician_ref_id, start_at);

CREATE INDEX IF NOT EXISTS idx_remittance_advice_header_provider
ON claims_ref.provider(provider_code, name);

-- Indexes for Claim Wise Tab
CREATE INDEX IF NOT EXISTS idx_remittance_advice_claim_wise_dates
ON claims.remittance(tx_at, ingestion_file_id);

CREATE INDEX IF NOT EXISTS idx_remittance_advice_claim_wise_payer
ON claims.remittance_claim(payer_ref_id, payment_reference);

-- Indexes for Activity Wise Tab
CREATE INDEX IF NOT EXISTS idx_remittance_advice_activity_wise_dates
ON claims.activity(start_at, code, type);

CREATE INDEX IF NOT EXISTS idx_remittance_advice_activity_wise_payment
ON claims.remittance_activity(payment_amount, denial_code);

-- Composite indexes for filtering
CREATE INDEX IF NOT EXISTS idx_remittance_advice_filter_date_facility
ON claims.remittance(tx_at, ingestion_file_id);

CREATE INDEX IF NOT EXISTS idx_remittance_advice_filter_payer_date
ON claims.remittance_claim(payer_ref_id, remittance_id, payment_reference);

-- =====================================================
-- COMMENTS AND DOCUMENTATION
-- =====================================================

COMMENT ON VIEW claims.v_remittance_advice_header IS
'Enhanced Header tab view for Remittance Advice Payerwise report - Provider/authorization level summary with aggregated metrics';

COMMENT ON VIEW claims.v_remittance_advice_claim_wise IS
'Enhanced Claim Wise tab view for Remittance Advice Payerwise report - Claim level details with financial reconciliation';

COMMENT ON VIEW claims.v_remittance_advice_activity_wise IS
'Enhanced Activity Wise tab view for Remittance Advice Payerwise report - Line-item level CPT/procedure reconciliation';

COMMENT ON FUNCTION claims.get_remittance_advice_report_params IS
'Function to get summary parameters for Remittance Advice Payerwise report with filtering support';

-- =====================================================
-- USAGE EXAMPLES
-- =====================================================

/*
-- Get Header Tab Data
SELECT * FROM claims.v_remittance_advice_header
WHERE remittance_date >= '2025-01-01'
  AND remittance_date <= '2025-01-31'
  AND facility_id = 'FAC001';

-- Get Claim Wise Tab Data
SELECT * FROM claims.v_remittance_advice_claim_wise
WHERE transaction_date >= '2025-01-01'
  AND transaction_date <= '2025-01-31'
  AND payer_id = 'PAYER001';

-- Get Activity Wise Tab Data
SELECT * FROM claims.v_remittance_advice_activity_wise
WHERE start_date >= '2025-01-01'
  AND start_date <= '2025-01-31'
  AND facility_id = 'FAC001'
ORDER BY start_date DESC;

-- Get Report Summary Parameters
SELECT * FROM claims.get_remittance_advice_report_params(
    '2025-01-01'::timestamptz,
    '2025-01-31'::timestamptz,
    'FAC001',
    'PAYER001',
    'RECEIVER001',
    'PAYREF001'
);
*/
