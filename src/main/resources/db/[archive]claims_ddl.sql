-- ============================================================
-- CLAIMS APP — Full Combined DDL (SSOT)
-- Date: 2025-09-05 (IST)
-- Notes / Decisions:
--   • Duplicate SUBMISSION (same Claim/ID) without <Resubmission> is IGNORED.
--     Enforced by: one claims.claim per claim_key_id, and one SUBMISSION claim_event per claim.
--   • StAX/XSD-driven model; amounts are non-negative by CHECKs.
--   • ‘updated_at’ maintained by a single trigger across mutable tables.
--   • Event types centralized via domain.
--   • Inline tags for easy manual verification: [XSD], [PK], [FK], [UQ], [IDX], [CHK], [AUDIT], [EVT], [MON]
-- ============================================================

-- ---------- 0) Extensions ----------
create extension if not exists pg_trgm;
create extension if not exists citext;
create extension if not exists pgcrypto;

-- ---------- 1) Schemas ----------
create schema if not exists claims;
create schema if not exists auth; -- reserved

-- ---------- 2) Roles (runtime app role) ----------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'claims_user') then
    create role claims_user login;
  end if;
end$$ language plpgsql;

-- ---------- 3) Domains / Enums ----------
-- Centralized event type domain: 1=SUBMISSION, 2=RESUBMISSION, 3=REMITTANCE
do $$
begin
  if not exists (select 1 from pg_type where typname = 'claim_event_type') then
    execute 'create domain claims.claim_event_type as smallint check (value in (1,2,3))';
  end if;
end$$;

-- ---------- 4) Audit helper (updated_at) ----------
create or replace function claims.set_updated_at()
returns trigger language plpgsql as $$
begin
  if NEW is distinct from OLD then
    NEW.updated_at := now();
  end if;
  return NEW;
end$$;

-- ============================================================
-- 5) RAW XML SSOT + XSD Header (common to both roots)
--    Root types: 1=Claim.Submission, 2=Remittance.Advice
-- ============================================================
create table if not exists claims.ingestion_file (
  id                     bigserial primary key,                                -- [PK]
  file_id                text not null,                                        -- [UQ] external idempotency
  root_type              smallint not null check (root_type in (1,2)),         -- [CHK]
  -- XSD Header (1..1 for both schemas)
  sender_id              text not null,                                        -- [XSD (1..1)]
  receiver_id            text not null,                                        -- [XSD (1..1)]
  transaction_date       timestamptz not null,                                 -- [XSD (1..1)]
  record_count_declared  int not null check (record_count_declared >= 0),      -- [XSD (1..1)] [CHK]
  disposition_flag       text not null,                                        -- [XSD (1..1)]
  -- Raw XML SSOT
  xml_bytes              bytea not null,                                       -- [SSOT]
  created_at             timestamptz not null default now(),                   -- [AUDIT]
  updated_at             timestamptz not null default now(),                   -- [AUDIT]
  constraint uq_ingestion_file unique (file_id)                                -- [UQ]
);
comment on table claims.ingestion_file is
  'SSOT: raw XML + XSD Header; duplicate files rejected by unique(file_id).';
create index if not exists idx_ing_file_root_type on claims.ingestion_file(root_type); -- [IDX]
create trigger trg_ingestion_file_updated_at
  before update on claims.ingestion_file
  for each row execute function claims.set_updated_at();

-- ============================================================
-- 6) CANONICAL CLAIM KEY (Claim/ID appears in both roots)
-- ============================================================
create table if not exists claims.claim_key (
  id          bigserial primary key,                -- [PK]
  claim_id    text not null unique,                 -- [UQ] canonical business id
  created_at  timestamptz not null default now(),   -- [AUDIT]
  updated_at  timestamptz not null default now()    -- [AUDIT]
);
create trigger trg_claim_key_updated_at
  before update on claims.claim_key
  for each row execute function claims.set_updated_at();

-- ============================================================
-- 7) CLAIM.SUBMISSION graph
-- ============================================================

-- One submission row per file (grouping)
create table if not exists claims.submission (
  id                 bigserial primary key,                                -- [PK]
  ingestion_file_id  bigint not null                                      -- [FK]
    references claims.ingestion_file(id) on delete restrict,
  created_at         timestamptz not null default now(),                  -- [AUDIT]
  updated_at         timestamptz not null default now()                   -- [AUDIT]
);
create index if not exists idx_submission_file on claims.submission(ingestion_file_id); -- [IDX]
create trigger trg_submission_updated_at
  before update on claims.submission
  for each row execute function claims.set_updated_at();

