-- ==========================================================================================================
-- CORE CLAIMS TABLES - MAIN PROCESSING SCHEMA
-- ==========================================================================================================
-- 
-- Purpose: Create all core claims processing tables
-- Version: 1.0
-- Date: 2025-01-15
-- 
-- This script creates the main claims processing tables including:
-- - Ingestion and file management tables
-- - Claim submission and processing tables
-- - Remittance processing tables
-- - Event tracking and audit tables
-- - Verification and monitoring tables
--
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
-- SECTION 1: INGESTION AND FILE MANAGEMENT
-- ==========================================================================================================

-- Ingestion file tracking
CREATE TABLE IF NOT EXISTS claims.ingestion_file (
  id                     BIGSERIAL PRIMARY KEY,
  file_id                TEXT NOT NULL,
  file_name              TEXT,
  root_type              SMALLINT NOT NULL CHECK (root_type IN (1,2)),
  sender_id              TEXT NOT NULL,
  receiver_id            TEXT NOT NULL,
  transaction_date       TIMESTAMPTZ NOT NULL,
  record_count           INTEGER NOT NULL,
  disposition_flag       TEXT NOT NULL,
  raw_xml                TEXT NOT NULL,
  status                 SMALLINT NOT NULL DEFAULT 0,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_ingestion_file_id UNIQUE (file_id)
);

COMMENT ON TABLE claims.ingestion_file IS 'Raw XML files ingested into the system';
COMMENT ON COLUMN claims.ingestion_file.root_type IS '1=Claim.Submission, 2=Remittance.Advice';
COMMENT ON COLUMN claims.ingestion_file.status IS '0=PENDING, 1=PROCESSED, 2=FAILED';

