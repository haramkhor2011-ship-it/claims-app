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
 * JPA Entity for the claims_ref.activity_code table.
 * 
 * This entity represents activity/service codes (CPT, HCPCS, LOCAL, etc.) used in the
 * claims processing system. Each activity code has a unique combination of
 * code and type.
 * 
 * Features:
 * - Soft delete support via status field
 * - Audit timestamps (created_at, updated_at)
 * - Unique constraint on (code, type) combination
 * - Support for multiple code systems (CPT, HCPCS, LOCAL)
 * - Full-text search support via trigram indexes
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@Entity
@Table(name = "activity_code", schema = "claims_ref",
       uniqueConstraints = @UniqueConstraint(name = "uq_activity_code", columnNames = {"code", "type"}))
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ActivityCode {

    /**
     * Primary key - auto-generated sequence ID
     */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    /**
     * Activity type/category (e.g., "CPT", "HCPCS", "LOCAL", "PROCEDURE", "SERVICE")
     */
    @Column(name = "type")
    private String type;

    /**
     * Activity code (e.g., "99213", "99214", "A1234")
     */
    @Column(name = "code", nullable = false)
    private String code;

    /**
     * Code system (e.g., "CPT", "HCPCS", "LOCAL")
     * Defaults to "LOCAL"
     */
    @Column(name = "code_system", nullable = false)
    @Builder.Default
    private String codeSystem = "LOCAL";

    /**
     * Human-readable description of the activity/service
     */
    @Column(name = "description")
    private String description;

    /**
     * Status of the activity code (ACTIVE, INACTIVE)
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
     * Check if the activity code is active
     * 
     * @return true if status is ACTIVE
     */
    public boolean isActive() {
        return "ACTIVE".equals(this.status);
    }

    /**
     * Check if the activity code is inactive (soft deleted)
     * 
     * @return true if status is INACTIVE
     */
    public boolean isInactive() {
        return "INACTIVE".equals(this.status);
    }

    /**
     * Soft delete the activity code by setting status to INACTIVE
     */
    public void softDelete() {
        this.status = "INACTIVE";
    }

    /**
     * Reactivate the activity code by setting status to ACTIVE
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
     * Get full code with type for unique identification
     * Format: "code (type)"
     * 
     * @return formatted unique identifier
     */
    public String getFullCode() {
        if (type != null && !type.trim().isEmpty()) {
            return code + " (" + type + ")";
        }
        return code;
    }
}