-- Claim (submission)
create table if not exists claims.claim (
  id                 bigserial primary key,                                -- [PK]
  claim_key_id       bigint not null                                       -- [FK]
    references claims.claim_key(id) on delete restrict,
  submission_id      bigint not null                                       -- [FK]
    references claims.submission(id) on delete restrict,
  -- Claim-level fields (XSD)
  id_payer           text,                                                 -- [XSD (0..1)]
  member_id          text,                                                 -- [XSD (0..1)]
  payer_id           text not null,                                        -- [XSD (1..1)]
  provider_id        text not null,                                        -- [XSD (1..1)]
  emirates_id_number text not null,                                        -- [XSD (1..1)]
  gross              numeric(14,2) not null check (gross >= 0),            -- [XSD (1..1)] [CHK]
  patient_share      numeric(14,2) not null check (patient_share >= 0),    -- [XSD (1..1)] [CHK]
  net                numeric(14,2) not null check (net >= 0),              -- [XSD (1..1)] [CHK]
  comments			  text,													-- store comments if found
  created_at         timestamptz not null default now(),                   -- [AUDIT]
  updated_at         timestamptz not null default now(),                   -- [AUDIT]
  -- Idempotency rules:
  --  • Only ONE claims.claim per claim_key_id globally → duplicate SUBMISSION (no <Resubmission>) is ignored by app on conflict.
  --  • Also unique within a submission file.
  constraint uq_claim_per_key unique (claim_key_id),                       -- [UQ]
  constraint uq_claim_submission_claimkey unique (submission_id, claim_key_id) -- [UQ]
);
create index if not exists idx_claim_claim_key   on claims.claim(claim_key_id);       -- [IDX]
create index if not exists idx_claim_payer       on claims.claim(payer_id);           -- [IDX]
create index if not exists idx_claim_provider    on claims.claim(provider_id);        -- [IDX]
create index if not exists idx_claim_member      on claims.claim(member_id);          -- [IDX]
create index if not exists idx_claim_emirates    on claims.claim(emirates_id_number); -- [IDX]
create index if not exists idx_claim_has_comments on claims.claim((comments is not null));

create trigger trg_claim_updated_at
  before update on claims.claim
  for each row execute function claims.set_updated_at();
comment on table claims.claim is
  'Core submission claim; duplicates without <Resubmission> are ignored (one row per claim_key_id).';

-- Encounter (submission)
create table if not exists claims.encounter (
  id                    bigserial primary key,                                -- [PK]
  claim_id              bigint not null                                       -- [FK]
    references claims.claim(id) on delete cascade,
  facility_id           text not null,                                        -- [XSD (1..1)]
  type                  text not null,                                        -- [XSD (1..1)]
  patient_id            text not null,                                        -- [XSD (1..1)]
  start_at              timestamptz not null,                                 -- [XSD (1..1)]
  end_at                timestamptz,                                          -- [XSD (0..1)]
  start_type            text,                                                 -- [XSD (0..1)]
  end_type              text,                                                 -- [XSD (0..1)]
  transfer_source       text,                                                 -- [XSD (0..1)]
  transfer_destination  text,                                                 -- [XSD (0..1)]
  created_at            timestamptz not null default now(),                   -- [AUDIT]
  updated_at            timestamptz not null default now()                    -- [AUDIT]
);
create index if not exists idx_encounter_claim on claims.encounter(claim_id); -- [IDX]
create trigger trg_encounter_updated_at
  before update on claims.encounter
  for each row execute function claims.set_updated_at();

-- Diagnosis (submission)
create table if not exists claims.diagnosis (
  id           bigserial primary key,                          -- [PK]
  claim_id bigint not null                                 -- [FK]
    references claims.claim(id) on delete cascade,
  diag_type    text not null,                                  -- [XSD (1..1)]
  code         text not null,                                  -- [XSD (1..1)]
  created_at   timestamptz not null default now(),             -- [AUDIT]
  updated_at   timestamptz not null default now()              -- [AUDIT]
);
create index if not exists idx_diagnosis_claim on claims.diagnosis(claim_id); -- [IDX]
create index if not exists idx_diagnosis_code on claims.diagnosis(code);
create index if not exists idx_diagnosis_claim_code on claims.diagnosis(claim_id, code);
create unique index if not exists uq_diagnosis_claim_type_code
  on claims.diagnosis (claim_id, diag_type, code);


create trigger trg_diagnosis_updated_at
  before update on claims.diagnosis
  for each row execute function claims.set_updated_at();

