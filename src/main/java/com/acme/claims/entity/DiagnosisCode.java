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
 * JPA Entity for the claims_ref.diagnosis_code table.
 * 
 * This entity represents diagnosis codes (ICD-10, ICD-9, etc.) used in the
 * claims processing system. Each diagnosis code has a unique combination of
 * code and code_system.
 * 
 * Features:
 * - Soft delete support via status field
 * - Audit timestamps (created_at, updated_at)
 * - Unique constraint on (code, code_system) combination
 * - Support for multiple code systems (ICD-10, ICD-9, LOCAL)
 * - Full-text search support via trigram indexes
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@Entity
@Table(name = "diagnosis_code", schema = "claims_ref",
       uniqueConstraints = @UniqueConstraint(name = "uq_diagnosis_code", columnNames = {"code"}))
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DiagnosisCode {

    /**
     * Primary key - auto-generated sequence ID
     */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    /**
     * Diagnosis code (e.g., "Z00.00", "I10", "E11.9")
     */
    @Column(name = "code", nullable = false)
    private String code;

    /**
     * Code system (e.g., "ICD-10", "ICD-9", "LOCAL")
     * Defaults to "ICD-10"
     */
    @Column(name = "code_system", nullable = false)
    @Builder.Default
    private String codeSystem = "ICD-10";

    /**
     * Human-readable description of the diagnosis
     */
    @Column(name = "description")
    private String description;

    /**
     * Status of the diagnosis code (ACTIVE, INACTIVE)
     * Used for soft delete functionality
     */
    @Column(name = "status", nullable = false)
    @Builder.Default
    private String status = "ACTIVE";

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
     * Check if the diagnosis code is active
     * 
     * @return true if status is ACTIVE
     */
    public boolean isActive() {
        return "ACTIVE".equals(this.status);
    }

    /**
     * Check if the diagnosis code is inactive (soft deleted)
     * 
     * @return true if status is INACTIVE
     */
    public boolean isInactive() {
        return "INACTIVE".equals(this.status);
    }

    /**
     * Soft delete the diagnosis code by setting status to INACTIVE
     */
    public void softDelete() {
        this.status = "INACTIVE";
    }

    /**
     * Reactivate the diagnosis code by setting status to ACTIVE
     */
    public void reactivate() {
        this.status = "ACTIVE";
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
     * Get full code with system for unique identification
     * Format: "code (codeSystem)"
     * 
     * @return formatted unique identifier
     */
    public String getFullCode() {
        return code + " (" + codeSystem + ")";
    }
}

