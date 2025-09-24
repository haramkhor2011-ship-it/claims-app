-- ==========================================================================================================
-- VIEW AND MATERIALIZED VIEW GENERATOR FROM JSON MAPPING
-- ==========================================================================================================
-- 
-- Date: 2025-01-14
-- Purpose: Generate views and materialized views based on report_columns_xml_mappings.json
-- 
-- This script creates a framework for generating database views and materialized views
-- based on the comprehensive field mappings defined in the JSON configuration file.
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: HELPER FUNCTIONS FOR VIEW GENERATION
-- ==========================================================================================================

-- Function to generate column definitions from mapping
CREATE OR REPLACE FUNCTION claims.generate_column_definition(
    p_report_column TEXT,
    p_submission_db_path TEXT,
    p_remittance_db_path TEXT,
    p_data_type TEXT,
    p_best_path TEXT,
    p_notes TEXT
) RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_column_name TEXT;
    v_column_definition TEXT;
    v_data_type_mapping TEXT;
BEGIN
    -- Clean column name (remove spaces, special chars)
    v_column_name := LOWER(REGEXP_REPLACE(p_report_column, '[^a-zA-Z0-9_]', '_', 'g'));
    
    -- Map data types to PostgreSQL types
    v_data_type_mapping := CASE 
        WHEN p_data_type = 'text' THEN 'TEXT'
        WHEN p_data_type = 'integer' THEN 'INTEGER'
        WHEN p_data_type = 'numeric(14,2)' THEN 'NUMERIC(14,2)'
        WHEN p_data_type = 'timestamptz' THEN 'TIMESTAMPTZ'
        WHEN p_data_type = 'boolean' THEN 'BOOLEAN'
        WHEN p_data_type = 'array of text' THEN 'TEXT[]'
        ELSE 'TEXT'
    END;
    
    -- Generate column definition based on best path
    IF p_best_path LIKE '%derived%' OR p_best_path LIKE '%Derived%' THEN
        -- For derived fields, create a CASE statement or calculation
        v_column_definition := FORMAT('  %s %s, -- Derived: %s', 
            v_column_name, v_data_type_mapping, p_notes);
    ELSIF p_best_path LIKE '%claims.%' THEN
        -- For direct database fields
        v_column_definition := FORMAT('  %s %s, -- %s', 
            v_column_name, v_data_type_mapping, p_best_path);
    ELSE
        -- For other cases, use the best path as is
        v_column_definition := FORMAT('  %s %s, -- %s', 
            v_column_name, v_data_type_mapping, p_best_path);
    END IF;
    
    RETURN v_column_definition;
END;
$$;

COMMENT ON FUNCTION claims.generate_column_definition IS 'Generates column definitions for views based on mapping configuration';

-- ==========================================================================================================
-- SECTION 2: CORE REPORT VIEWS BASED ON JSON MAPPING
-- ==========================================================================================================

