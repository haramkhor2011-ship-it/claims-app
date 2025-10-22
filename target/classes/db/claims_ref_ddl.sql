-- =====================================================================
-- Extensions (safe if repeated)
-- =====================================================================
create extension if not exists pg_trgm;
create extension if not exists pgcrypto;

-- =====================================================================
-- SCHEMA: claims_ref  (Reference data)
-- =====================================================================
create schema if not exists claims_ref;

-- -------------------------
-- Facilities
-- -------------------------
create table if not exists claims_ref.facility (
  id             bigserial primary key,
  facility_code  text not null unique,  -- e.g., DHA-F-0045446
  name           text,
  city           text,
  country        text,
  status         text default 'ACTIVE',
  created_at	 timestamptz default now(),
  updated_at     timestamptz
);
comment on table  claims_ref.facility is 'Master list of provider facilities (Encounter.FacilityID)';
comment on column claims_ref.facility.facility_code is 'External FacilityID (DHA/eClaim)';

-- -------------------------
-- Payers
-- -------------------------
create table if not exists claims_ref.payer (
  id          bigserial primary key,
  payer_code  text not null unique,     -- e.g., INS025
  name        text,
  status      text default 'ACTIVE',
  classification   text,
  created_at	 timestamptz default now(),
  updated_at  timestamptz default now()
);
comment on table  claims_ref.payer is 'Master list of Payers (Claim.PayerID)';
comment on column claims_ref.payer.payer_code is 'External PayerID';

-- -------------------------
-- Providers (org-level)
-- -------------------------
create table if not exists claims_ref.provider (
  id            bigserial primary key,
  provider_code text not null unique,
  name          text,
  status        text default 'ACTIVE',
  created_at	 timestamptz default now(),
  updated_at    timestamptz
);
comment on table claims_ref.provider is 'Master list of provider organizations (Claim.ProviderID)';

-- -------------------------
-- Clinicians
-- -------------------------
create table if not exists claims_ref.clinician (
  id              bigserial primary key,
  clinician_code  text not null unique, -- e.g., DHA-P-0228312
  name            text,
  specialty       text,
  status          text default 'ACTIVE',
  created_at	 timestamptz default now(),
  updated_at      timestamptz
);
comment on table claims_ref.clinician is 'Master list of clinicians (Activity.Clinician)';

-- -------------------------
-- Activity Codes
-- -------------------------
create table if not exists claims_ref.activity_code (
  id           bigserial primary key,
  type          text,
  code         text not null,
  code_system  text not null default 'LOCAL',   -- CPT/HCPCS/LOCAL/etc.
  description  text,
  status       text default 'ACTIVE',
  created_at	 timestamptz default now(),
  updated_at   timestamptz default now() default now(),
  constraint uq_activity_code unique (code, type)
);
comment on table claims_ref.activity_code is 'Service/procedure codes used in Activity.Code';

-- -------------------------
-- Diagnosis Codes
-- -------------------------
create table if not exists claims_ref.diagnosis_code (
  id           bigserial primary key,
  code         text not null,
  code_system  text not null default 'ICD-10',
  description  text,
  status       text default 'ACTIVE',
  created_at	 timestamptz default now(),
  updated_at   timestamptz default now(),
  constraint uq_diagnosis_code unique (code, code_system)
);
comment on table claims_ref.diagnosis_code is 'Diagnosis codes (Diagnosis.Code)';

-- -------------------------
-- Denial Codes  (surrogate id + unique(code))
-- -------------------------
create table if not exists claims_ref.denial_code (
  id          bigserial primary key,
  code        text not null unique,
  description text,
  payer_code  text,  -- optional scope
  created_at	 timestamptz default now(),
  updated_at  timestamptz
);
comment on table claims_ref.denial_code is 'Adjudication denial codes; optionally scoped by payer_code';

-- -------------------------
-- Observation dictionaries (curated lists; optional)
-- -------------------------
create table if not exists claims_ref.observation_type (
  obs_type     text primary key,  -- LOINC/Text/File/Universal Dental/Financial/Grouping/ERX/Result
  description  text
);

