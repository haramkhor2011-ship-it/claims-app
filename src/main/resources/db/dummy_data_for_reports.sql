-- ==========================================================================================================
-- DUMMY DATA FOR REPORTS TESTING
-- ==========================================================================================================
-- 
-- Date: 2025-09-24
-- Purpose: Populate database with realistic dummy data for testing all reports
-- 
-- This script creates comprehensive test data including:
-- - Reference data (facilities, payers, clinicians, denial codes)
-- - Claims data (submissions and remittances)
-- - Various rejection scenarios for testing
-- - Different time periods and amounts
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: CLEANUP EXISTING DATA (OPTIONAL)
-- ==========================================================================================================

-- Uncomment these lines if you want to clean existing data first
-- TRUNCATE TABLE claims.remittance_activity CASCADE;
-- TRUNCATE TABLE claims.remittance_claim CASCADE;
-- TRUNCATE TABLE claims.remittance CASCADE;
-- TRUNCATE TABLE claims.activity CASCADE;
-- TRUNCATE TABLE claims.diagnosis CASCADE;
-- TRUNCATE TABLE claims.encounter CASCADE;
-- TRUNCATE TABLE claims.claim CASCADE;
-- TRUNCATE TABLE claims.submission CASCADE;
-- TRUNCATE TABLE claims.claim_key CASCADE;
-- TRUNCATE TABLE claims.ingestion_file CASCADE;

-- ==========================================================================================================
-- SECTION 2: REFERENCE DATA POPULATION
-- ==========================================================================================================

-- Insert facilities
INSERT INTO claims_ref.facility (facility_code, name, city, country, status) VALUES
('FAC-001', 'Dubai London Clinic & Speciality Hospital L.L.C.', 'Dubai', 'UAE', 'ACTIVE'),
('FAC-002', 'City Hospital Dubai', 'Dubai', 'UAE', 'ACTIVE'),
('FAC-003', 'Medicare Hospital', 'Abu Dhabi', 'UAE', 'ACTIVE'),
('FAC-004', 'Al Zahra Hospital', 'Sharjah', 'UAE', 'ACTIVE'),
('FAC-005', 'American Hospital Dubai', 'Dubai', 'UAE', 'ACTIVE')
ON CONFLICT (facility_code) DO UPDATE SET 
    name = EXCLUDED.name,
    city = EXCLUDED.city,
    country = EXCLUDED.country,
    status = EXCLUDED.status;

-- Insert payers
INSERT INTO claims_ref.payer (payer_code, name, status) VALUES
('PAY-001', 'DHA Health Insurance', 'ACTIVE'),
('PAY-002', 'ADNIC Insurance', 'ACTIVE'),
('PAY-003', 'Oman Insurance Company', 'ACTIVE'),
('PAY-004', 'AXA Insurance', 'ACTIVE'),
('PAY-005', 'MetLife Insurance', 'ACTIVE'),
('PAY-006', 'Self-Paid', 'ACTIVE')
ON CONFLICT (payer_code) DO UPDATE SET 
    name = EXCLUDED.name,
    status = EXCLUDED.status;

-- Insert providers
INSERT INTO claims_ref.provider (provider_code, name, status) VALUES
('PROV-001', 'Dubai London Clinic Group', 'ACTIVE'),
('PROV-002', 'City Hospital Group', 'ACTIVE'),
('PROV-003', 'Medicare Healthcare Group', 'ACTIVE'),
('PROV-004', 'Al Zahra Healthcare', 'ACTIVE'),
('PROV-005', 'American Hospital Group', 'ACTIVE')
ON CONFLICT (provider_code) DO UPDATE SET 
    name = EXCLUDED.name,
    status = EXCLUDED.status;

-- Insert clinicians
INSERT INTO claims_ref.clinician (clinician_code, name, specialty, status) VALUES
('CLIN-001', 'Dr. Ahmed Al-Rashid', 'Cardiology', 'ACTIVE'),
('CLIN-002', 'Dr. Sarah Johnson', 'Orthopedics', 'ACTIVE'),
('CLIN-003', 'Dr. Mohammed Hassan', 'Internal Medicine', 'ACTIVE'),
('CLIN-004', 'Dr. Emily Chen', 'Pediatrics', 'ACTIVE'),
('CLIN-005', 'Dr. Omar Al-Zahra', 'Surgery', 'ACTIVE'),
('CLIN-006', 'Dr. Lisa Thompson', 'Dermatology', 'ACTIVE'),
('CLIN-007', 'Dr. Khalid Al-Mansouri', 'Neurology', 'ACTIVE'),
('CLIN-008', 'Dr. Jennifer Wilson', 'Gynecology', 'ACTIVE')
ON CONFLICT (clinician_code) DO UPDATE SET 
    name = EXCLUDED.name,
    specialty = EXCLUDED.specialty,
    status = EXCLUDED.status;