-- Comprehensive Claims Report View (based on JSON mapping)
CREATE OR REPLACE VIEW claims.v_comprehensive_claims_report AS
SELECT 
  -- Basic Claim Information
  ck.id AS claim_key_id,
  ck.claim_id,
  c.id AS claim_id_internal,
  c.payer_id,
  c.provider_id,
  c.member_id,
  c.emirates_id_number,
  c.gross AS initial_gross_amount,
  c.patient_share AS initial_patient_share,
  c.net AS initial_net_amount,
  c.tx_at AS claim_submission_date,
  c.comments AS claim_comments,
  
  -- Activity Information
  a.activity_id,
  a.start_at AS activity_start_date,
  a.end_at AS activity_end_date,
  a.clinician,
  a.code AS cpt_code,
  a.type AS cpt_type,
  a.quantity,
  a.net AS activity_net_amount,
  a.prior_authorization_id,
  
  -- Encounter Information
  e.facility_id,
  e.type AS encounter_type,
  e.patient_id,
  e.start_at AS encounter_start,
  e.end_at AS encounter_end,
  EXTRACT(YEAR FROM e.start_at) AS encounter_start_year,
  EXTRACT(MONTH FROM e.start_at) AS encounter_start_month,
  TO_CHAR(e.start_at, 'Month') AS encounter_start_month_name,
  
  -- Provider/Facility Information
  p.name AS provider_name,
  p.provider_code,
  f.name AS facility_name,
  f.facility_code,
  
  -- Payer Information
  pay.name AS payer_name,
  pay.payer_code,
  
  -- Remittance Information
  rc.id AS remittance_claim_id,
  rc.date_settlement,
  rc.payment_reference,
  rc.comments AS remittance_comments,
  ra.payment_amount,
  ra.denial_code,
  ra.net AS remittance_net_amount,
  
  -- Calculated Fields
  CASE 
    WHEN c.net IS NULL OR c.net = 0 THEN 0
    ELSE c.net - COALESCE(ra.payment_amount, 0)
  END AS outstanding_balance,
  
  CASE 
    WHEN ra.payment_amount = 0 THEN 'unpaid'
    WHEN ra.payment_amount = c.net THEN 'paid'
    WHEN ra.payment_amount < c.net THEN 'partial'
    ELSE 'unknown'
  END AS payment_status,
  
  EXTRACT(DAYS FROM (CURRENT_DATE - e.start_at)) AS aging_days,
  
  CASE 
    WHEN EXTRACT(DAYS FROM (CURRENT_DATE - e.start_at)) <= 30 THEN '0-30'
    WHEN EXTRACT(DAYS FROM (CURRENT_DATE - e.start_at)) <= 60 THEN '31-60'
    WHEN EXTRACT(DAYS FROM (CURRENT_DATE - e.start_at)) <= 90 THEN '61-90'
    ELSE '90+'
  END AS aging_bucket,
  
  -- File Information
  if_sub.file_id AS submission_file_id,
  if_rem.file_id AS remittance_file_id,
  if_sub.transaction_date AS submission_transaction_date,
  if_rem.transaction_date AS remittance_transaction_date,
  if_sub.sender_id,
  if_sub.receiver_id

FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims_ref.provider p ON p.provider_code = c.provider_id
LEFT JOIN claims_ref.facility f ON f.facility_code = e.facility_id
LEFT JOIN claims_ref.payer pay ON pay.payer_code = c.payer_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id AND ra.activity_id = a.activity_id
LEFT JOIN claims.submission s ON s.id = c.submission_id
LEFT JOIN claims.ingestion_file if_sub ON if_sub.id = s.ingestion_file_id
LEFT JOIN claims.remittance rem ON rem.claim_key_id = ck.id
LEFT JOIN claims.ingestion_file if_rem ON if_rem.id = rem.ingestion_file_id;

COMMENT ON VIEW claims.v_comprehensive_claims_report IS 'Comprehensive claims report view based on JSON mapping configuration';

-- ==========================================================================================================
-- SECTION 3: SPECIALIZED VIEWS FOR SPECIFIC REPORT TYPES
-- ==========================================================================================================

-- Balance Amount Report View (enhanced from existing implementation)
CREATE OR REPLACE VIEW claims.v_balance_amount_report AS
SELECT 
  ccr.claim_key_id,
  ccr.claim_id,
  ccr.provider_name AS facility_group_id,
  ccr.provider_name AS health_authority,
  ccr.facility_id,
  ccr.facility_name,
  ccr.claim_id AS claim_number,
  ccr.encounter_start AS encounter_start_date,
  ccr.encounter_end AS encounter_end_date,
  ccr.encounter_start_year,
  ccr.encounter_start_month,
  ccr.payer_id AS id_payer,
  ccr.patient_id,
  ccr.member_id,
  ccr.emirates_id_number,
  ccr.initial_net_amount AS claim_amt,
  COALESCE(ccr.payment_amount, 0) AS remitted_amt,
  ccr.outstanding_balance AS pending_amt,
  ccr.payment_status,
  ccr.aging_days,
  ccr.aging_bucket,
  ccr.claim_submission_date,
  ccr.submission_file_id AS last_submission_file,
  ccr.denial_code,
  ccr.remittance_comments
