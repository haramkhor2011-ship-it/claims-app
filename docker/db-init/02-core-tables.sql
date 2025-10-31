-- ==========================================================================================================
-- CORE CLAIMS TABLES - MAIN PROCESSING SCHEMA
-- ==========================================================================================================
-- 
-- Purpose: Create all core claims processing tables
-- Version: 2.0
-- Date: 2025-10-24
-- 
-- This script creates the main claims processing tables including:
-- - Ingestion and file management tables
-- - Claim submission and processing tables  
-- - Remittance processing tables
-- - Event tracking and audit tables
-- - Payment tracking tables
-- - Verification and monitoring tables
--
-- Note: Utility functions are in 08-functions-procedures.sql
-- Note: Reference data tables are in 03-ref-data-tables.sql
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: DOMAINS
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
-- SECTION 2: INGESTION AND FILE MANAGEMENT
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- 2.1 INGESTION FILE (Single Source of Truth)
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.ingestion_file (
  id                     BIGSERIAL PRIMARY KEY,
  file_id                TEXT NOT NULL,
  file_name              TEXT,
  root_type              SMALLINT NOT NULL CHECK (root_type IN (1,2)),
  sender_id              TEXT NOT NULL,
  receiver_id            TEXT NOT NULL,
  transaction_date       TIMESTAMPTZ NOT NULL,
  record_count_declared  INTEGER NOT NULL CHECK (record_count_declared >= 0),
  disposition_flag       TEXT NOT NULL,
  xml_bytes              BYTEA NOT NULL,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_ingestion_file UNIQUE (file_id)
);

COMMENT ON TABLE claims.ingestion_file IS 'SSOT: Raw XML + XSD Header; duplicate files rejected by unique(file_id)';
COMMENT ON COLUMN claims.ingestion_file.root_type IS '1=Claim.Submission, 2=Remittance.Advice';
COMMENT ON COLUMN claims.ingestion_file.xml_bytes IS 'Raw XML bytes (SSOT)';

CREATE INDEX IF NOT EXISTS idx_ingestion_file_root_type ON claims.ingestion_file(root_type);
CREATE INDEX IF NOT EXISTS idx_ingestion_file_sender ON claims.ingestion_file(sender_id);
CREATE INDEX IF NOT EXISTS idx_ingestion_file_receiver ON claims.ingestion_file(receiver_id);
CREATE INDEX IF NOT EXISTS idx_ingestion_file_transaction_date ON claims.ingestion_file(transaction_date);

--CREATE TRIGGER trg_ingestion_file_updated_at
  --BEFORE UPDATE ON claims.ingestion_file
  --FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- ----------------------------------------------------------------------------------------------------------
-- 2.2 INGESTION ERROR TRACKING
-- ----------------------------------------------------------------------------------------------------------
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

-- ==========================================================================================================
-- SECTION 3: CANONICAL CLAIM KEY
-- ==========================================================================================================

CREATE TABLE IF NOT EXISTS claims.claim_key (
  id          BIGSERIAL PRIMARY KEY,
  claim_id    TEXT NOT NULL,
  created_at  TIMESTAMPTZ,
  updated_at  TIMESTAMPTZ,
  CONSTRAINT uq_claim_key_claim_id UNIQUE (claim_id)
);

COMMENT ON TABLE claims.claim_key IS 'Canonical claim identifier (Claim/ID appears in both roots)';

CREATE INDEX IF NOT EXISTS idx_claim_key_claim_id ON claims.claim_key(claim_id);

-- ==========================================================================================================
-- SECTION 4: SUBMISSION PROCESSING
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- 4.1 SUBMISSION
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.submission (
  id                 BIGSERIAL PRIMARY KEY,
  ingestion_file_id  BIGINT NOT NULL REFERENCES claims.ingestion_file(id) ON DELETE RESTRICT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  tx_at              TIMESTAMPTZ NOT NULL,
  CONSTRAINT uq_submission_per_file UNIQUE (ingestion_file_id)
);

COMMENT ON TABLE claims.submission IS 'Submission grouping (one per ingestion file)';

CREATE INDEX IF NOT EXISTS idx_submission_file ON claims.submission(ingestion_file_id);
CREATE INDEX IF NOT EXISTS idx_submission_tx_at ON claims.submission(tx_at);

-- ----------------------------------------------------------------------------------------------------------
-- 4.2 CORE CLAIM DATA
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.claim (
  id                 BIGSERIAL PRIMARY KEY,
  claim_key_id       BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE RESTRICT,
  submission_id      BIGINT NOT NULL REFERENCES claims.submission(id) ON DELETE RESTRICT,
  id_payer           TEXT,
  member_id          TEXT,
  payer_id           TEXT NOT NULL,
  provider_id        TEXT NOT NULL,
  emirates_id_number TEXT NOT NULL,
  gross              NUMERIC(14,2) NOT NULL, 
  patient_share      NUMERIC(14,2) NOT NULL, 
  net                NUMERIC(14,2) NOT NULL,
  comments           TEXT,
  payer_ref_id       BIGINT,
  provider_ref_id    BIGINT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  tx_at              TIMESTAMPTZ NOT NULL,
  CONSTRAINT uq_claim_per_key UNIQUE (claim_key_id),
  CONSTRAINT uq_claim_submission_claimkey UNIQUE (submission_id, claim_key_id)
);

COMMENT ON TABLE claims.claim IS 'Core submission claim; duplicates without <Resubmission> are ignored (one row per claim_key_id)';

