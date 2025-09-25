# Day 1: Security Implementation - Complete Guide

## 📋 Overview

This document covers the complete Day 1 security implementation for the Claims Processing System. We've implemented a comprehensive user management and authentication system with JWT tokens, role-based access control, and account lockout features.

## 🎯 What We Accomplished

### ✅ Core Security Foundation
- JWT authentication with 15-minute tokens
- User management system with CRUD operations
- Role-based access control (SUPER_ADMIN, FACILITY_ADMIN, STAFF)
- Account lockout system (3 attempts, admin unlock only)
- Security toggle for ingestion vs API modes

### ✅ Database Schema
- Complete user management tables
- Multi-tenancy support (toggle-ready)
- Security audit logging
- SSO integration skeleton

### ✅ API Endpoints
- Authentication endpoints (`/api/auth/*`)
- User management endpoints (`/api/users/*`)
- Admin management endpoints (`/api/admin/*`)

---

## 🗂️ File Structure

```
src/main/java/com/acme/claims/security/
├── config/
│   ├── SecurityConfig.java              # Main security configuration
│   ├── SecurityProperties.java          # Security properties
│   └── JwtAuthenticationFilter.java     # JWT token processing
├── controller/
│   ├── AuthenticationController.java    # Login/logout endpoints
│   ├── UserController.java              # User CRUD operations
│   └── AdminController.java             # Admin account management
├── entity/
│   ├── User.java                        # User entity
│   ├── UserRole.java                    # User roles
│   ├── UserFacility.java                # Multi-tenancy
│   └── UserReportPermission.java        # Report access control
├── repository/
│   └── UserRepository.java              # User data access
├── service/
│   ├── JwtService.java                  # JWT token operations
│   ├── UserService.java                 # User business logic
│   ├── AuthenticationService.java       # Login authentication
│   └── DataInitializationService.java   # Default admin creation
├── util/
│   └── JwtSecretGenerator.java          # JWT secret generation
├── Role.java                            # User roles enum
├── ReportType.java                      # Report types enum
└── ame/                                 # Existing encryption (unchanged)

src/main/resources/
├── db/
│   └── user_management_schema.sql       # Database schema
├── application.yml                      # Main configuration
├── application-ingestion.yml            # Ingestion profile
└── application-api.yml                  # API profile
```

---

## 🔧 Configuration

### Main Configuration
**File**: `src/main/resources/application.yml`

```yaml
claims:
  security:
    enabled: false                           # Security toggle
    jwt:
      secret: "claims-jwt-secret-key-change-in-production-2025"
      access-token-expiration: PT15M          # 15 minutes
      refresh-token-expiration: P7D           # 7 days
      issuer: "claims-app"
      audience: "claims-users"
    
    multi-tenancy:
      enabled: false                           # Multi-tenant support
      default-facility-code: "DEFAULT"
    
    sso:
      enabled: false                           # SSO integration
      default-provider: "OAUTH2"
    
    account-lockout:
      max-failed-attempts: 3
      lockout-duration: PT30M                 # Not used - admin unlock only
      auto-unlock: false                      # Disabled - admin unlock only
    
    default-admin:
      username: "admin"
      password: "admin123"
      email: "admin@claims.local"
```

### Profile Configurations

**Ingestion Profile**: `src/main/resources/application-ingestion.yml`
```yaml
claims:
  security:
    enabled: false                           # No security for ingestion
```

**API Profile**: `src/main/resources/application-api.yml`
```yaml
claims:
  security:
    enabled: true                            # Enable security for API
```

---

## 🗄️ Database Schema

**File**: `src/main/resources/db/user_management_schema.sql`

### Core Tables
- **`users`**: User accounts with authentication data
- **`user_roles`**: Role assignments (SUPER_ADMIN, FACILITY_ADMIN, STAFF)
- **`user_facilities`**: Multi-tenancy support
- **`user_report_permissions`**: Report access control
- **`security_audit_log`**: Security event logging
- **`refresh_tokens`**: JWT refresh token storage

### Key Features
- **Account lockout tracking**: `failed_attempts`, `locked`, `locked_at`
- **Multi-tenancy ready**: `user_facilities` table with primary facility support
- **Audit logging**: Complete security event tracking
- **SSO skeleton**: Tables for future SSO integration

---

## 🔐 Security Features

### 1. JWT Authentication
**Files**: 
- `src/main/java/com/acme/claims/security/service/JwtService.java`
- `src/main/java/com/acme/claims/security/config/JwtAuthenticationFilter.java`

**Features**:
- 15-minute access tokens
- 7-day refresh tokens
- HMAC-SHA256 signing
- Token validation and extraction

### 2. Role-Based Access Control
**File**: `src/main/java/com/acme/claims/security/entity/User.java`

**Roles**:
- **SUPER_ADMIN**: Full system access, can create all user types
- **FACILITY_ADMIN**: Can create staff, manage assigned facilities
- **STAFF**: Read-only access to assigned facility data

### 3. Account Lockout System
**Files**:
- `src/main/java/com/acme/claims/security/service/AuthenticationService.java`
- `src/main/java/com/acme/claims/security/controller/AdminController.java`

**Features**:
- 3 failed attempts → account locked
- Admin unlock only (no automatic unlock)
- Clear user messaging about remaining attempts
- Complete reset on admin unlock

---

## 🌐 API Endpoints

### Authentication Endpoints
**File**: `src/main/java/com/acme/claims/security/controller/AuthenticationController.java`

