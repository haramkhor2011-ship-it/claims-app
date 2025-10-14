-- ==========================================================================================================
-- REFERENCE DATA TABLES - CLAIMS_REF SCHEMA
-- ==========================================================================================================
-- 
-- Purpose: Create reference data tables for lookups
-- Version: 1.0
-- Date: 2025-01-15
-- 
-- This script creates reference data tables including:
-- - Facilities, payers, providers, clinicians
-- - Activity codes, diagnosis codes, denial codes
-- - Contract packages and observation dictionaries
--
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- FACILITIES
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.facility (
  id             BIGSERIAL PRIMARY KEY,
  facility_code  TEXT NOT NULL UNIQUE,
  name           TEXT,
  city           TEXT,
  country        TEXT,
  status         TEXT DEFAULT 'ACTIVE',
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE claims_ref.facility IS 'Master list of provider facilities (Encounter.FacilityID)';
COMMENT ON COLUMN claims_ref.facility.facility_code IS 'External FacilityID (DHA/eClaim)';

CREATE INDEX IF NOT EXISTS idx_facility_code ON claims_ref.facility(facility_code);
CREATE INDEX IF NOT EXISTS idx_facility_status ON claims_ref.facility(status);
CREATE INDEX IF NOT EXISTS idx_ref_facility_code ON claims_ref.facility(facility_code);
CREATE INDEX IF NOT EXISTS idx_ref_facility_name_trgm ON claims_ref.facility USING gin (name gin_trgm_ops);

-- ----------------------------------------------------------------------------------------------------------
-- PAYERS
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.payer (
  id          BIGSERIAL PRIMARY KEY,
  payer_code  TEXT NOT NULL UNIQUE,
  name        TEXT,
  status      TEXT DEFAULT 'ACTIVE',
  classification   TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE claims_ref.payer IS 'Master list of Payers (Claim.PayerID)';
COMMENT ON COLUMN claims_ref.payer.payer_code IS 'External PayerID';

CREATE INDEX IF NOT EXISTS idx_payer_code ON claims_ref.payer(payer_code);
CREATE INDEX IF NOT EXISTS idx_payer_status ON claims_ref.payer(status);
CREATE INDEX IF NOT EXISTS idx_ref_payer_code ON claims_ref.payer(payer_code);
CREATE INDEX IF NOT EXISTS idx_ref_payer_name_trgm ON claims_ref.payer USING gin (name gin_trgm_ops);

-- ----------------------------------------------------------------------------------------------------------
-- PROVIDERS
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.provider (
  id            BIGSERIAL PRIMARY KEY,
  provider_code TEXT NOT NULL UNIQUE,
  name          TEXT,
  status        TEXT DEFAULT 'ACTIVE',
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE claims_ref.provider IS 'Master list of provider organizations (Claim.ProviderID)';

CREATE INDEX IF NOT EXISTS idx_provider_code ON claims_ref.provider(provider_code);
CREATE INDEX IF NOT EXISTS idx_provider_status ON claims_ref.provider(status);
CREATE INDEX IF NOT EXISTS idx_ref_provider_code ON claims_ref.provider(provider_code);
CREATE INDEX IF NOT EXISTS idx_ref_provider_name_trgm ON claims_ref.provider USING gin (name gin_trgm_ops);

-- ----------------------------------------------------------------------------------------------------------
-- CLINICIANS
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.clinician (
  id              BIGSERIAL PRIMARY KEY,
  clinician_code  TEXT NOT NULL UNIQUE,
  name            TEXT,
  specialty       TEXT,
  status          TEXT DEFAULT 'ACTIVE',
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE claims_ref.clinician IS 'Master list of clinicians (Activity.Clinician)';

CREATE INDEX IF NOT EXISTS idx_clinician_code ON claims_ref.clinician(clinician_code);
CREATE INDEX IF NOT EXISTS idx_clinician_status ON claims_ref.clinician(status);
CREATE INDEX IF NOT EXISTS idx_ref_clinician_code ON claims_ref.clinician(clinician_code);
CREATE INDEX IF NOT EXISTS idx_ref_clinician_name_trgm ON claims_ref.clinician USING gin (name gin_trgm_ops);

-- ----------------------------------------------------------------------------------------------------------
-- ACTIVITY CODES
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.activity_code (
  id           BIGSERIAL PRIMARY KEY,
  type          TEXT,
  code         TEXT NOT NULL,
  code_system  TEXT NOT NULL DEFAULT 'LOCAL',
  description  TEXT,
  status       TEXT DEFAULT 'ACTIVE',
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_activity_code UNIQUE (code, type)
);

COMMENT ON TABLE claims_ref.activity_code IS 'Service/procedure codes used in Activity.Code';

CREATE INDEX IF NOT EXISTS idx_activity_code_lookup ON claims_ref.activity_code(code, type);
CREATE INDEX IF NOT EXISTS idx_activity_code_status ON claims_ref.activity_code(status);
CREATE INDEX IF NOT EXISTS idx_ref_activity_code ON claims_ref.activity_code(code);
CREATE INDEX IF NOT EXISTS idx_ref_activity_desc_trgm ON claims_ref.activity_code USING gin (description gin_trgm_ops);

-- ----------------------------------------------------------------------------------------------------------
-- DIAGNOSIS CODES
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.diagnosis_code (
  id           BIGSERIAL PRIMARY KEY,
  code         TEXT NOT NULL,
  code_system  TEXT NOT NULL DEFAULT 'ICD-10',
  description  TEXT,
  status       TEXT DEFAULT 'ACTIVE',
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_diagnosis_code UNIQUE (code, code_system)
);

COMMENT ON TABLE claims_ref.diagnosis_code IS 'Diagnosis codes (Diagnosis.Code)';

CREATE INDEX IF NOT EXISTS idx_diagnosis_code_lookup ON claims_ref.diagnosis_code(code, code_system);
CREATE INDEX IF NOT EXISTS idx_diagnosis_code_status ON claims_ref.diagnosis_code(status);
CREATE INDEX IF NOT EXISTS idx_ref_diag_code ON claims_ref.diagnosis_code(code);
CREATE INDEX IF NOT EXISTS idx_ref_diag_desc_trgm ON claims_ref.diagnosis_code USING gin (description gin_trgm_ops);

-- ----------------------------------------------------------------------------------------------------------
-- DENIAL CODES
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.denial_code (
  id          BIGSERIAL PRIMARY KEY,
  code        TEXT NOT NULL UNIQUE,
  description TEXT,
  payer_code  TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE claims_ref.denial_code IS 'Adjudication denial codes; optionally scoped by payer_code';

CREATE INDEX IF NOT EXISTS idx_denial_code_lookup ON claims_ref.denial_code(code);
CREATE INDEX IF NOT EXISTS idx_denial_code_payer ON claims_ref.denial_code(payer_code);
CREATE INDEX IF NOT EXISTS idx_ref_denial_desc_trgm ON claims_ref.denial_code USING gin (description gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_ref_denial_payer ON claims_ref.denial_code(payer_code);

-- ----------------------------------------------------------------------------------------------------------
-- OBSERVATION DICTIONARIES
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.observation_type (
  obs_type     TEXT PRIMARY KEY,
  description  TEXT
);

CREATE TABLE IF NOT EXISTS claims_ref.observation_value_type (
  value_type   TEXT PRIMARY KEY,
  description  TEXT
);

COMMENT ON TABLE claims_ref.observation_type IS 'Dictionary of observation types';
COMMENT ON TABLE claims_ref.observation_value_type IS 'Dictionary of observation value types';

-- ----------------------------------------------------------------------------------------------------------
-- CONTRACT PACKAGES
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.contract_package (
  id           BIGSERIAL PRIMARY KEY,
  package_name TEXT NOT NULL UNIQUE,
  description  TEXT,
  status       TEXT DEFAULT 'ACTIVE',
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE claims_ref.contract_package IS 'Insurance contract/package names';

CREATE INDEX IF NOT EXISTS idx_contract_package_name ON claims_ref.contract_package(package_name);
CREATE INDEX IF NOT EXISTS idx_contract_package_status ON claims_ref.contract_package(status);

-- ----------------------------------------------------------------------------------------------------------
-- GRANTS TO CLAIMS_USER
-- ----------------------------------------------------------------------------------------------------------

-- Grant all privileges on reference tables to claims_user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA claims_ref TO claims_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA claims_ref TO claims_user;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA claims_ref GRANT ALL ON TABLES TO claims_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA claims_ref GRANT ALL ON SEQUENCES TO claims_user;