-- Insert denial codes
INSERT INTO claims_ref.denial_code (code, description, payer_code) VALUES
('MNEC-001', 'Service not covered under policy', 'PAY-001'),
('MNEC-002', 'Prior authorization required', 'PAY-001'),
('MNEC-003', 'Not clinically indicated', 'PAY-001'),
('MNEC-004', 'Duplicate claim', 'PAY-001'),
('MNEC-005', 'Invalid diagnosis code', 'PAY-001'),
('MNEC-006', 'Service date outside coverage period', 'PAY-002'),
('MNEC-007', 'Provider not in network', 'PAY-002'),
('MNEC-008', 'Exceeded benefit limit', 'PAY-002'),
('MNEC-009', 'Missing required documentation', 'PAY-003'),
('MNEC-010', 'Incorrect billing code', 'PAY-003')
ON CONFLICT (code) DO UPDATE SET 
    description = EXCLUDED.description,
    payer_code = EXCLUDED.payer_code;

-- Insert activity codes
INSERT INTO claims_ref.activity_code (code, code_system, description, status) VALUES
('99213', 'CPT', 'Office visit, established patient', 'ACTIVE'),
('99214', 'CPT', 'Office visit, established patient, detailed', 'ACTIVE'),
('99215', 'CPT', 'Office visit, established patient, comprehensive', 'ACTIVE'),
('99281', 'CPT', 'Emergency department visit', 'ACTIVE'),
('99282', 'CPT', 'Emergency department visit, expanded', 'ACTIVE'),
('99283', 'CPT', 'Emergency department visit, detailed', 'ACTIVE'),
('99284', 'CPT', 'Emergency department visit, comprehensive', 'ACTIVE'),
('99285', 'CPT', 'Emergency department visit, critical care', 'ACTIVE'),
('99291', 'CPT', 'Critical care, first 30-74 minutes', 'ACTIVE'),
('99292', 'CPT', 'Critical care, each additional 30 minutes', 'ACTIVE'),
('93000', 'CPT', 'Electrocardiogram, routine ECG', 'ACTIVE'),
('93010', 'CPT', 'Electrocardiogram, interpretation and report', 'ACTIVE'),
('93015', 'CPT', 'Cardiovascular stress test', 'ACTIVE'),
('93017', 'CPT', 'Cardiovascular stress test, with interpretation', 'ACTIVE'),
('93018', 'CPT', 'Cardiovascular stress test, with supervision', 'ACTIVE')
ON CONFLICT (code, code_system) DO UPDATE SET 
    description = EXCLUDED.description,
    status = EXCLUDED.status;

-- Insert diagnosis codes
INSERT INTO claims_ref.diagnosis_code (code, code_system, description, status) VALUES
('I10', 'ICD-10', 'Essential hypertension', 'ACTIVE'),
('I25.10', 'ICD-10', 'Atherosclerotic heart disease', 'ACTIVE'),
('E11.9', 'ICD-10', 'Type 2 diabetes mellitus without complications', 'ACTIVE'),
('M79.3', 'ICD-10', 'Panniculitis, unspecified', 'ACTIVE'),
('Z00.00', 'ICD-10', 'Encounter for general adult medical examination', 'ACTIVE'),
('Z51.11', 'ICD-10', 'Encounter for antineoplastic chemotherapy', 'ACTIVE'),
('F32.9', 'ICD-10', 'Major depressive disorder, single episode, unspecified', 'ACTIVE'),
('G43.909', 'ICD-10', 'Migraine, unspecified, not intractable', 'ACTIVE'),
('K21.9', 'ICD-10', 'Gastro-esophageal reflux disease without esophagitis', 'ACTIVE'),
('M25.561', 'ICD-10', 'Pain in right knee', 'ACTIVE')
ON CONFLICT (code, code_system) DO UPDATE SET 
    description = EXCLUDED.description,
    status = EXCLUDED.status;

-- ==========================================================================================================
-- SECTION 3: INGESTION FILES CREATION
-- ==========================================================================================================

