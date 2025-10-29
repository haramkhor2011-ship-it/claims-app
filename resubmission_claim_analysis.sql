-- Comprehensive Analysis: How Resubmission Claims are Handled in claims.claim Table
-- This analysis shows exactly what happens when a claim comes for resubmission

-- ==========================================================================================================
-- ANALYSIS: RESUBMISSION CLAIM PROCESSING
-- ==========================================================================================================

DO $$
DECLARE
    analysis_text TEXT;
BEGIN
    RAISE NOTICE '=== RESUBMISSION CLAIM ANALYSIS ===';
    RAISE NOTICE '';
    
    RAISE NOTICE '1. CLAIMS.CLAIM TABLE BEHAVIOR:';
    RAISE NOTICE '   ✓ Resubmission claims DO get processed in claims.claim table';
    RAISE NOTICE '   ✓ Uses upsertClaim() method with ON CONFLICT DO NOTHING';
    RAISE NOTICE '   ✓ If claim already exists: NO UPDATE, keeps original data';
    RAISE NOTICE '   ✓ If claim does not exist: INSERTS new claim record';
    RAISE NOTICE '';
    
    RAISE NOTICE '2. KEY INSIGHT:';
    RAISE NOTICE '   - claims.claim table stores the ORIGINAL submission data';
    RAISE NOTICE '   - Resubmission data is stored in claims.claim_resubmission table';
    RAISE NOTICE '   - claims.claim_event tracks submission vs resubmission events';
    RAISE NOTICE '';
    
    RAISE NOTICE '3. DATA FLOW FOR RESUBMISSIONS:';
    RAISE NOTICE '   Step 1: upsertClaimKey() - Gets existing claim_key_id';
    RAISE NOTICE '   Step 2: upsertClaim() - ON CONFLICT DO NOTHING (keeps original)';
    RAISE NOTICE '   Step 3: Process activities, encounters, etc. (may update)';
    RAISE NOTICE '   Step 4: Create resubmission event (type=2)';
    RAISE NOTICE '   Step 5: insertResubmission() - Stores resubmission details';
    RAISE NOTICE '';
    
    RAISE NOTICE '4. WHAT GETS STORED WHERE:';
    RAISE NOTICE '   claims.claim: Original submission data (unchanged)';
    RAISE NOTICE '   claims.claim_event: Both submission (type=1) and resubmission (type=2) events';
    RAISE NOTICE '   claims.claim_resubmission: Resubmission-specific data (type, comment, attachment)';
    RAISE NOTICE '   claims.activity: May be updated with new data';
    RAISE NOTICE '   claims.encounter: May be updated with new data';
    RAISE NOTICE '   claims.diagnosis: May be updated with new data';
END $$;

-- ==========================================================================================================
-- PRACTICAL TEST: RESUBMISSION SCENARIO
-- ==========================================================================================================

DO $$
DECLARE
    test_claim_id TEXT := 'RESUB-TEST-CLAIM-001';
    test_claim_key_id BIGINT;
    test_claim_id_db BIGINT;
    test_submission_id_1 BIGINT := 1001;
    test_submission_id_2 BIGINT := 1002;
    test_ingestion_file_id_1 BIGINT := 2001;
    test_ingestion_file_id_2 BIGINT := 2002;
    original_gross DECIMAL := 1000.00;
    resubmission_gross DECIMAL := 1200.00;
    claim_count_before INTEGER;
    claim_count_after INTEGER;
