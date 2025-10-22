-- Check what constraints and indexes actually exist on claim_event table
-- This will help identify the naming conflict

-- Step 1: List ALL constraints on the claim_event table
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'claims.claim_event'::regclass
ORDER BY conname;

-- Step 2: List ALL indexes on the claim_event table
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'claim_event' 
AND schemaname = 'claims'
ORDER BY indexname;

-- Step 3: Check for any constraints with 'dedup' in the name
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'claims.claim_event'::regclass
AND conname LIKE '%dedup%';

-- Step 4: Check for any indexes with 'dedup' in the name
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'claim_event' 
AND schemaname = 'claims'
AND indexname LIKE '%dedup%';