-- Create ingestion files for submissions
INSERT INTO claims.ingestion_file (file_id, file_name, root_type, sender_id, receiver_id, transaction_date, record_count_declared, disposition_flag, xml_bytes) VALUES
('SUB-2024-001', 'submission_2024_001.xml', 1, 'FAC-001', 'DHA', '2024-01-15 10:30:00+00', 5, 'SUCCESS', '\x3c786d6c3e3c636c61696d3e3c2f636c61696d3e3c2f786d6c3e'),
('SUB-2024-002', 'submission_2024_002.xml', 1, 'FAC-002', 'DHA', '2024-02-20 14:15:00+00', 8, 'SUCCESS', '\x3c786d6c3e3c636c61696d3e3c2f636c61696d3e3c2f786d6c3e'),
('SUB-2024-003', 'submission_2024_003.xml', 1, 'FAC-003', 'DHA', '2024-03-10 09:45:00+00', 12, 'SUCCESS', '\x3c786d6c3e3c636c61696d3e3c2f636c61696d3e3c2f786d6c3e'),
('SUB-2024-004', 'submission_2024_004.xml', 1, 'FAC-004', 'DHA', '2024-04-05 16:20:00+00', 6, 'SUCCESS', '\x3c786d6c3e3c636c61696d3e3c2f636c61696d3e3c2f786d6c3e'),
('SUB-2024-005', 'submission_2024_005.xml', 1, 'FAC-005', 'DHA', '2024-05-12 11:30:00+00', 10, 'SUCCESS', '\x3c786d6c3e3c636c61696d3e3c2f636c61696d3e3c2f786d6c3e'),
('SUB-2024-006', 'submission_2024_006.xml', 1, 'FAC-001', 'DHA', '2024-06-18 13:45:00+00', 7, 'SUCCESS', '\x3c786d6c3e3c636c61696d3e3c2f636c61696d3e3c2f786d6c3e'),
('SUB-2024-007', 'submission_2024_007.xml', 1, 'FAC-002', 'DHA', '2024-07-22 08:15:00+00', 9, 'SUCCESS', '\x3c786d6c3e3c636c61696d3e3c2f636c61696d3e3c2f786d6c3e'),
('SUB-2024-008', 'submission_2024_008.xml', 1, 'FAC-003', 'DHA', '2024-08-30 15:30:00+00', 11, 'SUCCESS', '\x3c786d6c3e3c636c61696d3e3c2f636c61696d3e3c2f786d6c3e'),
('SUB-2024-009', 'submission_2024_009.xml', 1, 'FAC-004', 'DHA', '2024-09-14 12:00:00+00', 4, 'SUCCESS', '\x3c786d6c3e3c636c61696d3e3c2f636c61696d3e3c2f786d6c3e'),
('SUB-2024-010', 'submission_2024_010.xml', 1, 'FAC-005', 'DHA', '2024-10-25 17:45:00+00', 13, 'SUCCESS', '\x3c786d6c3e3c636c61696d3e3c2f636c61696d3e3c2f786d6c3e')
ON CONFLICT (file_id) DO NOTHING;

-- Create ingestion files for remittances
INSERT INTO claims.ingestion_file (file_id, file_name, root_type, sender_id, receiver_id, transaction_date, record_count_declared, disposition_flag, xml_bytes) VALUES
('REM-2024-001', 'remittance_2024_001.xml', 2, 'DHA', 'FAC-001', '2024-01-20 10:30:00+00', 5, 'SUCCESS', '\x3c786d6c3e3c72656d697474616e63653e3c2f72656d697474616e63653e3c2f786d6c3e'),
('REM-2024-002', 'remittance_2024_002.xml', 2, 'DHA', 'FAC-002', '2024-02-25 14:15:00+00', 8, 'SUCCESS', '\x3c786d6c3e3c72656d697474616e63653e3c2f72656d697474616e63653e3c2f786d6c3e'),
('REM-2024-003', 'remittance_2024_003.xml', 2, 'DHA', 'FAC-003', '2024-03-15 09:45:00+00', 12, 'SUCCESS', '\x3c786d6c3e3c72656d697474616e63653e3c2f72656d697474616e63653e3c2f786d6c3e'),
('REM-2024-004', 'remittance_2024_004.xml', 2, 'DHA', 'FAC-004', '2024-04-10 16:20:00+00', 6, 'SUCCESS', '\x3c786d6c3e3c72656d697474616e63653e3c2f72656d697474616e63653e3c2f786d6c3e'),
('REM-2024-005', 'remittance_2024_005.xml', 2, 'DHA', 'FAC-005', '2024-05-17 11:30:00+00', 10, 'SUCCESS', '\x3c786d6c3e3c72656d697474616e63653e3c2f72656d697474616e63653e3c2f786d6c3e'),
('REM-2024-006', 'remittance_2024_006.xml', 2, 'DHA', 'FAC-001', '2024-06-23 13:45:00+00', 7, 'SUCCESS', '\x3c786d6c3e3c72656d697474616e63653e3c2f72656d697474616e63653e3c2f786d6c3e'),
('REM-2024-007', 'remittance_2024_007.xml', 2, 'DHA', 'FAC-002', '2024-07-27 08:15:00+00', 9, 'SUCCESS', '\x3c786d6c3e3c72656d697474616e63653e3c2f72656d697474616e63653e3c2f786d6c3e'),
('REM-2024-008', 'remittance_2024_008.xml', 2, 'DHA', 'FAC-003', '2024-08-05 15:30:00+00', 11, 'SUCCESS', '\x3c786d6c3e3c72656d697474616e63653e3c2f72656d697474616e63653e3c2f786d6c3e'),
('REM-2024-009', 'remittance_2024_009.xml', 2, 'DHA', 'FAC-004', '2024-09-19 12:00:00+00', 4, 'SUCCESS', '\x3c786d6c3e3c72656d697474616e63653e3c2f72656d697474616e63653e3c2f786d6c3e'),
('REM-2024-010', 'remittance_2024_010.xml', 2, 'DHA', 'FAC-005', '2024-10-30 17:45:00+00', 13, 'SUCCESS', '\x3c786d6c3e3c72656d697474616e63653e3c2f72656d697474616e63653e3c2f786d6c3e')
ON CONFLICT (file_id) DO NOTHING;

