-- Quick query to check actual column names in each view
SELECT 
  'Base Enhanced' as view_name,
  column_name,
  data_type
FROM information_schema.columns 
WHERE table_schema = 'claims' 
  AND table_name = 'v_balance_amount_base_enhanced'
ORDER BY ordinal_position;

SELECT 
  'Tab A' as view_name,
  column_name,
  data_type
FROM information_schema.columns 
WHERE table_schema = 'claims' 
  AND table_name = 'v_balance_amount_tab_a_corrected'
ORDER BY ordinal_position;

SELECT 
  'Tab B' as view_name,
  column_name,
  data_type
FROM information_schema.columns 
WHERE table_schema = 'claims' 
  AND table_name = 'v_balance_amount_tab_b_corrected'
ORDER BY ordinal_position;

SELECT 
  'Tab C' as view_name,
  column_name,
  data_type
FROM information_schema.columns 
WHERE table_schema = 'claims' 
  AND table_name = 'v_balance_amount_tab_c_corrected'
ORDER BY ordinal_position;