FROM claims.v_comprehensive_claims_report ccr
WHERE ccr.outstanding_balance > 0;

COMMENT ON VIEW claims.v_balance_amount_report IS 'Balance amount report view based on JSON mapping';

-- Rejected Claims Report View
CREATE OR REPLACE VIEW claims.v_rejected_claims_report AS
SELECT 
  ccr.claim_key_id,
  ccr.claim_id,
  ccr.facility_id,
  ccr.facility_name,
  ccr.provider_name AS facility_group,
  ccr.claim_id AS claim_number,
  ccr.encounter_start AS encounter_start_date,
  ccr.payer_id,
  ccr.payer_name,
  ccr.activity_id AS claim_activity_number,
  ccr.cpt_code,
  ccr.cpt_type,
  ccr.activity_net_amount AS net_amount,
  ccr.denial_code,
  ccr.remittance_comments AS denial_comment,
  ccr.payment_status,
  ccr.aging_days,
  ccr.claim_submission_date,
  ccr.remittance_file_id AS last_remittance_file
FROM claims.v_comprehensive_claims_report ccr
WHERE ccr.denial_code IS NOT NULL OR ccr.payment_status = 'unpaid';

COMMENT ON VIEW claims.v_rejected_claims_report IS 'Rejected claims report view based on JSON mapping';

-- Remittance Advice Report View
CREATE OR REPLACE VIEW claims.v_remittance_advice_report AS
SELECT 
  ccr.claim_key_id,
  ccr.claim_id,
  ccr.facility_id,
  ccr.facility_name,
  ccr.provider_name AS facility_group,
  ccr.claim_id AS claim_number,
  ccr.encounter_start AS encounter_start_date,
  ccr.payer_id,
  ccr.payer_name,
  ccr.activity_id AS claim_activity_number,
  ccr.cpt_code,
  ccr.cpt_type,
  ccr.activity_net_amount AS initial_net_amount,
  ccr.payment_amount AS remitted_amount,
  ccr.denial_code,
  ccr.remittance_comments,
  ccr.date_settlement,
  ccr.payment_reference,
  ccr.remittance_transaction_date,
  ccr.remittance_file_id
FROM claims.v_comprehensive_claims_report ccr
WHERE ccr.remittance_claim_id IS NOT NULL;

COMMENT ON VIEW claims.v_remittance_advice_report IS 'Remittance advice report view based on JSON mapping';

-- ==========================================================================================================
-- SECTION 4: MATERIALIZED VIEWS FOR PERFORMANCE
-- ==========================================================================================================

-- Materialized view for comprehensive claims report (refresh daily)
CREATE MATERIALIZED VIEW claims.mv_comprehensive_claims_report AS
SELECT * FROM claims.v_comprehensive_claims_report;

CREATE UNIQUE INDEX ON claims.mv_comprehensive_claims_report (claim_key_id, activity_id);

COMMENT ON MATERIALIZED VIEW claims.mv_comprehensive_claims_report IS 'Materialized view for comprehensive claims report - refresh daily for performance';

-- Materialized view for balance amount report (refresh daily)
CREATE MATERIALIZED VIEW claims.mv_balance_amount_report AS
SELECT * FROM claims.v_balance_amount_report;

CREATE UNIQUE INDEX ON claims.mv_balance_amount_report (claim_key_id);

COMMENT ON MATERIALIZED VIEW claims.mv_balance_amount_report IS 'Materialized view for balance amount report - refresh daily for performance';

-- Materialized view for rejected claims report (refresh daily)
CREATE MATERIALIZED VIEW claims.mv_rejected_claims_report AS
SELECT * FROM claims.v_rejected_claims_report;

CREATE UNIQUE INDEX ON claims.mv_rejected_claims_report (claim_key_id, activity_id);

COMMENT ON MATERIALIZED VIEW claims.mv_rejected_claims_report IS 'Materialized view for rejected claims report - refresh daily for performance';