CREATE INDEX IF NOT EXISTS idx_claim_claim_key ON claims.claim(claim_key_id);
CREATE INDEX IF NOT EXISTS idx_claim_payer ON claims.claim(payer_id);
CREATE INDEX IF NOT EXISTS idx_claim_provider ON claims.claim(provider_id);
CREATE INDEX IF NOT EXISTS idx_claim_member ON claims.claim(member_id);
CREATE INDEX IF NOT EXISTS idx_claim_emirates ON claims.claim(emirates_id_number);
CREATE INDEX IF NOT EXISTS idx_claim_has_comments ON claims.claim((comments IS NOT NULL));
CREATE INDEX IF NOT EXISTS idx_claim_tx_at ON claims.claim(tx_at);
CREATE INDEX IF NOT EXISTS idx_claim_payer_ref ON claims.claim(payer_ref_id);
CREATE INDEX IF NOT EXISTS idx_claim_provider_ref ON claims.claim(provider_ref_id);
CREATE INDEX IF NOT EXISTS idx_claim_amounts ON claims.claim(gross, patient_share, net);
CREATE INDEX IF NOT EXISTS idx_claim_dates ON claims.claim(created_at, updated_at);


-- ----------------------------------------------------------------------------------------------------------
-- 4.3 ENCOUNTER DATA
-- ----------------------------------------------------------------------------------------------------------
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

COMMENT ON TABLE claims.encounter IS 'Encounter information for submission claims';

CREATE INDEX IF NOT EXISTS idx_encounter_claim ON claims.encounter(claim_id);
CREATE INDEX IF NOT EXISTS idx_encounter_facility ON claims.encounter(facility_id);
CREATE INDEX IF NOT EXISTS idx_encounter_patient ON claims.encounter(patient_id);
CREATE INDEX IF NOT EXISTS idx_encounter_start ON claims.encounter(start_at);
CREATE INDEX IF NOT EXISTS idx_encounter_facility_ref ON claims.encounter(facility_ref_id);


-- ----------------------------------------------------------------------------------------------------------
-- 4.4 DIAGNOSIS DATA
-- ----------------------------------------------------------------------------------------------------------
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
CREATE INDEX IF NOT EXISTS idx_diagnosis_claim_code ON claims.diagnosis(claim_id, code);
CREATE INDEX IF NOT EXISTS idx_diagnosis_code_ref ON claims.diagnosis(diagnosis_code_ref_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_diagnosis_claim_type_code ON claims.diagnosis(claim_id, diag_type, code);

-- ----------------------------------------------------------------------------------------------------------
-- 4.5 ACTIVITY DATA
-- ----------------------------------------------------------------------------------------------------------
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
  CONSTRAINT uq_activity_bk UNIQUE (claim_id, activity_id)
);

COMMENT ON TABLE claims.activity IS 'Activities for submission claims';

CREATE INDEX IF NOT EXISTS idx_activity_claim ON claims.activity(claim_id);
CREATE INDEX IF NOT EXISTS idx_activity_code ON claims.activity(code);
CREATE INDEX IF NOT EXISTS idx_activity_clinician ON claims.activity(clinician);
CREATE INDEX IF NOT EXISTS idx_activity_start ON claims.activity(start_at);
CREATE INDEX IF NOT EXISTS idx_activity_type ON claims.activity(type);
CREATE INDEX IF NOT EXISTS idx_activity_clinician_ref ON claims.activity(clinician_ref_id);
CREATE INDEX IF NOT EXISTS idx_activity_code_ref ON claims.activity(activity_code_ref_id);

-- ----------------------------------------------------------------------------------------------------------
-- 4.6 OBSERVATION DATA
-- ----------------------------------------------------------------------------------------------------------
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
CREATE INDEX IF NOT EXISTS idx_obs_nonfile ON claims.observation(activity_id) WHERE file_bytes IS NULL;

-- ==========================================================================================================
-- SECTION 5: REMITTANCE PROCESSING
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- 5.1 REMITTANCE
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.remittance (
  id                 BIGSERIAL PRIMARY KEY,
  ingestion_file_id  BIGINT NOT NULL REFERENCES claims.ingestion_file(id) ON DELETE RESTRICT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  tx_at              TIMESTAMPTZ NOT NULL,
  CONSTRAINT uq_remittance_per_file UNIQUE (ingestion_file_id)
);

COMMENT ON TABLE claims.remittance IS 'Remittance grouping (one per ingestion file)';

CREATE INDEX IF NOT EXISTS idx_remittance_file ON claims.remittance(ingestion_file_id);
CREATE INDEX IF NOT EXISTS idx_remittance_tx_at ON claims.remittance(tx_at);

-- ----------------------------------------------------------------------------------------------------------
-- 5.2 REMITTANCE CLAIM DATA
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.remittance_claim (
  id                    BIGSERIAL PRIMARY KEY,
  remittance_id         BIGINT NOT NULL REFERENCES claims.remittance(id) ON DELETE RESTRICT,
  claim_key_id          BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE RESTRICT,
  id_payer              TEXT NOT NULL,
  provider_id           TEXT,
  denial_code           TEXT,
  comments              TEXT,
  payment_reference     TEXT NOT NULL,
  date_settlement       TIMESTAMPTZ,
  facility_id           TEXT,
  payer_ref_id          BIGINT,
  provider_ref_id       BIGINT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_remittance_claim UNIQUE (remittance_id, claim_key_id)
);

COMMENT ON TABLE claims.remittance_claim IS 'Remittance claims with payment information';

CREATE INDEX IF NOT EXISTS idx_remittance_claim_key ON claims.remittance_claim(claim_key_id);
CREATE INDEX IF NOT EXISTS idx_remittance_claim_payer ON claims.remittance_claim(id_payer);
CREATE INDEX IF NOT EXISTS idx_remittance_claim_provider ON claims.remittance_claim(provider_id);
CREATE INDEX IF NOT EXISTS idx_remittance_claim_comments ON claims.remittance_claim(comments);
CREATE INDEX IF NOT EXISTS idx_remittance_claim_payment_ref ON claims.remittance_claim(payment_reference);
CREATE INDEX IF NOT EXISTS idx_remit_claim_payer_ref ON claims.remittance_claim(payer_ref_id);
CREATE INDEX IF NOT EXISTS idx_remit_claim_provider_ref ON claims.remittance_claim(provider_ref_id);
CREATE INDEX IF NOT EXISTS idx_remit_claim_settle ON claims.remittance_claim(date_settlement);
CREATE INDEX IF NOT EXISTS idx_remittance_payer_ref ON claims.remittance_claim(payer_ref_id);
CREATE INDEX IF NOT EXISTS idx_remittance_provider_ref ON claims.remittance_claim(provider_ref_id);

