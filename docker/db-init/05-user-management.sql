-- ==========================================================================================================
-- USER MANAGEMENT & SECURITY SCHEMA
-- ==========================================================================================================
-- 
-- Purpose: Complete database schema for user management and security
-- Version: 1.0
-- Date: 2025-01-15
-- 
-- This schema creates tables for:
-- - User management and authentication
-- - Role-based access control
-- - Multi-tenancy support
-- - Security audit logging
-- - JWT refresh tokens
-- - SSO integration (skeleton)
--
-- ==========================================================================================================

-- ==========================================================================================================
-- SECTION 1: USER MANAGEMENT TABLES
-- ==========================================================================================================

-- Users table
CREATE TABLE IF NOT EXISTS claims.users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT true,
    locked BOOLEAN NOT NULL DEFAULT false,
    failed_attempts INTEGER NOT NULL DEFAULT 0,
    last_login TIMESTAMP,
    locked_at TIMESTAMP,
    password_changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by BIGINT REFERENCES claims.users(id),
    updated_by BIGINT REFERENCES claims.users(id)
);

COMMENT ON TABLE claims.users IS 'User accounts for authentication and authorization';

-- User roles table
CREATE TABLE IF NOT EXISTS claims.user_roles (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES claims.users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('SUPER_ADMIN', 'FACILITY_ADMIN', 'STAFF')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by BIGINT REFERENCES claims.users(id),
    UNIQUE(user_id, role)
);

COMMENT ON TABLE claims.user_roles IS 'User role assignments for RBAC';

-- User facilities table (for multi-tenancy)
CREATE TABLE IF NOT EXISTS claims.user_facilities (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES claims.users(id) ON DELETE CASCADE,
    facility_code VARCHAR(50) NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by BIGINT REFERENCES claims.users(id),
    UNIQUE(user_id, facility_code)
);

COMMENT ON TABLE claims.user_facilities IS 'User facility access for multi-tenancy';

-- User report permissions table
CREATE TABLE IF NOT EXISTS claims.user_report_permissions (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES claims.users(id) ON DELETE CASCADE,
    report_type VARCHAR(50) NOT NULL,
    granted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    granted_by BIGINT NOT NULL REFERENCES claims.users(id),
    UNIQUE(user_id, report_type)
);

COMMENT ON TABLE claims.user_report_permissions IS 'Granular report access permissions';

-- ==========================================================================================================
-- SECTION 2: SECURITY & AUDIT TABLES
-- ==========================================================================================================

-- Security audit log table
CREATE TABLE IF NOT EXISTS claims.security_audit_log (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES claims.users(id),
    username VARCHAR(50),
    action VARCHAR(50) NOT NULL,
    resource_type VARCHAR(50),
    resource_id VARCHAR(100),
    ip_address INET,
    user_agent TEXT,
    success BOOLEAN NOT NULL,
    error_message TEXT,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE claims.security_audit_log IS 'Security event audit trail';

-- Refresh tokens table
CREATE TABLE IF NOT EXISTS claims.refresh_tokens (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES claims.users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP,
    revoked BOOLEAN NOT NULL DEFAULT false
);

COMMENT ON TABLE claims.refresh_tokens IS 'JWT refresh token management';

-- ==========================================================================================================
-- SECTION 3: SSO INTEGRATION (SKELETON)
-- ==========================================================================================================

-- SSO providers table
CREATE TABLE IF NOT EXISTS claims.sso_providers (
    id BIGSERIAL PRIMARY KEY,
    provider_name VARCHAR(50) NOT NULL UNIQUE,
    provider_type VARCHAR(20) NOT NULL CHECK (provider_type IN ('OAUTH2', 'SAML', 'LDAP')),
    client_id VARCHAR(255),
    client_secret_enc BYTEA,
    discovery_url TEXT,
    enabled BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE claims.sso_providers IS 'SSO provider configurations';

-- SSO user mappings table
CREATE TABLE IF NOT EXISTS claims.sso_user_mappings (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES claims.users(id) ON DELETE CASCADE,
    sso_provider_id BIGINT NOT NULL REFERENCES claims.sso_providers(id) ON DELETE CASCADE,
    external_user_id VARCHAR(255) NOT NULL,
    external_username VARCHAR(100),
    external_email VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(sso_provider_id, external_user_id)
);

COMMENT ON TABLE claims.sso_user_mappings IS 'Mapping between internal users and SSO identities';

-- ==========================================================================================================
-- SECTION 4: INDEXES FOR PERFORMANCE
-- ==========================================================================================================

-- User indexes
CREATE INDEX IF NOT EXISTS idx_users_username ON claims.users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON claims.users(email);
CREATE INDEX IF NOT EXISTS idx_users_enabled ON claims.users(enabled);
CREATE INDEX IF NOT EXISTS idx_users_locked ON claims.users(locked);

-- User roles indexes
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON claims.user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON claims.user_roles(role);

-- User facilities indexes
CREATE INDEX IF NOT EXISTS idx_user_facilities_user_id ON claims.user_facilities(user_id);
CREATE INDEX IF NOT EXISTS idx_user_facilities_facility_code ON claims.user_facilities(facility_code);
CREATE INDEX IF NOT EXISTS idx_user_facilities_primary ON claims.user_facilities(is_primary);

-- Security audit indexes
CREATE INDEX IF NOT EXISTS idx_security_audit_user_id ON claims.security_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_security_audit_action ON claims.security_audit_log(action);
CREATE INDEX IF NOT EXISTS idx_security_audit_timestamp ON claims.security_audit_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_security_audit_success ON claims.security_audit_log(success);

-- Refresh token indexes
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON claims.refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at ON claims.refresh_tokens(expires_at);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_revoked ON claims.refresh_tokens(revoked);

-- SSO indexes
CREATE INDEX IF NOT EXISTS idx_sso_providers_enabled ON claims.sso_providers(enabled);
CREATE INDEX IF NOT EXISTS idx_sso_user_mappings_user_id ON claims.sso_user_mappings(user_id);
CREATE INDEX IF NOT EXISTS idx_sso_user_mappings_provider_id ON claims.sso_user_mappings(sso_provider_id);

-- ==========================================================================================================
-- SECTION 5: GRANTS TO CLAIMS_USER
-- ==========================================================================================================

-- Grant all privileges on user management tables to claims_user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA claims TO claims_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA claims TO claims_user;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA claims GRANT ALL ON TABLES TO claims_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA claims GRANT ALL ON SEQUENCES TO claims_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA claims GRANT ALL ON FUNCTIONS TO claims_user;

-- ==========================================================================================================
-- SECTION 6: DEFAULT ADMIN USER (OPTIONAL)
-- ==========================================================================================================

-- Insert default admin user (password: admin123 - should be changed in production)
INSERT INTO claims.users (username, email, password_hash, enabled, created_at, updated_at) VALUES
  ('admin', 'admin@claims.local', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTV5DCi', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT (username) DO NOTHING;

-- Assign SUPER_ADMIN role to admin user
INSERT INTO claims.user_roles (user_id, role, created_at, created_by) 
SELECT u.id, 'SUPER_ADMIN', CURRENT_TIMESTAMP, u.id 
FROM claims.users u 
WHERE u.username = 'admin'
ON CONFLICT (user_id, role) DO NOTHING;
