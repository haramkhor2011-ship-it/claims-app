package com.acme.claims.security.service;

import com.acme.claims.security.entity.User;
import com.acme.claims.security.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

/**
 * Authentication service for login and token management
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional
public class AuthenticationService {
    
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final UserService userService;
    
    /**
     * Authenticate user and return JWT token
     */
    public AuthenticationResult authenticate(String username, String password) {
        log.info("Attempting authentication for user: {}", username);
        
        Optional<User> userOpt = userRepository.findByUsername(username);
        if (userOpt.isEmpty()) {
            log.warn("Authentication failed: user not found - {}", username);
            return AuthenticationResult.failure("Invalid username or password");
        }
        
        User user = userOpt.get();
        
        // Check if user is enabled
        if (!user.getEnabled()) {
            log.warn("Authentication failed: user disabled - {}", username);
            return AuthenticationResult.failure("Account is disabled");
        }
        
        // Check if user is locked
        if (user.isAccountLocked()) {
            log.warn("Authentication failed: account locked - {} (attempts: {})", username, user.getFailedAttempts());
            
            String lockoutMessage;
            if (user.getFailedAttempts() >= 3) {
                lockoutMessage = "Account is locked due to 3 failed login attempts. Please contact your administrator to unlock your account.";
            } else {
                lockoutMessage = "Account is locked by administrator. Please contact your administrator to unlock your account.";
            }
            
            return AuthenticationResult.failure(lockoutMessage);
        }
        
        // Verify password
        if (!passwordEncoder.matches(password, user.getPasswordHash())) {
            log.warn("Authentication failed: invalid password - {}", username);
            userService.handleFailedLogin(user);
            
            // Get updated user to check new failed attempts count
            User updatedUser = userService.findByUsername(username).orElse(user);
            int remainingAttempts = 3 - updatedUser.getFailedAttempts();
            
            String errorMessage;
            if (remainingAttempts > 0) {
                errorMessage = String.format("Invalid username or password. %d attempt(s) remaining before account lockout.", remainingAttempts);
            } else {
                errorMessage = "Account has been locked due to multiple failed login attempts. Please contact your administrator to unlock your account.";
            }
            
            return AuthenticationResult.failure(errorMessage);
        }
        
        // Successful authentication
        userService.handleSuccessfulLogin(user);
        
        // Generate tokens
        String accessToken = jwtService.generateAccessToken(user);
        String refreshToken = jwtService.generateRefreshToken(user);
        
        log.info("Authentication successful for user: {}", username);
        
        return AuthenticationResult.success(accessToken, refreshToken, user);
    }
    
    /**
     * Refresh access token using refresh token
     */
    public AuthenticationResult refreshToken(String refreshToken) {
        try {
            // Validate refresh token
            String username = jwtService.extractUsername(refreshToken);
            Optional<User> userOpt = userRepository.findByUsername(username);
            
            if (userOpt.isEmpty()) {
                return AuthenticationResult.failure("Invalid refresh token");
            }
            
            User user = userOpt.get();
            if (!jwtService.validateToken(refreshToken, user)) {
                return AuthenticationResult.failure("Invalid refresh token");
            }
            
            // Generate new access token
            String newAccessToken = jwtService.generateAccessToken(user);
            
            return AuthenticationResult.success(newAccessToken, refreshToken, user);
            
        } catch (Exception e) {
            log.error("Error refreshing token", e);
            return AuthenticationResult.failure("Invalid refresh token");
        }
    }
    
    /**
     * Result class for authentication operations
     */
    public static class AuthenticationResult {
        private final boolean success;
        private final String message;
        private final String accessToken;
        private final String refreshToken;
        private final User user;
        
        private AuthenticationResult(boolean success, String message, String accessToken, 
                                   String refreshToken, User user) {
            this.success = success;
            this.message = message;
            this.accessToken = accessToken;
            this.refreshToken = refreshToken;
            this.user = user;
        }
        
        public static AuthenticationResult success(String accessToken, String refreshToken, User user) {
            return new AuthenticationResult(true, "Authentication successful", 
                    accessToken, refreshToken, user);
        }
        
        public static AuthenticationResult failure(String message) {
            return new AuthenticationResult(false, message, null, null, null);
        }
        
        // Getters
        public boolean isSuccess() { return success; }
        public String getMessage() { return message; }
        public String getAccessToken() { return accessToken; }
        public String getRefreshToken() { return refreshToken; }
        public User getUser() { return user; }
    }
}
