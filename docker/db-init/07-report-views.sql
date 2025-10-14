-- ==========================================================================================================
-- REPORT VIEWS - SQL VIEWS FOR REPORTS
-- ==========================================================================================================
-- 
-- Purpose: Create SQL views for reports (if needed)
-- Version: 1.0
-- Date: 2025-01-15
-- 
-- This script creates SQL views for reports that are not covered by materialized views.
-- Most reports use materialized views for performance, but some may need dynamic views.
--
-- ==========================================================================================================

-- Note: Most reports use materialized views for sub-second performance.
-- This file is reserved for any dynamic views that may be needed.
-- Currently, all reports are covered by materialized views in 06-materialized-views.sql

-- Example view structure (uncomment and modify as needed):
/*
-- Sample dynamic view for real-time data
CREATE OR REPLACE VIEW claims.v_recent_claims AS
SELECT 
  ck.claim_id,
  c.payer_id,
  c.provider_id,
  c.net,
  c.created_at,
  p.name as payer_name,
  pr.name as provider_name
FROM claims.claim_key ck
JOIN claims.claim c ON c.claim_key_id = ck.id
LEFT JOIN claims_ref.payer p ON p.id = c.payer_ref_id
LEFT JOIN claims_ref.provider pr ON pr.id = c.provider_ref_id
WHERE c.created_at >= NOW() - INTERVAL '24 hours'
ORDER BY c.created_at DESC;
*/

-- Grant access to claims_user
GRANT SELECT ON ALL TABLES IN SCHEMA claims TO claims_user;