```http
POST /api/auth/login
Content-Type: application/json
{
  "username": "admin",
  "password": "admin123"
}

Response:
{
  "accessToken": "eyJhbGciOiJIUzI1NiJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiJ9...",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "user": {
    "id": 1,
    "username": "admin",
    "email": "admin@claims.local",
    "roles": ["SUPER_ADMIN"],
    "facilities": [],
    "primaryFacility": null
  }
}
```

```http
POST /api/auth/refresh
Content-Type: application/json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### User Management Endpoints
**File**: `src/main/java/com/acme/claims/security/controller/UserController.java`

```http
# Create user
POST /api/users
Authorization: Bearer <token>
{
  "username": "john.doe",
  "email": "john@example.com",
  "password": "password123",
  "role": "STAFF",
  "facilityCode": "FACILITY_001"
}

# Get all users
GET /api/users
Authorization: Bearer <token>

# Update user
PUT /api/users/{id}
Authorization: Bearer <token>
{
  "email": "newemail@example.com",
  "enabled": true
}

# Change password
POST /api/users/{id}/change-password
Authorization: Bearer <token>
{
  "newPassword": "newpassword123"
}

# Lock/unlock user
POST /api/users/{id}/lock?locked=true
Authorization: Bearer <token>
```

### Admin Management Endpoints
**File**: `src/main/java/com/acme/claims/security/controller/AdminController.java`

```http
# View locked accounts
GET /api/admin/locked-accounts
Authorization: Bearer <token>

# Unlock account
POST /api/admin/unlock-account/{userId}
Authorization: Bearer <token>

# Reset failed attempts
POST /api/admin/reset-attempts/{userId}
Authorization: Bearer <token>

# Lockout statistics
GET /api/admin/lockout-stats
Authorization: Bearer <token>
```

---

## 🚀 Usage Instructions

### For Ingestion (Current Setup)
```bash
# Run with security disabled
java -jar claims-backend.jar --spring.profiles.active=ingestion,localfs

# Or use default (security disabled)
java -jar claims-backend.jar --spring.profiles.active=localfs
```

### For API Endpoints (When Ready)
```bash
# Run with security enabled
java -jar claims-backend.jar --spring.profiles.active=api

# Or enable via environment variable
java -jar claims-backend.jar -Dclaims.security.enabled=true
```

### Database Setup
```sql
-- Run the schema file
\i src/main/resources/db/user_management_schema.sql
```

---

## 🧪 Testing

### Test Security Disabled (Current)
```bash
# Should work without authentication
curl -X GET http://localhost:8080/api/users

# Login should return error
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin123"}'
# Response: {"error": "Security is disabled. Enable security to use authentication."}
```

### Test Security Enabled (Future)
```bash
# Should require authentication
curl -X GET http://localhost:8080/api/users
# Response: 401 Unauthorized

# Login should work
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin123"}'
# Response: JWT token
```

### Test Account Lockout
```bash
# Attempt 1
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "password": "wrongpassword"}'
# Response: "Invalid username or password. 2 attempt(s) remaining before account lockout."

# Attempt 2
# Response: "Invalid username or password. 1 attempt(s) remaining before account lockout."

# Attempt 3
# Response: "Account has been locked due to multiple failed login attempts. Please contact your administrator to unlock your account."
```

---

## 🔧 JWT Secret Management

### Current Setup
**File**: `src/main/resources/application.yml`
```yaml
claims:
  security:
    jwt:
      secret: "claims-jwt-secret-key-change-in-production-2025"
```

### Generate Secure Secret
**File**: `src/main/java/com/acme/claims/security/util/JwtSecretGenerator.java`

```bash
# Compile and run
mvn compile
java -cp target/classes com.acme.claims.security.util.JwtSecretGenerator
```

### Production Setup
```bash
# Use environment variable
export JWT_SECRET="your-super-secure-256-bit-secret-key-here"

# Update application.yml
claims:
  security:
    jwt:
      secret: ${JWT_SECRET:claims-jwt-secret-key-change-in-production-2025}
```

---

## 📊 Key Features Summary

### ✅ Implemented
- **JWT Authentication**: 15-minute tokens with refresh capability
- **User Management**: Complete CRUD operations with role-based access
- **Account Lockout**: 3 attempts → lock, admin unlock only
- **Multi-tenancy**: Toggle-ready facility-based access control
- **Security Toggle**: Disabled for ingestion, enabled for API
- **Admin Tools**: Locked account management and statistics
- **Audit Logging**: Security event tracking
- **SSO Skeleton**: Ready for future SSO integration

### 🔄 Ready for Day 2
- **API Security**: Secure existing endpoints
- **Data Filtering**: User context-based data access
- **Report Access Control**: Role-based report permissions
- **Integration Testing**: Complete system testing

---

## 🎯 Next Steps

1. **Test Current Setup**: Verify ingestion works without security interference
2. **Database Setup**: Run the user management schema
3. **Day 2 Planning**: Prepare for API endpoint security
4. **Production Secrets**: Generate secure JWT secrets when ready

---

## 📝 Notes

- **Security is disabled by default** - no interference with ingestion
- **Default admin**: username `admin`, password `admin123`
- **Account lockout**: Admin unlock only, no automatic unlock
- **Multi-tenancy**: Toggle-ready, not enabled by default
- **SSO**: Skeleton ready, not implemented yet

**The system is now ready for Day 2 implementation while maintaining full ingestion capability!**