-- ==========================================================================================================
-- SECTION 4: SUBMISSIONS CREATION
-- ==========================================================================================================

-- Create submissions
INSERT INTO claims.submission (ingestion_file_id, tx_at) VALUES
((SELECT id FROM claims.ingestion_file WHERE file_id = 'SUB-2024-001'), '2024-01-15 10:30:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'SUB-2024-002'), '2024-02-20 14:15:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'SUB-2024-003'), '2024-03-10 09:45:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'SUB-2024-004'), '2024-04-05 16:20:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'SUB-2024-005'), '2024-05-12 11:30:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'SUB-2024-006'), '2024-06-18 13:45:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'SUB-2024-007'), '2024-07-22 08:15:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'SUB-2024-008'), '2024-08-30 15:30:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'SUB-2024-009'), '2024-09-14 12:00:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'SUB-2024-010'), '2024-10-25 17:45:00+00')
ON CONFLICT DO NOTHING;

-- ==========================================================================================================
-- SECTION 5: REMITTANCES CREATION
-- ==========================================================================================================

-- Create remittances
INSERT INTO claims.remittance (ingestion_file_id, tx_at) VALUES
((SELECT id FROM claims.ingestion_file WHERE file_id = 'REM-2024-001'), '2024-01-20 10:30:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'REM-2024-002'), '2024-02-25 14:15:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'REM-2024-003'), '2024-03-15 09:45:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'REM-2024-004'), '2024-04-10 16:20:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'REM-2024-005'), '2024-05-17 11:30:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'REM-2024-006'), '2024-06-23 13:45:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'REM-2024-007'), '2024-07-27 08:15:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'REM-2024-008'), '2024-08-05 15:30:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'REM-2024-009'), '2024-09-19 12:00:00+00'),
((SELECT id FROM claims.ingestion_file WHERE file_id = 'REM-2024-010'), '2024-10-30 17:45:00+00')
ON CONFLICT DO NOTHING;

-- ==========================================================================================================
-- SECTION 6: CLAIM KEYS AND CLAIMS CREATION
-- ==========================================================================================================

-- Create claim keys and claims with various scenarios
DO $$
DECLARE
    claim_key_id_val BIGINT;
    claim_id_val BIGINT;
    submission_id_val BIGINT;
    encounter_id_val BIGINT;
    activity_id_val BIGINT;
    remittance_id_val BIGINT;
    remittance_claim_id_val BIGINT;
    remittance_activity_id_val BIGINT;
    i INTEGER;
    claim_amount NUMERIC;
    payment_amount NUMERIC;
    denial_code_val TEXT;
    rejection_scenario INTEGER;