-- ----------------------------------------------------------------------------------------------------------
-- 5.3 REMITTANCE ACTIVITY DATA
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.remittance_activity (
  id                    BIGSERIAL PRIMARY KEY,
  remittance_claim_id   BIGINT NOT NULL REFERENCES claims.remittance_claim(id) ON DELETE CASCADE,
  activity_id           TEXT NOT NULL,
  start_at              TIMESTAMPTZ NOT NULL,
  type                  TEXT NOT NULL,
  code                  TEXT NOT NULL,
  quantity              NUMERIC(14,2) NOT NULL,
  net                   NUMERIC(14,2) NOT NULL,
  list_price            NUMERIC(14,2),
  clinician             TEXT NOT NULL,
  prior_authorization_id TEXT,
  gross                 NUMERIC(14,2),
  patient_share         NUMERIC(14,2),
  payment_amount        NUMERIC(14,2) NOT NULL,
  denial_code           TEXT,
  denial_code_ref_id    BIGINT,
  activity_code_ref_id  BIGINT,
  clinician_ref_id      BIGINT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_remittance_activity UNIQUE (remittance_claim_id, activity_id)
);

COMMENT ON TABLE claims.remittance_activity IS 'Remittance activities with payment details';
COMMENT ON COLUMN claims.remittance_activity.payment_amount IS 'Payment amount (can be negative for taken back scenarios)';

CREATE INDEX IF NOT EXISTS idx_remittance_activity_claim ON claims.remittance_activity(remittance_claim_id);
CREATE INDEX IF NOT EXISTS idx_remittance_activity_code ON claims.remittance_activity(code);
CREATE INDEX IF NOT EXISTS idx_remittance_activity_clinician ON claims.remittance_activity(clinician);
CREATE INDEX IF NOT EXISTS idx_remit_act_start ON claims.remittance_activity(start_at);
CREATE INDEX IF NOT EXISTS idx_remit_act_type ON claims.remittance_activity(type);
CREATE INDEX IF NOT EXISTS idx_remittance_activity_code_ref ON claims.remittance_activity(activity_code_ref_id);
CREATE INDEX IF NOT EXISTS idx_remittance_activity_denial_ref ON claims.remittance_activity(denial_code_ref_id);
CREATE INDEX IF NOT EXISTS idx_remittance_activity_clinician_ref ON claims.remittance_activity(clinician_ref_id);