-- ==========================================================================================================
-- SECTION 5: REFRESH FUNCTIONS FOR MATERIALIZED VIEWS
-- ==========================================================================================================

-- Function to refresh all materialized views
CREATE OR REPLACE FUNCTION claims.refresh_all_report_materialized_views()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RAISE NOTICE 'Refreshing materialized views...';
  
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_comprehensive_claims_report;
  RAISE NOTICE 'Refreshed mv_comprehensive_claims_report';
  
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_balance_amount_report;
  RAISE NOTICE 'Refreshed mv_balance_amount_report';
  
  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_rejected_claims_report;
  RAISE NOTICE 'Refreshed mv_rejected_claims_report';
  
  RAISE NOTICE 'All materialized views refreshed successfully!';
END;
$$;

COMMENT ON FUNCTION claims.refresh_all_report_materialized_views IS 'Refreshes all report materialized views concurrently';

-- ==========================================================================================================
-- SECTION 6: GRANTS
-- ==========================================================================================================

-- Grant access to views
GRANT SELECT ON claims.v_comprehensive_claims_report TO claims_user;
GRANT SELECT ON claims.v_balance_amount_report TO claims_user;
GRANT SELECT ON claims.v_rejected_claims_report TO claims_user;
GRANT SELECT ON claims.v_remittance_advice_report TO claims_user;

-- Grant access to materialized views
GRANT SELECT ON claims.mv_comprehensive_claims_report TO claims_user;
GRANT SELECT ON claims.mv_balance_amount_report TO claims_user;
GRANT SELECT ON claims.mv_rejected_claims_report TO claims_user;

-- Grant access to functions
GRANT EXECUTE ON FUNCTION claims.generate_column_definition TO claims_user;
GRANT EXECUTE ON FUNCTION claims.refresh_all_report_materialized_views TO claims_user;

-- ==========================================================================================================
-- SECTION 7: USAGE EXAMPLES
-- ==========================================================================================================

-- Example 1: Get all claims with outstanding balance
-- SELECT 
--   claim_number,
--   facility_name,
--   provider_name as facility_group,
--   claim_amt,
--   pending_amt,
--   aging_days,
--   payment_status
-- FROM claims.v_balance_amount_report 
-- WHERE pending_amt > 1000
-- ORDER BY aging_days DESC;

-- Example 2: Get rejected claims by facility
-- SELECT 
--   facility_name,
--   COUNT(*) as rejected_count,
--   SUM(net_amount) as total_rejected_amount,
--   COUNT(DISTINCT denial_code) as unique_denial_codes
-- FROM claims.v_rejected_claims_report
-- GROUP BY facility_name
-- ORDER BY rejected_count DESC;

-- Example 3: Get remittance summary by payer
-- SELECT 
--   payer_name,
--   COUNT(*) as remittance_count,
--   SUM(remitted_amount) as total_remitted,
--   AVG(remitted_amount) as avg_remitted
-- FROM claims.v_remittance_advice_report
-- WHERE date_settlement >= CURRENT_DATE - INTERVAL '30 days'
-- GROUP BY payer_name
-- ORDER BY total_remitted DESC;

-- ==========================================================================================================
-- END OF VIEW GENERATOR FROM JSON MAPPING
-- ==========================================================================================================

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'View and Materialized View Generator from JSON Mapping created successfully!';
  RAISE NOTICE 'Created views:';
  RAISE NOTICE '1. v_comprehensive_claims_report - Main comprehensive view';
  RAISE NOTICE '2. v_balance_amount_report - Balance amount specific view';
  RAISE NOTICE '3. v_rejected_claims_report - Rejected claims specific view';
  RAISE NOTICE '4. v_remittance_advice_report - Remittance advice specific view';
  RAISE NOTICE 'Created materialized views for performance optimization';
  RAISE NOTICE 'Use claims.refresh_all_report_materialized_views() to refresh MVs';
  RAISE NOTICE 'Ready for production use!';
END$$;
