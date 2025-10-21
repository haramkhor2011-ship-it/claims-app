package com.acme.claims.security.service;


import com.acme.claims.security.config.SecurityProperties;
import com.acme.claims.security.entity.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;

/**
 * JWT token service for authentication
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class JwtService {
    
    private final SecurityProperties securityProperties;
    
    /**
     * Generate access token for user
     */
    public String generateAccessToken(User user) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", user.getId());
        claims.put("username", user.getUsername());
        claims.put("email", user.getEmail());
        claims.put("roles", user.getRoles().stream()
                .map(role -> role.getRole().name())
                .toArray());
        claims.put("facilities", user.getFacilityCodes());
        claims.put("primaryFacility", user.getPrimaryFacilityCode());
        
        // TODO: When multi-tenancy is enabled, uncomment the following logic:
        // When multi-tenancy is disabled, return empty facilities in JWT (no restrictions)
        if (!securityProperties.getMultiTenancy().isEnabled()) {
            claims.put("facilities", new String[0]); // Empty array means no restrictions
            claims.put("primaryFacility", null); // No primary facility when multi-tenancy disabled
        }
        
        return createToken(claims, user.getUsername(), securityProperties.getJwt().getAccessTokenExpiration());
    }
    
    /**
     * Generate refresh token for user
     */
    public String generateRefreshToken(User user) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", user.getId());
        claims.put("type", "refresh");
        
        return createToken(claims, user.getUsername(), securityProperties.getJwt().getRefreshTokenExpiration());
    }
    
    /**
     * Create JWT token with claims and expiration
     */
    private String createToken(Map<String, Object> claims, String subject, java.time.Duration expiration) {
        Instant now = Instant.now();
        Instant expirationTime = now.plus(expiration);
        
        return Jwts.builder()
                .claims(claims)
                .subject(subject)
                .issuer(securityProperties.getJwt().getIssuer())
                .audience().add(securityProperties.getJwt().getAudience()).and()
                .issuedAt(Date.from(now))
                .expiration(Date.from(expirationTime))
                .signWith(getSigningKey())
                .compact();
    }
    
    /**
     * Extract username from token
     */
    public String extractUsername(String token) {
        return extractClaim(token, Claims::getSubject);
    }
    
    /**
     * Extract user ID from token
     */
    public Long extractUserId(String token) {
        return extractClaim(token, claims -> claims.get("userId", Long.class));
    }
    
    /**
     * Extract roles from token
     */
    @SuppressWarnings("unchecked")
    public Set<String> extractRoles(String token) {
        return extractClaim(token, claims -> {
            Object roles = claims.get("roles");
            if (roles instanceof java.util.List) {
                return Set.copyOf((java.util.List<String>) roles);
            }
            return Set.of();
        });
    }
    
    /**
     * Extract facilities from token
     */
    @SuppressWarnings("unchecked")
    public Set<String> extractFacilities(String token) {
        return extractClaim(token, claims -> {
            Object facilities = claims.get("facilities");
            if (facilities instanceof java.util.Set) {
                return (Set<String>) facilities;
            }
            return Set.of();
        });
    }
    
    /**
     * Extract primary facility from token
     */
    public String extractPrimaryFacility(String token) {
        return extractClaim(token, claims -> claims.get("primaryFacility", String.class));
    }
    
    /**
     * Extract expiration date from token
     */
    public Date extractExpiration(String token) {
        return extractClaim(token, Claims::getExpiration);
    }
    
    /**
     * Extract specific claim from token
     */
    public <T> T extractClaim(String token, Function<Claims, T> claimsResolver) {
        final Claims claims = extractAllClaims(token);
        return claimsResolver.apply(claims);
    }
    
    /**
     * Extract all claims from token
     */
    private Claims extractAllClaims(String token) {
        return Jwts.parser()
                .setSigningKey(getSigningKey())
                .build()
                .parseClaimsJwt(token)
                .getPayload();
    }
    
    /**
     * Check if token is expired
     */
    public Boolean isTokenExpired(String token) {
        return extractExpiration(token).before(new Date());
    }
    
    /**
     * Validate token
     */
    public Boolean validateToken(String token, User user) {
        final String username = extractUsername(token);
        return (username.equals(user.getUsername()) && !isTokenExpired(token));
    }
    
    /**
     * Get signing key from secret
     */
    private SecretKey getSigningKey() {
        byte[] keyBytes = securityProperties.getJwt().getSecret().getBytes(StandardCharsets.UTF_8);
        return Keys.hmacShaKeyFor(keyBytes);
    }
    
    /**
     * Get token expiration time in seconds
     */
    public long getTokenExpirationInSeconds() {
        return securityProperties.getJwt().getAccessTokenExpiration().getSeconds();
    }
}