-- Activity (submission)
create table if not exists claims.activity (
  id                      bigserial primary key,                                -- [PK]
  claim_id                bigint not null                                       -- [FK]
    references claims.claim(id) on delete cascade,
  activity_id             text not null,                                        -- [XSD (1..1)]
  start_at                timestamptz not null,                                 -- [XSD (1..1)]
  type                    text not null,                                        -- [XSD (1..1)]
  code                    text not null,                                        -- [XSD (1..1)]
  quantity                numeric(14,2) not null check (quantity >= 0),         -- [XSD (1..1)] [CHK]
  net                     numeric(14,2) not null check (net >= 0),              -- [XSD (1..1)] [CHK]
  clinician               text not null,                                        -- [XSD (1..1)]
  prior_authorization_id  text,                                                 -- [XSD (0..1)]
  created_at              timestamptz not null default now(),                   -- [AUDIT]
  updated_at              timestamptz not null default now(),                   -- [AUDIT]
  constraint uq_activity_bk unique (claim_id, activity_id)                      -- [UQ]
);
create index if not exists idx_activity_claim     on claims.activity(claim_id);      -- [IDX]
create index if not exists idx_activity_clinician on claims.activity(clinician);     -- [IDX]
create index if not exists idx_activity_code      on claims.activity(code);          -- [IDX]
create index if not exists idx_activity_type      on claims.activity(type);          -- [IDX]
create index if not exists idx_activity_start     on claims.activity(start_at);      -- [IDX]
create trigger trg_activity_updated_at
  before update on claims.activity
  for each row execute function claims.set_updated_at();

-- Observation (on submission activity)
create table if not exists claims.observation (
  id           bigserial primary key,                                  -- [PK]
  activity_id  bigint not null                                         -- [FK]
    references claims.activity(id) on delete cascade,
  obs_type     text not null,                                          -- [XSD (1..1)]
  obs_code     text not null,                                          -- [XSD (1..1)]
  value_text   text,                                                   -- [XSD (0..1)]
  value_type   text,                                                   -- [XSD (0..1)]
  file_bytes   bytea,													-- to store file bytes if obs_type is file
  created_at   timestamptz not null default now(),                     -- [AUDIT]
  updated_at   timestamptz not null default now()                      -- [AUDIT]
);
-- Unique de-dup index on semantic content (md5(value_text))
--create unique index if not exists uq_observation_dedup
--  on claims.observation (activity_id, obs_type, obs_code, (pg_catalog.md5(coalesce(value_text,'')))); -- [UQ]
create index if not exists idx_obs_activity on claims.observation(activity_id); -- [IDX]
create index if not exists idx_obs_nonfile on claims.observation(activity_id) where file_bytes is null;

create trigger trg_observation_updated_at
  before update on claims.observation
  for each row execute function claims.set_updated_at();

-- Optional Contract (submission)
create table if not exists claims.claim_contract (
  id               bigserial primary key,                                -- [PK]
  claim_id         bigint not null                                       -- [FK]
    references claims.claim(id) on delete cascade,
  package_name     text,                                                 -- [XSD (0..1)]
  created_at       timestamptz not null default now(),                   -- [AUDIT]
  updated_at       timestamptz not null default now()                    -- [AUDIT]
);
create trigger trg_claim_contract_updated_at
  before update on claims.claim_contract
  for each row execute function claims.set_updated_at();

-- Resubmission (1:1 with RESUBMISSION event) — FK added later
create table if not exists claims.claim_resubmission (
  id                 bigserial primary key,                                -- [PK]
  claim_event_id     bigint not null unique,                               -- [UQ] [FK LATER]
  resubmission_type  text not null,                                        -- [XSD (1..1)]
  comment            text not null,                                        -- [XSD (1..1)]
  attachment         bytea,                                                 -- [XSD (0..1)] (metadata or ref; binary via claim_attachment)
  created_at         timestamptz not null default now(),                   -- [AUDIT]
  updated_at         timestamptz not null default now()                    -- [AUDIT]
);
create trigger trg_claim_resubmission_updated_at
  before update on claims.claim_resubmission
  for each row execute function claims.set_updated_at();

-- ============================================================
-- 8) REMITTANCE.ADVICE graph
-- ============================================================

-- One remittance row per file (grouping)
create table if not exists claims.remittance (
  id                 bigserial primary key,                                -- [PK]
  ingestion_file_id  bigint not null                                       -- [FK]
    references claims.ingestion_file(id) on delete restrict,
  created_at         timestamptz not null default now(),                   -- [AUDIT]
  updated_at         timestamptz not null default now()                    -- [AUDIT]
);
create index if not exists idx_remittance_file on claims.remittance(ingestion_file_id); -- [IDX]
create trigger trg_remittance_updated_at
  before update on claims.remittance
  for each row execute function claims.set_updated_at();