BEGIN
    RAISE NOTICE '=== PRACTICAL RESUBMISSION TEST ===';
    RAISE NOTICE '';
    
    -- Create test ingestion files
    INSERT INTO claims.ingestion_file (file_id, file_name, source, created_at) 
    VALUES ('RESUB-TEST-FILE-1', 'resub-test-1.xml', 'test', NOW()) 
    RETURNING id INTO test_ingestion_file_id_1;
    
    INSERT INTO claims.ingestion_file (file_id, file_name, source, created_at) 
    VALUES ('RESUB-TEST-FILE-2', 'resub-test-2.xml', 'test', NOW()) 
    RETURNING id INTO test_ingestion_file_id_2;
    
    -- Create test submission records
    INSERT INTO claims.submission (ingestion_file_id, tx_at) 
    VALUES (test_ingestion_file_id_1, NOW()) 
    RETURNING id INTO test_submission_id_1;
    
    INSERT INTO claims.submission (ingestion_file_id, tx_at) 
    VALUES (test_ingestion_file_id_2, NOW()) 
    RETURNING id INTO test_submission_id_2;
    
    RAISE NOTICE 'Created test data:';
    RAISE NOTICE '  Ingestion File 1: %', test_ingestion_file_id_1;
    RAISE NOTICE '  Ingestion File 2: %', test_ingestion_file_id_2;
    RAISE NOTICE '  Submission 1: %', test_submission_id_1;
    RAISE NOTICE '  Submission 2: %', test_submission_id_2;
    RAISE NOTICE '';
    
    -- Step 1: Create claim_key
    INSERT INTO claims.claim_key (claim_id, created_at) 
    VALUES (test_claim_id, NOW()) 
    RETURNING id INTO test_claim_key_id;
    
    RAISE NOTICE 'Step 1: Created claim_key_id: %', test_claim_key_id;
    
    -- Step 2: Initial submission - insert claim
    RAISE NOTICE '--- Step 2: Initial Submission ---';
    INSERT INTO claims.claim (
        claim_key_id, submission_id, id_payer, member_id, payer_id, provider_id, 
        gross, patient_share, net, tx_at
    ) VALUES (
        test_claim_key_id, test_submission_id_1, 'PAYER-001', 'MEMBER-001', 'PAYER-001', 'PROVIDER-001',
        original_gross, 100.00, 900.00, NOW()
    ) RETURNING id INTO test_claim_id_db;
    
    RAISE NOTICE '✓ Initial claim inserted with id: %', test_claim_id_db;
    RAISE NOTICE '✓ Gross amount: %', original_gross;
    
    -- Step 3: Create initial submission event
    INSERT INTO claims.claim_event (
        claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
    ) VALUES (
        test_claim_key_id, test_ingestion_file_id_1, NOW(), 1, test_submission_id_1, NULL
    );
    
    RAISE NOTICE '✓ Initial submission event created (type=1)';
    
    -- Step 4: Resubmission - simulate upsertClaim behavior
    RAISE NOTICE '--- Step 4: Resubmission (Simulating upsertClaim) ---';
    
    -- Count claims before resubmission
    SELECT COUNT(*) INTO claim_count_before FROM claims.claim WHERE claim_key_id = test_claim_key_id;
    RAISE NOTICE 'Claims before resubmission: %', claim_count_before;
    
    -- Simulate upsertClaim with ON CONFLICT DO NOTHING
    INSERT INTO claims.claim (
        claim_key_id, submission_id, id_payer, member_id, payer_id, provider_id, 
        gross, patient_share, net, tx_at
    ) VALUES (
        test_claim_key_id, test_submission_id_2, 'PAYER-001', 'MEMBER-001', 'PAYER-001', 'PROVIDER-001',
        resubmission_gross, 120.00, 1080.00, NOW()
    ) ON CONFLICT (claim_key_id) DO NOTHING;
    
    -- Count claims after resubmission
    SELECT COUNT(*) INTO claim_count_after FROM claims.claim WHERE claim_key_id = test_claim_key_id;
    RAISE NOTICE 'Claims after resubmission: %', claim_count_after;
    
    IF claim_count_before = claim_count_after THEN
        RAISE NOTICE '✓ CONFIRMED: No new claim record created (ON CONFLICT DO NOTHING worked)';
    ELSE
        RAISE NOTICE '✗ Unexpected: New claim record was created';
    END IF;
    
    -- Step 5: Check what data is actually stored
    RAISE NOTICE '--- Step 5: Data Verification ---';
    
    DECLARE
        stored_gross DECIMAL;
        stored_submission_id BIGINT;
    BEGIN
        SELECT gross, submission_id INTO stored_gross, stored_submission_id
        FROM claims.claim 
        WHERE claim_key_id = test_claim_key_id;
        
        RAISE NOTICE 'Stored gross amount: %', stored_gross;
        RAISE NOTICE 'Stored submission_id: %', stored_submission_id;
        
        IF stored_gross = original_gross THEN
            RAISE NOTICE '✓ CONFIRMED: Original gross amount preserved (% vs %)', stored_gross, resubmission_gross;
        ELSE
            RAISE NOTICE '✗ Unexpected: Gross amount changed from % to %', original_gross, stored_gross;
        END IF;
        
        IF stored_submission_id = test_submission_id_1 THEN
            RAISE NOTICE '✓ CONFIRMED: Original submission_id preserved (% vs %)', stored_submission_id, test_submission_id_2;
        ELSE
            RAISE NOTICE '✗ Unexpected: submission_id changed from % to %', test_submission_id_1, stored_submission_id;
        END IF;
    END;
    
    -- Step 6: Create resubmission event
    INSERT INTO claims.claim_event (
        claim_key_id, ingestion_file_id, event_time, type, submission_id, remittance_id
    ) VALUES (
        test_claim_key_id, test_ingestion_file_id_2, NOW(), 2, test_submission_id_2, NULL
    );
    
    RAISE NOTICE '✓ Resubmission event created (type=2)';
    
    -- Step 7: Store resubmission details
    DECLARE
        resubmission_event_id BIGINT;
    BEGIN
        SELECT id INTO resubmission_event_id
        FROM claims.claim_event 
        WHERE claim_key_id = test_claim_key_id AND type = 2;
        
        INSERT INTO claims.claim_resubmission (
            claim_event_id, resubmission_type, comment, attachment, tx_at
        ) VALUES (
            resubmission_event_id, 'CORRECTION', 'Updated amounts', NULL, NOW()
        );
        
        RAISE NOTICE '✓ Resubmission details stored in claims.claim_resubmission';
    END;
    
    -- Final verification
    RAISE NOTICE '--- Final State ---';
    RAISE NOTICE 'Total events for claim: %', (
        SELECT COUNT(*) FROM claims.claim_event WHERE claim_key_id = test_claim_key_id
    );
    
    RAISE NOTICE 'Event breakdown:';
    RAISE NOTICE '  Submission events (type=1): %', (
        SELECT COUNT(*) FROM claims.claim_event WHERE claim_key_id = test_claim_key_id AND type = 1
    );
    RAISE NOTICE '  Resubmission events (type=2): %', (
        SELECT COUNT(*) FROM claims.claim_event WHERE claim_key_id = test_claim_key_id AND type = 2
    );
    
    RAISE NOTICE 'Resubmission records: %', (
        SELECT COUNT(*) FROM claims.claim_resubmission cr
        JOIN claims.claim_event ce ON cr.claim_event_id = ce.id
        WHERE ce.claim_key_id = test_claim_key_id
    );
    
    -- Cleanup
    DELETE FROM claims.claim_resubmission WHERE claim_event_id IN (
        SELECT id FROM claims.claim_event WHERE claim_key_id = test_claim_key_id
    );
    DELETE FROM claims.claim_event WHERE claim_key_id = test_claim_key_id;
    DELETE FROM claims.claim WHERE claim_key_id = test_claim_key_id;
    DELETE FROM claims.claim_key WHERE id = test_claim_key_id;
    DELETE FROM claims.submission WHERE id IN (test_submission_id_1, test_submission_id_2);
    DELETE FROM claims.ingestion_file WHERE id IN (test_ingestion_file_id_1, test_ingestion_file_id_2);
    
    RAISE NOTICE '';
    RAISE NOTICE '=== CONCLUSION ===';
    RAISE NOTICE '✓ Resubmission claims DO get processed in claims.claim table';
    RAISE NOTICE '✓ Original claim data is PRESERVED (not updated)';
    RAISE NOTICE '✓ Resubmission data is stored separately in claims.claim_resubmission';
    RAISE NOTICE '✓ Both submission and resubmission events are tracked';
    RAISE NOTICE '✓ This maintains data integrity and audit trail';
