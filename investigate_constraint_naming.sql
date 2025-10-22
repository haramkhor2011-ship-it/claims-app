-- Investigate the constraint naming issue
-- Check all constraints on the claim_event table

-- Step 1: List ALL constraints on the claim_event table
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'claims.claim_event'::regclass;

-- Step 2: Check information_schema for constraints
SELECT 
    constraint_name, 
    constraint_type, 
    table_name,
    table_schema
FROM information_schema.table_constraints 
WHERE table_name = 'claim_event' 
AND table_schema = 'claims';

-- Step 3: Check for unique indexes (constraints might be created as indexes)
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'claim_event' 
AND schemaname = 'claims'
AND indexdef LIKE '%UNIQUE%';

-- Step 4: Check if there's a constraint with similar name
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'claims.claim_event'::regclass
AND conname LIKE '%dedup%';