-- Remittance Claim (per-claim adjudication)
create table if not exists claims.remittance_claim (
  id                 bigserial primary key,                                -- [PK]
  remittance_id      bigint not null                                       -- [FK]
    references claims.remittance(id) on delete cascade,
  claim_key_id       bigint not null                                       -- [FK] why reference claim_key(id) and not claim(id)?
    references claims.claim_key(id) on delete restrict,
  id_payer           text not null,                                        -- [XSD (1..1)]
  provider_id        text,                                                 -- [XSD (0..1)]
  denial_code        text,                                                 -- [XSD (0..1)]
  payment_reference  text not null,                                        -- [XSD (1..1)]
  date_settlement    timestamptz,                                          -- [XSD (0..1)]
  facility_id        text,                                                 -- [XSD (0..1)] stored here
  created_at         timestamptz not null default now(),                   -- [AUDIT]
  updated_at         timestamptz not null default now(),                   -- [AUDIT]
  constraint uq_remittance_claim unique (remittance_id, claim_key_id)      -- [UQ]
);
create index if not exists idx_remit_claim_key      on claims.remittance_claim(claim_key_id);    -- [IDX]
create index if not exists idx_remit_claim_provider on claims.remittance_claim(provider_id);     -- [IDX]
create index if not exists idx_remit_claim_denial   on claims.remittance_claim(denial_code);     -- [IDX]
create index if not exists idx_remit_claim_settle   on claims.remittance_claim(date_settlement); -- [IDX]
create trigger trg_remittance_claim_updated_at
  before update on claims.remittance_claim
  for each row execute function claims.set_updated_at();

-- Remittance Activity (per activity within that claim)
create table if not exists claims.remittance_activity (
  id                      bigserial primary key,                                -- [PK]
  remittance_claim_id     bigint not null                                       -- [FK]
    references claims.remittance_claim(id) on delete cascade,
  activity_id             text not null,                                        -- [XSD (1..1)]
  start_at                timestamptz not null,                                 -- [XSD (1..1)]
  type                    text not null,                                        -- [XSD (1..1)]
  code                    text not null,                                        -- [XSD (1..1)]
  quantity                numeric(14,2) not null check (quantity >= 0),         -- [XSD (1..1)] [CHK]
  net                     numeric(14,2) not null check (net >= 0),              -- [XSD (1..1)] [CHK]
  list_price              numeric(14,2) check (list_price is null or list_price >= 0), -- [XSD (0..1)] [CHK]
  clinician               text not null,                                        -- [XSD (1..1)]
  prior_authorization_id  text,                                                 -- [XSD (0..1)]
  gross                   numeric(14,2) check (gross is null or gross >= 0),    -- [XSD (0..1)] [CHK]
  patient_share           numeric(14,2) check (patient_share is null or patient_share >= 0), -- [XSD (0..1)] [CHK]
  payment_amount          numeric(14,2) not null check (payment_amount >= 0),   -- [XSD (1..1)] [CHK]
  denial_code             text,                                                 -- [XSD (0..1)]
  created_at              timestamptz not null default now(),                   -- [AUDIT]
  updated_at              timestamptz not null default now(),                   -- [AUDIT]
  constraint uq_remittance_activity unique (remittance_claim_id, activity_id)   -- [UQ]
);
create index if not exists idx_remit_act_claim     on claims.remittance_activity(remittance_claim_id); -- [IDX]
create index if not exists idx_remit_act_clinician on claims.remittance_activity(clinician);           -- [IDX]
create index if not exists idx_remit_act_code      on claims.remittance_activity(code);                -- [IDX]
create index if not exists idx_remit_act_type      on claims.remittance_activity(type);                -- [IDX]
create index if not exists idx_remit_act_start     on claims.remittance_activity(start_at);            -- [IDX]
create trigger trg_remittance_activity_updated_at
  before update on claims.remittance_activity
  for each row execute function claims.set_updated_at();

-- ============================================================
-- 9) EVENTS / SNAPSHOTS / TIMELINE
-- ============================================================