insert into claims_ref.observation_type(obs_type, description) values
  ('LOINC','LOINC standardized code'),
  ('Text','Free text observation'),
  ('File','Binary file attachment'),
  ('Universal Dental','Universal Dental coding'),
  ('Financial','Financial observation'),
  ('Grouping','Panel/grouping marker'),
  ('ERX','Electronic prescription'),
  ('Result','Generic lab/clinical result')
on conflict (obs_type) do update set description = excluded.description;

create table if not exists claims_ref.observation_value_type (
  value_type   text primary key,  -- curated unit/value type (optional)
  description  text
);

create table if not exists claims_ref.observation_code (
  id          bigserial primary key,
  code        text not null unique, -- curated short-hand like A1C/BPS/etc.
  description text
);

-- -------------------------
-- Contract Packages
-- -------------------------
create table if not exists claims_ref.contract_package (
  package_name text primary key,
  description  text,
  status       text default 'ACTIVE',
  updated_at   timestamptz default now() default now()
);

-- -------------------------
-- Type dictionaries (seed)
-- -------------------------
create table if not exists claims_ref.activity_type (
  type_code   text primary key,
  description text
);

--insert into claims_ref.activity_type(type_code, description) values
--  ('3','Diagnostic/Lab'),('4','Radiology'),('5','Pharmacy'),('6','Consumables'),
  --('8','Consultation'),('9','Inpatient'),('10','Other')
--on conflict (type_code) do update set description = excluded.description;

create table if not exists claims_ref.encounter_type (
  type_code   text primary key,
  description text
);

i--nsert into claims_ref.encounter_type(type_code, description) values
  --('1','OPD'),('2','ER'),('3','IPD'),('4','Day Case'),('5','Home Care'),
  --('6','Telemedicine'),('7','OT'),('8','Physio'),('9','Dental'),('10','Wellness'),
  --('12','Maternity'),('13','Mental Health'),('15','Rehab'),('41','Ambulance'),('42','Nursing')
--on conflict (type_code) do update set description = excluded.description;

create table if not exists claims_ref.resubmission_type (
  type_code   text primary key,
  description text
);

--insert into claims_ref.resubmission_type(type_code, description) values
--  ('correction','Correction'),
--  ('internal complaint','Internal complaint'),
--  ('legacy','Legacy'),
--  ('reconciliation','Reconciliation')
--on conflict (type_code) do update set description = excluded.description;

-- =====================================================================
-- AUDIT: newly discovered codes during ingest
-- =====================================================================
create schema if not exists claims;

create table if not exists claims.code_discovery_audit (
  id                bigserial primary key,
  discovered_at     timestamptz not null default now(),
  source_table      text not null,         -- e.g., 'claims_ref.activity_code'
  code              text not null,
  code_system       text,                  -- when applicable
  discovered_by     text not null default 'SYSTEM',
  ingestion_file_id bigint,
  claim_external_id text,
  details           jsonb not null default '{}'::jsonb
);
create index if not exists idx_code_discovery_at   on claims.code_discovery_audit(discovered_at);
create index if not exists idx_code_discovery_code on claims.code_discovery_audit(code);

-- =====================================================================
-- FACT tables: add nullable FK columns (backward compatible)
-- =====================================================================

-- CLAIM: payer_ref_id, provider_ref_id
alter table if exists claims.claim
  add column if not exists payer_ref_id    bigint,
  add column if not exists provider_ref_id bigint;

-- ENCOUNTER: facility_ref_id
alter table if exists claims.encounter
  add column if not exists facility_ref_id bigint;

-- ACTIVITY: clinician_ref_id, activity_code_ref_id
alter table if exists claims.activity
  add column if not exists clinician_ref_id     bigint,
  add column if not exists activity_code_ref_id bigint;

-- DIAGNOSIS: diagnosis_code_ref_id
alter table if exists claims.diagnosis
  add column if not exists diagnosis_code_ref_id bigint;

-- REMITTANCE_CLAIM: denial_code_ref_id
alter table if exists claims.remittance_claim
  add column if not exists denial_code_ref_id bigint,
  add column if not exists payer_ref_id bigint,
  add column if not exists provider_ref_id bigint;

