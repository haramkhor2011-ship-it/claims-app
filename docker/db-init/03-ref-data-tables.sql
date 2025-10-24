-- ==========================================================================================================
-- REFERENCE DATA TABLES - CLAIMS_REF SCHEMA
-- ==========================================================================================================
-- 
-- Purpose: Create all reference data tables for claims processing
-- Version: 2.0
-- Date: 2025-10-24
-- 
-- This script creates reference data tables including:
-- - Facility, Payer, Provider, Clinician master data
-- - Activity codes, Diagnosis codes, Denial codes
-- - Observation dictionaries and type mappings
-- - Bootstrap status tracking
-- - Foreign key constraints to core tables
--
-- Note: Extensions and schemas are created in 01-init-db.sql
-- Note: Core tables are created in 02-core-tables.sql
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: FACILITY MASTER DATA
-- ==========================================================================================================

CREATE TABLE IF NOT EXISTS claims_ref.facility (
  id             BIGSERIAL PRIMARY KEY,
  facility_code  TEXT NOT NULL UNIQUE,  -- e.g., DHA-F-0045446
  name           TEXT,
  city           TEXT,
  country        TEXT,
  status         TEXT DEFAULT 'ACTIVE',
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ
);

COMMENT ON TABLE claims_ref.facility IS 'Master list of provider facilities (Encounter.FacilityID)';
COMMENT ON COLUMN claims_ref.facility.facility_code IS 'External FacilityID (DHA/eClaim)';

CREATE INDEX IF NOT EXISTS idx_facility_code ON claims_ref.facility(facility_code);
CREATE INDEX IF NOT EXISTS idx_facility_status ON claims_ref.facility(status);
CREATE INDEX IF NOT EXISTS idx_ref_facility_code ON claims_ref.facility(facility_code);
CREATE INDEX IF NOT EXISTS idx_ref_facility_name_trgm ON claims_ref.facility USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_facility_active ON claims_ref.facility(facility_code) WHERE status = 'ACTIVE';

-- ==========================================================================================================
-- SECTION 2: PAYER MASTER DATA
-- ==========================================================================================================

