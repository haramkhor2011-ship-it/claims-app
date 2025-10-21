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
 * JPA Entity for the claims_ref.payer table.
 * 
 * This entity represents payers (insurance companies, government entities, etc.)
 * in the claims processing system. Each payer has a unique payer_code that
 * corresponds to external PayerID from DHA/eClaim systems.
 * 
 * Features:
 * - Soft delete support via status field
 * - Audit timestamps (created_at, updated_at)
 * - Unique constraint on payer_code
 * - Classification field for payer categorization
 * - Full-text search support via trigram indexes
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@Entity
@Table(name = "payer", schema = "claims_ref")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Payer {

    /**
     * Primary key - auto-generated sequence ID
     */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    /**
     * External PayerID from DHA/eClaim systems
     * Must be unique across all payers
     */
    @Column(name = "payer_code", nullable = false, unique = true)
    private String payerCode;

    /**
     * Human-readable payer name
     */
    @Column(name = "name")
    private String name;

    /**
     * Status of the payer (ACTIVE, INACTIVE)
     * Used for soft delete functionality
     */
    @Column(name = "status", nullable = false)
    @Builder.Default
    private String status = "ACTIVE";

    /**
     * Classification of the payer (e.g., GOVERNMENT, PRIVATE, SELF_PAY)
     */
    @Column(name = "classification")
    private String classification;

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
     * Check if the payer is active
     * 
     * @return true if status is ACTIVE
     */
    public boolean isActive() {
        return "ACTIVE".equals(this.status);
    }

    /**
     * Check if the payer is inactive (soft deleted)
     * 
     * @return true if status is INACTIVE
     */
    public boolean isInactive() {
        return "INACTIVE".equals(this.status);
    }

    /**
     * Soft delete the payer by setting status to INACTIVE
     */
    public void softDelete() {
        this.status = "INACTIVE";
    }

    /**
     * Reactivate the payer by setting status to ACTIVE
     */
    public void reactivate() {
        this.status = "ACTIVE";
    }

    /**
     * Get formatted display name for UI rendering
     * Format: "payerCode - name"
     * 
     * @return formatted display string
     */
    public String getDisplayName() {
        if (name != null && !name.trim().isEmpty()) {
            return payerCode + " - " + name;
        }
        return payerCode;
    }
}

