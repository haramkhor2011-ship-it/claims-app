// FILE: src/main/java/com/acme/claims/domain/enums/PaymentStatus.java
// Version: v2.0.0
package com.acme.claims.domain.enums;

/**
 * Payment status enumeration for claims
 * Used in claim_payment table to track current payment status
 * 
 * This enum represents the four possible payment states of a claim:
 * - PENDING: Claim is submitted but no payment has been made
 * - PARTIALLY_PAID: Claim has received some payment but not the full amount
 * - FULLY_PAID: Claim has been paid in full
 * - REJECTED: Claim has been rejected/denied
 */
public enum PaymentStatus {
    FULLY_PAID("FULLY_PAID", "Claim is fully paid"),
    PARTIALLY_PAID("PARTIALLY_PAID", "Claim is partially paid"),
    REJECTED("REJECTED", "Claim is fully rejected"),
    PENDING("PENDING", "Claim is pending payment");
    
    private final String code;
    private final String description;
    
    PaymentStatus(String code, String description) {
        this.code = code;
        this.description = description;
    }
    
    public String getCode() {
        return code;
    }
    
    public String getDescription() {
        return description;
    }
    
    /**
     * Convert string code to PaymentStatus enum
     * @param code The payment status code
     * @return PaymentStatus enum value
     * @throws IllegalArgumentException if code is invalid
     */
    public static PaymentStatus fromCode(String code) {
        if (code == null) {
            return PENDING; // Default to PENDING for null values
        }
        
        for (PaymentStatus status : values()) {
            if (status.code.equals(code)) {
                return status;
            }
        }
        throw new IllegalArgumentException("Invalid payment status code: " + code);
    }
    
    /**
     * Check if this status represents a paid claim (fully or partially)
     * @return true if claim has received payment
     */
    public boolean isPaid() {
        return this == FULLY_PAID || this == PARTIALLY_PAID;
    }
    
    /**
     * Check if this status represents a fully paid claim
     * @return true if claim is fully paid
     */
    public boolean isFullyPaid() {
        return this == FULLY_PAID;
    }
    
    /**
     * Check if this status represents a rejected claim
     * @return true if claim is rejected
     */
    public boolean isRejected() {
        return this == REJECTED;
    }
    
    /**
     * Check if this status represents a pending claim
     * @return true if claim is pending
     */
    public boolean isPending() {
        return this == PENDING;
    }
    
    @Override
    public String toString() {
        return code;
    }
}