BEGIN
    -- Loop through creating 50 claims with various scenarios
    FOR i IN 1..50 LOOP
        -- Create claim key
        INSERT INTO claims.claim_key (claim_id) VALUES ('CLM-' || LPAD(i::TEXT, 6, '0'))
        RETURNING id INTO claim_key_id_val;
        
        -- Get submission ID (cycle through submissions)
        SELECT id INTO submission_id_val FROM claims.submission 
        ORDER BY id LIMIT 1 OFFSET ((i-1) % 10);
        
        -- Create claim
        claim_amount := 1000 + (RANDOM() * 5000); -- Random amount between 1000-6000
        INSERT INTO claims.claim (
            claim_key_id, submission_id, id_payer, member_id, payer_id, provider_id, 
            emirates_id_number, gross, patient_share, net, comments, tx_at
        ) VALUES (
            claim_key_id_val, submission_id_val, 'PAY-' || LPAD((i % 5 + 1)::TEXT, 3, '0'),
            'MEM-' || LPAD(i::TEXT, 6, '0'), 'PAY-' || LPAD((i % 5 + 1)::TEXT, 3, '0'),
            'PROV-' || LPAD((i % 5 + 1)::TEXT, 3, '0'), '784-' || LPAD(i::TEXT, 7, '0') || '-' || LPAD((i % 9 + 1)::TEXT, 1, '0'),
            claim_amount, claim_amount * 0.1, claim_amount * 0.9,
            CASE WHEN i % 10 = 0 THEN 'Special case claim' ELSE NULL END,
            ('2024-' || LPAD((i % 12 + 1)::TEXT, 2, '0') || '-' || LPAD((i % 28 + 1)::TEXT, 2, '0') || ' 10:30:00+00')::timestamp with time zone
        ) RETURNING id INTO claim_id_val;
        
        -- Create encounter
        INSERT INTO claims.encounter (
            claim_id, facility_id, type, patient_id, start_at, end_at, start_type, end_type
        ) VALUES (
            claim_id_val, 'FAC-' || LPAD((i % 5 + 1)::TEXT, 3, '0'), 'OUTPATIENT',
            'PAT-' || LPAD(i::TEXT, 6, '0'),
            ('2024-' || LPAD((i % 12 + 1)::TEXT, 2, '0') || '-' || LPAD((i % 28 + 1)::TEXT, 2, '0') || ' 09:00:00+00')::timestamp with time zone,
            ('2024-' || LPAD((i % 12 + 1)::TEXT, 2, '0') || '-' || LPAD((i % 28 + 1)::TEXT, 2, '0') || ' 11:00:00+00')::timestamp with time zone,
            'ARRIVAL', 'DEPARTURE'
        ) RETURNING id INTO encounter_id_val;
        
        -- Create diagnosis
        INSERT INTO claims.diagnosis (claim_id, diag_type, code) VALUES
        (claim_id_val, 'PRINCIPAL', 'I10'),
        (claim_id_val, 'SECONDARY', 'E11.9');
        
        -- Create activity
        INSERT INTO claims.activity (
            claim_id, activity_id, start_at, type, code, quantity, net, clinician, prior_authorization_id
        ) VALUES (
            claim_id_val, 'ACT-' || LPAD(i::TEXT, 6, '0'),
            ('2024-' || LPAD((i % 12 + 1)::TEXT, 2, '0') || '-' || LPAD((i % 28 + 1)::TEXT, 2, '0') || ' 09:30:00+00')::timestamp with time zone,
            'PROCEDURE', '99213', 1, claim_amount, 'CLIN-' || LPAD((i % 8 + 1)::TEXT, 3, '0'),
            CASE WHEN i % 5 = 0 THEN 'AUTH-' || LPAD(i::TEXT, 6, '0') ELSE NULL END
        ) RETURNING id INTO activity_id_val;
        
        -- Create remittance (for 80% of claims)
        IF i % 5 != 0 THEN
            -- Get remittance ID (cycle through remittances)
            SELECT id INTO remittance_id_val FROM claims.remittance 
            ORDER BY id LIMIT 1 OFFSET ((i-1) % 10);
            
            -- Determine rejection scenario
            rejection_scenario := i % 4;
            
            -- Create remittance claim
            INSERT INTO claims.remittance_claim (
                remittance_id, claim_key_id, id_payer, provider_id, denial_code, 
                payment_reference, date_settlement, facility_id
            ) VALUES (
                remittance_id_val, claim_key_id_val, 'PAY-' || LPAD((i % 5 + 1)::TEXT, 3, '0'),
                'PROV-' || LPAD((i % 5 + 1)::TEXT, 3, '0'),
                CASE 
                    WHEN rejection_scenario = 0 THEN NULL  -- Fully paid
                    WHEN rejection_scenario = 1 THEN 'MNEC-003'  -- Not clinically indicated
                    WHEN rejection_scenario = 2 THEN 'MNEC-002'  -- Prior authorization required
                    ELSE 'MNEC-001'  -- Service not covered
                END,
                'PAY-REF-' || LPAD(i::TEXT, 6, '0'),
                ('2024-' || LPAD((i % 12 + 1)::TEXT, 2, '0') || '-' || LPAD((i % 28 + 1)::TEXT, 2, '0') || ' 14:00:00+00')::timestamp with time zone,
                'FAC-' || LPAD((i % 5 + 1)::TEXT, 3, '0')
            ) RETURNING id INTO remittance_claim_id_val;
            
            -- Create remittance activity with different payment scenarios
            CASE rejection_scenario
                WHEN 0 THEN  -- Fully paid
                    payment_amount := claim_amount;
                    denial_code_val := NULL;
                WHEN 1 THEN  -- Fully rejected
                    payment_amount := 0;
                    denial_code_val := 'MNEC-003';
                WHEN 2 THEN  -- Partially rejected
                    payment_amount := claim_amount * 0.6;
                    denial_code_val := 'MNEC-002';
                ELSE  -- Partially rejected with different denial
                    payment_amount := claim_amount * 0.8;
                    denial_code_val := 'MNEC-001';
            END CASE;
            
            INSERT INTO claims.remittance_activity (
                remittance_claim_id, activity_id, start_at, type, code, quantity, net, 
                list_price, clinician, prior_authorization_id, gross, patient_share, 
                payment_amount, denial_code
            ) VALUES (
                remittance_claim_id_val, 'ACT-' || LPAD(i::TEXT, 6, '0'),
                ('2024-' || LPAD((i % 12 + 1)::TEXT, 2, '0') || '-' || LPAD((i % 28 + 1)::TEXT, 2, '0') || ' 09:30:00+00')::timestamp with time zone,
                'PROCEDURE', '99213', 1, claim_amount, claim_amount * 1.2,
                'CLIN-' || LPAD((i % 8 + 1)::TEXT, 3, '0'),
                CASE WHEN i % 5 = 0 THEN 'AUTH-' || LPAD(i::TEXT, 6, '0') ELSE NULL END,
                claim_amount, claim_amount * 0.1, payment_amount, denial_code_val
            ) RETURNING id INTO remittance_activity_id_val;
        END IF;
        
        -- Create claim events
        INSERT INTO claims.claim_event (claim_key_id, ingestion_file_id, event_time, type, submission_id) VALUES
        (claim_key_id_val, (SELECT id FROM claims.ingestion_file WHERE file_id = 'SUB-2024-' || LPAD(((i-1) % 10 + 1)::TEXT, 3, '0')), 
         ('2024-' || LPAD((i % 12 + 1)::TEXT, 2, '0') || '-' || LPAD((i % 28 + 1)::TEXT, 2, '0') || ' 10:30:00+00')::timestamp with time zone, 1, submission_id_val);
        
        IF i % 5 != 0 THEN
            INSERT INTO claims.claim_event (claim_key_id, ingestion_file_id, event_time, type, remittance_id) VALUES
            (claim_key_id_val, (SELECT id FROM claims.ingestion_file WHERE file_id = 'REM-2024-' || LPAD(((i-1) % 10 + 1)::TEXT, 3, '0')), 
             ('2024-' || LPAD((i % 12 + 1)::TEXT, 2, '0') || '-' || LPAD((i % 28 + 1)::TEXT, 2, '0') || ' 14:00:00+00')::timestamp with time zone, 3, remittance_id_val);
        END IF;
        
        -- Create claim status timeline
        INSERT INTO claims.claim_status_timeline (claim_key_id, status, status_time, claim_event_id) VALUES
        (claim_key_id_val, 1, ('2024-' || LPAD((i % 12 + 1)::TEXT, 2, '0') || '-' || LPAD((i % 28 + 1)::TEXT, 2, '0') || ' 10:30:00+00')::timestamp with time zone, 
         (SELECT id FROM claims.claim_event WHERE claim_key_id = claim_key_id_val AND type = 1));
        
        IF i % 5 != 0 THEN
            INSERT INTO claims.claim_status_timeline (claim_key_id, status, status_time, claim_event_id) VALUES
            (claim_key_id_val, 3, ('2024-' || LPAD((i % 12 + 1)::TEXT, 2, '0') || '-' || LPAD((i % 28 + 1)::TEXT, 2, '0') || ' 14:00:00+00')::timestamp with time zone, 
             (SELECT id FROM claims.claim_event WHERE claim_key_id = claim_key_id_val AND type = 3));
        END IF;
        
        -- Create resubmissions for some claims (20% of rejected claims)
        IF i % 5 != 0 AND rejection_scenario IN (1, 2) AND i % 10 = 0 THEN
            INSERT INTO claims.claim_event (claim_key_id, event_time, type, submission_id) VALUES
            (claim_key_id_val, ('2024-' || LPAD((i % 12 + 1)::TEXT, 2, '0') || '-' || LPAD((i % 28 + 1)::TEXT, 2, '0') || ' 16:00:00+00')::timestamp with time zone, 2, submission_id_val);
            
            INSERT INTO claims.claim_resubmission (claim_event_id, resubmission_type, comment) VALUES
            ((SELECT id FROM claims.claim_event WHERE claim_key_id = claim_key_id_val AND type = 2), 'correction', 'Resubmitted with additional documentation');
        END IF;
    END LOOP;