-- Event stream over claims
create table if not exists claims.claim_event (
  id                 bigserial primary key,                                -- [PK]
  claim_key_id       bigint not null                                       -- [FK]
    references claims.claim_key(id) on delete restrict,
  ingestion_file_id  bigint                                                -- [FK] provenance to exact file
    references claims.ingestion_file(id) on delete set null,
  event_time         timestamptz not null,                                 -- [EVT]
  type               claims.claim_event_type not null,                     -- [EVT]
  submission_id      bigint,                                               -- [FK LATER]
  remittance_id      bigint,                                               -- [FK LATER]
  created_at         timestamptz not null default now()                    -- [AUDIT]
);
-- Exactly one SUBMISSION event per claim (ignores repeats)
create unique index if not exists uq_claim_event_one_submission
  on claims.claim_event (claim_key_id)
  where type = 1;                                                          -- [UQ]
-- Dedupe guard (per type + time)
create unique index if not exists uq_claim_event_dedup
  on claims.claim_event (claim_key_id, type, event_time);                  -- [UQ]
create index if not exists idx_event_claim_key on claims.claim_event(claim_key_id); -- [IDX]
create index if not exists idx_event_time      on claims.claim_event(event_time);   -- [IDX]

-- Activity snapshots at event time
create table if not exists claims.claim_event_activity (
  id                             bigserial primary key,                                -- [PK]
  claim_event_id                 bigint not null                                       -- [FK]
    references claims.claim_event(id) on delete cascade,
  activity_id_ref                bigint                                                -- [FK]
    references claims.activity(id) on delete set null,
  remittance_activity_id_ref     bigint                                                -- [FK]
    references claims.remittance_activity(id) on delete set null,
  activity_id_at_event           text not null,                                        -- [EVT]
  start_at_event                 timestamptz not null,                                 -- [EVT]
  type_at_event                  text not null,                                        -- [EVT]
  code_at_event                  text not null,                                        -- [EVT]
  quantity_at_event              numeric(14,2) not null,                               -- [EVT]
  net_at_event                   numeric(14,2) not null,                               -- [EVT]
  clinician_at_event             text not null,                                        -- [EVT]
  prior_authorization_id_at_event text,                                                -- [EVT]
  -- Remittance-only snapshot fields
  list_price_at_event            numeric(14,2),
  gross_at_event                 numeric(14,2),
  patient_share_at_event         numeric(14,2),
  payment_amount_at_event        numeric(14,2),
  denial_code_at_event           text,
  created_at                     timestamptz not null default now()                    -- [AUDIT]
);
create unique index if not exists uq_cea_event_activity
  on claims.claim_event_activity (claim_event_id, activity_id_at_event);              -- [UQ]
create index if not exists idx_cea_event on claims.claim_event_activity(claim_event_id); -- [IDX]

-- Observations tied to an event snapshot
create table if not exists claims.event_observation (
  id                         bigserial primary key,                                  -- [PK]
  claim_event_activity_id    bigint not null                                         -- [FK]
    references claims.claim_event_activity(id) on delete cascade,
  obs_type                   text not null,                                          -- [EVT]
  obs_code                   text not null,                                          -- [EVT]
  value_text                 text,                                                   -- [EVT]
  value_type                 text,                                                   -- [EVT]
  file_bytes				bytea,       -- of type is FILE, then store B64 decoded
  created_at                 timestamptz not null default now()                      -- [AUDIT]
);
create index if not exists idx_event_obs_cea on claims.event_observation(claim_event_activity_id); -- [IDX]

-- Derived status timeline
create table if not exists claims.claim_status_timeline (
  id             bigserial primary key,                                -- [PK]
  claim_key_id   bigint not null                                       -- [FK]
    references claims.claim_key(id) on delete cascade,
  status         smallint not null,                                    -- [EVT] 1=SUBMITTED,2=RESUBMITTED,3=PAID,4=PARTIALLY_PAID,5=REJECTED,6=UNKNOWN
  status_time    timestamptz not null,                                 -- [EVT] -- this should reflect either of transactiondate from submission or remittance
  claim_event_id bigint                                                -- [FK]
    references claims.claim_event(id) on delete set null,
  created_at     timestamptz not null default now()                    -- [AUDIT]
);
create index if not exists idx_cst_claim_key_time on claims.claim_status_timeline(claim_key_id, status_time); -- [IDX]

-- Cross-object FKs added now that targets exist
alter table claims.claim_event
  add constraint fk_claim_event_submission
  foreign key (submission_id) references claims.submission(id) on delete set null;

alter table claims.claim_event
  add constraint fk_claim_event_remittance
  foreign key (remittance_id) references claims.remittance(id) on delete set null;

alter table claims.claim_resubmission
  add constraint fk_resubmission_event
  foreign key (claim_event_id) references claims.claim_event(id) on delete cascade;

