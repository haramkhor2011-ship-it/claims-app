-- ==========================================================================================================
-- DHPO INTEGRATION CONFIGURATION
-- ==========================================================================================================
-- 
-- Purpose: Create DHPO integration tables with AME encryption support
-- Version: 2.0
-- Date: 2025-10-24
-- 
-- This script creates tables for:
-- - Facility DHPO configuration with encrypted credentials
-- - Integration toggles for feature flags
-- - AME encryption metadata storage
--
-- Note: Extensions and schemas are created in 01-init-db.sql
-- Note: Core tables are created in 02-core-tables.sql
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: FACILITY DHPO CONFIGURATION
-- ==========================================================================================================

CREATE TABLE IF NOT EXISTS claims.facility_dhpo_config (
  id                    BIGSERIAL PRIMARY KEY,
  facility_code         CITEXT NOT NULL,
  facility_name         TEXT NOT NULL,

  -- DHPO endpoints
  endpoint_url          TEXT NOT NULL DEFAULT 'https://dhpo.eclaimlink.ae/ValidateTransactions.asmx',
  endpoint_url_for_erx  TEXT NOT NULL DEFAULT 'https://dhpo.eclaimlink.ae/eRxValidateTransactions.asmx',

  -- App-managed encryption for credentials
  dhpo_username_enc     BYTEA NOT NULL,
  dhpo_password_enc     BYTEA NOT NULL,
  enc_meta_json         JSONB NOT NULL DEFAULT '{}'::jsonb,  -- {kek_version:int, alg:"AES/GCM", iv:base64, tagBits:int}

  active                BOOLEAN NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(facility_code)
);

COMMENT ON TABLE claims.facility_dhpo_config IS 'Per-facility DHPO endpoints + encrypted creds (AME)';
COMMENT ON COLUMN claims.facility_dhpo_config.enc_meta_json IS 'Enc metadata: {"kek_version":int,"alg":"AES/GCM","iv":"b64","tagBits":int}';

CREATE INDEX IF NOT EXISTS idx_facility_dhpo_config_active ON claims.facility_dhpo_config(active);

-- ==========================================================================================================
-- SECTION 2: INTEGRATION TOGGLES
-- ==========================================================================================================

CREATE TABLE IF NOT EXISTS claims.integration_toggle (
  code       TEXT PRIMARY KEY,
  enabled    BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


COMMENT ON TABLE claims.integration_toggle IS 'Feature toggles for integrations';


-- ==========================================================================================================
-- SECTION 3: DEFAULT INTEGRATION TOGGLES
-- ==========================================================================================================
insert into claims.integration_toggle (code,enabled) values ('dhpo.new.enabled',false);
insert into claims.integration_toggle (code,enabled) values ('dhpo.search.enabled',false);
insert into claims.integration_toggle (code,enabled) values ('dhpo.setDownloaded.enabled',false);
insert into claims.integration_toggle (code,enabled) values ('dhpo.startup.backfill.enabled',true);

-- ==========================================================================================================
-- SECTION 4: RESOLUTION RULES (DOCUMENTATION)
-- ==========================================================================================================

-- Resolution rules in code:
-- effective_search_enabled = coalesce(facility.search_enabled, global.search.enabled)
-- effective_setdownload_enabled = coalesce(facility.setdownload_enabled, global.setDownloaded.enabled)
-- effective_retry_max_attempts = coalesce(facility.retry_max_attempts, 2)

-- ==========================================================================================================
-- SECTION 5: PERMISSIONS AND GRANTS
-- ==========================================================================================================

-- Grant operational access to claims_user
GRANT SELECT, INSERT, UPDATE ON claims.facility_dhpo_config TO claims_user;
GRANT SELECT, INSERT, UPDATE ON claims.integration_toggle TO claims_user;

-- Grant sequence access
GRANT USAGE, SELECT ON SEQUENCE claims.facility_dhpo_config_id_seq TO claims_user;

-- ==========================================================================================================
-- END OF DHPO CONFIGURATION
-- ==========================================================================================================