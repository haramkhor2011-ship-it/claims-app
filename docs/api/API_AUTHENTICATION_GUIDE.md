# API Authentication Guide

This document provides comprehensive documentation of API authentication in the Claims Backend system, including JWT tokens, OAuth2 integration, and environment-specific authentication flows.

## Overview

This guide covers:
- **Authentication Methods**: JWT tokens and OAuth2 integration
- **Token Management**: Token generation, validation, and refresh
- **Environment-Specific Flows**: Local, staging, and production authentication
- **Security Considerations**: Token security and best practices
- **Troubleshooting**: Common authentication issues and solutions

---

## Authentication Architecture

### Authentication Flow

```
Client → JWT Token → Claims Backend → Token Validation → Role Extraction → Authorization
```

**Components**:
1. **JWT Token**: Contains user identity and roles
2. **Token Validator**: Validates JWT signature and claims
3. **Role Extractor**: Extracts roles from JWT claims
4. **Authorization Filter**: Applies role-based access control

### Token Structure

**JWT Header**:
```json
{
  "alg": "RS256",
  "typ": "JWT",
  "kid": "key-id"
}
```

**JWT Payload**:
```json
{
  "sub": "user@company.com",
  "iat": 1640995200,
  "exp": 1641081600,
  "iss": "https://auth.company.com",
  "aud": "claims-backend",
  "roles": ["FACILITY_ADMIN"],
  "facilityId": "FAC001",
  "facilityRefId": 123,
  "tenantId": "company-tenant"
}
```

---

## Environment-Specific Authentication

### Local Development Environment

**Authentication**: Simplified or disabled
**Purpose**: Development and testing without authentication complexity

**Configuration**:
```yaml
# application-local.yml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          enabled: false
claims:
  security:
    authentication:
      enabled: false
    jwt:
      validation: disabled
```

**Behavior**:
- JWT validation disabled
- Security bypasses enabled
- No token required for API calls
- Debug information included in responses
- Cross-facility access allowed

**Example Usage**:
```bash
# No authentication required
curl -X POST http://localhost:8080/api/reports/data/balance-amount \
  -H "Content-Type: application/json" \
  -d '{"reportType":"BALANCE_AMOUNT_REPORT","facilityCodes":["FAC001"]}'
```

### Staging Environment

**Authentication**: Basic JWT validation
**Purpose**: Testing authentication without full OAuth2 complexity

**Configuration**:
```yaml
# application-staging.yml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          enabled: true
          issuer-uri: ${OAUTH2_ISSUER_URI}
claims:
  security:
    authentication:
      enabled: true
    jwt:
      validation: basic
```

**Behavior**:
- JWT validation enabled
- Basic token validation
- Role-based access control
- Multi-tenancy enabled
- Audit logging enabled

**Example Usage**:
```bash
# JWT token required
curl -X POST http://staging-api.company.com/api/reports/data/balance-amount \
  -H "Authorization: Bearer <jwt-token>" \
  -H "Content-Type: application/json" \
  -d '{"reportType":"BALANCE_AMOUNT_REPORT","facilityCodes":["FAC001"]}'
```

### Production Environment

**Authentication**: Full OAuth2 integration
**Purpose**: Production-grade security with OAuth2 provider

**Configuration**:
```yaml
# application-prod.yml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          enabled: true
          issuer-uri: ${OAUTH2_ISSUER_URI}
          jwk-set-uri: ${OAUTH2_JWK_SET_URI}
claims:
  security:
    authentication:
      enabled: true
    jwt:
      validation: full
      oauth2:
        enabled: true
```

**Behavior**:
- Full OAuth2 integration
- Complete JWT validation
- Strict role-based access control
- Multi-tenancy enforced
- Comprehensive audit logging
- Rate limiting enabled

**Example Usage**:
```bash
# OAuth2 JWT token required
curl -X POST https://api.company.com/api/reports/data/balance-amount \
  -H "Authorization: Bearer <oauth2-jwt-token>" \
  -H "Content-Type: application/json" \
  -d '{"reportType":"BALANCE_AMOUNT_REPORT","facilityCodes":["FAC001"]}'
```

---

## JWT Token Management

### Token Generation

**OAuth2 Provider Token Generation**:
```bash
# Get access token from OAuth2 provider
curl -X POST https://auth.company.com/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=<client-id>&client_secret=<client-secret>&scope=claims-backend"
```