-- =====================================================================
-- FK constraints (wrapped in DO blocks because PostgreSQL lacks IF NOT EXISTS on ADD CONSTRAINT)
-- =====================================================================

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'fk_claim_payer_ref') then
    alter table claims.claim
      add constraint fk_claim_payer_ref
      foreign key (payer_ref_id) references claims_ref.payer(id);
  end if;
end$$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'fk_claim_provider_ref') then
    alter table claims.claim
      add constraint fk_claim_provider_ref
      foreign key (provider_ref_id) references claims_ref.provider(id);
  end if;
end$$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'fk_encounter_facility_ref') then
    alter table claims.encounter
      add constraint fk_encounter_facility_ref
      foreign key (facility_ref_id) references claims_ref.facility(id);
  end if;
end$$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'fk_activity_clinician_ref') then
    alter table claims.activity
      add constraint fk_activity_clinician_ref
      foreign key (clinician_ref_id) references claims_ref.clinician(id);
  end if;
end$$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'fk_activity_code_ref') then
    alter table claims.activity
      add constraint fk_activity_code_ref
      foreign key (activity_code_ref_id) references claims_ref.activity_code(id);
  end if;
end$$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'fk_diag_code_ref') then
    alter table claims.diagnosis
      add constraint fk_diag_code_ref
      foreign key (diagnosis_code_ref_id) references claims_ref.diagnosis_code(id);
  end if;
end$$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'fk_remit_denial_ref') then
    alter table claims.remittance_claim
      add constraint fk_remit_denial_ref
      foreign key (denial_code_ref_id) references claims_ref.denial_code(id);
  end if;
end$$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname='fk_remit_payer_ref') then
    alter table claims.remittance_claim
      add constraint fk_remit_payer_ref
      foreign key (payer_ref_id) references claims_ref.payer(id);
  end if;
end$$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname='fk_remit_provider_ref') then
    alter table claims.remittance_claim
      add constraint fk_remit_provider_ref
      foreign key (provider_ref_id) references claims_ref.provider(id);
  end if;
end$$;


-- =====================================================================
-- Indexes to speed lookups
-- =====================================================================
create index if not exists idx_ref_facility_code     on claims_ref.facility(facility_code);
create index if not exists idx_ref_payer_code        on claims_ref.payer(payer_code);
create index if not exists idx_ref_provider_code     on claims_ref.provider(provider_code);
create index if not exists idx_ref_clinician_code    on claims_ref.clinician(clinician_code);
create index if not exists idx_ref_activity_code     on claims_ref.activity_code(code);
create index if not exists idx_ref_diag_code         on claims_ref.diagnosis_code(code);
create index if not exists idx_ref_denial_payer      on claims_ref.denial_code(payer_code);
create index if not exists idx_remit_claim_payer_ref    on claims.remittance_claim(payer_ref_id);
create index if not exists idx_remit_claim_provider_ref on claims.remittance_claim(provider_ref_id);

-- Optional fuzzy search (trgm) on names/descriptions
create index if not exists idx_ref_facility_name_trgm  on claims_ref.facility      using gin (name gin_trgm_ops);
create index if not exists idx_ref_payer_name_trgm     on claims_ref.payer         using gin (name gin_trgm_ops);
create index if not exists idx_ref_provider_name_trgm  on claims_ref.provider      using gin (name gin_trgm_ops);
create index if not exists idx_ref_clinician_name_trgm on claims_ref.clinician     using gin (name gin_trgm_ops);
create index if not exists idx_ref_activity_desc_trgm  on claims_ref.activity_code using gin (description gin_trgm_ops);
create index if not exists idx_ref_diag_desc_trgm      on claims_ref.diagnosis_code using gin (description gin_trgm_ops);
create index if not exists idx_ref_denial_desc_trgm    on claims_ref.denial_code    using gin (description gin_trgm_ops);

-- =====================================================================
-- Grants to app role
-- =====================================================================
grant select, insert, update on all tables in schema claims_ref to claims_user;
grant usage, select on all sequences in schema claims_ref to claims_user;