END $$;

-- ==========================================================================================================
-- SECTION 7: ADDITIONAL TEST DATA FOR SPECIFIC SCENARIOS
-- ==========================================================================================================

-- Create some claims with specific rejection patterns for testing
DO $$
DECLARE
    claim_key_id_val BIGINT;
    claim_id_val BIGINT;
    submission_id_val BIGINT;
    encounter_id_val BIGINT;
    remittance_id_val BIGINT;
    remittance_claim_id_val BIGINT;
    i INTEGER;
BEGIN
    -- Create 10 additional claims with specific patterns
    FOR i IN 51..60 LOOP
        -- Create claim key
        INSERT INTO claims.claim_key (claim_id) VALUES ('CLM-' || LPAD(i::TEXT, 6, '0'))
        RETURNING id INTO claim_key_id_val;
        
        -- Get submission ID
        SELECT id INTO submission_id_val FROM claims.submission ORDER BY id LIMIT 1;
        
        -- Create claim with specific amounts for testing
        INSERT INTO claims.claim (
            claim_key_id, submission_id, id_payer, member_id, payer_id, provider_id, 
            emirates_id_number, gross, patient_share, net, tx_at
        ) VALUES (
            claim_key_id_val, submission_id_val, 'PAY-001', 'MEM-' || LPAD(i::TEXT, 6, '0'), 'PAY-001',
            'PROV-001', '784-' || LPAD(i::TEXT, 7, '0') || '-1',
            CASE 
                WHEN i <= 55 THEN 5000.00  -- High value claims
                ELSE 500.00                -- Low value claims
            END,
            CASE 
                WHEN i <= 55 THEN 500.00
                ELSE 50.00
            END,
            CASE 
                WHEN i <= 55 THEN 4500.00
                ELSE 450.00
            END,
            '2024-11-01 10:30:00+00'::timestamp with time zone
        ) RETURNING id INTO claim_id_val;
        
        -- Create encounter
        INSERT INTO claims.encounter (
            claim_id, facility_id, type, patient_id, start_at, end_at
        ) VALUES (
            claim_id_val, 'FAC-001', 'OUTPATIENT', 'PAT-' || LPAD(i::TEXT, 6, '0'),
            '2024-11-01 09:00:00+00'::timestamp with time zone, '2024-11-01 11:00:00+00'::timestamp with time zone
        ) RETURNING id INTO encounter_id_val;
        
        -- Create diagnosis
        INSERT INTO claims.diagnosis (claim_id, diag_type, code) VALUES
        (claim_id_val, 'PRINCIPAL', 'I10');
        
        -- Create activity
        INSERT INTO claims.activity (
            claim_id, activity_id, start_at, type, code, quantity, net, clinician
        ) VALUES (
            claim_id_val, 'ACT-' || LPAD(i::TEXT, 6, '0'),
            '2024-11-01 09:30:00+00'::timestamp with time zone, 'PROCEDURE', '99214', 1,
            CASE 
                WHEN i <= 55 THEN 4500.00
                ELSE 450.00
            END, 'CLIN-001'
        );
        
        -- Create remittance with specific rejection patterns
        SELECT id INTO remittance_id_val FROM claims.remittance ORDER BY id LIMIT 1;
        
        INSERT INTO claims.remittance_claim (
            remittance_id, claim_key_id, id_payer, provider_id, denial_code, 
            payment_reference, date_settlement, facility_id
        ) VALUES (
            remittance_id_val, claim_key_id_val, 'PAY-001', 'PROV-001',
            CASE 
                WHEN i <= 52 THEN NULL  -- Fully paid
                WHEN i <= 54 THEN 'MNEC-003'  -- Not clinically indicated
                WHEN i <= 56 THEN 'MNEC-002'  -- Prior authorization required
                ELSE 'MNEC-001'  -- Service not covered
            END,
            'PAY-REF-' || LPAD(i::TEXT, 6, '0'), '2024-11-05 14:00:00+00'::timestamp with time zone, 'FAC-001'
        ) RETURNING id INTO remittance_claim_id_val;
        
        -- Create remittance activity
        INSERT INTO claims.remittance_activity (
            remittance_claim_id, activity_id, start_at, type, code, quantity, net, 
            list_price, clinician, gross, patient_share, payment_amount, denial_code
        ) VALUES (
            remittance_claim_id_val, 'ACT-' || LPAD(i::TEXT, 6, '0'),
            '2024-11-01 09:30:00+00'::timestamp with time zone, 'PROCEDURE', '99214', 1,
            CASE 
                WHEN i <= 55 THEN 4500.00
                ELSE 450.00
            END,
            CASE 
                WHEN i <= 55 THEN 5400.00
                ELSE 540.00
            END, 'CLIN-001',
            CASE 
                WHEN i <= 55 THEN 5000.00
                ELSE 500.00
            END,
            CASE 
                WHEN i <= 55 THEN 500.00
                ELSE 50.00
            END,
            CASE 
                WHEN i <= 52 THEN 
                    CASE 
                        WHEN i <= 55 THEN 4500.00  -- Fully paid
                        ELSE 450.00
                    END
                WHEN i <= 54 THEN 0  -- Fully rejected
                WHEN i <= 56 THEN 
                    CASE 
                        WHEN i <= 55 THEN 2700.00  -- Partially rejected (60%)
                        ELSE 270.00
                    END
                ELSE 
                    CASE 
                        WHEN i <= 55 THEN 3600.00  -- Partially rejected (80%)
                        ELSE 360.00
                    END
            END,
            CASE 
                WHEN i <= 52 THEN NULL
                WHEN i <= 54 THEN 'MNEC-003'
                WHEN i <= 56 THEN 'MNEC-002'
                ELSE 'MNEC-001'
            END
        );
        
        -- Create claim events
        INSERT INTO claims.claim_event (claim_key_id, ingestion_file_id, event_time, type, submission_id) VALUES
        (claim_key_id_val, (SELECT id FROM claims.ingestion_file WHERE file_id = 'SUB-2024-001'), '2024-11-01 10:30:00+00'::timestamp with time zone, 1, submission_id_val);
        
        INSERT INTO claims.claim_event (claim_key_id, ingestion_file_id, event_time, type, remittance_id) VALUES
        (claim_key_id_val, (SELECT id FROM claims.ingestion_file WHERE file_id = 'REM-2024-001'), '2024-11-05 14:00:00+00'::timestamp with time zone, 3, remittance_id_val);
        
        -- Create claim status timeline
        INSERT INTO claims.claim_status_timeline (claim_key_id, status, status_time, claim_event_id) VALUES
        (claim_key_id_val, 1, '2024-11-01 10:30:00+00'::timestamp with time zone, 
         (SELECT id FROM claims.claim_event WHERE claim_key_id = claim_key_id_val AND type = 1));
        
        INSERT INTO claims.claim_status_timeline (claim_key_id, status, status_time, claim_event_id) VALUES
        (claim_key_id_val, 3, '2024-11-05 14:00:00+00'::timestamp with time zone, 
         (SELECT id FROM claims.claim_event WHERE claim_key_id = claim_key_id_val AND type = 3));
    END LOOP;