CREATE TABLE IF NOT EXISTS claims_ref.payer (
  id             BIGSERIAL PRIMARY KEY,
  payer_code     TEXT NOT NULL UNIQUE,     -- e.g., INS025
  name           TEXT,
  status         TEXT DEFAULT 'ACTIVE',
  classification TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE claims_ref.payer IS 'Master list of Payers (Claim.PayerID)';
COMMENT ON COLUMN claims_ref.payer.payer_code IS 'External PayerID';

CREATE INDEX IF NOT EXISTS idx_payer_code ON claims_ref.payer(payer_code);
CREATE INDEX IF NOT EXISTS idx_payer_status ON claims_ref.payer(status);
CREATE INDEX IF NOT EXISTS idx_ref_payer_code ON claims_ref.payer(payer_code);
CREATE INDEX IF NOT EXISTS idx_ref_payer_name_trgm ON claims_ref.payer USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_payer_active ON claims_ref.payer(payer_code) WHERE status = 'ACTIVE';

-- ==========================================================================================================
-- SECTION 3: PROVIDER MASTER DATA
-- ==========================================================================================================

CREATE TABLE IF NOT EXISTS claims_ref.provider (
  id            BIGSERIAL PRIMARY KEY,
  provider_code TEXT NOT NULL UNIQUE,
  name          TEXT,
  status        TEXT DEFAULT 'ACTIVE',
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ
);

COMMENT ON TABLE claims_ref.provider IS 'Master list of provider organizations (Claim.ProviderID)';

CREATE INDEX IF NOT EXISTS idx_provider_code ON claims_ref.provider(provider_code);
CREATE INDEX IF NOT EXISTS idx_provider_status ON claims_ref.provider(status);
CREATE INDEX IF NOT EXISTS idx_ref_provider_code ON claims_ref.provider(provider_code);
CREATE INDEX IF NOT EXISTS idx_ref_provider_name_trgm ON claims_ref.provider USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_provider_active ON claims_ref.provider(provider_code) WHERE status = 'ACTIVE';

-- ==========================================================================================================
-- SECTION 4: CLINICIAN MASTER DATA
-- ==========================================================================================================

CREATE TABLE IF NOT EXISTS claims_ref.clinician (
  id              BIGSERIAL PRIMARY KEY,
  clinician_code  TEXT NOT NULL UNIQUE, -- e.g., DHA-P-0228312
  name            TEXT,
  specialty       TEXT,
  status          TEXT DEFAULT 'ACTIVE',
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ
);

COMMENT ON TABLE claims_ref.clinician IS 'Master list of clinicians (Activity.Clinician)';

CREATE INDEX IF NOT EXISTS idx_clinician_code ON claims_ref.clinician(clinician_code);
CREATE INDEX IF NOT EXISTS idx_clinician_status ON claims_ref.clinician(status);
CREATE INDEX IF NOT EXISTS idx_ref_clinician_code ON claims_ref.clinician(clinician_code);
CREATE INDEX IF NOT EXISTS idx_ref_clinician_name_trgm ON claims_ref.clinician USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_clinician_active ON claims_ref.clinician(clinician_code) WHERE status = 'ACTIVE';

-- ==========================================================================================================
-- SECTION 5: ACTIVITY CODES
-- ==========================================================================================================

CREATE TABLE IF NOT EXISTS claims_ref.activity_code (
  id           BIGSERIAL PRIMARY KEY,
  type         TEXT,
  code         TEXT NOT NULL,
  code_system  TEXT NOT NULL DEFAULT 'LOCAL',   -- CPT/HCPCS/LOCAL/etc.
  description  TEXT,
  status       TEXT DEFAULT 'ACTIVE',
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ,
  CONSTRAINT uq_activity_code UNIQUE (code, type)
);

COMMENT ON TABLE claims_ref.activity_code IS 'Service/procedure codes used in Activity.Code';

CREATE INDEX IF NOT EXISTS idx_activity_code_lookup ON claims_ref.activity_code(code, type);
CREATE INDEX IF NOT EXISTS idx_activity_code_status ON claims_ref.activity_code(status);
CREATE INDEX IF NOT EXISTS idx_ref_activity_code ON claims_ref.activity_code(code);
CREATE INDEX IF NOT EXISTS idx_ref_activity_desc_trgm ON claims_ref.activity_code USING gin (description gin_trgm_ops);

-- ==========================================================================================================
-- SECTION 6: DIAGNOSIS CODES
-- ==========================================================================================================

CREATE TABLE IF NOT EXISTS claims_ref.diagnosis_code (
  id           BIGSERIAL PRIMARY KEY,
  code         TEXT NOT NULL,
  code_system  TEXT NOT NULL DEFAULT 'ICD-10',
  description  TEXT,
  status       TEXT DEFAULT 'ACTIVE',
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ,
  CONSTRAINT uq_diagnosis_code UNIQUE (code, description)
);

COMMENT ON TABLE claims_ref.diagnosis_code IS 'Diagnosis codes (Diagnosis.Code)';

CREATE INDEX IF NOT EXISTS idx_diagnosis_code_lookup ON claims_ref.diagnosis_code(code, description);
CREATE INDEX IF NOT EXISTS idx_diagnosis_code_status ON claims_ref.diagnosis_code(status);
CREATE INDEX IF NOT EXISTS idx_ref_diag_code ON claims_ref.diagnosis_code(code);
CREATE INDEX IF NOT EXISTS idx_ref_diag_desc_trgm ON claims_ref.diagnosis_code USING gin (description gin_trgm_ops);

-- ==========================================================================================================
-- SECTION 7: DENIAL CODES
-- ==========================================================================================================

CREATE TABLE IF NOT EXISTS claims_ref.denial_code (
  id          BIGSERIAL PRIMARY KEY,
  code        TEXT NOT NULL UNIQUE,
  description TEXT,
  payer_code  TEXT,  -- optional scope
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ
);

COMMENT ON TABLE claims_ref.denial_code IS 'Adjudication denial codes; optionally scoped by payer_code';

CREATE INDEX IF NOT EXISTS idx_denial_code_lookup ON claims_ref.denial_code(code);
CREATE INDEX IF NOT EXISTS idx_denial_code_payer ON claims_ref.denial_code(payer_code);
CREATE INDEX IF NOT EXISTS idx_ref_denial_desc_trgm ON claims_ref.denial_code USING gin (description gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_ref_denial_payer ON claims_ref.denial_code(payer_code);

-- ==========================================================================================================
-- SECTION 8: OBSERVATION DICTIONARIES
-- ==========================================================================================================

CREATE TABLE IF NOT EXISTS claims_ref.observation_type (
  obs_type     TEXT PRIMARY KEY,  -- LOINC/Text/File/Universal Dental/Financial/Grouping/ERX/Result
  description  TEXT
);

CREATE TABLE IF NOT EXISTS claims_ref.observation_value_type (
  value_type   TEXT PRIMARY KEY,  -- curated unit/value type (optional)
  description  TEXT
);

CREATE TABLE IF NOT EXISTS claims_ref.observation_code (
  id          BIGSERIAL PRIMARY KEY,
  code        TEXT NOT NULL UNIQUE, -- curated short-hand like A1C/BPS/etc.
  description TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Seed observation types
INSERT INTO claims_ref.observation_type(obs_type, description) VALUES
  ('LOINC','LOINC standardized code'),
  ('Text','Free text observation'),
  ('File','Binary file attachment'),
  ('Universal Dental','Universal Dental coding'),
  ('Financial','Financial observation'),
  ('Grouping','Panel/grouping marker'),
  ('ERX','Electronic prescription'),
  ('Result','Generic lab/clinical result')
ON CONFLICT (obs_type) DO UPDATE SET description = EXCLUDED.description;

-- ==========================================================================================================
-- SECTION 9: TYPE DICTIONARIES
-- ==========================================================================================================

CREATE TABLE IF NOT EXISTS claims_ref.activity_type (
  type_code   TEXT PRIMARY KEY,
  description TEXT
);

CREATE TABLE IF NOT EXISTS claims_ref.encounter_type (
  type_code   TEXT PRIMARY KEY,
  description TEXT
);

CREATE TABLE IF NOT EXISTS claims_ref.resubmission_type (
  type_code   TEXT PRIMARY KEY,
  description TEXT
);

-- Seed activity types
INSERT INTO claims_ref.activity_type(type_code, description) VALUES
  ('PROCEDURE', 'Medical procedure'),
  ('DIAGNOSIS', 'Diagnostic service'),
  ('TREATMENT', 'Treatment service'),
  ('CONSULTATION', 'Medical consultation'),
  ('LABORATORY', 'Laboratory test'),
  ('RADIOLOGY', 'Radiology service'),
  ('PHARMACY', 'Pharmacy service')
ON CONFLICT (type_code) DO UPDATE SET description = EXCLUDED.description;

-- Seed encounter types
INSERT INTO claims_ref.encounter_type(type_code, description) VALUES
  ('INPATIENT', 'Inpatient encounter'),
  ('OUTPATIENT', 'Outpatient encounter'),
  ('EMERGENCY', 'Emergency encounter'),
  ('AMBULATORY', 'Ambulatory encounter'),
  ('ADMISSION', 'Patient admission'),
  ('ARRIVAL', 'Patient arrival'),
  ('REGISTRATION', 'Patient registration'),
  ('DISCHARGE', 'Patient discharge'),
  ('DEPARTURE', 'Patient departure'),
  ('COMPLETION', 'Service completion')
ON CONFLICT (type_code) DO UPDATE SET description = EXCLUDED.description;

-- Seed resubmission types
INSERT INTO claims_ref.resubmission_type(type_code, description) VALUES
  ('correction','Correction'),
  ('internal complaint','Internal complaint'),
  ('legacy','Legacy'),
  ('reconciliation','Reconciliation')
ON CONFLICT (type_code) DO UPDATE SET description = EXCLUDED.description;

-- ==========================================================================================================
-- SECTION 10: BOOTSTRAP STATUS
-- ==========================================================================================================

CREATE TABLE IF NOT EXISTS claims_ref.bootstrap_status (
  id              BIGSERIAL PRIMARY KEY,
  bootstrap_name  TEXT NOT NULL UNIQUE,
  completed_at    TIMESTAMPTZ DEFAULT NOW(),
  version         TEXT DEFAULT '1.0',
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE claims_ref.bootstrap_status IS 'Tracks completion status of one-time bootstrap operations';
COMMENT ON COLUMN claims_ref.bootstrap_status.bootstrap_name IS 'Unique identifier for the bootstrap operation';
COMMENT ON COLUMN claims_ref.bootstrap_status.completed_at IS 'Timestamp when bootstrap completed successfully';
COMMENT ON COLUMN claims_ref.bootstrap_status.version IS 'Version of the bootstrap data/process';

CREATE INDEX IF NOT EXISTS idx_bootstrap_status_name ON claims_ref.bootstrap_status(bootstrap_name);
CREATE INDEX IF NOT EXISTS idx_bootstrap_status_completed ON claims_ref.bootstrap_status(completed_at);

-- ==========================================================================================================
-- SECTION 11: FOREIGN KEY CONSTRAINTS
-- ==========================================================================================================

-- Add foreign key constraints for reference data relationships
DO $$
BEGIN
  -- Claim reference data FKs
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_claim_payer_ref') THEN
    ALTER TABLE claims.claim ADD CONSTRAINT fk_claim_payer_ref FOREIGN KEY (payer_ref_id) REFERENCES claims_ref.payer(id);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_claim_provider_ref') THEN
    ALTER TABLE claims.claim ADD CONSTRAINT fk_claim_provider_ref FOREIGN KEY (provider_ref_id) REFERENCES claims_ref.provider(id);
  END IF;
  
  -- Encounter reference data FKs
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_encounter_facility_ref') THEN
    ALTER TABLE claims.encounter ADD CONSTRAINT fk_encounter_facility_ref FOREIGN KEY (facility_ref_id) REFERENCES claims_ref.facility(id);
  END IF;
  
  -- Activity reference data FKs
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_activity_clinician_ref') THEN
    ALTER TABLE claims.activity ADD CONSTRAINT fk_activity_clinician_ref FOREIGN KEY (clinician_ref_id) REFERENCES claims_ref.clinician(id);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_activity_code_ref') THEN
    ALTER TABLE claims.activity ADD CONSTRAINT fk_activity_code_ref FOREIGN KEY (activity_code_ref_id) REFERENCES claims_ref.activity_code(id);
  END IF;
  
  -- Diagnosis reference data FKs
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_diagnosis_code_ref') THEN
    ALTER TABLE claims.diagnosis ADD CONSTRAINT fk_diagnosis_code_ref FOREIGN KEY (diagnosis_code_ref_id) REFERENCES claims_ref.diagnosis_code(id);
  END IF;
  
  -- Remittance claim reference data FKs
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_remittance_denial_ref') THEN
    ALTER TABLE claims.remittance_activity ADD CONSTRAINT fk_remittance_activity_denial_ref FOREIGN KEY (denial_code_ref_id) REFERENCES claims_ref.denial_code(id);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_remittance_payer_ref') THEN
    ALTER TABLE claims.remittance_claim ADD CONSTRAINT fk_remittance_payer_ref FOREIGN KEY (payer_ref_id) REFERENCES claims_ref.payer(id);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_remittance_provider_ref') THEN
    ALTER TABLE claims.remittance_claim ADD CONSTRAINT fk_remittance_provider_ref FOREIGN KEY (provider_ref_id) REFERENCES claims_ref.provider(id);
  END IF;
  
  -- Remittance activity reference data FKs
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_remittance_activity_code_ref') THEN
    ALTER TABLE claims.remittance_activity ADD CONSTRAINT fk_remittance_activity_code_ref FOREIGN KEY (activity_code_ref_id) REFERENCES claims_ref.activity_code(id);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_remittance_activity_clinician_ref') THEN
    ALTER TABLE claims.remittance_activity ADD CONSTRAINT fk_remittance_activity_clinician_ref FOREIGN KEY (clinician_ref_id) REFERENCES claims_ref.clinician(id);
  END IF;
END$$;

-- ==========================================================================================================
-- SECTION 12: ADDITIONAL INDEXES FOR PERFORMANCE
-- ==========================================================================================================

-- Indexes for reference data foreign keys
CREATE INDEX IF NOT EXISTS idx_claim_payer_ref ON claims.claim(payer_ref_id);
CREATE INDEX IF NOT EXISTS idx_claim_provider_ref ON claims.claim(provider_ref_id);
CREATE INDEX IF NOT EXISTS idx_encounter_facility_ref ON claims.encounter(facility_ref_id);
CREATE INDEX IF NOT EXISTS idx_activity_clinician_ref ON claims.activity(clinician_ref_id);
CREATE INDEX IF NOT EXISTS idx_activity_code_ref ON claims.activity(activity_code_ref_id);
CREATE INDEX IF NOT EXISTS idx_diagnosis_code_ref ON claims.diagnosis(diagnosis_code_ref_id);
CREATE INDEX IF NOT EXISTS idx_remittance_activity_denial_ref ON claims.remittance_activity(denial_code_ref_id);
CREATE INDEX IF NOT EXISTS idx_remittance_activity_clinician_ref ON claims.remittance_activity(clinician_ref_id);
CREATE INDEX IF NOT EXISTS idx_remittance_payer_ref ON claims.remittance_claim(payer_ref_id);
CREATE INDEX IF NOT EXISTS idx_remittance_provider_ref ON claims.remittance_claim(provider_ref_id);

-- ==========================================================================================================
-- SECTION 13: PERMISSIONS AND GRANTS
-- ==========================================================================================================

-- Grant permissions to claims_user role
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA claims_ref TO claims_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA claims_ref TO claims_user;

-- ==========================================================================================================
-- END OF REFERENCE DATA TABLES
-- ==========================================================================================================