**Response**:
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "claims-backend"
}
```

### Token Validation

**Java Implementation**:
```java
@Component
public class JwtTokenValidator {
    
    @Value("${spring.security.oauth2.resourceserver.jwt.issuer-uri}")
    private String issuerUri;
    
    @Value("${spring.security.oauth2.resourceserver.jwt.jwk-set-uri}")
    private String jwkSetUri;
    
    public Claims validateToken(String token) {
        try {
            JwtDecoder jwtDecoder = NimbusJwtDecoder.withJwkSetUri(jwkSetUri).build();
            Jwt jwt = jwtDecoder.decode(token);
            
            // Validate claims
            validateClaims(jwt.getClaims());
            
            return jwt.getClaims();
        } catch (JwtException e) {
            throw new AuthenticationException("Invalid JWT token", e);
        }
    }
    
    private void validateClaims(Map<String, Object> claims) {
        // Validate issuer
        String issuer = (String) claims.get("iss");
        if (!issuerUri.equals(issuer)) {
            throw new AuthenticationException("Invalid token issuer");
        }
        
        // Validate audience
        String audience = (String) claims.get("aud");
        if (!"claims-backend".equals(audience)) {
            throw new AuthenticationException("Invalid token audience");
        }
        
        // Validate expiration
        Long exp = (Long) claims.get("exp");
        if (exp != null && exp < System.currentTimeMillis() / 1000) {
            throw new AuthenticationException("Token expired");
        }
    }
}
```

### Token Refresh

**Refresh Token Flow**:
```bash
# Refresh access token
curl -X POST https://auth.company.com/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token&refresh_token=<refresh-token>&client_id=<client-id>&client_secret=<client-secret>"
```

**Response**:
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

---

## Role-Based Access Control

### Role Definitions

**SUPER_ADMIN**:
- Full access to all facilities
- Can access all reports
- Can manage users and configuration
- No facility filtering applied

**FACILITY_ADMIN**:
- Access limited to assigned facility
- Can access all reports for facility
- Can manage facility users
- Automatic facility filtering applied

**STAFF**:
- Read-only access to assigned facility
- Can view reports for facility
- Cannot manage users
- Automatic facility filtering applied

**CLAIMS_RO**:
- Read-only access to specific reports
- Limited to assigned facility
- External system integration
- Automatic facility filtering applied

### Role Extraction

**Java Implementation**:
```java
@Component
public class RoleExtractor {
    
    public Collection<GrantedAuthority> extractAuthorities(Claims claims) {
        List<GrantedAuthority> authorities = new ArrayList<>();
        
        // Extract roles from JWT claims
        Object rolesObj = claims.get("roles");
        if (rolesObj instanceof List) {
            List<String> roles = (List<String>) rolesObj;
            for (String role : roles) {
                authorities.add(new SimpleGrantedAuthority("ROLE_" + role));
            }
        }
        
        return authorities;
    }
    
    public String extractFacilityId(Claims claims) {
        return (String) claims.get("facilityId");
    }
    
    public Long extractFacilityRefId(Claims claims) {
        Object refId = claims.get("facilityRefId");
        if (refId instanceof Number) {
            return ((Number) refId).longValue();
        }
        return null;
    }
}
```

### Authorization Implementation

**Method-Level Security**:
```java
@PostMapping("/balance-amount")
@PreAuthorize("hasRole('SUPER_ADMIN') or hasRole('FACILITY_ADMIN') or hasRole('STAFF')")
@Operation(summary = "Get Balance Amount Report", description = "Retrieve balance amount report data")
public ResponseEntity<ReportResponse> getBalanceAmountReport(
        @Valid @RequestBody BalanceAmountRequest request,
        Authentication authentication) {
    
    // Apply facility filtering based on user role
    applyFacilityFiltering(request, authentication);
    
    List<Map<String, Object>> data = balanceAmountReportService.getReportData(request);
    
    return ResponseEntity.ok(buildSuccessResponse(data));
}