-- ============================================================
-- 10) ATTACHMENTS (decoded binary; metadata is optional)
-- ============================================================
create table if not exists claims.claim_attachment (
  id             bigserial primary key,                                -- [PK]
  claim_key_id   bigint not null                                       -- [FK]
    references claims.claim_key(id) on delete cascade,
  claim_event_id bigint not null                                       -- [FK]
    references claims.claim_event(id) on delete cascade,
  file_name      text,                                                 -- [XSD (0..1)]
  mime_type      text,                                                 -- [XSD (0..1)]
  data_base64    bytea not null,                                       -- [BIN] decoded binary payload (name retained)
  data_length    int,                                                  -- [OPT]
  created_at     timestamptz not null default now()                    -- [AUDIT]
);
create unique index if not exists uq_claim_attachment_key_event_file
  on claims.claim_attachment (claim_key_id, claim_event_id, coalesce(file_name,'')); -- [UQ]
comment on table claims.claim_attachment is
  'Binary attachments for claims (decoded); unique per (claim, event, filename)';
comment on column claims.claim_attachment.data_base64 is
  'DECODED binary data (not base64 text).';

-- ============================================================
-- 11) INGESTION MONITORING & VERIFICATION (operational layer)
-- ============================================================

-- Orchestrator run summary (per poll)
create table if not exists claims.ingestion_run (
  id                 bigserial primary key,                                -- [PK] [MON]
  started_at         timestamptz not null default now(),                   -- [MON]
  ended_at           timestamptz,                                          -- [MON]
  profile            text not null,                                        -- [MON]
  fetcher_name       text not null,                                        -- [MON]
  acker_name         text,                                                 -- [MON]
  poll_reason        text,                                                 -- [MON]
  files_discovered   int not null default 0,                                -- [MON]
  files_pulled       int not null default 0,                                -- [MON]
  files_processed_ok int not null default 0,                                -- [MON]
  files_failed       int not null default 0,                                -- [MON]
  files_already      int not null default 0,                                -- [MON]
  acks_sent          int not null default 0                                 -- [MON]
);

-- Per-file audit + counters
create table if not exists claims.ingestion_file_audit (
  id                          bigserial primary key,                        -- [PK] [MON]
  ingestion_run_id            bigint not null                               -- [FK]
    references claims.ingestion_run(id) on delete cascade,
  ingestion_file_id           bigint not null                               -- [FK]
    references claims.ingestion_file(id) on delete cascade,
  status                      smallint not null,                            -- [MON] 0=ALREADY,1=OK,2=FAIL
  reason                      text,                                         -- [MON]
  error_class                 text,                                         -- [MON]
  error_message               text,                                         -- [MON]
  validation_ok               boolean not null default false,               -- [MON]
  header_sender_id            text not null,                                -- [MON]
  header_receiver_id          text not null,                                -- [MON]
  header_transaction_date     timestamptz not null,                         -- [MON]
  header_record_count         int not null,                                 -- [MON]
  header_disposition_flag     text not null,                                -- [MON]
  parsed_claims               int default 0,                                -- [MON]
  parsed_encounters           int default 0,                                -- [MON]
  parsed_diagnoses            int default 0,                                -- [MON]
  parsed_activities           int default 0,                                -- [MON]
  parsed_observations         int default 0,                                -- [MON]
  persisted_claims            int default 0,                                -- [MON]
  persisted_encounters        int default 0,                                -- [MON]
  persisted_diagnoses         int default 0,                                -- [MON]
  persisted_activities        int default 0,                                -- [MON]
  persisted_observations      int default 0,                                -- [MON]
  parsed_remit_claims         int default 0,                                -- [MON]
  parsed_remit_activities     int default 0,                                -- [MON]
  persisted_remit_claims      int default 0,                                -- [MON]
  persisted_remit_activities  int default 0,                                -- [MON]
  projected_events            int default 0,                                -- [MON]
  projected_status_rows       int default 0,                                -- [MON]
  verification_passed         boolean,                                      -- [MON]
  verification_failed_count   int default 0,                                -- [MON]
  ack_attempted               boolean not null default false,               -- [MON]
  ack_sent                    boolean not null default false,               -- [MON]
  created_at                  timestamptz not null default now()            -- [AUDIT]
);
create index if not exists idx_file_audit_run  on claims.ingestion_file_audit(ingestion_run_id);  -- [IDX]
create index if not exists idx_file_audit_file on claims.ingestion_file_audit(ingestion_file_id); -- [IDX]

