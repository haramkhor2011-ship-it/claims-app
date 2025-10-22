-- Enhanced verification service implementation
-- This addresses the missing verification checks identified

-- 1. Create enhanced verification function
CREATE OR REPLACE FUNCTION claims.enhanced_verify_file(
    p_ingestion_file_id BIGINT,
    p_expected_claims INTEGER DEFAULT NULL,
    p_expected_activities INTEGER DEFAULT NULL
) RETURNS TABLE(
    check_name TEXT,
    status TEXT,
    message TEXT,
    count_found INTEGER
) LANGUAGE plpgsql AS $$
DECLARE
    v_claim_events INTEGER;
    v_actual_claims INTEGER;
    v_actual_activities INTEGER;
    v_orphan_activities INTEGER;
    v_orphan_cea INTEGER;
    v_orphan_observations INTEGER;
    v_missing_payers INTEGER;
    v_missing_providers INTEGER;
    v_missing_facilities INTEGER;
    v_zero_amount_claims INTEGER;
    v_future_date_claims INTEGER;
    v_constraint_errors INTEGER;
BEGIN
    -- 1. Basic existence checks
    SELECT COUNT(*) INTO v_claim_events
    FROM claims.claim_event 
    WHERE ingestion_file_id = p_ingestion_file_id;
    
    IF v_claim_events = 0 THEN
        RETURN QUERY SELECT 'claim_events_exist'::TEXT, 'FAIL'::TEXT, 'No claim events found'::TEXT, 0;
        RETURN;
    END IF;
    
    RETURN QUERY SELECT 'claim_events_exist'::TEXT, 'PASS'::TEXT, 'Claim events found'::TEXT, v_claim_events;
    
    -- 2. Count verification
    IF p_expected_claims IS NOT NULL AND p_expected_claims > 0 THEN
        SELECT COUNT(DISTINCT claim_key_id) INTO v_actual_claims
        FROM claims.claim_event 
        WHERE ingestion_file_id = p_ingestion_file_id;
        
        IF v_actual_claims < p_expected_claims THEN
            RETURN QUERY SELECT 'claim_count'::TEXT, 'FAIL'::TEXT, 
                'Incomplete claim persistence'::TEXT, v_actual_claims;
        ELSE
            RETURN QUERY SELECT 'claim_count'::TEXT, 'PASS'::TEXT, 
                'All claims persisted'::TEXT, v_actual_claims;
        END IF;
    END IF;
    
    -- 3. Activity count verification
    IF p_expected_activities IS NOT NULL AND p_expected_activities > 0 THEN
        SELECT COUNT(*) INTO v_actual_activities
        FROM claims.activity a 
        JOIN claims.claim c ON a.claim_id = c.id
        JOIN claims.claim_event ce ON c.claim_key_id = ce.claim_key_id
        WHERE ce.ingestion_file_id = p_ingestion_file_id;
        
        IF v_actual_activities < p_expected_activities THEN
            RETURN QUERY SELECT 'activity_count'::TEXT, 'FAIL'::TEXT, 
                'Incomplete activity persistence'::TEXT, v_actual_activities;
        ELSE
            RETURN QUERY SELECT 'activity_count'::TEXT, 'PASS'::TEXT, 
                'All activities persisted'::TEXT, v_actual_activities;
        END IF;
    END IF;
    
    -- 4. Orphan detection
    SELECT COUNT(*) INTO v_orphan_activities
    FROM claims.activity a
    LEFT JOIN claims.claim c ON c.id = a.claim_id
    WHERE c.id IS NULL;
    
    IF v_orphan_activities > 0 THEN
        RETURN QUERY SELECT 'orphan_activities'::TEXT, 'FAIL'::TEXT, 
            'Orphan activities found'::TEXT, v_orphan_activities;
    ELSE
        RETURN QUERY SELECT 'orphan_activities'::TEXT, 'PASS'::TEXT, 
            'No orphan activities'::TEXT, 0;
    END IF;
    
    -- 5. Reference data integrity
    SELECT COUNT(*) INTO v_missing_payers
    FROM claims.claim c 
    LEFT JOIN claims_ref.payer p ON c.payer_id = p.payer_code
    WHERE p.id IS NULL AND c.payer_id IS NOT NULL;
    
    IF v_missing_payers > 0 THEN
        RETURN QUERY SELECT 'missing_payers'::TEXT, 'WARN'::TEXT, 
            'Missing payer reference data'::TEXT, v_missing_payers;
    ELSE
        RETURN QUERY SELECT 'missing_payers'::TEXT, 'PASS'::TEXT, 
            'All payers have reference data'::TEXT, 0;
    END IF;
    
    -- 6. Data quality checks
    SELECT COUNT(*) INTO v_zero_amount_claims
    FROM claims.claim 
    WHERE gross = 0 AND patient_share = 0 AND net = 0;
    
    IF v_zero_amount_claims > 0 THEN
        RETURN QUERY SELECT 'zero_amount_claims'::TEXT, 'WARN'::TEXT, 
            'Claims with zero amounts'::TEXT, v_zero_amount_claims;
    ELSE
        RETURN QUERY SELECT 'zero_amount_claims'::TEXT, 'PASS'::TEXT, 
            'No zero amount claims'::TEXT, 0;
    END IF;
    
    -- 7. Constraint error detection
    SELECT COUNT(*) INTO v_constraint_errors
    FROM claims.ingestion_error ie
    WHERE ie.ingestion_file_id = p_ingestion_file_id
      AND (ie.error_message LIKE '%constraint%' 
           OR ie.error_message LIKE '%transaction%'
           OR ie.error_message LIKE '%duplicate%');
    
    IF v_constraint_errors > 0 THEN
        RETURN QUERY SELECT 'constraint_errors'::TEXT, 'FAIL'::TEXT, 
            'Constraint errors detected'::TEXT, v_constraint_errors;
    ELSE
        RETURN QUERY SELECT 'constraint_errors'::TEXT, 'PASS'::TEXT, 
            'No constraint errors'::TEXT, 0;
    END IF;
    
END;
$$;

-- 2. Test the enhanced verification
SELECT * FROM claims.enhanced_verify_file(9991, 1, 488);

-- 3. Create verification summary view
CREATE OR REPLACE VIEW claims.v_file_verification_summary AS
SELECT 
    ifa.ingestion_file_id,
    ifa.file_name,
    ifa.parsed_claims,
    ifa.persisted_claims,
    ifa.parsed_activities,
    ifa.persisted_activities,
    CASE 
        WHEN ifa.persisted_claims = ifa.parsed_claims AND ifa.persisted_activities = ifa.parsed_activities 
        THEN 'COMPLETE'
        WHEN ifa.persisted_claims = 0 AND ifa.persisted_activities = 0 
        THEN 'FAILED'
        ELSE 'PARTIAL'
    END as persistence_status,
    COUNT(ie.id) as error_count
FROM claims.ingestion_file_audit ifa
LEFT JOIN claims.ingestion_error ie ON ifa.ingestion_file_id = ie.ingestion_file_id
GROUP BY ifa.ingestion_file_id, ifa.file_name, ifa.parsed_claims, ifa.persisted_claims, 
         ifa.parsed_activities, ifa.persisted_activities
ORDER BY ifa.ingestion_file_id DESC;
