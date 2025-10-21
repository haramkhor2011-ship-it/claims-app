package com.acme.claims.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

/**
 * JPA Entity for the claims_ref.denial_code table.
 * 
 * This entity represents denial codes used in remittance advice processing.
 * Denial codes indicate why claims or activities were denied or adjusted.
 * Each denial code is unique and may be optionally scoped by payer_code.
 * 
 * Features:
 * - Unique constraint on code
 * - Optional payer-specific scoping via payer_code
 * - Audit timestamps (created_at, updated_at)
 * - Full-text search support via trigram indexes
 * - No soft delete (denial codes are typically not deleted)
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@Entity
@Table(name = "denial_code", schema = "claims_ref")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DenialCode {

    /**
     * Primary key - auto-generated sequence ID
     */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    /**
     * Denial code (e.g., "CO-45", "PR-1", "MA-130")
     * Must be unique across all denial codes
     */
    @Column(name = "code", nullable = false, unique = true)
    private String code;

    /**
     * Human-readable description of the denial reason
     */
    @Column(name = "description")
    private String description;

    /**
     * Optional payer code for payer-specific denial codes
     * If null, the denial code applies to all payers
     */
    @Column(name = "payer_code")
    private String payerCode;

    /**
     * Timestamp when the record was created
     * Automatically set by Hibernate
     */
    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    /**
     * Timestamp when the record was last updated
     * Automatically updated by Hibernate on each modification
     */
    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    /**
     * Check if this denial code is payer-specific
     * 
     * @return true if payer_code is not null
     */
    public boolean isPayerSpecific() {
        return payerCode != null && !payerCode.trim().isEmpty();
    }

    /**
     * Check if this denial code applies to all payers
     * 
     * @return true if payer_code is null or empty
     */
    public boolean isGlobal() {
        return !isPayerSpecific();
    }

    /**
     * Get formatted display name for UI rendering
     * Format: "code - description"
     * 
     * @return formatted display string
     */
    public String getDisplayName() {
        if (description != null && !description.trim().isEmpty()) {
            return code + " - " + description;
        }
        return code;
    }

    /**
     * Get full code with payer scope for identification
     * Format: "code (payerCode)" or "code (GLOBAL)"
     * 
     * @return formatted unique identifier with scope
     */
    public String getFullCode() {
        if (isPayerSpecific()) {
            return code + " (" + payerCode + ")";
        }
        return code + " (GLOBAL)";
    }
}

