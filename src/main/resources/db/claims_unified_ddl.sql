-- ==========================================================================================================
-- CLAIMS PROCESSING SYSTEM - UNIFIED DDL
-- ==========================================================================================================
-- 
-- Purpose: Complete database schema for claims processing system
-- Version: 2.0
-- Date: 2025-09-17
-- 
-- This DDL creates a comprehensive database schema for processing healthcare claims including:
-- - Raw XML ingestion and storage
-- - Claim submission processing
-- - Remittance advice processing
-- - Reference data management
-- - DHPO integration configuration
-- - Audit trails and monitoring
--
-- Architecture:
-- - Single Source of Truth (SSOT) for raw XML data
-- - Normalized relational model for processed data
-- - Comprehensive reference data management
-- - Secure credential storage with encryption
-- - Event-driven audit trails
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: EXTENSIONS AND SCHEMAS
-- ==========================================================================================================

-- Required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;     -- Text similarity and trigram indexes
CREATE EXTENSION IF NOT EXISTS citext;      -- Case-insensitive text type
CREATE EXTENSION IF NOT EXISTS pgcrypto;    -- Cryptographic functions

-- Schema creation
CREATE SCHEMA IF NOT EXISTS claims;         -- Main claims processing schema
CREATE SCHEMA IF NOT EXISTS claims_ref;     -- Reference data schema
CREATE SCHEMA IF NOT EXISTS auth;           -- Authentication schema (reserved)

-- ==========================================================================================================
-- SECTION 2: ROLES AND PERMISSIONS
-- ==========================================================================================================

-- Application role for runtime operations
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'claims_user') THEN
    CREATE ROLE claims_user LOGIN;
  END IF;
END$$ LANGUAGE plpgsql;

-- ==========================================================================================================
-- SECTION 3: DOMAINS AND ENUMS
-- ==========================================================================================================

-- Centralized event type domain
-- 1 = SUBMISSION, 2 = RESUBMISSION, 3 = REMITTANCE
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'claim_event_type') THEN
    EXECUTE 'CREATE DOMAIN claims.claim_event_type AS smallint CHECK (value IN (1,2,3))';
  END IF;
END$$;

-- ==========================================================================================================
-- SECTION 4: UTILITY FUNCTIONS
-- ==========================================================================================================

-- Audit helper function for updated_at timestamps
CREATE OR REPLACE FUNCTION claims.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW IS DISTINCT FROM OLD THEN
    NEW.updated_at := NOW();
  END IF;
  RETURN NEW;
END$$;