private void applyFacilityFiltering(ReportRequest request, Authentication authentication) {
    Collection<? extends GrantedAuthority> authorities = authentication.getAuthorities();
    
    if (authorities.stream().noneMatch(auth -> auth.getAuthority().equals("ROLE_SUPER_ADMIN"))) {
        // Extract facility ID from JWT claims
        if (authentication instanceof JwtAuthenticationToken) {
            JwtAuthenticationToken jwtAuth = (JwtAuthenticationToken) authentication;
            String facilityId = jwtAuth.getToken().getClaimAsString("facilityId");
            request.setFacilityId(facilityId);
        }
    }
}
```

---

## Multi-Tenancy Implementation

### Facility-Based Isolation

**JWT Claims for Multi-Tenancy**:
```json
{
  "sub": "user@company.com",
  "roles": ["FACILITY_ADMIN"],
  "facilityId": "FAC001",
  "facilityRefId": 123,
  "facilityIds": ["FAC001", "FAC002"],
  "tenantId": "company-tenant"
}
```

**Automatic Facility Filtering**:
```java
@Service
public class FacilitySecurityService {
    
    public void applyFacilityFiltering(ReportRequest request, Authentication authentication) {
        if (isSuperAdmin(authentication)) {
            // SUPER_ADMIN can access all facilities
            return;
        }
        
        String facilityId = extractFacilityId(authentication);
        if (facilityId != null) {
            request.setFacilityId(facilityId);
        }
    }
    
    private boolean isSuperAdmin(Authentication authentication) {
        return authentication.getAuthorities().stream()
            .anyMatch(auth -> auth.getAuthority().equals("ROLE_SUPER_ADMIN"));
    }
    
    private String extractFacilityId(Authentication authentication) {
        if (authentication instanceof JwtAuthenticationToken) {
            JwtAuthenticationToken jwtAuth = (JwtAuthenticationToken) authentication;
            return jwtAuth.getToken().getClaimAsString("facilityId");
        }
        return null;
    }
}
```

---

## Security Configuration

### Spring Security Configuration

**Local Development Configuration**:
```java
@Configuration
@Profile("localfs")
public class LocalSecurityConfig {
    
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf().disable()
            .authorizeHttpRequests(authz -> authz
                .requestMatchers("/api/reports/**").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt.disable())
            );
        return http.build();
    }
}
```

**Production Configuration**:
```java
@Configuration
@Profile("prod")
public class ProductionSecurityConfig {
    
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf().csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
            .authorizeHttpRequests(authz -> authz
                .requestMatchers("/api/reports/**").hasAnyRole("SUPER_ADMIN", "FACILITY_ADMIN", "STAFF")
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .decoder(jwtDecoder())
                    .jwtAuthenticationConverter(jwtAuthenticationConverter())
                )
            )
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            );
        return http.build();
    }
    
    @Bean
    public JwtDecoder jwtDecoder() {
        return NimbusJwtDecoder.withJwkSetUri(jwkSetUri).build();
    }
    
    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(jwtGrantedAuthoritiesConverter());
        return converter;
    }
    
    @Bean
    public JwtGrantedAuthoritiesConverter jwtGrantedAuthoritiesConverter() {
        JwtGrantedAuthoritiesConverter converter = new JwtGrantedAuthoritiesConverter();
        converter.setAuthorityPrefix("ROLE_");
        converter.setAuthoritiesClaimName("roles");
        return converter;
    }
}
```

### OAuth2 Configuration

**OAuth2 Resource Server Configuration**:
```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: ${OAUTH2_ISSUER_URI}
          jwk-set-uri: ${OAUTH2_JWK_SET_URI}
          audience: claims-backend
```

**Environment Variables**:
```bash
# Production environment variables
export OAUTH2_ISSUER_URI=https://auth.company.com
export OAUTH2_JWK_SET_URI=https://auth.company.com/.well-known/jwks.json
export OAUTH2_AUDIENCE=claims-backend
```

---

## Error Handling

### Authentication Errors

**Invalid Token Error**:
```json
{
  "success": false,
  "error": {
    "code": "AUTHENTICATION_ERROR",
    "message": "Invalid JWT token",
    "details": {
      "error": "JWT validation failed",
      "timestamp": "2025-01-15T10:30:00Z"
    }
  }
}
```

**Expired Token Error**:
```json
{
  "success": false,
  "error": {
    "code": "TOKEN_EXPIRED",
    "message": "JWT token has expired",
    "details": {
      "expiredAt": "2025-01-15T09:30:00Z",
      "currentTime": "2025-01-15T10:30:00Z",
      "timestamp": "2025-01-15T10:30:00Z"
    }
  }
}
```

**Access Denied Error**:
```json
{
  "success": false,
  "error": {
    "code": "ACCESS_DENIED",
    "message": "Insufficient permissions",
    "details": {
      "requiredRole": "FACILITY_ADMIN",
      "userRoles": ["STAFF"],
      "resource": "/api/reports/data/balance-amount",
      "timestamp": "2025-01-15T10:30:00Z"
    }
  }
}
```

### Error Handling Implementation

**Global Exception Handler**:
```java
@ControllerAdvice
public class AuthenticationExceptionHandler {
    