---- Batch metrics (per stage/table per batch)  -- are we using below table anywhere in our code?
--create table if not exists claims.ingestion_batch_metric (
--  id                    bigserial primary key,                                -- [PK] [MON]
--  ingestion_file_id     bigint not null                                       -- [FK]
    --references claims.ingestion_file(id) on delete cascade,
  ---stage                 text not null,                                        -- [MON] e.g., PARSE|MAP|INSERT_*
  --target_table          text,                                                 -- [MON]
  --batch_no              int not null,                                         -- [MON]
  --started_at            timestamptz not null default now(),                   -- [MON]
  --ended_at              timestamptz,                                          -- [MON]
  --rows_attempted        int not null default 0,                                -- [MON]
  --rows_inserted         int not null default 0,                                -- [MON]
  --conflicts_ignored     int not null default 0,                                -- [MON]
  --retries               int not null default 0,                                -- [MON]
  --status                text not null,                                        -- [MON]
  --error_class           text,                                                 -- [MON]
  --error_message         text                                                  -- [MON]
--);
--create index if not exists idx_batch_metric_file on claims.ingestion_batch_metric(ingestion_file_id, stage, batch_no); -- [IDX]

-- Error log (fine-grained)
create table if not exists claims.ingestion_error (
  id                    bigserial primary key,                                -- [PK] [MON]
  ingestion_file_id     bigint not null                                       -- [FK]
    references claims.ingestion_file(id) on delete cascade,
  stage                 text not null,                                        -- [MON] FETCH|PARSE|VALIDATE|...
  object_type           text,                                                 -- [MON]
  object_key            text,                                                 -- [MON] e.g., Claim.ID
  error_code            text,                                                 -- [MON]
  error_message         text not null,                                        -- [MON]
  stack_excerpt         text,                                                 -- [MON]
  retryable             boolean not null default false,                       -- [MON]
  occurred_at           timestamptz not null default now()                    -- [AUDIT]
);
create index if not exists idx_ing_error_file_stage on claims.ingestion_error(ingestion_file_id, stage, occurred_at desc); -- [IDX]
comment on table claims.ingestion_error is
  'Central error log. For future normalization: if code lookups fail, log "code not found for: {code}, claim id: {claim_id}, file id: {file_id}".';

-- Verification rules & results
create table if not exists claims.verification_rule (
  id            bigserial primary key,                                -- [PK] [MON]
  code          text not null unique,                                  -- [UQ] e.g., COUNT_MATCH
  description   text not null,
  severity      smallint not null,                                     -- 1=INFO 2=WARNING 3=ERROR
  sql_text      text not null,                                         -- parameterized with :ingestion_file_id
  active        boolean not null default true,                         -- [MON]
  created_at    timestamptz not null default now()                     -- [AUDIT]
);

create table if not exists claims.verification_run (
  id                  bigserial primary key,                                -- [PK] [MON]
  ingestion_file_id   bigint not null                                       -- [FK]
    references claims.ingestion_file(id) on delete cascade,
  started_at          timestamptz not null default now(),                   -- [MON]
  ended_at            timestamptz,                                          -- [MON]
  passed              boolean,                                              -- [MON]
  failed_rules        int not null default 0                                 -- [MON]
);
create index if not exists idx_ver_run_file on claims.verification_run(ingestion_file_id); -- [IDX]

create table if not exists claims.verification_result (
  id                   bigserial primary key,                                -- [PK] [MON]
  verification_run_id  bigint not null                                       -- [FK]
    references claims.verification_run(id) on delete cascade,
  rule_id              bigint not null                                       -- [FK]
    references claims.verification_rule(id) on delete restrict,
  ok                   boolean not null,                                     -- [MON]
  rows_affected        bigint,                                               -- [MON]
  sample_json          jsonb,                                                -- [MON]
  message              text,                                                 -- [MON]
  executed_at          timestamptz not null default now()                    -- [AUDIT]
);
create index if not exists idx_ver_result_run on claims.verification_result(verification_run_id, rule_id); -- [IDX]

-- ============================================================
-- 12) KPI View (hourly rollup)
-- ============================================================
create or replace view claims.v_ingestion_kpis as
select
  date_trunc('hour', ifa.created_at) as hour_bucket,
  count(*)                                        as files_total,
  sum(case when status=1 then 1 else 0 end)       as files_ok,
  sum(case when status=2 then 1 else 0 end)       as files_fail,
  sum(case when status=0 then 1 else 0 end)       as files_already,
  sum(parsed_claims)                               as parsed_claims,
  sum(persisted_claims)                            as persisted_claims,
  sum(parsed_activities)                           as parsed_activities,
  sum(persisted_activities)                        as persisted_activities,
  sum(parsed_remit_claims)                         as parsed_remit_claims,
  sum(persisted_remit_claims)                      as persisted_remit_claims,
  sum(parsed_remit_activities)                     as parsed_remit_activities,
  sum(persisted_remit_activities)                  as persisted_remit_activities,
  sum(case when verification_passed then 1 else 0 end) as files_verified