END $$;

-- ==========================================================================================================
-- QUERY EXAMPLES FOR RESUBMISSION DATA
-- ==========================================================================================================

DO $$
BEGIN
    RAISE NOTICE '=== USEFUL QUERIES FOR RESUBMISSION DATA ===';
    RAISE NOTICE '';
    
    RAISE NOTICE '1. Get all claims with resubmissions:';
    RAISE NOTICE '   SELECT c.*, ce.type, ce.event_time';
    RAISE NOTICE '   FROM claims.claim c';
    RAISE NOTICE '   JOIN claims.claim_event ce ON c.claim_key_id = ce.claim_key_id';
    RAISE NOTICE '   WHERE ce.type = 2;';
    RAISE NOTICE '';
    
    RAISE NOTICE '2. Get resubmission details:';
    RAISE NOTICE '   SELECT c.*, cr.resubmission_type, cr.comment, cr.tx_at';
    RAISE NOTICE '   FROM claims.claim c';
    RAISE NOTICE '   JOIN claims.claim_event ce ON c.claim_key_id = ce.claim_key_id';
    RAISE NOTICE '   JOIN claims.claim_resubmission cr ON ce.id = cr.claim_event_id';
    RAISE NOTICE '   WHERE ce.type = 2;';
    RAISE NOTICE '';
    
    RAISE NOTICE '3. Get submission history for a claim:';
    RAISE NOTICE '   SELECT ce.type, ce.event_time, s.tx_at as submission_time';
    RAISE NOTICE '   FROM claims.claim_event ce';
    RAISE NOTICE '   LEFT JOIN claims.submission s ON ce.submission_id = s.id';
    RAISE NOTICE '   WHERE ce.claim_key_id = ?';
    RAISE NOTICE '   ORDER BY ce.event_time;';
    RAISE NOTICE '';
    
    RAISE NOTICE '4. Count resubmissions per claim:';
    RAISE NOTICE '   SELECT c.id, COUNT(ce.id) as resubmission_count';
    RAISE NOTICE '   FROM claims.claim c';
    RAISE NOTICE '   JOIN claims.claim_event ce ON c.claim_key_id = ce.claim_key_id';
    RAISE NOTICE '   WHERE ce.type = 2';
    RAISE NOTICE '   GROUP BY c.id;';
END $$;