END $$;

-- ==========================================================================================================
-- SECTION 8: VERIFICATION QUERIES
-- ==========================================================================================================

-- Display summary of created data
SELECT 'Data Creation Summary' as summary;
SELECT 'Claim Keys' as table_name, COUNT(*) as record_count FROM claims.claim_key
UNION ALL
SELECT 'Claims' as table_name, COUNT(*) as record_count FROM claims.claim
UNION ALL
SELECT 'Encounters' as table_name, COUNT(*) as record_count FROM claims.encounter
UNION ALL
SELECT 'Activities' as table_name, COUNT(*) as record_count FROM claims.activity
UNION ALL
SELECT 'Remittance Claims' as table_name, COUNT(*) as record_count FROM claims.remittance_claim
UNION ALL
SELECT 'Remittance Activities' as table_name, COUNT(*) as record_count FROM claims.remittance_activity
UNION ALL
SELECT 'Claim Events' as table_name, COUNT(*) as record_count FROM claims.claim_event
UNION ALL
SELECT 'Claim Status Timeline' as table_name, COUNT(*) as record_count FROM claims.claim_status_timeline;

-- Display rejection type distribution
SELECT 'Rejection Type Distribution' as analysis;
SELECT 
    CASE 
        WHEN ra.payment_amount = 0 THEN 'Fully Rejected'
        WHEN ra.payment_amount < ra.net THEN 'Partially Rejected'
        WHEN ra.payment_amount = ra.net THEN 'Fully Paid'
        ELSE 'Unknown Status'
    END as rejection_type,
    COUNT(*) as count
