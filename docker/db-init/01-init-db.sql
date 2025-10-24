-- ==========================================================================================================
-- DATABASE INITIALIZATION - SCHEMAS, EXTENSIONS, ROLES
-- ==========================================================================================================
-- 
-- Purpose: Create database schemas, extensions, and roles
-- Version: 1.0
-- Date: 2025-01-15
-- 
-- This script creates the foundational database structure:
-- - PostgreSQL extensions for text search and encryption
-- - Database schemas for claims processing
-- - Application roles with appropriate permissions
--
-- ==========================================================================================================

-- Required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;     -- Text similarity and trigram indexes
CREATE EXTENSION IF NOT EXISTS citext;      -- Case-insensitive text type
CREATE EXTENSION IF NOT EXISTS pgcrypto;    -- Cryptographic functions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Schema creation
CREATE SCHEMA IF NOT EXISTS claims;         -- Main claims processing schema
CREATE SCHEMA IF NOT EXISTS claims_ref;     -- Reference data schema
CREATE SCHEMA IF NOT EXISTS auth;           -- Authentication schema (reserved)

-- Application role for runtime operations
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'claims_user') THEN
    CREATE ROLE claims_user LOGIN;
  END IF;
END$$ LANGUAGE plpgsql;

-- Grant schema usage to claims_user
GRANT USAGE ON SCHEMA claims TO claims_user;
GRANT USAGE ON SCHEMA claims_ref TO claims_user;
GRANT USAGE ON SCHEMA auth TO claims_user;

-- Grant create privileges for tables, views, etc.
GRANT CREATE ON SCHEMA claims TO claims_user;
GRANT CREATE ON SCHEMA claims_ref TO claims_user;
GRANT CREATE ON SCHEMA auth TO claims_user;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA claims GRANT ALL ON TABLES TO claims_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA claims GRANT ALL ON SEQUENCES TO claims_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA claims GRANT ALL ON FUNCTIONS TO claims_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA claims_ref GRANT ALL ON TABLES TO claims_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA claims_ref GRANT ALL ON SEQUENCES TO claims_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA claims_ref GRANT ALL ON FUNCTIONS TO claims_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON TABLES TO claims_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON SEQUENCES TO claims_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON FUNCTIONS TO claims_user;