    @ExceptionHandler(JwtException.class)
    public ResponseEntity<ErrorResponse> handleJwtException(JwtException e) {
        ErrorResponse error = ErrorResponse.builder()
            .code("AUTHENTICATION_ERROR")
            .message("Invalid JWT token")
            .details(Map.of("error", e.getMessage()))
            .timestamp(Instant.now().toString())
            .build();
        
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(error);
    }
    
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ErrorResponse> handleAccessDeniedException(AccessDeniedException e) {
        ErrorResponse error = ErrorResponse.builder()
            .code("ACCESS_DENIED")
            .message("Insufficient permissions")
            .details(Map.of("error", e.getMessage()))
            .timestamp(Instant.now().toString())
            .build();
        
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(error);
    }
}
```

---

## Troubleshooting

### Common Authentication Issues

**Issue 1: Invalid JWT Token**
**Symptoms**: 401 Unauthorized errors
**Causes**: Malformed token, wrong signature, invalid claims
**Solutions**:
```bash
# Check token format
echo "<token>" | base64 -d | jq .

# Verify token signature
jwt verify <token> --secret <secret-key>

# Check token claims
jwt decode <token>
```

**Issue 2: Token Expired**
**Symptoms**: 401 Unauthorized with expiration error
**Causes**: Token past expiration time
**Solutions**:
```bash
# Check token expiration
jwt decode <token> | jq .exp

# Refresh token
curl -X POST https://auth.company.com/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token&refresh_token=<refresh-token>"
```

**Issue 3: Access Denied**
**Symptoms**: 403 Forbidden errors
**Causes**: Insufficient permissions, wrong role
**Solutions**:
```bash
# Check user roles in token
jwt decode <token> | jq .roles

# Verify facility access
jwt decode <token> | jq .facilityId
```

### Debugging Commands

**Check Token Validity**:
```bash
# Decode JWT token
echo "<token>" | base64 -d | jq .

# Verify token signature
jwt verify <token> --secret <secret-key>

# Check token expiration
jwt decode <token> | jq .exp
```

**Check Authentication Status**:
```bash
# Test authentication endpoint
curl -H "Authorization: Bearer <token>" \
     http://localhost:8080/api/reports/data/available

# Check authentication logs
tail -f logs/application.log | grep "AUTHENTICATION"
```

---

## Best Practices

### Security Best Practices

1. **Token Security**: Use secure token storage and transmission
2. **Token Rotation**: Implement token rotation policies
3. **Audit Logging**: Log all authentication events
4. **Rate Limiting**: Implement rate limiting for authentication endpoints
5. **Monitoring**: Monitor authentication failures and anomalies

### Environment-Specific Best Practices

**Local Development**:
- Disable authentication for easier development
- Use test tokens or no authentication
- Enable debug logging
- Allow cross-facility access for testing

**Staging Environment**:
- Use basic JWT validation
- Test authentication flows
- Verify role-based access control
- Test multi-tenancy functionality

**Production Environment**:
- Use full OAuth2 integration
- Implement comprehensive security
- Monitor authentication events
- Use production-grade token management

---

## Related Documentation

- [API Error Codes](API_ERROR_CODES.md) - Comprehensive error code documentation
- [Security Matrix](SECURITY_MATRIX.md) - Security implementation details
- [Multi-Tenancy Behavior](MULTI_TENANCY_BEHAVIOR.md) - Multi-tenancy implementation
- [Environment Behavior Guide](ENVIRONMENT_BEHAVIOR_GUIDE.md) - Environment-specific behavior
- [Configuration Matrix](CONFIGURATION_MATRIX.md) - Authentication configuration