FROM claims.remittance_activity ra
GROUP BY 
    CASE 
        WHEN ra.payment_amount = 0 THEN 'Fully Rejected'
        WHEN ra.payment_amount < ra.net THEN 'Partially Rejected'
        WHEN ra.payment_amount = ra.net THEN 'Fully Paid'
        ELSE 'Unknown Status'
    END
ORDER BY count DESC;

-- Display denial code distribution
SELECT 'Denial Code Distribution' as analysis;
SELECT 
    ra.denial_code,
    dc.description,
    COUNT(*) as count
FROM claims.remittance_activity ra
LEFT JOIN claims_ref.denial_code dc ON ra.denial_code = dc.code
WHERE ra.denial_code IS NOT NULL
GROUP BY ra.denial_code, dc.description
ORDER BY count DESC;

-- Display facility performance
SELECT 'Facility Performance' as analysis;
SELECT 
    f.name as facility_name,
    COUNT(DISTINCT ck.id) as total_claims,
    COUNT(DISTINCT rc.id) as remitted_claims,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = 0 THEN rc.id END) as fully_rejected,
    COUNT(DISTINCT CASE WHEN ra.payment_amount > 0 AND ra.payment_amount < ra.net THEN rc.id END) as partially_rejected,
    COUNT(DISTINCT CASE WHEN ra.payment_amount = ra.net THEN rc.id END) as fully_paid
FROM claims.claim_key ck
JOIN claims.claim c ON ck.id = c.claim_key_id
JOIN claims.encounter e ON c.id = e.claim_id
LEFT JOIN claims_ref.facility f ON e.facility_id = f.facility_code
LEFT JOIN claims.remittance_claim rc ON ck.id = rc.claim_key_id
LEFT JOIN claims.remittance_activity ra ON rc.id = ra.remittance_claim_id
GROUP BY f.name
ORDER BY total_claims DESC;

-- ==========================================================================================================
-- END OF DUMMY DATA SCRIPT
-- ==========================================================================================================

-- Instructions for using this data:
-- 1. Run this script to populate your database with test data
-- 2. The data includes various rejection scenarios for comprehensive testing
-- 3. Use the verification queries to understand the data distribution
-- 4. Test all three report tabs with this data
-- 5. Verify that the rejection calculations are working correctly
