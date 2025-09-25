package com.acme.claims.security.service;

import com.acme.claims.security.Role;
import com.acme.claims.security.config.SecurityProperties;
import com.acme.claims.security.entity.User;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Service to initialize default data on application startup
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DataInitializationService implements CommandLineRunner {
    
    private final UserService userService;
    private final PasswordEncoder passwordEncoder;
    private final SecurityProperties securityProperties;
    
    @Override
    @Transactional
    public void run(String... args) throws Exception {
        if (securityProperties.isEnabled()) {
            initializeDefaultSuperAdmin();
        } else {
            log.info("Security is disabled - skipping user initialization");
        }
    }
    
    /**
     * Initialize default super admin user if it doesn't exist
     */
    private void initializeDefaultSuperAdmin() {
        String defaultUsername = securityProperties.getDefaultAdmin().getUsername();
        
        if (userService.findByUsername(defaultUsername).isEmpty()) {
            log.info("Creating default super admin user: {}", defaultUsername);
            
            try {
                User superAdmin = userService.createUser(
                        defaultUsername,
                        securityProperties.getDefaultAdmin().getEmail(),
                        securityProperties.getDefaultAdmin().getPassword(),
                        Role.SUPER_ADMIN,
                        null // No creator for default admin
                );
                
                log.info("Default super admin created successfully: {}", defaultUsername);
                log.warn("IMPORTANT: Change the default admin password after first login!");
                
            } catch (Exception e) {
                log.error("Failed to create default super admin", e);
            }
        } else {
            log.info("Default super admin already exists: {}", defaultUsername);
        }
    }
}
