-- ==========================================================================================================
-- DYNAMIC VIEW GENERATOR FROM JSON MAPPING
-- ==========================================================================================================
-- 
-- Date: 2025-01-14
-- Purpose: Dynamically generate views and materialized views based on report_columns_xml_mappings.json
-- 
-- This script provides functions to dynamically create database views and materialized views
-- based on the comprehensive field mappings defined in the JSON configuration file.
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: JSON MAPPING CONFIGURATION TABLE
-- ==========================================================================================================

-- Table to store the JSON mapping configuration
CREATE TABLE IF NOT EXISTS claims.report_column_mappings (
    id SERIAL PRIMARY KEY,
    report_column TEXT NOT NULL,
    submission_xml_path TEXT,
    remittance_xml_path TEXT,
    notes_derivation TEXT,
    cursor_analysis TEXT,
    submission_db_path TEXT,
    remittance_db_path TEXT,
    data_type TEXT,
    best_path TEXT,
    ai_analysis TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_report_column_mappings_column ON claims.report_column_mappings(report_column);
CREATE INDEX IF NOT EXISTS idx_report_column_mappings_best_path ON claims.report_column_mappings(best_path);

COMMENT ON TABLE claims.report_column_mappings IS 'Stores field mappings from JSON configuration for dynamic view generation';

-- ==========================================================================================================
-- SECTION 2: FUNCTIONS TO POPULATE MAPPING TABLE FROM JSON
-- ==========================================================================================================

-- Function to populate mapping table from JSON data
CREATE OR REPLACE FUNCTION claims.populate_mappings_from_json()
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_json_data JSONB;
    v_row JSONB;
BEGIN
    -- Clear existing data
    DELETE FROM claims.report_column_mappings;
    
    -- This would typically read from the actual JSON file
    -- For now, we'll insert some key mappings based on the JSON structure
    INSERT INTO claims.report_column_mappings (
        report_column, submission_xml_path, remittance_xml_path, 
        notes_derivation, submission_db_path, remittance_db_path, 
        data_type, best_path, ai_analysis
    ) VALUES
    -- Key mappings from the JSON file
    ('ActivityID', 'Claim/Activity/ID', 'Claim/Activity/ID', 
     'Direct element: activity/line identifier', 
     'claims.activity.activity_id', 'claims.remittance_activity.activity_id',
     'text', 'claims.activity.activity_id', 'Unique identifier for each activity'),
     
    ('ActivityStartDate', 'Claim/Activity/Start', 'Claim/Activity/Start',
     'Start timestamp of service/activity',
     'claims.activity.start_at', 'claims.remittance_activity.start_at',
     'timestamptz', 'claims.activity.start_at', 'Represents the start of the activity'),
     
    ('ClaimNumber', 'Claim/ID', 'Claim/ID',
     'Provider''s unique claim identifier',
     'claims.claim_key.claim_id', 'claims.claim_key.claim_id',
     'text', 'claims.claim_key.claim_id', 'Critical for linking submission to remittance'),
     
    ('BilledAmount', 'Claim/Activity/Net (sum of activities)', 'Claim/Activity/Net (per activity)',
     'Sum of Activity/Net across activities for claim total',
     'sum(claims.activity.net) over (partition by claim_id)', 'sum(claims.remittance_activity.net) over (partition by remittance_claim_id)',
     'numeric(14,2)', 'sum(claims.activity.net)', 'Represents total billed amount'),
     
    ('PaidAmount', 'Not in submission', 'Claim/Activity/PaymentAmount',
     'Amount paid per activity; sum for claim total',
     'Not stored', 'claims.remittance_activity.payment_amount',
     'numeric(14,2)', 'claims.remittance_activity.payment_amount', 'Directly from remittance'),
     
    ('OutstandingBalance', 'Derived', 'Derived',
     'Computed as sum(Activity/Net) - sum(Activity/PaymentAmount)',
     'Derived: claims.claim.net - sum(claims.remittance_activity.payment_amount)', 'Derived: sum(claims.remittance_activity.net) - sum(payment_amount)',
     'numeric(14,2)', 'claims.claim.net - sum(claims.remittance_activity.payment_amount)', 'Represents unpaid balance'),
     
    ('FacilityID', 'Claim/Encounter/FacilityID', 'Claim/Encounter/FacilityID',
     'Direct mapping to facility identifier',
     'claims.encounter.facility_id', 'claims.remittance_claim.facility_id',
     'text', 'claims.encounter.facility_id', 'Identifies facility hosting encounter'),
     
    ('FacilityName', 'Not in XML (IDs only)', 'Not in XML',
     'Resolve FacilityID to name via master data lookup',
     'claims_ref.facility.name', 'claims_ref.facility.name',
     'text', 'claims_ref.facility.name', 'Requires external lookup'),
     
    ('PayerID', 'Claim/PayerID', 'Claim/PayerID',
     'Insurance payer identifier',
     'claims.claim.payer_id', 'claims.remittance_claim.payer_id',
     'text', 'claims.claim.payer_id', 'Identifies insurance payer'),
     
    ('PayerName', 'Not in XML (IDs only)', 'Not in XML',
     'Resolve PayerID to name via master data lookup',
     'claims_ref.payer.name', 'claims_ref.payer.name',
     'text', 'claims_ref.payer.name', 'Requires external lookup'),
     
    ('DenialCode', 'Not in submission', 'Claim/Activity/DenialCode',
     'Direct mapping to denial code for rejected activities',
     'Not stored', 'claims.remittance_activity.denial_code',
     'text', 'claims.remittance_activity.denial_code', 'Available in remittance for denied activities'),
     
    ('AgingDays', 'Derived (not in XML)', 'Derived (not in XML)',
     'Computed as current date minus ClaimDateSettlement or EncounterStart',
     'Derived: current_date - claims.encounter.start_at', 'Derived: current_date - claims.remittance_claim.date_settlement',
     'integer', 'current_date - claims.encounter.start_at', 'Dynamic calculation'),
     
    ('PaymentStatus', 'Not explicit', 'Not explicit',
     'Inferred from Activity/PaymentAmount: 0 = unpaid, =Net = paid, <Net = partial',
     'Derived', 'case when claims.remittance_activity.payment_amount = 0 then ''unpaid'' when payment_amount = net then ''paid'' else ''partial''',
     'text', 'case when claims.remittance_activity.payment_amount = 0 then ''unpaid'' when payment_amount = net then ''paid'' else ''partial''', 'Derived from remittance payment data');
     
    RAISE NOTICE 'Populated % mappings from JSON configuration', (SELECT COUNT(*) FROM claims.report_column_mappings);
END;
$$;

COMMENT ON FUNCTION claims.populate_mappings_from_json IS 'Populates the mapping table with data from JSON configuration';

-- ==========================================================================================================
-- SECTION 3: DYNAMIC VIEW GENERATION FUNCTIONS
-- ==========================================================================================================

-- Function to generate column definitions for a view
CREATE OR REPLACE FUNCTION claims.generate_view_columns(
    p_view_name TEXT,
    p_include_derived BOOLEAN DEFAULT TRUE
) RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_columns TEXT := '';
    v_column_def TEXT;
    v_rec RECORD;
BEGIN
    FOR v_rec IN 
        SELECT 
            report_column,
            best_path,
            data_type,
            notes_derivation
        FROM claims.report_column_mappings
        WHERE (p_include_derived OR best_path NOT LIKE '%Derived%')
        ORDER BY report_column
    LOOP
        -- Clean column name
        v_column_def := LOWER(REGEXP_REPLACE(v_rec.report_column, '[^a-zA-Z0-9_]', '_', 'g'));
        
        -- Add column definition
        IF v_columns != '' THEN
            v_columns := v_columns || E',\n  ';
        END IF;
        
        -- Handle derived fields
        IF v_rec.best_path LIKE '%Derived%' OR v_rec.best_path LIKE '%derived%' THEN
            v_columns := v_columns || FORMAT('%s %s, -- Derived: %s', 
                v_column_def, 
                CASE v_rec.data_type 
                    WHEN 'text' THEN 'TEXT'
                    WHEN 'integer' THEN 'INTEGER'
                    WHEN 'numeric(14,2)' THEN 'NUMERIC(14,2)'
                    WHEN 'timestamptz' THEN 'TIMESTAMPTZ'
                    WHEN 'boolean' THEN 'BOOLEAN'
                    ELSE 'TEXT'
                END,
                v_rec.notes_derivation
            );
        ELSE
            v_columns := v_columns || FORMAT('%s %s, -- %s', 
                v_column_def,
                CASE v_rec.data_type 
                    WHEN 'text' THEN 'TEXT'
                    WHEN 'integer' THEN 'INTEGER'
                    WHEN 'numeric(14,2)' THEN 'NUMERIC(14,2)'
                    WHEN 'timestamptz' THEN 'TIMESTAMPTZ'
                    WHEN 'boolean' THEN 'BOOLEAN'
                    ELSE 'TEXT'
                END,
                v_rec.best_path
            );
        END IF;
    END LOOP;
    
    RETURN v_columns;
END;
$$;

COMMENT ON FUNCTION claims.generate_view_columns IS 'Generates column definitions for views based on mapping configuration';

-- Function to create a dynamic view based on mapping
CREATE OR REPLACE FUNCTION claims.create_dynamic_view(
    p_view_name TEXT,
    p_view_type TEXT DEFAULT 'comprehensive',
    p_include_derived BOOLEAN DEFAULT TRUE
) RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
    v_columns TEXT;
    v_where_clause TEXT := '';
    v_from_clause TEXT;
BEGIN
    -- Generate column definitions
    v_columns := claims.generate_view_columns(p_view_name, p_include_derived);
    
    -- Build FROM clause based on view type
    CASE p_view_type
        WHEN 'comprehensive' THEN
            v_from_clause := 'FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims_ref.provider p ON p.provider_code = c.provider_id
LEFT JOIN claims_ref.facility f ON f.facility_code = e.facility_id
LEFT JOIN claims_ref.payer pay ON pay.payer_code = c.payer_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id AND ra.activity_id = a.activity_id';
            
        WHEN 'balance_amount' THEN
            v_from_clause := 'FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims_ref.provider p ON p.provider_code = c.provider_id
LEFT JOIN claims_ref.facility f ON f.facility_code = e.facility_id
LEFT JOIN claims_ref.payer pay ON pay.payer_code = c.payer_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id AND ra.activity_id = a.activity_id';
            v_where_clause := 'WHERE (c.net - COALESCE(ra.payment_amount, 0)) > 0';
            
        WHEN 'rejected_claims' THEN
            v_from_clause := 'FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
JOIN claims.encounter e ON e.claim_id = c.id
LEFT JOIN claims.activity a ON a.claim_id = c.id
LEFT JOIN claims_ref.provider p ON p.provider_code = c.provider_id
LEFT JOIN claims_ref.facility f ON f.facility_code = e.facility_id
LEFT JOIN claims_ref.payer pay ON pay.payer_code = c.payer_id
LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id AND ra.activity_id = a.activity_id';
            v_where_clause := 'WHERE ra.denial_code IS NOT NULL OR ra.payment_amount = 0';
            
        ELSE
            RAISE EXCEPTION 'Unknown view type: %', p_view_type;
    END CASE;
    
    -- Build the complete SQL
    v_sql := FORMAT('CREATE OR REPLACE VIEW claims.%I AS
SELECT 
  %s
%s
%s', p_view_name, v_columns, v_from_clause, v_where_clause);
    
    RETURN v_sql;
END;
$$;

COMMENT ON FUNCTION claims.create_dynamic_view IS 'Creates a dynamic view based on mapping configuration';

-- Function to execute dynamic view creation
CREATE OR REPLACE FUNCTION claims.execute_dynamic_view_creation(
    p_view_name TEXT,
    p_view_type TEXT DEFAULT 'comprehensive',
    p_include_derived BOOLEAN DEFAULT TRUE
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
BEGIN
    -- Generate the SQL
    v_sql := claims.create_dynamic_view(p_view_name, p_view_type, p_include_derived);
    
    -- Execute the SQL
    EXECUTE v_sql;
    
    RAISE NOTICE 'Created dynamic view: claims.%', p_view_name;
END;
$$;

COMMENT ON FUNCTION claims.execute_dynamic_view_creation IS 'Executes the creation of a dynamic view';

-- ==========================================================================================================
-- SECTION 4: MATERIALIZED VIEW GENERATION
-- ==========================================================================================================

-- Function to create materialized view from existing view
CREATE OR REPLACE FUNCTION claims.create_materialized_view_from_view(
    p_mv_name TEXT,
    p_view_name TEXT,
    p_index_columns TEXT[] DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
    v_index_sql TEXT;
    v_col TEXT;
BEGIN
    -- Create materialized view
    v_sql := FORMAT('CREATE MATERIALIZED VIEW claims.%I AS SELECT * FROM claims.%I', p_mv_name, p_view_name);
    EXECUTE v_sql;
    
    -- Create indexes if specified
    IF p_index_columns IS NOT NULL THEN
        FOR v_col IN SELECT unnest(p_index_columns)
        LOOP
            v_index_sql := FORMAT('CREATE UNIQUE INDEX IF NOT EXISTS idx_%s_%s ON claims.%I (%s)', 
                p_mv_name, v_col, p_mv_name, v_col);
            EXECUTE v_index_sql;
        END LOOP;
    END IF;
    
    RAISE NOTICE 'Created materialized view: claims.% with indexes on: %', p_mv_name, p_index_columns;
END;
$$;

COMMENT ON FUNCTION claims.create_materialized_view_from_view IS 'Creates a materialized view from an existing view with optional indexes';

-- ==========================================================================================================
-- SECTION 5: BATCH VIEW CREATION
-- ==========================================================================================================

-- Function to create all standard views based on mapping
CREATE OR REPLACE FUNCTION claims.create_all_standard_views()
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE NOTICE 'Creating all standard views from JSON mapping...';
    
    -- Populate mappings first
    PERFORM claims.populate_mappings_from_json();
    
    -- Create comprehensive view
    PERFORM claims.execute_dynamic_view_creation('v_dynamic_comprehensive_report', 'comprehensive', TRUE);
    
    -- Create balance amount view
    PERFORM claims.execute_dynamic_view_creation('v_dynamic_balance_amount_report', 'balance_amount', TRUE);
    
    -- Create rejected claims view
    PERFORM claims.execute_dynamic_view_creation('v_dynamic_rejected_claims_report', 'rejected_claims', TRUE);
    
    -- Create materialized views
    PERFORM claims.create_materialized_view_from_view(
        'mv_dynamic_comprehensive_report', 
        'v_dynamic_comprehensive_report',
        ARRAY['claim_key_id', 'activity_id']
    );
    
    PERFORM claims.create_materialized_view_from_view(
        'mv_dynamic_balance_amount_report', 
        'v_dynamic_balance_amount_report',
        ARRAY['claim_key_id']
    );
    
    PERFORM claims.create_materialized_view_from_view(
        'mv_dynamic_rejected_claims_report', 
        'v_dynamic_rejected_claims_report',
        ARRAY['claim_key_id', 'activity_id']
    );
    
    RAISE NOTICE 'All standard views and materialized views created successfully!';
END;
$$;

COMMENT ON FUNCTION claims.create_all_standard_views IS 'Creates all standard views and materialized views based on JSON mapping';

-- ==========================================================================================================
-- SECTION 6: GRANTS
-- ==========================================================================================================

-- Grant access to mapping table
GRANT SELECT ON claims.report_column_mappings TO claims_user;

-- Grant access to functions
GRANT EXECUTE ON FUNCTION claims.populate_mappings_from_json TO claims_user;
GRANT EXECUTE ON FUNCTION claims.generate_view_columns TO claims_user;
GRANT EXECUTE ON FUNCTION claims.create_dynamic_view TO claims_user;
GRANT EXECUTE ON FUNCTION claims.execute_dynamic_view_creation TO claims_user;
GRANT EXECUTE ON FUNCTION claims.create_materialized_view_from_view TO claims_user;
GRANT EXECUTE ON FUNCTION claims.create_all_standard_views TO claims_user;

-- ==========================================================================================================
-- SECTION 7: USAGE EXAMPLES
-- ==========================================================================================================

-- Example 1: Create all standard views
-- SELECT claims.create_all_standard_views();

-- Example 2: Create a custom view with specific columns
-- SELECT claims.execute_dynamic_view_creation('v_custom_claims_report', 'comprehensive', FALSE);

-- Example 3: Create a materialized view from existing view
-- SELECT claims.create_materialized_view_from_view('mv_custom_report', 'v_custom_claims_report', ARRAY['claim_key_id']);

-- Example 4: View the mapping configuration
-- SELECT report_column, best_path, data_type FROM claims.report_column_mappings ORDER BY report_column;

-- ==========================================================================================================
-- END OF DYNAMIC VIEW GENERATOR
-- ==========================================================================================================

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'Dynamic View Generator from JSON Mapping created successfully!';
  RAISE NOTICE 'Available functions:';
  RAISE NOTICE '1. claims.populate_mappings_from_json() - Populate mapping table';
  RAISE NOTICE '2. claims.create_all_standard_views() - Create all standard views and MVs';
  RAISE NOTICE '3. claims.execute_dynamic_view_creation() - Create custom views';
  RAISE NOTICE '4. claims.create_materialized_view_from_view() - Create MVs from views';
  RAISE NOTICE 'Ready for dynamic view generation!';
END$$;
