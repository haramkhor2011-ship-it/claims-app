-- ==========================================================================================================
-- SCOPING CHECK SKELETON (Reuse from 02_balance_amount_to_be_received_report_corrected.sql)
-- ==========================================================================================================
-- Purpose: Provide a reusable template for adding user-facility scoping to any report view/function.
-- Usage:
-- 1) Ensure function claims.check_user_facility_access(user_id, facility_code, access_type) exists.
-- 2) Wrap a base report view with a scoped view using the template below.
-- 3) Replace placeholders: {SCOPED_VIEW_NAME}, {BASE_VIEW_NAME}, {BASE_SOURCE_VIEW}.

-- Function reference (should already be created by 02 report corrected SQL):
--   CREATE OR REPLACE FUNCTION claims.check_user_facility_access(p_user_id TEXT, p_facility_code TEXT, p_access_type TEXT DEFAULT 'READ')
--   RETURNS BOOLEAN ...

-- Template for creating a scoped view from a base view
-- NOTE: {BASE_SOURCE_VIEW} must expose claim_key_id and facility_id
-- Example replacements:
--   {SCOPED_VIEW_NAME}  -> claims.v_your_report_scoped
--   {BASE_VIEW_NAME}    -> claims.v_your_report
--   {BASE_SOURCE_VIEW}  -> claims.v_your_report_base (or the same as base view if it contains facility_id)
--
-- CREATE OR REPLACE VIEW {SCOPED_VIEW_NAME} AS
-- SELECT t.*
-- FROM {BASE_VIEW_NAME} t
-- JOIN {BASE_SOURCE_VIEW} b ON b.claim_key_id = t.claim_key_id
-- WHERE claims.check_user_facility_access(
--   current_setting(''app.current_user_id'', TRUE),
--   b.facility_id,
--   'READ'
-- );

-- Grants example:
-- GRANT SELECT ON {SCOPED_VIEW_NAME} TO claims_user;

-- Optional: API function wrapper pattern (returns table with total_records for pagination)
-- CREATE OR REPLACE FUNCTION claims.get_{report_code}_scoped(
--   p_user_id TEXT,
--   p_facility_codes TEXT[] DEFAULT NULL,
--   p_date_from TIMESTAMPTZ DEFAULT NULL,
--   p_date_to TIMESTAMPTZ DEFAULT NULL,
--   p_limit INTEGER DEFAULT 100,
--   p_offset INTEGER DEFAULT 0
-- ) RETURNS SETOF {SCOPED_VIEW_NAME} AS $$
-- DECLARE
--   v_where TEXT := ''WHERE 1=1'';
-- BEGIN
--   IF p_date_from IS NOT NULL THEN v_where := v_where || '' AND b.encounter_start >= $3''; END IF;
--   IF p_date_to   IS NOT NULL THEN v_where := v_where || '' AND b.encounter_start <= $4''; END IF;
--   IF p_facility_codes IS NOT NULL AND array_length(p_facility_codes,1) > 0 THEN
--     v_where := v_where || '' AND b.facility_id = ANY($2)'';
--   ELSE
--     v_where := v_where || '' AND claims.check_user_facility_access($1, b.facility_id, ''''READ'''')'';
--   END IF;
--   RETURN QUERY EXECUTE format(''SELECT t.* FROM {BASE_VIEW_NAME} t JOIN {BASE_SOURCE_VIEW} b ON b.claim_key_id=t.claim_key_id %s LIMIT $5 OFFSET $6'', v_where)
--     USING p_user_id, p_facility_codes, p_date_from, p_date_to, p_limit, p_offset;
-- END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- TODO: When implementing each specific report, copy this block, substitute placeholders, and add grants.

-- ==========================================================================================================



