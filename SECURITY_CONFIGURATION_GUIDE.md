# Security Configuration Guide

## Overview
This guide explains how to enable and configure security for the Claims Backend API. Security is currently disabled by default for development purposes.

## Current Security Status
- **Security Enabled**: `false` (disabled)
- **Location**: `src/main/resources/application.yml` → `claims.security.enabled: false`

## Enabling Security

### Step 1: Enable Security in Configuration
Update `src/main/resources/application.yml`:

```yaml
claims:
  security:
    enabled: true  # Change from false to true
```

### Step 2: Configure JWT Settings
Ensure JWT configuration is properly set:

```yaml
claims:
  security:
    jwt:
      secret: "your-secure-jwt-secret-key-change-in-production-2025"
      access-token-expiration: PT15M          # 15 minutes
      refresh-token-expiration: P7D           # 7 days
      issuer: "claims-app"
      audience: "claims-users"
```

### Step 3: Configure Default Admin User
Set up the default admin user:

```yaml
claims:
  security:
    default-admin:
      username: "admin"
      password: "admin123"  # Change this in production!
      email: "admin@claims.local"
```

### Step 4: Configure Multi-Tenancy (Optional)
If you need multi-tenant support:

```yaml
claims:
  security:
    multi-tenancy:
      enabled: true
      default-facility-code: "DEFAULT"
```

### Step 5: Configure Account Lockout
Set up account lockout policies:

```yaml
claims:
  security:
    account-lockout:
      max-failed-attempts: 3
      lockout-duration: PT30M                 # 30 minutes
      auto-unlock: false                      # Disabled - admin unlock only
```

## Security Features

### 1. JWT Authentication
- **Access Token**: Short-lived (15 minutes) for API access
- **Refresh Token**: Long-lived (7 days) for token renewal
- **Bearer Token**: Required in `Authorization` header

### 2. Role-Based Access Control (RBAC)
- **SUPER_ADMIN**: Full system access
- **FACILITY_ADMIN**: Facility-specific admin access
- **STAFF**: Limited access to assigned facilities

### 3. Facility-Based Access Control
- Users can only access data from their assigned facilities
- Facility codes are enforced at the service layer
- Database functions receive filtered facility lists

### 4. Report-Level Permissions
- Users can only access reports they have permission for
- Permissions are stored in `user_report_permission` table
- Admin users automatically get all report permissions

### 5. Rate Limiting
- **Per User**: 100 requests per minute
- **Per Endpoint**: 1000 requests per minute
- **Headers**: Rate limit information in response headers

### 6. Audit Logging
- All report access is logged with user context
- Correlation IDs for request tracing
- Structured JSON logs for analysis

## API Security Headers

### Required Headers
```http
Authorization: Bearer <jwt-token>
Content-Type: application/json
X-Correlation-ID: <optional-correlation-id>
```

### Response Headers
```http
X-Correlation-ID: <correlation-id>
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200000
```

## Security Endpoints

### Authentication
- `POST /api/auth/login` - User login
- `POST /api/auth/refresh` - Token refresh
- `GET /api/auth/me` - Current user info
- `POST /api/auth/logout` - User logout

### Reports (Protected)
- `POST /api/reports/data/query` - Unified report endpoint
- `GET /api/reports/data/available` - Available reports
- `GET /api/reports/data/access-summary` - Access summary

## Security Configuration Classes

### 1. SecurityConfig
- **Location**: `src/main/java/com/acme/claims/security/config/SecurityConfig.java`
- **Purpose**: Main security configuration
- **Features**: JWT, CORS, CSRF, session management

### 2. JwtAuthenticationFilter
- **Location**: `src/main/java/com/acme/claims/security/filter/JwtAuthenticationFilter.java`
- **Purpose**: JWT token validation
- **Features**: Token extraction, validation, user context

### 3. JwtTokenProvider
- **Location**: `src/main/java/com/acme/claims/security/service/JwtTokenProvider.java`
- **Purpose**: JWT token generation and validation
- **Features**: Token creation, validation, expiration

### 4. UserDetailsServiceImpl
- **Location**: `src/main/java/com/acme/claims/security/service/UserDetailsServiceImpl.java`
- **Purpose**: User authentication and authorization
- **Features**: User loading, role assignment, facility access

## Database Security

### User Tables
- `users` - User accounts
- `user_roles` - User role assignments
- `user_facilities` - User facility access
- `user_report_permissions` - Report-level permissions

### Security Functions
- `claims.get_user_facilities(user_id)` - Get user's accessible facilities
- `claims.check_facility_access(user_id, facility_code)` - Check facility access
- `claims.get_user_report_permissions(user_id)` - Get user's report permissions

## Testing Security

### 1. Login Test
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin123"}'
```

### 2. Access Protected Endpoint
```bash
curl -X POST http://localhost:8080/api/reports/data/query \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"reportType": "BALANCE_AMOUNT_REPORT", "page": 0, "size": 50}'
```

### 3. Test Rate Limiting
```bash
# Make multiple requests quickly to test rate limiting
for i in {1..110}; do
  curl -X POST http://localhost:8080/api/reports/data/query \
    -H "Authorization: Bearer <token>" \
    -H "Content-Type: application/json" \
    -d '{"reportType": "BALANCE_AMOUNT_REPORT"}'
done
```

## Production Security Checklist

### 1. Configuration
- [ ] Change JWT secret to a secure random string
- [ ] Change default admin password
- [ ] Enable HTTPS/TLS
- [ ] Configure proper CORS origins
- [ ] Set up proper logging levels

### 2. Database
- [ ] Ensure user tables are properly secured
- [ ] Implement proper backup encryption
- [ ] Set up database connection encryption
- [ ] Configure proper database user permissions

### 3. Infrastructure
- [ ] Set up firewall rules
- [ ] Configure load balancer security
- [ ] Implement proper monitoring and alerting
- [ ] Set up intrusion detection

### 4. Application
- [ ] Enable all security features
- [ ] Configure proper error handling
- [ ] Set up audit logging
- [ ] Implement proper session management

## Troubleshooting

### Common Issues

#### 1. "No authenticated user found"
- **Cause**: JWT token missing or invalid
- **Solution**: Check Authorization header and token validity

#### 2. "Access Denied"
- **Cause**: User doesn't have required permissions
- **Solution**: Check user roles and report permissions

#### 3. "Rate limit exceeded"
- **Cause**: Too many requests in time window
- **Solution**: Wait for rate limit reset or increase limits

#### 4. "Facility access denied"
- **Cause**: User trying to access unauthorized facility
- **Solution**: Check user facility assignments

### Debug Mode
Enable debug logging for security:

```yaml
logging:
  level:
    com.acme.claims.security: DEBUG
    org.springframework.security: DEBUG
```

## Security Best Practices

### 1. Token Management
- Use short-lived access tokens
- Implement proper token refresh
- Store tokens securely on client side
- Implement token blacklisting for logout

### 2. Password Security
- Enforce strong password policies
- Implement password hashing (BCrypt)
- Set up account lockout policies
- Regular password rotation

### 3. API Security
- Validate all input parameters
- Implement proper error handling
- Use HTTPS in production
- Set up proper CORS policies

### 4. Monitoring
- Log all security events
- Monitor for suspicious activity
- Set up alerts for security violations
- Regular security audits

## Support

For security-related issues or questions:
- Check application logs for detailed error messages
- Review security configuration settings
- Test with Postman collection provided
- Contact system administrator for access issues
