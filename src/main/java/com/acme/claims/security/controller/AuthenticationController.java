package com.acme.claims.security.controller;

import com.acme.claims.security.config.SecurityProperties;
import com.acme.claims.security.service.AuthenticationService;
import com.acme.claims.security.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Authentication controller for login and token management
 */
@Slf4j
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthenticationController {
    
    private final AuthenticationService authenticationService;
    private final UserService userService;
    private final SecurityProperties securityProperties;
    
    /**
     * Login endpoint
     */
    @PostMapping("/login")
    public ResponseEntity<?> login(@Valid @RequestBody LoginRequest request) {
        if (!securityProperties.isEnabled()) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "Security is disabled. Enable security to use authentication."));
        }
        
        log.info("Login attempt for user: {}", request.getUsername());
        
        AuthenticationService.AuthenticationResult result = 
                authenticationService.authenticate(request.getUsername(), request.getPassword());
        
        if (result.isSuccess()) {
            LoginResponse response = LoginResponse.builder()
                    .accessToken(result.getAccessToken())
                    .refreshToken(result.getRefreshToken())
                    .tokenType("Bearer")
                    .expiresIn(900) // 15 minutes in seconds
                    .user(UserInfo.builder()
                            .id(result.getUser().getId())
                            .username(result.getUser().getUsername())
                            .email(result.getUser().getEmail())
                            .roles(result.getUser().getRoles().stream()
                                    .map(role -> role.getRole().name())
                                    .toList())
                            .facilities(result.getUser().getFacilityCodes())
                            .primaryFacility(result.getUser().getPrimaryFacilityCode())
                            .build())
                    .build();
            
            return ResponseEntity.ok(response);
        } else {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", result.getMessage()));
        }
    }
    
    /**
     * Refresh token endpoint
     */
    @PostMapping("/refresh")
    public ResponseEntity<?> refreshToken(@Valid @RequestBody RefreshTokenRequest request) {
        AuthenticationService.AuthenticationResult result = 
                authenticationService.refreshToken(request.getRefreshToken());
        
        if (result.isSuccess()) {
            RefreshTokenResponse response = RefreshTokenResponse.builder()
                    .accessToken(result.getAccessToken())
                    .tokenType("Bearer")
                    .expiresIn(900) // 15 minutes in seconds
                    .build();
            
            return ResponseEntity.ok(response);
        } else {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", result.getMessage()));
        }
    }
    
    /**
     * Logout endpoint (client-side token invalidation)
     */
    @PostMapping("/logout")
    public ResponseEntity<?> logout() {
        // In a stateless JWT system, logout is handled client-side
        // by removing the token from storage
        return ResponseEntity.ok(Map.of("message", "Logged out successfully"));
    }
    
    /**
     * Get current user info
     */
    @GetMapping("/me")
    public ResponseEntity<?> getCurrentUser(@RequestHeader("Authorization") String authHeader) {
        // This will be implemented with JWT filter
        return ResponseEntity.ok(Map.of("message", "Current user info endpoint"));
    }
    
    // DTOs
    
    public static class LoginRequest {
        private String username;
        private String password;
        
        // Getters and setters
        public String getUsername() { return username; }
        public void setUsername(String username) { this.username = username; }
        public String getPassword() { return password; }
        public void setPassword(String password) { this.password = password; }
    }
    
    public static class RefreshTokenRequest {
        private String refreshToken;
        
        // Getters and setters
        public String getRefreshToken() { return refreshToken; }
        public void setRefreshToken(String refreshToken) { this.refreshToken = refreshToken; }
    }
    
    public static class LoginResponse {
        private String accessToken;
        private String refreshToken;
        private String tokenType;
        private long expiresIn;
        private UserInfo user;
        
        // Builder pattern
        public static LoginResponseBuilder builder() {
            return new LoginResponseBuilder();
        }
        
        public static class LoginResponseBuilder {
            private String accessToken;
            private String refreshToken;
            private String tokenType;
            private long expiresIn;
            private UserInfo user;
            
            public LoginResponseBuilder accessToken(String accessToken) {
                this.accessToken = accessToken;
                return this;
            }
            
            public LoginResponseBuilder refreshToken(String refreshToken) {
                this.refreshToken = refreshToken;
                return this;
            }
            
            public LoginResponseBuilder tokenType(String tokenType) {
                this.tokenType = tokenType;
                return this;
            }
            
            public LoginResponseBuilder expiresIn(long expiresIn) {
                this.expiresIn = expiresIn;
                return this;
            }
            
            public LoginResponseBuilder user(UserInfo user) {
                this.user = user;
                return this;
            }
            
            public LoginResponse build() {
                LoginResponse response = new LoginResponse();
                response.accessToken = this.accessToken;
                response.refreshToken = this.refreshToken;
                response.tokenType = this.tokenType;
                response.expiresIn = this.expiresIn;
                response.user = this.user;
                return response;
            }
        }
        
        // Getters
        public String getAccessToken() { return accessToken; }
        public String getRefreshToken() { return refreshToken; }
        public String getTokenType() { return tokenType; }
        public long getExpiresIn() { return expiresIn; }
        public UserInfo getUser() { return user; }
    }
    
    public static class RefreshTokenResponse {
        private String accessToken;
        private String tokenType;
        private long expiresIn;
        
        // Builder pattern
        public static RefreshTokenResponseBuilder builder() {
            return new RefreshTokenResponseBuilder();
        }
        
        public static class RefreshTokenResponseBuilder {
            private String accessToken;
            private String tokenType;
            private long expiresIn;
            
            public RefreshTokenResponseBuilder accessToken(String accessToken) {
                this.accessToken = accessToken;
                return this;
            }
            
            public RefreshTokenResponseBuilder tokenType(String tokenType) {
                this.tokenType = tokenType;
                return this;
            }
            
            public RefreshTokenResponseBuilder expiresIn(long expiresIn) {
                this.expiresIn = expiresIn;
                return this;
            }
            
            public RefreshTokenResponse build() {
                RefreshTokenResponse response = new RefreshTokenResponse();
                response.accessToken = this.accessToken;
                response.tokenType = this.tokenType;
                response.expiresIn = this.expiresIn;
                return response;
            }
        }
        
        // Getters
        public String getAccessToken() { return accessToken; }
        public String getTokenType() { return tokenType; }
        public long getExpiresIn() { return expiresIn; }
    }
    
    public static class UserInfo {
        private Long id;
        private String username;
        private String email;
        private java.util.List<String> roles;
        private java.util.Set<String> facilities;
        private String primaryFacility;
        
        // Builder pattern
        public static UserInfoBuilder builder() {
            return new UserInfoBuilder();
        }
        
        public static class UserInfoBuilder {
            private Long id;
            private String username;
            private String email;
            private java.util.List<String> roles;
            private java.util.Set<String> facilities;
            private String primaryFacility;
            
            public UserInfoBuilder id(Long id) {
                this.id = id;
                return this;
            }
            
            public UserInfoBuilder username(String username) {
                this.username = username;
                return this;
            }
            
            public UserInfoBuilder email(String email) {
                this.email = email;
                return this;
            }
            
            public UserInfoBuilder roles(java.util.List<String> roles) {
                this.roles = roles;
                return this;
            }
            
            public UserInfoBuilder facilities(java.util.Set<String> facilities) {
                this.facilities = facilities;
                return this;
            }
            
            public UserInfoBuilder primaryFacility(String primaryFacility) {
                this.primaryFacility = primaryFacility;
                return this;
            }
            
            public UserInfo build() {
                UserInfo userInfo = new UserInfo();
                userInfo.id = this.id;
                userInfo.username = this.username;
                userInfo.email = this.email;
                userInfo.roles = this.roles;
                userInfo.facilities = this.facilities;
                userInfo.primaryFacility = this.primaryFacility;
                return userInfo;
            }
        }
        
        // Getters
        public Long getId() { return id; }
        public String getUsername() { return username; }
        public String getEmail() { return email; }
        public java.util.List<String> getRoles() { return roles; }
        public java.util.Set<String> getFacilities() { return facilities; }
        public String getPrimaryFacility() { return primaryFacility; }
    }
}