from claims.ingestion_file_audit ifa
group by 1
order by 1 desc;

-- View description: Hourly rollup of ingestion KPIs derived from ingestion_file_audit.
-- Metrics include parsed/persisted counts for submissions and remittances and verification pass counts.
comment on view claims.v_ingestion_kpis is 'Hourly rollup of ingestion KPIs; source: claims.ingestion_file_audit';

-- ============================================================
-- 13) Grants
-- ============================================================
grant usage on schema claims to claims_user;
grant select, insert, update on all tables in schema claims to claims_user;
grant usage, select on all sequences in schema claims to claims_user;
alter default privileges in schema claims grant select, insert, update on tables to claims_user;
alter default privileges in schema claims grant usage, select on sequences to claims_user;

-- SUBMISSION: tx_at <- ingestion_file.transaction_date  ---
do $$
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema='claims' and table_name='submission' and column_name='tx_at') then
    execute 'alter table claims.submission add column tx_at timestamptz';
  end if;
end$$;

create or replace function claims.set_submission_tx_at()
returns trigger language plpgsql as $$
begin
  if NEW.tx_at is null then
    select i.transaction_date into NEW.tx_at
    from claims.ingestion_file i
    where i.id = NEW.ingestion_file_id;
  end if;
  return NEW;
end$$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname='trg_submission_tx_at') then
    execute 'create trigger trg_submission_tx_at
             before insert on claims.submission
             for each row execute function claims.set_submission_tx_at()';
  end if;
end$$;

-- REMITTANCE: tx_at <- ingestion_file.transaction_date
do $$
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema='claims' and table_name='remittance' and column_name='tx_at') then
    execute 'alter table claims.remittance add column tx_at timestamptz';
  end if;
end$$;

create or replace function claims.set_remittance_tx_at()
returns trigger language plpgsql as $$
begin
  if NEW.tx_at is null then
    select i.transaction_date into NEW.tx_at
    from claims.ingestion_file i
    where i.id = NEW.ingestion_file_id;
  end if;
  return NEW;
end$$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname='trg_remittance_tx_at') then
    execute 'create trigger trg_remittance_tx_at
             before insert on claims.remittance
             for each row execute function claims.set_remittance_tx_at()';
  end if;
end$$;

-- CLAIM: tx_at <- submission.tx_at
do $$
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema='claims' and table_name='claim' and column_name='tx_at') then
    execute 'alter table claims.claim add column tx_at timestamptz';
  end if;
end$$;

create or replace function claims.set_claim_tx_at()
returns trigger language plpgsql as $$
begin
  if NEW.tx_at is null then
    select s.tx_at into NEW.tx_at
    from claims.submission s
    where s.id = NEW.submission_id;
  end if;
  return NEW;
end$$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname='trg_claim_tx_at') then
    execute 'create trigger trg_claim_tx_at
             before insert on claims.claim
             for each row execute function claims.set_claim_tx_at()';
  end if;
end$$;

-- BACKFILL existing rows then enforce NOT NULL + INDEX
update claims.submission s
set tx_at = i.transaction_date
from claims.ingestion_file i
where s.tx_at is null and s.ingestion_file_id = i.id;

update claims.remittance r
set tx_at = i.transaction_date
from claims.ingestion_file i
where r.tx_at is null and r.ingestion_file_id = i.id;

update claims.claim c
set tx_at = s.tx_at
from claims.submission s
where c.tx_at is null and c.submission_id = s.id;

alter table claims.submission alter column tx_at set not null;
alter table claims.remittance alter column tx_at set not null;
alter table claims.claim      alter column tx_at set not null;

create index if not exists idx_submission_tx_at on claims.submission(tx_at);
create index if not exists idx_remittance_tx_at on claims.remittance(tx_at);
create index if not exists idx_claim_tx_at      on claims.claim(tx_at);

-- EVENTS: ensure and index canonical event clock (already present)
-- (No new column; we rely on claim_event.event_time)
create index if not exists idx_event_time on claims.claim_event(event_time);
ALTER ROLE claims_user PASSWORD 'securepass';