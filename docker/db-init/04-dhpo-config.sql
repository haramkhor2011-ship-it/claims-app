-- ==========================================================================================================
-- DHPO INTEGRATION CONFIGURATION
-- ==========================================================================================================
-- 
-- Purpose: Create DHPO integration tables with AME encryption support
-- Version: 1.0
-- Date: 2025-01-15
-- 
-- This script creates tables for:
-- - Facility DHPO configuration with encrypted credentials
-- - Integration toggles for feature flags
-- - AME encryption metadata storage
--
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- FACILITY DHPO CONFIGURATION
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.facility_dhpo_config (
  id                    BIGSERIAL PRIMARY KEY,
  facility_code         TEXT NOT NULL,
  facility_name         TEXT NOT NULL,
  endpoint_url          TEXT NOT NULL DEFAULT 'https://dhpo.eclaimlink.ae/ValidateTransactions.asmx',
  endpoint_url_for_erx  TEXT NOT NULL DEFAULT 'https://dhpo.eclaimlink.ae/eRxValidateTransactions.asmx',
  
  -- App-managed encryption for credentials (AME)
  dhpo_username_enc     BYTEA,
  dhpo_password_enc     BYTEA,
  enc_meta_json         JSONB DEFAULT '{}'::jsonb,
  
  -- Legacy plain columns (for migration)
  login_ct              BYTEA,
  pwd_ct                BYTEA,
  enc_meta              JSONB DEFAULT '{}'::jsonb,
  
  active                BOOLEAN NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(facility_code)
);

COMMENT ON TABLE claims.facility_dhpo_config IS 'Per-facility DHPO endpoints + encrypted creds (AME)';
COMMENT ON COLUMN claims.facility_dhpo_config.enc_meta_json IS 'Enc metadata: {"kek_version":int,"alg":"AES/GCM","iv":"b64","tagBits":int}';
COMMENT ON COLUMN claims.facility_dhpo_config.dhpo_username_enc IS 'Encrypted DHPO username using AME';
COMMENT ON COLUMN claims.facility_dhpo_config.dhpo_password_enc IS 'Encrypted DHPO password using AME';

-- ----------------------------------------------------------------------------------------------------------
-- INTEGRATION TOGGLES
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.integration_toggle (
  code       TEXT PRIMARY KEY,
  enabled    BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.integration_toggle IS 'Feature flags for integration components';

-- ----------------------------------------------------------------------------------------------------------
-- DEFAULT INTEGRATION TOGGLES
-- ----------------------------------------------------------------------------------------------------------
INSERT INTO claims.integration_toggle(code, enabled) VALUES
  ('dhpo.search.enabled', true),
  ('dhpo.setDownloaded.enabled', true),
  ('dhpo.new.enabled', true),
  ('db.initialized', false)
ON CONFLICT (code) DO NOTHING;

-- ----------------------------------------------------------------------------------------------------------
-- GRANTS TO CLAIMS_USER
-- ----------------------------------------------------------------------------------------------------------

-- Grant operational access to claims_user
GRANT SELECT, INSERT, UPDATE ON claims.facility_dhpo_config TO claims_user;
GRANT SELECT, INSERT, UPDATE ON claims.integration_toggle TO claims_user;

-- Grant sequence access
GRANT USAGE, SELECT ON SEQUENCE claims.facility_dhpo_config_id_seq TO claims_user;

-- ----------------------------------------------------------------------------------------------------------
-- INDEXES FOR PERFORMANCE
-- ----------------------------------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_facility_dhpo_config_code ON claims.facility_dhpo_config(facility_code);
CREATE INDEX IF NOT EXISTS idx_facility_dhpo_config_active ON claims.facility_dhpo_config(active);
CREATE INDEX IF NOT EXISTS idx_integration_toggle_enabled ON claims.integration_toggle(enabled);

-- ----------------------------------------------------------------------------------------------------------
-- COMMENTS ON RESOLUTION RULES
-- ----------------------------------------------------------------------------------------------------------
-- Resolution rules in code:
-- effective_search_enabled = coalesce(facility.search_enabled, global.search.enabled)
-- effective_setdownload_enabled = coalesce(facility.setdownload_enabled, global.setDownloaded.enabled)
-- effective_retry_max_attempts = coalesce(facility.retry_max_attempts, 2)