-- Ingestion errors
CREATE TABLE IF NOT EXISTS claims.ingestion_error (
  id                 BIGSERIAL PRIMARY KEY,
  ingestion_file_id  BIGINT NOT NULL REFERENCES claims.ingestion_file(id) ON DELETE CASCADE,
  stage              TEXT NOT NULL,
  object_type        TEXT,
  object_key         TEXT,
  error_code         TEXT NOT NULL,
  error_message      TEXT NOT NULL,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.ingestion_error IS 'Detailed error log for ingestion failures';

-- ==========================================================================================================
-- SECTION 2: CLAIM KEY MANAGEMENT
-- ==========================================================================================================

-- Claim key canonical identifier
CREATE TABLE IF NOT EXISTS claims.claim_key (
  id          BIGSERIAL PRIMARY KEY,
  claim_id    TEXT NOT NULL UNIQUE,
  created_at  TIMESTAMPTZ,
  updated_at  TIMESTAMPTZ
);

COMMENT ON TABLE claims.claim_key IS 'Canonical claim identifier mapping';

-- ==========================================================================================================
-- SECTION 3: CLAIM SUBMISSION PROCESSING
-- ==========================================================================================================

-- Submission header
CREATE TABLE IF NOT EXISTS claims.submission (
  id                 BIGSERIAL PRIMARY KEY,
  ingestion_file_id  BIGINT NOT NULL REFERENCES claims.ingestion_file(id) ON DELETE RESTRICT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  tx_at              TIMESTAMPTZ NOT NULL
);

COMMENT ON TABLE claims.submission IS 'Claim submission file header';

-- Main claim record
CREATE TABLE IF NOT EXISTS claims.claim (
  id                 BIGSERIAL PRIMARY KEY,
  claim_key_id       BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE RESTRICT,
  submission_id      BIGINT NOT NULL REFERENCES claims.submission(id) ON DELETE RESTRICT,
  id_payer           TEXT,
  member_id          TEXT,
  payer_id           TEXT NOT NULL,
  provider_id        TEXT NOT NULL,
  emirates_id_number TEXT NOT NULL,
  gross              NUMERIC(15,2) NOT NULL,
  patient_share      NUMERIC(15,2) NOT NULL,
  net                NUMERIC(15,2) NOT NULL,
  payer_ref_id       BIGINT,
  provider_ref_id    BIGINT,
  comments           TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  tx_at              TIMESTAMPTZ,
  CONSTRAINT uq_claim_submission UNIQUE (claim_key_id)
);

COMMENT ON TABLE claims.claim IS 'Main claim record with financial details';

-- Encounter details
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

COMMENT ON TABLE claims.encounter IS 'Patient encounter details';

-- Diagnosis codes
CREATE TABLE IF NOT EXISTS claims.diagnosis (
  id                    BIGSERIAL PRIMARY KEY,
  claim_id              BIGINT NOT NULL REFERENCES claims.claim(id) ON DELETE CASCADE,
  diag_type             TEXT NOT NULL,
  code                  TEXT NOT NULL,
  diagnosis_code_ref_id BIGINT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.diagnosis IS 'Diagnosis codes for encounters';

-- Activity/procedure details
CREATE TABLE IF NOT EXISTS claims.activity (
  id                    BIGSERIAL PRIMARY KEY,
  claim_id              BIGINT NOT NULL REFERENCES claims.claim(id) ON DELETE CASCADE,
  activity_id           TEXT NOT NULL,
  start_at              TIMESTAMPTZ NOT NULL,
  type                  TEXT NOT NULL,
  code                  TEXT NOT NULL,
  quantity              NUMERIC(10,3) NOT NULL,
  net                   NUMERIC(15,2) NOT NULL,
  clinician             TEXT NOT NULL,
  prior_auth_id         TEXT,
  activity_code_ref_id  BIGINT,
  clinician_ref_id      BIGINT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_claim_activity UNIQUE (claim_id, activity_id)
);

COMMENT ON TABLE claims.activity IS 'Medical procedures and services';

-- Activity observations
CREATE TABLE IF NOT EXISTS claims.observation (
  id          BIGSERIAL PRIMARY KEY,
  activity_id BIGINT NOT NULL REFERENCES claims.activity(id) ON DELETE CASCADE,
  obs_type    TEXT NOT NULL,
  obs_code    TEXT NOT NULL,
  value_text  TEXT,
  value_type  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_observation UNIQUE (activity_id, obs_type, obs_code, md5(COALESCE(value_text, '')))
);

COMMENT ON TABLE claims.observation IS 'Clinical observations for activities';

-- ==========================================================================================================
-- SECTION 4: REMITTANCE PROCESSING
-- ==========================================================================================================

-- Remittance header
CREATE TABLE IF NOT EXISTS claims.remittance (
  id                 BIGSERIAL PRIMARY KEY,
  ingestion_file_id  BIGINT NOT NULL REFERENCES claims.ingestion_file(id) ON DELETE RESTRICT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  tx_at              TIMESTAMPTZ NOT NULL
);

COMMENT ON TABLE claims.remittance IS 'Remittance advice file header';

-- Remittance claim details
CREATE TABLE IF NOT EXISTS claims.remittance_claim (
  id                    BIGSERIAL PRIMARY KEY,
  remittance_id         BIGINT NOT NULL REFERENCES claims.remittance(id) ON DELETE RESTRICT,
  claim_key_id          BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE RESTRICT,
  id_payer              TEXT NOT NULL,
  provider_id           TEXT,
  denial_code           TEXT,
  payment_reference     TEXT NOT NULL,
  date_settlement       DATE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_remittance_claim UNIQUE (remittance_id, claim_key_id)
);

COMMENT ON TABLE claims.remittance_claim IS 'Remittance details per claim';

-- Remittance activity details
CREATE TABLE IF NOT EXISTS claims.remittance_activity (
  id                    BIGSERIAL PRIMARY KEY,
  remittance_claim_id   BIGINT NOT NULL REFERENCES claims.remittance_claim(id) ON DELETE CASCADE,
  activity_id           TEXT NOT NULL,
  start_at              TIMESTAMPTZ NOT NULL,
  type                  TEXT NOT NULL,
  code                  TEXT NOT NULL,
  quantity              NUMERIC(10,3) NOT NULL,
  net                   NUMERIC(15,2) NOT NULL,
  gross                 NUMERIC(15,2),
  patient_share         NUMERIC(15,2),
  payment_amount        NUMERIC(15,2) NOT NULL,
  denial_code           TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_remittance_activity UNIQUE (remittance_claim_id, activity_id)
);

COMMENT ON TABLE claims.remittance_activity IS 'Remittance details per activity';

-- ==========================================================================================================
-- SECTION 5: EVENT TRACKING AND AUDIT
-- ==========================================================================================================

-- Claim events
CREATE TABLE IF NOT EXISTS claims.claim_event (
  id                 BIGSERIAL PRIMARY KEY,
  claim_key_id       BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE RESTRICT,
  ingestion_file_id  BIGINT REFERENCES claims.ingestion_file(id) ON DELETE RESTRICT,
  event_time         TIMESTAMPTZ NOT NULL,
  type               SMALLINT NOT NULL,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_claim_event UNIQUE (claim_key_id, type, event_time)
);

COMMENT ON TABLE claims.claim_event IS 'Event stream for claim lifecycle';
COMMENT ON COLUMN claims.claim_event.type IS '1=SUBMISSION, 2=RESUBMISSION, 3=REMITTANCE';

-- Claim event activity snapshots
CREATE TABLE IF NOT EXISTS claims.claim_event_activity (
  id                              BIGSERIAL PRIMARY KEY,
  claim_event_id                  BIGINT NOT NULL REFERENCES claims.claim_event(id) ON DELETE CASCADE,
  activity_id_ref                 BIGINT REFERENCES claims.activity(id) ON DELETE SET NULL,
  remittance_activity_id_ref      BIGINT REFERENCES claims.remittance_activity(id) ON DELETE SET NULL,
  activity_id_at_event            TEXT NOT NULL,
  start_at                        TIMESTAMPTZ NOT NULL,
  type                            TEXT NOT NULL,
  code                            TEXT NOT NULL,
  quantity                        NUMERIC(10,3) NOT NULL,
  net                             NUMERIC(15,2) NOT NULL,
  clinician                       TEXT NOT NULL,
  created_at                      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  tx_at                           TIMESTAMPTZ
);

COMMENT ON TABLE claims.claim_event_activity IS 'Activity state snapshots at event time';

-- Claim status timeline
CREATE TABLE IF NOT EXISTS claims.claim_status_timeline (
  id             BIGSERIAL PRIMARY KEY,
  claim_key_id   BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE CASCADE,
  status         SMALLINT NOT NULL,
  status_time    TIMESTAMPTZ NOT NULL,
  claim_event_id BIGINT REFERENCES claims.claim_event(id) ON DELETE SET NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.claim_status_timeline IS 'Derived claim status timeline';
COMMENT ON COLUMN claims.claim_status_timeline.status IS '1=SUBMITTED, 2=RESUBMITTED, 3=PAID, 4=PARTIALLY_PAID, 5=REJECTED, 6=UNKNOWN';

-- ==========================================================================================================
-- SECTION 5.5: CLAIM PAYMENT AND FINANCIAL TRACKING TABLES
-- ==========================================================================================================

-- Claim payment aggregated financial summary
CREATE TABLE IF NOT EXISTS claims.claim_payment (
  id                         BIGSERIAL PRIMARY KEY,
  claim_key_id               BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE CASCADE,
  
  -- === FINANCIAL SUMMARY (aggregated from all remittances) ===
  total_submitted_amount     NUMERIC(15,2) NOT NULL DEFAULT 0,
  total_paid_amount          NUMERIC(15,2) NOT NULL DEFAULT 0,
  total_remitted_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
  total_rejected_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
  total_denied_amount        NUMERIC(15,2) NOT NULL DEFAULT 0,
  
  -- === ACTIVITY COUNTS ===
  total_activities           INTEGER NOT NULL DEFAULT 0,
  paid_activities            INTEGER NOT NULL DEFAULT 0,
  partially_paid_activities  INTEGER NOT NULL DEFAULT 0,
  rejected_activities        INTEGER NOT NULL DEFAULT 0,
  pending_activities         INTEGER NOT NULL DEFAULT 0,
  
  -- === PAYMENT STATUS ===
  payment_status             VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  
  -- === LIFECYCLE TRACKING ===
  remittance_count           INTEGER NOT NULL DEFAULT 0,
  resubmission_count         INTEGER NOT NULL DEFAULT 0,
  processing_cycles          INTEGER NOT NULL DEFAULT 0,
  
  -- === DATES ===
  first_submission_date      DATE,
  last_submission_date       DATE,
  first_remittance_date      DATE,
  last_remittance_date       DATE,
  first_payment_date         DATE,
  last_payment_date          DATE,
  latest_settlement_date     DATE,
  
  -- === PROCESSING METRICS ===
  days_to_first_payment      INTEGER,
  days_to_final_settlement   INTEGER,
  
  -- === PAYMENT REFERENCES ===
  payment_reference          VARCHAR(100),
  latest_payment_reference   VARCHAR(100),
  
  -- === BUSINESS TRANSACTION TIME ===
  tx_at                      TIMESTAMPTZ NOT NULL,
  
  -- === AUDIT TIMESTAMPS ===
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- === CONSTRAINTS ===
  CONSTRAINT uq_claim_payment_claim_key UNIQUE (claim_key_id),
  CONSTRAINT ck_claim_payment_status CHECK (payment_status IN ('FULLY_PAID', 'PARTIALLY_PAID', 'REJECTED', 'PENDING')),
  CONSTRAINT ck_claim_payment_amounts CHECK (
    total_submitted_amount >= 0 AND 
    total_paid_amount >= 0 AND
    total_remitted_amount >= 0 AND
    total_rejected_amount >= 0 AND
    total_denied_amount >= 0
  ),
  CONSTRAINT ck_claim_payment_activities CHECK (
    total_activities >= 0 AND
    paid_activities >= 0 AND
    partially_paid_activities >= 0 AND
    rejected_activities >= 0 AND
    pending_activities >= 0
  )
);

COMMENT ON TABLE claims.claim_payment IS 'Aggregated financial summary and lifecycle tracking for claims - ONE ROW PER CLAIM';
COMMENT ON COLUMN claims.claim_payment.claim_key_id IS 'Canonical claim identifier';
COMMENT ON COLUMN claims.claim_payment.payment_status IS 'Current payment status: FULLY_PAID, PARTIALLY_PAID, REJECTED, PENDING';
COMMENT ON COLUMN claims.claim_payment.total_submitted_amount IS 'Total amount submitted across all activities';
COMMENT ON COLUMN claims.claim_payment.total_paid_amount IS 'Total amount paid across all remittances';
COMMENT ON COLUMN claims.claim_payment.total_rejected_amount IS 'Total amount rejected/denied';
COMMENT ON COLUMN claims.claim_payment.remittance_count IS 'Number of remittance cycles for this claim';
COMMENT ON COLUMN claims.claim_payment.resubmission_count IS 'Number of resubmissions for this claim';

-- === INDEXES ===
CREATE INDEX IF NOT EXISTS idx_claim_payment_claim_key ON claims.claim_payment(claim_key_id);
CREATE INDEX IF NOT EXISTS idx_claim_payment_status ON claims.claim_payment(payment_status);
CREATE INDEX IF NOT EXISTS idx_claim_payment_tx_at ON claims.claim_payment(tx_at);
CREATE INDEX IF NOT EXISTS idx_claim_payment_dates ON claims.claim_payment(first_submission_date, latest_settlement_date);
CREATE INDEX IF NOT EXISTS idx_claim_payment_settlement ON claims.claim_payment(latest_settlement_date);
CREATE INDEX IF NOT EXISTS idx_claim_payment_amounts ON claims.claim_payment(total_submitted_amount, total_paid_amount);
CREATE INDEX IF NOT EXISTS idx_claim_payment_cycles ON claims.claim_payment(processing_cycles, resubmission_count);

-- === TRIGGERS ===
CREATE TRIGGER trg_claim_payment_updated_at
  BEFORE UPDATE ON claims.claim_payment
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- Claim activity summary (activity-level financial tracking)
CREATE TABLE IF NOT EXISTS claims.claim_activity_summary (
  id                         BIGSERIAL PRIMARY KEY,
  claim_key_id               BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE CASCADE,
  activity_id                TEXT NOT NULL,
  
  -- === FINANCIAL METRICS PER ACTIVITY ===
  submitted_amount           NUMERIC(15,2) NOT NULL DEFAULT 0,
  paid_amount               NUMERIC(15,2) NOT NULL DEFAULT 0,
  rejected_amount           NUMERIC(15,2) NOT NULL DEFAULT 0,
  denied_amount             NUMERIC(15,2) NOT NULL DEFAULT 0,
  
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
  CONSTRAINT ck_activity_status CHECK (activity_status IN ('FULLY_PAID', 'PARTIALLY_PAID', 'REJECTED', 'PENDING')),
  CONSTRAINT ck_activity_amounts CHECK (
    paid_amount >= 0 AND 
    rejected_amount >= 0 AND
    denied_amount >= 0 AND
    submitted_amount >= 0
  )
);

COMMENT ON TABLE claims.claim_activity_summary IS 'Activity-level financial summary and tracking - ONE ROW PER ACTIVITY';
COMMENT ON COLUMN claims.claim_activity_summary.claim_key_id IS 'Canonical claim identifier';
COMMENT ON COLUMN claims.claim_activity_summary.activity_id IS 'Business activity identifier';
COMMENT ON COLUMN claims.claim_activity_summary.activity_status IS 'Activity payment status: FULLY_PAID, PARTIALLY_PAID, REJECTED, PENDING';
COMMENT ON COLUMN claims.claim_activity_summary.denial_codes IS 'Array of denial codes for this activity';

-- === INDEXES ===
CREATE INDEX IF NOT EXISTS idx_activity_summary_claim_key ON claims.claim_activity_summary(claim_key_id);
CREATE INDEX IF NOT EXISTS idx_activity_summary_activity_id ON claims.claim_activity_summary(activity_id);
CREATE INDEX IF NOT EXISTS idx_activity_summary_status ON claims.claim_activity_summary(activity_status);
CREATE INDEX IF NOT EXISTS idx_activity_summary_amounts ON claims.claim_activity_summary(submitted_amount, paid_amount);

-- === TRIGGERS ===
CREATE TRIGGER trg_activity_summary_updated_at
  BEFORE UPDATE ON claims.claim_activity_summary
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- Claim financial timeline (event-based financial history)
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

-- === INDEXES ===
CREATE INDEX IF NOT EXISTS idx_financial_timeline_claim_key ON claims.claim_financial_timeline(claim_key_id);
CREATE INDEX IF NOT EXISTS idx_financial_timeline_date ON claims.claim_financial_timeline(event_date);
CREATE INDEX IF NOT EXISTS idx_financial_timeline_type ON claims.claim_financial_timeline(event_type);
CREATE INDEX IF NOT EXISTS idx_financial_timeline_tx_at ON claims.claim_financial_timeline(tx_at);

-- Payer performance summary (payer performance metrics)
CREATE TABLE IF NOT EXISTS claims.payer_performance_summary (
  id                         BIGSERIAL PRIMARY KEY,
  payer_ref_id               BIGINT NOT NULL REFERENCES claims_ref.payer(id) ON DELETE CASCADE,
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

-- === INDEXES ===
CREATE INDEX IF NOT EXISTS idx_payer_performance_payer ON claims.payer_performance_summary(payer_ref_id);
CREATE INDEX IF NOT EXISTS idx_payer_performance_month ON claims.payer_performance_summary(month_bucket);
CREATE INDEX IF NOT EXISTS idx_payer_performance_rates ON claims.payer_performance_summary(payment_rate, rejection_rate);

-- === TRIGGERS ===
CREATE TRIGGER trg_payer_performance_updated_at
  BEFORE UPDATE ON claims.payer_performance_summary
  FOR EACH ROW EXECUTE FUNCTION claims.set_updated_at();

-- ==========================================================================================================
-- SECTION 5.6: CLAIM PAYMENT TRIGGERS
-- ==========================================================================================================

-- Triggers for automatic claim_payment updates
CREATE TRIGGER trg_update_claim_payment_remittance_claim
  AFTER INSERT OR UPDATE OR DELETE ON claims.remittance_claim
  FOR EACH ROW EXECUTE FUNCTION claims.update_claim_payment_on_remittance_claim();

CREATE TRIGGER trg_update_claim_payment_remittance_activity
  AFTER INSERT OR UPDATE OR DELETE ON claims.remittance_activity
  FOR EACH ROW EXECUTE FUNCTION claims.update_claim_payment_on_remittance_activity();

CREATE TRIGGER trg_update_activity_summary_remittance_activity
  AFTER INSERT OR UPDATE OR DELETE ON claims.remittance_activity
  FOR EACH ROW EXECUTE FUNCTION claims.update_activity_summary_on_remittance_activity();

-- ==========================================================================================================
-- SECTION 6: CLAIM ATTACHMENTS AND RESUBMISSIONS
-- ==========================================================================================================

-- Claim resubmission details
CREATE TABLE IF NOT EXISTS claims.claim_resubmission (
  id                 BIGSERIAL PRIMARY KEY,
  claim_event_id     BIGINT NOT NULL REFERENCES claims.claim_event(id) ON DELETE RESTRICT,
  resubmission_type  TEXT NOT NULL,
  comment            TEXT NOT NULL,
  attachment         BYTEA,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.claim_resubmission IS 'Resubmission details and attachments';

-- Claim contract details
CREATE TABLE IF NOT EXISTS claims.claim_contract (
  id           BIGSERIAL PRIMARY KEY,
  claim_id     BIGINT NOT NULL REFERENCES claims.claim(id) ON DELETE CASCADE,
  package_name TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.claim_contract IS 'Insurance contract/package information';

-- Claim attachments
CREATE TABLE IF NOT EXISTS claims.claim_attachment (
  id             BIGSERIAL PRIMARY KEY,
  claim_key_id   BIGINT NOT NULL REFERENCES claims.claim_key(id) ON DELETE CASCADE,
  claim_event_id BIGINT NOT NULL REFERENCES claims.claim_event(id) ON DELETE CASCADE,
  file_name      TEXT,
  mime_type      TEXT,
  data_base64    BYTEA,
  data_length    INTEGER,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.claim_attachment IS 'File attachments for claims';

-- Event observations
CREATE TABLE IF NOT EXISTS claims.event_observation (
  id                        BIGSERIAL PRIMARY KEY,
  claim_event_activity_id   BIGINT NOT NULL REFERENCES claims.claim_event_activity(id) ON DELETE CASCADE,
  obs_type                  TEXT NOT NULL,
  obs_code                  TEXT NOT NULL,
  value_text                TEXT,
  value_type                TEXT,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  tx_at                     TIMESTAMPTZ
);

COMMENT ON TABLE claims.event_observation IS 'Observation snapshots at event time';

-- ==========================================================================================================
-- SECTION 7: VERIFICATION AND MONITORING
-- ==========================================================================================================

-- Verification rules
CREATE TABLE IF NOT EXISTS claims.verification_rule (
  id          BIGSERIAL PRIMARY KEY,
  code        TEXT NOT NULL,
  description TEXT NOT NULL,
  severity    SMALLINT NOT NULL,
  sql_text    TEXT NOT NULL,
  enabled     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_verification_rule_code UNIQUE (code)
);

COMMENT ON TABLE claims.verification_rule IS 'Configurable verification rules';

-- Verification runs
CREATE TABLE IF NOT EXISTS claims.verification_run (
  id                 BIGSERIAL PRIMARY KEY,
  ingestion_file_id  BIGINT NOT NULL REFERENCES claims.ingestion_file(id) ON DELETE RESTRICT,
  started_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at           TIMESTAMPTZ,
  passed             BOOLEAN,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.verification_run IS 'Verification run tracking';

-- Verification results
CREATE TABLE IF NOT EXISTS claims.verification_result (
  id                 BIGSERIAL PRIMARY KEY,
  verification_run_id BIGINT NOT NULL REFERENCES claims.verification_run(id) ON DELETE CASCADE,
  rule_id            BIGINT NOT NULL REFERENCES claims.verification_rule(id) ON DELETE RESTRICT,
  ok                 BOOLEAN NOT NULL,
  rows_affected      BIGINT,
  error_message      TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.verification_result IS 'Individual verification rule results';

-- Ingestion file audit
CREATE TABLE IF NOT EXISTS claims.ingestion_file_audit (
  id                          BIGSERIAL PRIMARY KEY,
  ingestion_run_id            BIGINT NOT NULL REFERENCES claims.ingestion_run(id) ON DELETE CASCADE,
  ingestion_file_id           BIGINT NOT NULL REFERENCES claims.ingestion_file(id) ON DELETE CASCADE,
  status                      SMALLINT NOT NULL,
  reason                      TEXT,
  claims_parsed               INTEGER NOT NULL DEFAULT 0,
  claims_persisted            INTEGER NOT NULL DEFAULT 0,
  activities_parsed           INTEGER NOT NULL DEFAULT 0,
  activities_persisted        INTEGER NOT NULL DEFAULT 0,
  observations_parsed         INTEGER NOT NULL DEFAULT 0,
  observations_persisted      INTEGER NOT NULL DEFAULT 0,
  encounters_parsed           INTEGER NOT NULL DEFAULT 0,
  encounters_persisted        INTEGER NOT NULL DEFAULT 0,
  diagnoses_parsed            INTEGER NOT NULL DEFAULT 0,
  diagnoses_persisted         INTEGER NOT NULL DEFAULT 0,
  remittance_claims_parsed    INTEGER NOT NULL DEFAULT 0,
  remittance_claims_persisted INTEGER NOT NULL DEFAULT 0,
  remittance_activities_parsed INTEGER NOT NULL DEFAULT 0,
  remittance_activities_persisted INTEGER NOT NULL DEFAULT 0,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.ingestion_file_audit IS 'Per-file audit trail with parsed vs persisted counts';

-- Ingestion run tracking
CREATE TABLE IF NOT EXISTS claims.ingestion_run (
  id                   BIGSERIAL PRIMARY KEY,
  started_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at             TIMESTAMPTZ,
  profile              TEXT NOT NULL,
  fetcher_name         TEXT NOT NULL,
  files_processed      INTEGER NOT NULL DEFAULT 0,
  files_success        INTEGER NOT NULL DEFAULT 0,
  files_failed         INTEGER NOT NULL DEFAULT 0,
  claims_processed     INTEGER NOT NULL DEFAULT 0,
  activities_processed INTEGER NOT NULL DEFAULT 0,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.ingestion_run IS 'Ingestion run summary metrics';

-- Ingestion batch metrics
CREATE TABLE IF NOT EXISTS claims.ingestion_batch_metric (
  id                 BIGSERIAL PRIMARY KEY,
  ingestion_run_id   BIGINT NOT NULL REFERENCES claims.ingestion_run(id) ON DELETE CASCADE,
  batch_number       INTEGER NOT NULL,
  batch_size         INTEGER NOT NULL,
  processing_time_ms BIGINT NOT NULL,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE claims.ingestion_batch_metric IS 'Performance metrics per processing batch';

-- Code discovery audit
CREATE TABLE IF NOT EXISTS claims.code_discovery_audit (
  id                 BIGSERIAL PRIMARY KEY,
  discovered_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  source_table       TEXT NOT NULL,
  code               TEXT NOT NULL,
  code_system        TEXT,
  description        TEXT,
  ingestion_file_id  BIGINT REFERENCES claims.ingestion_file(id) ON DELETE SET NULL
);

COMMENT ON TABLE claims.code_discovery_audit IS 'Audit trail for discovered reference codes';

-- ==========================================================================================================
-- SECTION 8: INDEXES FOR PERFORMANCE
-- ==========================================================================================================

-- Ingestion file indexes
CREATE INDEX IF NOT EXISTS idx_ingestion_file_status ON claims.ingestion_file(status);
CREATE INDEX IF NOT EXISTS idx_ingestion_file_created ON claims.ingestion_file(created_at);
CREATE INDEX IF NOT EXISTS idx_ingestion_file_transaction_date ON claims.ingestion_file(transaction_date);

-- Claim indexes
CREATE INDEX IF NOT EXISTS idx_claim_payer_id ON claims.claim(payer_id);
CREATE INDEX IF NOT EXISTS idx_claim_provider_id ON claims.claim(provider_id);
CREATE INDEX IF NOT EXISTS idx_claim_created_at ON claims.claim(created_at);
CREATE INDEX IF NOT EXISTS idx_claim_tx_at ON claims.claim(tx_at);

-- Activity indexes
CREATE INDEX IF NOT EXISTS idx_activity_code ON claims.activity(code);
CREATE INDEX IF NOT EXISTS idx_activity_type ON claims.activity(type);
CREATE INDEX IF NOT EXISTS idx_activity_clinician ON claims.activity(clinician);

-- Remittance indexes
CREATE INDEX IF NOT EXISTS idx_remittance_claim_payer ON claims.remittance_claim(id_payer);
CREATE INDEX IF NOT EXISTS idx_remittance_claim_settlement ON claims.remittance_claim(date_settlement);

-- Event indexes
CREATE INDEX IF NOT EXISTS idx_claim_event_type ON claims.claim_event(type);
CREATE INDEX IF NOT EXISTS idx_claim_event_time ON claims.claim_event(event_time);
CREATE INDEX IF NOT EXISTS idx_claim_status_timeline_status ON claims.claim_status_timeline(status);
CREATE INDEX IF NOT EXISTS idx_claim_status_timeline_time ON claims.claim_status_timeline(status_time);

-- Verification indexes
CREATE INDEX IF NOT EXISTS idx_verification_run_started ON claims.verification_run(started_at);
CREATE INDEX IF NOT EXISTS idx_ingestion_run_started ON claims.ingestion_run(started_at);