-- ==========================================================================================================
-- SECTION 5: REFERENCE DATA SCHEMA (claims_ref)
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- 5.1 FACILITIES
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.facility (
  id             BIGSERIAL PRIMARY KEY,
  facility_code  TEXT NOT NULL UNIQUE,                    -- External FacilityID (e.g., DHA-F-0045446)
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

-- ----------------------------------------------------------------------------------------------------------
-- 5.2 PAYERS
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.payer (
  id          BIGSERIAL PRIMARY KEY,
  payer_code  TEXT NOT NULL UNIQUE,                      -- External PayerID (e.g., INS025)
  name        TEXT,
  status      TEXT DEFAULT 'ACTIVE',
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE claims_ref.payer IS 'Master list of Payers (Claim.PayerID)';
COMMENT ON COLUMN claims_ref.payer.payer_code IS 'External PayerID';

CREATE INDEX IF NOT EXISTS idx_payer_code ON claims_ref.payer(payer_code);
CREATE INDEX IF NOT EXISTS idx_payer_status ON claims_ref.payer(status);

-- ----------------------------------------------------------------------------------------------------------
-- 5.3 PROVIDERS
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

-- ----------------------------------------------------------------------------------------------------------
-- 5.4 CLINICIANS
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.clinician (
  id              BIGSERIAL PRIMARY KEY,
  clinician_code  TEXT NOT NULL UNIQUE,                  -- External ClinicianID (e.g., DHA-P-0228312)
  name            TEXT,
  specialty       TEXT,
  status          TEXT DEFAULT 'ACTIVE',
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE claims_ref.clinician IS 'Master list of clinicians (Activity.Clinician)';

CREATE INDEX IF NOT EXISTS idx_clinician_code ON claims_ref.clinician(clinician_code);
CREATE INDEX IF NOT EXISTS idx_clinician_status ON claims_ref.clinician(status);

-- ----------------------------------------------------------------------------------------------------------
-- 5.5 ACTIVITY CODES
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.activity_code (
  id           BIGSERIAL PRIMARY KEY,
  code         TEXT NOT NULL,
  code_system  TEXT NOT NULL DEFAULT 'LOCAL',           -- CPT/HCPCS/LOCAL/etc.
  description  TEXT,
  status       TEXT DEFAULT 'ACTIVE',
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_activity_code UNIQUE (code, code_system)
);

COMMENT ON TABLE claims_ref.activity_code IS 'Service/procedure codes used in Activity.Code';

CREATE INDEX IF NOT EXISTS idx_activity_code_lookup ON claims_ref.activity_code(code, code_system);
CREATE INDEX IF NOT EXISTS idx_activity_code_status ON claims_ref.activity_code(status);

-- ----------------------------------------------------------------------------------------------------------
-- 5.6 DIAGNOSIS CODES
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

-- ----------------------------------------------------------------------------------------------------------
-- 5.7 DENIAL CODES
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.denial_code (
  id          BIGSERIAL PRIMARY KEY,
  code        TEXT NOT NULL UNIQUE,
  description TEXT,
  payer_code  TEXT,                                       -- Optional scope by payer
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE claims_ref.denial_code IS 'Adjudication denial codes; optionally scoped by payer_code';

CREATE INDEX IF NOT EXISTS idx_denial_code_lookup ON claims_ref.denial_code(code);
CREATE INDEX IF NOT EXISTS idx_denial_code_payer ON claims_ref.denial_code(payer_code);

-- ----------------------------------------------------------------------------------------------------------
-- 5.8 OBSERVATION DICTIONARIES
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.observation_type (
  obs_type     TEXT PRIMARY KEY,                          -- LOINC/Text/File/Universal Dental/Financial/Grouping/ERX/Result
  description  TEXT
);

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

CREATE TABLE IF NOT EXISTS claims_ref.observation_value_type (
  value_type   TEXT PRIMARY KEY,                          -- Curated unit/value type (optional)
  description  TEXT
);

CREATE TABLE IF NOT EXISTS claims_ref.observation_code (
  id          BIGSERIAL PRIMARY KEY,
  code        TEXT NOT NULL UNIQUE,                       -- Curated short-hand like A1C/BPS/etc.
  description TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------------------------------------------------
-- 5.9 CONTRACT PACKAGES
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.contract_package (
  package_name TEXT PRIMARY KEY,
  description  TEXT,
  status       TEXT DEFAULT 'ACTIVE',
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------------------------------------------------
-- 5.10 TYPE DICTIONARIES
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims_ref.activity_type (
  type_code   TEXT PRIMARY KEY,
  description TEXT
);

CREATE TABLE IF NOT EXISTS claims_ref.encounter_type (
  type_code   TEXT PRIMARY KEY,
  description TEXT
);

CREATE TABLE IF NOT EXISTS claims_ref.encounter_start_type (
  type_code   TEXT PRIMARY KEY,
  description TEXT
);

CREATE TABLE IF NOT EXISTS claims_ref.encounter_end_type (
  type_code   TEXT PRIMARY KEY,
  description TEXT
);

-- ==========================================================================================================
-- SECTION 6: MAIN CLAIMS SCHEMA (claims)
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- 6.1 RAW XML INGESTION (Single Source of Truth)
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.ingestion_file (
  id                     BIGSERIAL PRIMARY KEY,
  file_id                TEXT NOT NULL,  
  file_name              TEXT NOT NULL,                                       -- External idempotency key
  root_type              SMALLINT NOT NULL CHECK (root_type IN (1,2)),        -- 1=Submission, 2=Remittance
  -- XSD Header (common to both schemas)
  sender_id              TEXT NOT NULL,
  receiver_id            TEXT NOT NULL,
  transaction_date       TIMESTAMPTZ NOT NULL,
  record_count_declared  INTEGER NOT NULL CHECK (record_count_declared >= 0),
  disposition_flag       TEXT NOT NULL,
  -- Raw XML storage
  xml_bytes              BYTEA NOT NULL,
  -- Audit fields
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_ingestion_file UNIQUE (file_id, file_name)
);

COMMENT ON TABLE claims.ingestion_file IS 'SSOT: Raw XML + XSD Header; duplicate files rejected by unique(file_id)';
COMMENT ON COLUMN claims.ingestion_file.root_type IS '1=Claim.Submission, 2=Remittance.Advice';
COMMENT ON COLUMN claims.ingestion_file.xml_bytes IS 'Raw XML bytes (SSOT)';

CREATE INDEX IF NOT EXISTS idx_ingestion_file_root_type ON claims.ingestion_file(root_type);
CREATE INDEX IF NOT EXISTS idx_ingestion_file_sender ON claims.ingestion_file(sender_id);
CREATE INDEX IF NOT EXISTS idx_ingestion_file_receiver ON claims.ingestion_file(receiver_id);
CREATE INDEX IF NOT EXISTS idx_ingestion_file_transaction_date ON claims.ingestion_file(transaction_date);

CREATE TRIGGER trg_ingestion_file_updated_at
  BEFORE UPDATE ON claims.ingestion_file
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- Ingestion error tracking  
CREATE TABLE IF NOT EXISTS claims.ingestion_error (
  id                 BIGSERIAL PRIMARY KEY,
  ingestion_file_id  BIGINT NOT NULL REFERENCES claims.ingestion_file(id) ON DELETE CASCADE,
  stage              TEXT NOT NULL,
  object_type        TEXT,
  object_key         TEXT,
  error_code         TEXT,
  error_message      TEXT NOT NULL,
  stack_excerpt      TEXT,
  retryable          BOOLEAN NOT NULL DEFAULT FALSE,
  occurred_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.ingestion_error IS 'Error tracking during file ingestion';

CREATE INDEX IF NOT EXISTS idx_ingestion_error_file ON claims.ingestion_error(ingestion_file_id);
CREATE INDEX IF NOT EXISTS idx_ingestion_error_stage ON claims.ingestion_error(stage);
CREATE INDEX IF NOT EXISTS idx_ingestion_error_time ON claims.ingestion_error(occurred_at);
CREATE INDEX IF NOT EXISTS idx_ingestion_error_retryable ON claims.ingestion_error(retryable);

-- ----------------------------------------------------------------------------------------------------------
-- 6.2 CANONICAL CLAIM KEY
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.claim_key (
  id          BIGSERIAL PRIMARY KEY,
  claim_id    TEXT NOT NULL UNIQUE,                      -- Canonical business ID
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.claim_key IS 'Canonical claim identifier (Claim/ID appears in both roots)';

CREATE INDEX IF NOT EXISTS idx_claim_key_claim_id ON claims.claim_key(claim_id);

CREATE TRIGGER trg_claim_key_updated_at
  BEFORE UPDATE ON claims.claim_key
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- ----------------------------------------------------------------------------------------------------------
-- 6.3 SUBMISSION PROCESSING
-- ----------------------------------------------------------------------------------------------------------

-- Submission grouping (one per file)
CREATE TABLE IF NOT EXISTS claims.submission (
  id                 BIGSERIAL PRIMARY KEY,
  ingestion_file_id  BIGINT NOT NULL REFERENCES claims.ingestion_file(id) ON DELETE RESTRICT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  tx_at              TIMESTAMPTZ NOT NULL
);

COMMENT ON TABLE claims.submission IS 'Submission grouping (one per ingestion file)';

CREATE INDEX IF NOT EXISTS idx_submission_file ON claims.submission(ingestion_file_id);

CREATE TRIGGER trg_submission_updated_at
  BEFORE UPDATE ON claims.submission
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- Core submission claim
CREATE TABLE IF NOT EXISTS claims.claim (
  id                 BIGSERIAL PRIMARY KEY,
  claim_key_id       BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE RESTRICT,
  submission_id      BIGINT NOT NULL REFERENCES claims.submission(id) ON DELETE RESTRICT,
  -- Claim-level fields (XSD)
  id_payer           TEXT,                                                 -- Optional
  member_id          TEXT,                                                 -- Optional
  payer_id           TEXT NOT NULL,
  provider_id        TEXT NOT NULL,
  emirates_id_number TEXT NOT NULL,
  gross              NUMERIC(14,2) NOT NULL CHECK (gross >= 0),
  patient_share      NUMERIC(14,2) NOT NULL CHECK (patient_share >= 0),
  net                NUMERIC(14,2) NOT NULL CHECK (net >= 0),
  comments           TEXT,                                                 -- Store comments if found
  -- Reference data foreign keys
  payer_ref_id       BIGINT,
  provider_ref_id    BIGINT,
  -- Audit fields
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  tx_at              TIMESTAMPTZ NOT NULL,                                 -- Transaction timestamp
  -- Idempotency constraints
  CONSTRAINT uq_claim_per_key UNIQUE (claim_key_id),                       -- One claim per key globally
  CONSTRAINT uq_claim_submission_claimkey UNIQUE (submission_id, claim_key_id)
);

COMMENT ON TABLE claims.claim IS 'Core submission claim; duplicates without <Resubmission> are ignored (one row per claim_key_id)';

CREATE INDEX IF NOT EXISTS idx_claim_claim_key ON claims.claim(claim_key_id);
CREATE INDEX IF NOT EXISTS idx_claim_payer ON claims.claim(payer_id);
CREATE INDEX IF NOT EXISTS idx_claim_provider ON claims.claim(provider_id);
CREATE INDEX IF NOT EXISTS idx_claim_member ON claims.claim(member_id);
CREATE INDEX IF NOT EXISTS idx_claim_emirates ON claims.claim(emirates_id_number);
CREATE INDEX IF NOT EXISTS idx_claim_has_comments ON claims.claim((comments IS NOT NULL));

CREATE TRIGGER trg_claim_updated_at
  BEFORE UPDATE ON claims.claim
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- Encounter (submission)
CREATE TABLE IF NOT EXISTS claims.encounter (
  id                    BIGSERIAL PRIMARY KEY,
  claim_id              BIGINT NOT NULL REFERENCES claims.claim(id) ON DELETE CASCADE,
  facility_id           TEXT NOT NULL,
  type                  TEXT NOT NULL,
  patient_id            TEXT NOT NULL,
  start_at              TIMESTAMPTZ NOT NULL,
  end_at                TIMESTAMPTZ,
  start_type            TEXT,
  end_type              TEXT,
  transfer_source       TEXT,
  transfer_destination  TEXT,
  facility_ref_id       BIGINT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.encounter IS 'Encounter details for submission claims';

CREATE INDEX IF NOT EXISTS idx_encounter_claim ON claims.encounter(claim_id);
CREATE INDEX IF NOT EXISTS idx_encounter_facility ON claims.encounter(facility_id);
CREATE INDEX IF NOT EXISTS idx_encounter_patient ON claims.encounter(patient_id);
CREATE INDEX IF NOT EXISTS idx_encounter_start ON claims.encounter(start_at);

CREATE TRIGGER trg_encounter_updated_at
  BEFORE UPDATE ON claims.encounter
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- Diagnosis (submission)
CREATE TABLE IF NOT EXISTS claims.diagnosis (
  id                    BIGSERIAL PRIMARY KEY,
  claim_id              BIGINT NOT NULL REFERENCES claims.claim(id) ON DELETE CASCADE,
  diag_type             TEXT NOT NULL,
  code                  TEXT NOT NULL,
  diagnosis_code_ref_id BIGINT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.diagnosis IS 'Diagnosis codes for submission claims';

CREATE INDEX IF NOT EXISTS idx_diagnosis_claim ON claims.diagnosis(claim_id);
CREATE INDEX IF NOT EXISTS idx_diagnosis_code ON claims.diagnosis(code);
CREATE INDEX IF NOT EXISTS idx_diagnosis_type ON claims.diagnosis(diag_type);

CREATE TRIGGER trg_diagnosis_updated_at
  BEFORE UPDATE ON claims.diagnosis
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- Activity (submission)
CREATE TABLE IF NOT EXISTS claims.activity (
  id                    BIGSERIAL PRIMARY KEY,
  claim_id              BIGINT NOT NULL REFERENCES claims.claim(id) ON DELETE CASCADE,
  activity_id           TEXT NOT NULL,
  start_at              TIMESTAMPTZ NOT NULL,
  type                  TEXT NOT NULL,
  code                  TEXT NOT NULL,
  quantity              NUMERIC(14,2) NOT NULL CHECK (quantity >= 0),
  net                   NUMERIC(14,2) NOT NULL CHECK (net >= 0),
  clinician             TEXT NOT NULL,
  prior_authorization_id TEXT,
  clinician_ref_id      BIGINT,
  activity_code_ref_id  BIGINT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_activity_claim_id UNIQUE (claim_id, activity_id)
);

COMMENT ON TABLE claims.activity IS 'Activities for submission claims';

CREATE INDEX IF NOT EXISTS idx_activity_claim ON claims.activity(claim_id);
CREATE INDEX IF NOT EXISTS idx_activity_code ON claims.activity(code);
CREATE INDEX IF NOT EXISTS idx_activity_clinician ON claims.activity(clinician);
CREATE INDEX IF NOT EXISTS idx_activity_start ON claims.activity(start_at);

CREATE TRIGGER trg_activity_updated_at
  BEFORE UPDATE ON claims.activity
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- Observation (submission)
CREATE TABLE IF NOT EXISTS claims.observation (
  id          BIGSERIAL PRIMARY KEY,
  activity_id BIGINT NOT NULL REFERENCES claims.activity(id) ON DELETE CASCADE,
  obs_type    TEXT NOT NULL,
  obs_code    TEXT NOT NULL,
  value_text  TEXT,
  value_type  TEXT,
  file_bytes  BYTEA,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.observation IS 'Observations for submission activities';

CREATE INDEX IF NOT EXISTS idx_observation_activity ON claims.observation(activity_id);
CREATE INDEX IF NOT EXISTS idx_observation_type ON claims.observation(obs_type);
CREATE INDEX IF NOT EXISTS idx_observation_code ON claims.observation(obs_code);

CREATE TRIGGER trg_observation_updated_at
  BEFORE UPDATE ON claims.observation
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- Resubmission (submission)
CREATE TABLE IF NOT EXISTS claims.resubmission (
  id                    BIGSERIAL PRIMARY KEY,
  claim_id              BIGINT NOT NULL REFERENCES claims.claim(id) ON DELETE CASCADE,
  resubmission_id       TEXT NOT NULL,
  original_claim_id     TEXT NOT NULL,
  reason                TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_resubmission_claim_id UNIQUE (claim_id, resubmission_id)
);

COMMENT ON TABLE claims.resubmission IS 'Resubmission information for claims';

CREATE INDEX IF NOT EXISTS idx_resubmission_claim ON claims.resubmission(claim_id);
CREATE INDEX IF NOT EXISTS idx_resubmission_original ON claims.resubmission(original_claim_id);

CREATE TRIGGER trg_resubmission_updated_at
  BEFORE UPDATE ON claims.resubmission
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- Contract (submission)
CREATE TABLE IF NOT EXISTS claims.contract (
  id              BIGSERIAL PRIMARY KEY,
  claim_id        BIGINT NOT NULL REFERENCES claims.claim(id) ON DELETE CASCADE,
  package_name    TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_contract_claim_id UNIQUE (claim_id, package_name)
);

COMMENT ON TABLE claims.contract IS 'Contract packages for claims';

CREATE INDEX IF NOT EXISTS idx_contract_claim ON claims.contract(claim_id);
CREATE INDEX IF NOT EXISTS idx_contract_package ON claims.contract(package_name);

CREATE TRIGGER trg_contract_updated_at
  BEFORE UPDATE ON claims.contract
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- ----------------------------------------------------------------------------------------------------------
-- 6.4 REMITTANCE PROCESSING
-- ----------------------------------------------------------------------------------------------------------

-- Remittance grouping (one per file)
CREATE TABLE IF NOT EXISTS claims.remittance (
  id                 BIGSERIAL PRIMARY KEY,
  ingestion_file_id  BIGINT NOT NULL REFERENCES claims.ingestion_file(id) ON DELETE RESTRICT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  tx_at              TIMESTAMPTZ NOT NULL
);

COMMENT ON TABLE claims.remittance IS 'Remittance grouping (one per ingestion file)';

CREATE INDEX IF NOT EXISTS idx_remittance_file ON claims.remittance(ingestion_file_id);

CREATE TRIGGER trg_remittance_updated_at
  BEFORE UPDATE ON claims.remittance
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- Remittance claim
CREATE TABLE IF NOT EXISTS claims.remittance_claim (
  id                BIGSERIAL PRIMARY KEY,
  claim_key_id      BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE RESTRICT,
  remittance_id     BIGINT NOT NULL REFERENCES claims.remittance(id) ON DELETE RESTRICT,
  id_payer          TEXT NOT NULL,
  provider_id       TEXT,
  denial_code       TEXT,
  payment_reference TEXT NOT NULL,
  date_settlement   TIMESTAMPTZ,
  facility_id       TEXT,
  denial_code_ref_id BIGINT,
  payer_ref_id      BIGINT,
  provider_ref_id   BIGINT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_remittance_claim_key UNIQUE (remittance_id, claim_key_id)
);

COMMENT ON TABLE claims.remittance_claim IS 'Remittance claims with payment information';

CREATE INDEX IF NOT EXISTS idx_remittance_claim_key ON claims.remittance_claim(claim_key_id);
CREATE INDEX IF NOT EXISTS idx_remittance_claim_payer ON claims.remittance_claim(id_payer);
CREATE INDEX IF NOT EXISTS idx_remittance_claim_provider ON claims.remittance_claim(provider_id);
CREATE INDEX IF NOT EXISTS idx_remittance_claim_payment_ref ON claims.remittance_claim(payment_reference);

CREATE TRIGGER trg_remittance_claim_updated_at
  BEFORE UPDATE ON claims.remittance_claim
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- Remittance activity
CREATE TABLE IF NOT EXISTS claims.remittance_activity (
  id                BIGSERIAL PRIMARY KEY,
  remittance_claim_id BIGINT NOT NULL REFERENCES claims.remittance_claim(id) ON DELETE CASCADE,
  activity_id       TEXT NOT NULL,
  start_at          TIMESTAMPTZ NOT NULL,
  type              TEXT NOT NULL,
  code              TEXT NOT NULL,
  quantity          NUMERIC(14,2) NOT NULL CHECK (quantity >= 0),
  net               NUMERIC(14,2) NOT NULL CHECK (net >= 0),
  list_price        NUMERIC(14,2),
  clinician         TEXT NOT NULL,
  prior_authorization_id TEXT,
  gross             NUMERIC(14,2),
  patient_share     NUMERIC(14,2),
  payment_amount    NUMERIC(14,2) NOT NULL CHECK (payment_amount >= 0),
  denial_code       TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_remittance_activity_claim_id UNIQUE (remittance_claim_id, activity_id)
);

COMMENT ON TABLE claims.remittance_activity IS 'Remittance activities with payment details';

CREATE INDEX IF NOT EXISTS idx_remittance_activity_claim ON claims.remittance_activity(remittance_claim_id);
CREATE INDEX IF NOT EXISTS idx_remittance_activity_code ON claims.remittance_activity(code);
CREATE INDEX IF NOT EXISTS idx_remittance_activity_clinician ON claims.remittance_activity(clinician);

CREATE TRIGGER trg_remittance_activity_updated_at
  BEFORE UPDATE ON claims.remittance_activity
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- ----------------------------------------------------------------------------------------------------------
-- 6.5 ATTACHMENTS
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.claim_attachment (
  id          BIGSERIAL PRIMARY KEY,
  claim_id    BIGINT NOT NULL REFERENCES claims.claim(id) ON DELETE CASCADE,
  attachment_id TEXT NOT NULL,
  type        TEXT NOT NULL,
  code        TEXT NOT NULL,
  file_bytes  BYTEA NOT NULL,
  file_size   BIGINT NOT NULL CHECK (file_size >= 0),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_attachment_claim_id UNIQUE (claim_id, attachment_id)
);

COMMENT ON TABLE claims.claim_attachment IS 'Binary attachments for claims';

CREATE INDEX IF NOT EXISTS idx_attachment_claim ON claims.claim_attachment(claim_id);
CREATE INDEX IF NOT EXISTS idx_attachment_type ON claims.claim_attachment(type);
CREATE INDEX IF NOT EXISTS idx_attachment_code ON claims.claim_attachment(code);

CREATE TRIGGER trg_attachment_updated_at
  BEFORE UPDATE ON claims.claim_attachment
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- ----------------------------------------------------------------------------------------------------------
-- 6.6 EVENT TRACKING AND AUDIT
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.claim_event (
  id                 BIGSERIAL PRIMARY KEY,
  claim_key_id       BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE RESTRICT,
  ingestion_file_id  BIGINT REFERENCES claims.ingestion_file(id) ON DELETE SET NULL,
  event_time         TIMESTAMPTZ NOT NULL,
  type               SMALLINT NOT NULL,
  submission_id      BIGINT REFERENCES claims.submission(id) ON DELETE SET NULL,
  remittance_id      BIGINT REFERENCES claims.remittance(id) ON DELETE SET NULL,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.claim_event IS 'Event tracking for claims (submission, resubmission, remittance)';

CREATE INDEX IF NOT EXISTS idx_claim_event_key ON claims.claim_event(claim_key_id);
CREATE INDEX IF NOT EXISTS idx_claim_event_type ON claims.claim_event(type);
CREATE INDEX IF NOT EXISTS idx_claim_event_time ON claims.claim_event(event_time);
CREATE INDEX IF NOT EXISTS idx_claim_event_created ON claims.claim_event(created_at);

-- Claim resubmission (1:1 with RESUBMISSION event)
CREATE TABLE IF NOT EXISTS claims.claim_resubmission (
  id                 BIGSERIAL PRIMARY KEY,
  claim_event_id     BIGINT NOT NULL REFERENCES claims.claim_event(id) ON DELETE CASCADE,
  resubmission_type  TEXT NOT NULL,
  comment            TEXT NOT NULL,
  attachment         BYTEA,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.claim_resubmission IS 'Resubmission information linked to claim events';

CREATE INDEX IF NOT EXISTS idx_claim_resubmission_event ON claims.claim_resubmission(claim_event_id);
CREATE INDEX IF NOT EXISTS idx_claim_resubmission_original ON claims.claim_resubmission(original_claim_id);

CREATE TRIGGER trg_claim_resubmission_updated_at
  BEFORE UPDATE ON claims.claim_resubmission
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- Activity snapshots at event time
CREATE TABLE IF NOT EXISTS claims.claim_event_activity (
  id                               BIGSERIAL PRIMARY KEY,
  claim_event_id                   BIGINT NOT NULL REFERENCES claims.claim_event(id) ON DELETE CASCADE,
  activity_id_ref                  BIGINT REFERENCES claims.activity(id) ON DELETE SET NULL,
  remittance_activity_id_ref       BIGINT REFERENCES claims.remittance_activity(id) ON DELETE SET NULL,
  activity_id_at_event             TEXT NOT NULL,
  start_at_event                   TIMESTAMPTZ NOT NULL,
  type_at_event                    TEXT NOT NULL,
  code_at_event                    TEXT NOT NULL,
  quantity_at_event                NUMERIC(14,2) NOT NULL CHECK (quantity_at_event >= 0),
  net_at_event                     NUMERIC(14,2) NOT NULL CHECK (net_at_event >= 0),
  clinician_at_event               TEXT NOT NULL,
  prior_authorization_id_at_event  TEXT,
  list_price_at_event              NUMERIC(14,2),
  gross_at_event                   NUMERIC(14,2),
  patient_share_at_event           NUMERIC(14,2),
  payment_amount_at_event          NUMERIC(14,2),
  denial_code_at_event             TEXT,
  created_at                       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.claim_event_activity IS 'Activity snapshots at the time of claim events';

CREATE UNIQUE INDEX IF NOT EXISTS uq_cea_event_activity ON claims.claim_event_activity (claim_event_id, activity_id_at_event);
CREATE INDEX IF NOT EXISTS idx_cea_event ON claims.claim_event_activity(claim_event_id);

-- Observations tied to an event snapshot
CREATE TABLE IF NOT EXISTS claims.event_observation (
  id                         BIGSERIAL PRIMARY KEY,
  claim_event_activity_id    BIGINT NOT NULL REFERENCES claims.claim_event_activity(id) ON DELETE CASCADE,
  obs_type                   TEXT NOT NULL,
  obs_code                   TEXT NOT NULL,
  value_text                 TEXT,
  value_type                 TEXT,
  file_bytes                 BYTEA,                                          -- For FILE type observations
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.event_observation IS 'Observations tied to claim event activity snapshots';

CREATE INDEX IF NOT EXISTS idx_event_obs_cea ON claims.event_observation(claim_event_activity_id);

-- Derived status timeline
CREATE TABLE IF NOT EXISTS claims.claim_status_timeline (
  id             BIGSERIAL PRIMARY KEY,
  claim_key_id   BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE CASCADE,
  status         SMALLINT NOT NULL,                                          -- 1=SUBMITTED,2=RESUBMITTED,3=PAID,4=PARTIALLY_PAID,5=REJECTED,6=UNKNOWN
  status_time    TIMESTAMPTZ NOT NULL,                                       -- Should reflect transaction_date from submission or remittance
  claim_event_id BIGINT REFERENCES claims.claim_event(id) ON DELETE SET NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.claim_status_timeline IS 'Derived status timeline for claims';

CREATE INDEX IF NOT EXISTS idx_cst_claim_key_time ON claims.claim_status_timeline(claim_key_id, status_time);

-- ----------------------------------------------------------------------------------------------------------
-- 6.7 INGESTION MONITORING
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.ingestion_run (
  id                 BIGSERIAL PRIMARY KEY,
  started_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at           TIMESTAMPTZ,
  profile            TEXT NOT NULL,
  fetcher_name       TEXT NOT NULL,
  acker_name         TEXT,
  poll_reason        TEXT,
  files_discovered   INTEGER NOT NULL DEFAULT 0,
  files_pulled       INTEGER NOT NULL DEFAULT 0,
  files_processed_ok INTEGER NOT NULL DEFAULT 0,
  files_failed       INTEGER NOT NULL DEFAULT 0,
  files_already      INTEGER NOT NULL DEFAULT 0,
  acks_sent          INTEGER NOT NULL DEFAULT 0
);

COMMENT ON TABLE claims.ingestion_run IS 'Orchestrator run summary (per poll)';

CREATE INDEX IF NOT EXISTS idx_ingestion_run_started ON claims.ingestion_run(started_at);
CREATE INDEX IF NOT EXISTS idx_ingestion_run_profile ON claims.ingestion_run(profile);

-- Per-file audit + counters
CREATE TABLE IF NOT EXISTS claims.ingestion_file_audit (
  id                          BIGSERIAL PRIMARY KEY,
  ingestion_run_id            BIGINT NOT NULL REFERENCES claims.ingestion_run(id) ON DELETE CASCADE,
  ingestion_file_id           BIGINT NOT NULL REFERENCES claims.ingestion_file(id) ON DELETE CASCADE,
  status                      SMALLINT NOT NULL,                            -- 0=ALREADY,1=OK,2=FAIL
  reason                      TEXT,
  error_class                 TEXT,
  error_message               TEXT,
  validation_ok               BOOLEAN NOT NULL DEFAULT FALSE,
  header_sender_id            TEXT NOT NULL,
  header_receiver_id          TEXT NOT NULL,
  header_transaction_date     TIMESTAMPTZ NOT NULL,
  header_record_count         INTEGER NOT NULL,
  header_disposition_flag     TEXT NOT NULL,
  parsed_claims               INTEGER DEFAULT 0,
  parsed_encounters           INTEGER DEFAULT 0,
  parsed_diagnoses            INTEGER DEFAULT 0,
  parsed_activities           INTEGER DEFAULT 0,
  parsed_observations         INTEGER DEFAULT 0,
  persisted_claims            INTEGER DEFAULT 0,
  persisted_encounters        INTEGER DEFAULT 0,
  persisted_diagnoses         INTEGER DEFAULT 0,
  persisted_activities        INTEGER DEFAULT 0,
  persisted_observations      INTEGER DEFAULT 0,
  parsed_remit_claims         INTEGER DEFAULT 0,
  parsed_remit_activities     INTEGER DEFAULT 0,
  persisted_remit_claims      INTEGER DEFAULT 0,
  persisted_remit_activities  INTEGER DEFAULT 0,
  verification_passed         BOOLEAN DEFAULT FALSE,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.ingestion_file_audit IS 'Per-file audit + counters for ingestion monitoring';

CREATE INDEX IF NOT EXISTS idx_file_audit_run ON claims.ingestion_file_audit(ingestion_run_id);
CREATE INDEX IF NOT EXISTS idx_file_audit_file ON claims.ingestion_file_audit(ingestion_file_id);
CREATE INDEX IF NOT EXISTS idx_file_audit_status ON claims.ingestion_file_audit(status);

CREATE TABLE IF NOT EXISTS claims.ingestion_error (
  id              BIGSERIAL PRIMARY KEY,
  ingestion_file_id BIGINT REFERENCES claims.ingestion_file(id) ON DELETE CASCADE,
  error_class     TEXT NOT NULL,
  error_message   TEXT NOT NULL,
  error_details   JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.ingestion_error IS 'Central error log for ingestion failures';

CREATE INDEX IF NOT EXISTS idx_ingestion_error_file ON claims.ingestion_error(ingestion_file_id);
CREATE INDEX IF NOT EXISTS idx_ingestion_error_class ON claims.ingestion_error(error_class);
CREATE INDEX IF NOT EXISTS idx_ingestion_error_created ON claims.ingestion_error(created_at);

-- ----------------------------------------------------------------------------------------------------------
-- 6.8 VERIFICATION SYSTEM
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.verification_rule (
  id            BIGSERIAL PRIMARY KEY,
  code          TEXT NOT NULL UNIQUE,                                      -- e.g., COUNT_MATCH
  description   TEXT NOT NULL,
  enabled       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.verification_rule IS 'Verification rules for data quality checks';

CREATE INDEX IF NOT EXISTS idx_verification_rule_code ON claims.verification_rule(code);
CREATE INDEX IF NOT EXISTS idx_verification_rule_enabled ON claims.verification_rule(enabled);

CREATE TABLE IF NOT EXISTS claims.verification_run (
  id                  BIGSERIAL PRIMARY KEY,
  ingestion_file_id   BIGINT NOT NULL REFERENCES claims.ingestion_file(id) ON DELETE CASCADE,
  started_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at            TIMESTAMPTZ,
  passed              BOOLEAN,
  failed_rules        INTEGER NOT NULL DEFAULT 0
);

COMMENT ON TABLE claims.verification_run IS 'Verification run for each ingestion file';

CREATE INDEX IF NOT EXISTS idx_ver_run_file ON claims.verification_run(ingestion_file_id);
CREATE INDEX IF NOT EXISTS idx_ver_run_started ON claims.verification_run(started_at);

CREATE TABLE IF NOT EXISTS claims.verification_result (
  id                   BIGSERIAL PRIMARY KEY,
  verification_run_id  BIGINT NOT NULL REFERENCES claims.verification_run(id) ON DELETE CASCADE,
  rule_id              BIGINT NOT NULL REFERENCES claims.verification_rule(id) ON DELETE RESTRICT,
  ok                   BOOLEAN NOT NULL,
  rows_affected        BIGINT,
  sample_json          JSONB,
  message              TEXT,
  executed_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.verification_result IS 'Individual verification rule results';

CREATE INDEX IF NOT EXISTS idx_ver_result_run ON claims.verification_result(verification_run_id, rule_id);

-- ----------------------------------------------------------------------------------------------------------
-- 6.7 CLAIM ATTACHMENTS AND CONTRACTS
-- ----------------------------------------------------------------------------------------------------------

-- Claim attachments
CREATE TABLE IF NOT EXISTS claims.claim_attachment (
  id              BIGSERIAL PRIMARY KEY,
  claim_key_id    BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE CASCADE,
  claim_event_id  BIGINT NOT NULL REFERENCES claims.claim_event(id) ON DELETE CASCADE,
  file_name       TEXT,
  mime_type       TEXT,
  data_base64     BYTEA NOT NULL,
  data_length     INTEGER,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.claim_attachment IS 'File attachments for claims';

CREATE INDEX IF NOT EXISTS idx_claim_attachment_key ON claims.claim_attachment(claim_key_id);
CREATE INDEX IF NOT EXISTS idx_claim_attachment_event ON claims.claim_attachment(claim_event_id);

-- Claim contracts
CREATE TABLE IF NOT EXISTS claims.claim_contract (
  id              BIGSERIAL PRIMARY KEY,
  claim_id        BIGINT NOT NULL REFERENCES claims.claim(id) ON DELETE CASCADE,
  package_name    TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.claim_contract IS 'Contract package information for claims';

CREATE INDEX IF NOT EXISTS idx_claim_contract_claim ON claims.claim_contract(claim_id);

CREATE TRIGGER trg_claim_contract_updated_at
  BEFORE UPDATE ON claims.claim_contract
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- Code discovery audit
CREATE TABLE IF NOT EXISTS claims.code_discovery_audit (
  id                  BIGSERIAL PRIMARY KEY,
  discovered_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  source_table        TEXT NOT NULL,
  code                TEXT NOT NULL,
  code_system         TEXT,
  discovered_by       TEXT NOT NULL DEFAULT 'SYSTEM',
  ingestion_file_id   BIGINT REFERENCES claims.ingestion_file(id) ON DELETE SET NULL,
  claim_external_id   TEXT,
  details             JSONB NOT NULL DEFAULT '{}'
);

COMMENT ON TABLE claims.code_discovery_audit IS 'Audit trail for newly discovered codes during ingestion';

CREATE INDEX IF NOT EXISTS idx_code_discovery_source ON claims.code_discovery_audit(source_table, code);
CREATE INDEX IF NOT EXISTS idx_code_discovery_file ON claims.code_discovery_audit(ingestion_file_id);
CREATE INDEX IF NOT EXISTS idx_code_discovery_time ON claims.code_discovery_audit(discovered_at);

-- ==========================================================================================================
-- SECTION 8: DHPO INTEGRATION CONFIGURATION
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- 8.1 FACILITY DHPO CONFIGURATION
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.facility_dhpo_config (
  id                     BIGSERIAL PRIMARY KEY,
  facility_code          CITEXT NOT NULL,
  facility_name          TEXT NOT NULL,
  -- DHPO endpoints
  endpoint_url           TEXT NOT NULL DEFAULT 'https://dhpo.eclaimlink.ae/ValidateTransactions.asmx',
  endpoint_url_for_erx   TEXT NOT NULL DEFAULT 'https://dhpo.eclaimlink.ae/eRxValidateTransactions.asmx',
  -- App-managed encryption for credentials
  dhpo_username_enc      BYTEA NOT NULL,
  dhpo_password_enc      BYTEA NOT NULL,
  enc_meta_json          JSONB NOT NULL,                    -- {kek_version:int, alg:"AES/GCM", iv:base64, tagBits:int}
  -- Status and audit
  active                 BOOLEAN NOT NULL DEFAULT TRUE,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_facility_dhpo_config UNIQUE (facility_code)
);

COMMENT ON TABLE claims.facility_dhpo_config IS 'Per-facility DHPO endpoints + encrypted credentials (AME)';
COMMENT ON COLUMN claims.facility_dhpo_config.enc_meta_json IS 'Encryption metadata: {"kek_version":int,"alg":"AES/GCM","iv":"b64","tagBits":int}';

CREATE INDEX IF NOT EXISTS idx_dhpo_config_facility ON claims.facility_dhpo_config(facility_code);
CREATE INDEX IF NOT EXISTS idx_dhpo_config_active ON claims.facility_dhpo_config(active);

-- Integration feature toggles
CREATE TABLE IF NOT EXISTS claims.integration_toggle (
  code       TEXT PRIMARY KEY,
  enabled    BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.integration_toggle IS 'Feature toggles for system integrations';

CREATE INDEX IF NOT EXISTS idx_integration_toggle_enabled ON claims.integration_toggle(enabled);

-- ----------------------------------------------------------------------------------------------------------
-- 8.2 INGESTION PROCESSING TABLES
-- ----------------------------------------------------------------------------------------------------------

-- Ingestion run tracking
CREATE TABLE IF NOT EXISTS claims.ingestion_run (
  id                    BIGSERIAL PRIMARY KEY,
  started_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at              TIMESTAMPTZ,
  profile               TEXT NOT NULL,
  fetcher_name          TEXT NOT NULL,
  acker_name            TEXT,
  poll_reason           TEXT,
  files_discovered      INTEGER NOT NULL DEFAULT 0,
  files_pulled          INTEGER NOT NULL DEFAULT 0,
  files_processed_ok    INTEGER NOT NULL DEFAULT 0,
  files_failed          INTEGER NOT NULL DEFAULT 0,
  files_already         INTEGER NOT NULL DEFAULT 0,
  acks_sent             INTEGER NOT NULL DEFAULT 0
);

COMMENT ON TABLE claims.ingestion_run IS 'Tracking table for ingestion batch runs';

CREATE INDEX IF NOT EXISTS idx_ingestion_run_started ON claims.ingestion_run(started_at);
CREATE INDEX IF NOT EXISTS idx_ingestion_run_profile ON claims.ingestion_run(profile);

-- Ingestion file audit
CREATE TABLE IF NOT EXISTS claims.ingestion_file_audit (
  id                            BIGSERIAL PRIMARY KEY,
  ingestion_run_id              BIGINT NOT NULL REFERENCES claims.ingestion_run(id) ON DELETE CASCADE,
  ingestion_file_id             BIGINT NOT NULL REFERENCES claims.ingestion_file(id) ON DELETE CASCADE,
  status                        SMALLINT NOT NULL,
  reason                        TEXT,
  error_class                   TEXT,
  error_message                 TEXT,
  validation_ok                 BOOLEAN NOT NULL DEFAULT FALSE,
  header_sender_id              TEXT NOT NULL,
  header_receiver_id            TEXT NOT NULL,
  header_transaction_date       TIMESTAMPTZ NOT NULL,
  header_record_count           INTEGER NOT NULL,
  header_disposition_flag       TEXT NOT NULL,
  parsed_claims                 INTEGER DEFAULT 0,
  parsed_encounters             INTEGER DEFAULT 0,
  parsed_diagnoses              INTEGER DEFAULT 0,
  parsed_activities             INTEGER DEFAULT 0,
  parsed_observations           INTEGER DEFAULT 0,
  persisted_claims              INTEGER DEFAULT 0,
  persisted_encounters          INTEGER DEFAULT 0,
  persisted_diagnoses           INTEGER DEFAULT 0,
  persisted_activities          INTEGER DEFAULT 0,
  persisted_observations        INTEGER DEFAULT 0,
  parsed_remit_claims           INTEGER DEFAULT 0,
  parsed_remit_activities       INTEGER DEFAULT 0,
  persisted_remit_claims        INTEGER DEFAULT 0
);

COMMENT ON TABLE claims.ingestion_file_audit IS 'Detailed audit trail for each ingested file';

CREATE INDEX IF NOT EXISTS idx_ingestion_audit_run ON claims.ingestion_file_audit(ingestion_run_id);
CREATE INDEX IF NOT EXISTS idx_ingestion_audit_file ON claims.ingestion_file_audit(ingestion_file_id);
CREATE INDEX IF NOT EXISTS idx_ingestion_audit_status ON claims.ingestion_file_audit(status);

-- ----------------------------------------------------------------------------------------------------------
-- 8.3 VERIFICATION SYSTEM TABLES
-- ----------------------------------------------------------------------------------------------------------

-- Verification rules
CREATE TABLE IF NOT EXISTS claims.verification_rule (
  id           BIGSERIAL PRIMARY KEY,
  code         TEXT NOT NULL,
  description  TEXT NOT NULL,
  severity     SMALLINT NOT NULL,
  sql_text     TEXT NOT NULL,
  active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.verification_rule IS 'Rules for data verification and validation';

CREATE UNIQUE INDEX IF NOT EXISTS uq_verification_rule_code ON claims.verification_rule(code);
CREATE INDEX IF NOT EXISTS idx_verification_rule_active ON claims.verification_rule(active);

-- Verification runs
CREATE TABLE IF NOT EXISTS claims.verification_run (
  id                  BIGSERIAL PRIMARY KEY,
  ingestion_file_id   BIGINT NOT NULL REFERENCES claims.ingestion_file(id) ON DELETE CASCADE,
  started_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at            TIMESTAMPTZ,
  passed              BOOLEAN,
  failed_rules        INTEGER NOT NULL DEFAULT 0
);

COMMENT ON TABLE claims.verification_run IS 'Verification run instances';

CREATE INDEX IF NOT EXISTS idx_verification_run_file ON claims.verification_run(ingestion_file_id);
CREATE INDEX IF NOT EXISTS idx_verification_run_started ON claims.verification_run(started_at);

-- Verification results
CREATE TABLE IF NOT EXISTS claims.verification_result (
  id                    BIGSERIAL PRIMARY KEY,
  verification_run_id   BIGINT NOT NULL REFERENCES claims.verification_run(id) ON DELETE CASCADE,
  rule_id               BIGINT NOT NULL REFERENCES claims.verification_rule(id) ON DELETE CASCADE,
  ok                    BOOLEAN NOT NULL,
  rows_affected         BIGINT,
  sample_json           JSONB,
  message               TEXT,
  executed_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.verification_result IS 'Individual verification rule results';

CREATE INDEX IF NOT EXISTS idx_verification_result_run ON claims.verification_result(verification_run_id);
CREATE INDEX IF NOT EXISTS idx_verification_result_rule ON claims.verification_result(rule_id);
CREATE INDEX IF NOT EXISTS idx_verification_result_ok ON claims.verification_result(ok);

-- ----------------------------------------------------------------------------------------------------------
-- 8.4 INGESTION KPI VIEW
-- ----------------------------------------------------------------------------------------------------------

-- Ingestion KPIs view
CREATE OR REPLACE VIEW claims.v_ingestion_kpis AS
SELECT 
  date_trunc('hour', ifa.header_transaction_date) AS hour_bucket,
  COUNT(*) AS files_total,
  COUNT(*) FILTER (WHERE ifa.status = 1) AS files_ok,
  COUNT(*) FILTER (WHERE ifa.status = 2) AS files_fail,
  COUNT(*) FILTER (WHERE ifa.status = 3) AS files_already,
  COALESCE(SUM(ifa.parsed_claims), 0) AS parsed_claims,
  COALESCE(SUM(ifa.persisted_claims), 0) AS persisted_claims,
  COALESCE(SUM(ifa.parsed_activities), 0) AS parsed_activities,
  COALESCE(SUM(ifa.persisted_activities), 0) AS persisted_activities,
  COALESCE(SUM(ifa.parsed_remit_claims), 0) AS parsed_remit_claims,
  COALESCE(SUM(ifa.persisted_remit_claims), 0) AS persisted_remit_claims,
  COALESCE(SUM(ifa.parsed_remit_activities), 0) AS parsed_remit_activities,
  0 AS persisted_remit_activities,  -- Missing from audit table
  COUNT(*) FILTER (WHERE vr.passed = TRUE) AS files_verified
FROM claims.ingestion_file_audit ifa
LEFT JOIN claims.verification_run vr ON vr.ingestion_file_id = ifa.ingestion_file_id
GROUP BY date_trunc('hour', ifa.header_transaction_date)
ORDER BY hour_bucket DESC;

COMMENT ON VIEW claims.v_ingestion_kpis IS 'Hourly KPI metrics for ingestion processing';

CREATE TRIGGER trg_dhpo_config_updated_at
  BEFORE UPDATE ON claims.facility_dhpo_config
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- ----------------------------------------------------------------------------------------------------------
-- 8.2 INTEGRATION TOGGLES
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.integration_toggle (
  code        TEXT PRIMARY KEY,
  enabled     BOOLEAN NOT NULL DEFAULT FALSE,
  description TEXT,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.integration_toggle IS 'Global integration feature toggles';

-- Insert default toggles
INSERT INTO claims.integration_toggle(code, enabled, description) VALUES
  ('dhpo.search.enabled', TRUE, 'Enable DHPO search operations'),
  ('dhpo.setDownloaded.enabled', TRUE, 'Enable DHPO setDownloaded operations'),
  ('dhpo.new.enabled', TRUE, 'Enable DHPO new transactions polling')
ON CONFLICT (code) DO UPDATE SET 
  enabled = EXCLUDED.enabled,
  description = EXCLUDED.description,
  updated_at = NOW();

CREATE TRIGGER trg_integration_toggle_updated_at
  BEFORE UPDATE ON claims.integration_toggle
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- ----------------------------------------------------------------------------------------------------------
-- 6.9 KPI VIEW (hourly rollup)
-- ----------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW claims.v_ingestion_kpis AS
SELECT
  DATE_TRUNC('hour', ifa.created_at) AS hour_bucket,
  COUNT(*) AS total_files,
  SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) AS files_processed,
  SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) AS files_failed,
  SUM(CASE WHEN status = 0 THEN 1 ELSE 0 END) AS files_already,
  SUM(parsed_claims) AS parsed_claims,
  SUM(persisted_claims) AS persisted_claims,
  SUM(parsed_activities) AS parsed_activities,
  SUM(persisted_activities) AS persisted_activities,
  SUM(parsed_remit_claims) AS parsed_remit_claims,
  SUM(persisted_remit_claims) AS persisted_remit_claims,
  SUM(parsed_remit_activities) AS parsed_remit_activities,
  SUM(persisted_remit_activities) AS persisted_remit_activities,
  SUM(CASE WHEN verification_passed THEN 1 ELSE 0 END) AS files_verified
FROM claims.ingestion_file_audit ifa
GROUP BY 1
ORDER BY 1 DESC;

COMMENT ON VIEW claims.v_ingestion_kpis IS 'Hourly rollup of ingestion KPIs; source: claims.ingestion_file_audit';

-- ==========================================================================================================
-- SECTION 7: TRANSACTION TIMESTAMP MANAGEMENT
-- ==========================================================================================================

-- Add tx_at columns to submission, remittance, and claim tables
ALTER TABLE claims.submission ADD COLUMN IF NOT EXISTS tx_at TIMESTAMPTZ;
ALTER TABLE claims.remittance ADD COLUMN IF NOT EXISTS tx_at TIMESTAMPTZ;
ALTER TABLE claims.claim ADD COLUMN IF NOT EXISTS tx_at TIMESTAMPTZ;

-- Add tx_at columns to event and snapshot tables
ALTER TABLE claims.claim_event_activity ADD COLUMN IF NOT EXISTS tx_at TIMESTAMPTZ;
ALTER TABLE claims.event_observation ADD COLUMN IF NOT EXISTS tx_at TIMESTAMPTZ;

-- Function to set submission tx_at from ingestion_file.transaction_date
CREATE OR REPLACE FUNCTION claims.set_submission_tx_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tx_at IS NULL THEN
    SELECT i.transaction_date INTO NEW.tx_at
    FROM claims.ingestion_file i
    WHERE i.id = NEW.ingestion_file_id;
  END IF;
  RETURN NEW;
END$$;

-- Function to set remittance tx_at from ingestion_file.transaction_date
CREATE OR REPLACE FUNCTION claims.set_remittance_tx_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tx_at IS NULL THEN
    SELECT i.transaction_date INTO NEW.tx_at
    FROM claims.ingestion_file i
    WHERE i.id = NEW.ingestion_file_id;
  END IF;
  RETURN NEW;
END$$;

-- Function to set claim tx_at from submission.tx_at
CREATE OR REPLACE FUNCTION claims.set_claim_tx_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tx_at IS NULL THEN
    SELECT s.tx_at INTO NEW.tx_at
    FROM claims.submission s
    WHERE s.id = NEW.submission_id;
  END IF;
  RETURN NEW;
END$$;

-- Function to set claim_event_activity tx_at from related claim_event.event_time
CREATE OR REPLACE FUNCTION claims.set_claim_event_activity_tx_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tx_at IS NULL THEN
    SELECT ce.event_time INTO NEW.tx_at
    FROM claims.claim_event ce
    WHERE ce.id = NEW.claim_event_id;
  END IF;
  RETURN NEW;
END$$;

-- Function to set event_observation tx_at from related claim_event_activity.tx_at
CREATE OR REPLACE FUNCTION claims.set_event_observation_tx_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tx_at IS NULL THEN
    SELECT cea.tx_at INTO NEW.tx_at
    FROM claims.claim_event_activity cea
    WHERE cea.id = NEW.claim_event_activity_id;
  END IF;
  RETURN NEW;
END$$;

-- Create triggers for tx_at management
CREATE TRIGGER IF NOT EXISTS trg_submission_tx_at
  BEFORE INSERT ON claims.submission
  FOR EACH ROW EXECUTE FUNCTION claims.set_submission_tx_at();

CREATE TRIGGER IF NOT EXISTS trg_remittance_tx_at
  BEFORE INSERT ON claims.remittance
  FOR EACH ROW EXECUTE FUNCTION claims.set_remittance_tx_at();

CREATE TRIGGER IF NOT EXISTS trg_claim_tx_at
  BEFORE INSERT ON claims.claim
  FOR EACH ROW EXECUTE FUNCTION claims.set_claim_tx_at();

CREATE TRIGGER IF NOT EXISTS trg_claim_event_activity_tx_at
  BEFORE INSERT ON claims.claim_event_activity
  FOR EACH ROW EXECUTE FUNCTION claims.set_claim_event_activity_tx_at();

CREATE TRIGGER IF NOT EXISTS trg_event_observation_tx_at
  BEFORE INSERT ON claims.event_observation
  FOR EACH ROW EXECUTE FUNCTION claims.set_event_observation_tx_at();

-- Backfill existing rows and enforce NOT NULL constraints
UPDATE claims.submission s
SET tx_at = i.transaction_date
FROM claims.ingestion_file i
WHERE s.tx_at IS NULL AND s.ingestion_file_id = i.id;

UPDATE claims.remittance r
SET tx_at = i.transaction_date
FROM claims.ingestion_file i
WHERE r.tx_at IS NULL AND r.ingestion_file_id = i.id;

UPDATE claims.claim c
SET tx_at = s.tx_at
FROM claims.submission s
WHERE c.tx_at IS NULL AND c.submission_id = s.id;

-- Backfill claim_event_activity.tx_at from claim_event.event_time
UPDATE claims.claim_event_activity cea
SET tx_at = ce.event_time
FROM claims.claim_event ce
WHERE cea.tx_at IS NULL AND ce.id = cea.claim_event_id;

-- Backfill event_observation.tx_at from claim_event_activity.tx_at
UPDATE claims.event_observation eo
SET tx_at = cea.tx_at
FROM claims.claim_event_activity cea
WHERE eo.tx_at IS NULL AND cea.id = eo.claim_event_activity_id;

-- Enforce NOT NULL constraints
ALTER TABLE claims.submission ALTER COLUMN tx_at SET NOT NULL;
ALTER TABLE claims.remittance ALTER COLUMN tx_at SET NOT NULL;
ALTER TABLE claims.claim ALTER COLUMN tx_at SET NOT NULL;
ALTER TABLE claims.claim_event_activity ALTER COLUMN tx_at SET NOT NULL;
ALTER TABLE claims.event_observation ALTER COLUMN tx_at SET NOT NULL;

-- Create indexes for tx_at columns
CREATE INDEX IF NOT EXISTS idx_submission_tx_at ON claims.submission(tx_at);
CREATE INDEX IF NOT EXISTS idx_remittance_tx_at ON claims.remittance(tx_at);
CREATE INDEX IF NOT EXISTS idx_claim_tx_at ON claims.claim(tx_at);
CREATE INDEX IF NOT EXISTS idx_claim_event_activity_tx_at ON claims.claim_event_activity(tx_at);
CREATE INDEX IF NOT EXISTS idx_event_observation_tx_at ON claims.event_observation(tx_at);

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_claim_event_activity_tx_at_code ON claims.claim_event_activity(tx_at, code);
CREATE INDEX IF NOT EXISTS idx_event_observation_tx_at_type ON claims.event_observation(tx_at, obs_type);

-- ==========================================================================================================
-- SECTION 8.5: REFERENCE DATA FOREIGN KEY CONSTRAINTS
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
    ALTER TABLE claims.remittance_claim ADD CONSTRAINT fk_remittance_denial_ref FOREIGN KEY (denial_code_ref_id) REFERENCES claims_ref.denial_code(id);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_remittance_payer_ref') THEN
    ALTER TABLE claims.remittance_claim ADD CONSTRAINT fk_remittance_payer_ref FOREIGN KEY (payer_ref_id) REFERENCES claims_ref.payer(id);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_remittance_provider_ref') THEN
    ALTER TABLE claims.remittance_claim ADD CONSTRAINT fk_remittance_provider_ref FOREIGN KEY (provider_ref_id) REFERENCES claims_ref.provider(id);
  END IF;
END$$;

-- ==========================================================================================================
-- SECTION 9: PERMISSIONS AND GRANTS
-- ==========================================================================================================

-- Grant permissions to claims_user role
GRANT USAGE ON SCHEMA claims TO claims_user;
GRANT USAGE ON SCHEMA claims_ref TO claims_user;

-- Main tables
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA claims TO claims_user;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA claims_ref TO claims_user;

-- Sequences
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA claims TO claims_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA claims_ref TO claims_user;

-- Functions
GRANT EXECUTE ON FUNCTION claims.set_updated_at() TO claims_user;
GRANT EXECUTE ON FUNCTION claims.set_submission_tx_at() TO claims_user;
GRANT EXECUTE ON FUNCTION claims.set_remittance_tx_at() TO claims_user;
GRANT EXECUTE ON FUNCTION claims.set_claim_tx_at() TO claims_user;
GRANT EXECUTE ON FUNCTION claims.set_claim_event_activity_tx_at() TO claims_user;
GRANT EXECUTE ON FUNCTION claims.set_event_observation_tx_at() TO claims_user;

-- Views
GRANT SELECT ON claims.v_ingestion_kpis TO claims_user;

-- Default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA claims GRANT SELECT, INSERT, UPDATE ON TABLES TO claims_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA claims GRANT USAGE, SELECT ON SEQUENCES TO claims_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA claims_ref GRANT SELECT, INSERT, UPDATE ON TABLES TO claims_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA claims_ref GRANT USAGE, SELECT ON SEQUENCES TO claims_user;

-- ==========================================================================================================
-- SECTION 10: INITIAL DATA AND SEEDING
-- ==========================================================================================================

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

-- Seed encounter start/end types
--INSERT INTO claims_ref.encounter_start_type(type_code, description) VALUES
--  ('ADMISSION', 'Patient admission'),
--  ('ARRIVAL', 'Patient arrival'),
--  ('REGISTRATION', 'Patient registration')
--ON CONFLICT (type_code) DO UPDATE SET description = EXCLUDED.description;

--INSERT INTO claims_ref.encounter_end_type(type_code, description) VALUES
  --('DISCHARGE', 'Patient discharge'),
  --('DEPARTURE', 'Patient departure'),
  --('COMPLETION', 'Service completion')
--ON CONFLICT (type_code) DO UPDATE SET description = EXCLUDED.description;

-- ==========================================================================================================
-- SECTION 11: PERFORMANCE OPTIMIZATIONS
-- ==========================================================================================================

-- Additional indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_claim_amounts ON claims.claim(gross, patient_share, net);
CREATE INDEX IF NOT EXISTS idx_claim_dates ON claims.claim(created_at, updated_at);
CREATE INDEX IF NOT EXISTS idx_ingestion_file_dates ON claims.ingestion_file(created_at, transaction_date);

-- Partial indexes for active records
CREATE INDEX IF NOT EXISTS idx_facility_active ON claims_ref.facility(facility_code) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_payer_active ON claims_ref.payer(payer_code) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_provider_active ON claims_ref.provider(provider_code) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_clinician_active ON claims_ref.clinician(clinician_code) WHERE status = 'ACTIVE';

-- Indexes for reference data foreign keys
CREATE INDEX IF NOT EXISTS idx_claim_payer_ref ON claims.claim(payer_ref_id);
CREATE INDEX IF NOT EXISTS idx_claim_provider_ref ON claims.claim(provider_ref_id);
CREATE INDEX IF NOT EXISTS idx_encounter_facility_ref ON claims.encounter(facility_ref_id);
CREATE INDEX IF NOT EXISTS idx_activity_clinician_ref ON claims.activity(clinician_ref_id);
CREATE INDEX IF NOT EXISTS idx_activity_code_ref ON claims.activity(activity_code_ref_id);
CREATE INDEX IF NOT EXISTS idx_diagnosis_code_ref ON claims.diagnosis(diagnosis_code_ref_id);
CREATE INDEX IF NOT EXISTS idx_remittance_denial_ref ON claims.remittance_claim(denial_code_ref_id);
CREATE INDEX IF NOT EXISTS idx_remittance_payer_ref ON claims.remittance_claim(payer_ref_id);
CREATE INDEX IF NOT EXISTS idx_remittance_provider_ref ON claims.remittance_claim(provider_ref_id);

-- ==========================================================================================================
-- END OF UNIFIED DDL
-- ==========================================================================================================

-- Final comments
COMMENT ON SCHEMA claims IS 'Main claims processing schema - handles XML ingestion, submission processing, and remittance processing';
COMMENT ON SCHEMA claims_ref IS 'Reference data schema - master data for facilities, payers, providers, codes, and dictionaries';

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'Claims Processing System DDL created successfully!';
  RAISE NOTICE 'Schemas: claims, claims_ref';
  RAISE NOTICE 'Extensions: pg_trgm, citext, pgcrypto';
  RAISE NOTICE 'Role: claims_user';
  RAISE NOTICE 'Ready for claims processing operations.';
END$$;
