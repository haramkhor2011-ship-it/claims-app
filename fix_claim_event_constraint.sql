-- Fix missing constraint that's causing claim persistence failures
-- This constraint is required for the insertClaimEvent SQL to work properly

-- Check if the constraint exists
DO $$
BEGIN
    -- Try to add the constraint if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'uq_claim_event_dedup' 
        AND table_name = 'claim_event' 
        AND table_schema = 'claims'
    ) THEN
        -- Add the missing constraint
        ALTER TABLE claims.claim_event 
        ADD CONSTRAINT uq_claim_event_dedup 
        UNIQUE (claim_key_id, type, event_time);
        
        RAISE NOTICE 'Added missing constraint uq_claim_event_dedup';
    ELSE
        RAISE NOTICE 'Constraint uq_claim_event_dedup already exists';
    END IF;
END $$;

-- Verify the constraint exists
SELECT constraint_name, constraint_type, table_name 
FROM information_schema.table_constraints 
WHERE constraint_name = 'uq_claim_event_dedup' 
AND table_schema = 'claims';
