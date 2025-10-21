package com.acme.claims.validation;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.regex.Pattern;

/**
 * Validation utility for claim-related operations.
 * 
 * This utility provides validation methods for claim IDs and other
 * claim-related parameters to ensure data integrity and security.
 */
@Slf4j
@Component
public class ClaimValidationUtil {

    // Pattern for valid claim IDs (alphanumeric with optional hyphens/underscores)
    private static final Pattern CLAIM_ID_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{3,50}$");
    
    // Maximum length for claim ID
    private static final int MAX_CLAIM_ID_LENGTH = 50;
    
    // Minimum length for claim ID
    private static final int MIN_CLAIM_ID_LENGTH = 3;

    /**
     * Validates a claim ID format and content.
     * 
     * @param claimId The claim ID to validate
     * @return true if the claim ID is valid, false otherwise
     */
    public boolean isValidClaimId(String claimId) {
        if (claimId == null || claimId.trim().isEmpty()) {
            log.debug("Claim ID validation failed: null or empty");
            return false;
        }

        String trimmedClaimId = claimId.trim();
        
        if (trimmedClaimId.length() < MIN_CLAIM_ID_LENGTH || trimmedClaimId.length() > MAX_CLAIM_ID_LENGTH) {
            log.debug("Claim ID validation failed: invalid length {} (expected {}-{})", 
                    trimmedClaimId.length(), MIN_CLAIM_ID_LENGTH, MAX_CLAIM_ID_LENGTH);
            return false;
        }

        if (!CLAIM_ID_PATTERN.matcher(trimmedClaimId).matches()) {
            log.debug("Claim ID validation failed: invalid format '{}'", trimmedClaimId);
            return false;
        }

        log.debug("Claim ID validation passed: '{}'", trimmedClaimId);
        return true;
    }

    /**
     * Validates a claim ID and throws an exception if invalid.
     * 
     * @param claimId The claim ID to validate
     * @throws IllegalArgumentException if the claim ID is invalid
     */
    public void validateClaimId(String claimId) {
        if (!isValidClaimId(claimId)) {
            throw new IllegalArgumentException("Invalid claim ID format: " + claimId);
        }
    }

    /**
     * Sanitizes a claim ID by trimming whitespace and converting to uppercase.
     * 
     * @param claimId The claim ID to sanitize
     * @return The sanitized claim ID
     */
    public String sanitizeClaimId(String claimId) {
        if (claimId == null) {
            return null;
        }
        return claimId.trim().toUpperCase();
    }

    /**
     * Checks if a claim ID contains potentially malicious content.
     * 
     * @param claimId The claim ID to check
     * @return true if the claim ID appears safe, false if potentially malicious
     */
    public boolean isClaimIdSafe(String claimId) {
        if (claimId == null) {
            return true;
        }

        // Check for SQL injection patterns
        String lowerClaimId = claimId.toLowerCase();
        String[] suspiciousPatterns = {
            "union", "select", "insert", "update", "delete", "drop", "create", "alter",
            "exec", "execute", "script", "javascript", "vbscript", "onload", "onerror",
            "';", "--", "/*", "*/", "xp_", "sp_"
        };

        for (String pattern : suspiciousPatterns) {
            if (lowerClaimId.contains(pattern)) {
                log.warn("Potentially malicious claim ID detected: '{}' contains '{}'", claimId, pattern);
                return false;
            }
        }

        return true;
    }

    /**
     * Comprehensive validation of a claim ID including safety checks.
     * 
     * @param claimId The claim ID to validate
     * @throws IllegalArgumentException if the claim ID is invalid or unsafe
     */
    public void validateClaimIdComprehensive(String claimId) {
        validateClaimId(claimId);
        
        if (!isClaimIdSafe(claimId)) {
            throw new IllegalArgumentException("Claim ID contains potentially malicious content: " + claimId);
        }
    }
}