-- ==========================================================================================================
-- SECTION 6: CLAIM EVENT TRACKING
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- 6.1 CLAIM EVENT
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.claim_event (
  id                 BIGSERIAL PRIMARY KEY,
  claim_key_id       BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE RESTRICT,
  ingestion_file_id  BIGINT REFERENCES claims.ingestion_file(id) ON DELETE RESTRICT,
  event_time         TIMESTAMPTZ NOT NULL,
  type               SMALLINT NOT NULL,
  submission_id      BIGINT REFERENCES claims.submission(id) ON DELETE RESTRICT,
  remittance_id      BIGINT REFERENCES claims.remittance(id) ON DELETE RESTRICT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.claim_event IS 'Event tracking for claim lifecycle';

CREATE INDEX IF NOT EXISTS idx_claim_event_key ON claims.claim_event(claim_key_id);
CREATE INDEX IF NOT EXISTS idx_claim_event_type ON claims.claim_event(type);
CREATE INDEX IF NOT EXISTS idx_claim_event_time ON claims.claim_event(event_time);
CREATE INDEX IF NOT EXISTS idx_claim_event_file ON claims.claim_event(ingestion_file_id);
CREATE INDEX IF NOT EXISTS idx_balance_amount_base_enhanced_resubmission ON claims.claim_event(claim_key_id, type, event_time) WHERE type = 2;
CREATE INDEX IF NOT EXISTS idx_remittances_resubmission_claim_event_type ON claims.claim_event(claim_key_id, type);

ALTER TABLE claims.claim_event ADD CONSTRAINT uq_claim_event_dedup UNIQUE (claim_key_id, type, event_time);
--CREATE UNIQUE INDEX IF NOT EXISTS uq_claim_event_one_submission ON claims.claim_event(claim_key_id) WHERE type = 1;

-- ----------------------------------------------------------------------------------------------------------
-- 6.2 CLAIM EVENT ACTIVITY SNAPSHOT
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.claim_event_activity (
  id                              BIGSERIAL PRIMARY KEY,
  claim_event_id                  BIGINT NOT NULL REFERENCES claims.claim_event(id) ON DELETE CASCADE,
  activity_id_ref                 BIGINT REFERENCES claims.activity(id) ON DELETE SET NULL,
  remittance_activity_id_ref      BIGINT REFERENCES claims.remittance_activity(id) ON DELETE SET NULL,
  activity_id_at_event            TEXT NOT NULL,
  start_at_event                  TIMESTAMPTZ NOT NULL,
  type_at_event                   TEXT NOT NULL,
  code_at_event                   TEXT NOT NULL,
  quantity_at_event               NUMERIC(14,2) NOT NULL CHECK (quantity_at_event >= 0),
  net_at_event                    NUMERIC(14,2) NOT NULL CHECK (net_at_event >= 0),
  clinician_at_event              TEXT NOT NULL,
  prior_authorization_id_at_event TEXT,
  list_price_at_event             NUMERIC(14,2),
  gross_at_event                  NUMERIC(14,2),
  patient_share_at_event          NUMERIC(14,2),
  payment_amount_at_event         NUMERIC(14,2),
  denial_code_at_event            TEXT,
  created_at                      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.claim_event_activity IS 'Activity snapshot at claim event time';

CREATE INDEX IF NOT EXISTS idx_claim_event_activity_event ON claims.claim_event_activity(claim_event_id);
CREATE INDEX IF NOT EXISTS idx_claim_event_activity_ref ON claims.claim_event_activity(activity_id_ref);
CREATE INDEX IF NOT EXISTS idx_claim_event_activity_remit_ref ON claims.claim_event_activity(remittance_activity_id_ref);
CREATE UNIQUE INDEX IF NOT EXISTS uq_claim_event_activity_key ON claims.claim_event_activity(claim_event_id, activity_id_at_event);

-- ----------------------------------------------------------------------------------------------------------
-- 6.3 CLAIM STATUS TIMELINE
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.claim_status_timeline (
  id             BIGSERIAL PRIMARY KEY,
  claim_key_id   BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE CASCADE,
  status         SMALLINT NOT NULL,
  status_time    TIMESTAMPTZ NOT NULL,
  claim_event_id BIGINT REFERENCES claims.claim_event(id) ON DELETE SET NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.claim_status_timeline IS 'Status timeline for claim lifecycle';

CREATE INDEX IF NOT EXISTS idx_claim_status_timeline_key ON claims.claim_status_timeline(claim_key_id);
CREATE INDEX IF NOT EXISTS idx_claim_status_timeline_status ON claims.claim_status_timeline(status);
CREATE INDEX IF NOT EXISTS idx_claim_status_timeline_time ON claims.claim_status_timeline(status_time);

-- ==========================================================================================================
-- SECTION 7: PAYMENT TRACKING TABLES
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- 7.1 CLAIM PAYMENT (AGGREGATED FINANCIAL SUMMARY)
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.claim_payment (
  id                         BIGSERIAL PRIMARY KEY,
  claim_key_id               BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE CASCADE,
  
  -- === FINANCIAL SUMMARY (aggregated from all remittances) ===
  total_submitted_amount     NUMERIC(15,2) NOT NULL DEFAULT 0,
  total_paid_amount          NUMERIC(15,2) NOT NULL DEFAULT 0,
  total_remitted_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
  total_rejected_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
  total_denied_amount        NUMERIC(15,2) NOT NULL DEFAULT 0,
  total_taken_back_amount    NUMERIC(15,2) NOT NULL DEFAULT 0,
  total_taken_back_count     INTEGER NOT NULL DEFAULT 0,
  total_net_paid_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
  
  -- === ACTIVITY COUNTS ===
  total_activities           INTEGER NOT NULL DEFAULT 0,
  paid_activities            INTEGER NOT NULL DEFAULT 0,
  partially_paid_activities  INTEGER NOT NULL DEFAULT 0,
  rejected_activities        INTEGER NOT NULL DEFAULT 0,
  pending_activities         INTEGER NOT NULL DEFAULT 0,
  taken_back_activities      INTEGER NOT NULL DEFAULT 0,
  partially_taken_back_activities INTEGER NOT NULL DEFAULT 0,
  
  -- === LIFECYCLE TRACKING ===
  remittance_count           INTEGER NOT NULL DEFAULT 0,
  resubmission_count         INTEGER NOT NULL DEFAULT 0,
  
  -- === CURRENT STATUS ===
  payment_status             VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  
  -- === LIFECYCLE DATES ===
  first_submission_date      DATE,
  last_submission_date       DATE,
  first_remittance_date      DATE,
  last_remittance_date       DATE,
  first_payment_date         DATE,
  last_payment_date          DATE,
  latest_settlement_date     DATE,
  
  -- === LIFECYCLE METRICS ===
  days_to_first_payment      INTEGER,
  days_to_final_settlement   INTEGER,
  processing_cycles          INTEGER NOT NULL DEFAULT 1,
  
  -- === PAYMENT REFERENCES ===
  latest_payment_reference   VARCHAR(100),
  payment_references         TEXT[],
  
  -- === BUSINESS TRANSACTION TIME ===
  tx_at                      TIMESTAMPTZ NOT NULL,
  
  -- === AUDIT TIMESTAMPS ===
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- === CONSTRAINTS ===
  CONSTRAINT uq_claim_payment_claim_key UNIQUE (claim_key_id),
  CONSTRAINT ck_claim_payment_status CHECK (payment_status IN ('FULLY_PAID', 'PARTIALLY_PAID', 'REJECTED', 'PENDING', 'TAKEN_BACK', 'PARTIALLY_TAKEN_BACK')),
  CONSTRAINT ck_claim_payment_amounts CHECK (
    total_paid_amount >= 0 AND 
    total_remitted_amount >= 0 AND 
    total_rejected_amount >= 0 AND
    total_denied_amount >= 0 AND
    total_submitted_amount >= 0 AND
    total_taken_back_amount >= 0 AND
    total_taken_back_count >= 0 AND
    total_net_paid_amount >= 0
  ),
  CONSTRAINT ck_claim_payment_activities CHECK (
    total_activities >= 0 AND
    paid_activities >= 0 AND
    partially_paid_activities >= 0 AND
    rejected_activities >= 0 AND
    pending_activities >= 0 AND
    taken_back_activities >= 0 AND
    partially_taken_back_activities >= 0 AND
    (paid_activities + partially_paid_activities + rejected_activities + 
     pending_activities + taken_back_activities + partially_taken_back_activities) = total_activities
  ),
  CONSTRAINT ck_claim_payment_dates CHECK (
    (first_submission_date IS NULL OR first_submission_date <= CURRENT_DATE + INTERVAL '30 days') AND
    (first_payment_date IS NULL OR first_payment_date <= CURRENT_DATE + INTERVAL '30 days') AND
    (first_submission_date IS NULL OR last_submission_date IS NULL OR first_submission_date <= last_submission_date) AND
    (first_payment_date IS NULL OR last_payment_date IS NULL OR first_payment_date <= last_payment_date)
  )
);

COMMENT ON TABLE claims.claim_payment IS 'Aggregated financial summary and lifecycle tracking for claims - ONE ROW PER CLAIM';
COMMENT ON COLUMN claims.claim_payment.claim_key_id IS 'Canonical claim identifier - UNIQUE constraint ensures one row per claim';
COMMENT ON COLUMN claims.claim_payment.total_taken_back_amount IS 'Total amount taken back (reversed) across all activities';
COMMENT ON COLUMN claims.claim_payment.total_taken_back_count IS 'Total number of taken back transactions';
COMMENT ON COLUMN claims.claim_payment.total_net_paid_amount IS 'Net amount paid after accounting for taken back amounts (paid - taken_back)';
COMMENT ON COLUMN claims.claim_payment.taken_back_activities IS 'Number of activities with TAKEN_BACK status';
COMMENT ON COLUMN claims.claim_payment.partially_taken_back_activities IS 'Number of activities with PARTIALLY_TAKEN_BACK status';

CREATE INDEX IF NOT EXISTS idx_claim_payment_claim_key ON claims.claim_payment(claim_key_id);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status ON claims.claim_payment(payment_status);
CREATE INDEX IF NOT EXISTS idx_claim_payment_tx_at ON claims.claim_payment(tx_at);
CREATE INDEX IF NOT EXISTS idx_claim_payment_dates ON claims.claim_payment(first_payment_date, last_payment_date);
CREATE INDEX IF NOT EXISTS idx_claim_payment_settlement ON claims.claim_payment(latest_settlement_date);
CREATE INDEX IF NOT EXISTS idx_claim_payment_amounts ON claims.claim_payment(total_submitted_amount, total_paid_amount);
CREATE INDEX IF NOT EXISTS idx_claim_payment_cycles ON claims.claim_payment(processing_cycles, resubmission_count);
CREATE INDEX IF NOT EXISTS idx_claim_payment_taken_back_amount ON claims.claim_payment(total_taken_back_amount);
CREATE INDEX IF NOT EXISTS idx_claim_payment_net_paid_amount ON claims.claim_payment(total_net_paid_amount);
CREATE INDEX IF NOT EXISTS idx_claim_payment_taken_back_status ON claims.claim_payment(payment_status) WHERE payment_status IN ('TAKEN_BACK', 'PARTIALLY_TAKEN_BACK');
CREATE INDEX IF NOT EXISTS idx_claim_payment_taken_back_activities ON claims.claim_payment(taken_back_activities, partially_taken_back_activities);
CREATE INDEX IF NOT EXISTS idx_claim_payment_financial_summary ON claims.claim_payment(total_submitted_amount, total_net_paid_amount, total_taken_back_amount);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status_active ON claims.claim_payment(payment_status) WHERE payment_status != 'PENDING';
CREATE INDEX IF NOT EXISTS idx_claim_payment_financial_summary_alt ON claims.claim_payment(total_submitted_amount, total_paid_amount, total_rejected_amount);

ALTER TABLE claims.claim_payment ALTER COLUMN remittance_count SET DEFAULT 0;
-- ----------------------------------------------------------------------------------------------------------
-- 7.2 CLAIM ACTIVITY SUMMARY (ACTIVITY-LEVEL FINANCIAL TRACKING)
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.claim_activity_summary (
  id                         BIGSERIAL PRIMARY KEY,
  claim_key_id               BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE CASCADE,
  activity_id                TEXT NOT NULL,
  
  -- === FINANCIAL METRICS PER ACTIVITY ===
  submitted_amount           NUMERIC(15,2) NOT NULL DEFAULT 0,
  paid_amount               NUMERIC(15,2) NOT NULL DEFAULT 0,
  rejected_amount           NUMERIC(15,2) NOT NULL DEFAULT 0,
  denied_amount             NUMERIC(15,2) NOT NULL DEFAULT 0,
  taken_back_amount         NUMERIC(15,2) NOT NULL DEFAULT 0,
  taken_back_count          INTEGER NOT NULL DEFAULT 0,
  net_paid_amount          NUMERIC(15,2) NOT NULL DEFAULT 0,
  
  -- === ACTIVITY STATUS ===
  activity_status           VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  
  -- === LIFECYCLE TRACKING ===
  remittance_count          INTEGER NOT NULL DEFAULT 0,
  denial_codes              TEXT[],
  
  -- === DATES ===
  first_payment_date        DATE,
  last_payment_date         DATE,
  days_to_first_payment     INTEGER,
  
  -- === BUSINESS TRANSACTION TIME ===
  tx_at                     TIMESTAMPTZ NOT NULL,
  
  -- === AUDIT TIMESTAMPS ===
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- === CONSTRAINTS ===
  CONSTRAINT uq_activity_summary UNIQUE (claim_key_id, activity_id),
  CONSTRAINT ck_activity_status CHECK (activity_status IN ('FULLY_PAID', 'PARTIALLY_PAID', 'REJECTED', 'PENDING', 'TAKEN_BACK', 'PARTIALLY_TAKEN_BACK')),
  CONSTRAINT ck_activity_amounts CHECK (
    paid_amount >= 0 AND 
    rejected_amount >= 0 AND
    denied_amount >= 0 AND
    submitted_amount >= 0 AND
    taken_back_amount >= 0 AND
    taken_back_count >= 0 AND
    net_paid_amount >= 0
  )
);

COMMENT ON TABLE claims.claim_activity_summary IS 'Activity-level financial summary and tracking - ONE ROW PER ACTIVITY';
COMMENT ON COLUMN claims.claim_activity_summary.claim_key_id IS 'Canonical claim identifier';
COMMENT ON COLUMN claims.claim_activity_summary.activity_id IS 'Business activity identifier';
COMMENT ON COLUMN claims.claim_activity_summary.activity_status IS 'Activity payment status: FULLY_PAID, PARTIALLY_PAID, REJECTED, PENDING, TAKEN_BACK, PARTIALLY_TAKEN_BACK';
COMMENT ON COLUMN claims.claim_activity_summary.denial_codes IS 'Array of denial codes for this activity';

CREATE INDEX IF NOT EXISTS idx_activity_summary_claim_key ON claims.claim_activity_summary(claim_key_id);
CREATE INDEX IF NOT EXISTS idx_activity_summary_activity_id ON claims.claim_activity_summary(activity_id);
CREATE INDEX IF NOT EXISTS idx_activity_summary_status ON claims.claim_activity_summary(activity_status);
CREATE INDEX IF NOT EXISTS idx_activity_summary_amounts ON claims.claim_activity_summary(submitted_amount, paid_amount);


-- ----------------------------------------------------------------------------------------------------------
-- 7.3 CLAIM FINANCIAL TIMELINE (EVENT-BASED FINANCIAL HISTORY)
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.claim_financial_timeline (
  id                         BIGSERIAL PRIMARY KEY,
  claim_key_id               BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE CASCADE,
  event_type                 VARCHAR(20) NOT NULL,
  event_date                 DATE NOT NULL,
  
  -- === FINANCIAL IMPACT ===
  amount                     NUMERIC(15,2) NOT NULL,
  cumulative_paid            NUMERIC(15,2) NOT NULL,
  cumulative_rejected        NUMERIC(15,2) NOT NULL,
  
  -- === EVENT DETAILS ===
  payment_reference          VARCHAR(100),
  denial_code                VARCHAR(50),
  event_description          TEXT,
  
  -- === BUSINESS TRANSACTION TIME ===
  tx_at                      TIMESTAMPTZ NOT NULL,
  
  -- === AUDIT TIMESTAMPS ===
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- === CONSTRAINTS ===
  CONSTRAINT ck_financial_timeline_event_type CHECK (event_type IN ('SUBMISSION', 'PAYMENT', 'DENIAL', 'RESUBMISSION')),
  CONSTRAINT ck_financial_timeline_amounts CHECK (
    amount >= 0 AND 
    cumulative_paid >= 0 AND
    cumulative_rejected >= 0
  )
);

COMMENT ON TABLE claims.claim_financial_timeline IS 'Event-based financial timeline for claims - ONE ROW PER FINANCIAL EVENT';
COMMENT ON COLUMN claims.claim_financial_timeline.claim_key_id IS 'Canonical claim identifier';
COMMENT ON COLUMN claims.claim_financial_timeline.event_type IS 'Type of financial event: SUBMISSION, PAYMENT, DENIAL, RESUBMISSION';
COMMENT ON COLUMN claims.claim_financial_timeline.cumulative_paid IS 'Cumulative paid amount up to this event';
COMMENT ON COLUMN claims.claim_financial_timeline.cumulative_rejected IS 'Cumulative rejected amount up to this event';

CREATE INDEX IF NOT EXISTS idx_financial_timeline_claim_key ON claims.claim_financial_timeline(claim_key_id);
CREATE INDEX IF NOT EXISTS idx_financial_timeline_date ON claims.claim_financial_timeline(event_date);
CREATE INDEX IF NOT EXISTS idx_financial_timeline_type ON claims.claim_financial_timeline(event_type);
CREATE INDEX IF NOT EXISTS idx_financial_timeline_tx_at ON claims.claim_financial_timeline(tx_at);

-- ----------------------------------------------------------------------------------------------------------
-- 7.4 PAYER PERFORMANCE SUMMARY (PAYER PERFORMANCE METRICS)
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.payer_performance_summary (
  id                         BIGSERIAL PRIMARY KEY,
  payer_ref_id               BIGINT NOT NULL,
  month_bucket               DATE NOT NULL,
  
  -- === PERFORMANCE METRICS ===
  total_claims               INTEGER NOT NULL DEFAULT 0,
  total_submitted_amount     NUMERIC(15,2) NOT NULL DEFAULT 0,
  total_paid_amount          NUMERIC(15,2) NOT NULL DEFAULT 0,
  total_rejected_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
  
  -- === PERFORMANCE RATES ===
  payment_rate               NUMERIC(5,2) NOT NULL DEFAULT 0,
  rejection_rate             NUMERIC(5,2) NOT NULL DEFAULT 0,
  avg_processing_days        NUMERIC(5,2) NOT NULL DEFAULT 0,
  
  -- === AUDIT TIMESTAMPS ===
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- === CONSTRAINTS ===
  CONSTRAINT uq_payer_performance UNIQUE (payer_ref_id, month_bucket),
  CONSTRAINT ck_payer_performance_amounts CHECK (
    total_submitted_amount >= 0 AND 
    total_paid_amount >= 0 AND
    total_rejected_amount >= 0
  ),
  CONSTRAINT ck_payer_performance_rates CHECK (
    payment_rate >= 0 AND payment_rate <= 100 AND
    rejection_rate >= 0 AND rejection_rate <= 100
  )
);

COMMENT ON TABLE claims.payer_performance_summary IS 'Payer performance metrics - ONE ROW PER PAYER PER MONTH';
COMMENT ON COLUMN claims.payer_performance_summary.payer_ref_id IS 'Reference to payer master data';
COMMENT ON COLUMN claims.payer_performance_summary.month_bucket IS 'Month bucket for performance tracking';
COMMENT ON COLUMN claims.payer_performance_summary.payment_rate IS 'Payment rate percentage (0-100)';
COMMENT ON COLUMN claims.payer_performance_summary.rejection_rate IS 'Rejection rate percentage (0-100)';

CREATE INDEX IF NOT EXISTS idx_payer_performance_payer ON claims.payer_performance_summary(payer_ref_id);
CREATE INDEX IF NOT EXISTS idx_payer_performance_month ON claims.payer_performance_summary(month_bucket);
CREATE INDEX IF NOT EXISTS idx_payer_performance_rates ON claims.payer_performance_summary(payment_rate, rejection_rate);


-- ==========================================================================================================
-- SECTION 8: RESUBMISSION AND CONTRACTS
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- 8.1 CLAIM RESUBMISSION
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.claim_resubmission (
  id                 BIGSERIAL PRIMARY KEY,
  claim_event_id     BIGINT NOT NULL REFERENCES claims.claim_event(id) ON DELETE RESTRICT,
  resubmission_type  TEXT NOT NULL,
  comment            TEXT NOT NULL,
  attachment         BYTEA,
  tx_at              TIMESTAMPTZ NOT NULL,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_claim_resubmission_event UNIQUE (claim_event_id)
);

COMMENT ON TABLE claims.claim_resubmission IS 'Resubmission information for claims';

CREATE INDEX IF NOT EXISTS idx_claim_resubmission_type ON claims.claim_resubmission(resubmission_type);


-- ----------------------------------------------------------------------------------------------------------
-- 8.2 CLAIM CONTRACT
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.claim_contract (
  id           BIGSERIAL PRIMARY KEY,
  claim_id     BIGINT NOT NULL REFERENCES claims.claim(id) ON DELETE CASCADE,
  package_name TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.claim_contract IS 'Contract information for claims';

CREATE INDEX IF NOT EXISTS idx_claim_contract_claim ON claims.claim_contract(claim_id);


-- ----------------------------------------------------------------------------------------------------------
-- 8.3 CLAIM ATTACHMENT
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.claim_attachment (
  id             BIGSERIAL PRIMARY KEY,
  claim_key_id   BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE CASCADE,
  claim_event_id BIGINT NOT NULL REFERENCES claims.claim_event(id) ON DELETE CASCADE,
  file_name      TEXT,
  mime_type      TEXT,
  data_base64    BYTEA NOT NULL,
  data_length    INTEGER,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.claim_attachment IS 'Attachments for claims';

CREATE INDEX IF NOT EXISTS idx_claim_attachment_key ON claims.claim_attachment(claim_key_id);
CREATE INDEX IF NOT EXISTS idx_claim_attachment_event ON claims.claim_attachment(claim_event_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_claim_attachment_key_event_file ON claims.claim_attachment(claim_key_id, claim_event_id, COALESCE(file_name, ''));

-- ----------------------------------------------------------------------------------------------------------
-- 8.4 EVENT OBSERVATION
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.event_observation (
  id                        BIGSERIAL PRIMARY KEY,
  claim_event_activity_id   BIGINT NOT NULL REFERENCES claims.claim_event_activity(id) ON DELETE CASCADE,
  obs_type                  TEXT NOT NULL,
  obs_code                  TEXT NOT NULL,
  value_text                TEXT,
  value_type                TEXT,
  file_bytes                BYTEA,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.event_observation IS 'Observations at claim event time';

CREATE INDEX IF NOT EXISTS idx_event_observation_activity ON claims.event_observation(claim_event_activity_id);
CREATE INDEX IF NOT EXISTS idx_event_observation_type ON claims.event_observation(obs_type);
CREATE INDEX IF NOT EXISTS idx_event_observation_code ON claims.event_observation(obs_code);

-- ==========================================================================================================
-- SECTION 9: VERIFICATION AND AUDIT
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- 9.1 CODE DISCOVERY AUDIT
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.code_discovery_audit (
  id                 BIGSERIAL PRIMARY KEY,
  discovered_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  source_table       TEXT NOT NULL,
  code               TEXT NOT NULL,
  code_system        TEXT,
  discovered_by      TEXT NOT NULL DEFAULT 'SYSTEM',
  ingestion_file_id  BIGINT REFERENCES claims.ingestion_file(id) ON DELETE SET NULL,
  claim_external_id  TEXT,
  details            JSONB NOT NULL DEFAULT '{}'
);

COMMENT ON TABLE claims.code_discovery_audit IS 'Audit trail for discovered codes';

CREATE INDEX IF NOT EXISTS idx_code_discovery_audit_source ON claims.code_discovery_audit(source_table);
CREATE INDEX IF NOT EXISTS idx_code_discovery_audit_code ON claims.code_discovery_audit(code);
CREATE INDEX IF NOT EXISTS idx_code_discovery_audit_discovered ON claims.code_discovery_audit(discovered_at);

-- ----------------------------------------------------------------------------------------------------------
-- 9.2 VERIFICATION RULE
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.verification_rule (
  id          BIGSERIAL PRIMARY KEY,
  code        TEXT NOT NULL,
  description TEXT NOT NULL,
  severity    SMALLINT NOT NULL,
  sql_text    TEXT NOT NULL,
  active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_verification_rule_code UNIQUE (code)
);

COMMENT ON TABLE claims.verification_rule IS 'Data verification rules';

CREATE INDEX IF NOT EXISTS idx_verification_rule_active ON claims.verification_rule(active);
CREATE INDEX IF NOT EXISTS idx_verification_rule_severity ON claims.verification_rule(severity);

-- ----------------------------------------------------------------------------------------------------------
-- 9.3 VERIFICATION RUN
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.verification_run (
  id                 BIGSERIAL PRIMARY KEY,
  ingestion_file_id  BIGINT NOT NULL REFERENCES claims.ingestion_file(id) ON DELETE RESTRICT,
  started_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at           TIMESTAMPTZ,
  passed             BOOLEAN,
  failed_rules       INTEGER NOT NULL DEFAULT 0
);

COMMENT ON TABLE claims.verification_run IS 'Verification run results';

CREATE INDEX IF NOT EXISTS idx_verification_run_file ON claims.verification_run(ingestion_file_id);
CREATE INDEX IF NOT EXISTS idx_verification_run_started ON claims.verification_run(started_at);

-- ----------------------------------------------------------------------------------------------------------
-- 9.4 VERIFICATION RESULT
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.verification_result (
  id                 BIGSERIAL PRIMARY KEY,
  verification_run_id BIGINT NOT NULL REFERENCES claims.verification_run(id) ON DELETE CASCADE,
  rule_id            BIGINT NOT NULL REFERENCES claims.verification_rule(id) ON DELETE RESTRICT,
  ok                 BOOLEAN NOT NULL,
  rows_affected      BIGINT,
  sample_json        JSONB,
  message            TEXT,
  executed_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.verification_result IS 'Individual verification rule results';

CREATE INDEX IF NOT EXISTS idx_verification_result_run ON claims.verification_result(verification_run_id, rule_id);
CREATE INDEX IF NOT EXISTS idx_verification_result_ok ON claims.verification_result(ok);

-- ==========================================================================================================
-- SECTION 10: INGESTION RUN TRACKING
-- ==========================================================================================================

-- ----------------------------------------------------------------------------------------------------------
-- 10.1 INGESTION RUN
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.ingestion_run (
  id                   BIGSERIAL PRIMARY KEY,
  started_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at             TIMESTAMPTZ,
  profile              TEXT NOT NULL,
  fetcher_name         TEXT NOT NULL,
  acker_name           TEXT,
  poll_reason          TEXT,
  files_discovered     INTEGER NOT NULL DEFAULT 0,
  files_pulled         INTEGER NOT NULL DEFAULT 0,
  files_processed_ok   INTEGER NOT NULL DEFAULT 0,
  files_failed         INTEGER NOT NULL DEFAULT 0,
  files_already        INTEGER NOT NULL DEFAULT 0,
  acks_sent            INTEGER NOT NULL DEFAULT 0
);

COMMENT ON TABLE claims.ingestion_run IS 'Ingestion run tracking';

CREATE INDEX IF NOT EXISTS idx_ingestion_run_started ON claims.ingestion_run(started_at);
CREATE INDEX IF NOT EXISTS idx_ingestion_run_profile ON claims.ingestion_run(profile);

-- ----------------------------------------------------------------------------------------------------------
-- 10.2 INGESTION FILE AUDIT
-- ----------------------------------------------------------------------------------------------------------
-- ----------------------------------------------------------------------------------------------------------
-- 10.2 INGESTION FILE AUDIT
-- ----------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS claims.ingestion_file_audit (
  id                          BIGSERIAL PRIMARY KEY,
  ingestion_run_id            BIGINT NOT NULL REFERENCES claims.ingestion_run(id) ON DELETE CASCADE,
  ingestion_file_id           BIGINT NOT NULL REFERENCES claims.ingestion_file(id) ON DELETE CASCADE,
  status                      SMALLINT NOT NULL,
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
  projected_events            INTEGER,
  projected_status_rows       INTEGER,
  verification_failed_count   INTEGER,
  ack_attempted               BOOLEAN,
  ack_sent                    BOOLEAN,
  pipeline_success            BOOLEAN,
  duration_ms                 BIGINT,
  file_size_bytes             BIGINT,
  processing_mode             VARCHAR(50),
  worker_thread               VARCHAR(255),
  total_gross_amount          NUMERIC(19, 4),
  total_net_amount            NUMERIC(19, 4),
  total_patient_share         NUMERIC(19, 4),
  unique_payers               INTEGER,
  unique_providers             INTEGER,
  created_at                  TIMESTAMPTZ DEFAULT NOW(),
  verification_passed         BOOLEAN,
  CONSTRAINT uq_ingestion_file_audit UNIQUE (ingestion_run_id, ingestion_file_id)
);

COMMENT ON TABLE claims.ingestion_file_audit IS 'Audit trail for ingestion file processing';

-- Column comments
COMMENT ON COLUMN claims.ingestion_file_audit.parsed_diagnoses IS 'Number of diagnoses parsed from the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.persisted_diagnoses IS 'Number of diagnoses successfully persisted to the database.';
COMMENT ON COLUMN claims.ingestion_file_audit.parsed_encounters IS 'Number of encounters parsed from the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.persisted_encounters IS 'Number of encounters successfully persisted to the database.';
COMMENT ON COLUMN claims.ingestion_file_audit.parsed_observations IS 'Number of observations parsed from the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.persisted_observations IS 'Number of observations successfully persisted to the database.';
COMMENT ON COLUMN claims.ingestion_file_audit.parsed_remit_claims IS 'Number of remittance claims parsed from the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.persisted_remit_claims IS 'Number of remittance claims successfully persisted to the database.';
COMMENT ON COLUMN claims.ingestion_file_audit.parsed_remit_activities IS 'Number of remittance activities parsed from the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.persisted_remit_activities IS 'Number of remittance activities successfully persisted to the database.';
COMMENT ON COLUMN claims.ingestion_file_audit.projected_events IS 'Number of claim events projected (submission/resubmission/remittance).';
COMMENT ON COLUMN claims.ingestion_file_audit.projected_status_rows IS 'Number of claim status timeline rows projected.';
COMMENT ON COLUMN claims.ingestion_file_audit.duration_ms IS 'Total time taken to process the file in milliseconds.';
COMMENT ON COLUMN claims.ingestion_file_audit.file_size_bytes IS 'Size of the XML file in bytes.';
COMMENT ON COLUMN claims.ingestion_file_audit.processing_mode IS 'Mode of processing (e.g., file, memory).';
COMMENT ON COLUMN claims.ingestion_file_audit.worker_thread IS 'Name of the worker thread that processed the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.total_gross_amount IS 'Sum of gross amounts from all claims in the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.total_net_amount IS 'Sum of net amounts from all claims in the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.total_patient_share IS 'Sum of patient share amounts from all claims in the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.unique_payers IS 'Number of unique payers in the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.unique_providers IS 'Number of unique providers in the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.ack_sent IS 'True if an acknowledgment was sent for the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.pipeline_success IS 'True if the pipeline processing completed successfully.';
COMMENT ON COLUMN claims.ingestion_file_audit.verification_failed_count IS 'Number of verification failures detected for the file.';
COMMENT ON COLUMN claims.ingestion_file_audit.created_at IS 'Timestamp when the audit record was created.';
COMMENT ON COLUMN claims.ingestion_file_audit.verification_passed IS 'True if post-persistence verification succeeded.';

CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_run ON claims.ingestion_file_audit(ingestion_run_id);
CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_file ON claims.ingestion_file_audit(ingestion_file_id);
CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_status ON claims.ingestion_file_audit(status);
CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_validation ON claims.ingestion_file_audit(validation_ok);
CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_duration ON claims.ingestion_file_audit(duration_ms) WHERE duration_ms IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ingestion_file_audit_verification ON claims.ingestion_file_audit(verification_passed) WHERE verification_passed IS NOT NULL;
-- ==========================================================================================================
-- SECTION 11: PERMISSIONS AND GRANTS
-- ==========================================================================================================

-- Grant permissions to claims_user role
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA claims TO claims_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA claims TO claims_user;

-- ==========================================================================================================
-- END OF CORE TABLES
-- ==========================================================================================================
