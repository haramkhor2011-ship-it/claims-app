-- ==========================================================================================================
-- CHECK ACTUAL VIEW STRUCTURE
-- ==========================================================================================================
-- Let's see what columns actually exist in each view
-- ==========================================================================================================

-- Check Base View columns
SELECT 
  'Base Enhanced View' as view_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_schema = 'claims' 
  AND table_name = 'v_balance_amount_base_enhanced'
ORDER BY ordinal_position;

-- Check Tab A columns
SELECT 
  'Tab A View' as view_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_schema = 'claims' 
  AND table_name = 'v_balance_amount_tab_a_corrected'
ORDER BY ordinal_position;

-- Check Tab B columns
SELECT 
  'Tab B View' as view_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_schema = 'claims' 
  AND table_name = 'v_balance_amount_tab_b_corrected'
ORDER BY ordinal_position;

-- Check Tab C columns
SELECT 
  'Tab C View' as view_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_schema = 'claims' 
  AND table_name = 'v_balance_amount_tab_c_corrected'
ORDER BY ordinal_position;
