-- SCHEMA: claims.facility_dhpo_config
-- Purpose: One row per facility + global toggle fields (Option B)
CREATE TABLE IF NOT EXISTS claims.facility_dhpo_config (
                                                           id                 BIGSERIAL PRIMARY KEY,
                                                           facility_code      CITEXT        NOT NULL,
                                                           facility_name      TEXT          NOT NULL,

    -- DHPO endpoints
                                                           endpoint_url       TEXT          NOT NULL DEFAULT 'https://dhpo.eclaimlink.ae/ValidateTransactions.asmx',
                                                           endpoint_url_for_erx TEXT        NOT NULL DEFAULT 'https://dhpo.eclaimlink.ae/eRxValidateTransactions.asmx',

    -- App-managed encryption for credentials
                                                           dhpo_username_enc  BYTEA         NOT NULL,
                                                           dhpo_password_enc  BYTEA         NOT NULL,
                                                           enc_meta_json      JSONB         NOT NULL,  -- {kek_version:int, alg:"AES/GCM", iv:base64, tagBits:int}

                                                           active             BOOLEAN       NOT NULL DEFAULT TRUE,
                                                           created_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    UNIQUE(facility_code)
    );



COMMENT ON TABLE  claims.facility_dhpo_config IS 'Per-facility DHPO endpoints + encrypted creds (AME).';
COMMENT ON COLUMN claims.facility_dhpo_config.enc_meta_json IS 'Enc metadata: {"kek_version":int,"alg":"AES/GCM","iv":"b64","tagBits":int}';



-- operational role used by our app
grant select, insert, update on claims.facility_dhpo_config to claims_user;

-- do NOT grant raw access to decrypt helper (we’ll use controlled access below)
-- global toggles (we already use this table)
create table if not exists claims.integration_toggle(
                                                        code text primary key,
                                                        enabled boolean not null default false,
                                                        updated_at timestamptz not null default now()
    );

insert into claims.integration_toggle(code, enabled) values
                                                         ('dhpo.search.enabled', true),
                                                         ('dhpo.setDownloaded.enabled', true)
    on conflict (code) do nothing;

grant select, insert, update on claims.integration_toggle to claims_user;

------------------------------------
resolution rule in code 
--effective_search_enabled = coalesce(facility.search_enabled, global.search.enabled)
--effective_setdownload_enabled = coalesce(facility.setdownload_enabled, global.setDownloaded.enabled)
--effective_retry_max_attempts = coalesce(facility.retry_max_attempts, 2)

-- AME schema (encrypted-at-rest, app decrypts on read)
alter table claims.facility_dhpo_config
    add column if not exists login_ct  bytea,   -- AES-GCM ciphertext (base64 in app if you prefer)
    add column if not exists pwd_ct    bytea,
    add column if not exists enc_meta  jsonb default '{}'::jsonb;  -- algo, keyId, iv sizes, version

-- optional: remove plain columns once migrated
-- alter table claims.facility_dhpo_config drop column login_plain;
-- alter table claims.facility_dhpo_config drop column pwd_plain;
