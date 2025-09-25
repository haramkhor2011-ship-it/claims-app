-- ==========================================================================================================
-- USER MANAGEMENT & SECURITY SCHEMA
-- ==========================================================================================================
-- 
-- Purpose: Complete database schema for user management and security
-- Version: 1.0
-- Date: 2025-01-27
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

-- User roles table
CREATE TABLE IF NOT EXISTS claims.user_roles (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES claims.users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('SUPER_ADMIN', 'FACILITY_ADMIN', 'STAFF')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by BIGINT REFERENCES claims.users(id),
    UNIQUE(user_id, role)
);

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

-- User report permissions table
CREATE TABLE IF NOT EXISTS claims.user_report_permissions (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES claims.users(id) ON DELETE CASCADE,
    report_type VARCHAR(50) NOT NULL,
    granted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    granted_by BIGINT NOT NULL REFERENCES claims.users(id),
    UNIQUE(user_id, report_type)
);

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

-- ==========================================================================================================
-- SECTION 3: SSO INTEGRATION TABLES (SKELETON)
-- ==========================================================================================================

-- SSO providers table
CREATE TABLE IF NOT EXISTS claims.sso_providers (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    provider_type VARCHAR(20) NOT NULL CHECK (provider_type IN ('OAUTH2', 'SAML', 'LDAP')),
    config_json JSONB,
    enabled BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- User SSO mappings table
CREATE TABLE IF NOT EXISTS claims.user_sso_mappings (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES claims.users(id) ON DELETE CASCADE,
    sso_provider_id BIGINT NOT NULL REFERENCES claims.sso_providers(id) ON DELETE CASCADE,
    external_id VARCHAR(100) NOT NULL,
    external_username VARCHAR(100),
    external_email VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(sso_provider_id, external_id)
);

-- ==========================================================================================================
-- SECTION 4: INDEXES FOR PERFORMANCE
-- ==========================================================================================================

-- Users table indexes
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
CREATE INDEX IF NOT EXISTS idx_user_facilities_primary ON claims.user_facilities(user_id, is_primary) WHERE is_primary = true;

-- User report permissions indexes
CREATE INDEX IF NOT EXISTS idx_user_report_permissions_user_id ON claims.user_report_permissions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_report_permissions_report_type ON claims.user_report_permissions(report_type);

-- Security audit log indexes
CREATE INDEX IF NOT EXISTS idx_security_audit_user_id ON claims.security_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_security_audit_timestamp ON claims.security_audit_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_security_audit_action ON claims.security_audit_log(action);
CREATE INDEX IF NOT EXISTS idx_security_audit_success ON claims.security_audit_log(success);

-- Refresh tokens indexes
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON claims.refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at ON claims.refresh_tokens(expires_at);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_revoked ON claims.refresh_tokens(revoked);

-- SSO tables indexes
CREATE INDEX IF NOT EXISTS idx_user_sso_mappings_user_id ON claims.user_sso_mappings(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sso_mappings_provider_id ON claims.user_sso_mappings(sso_provider_id);
CREATE INDEX IF NOT EXISTS idx_user_sso_mappings_external_id ON claims.user_sso_mappings(sso_provider_id, external_id);

-- ==========================================================================================================
-- SECTION 5: TRIGGERS FOR UPDATED_AT
-- ==========================================================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION claims.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON claims.users
    FOR EACH ROW EXECUTE FUNCTION claims.update_updated_at_column();

CREATE TRIGGER update_sso_providers_updated_at BEFORE UPDATE ON claims.sso_providers
    FOR EACH ROW EXECUTE FUNCTION claims.update_updated_at_column();

CREATE TRIGGER update_user_sso_mappings_updated_at BEFORE UPDATE ON claims.user_sso_mappings
    FOR EACH ROW EXECUTE FUNCTION claims.update_updated_at_column();

-- ==========================================================================================================
-- SECTION 6: DEFAULT DATA
-- ==========================================================================================================

-- Insert default super admin user
-- Password: admin123 (will be hashed by application)
INSERT INTO claims.users (username, email, password_hash, enabled, locked, created_at, updated_at)
VALUES ('admin', 'admin@claims.local', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTVEFDi', true, false, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT (username) DO NOTHING;

-- Insert super admin role
INSERT INTO claims.user_roles (user_id, role, created_at)
SELECT u.id, 'SUPER_ADMIN', CURRENT_TIMESTAMP
FROM claims.users u
WHERE u.username = 'admin'
ON CONFLICT (user_id, role) DO NOTHING;

-- ==========================================================================================================
-- SECTION 7: COMMENTS
-- ==========================================================================================================

COMMENT ON TABLE claims.users IS 'User accounts for the claims system';
COMMENT ON TABLE claims.user_roles IS 'User role assignments';
COMMENT ON TABLE claims.user_facilities IS 'User facility associations for multi-tenancy';
COMMENT ON TABLE claims.user_report_permissions IS 'User permissions for specific reports';
COMMENT ON TABLE claims.security_audit_log IS 'Security event audit trail';
COMMENT ON TABLE claims.refresh_tokens IS 'JWT refresh tokens for extended sessions';
COMMENT ON TABLE claims.sso_providers IS 'SSO provider configurations (skeleton)';
COMMENT ON TABLE claims.user_sso_mappings IS 'User mappings to external SSO systems (skeleton)';

COMMENT ON COLUMN claims.users.password_hash IS 'BCrypt hashed password';
COMMENT ON COLUMN claims.users.failed_attempts IS 'Number of consecutive failed login attempts';
COMMENT ON COLUMN claims.users.locked IS 'Account locked due to failed attempts or admin action';
COMMENT ON COLUMN claims.user_facilities.is_primary IS 'Primary facility for the user (used for default data filtering)';
COMMENT ON COLUMN claims.refresh_tokens.token_hash IS 'SHA-256 hash of the refresh token';
COMMENT ON COLUMN claims.security_audit_log.resource_type IS 'Type of resource accessed (e.g., CLAIM, FACILITY, REPORT)';
COMMENT ON COLUMN claims.security_audit_log.resource_id IS 'ID of the specific resource accessed';
