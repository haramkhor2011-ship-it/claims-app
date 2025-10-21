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
 * JPA Entity for the claims_ref.facility table.
 * 
 * This entity represents provider facilities in the claims processing system.
 * Each facility has a unique facility_code that corresponds to external FacilityID
 * from DHA/eClaim systems.
 * 
 * Features:
 * - Soft delete support via status field
 * - Audit timestamps (created_at, updated_at)
 * - Unique constraint on facility_code
 * - Full-text search support via trigram indexes
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@Entity
@Table(name = "facility", schema = "claims_ref")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Facility {

    /**
     * Primary key - auto-generated sequence ID
     */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    /**
     * External FacilityID from DHA/eClaim systems
     * Must be unique across all facilities
     */
    @Column(name = "facility_code", nullable = false, unique = true)
    private String facilityCode;

    /**
     * Human-readable facility name
     */
    @Column(name = "name")
    private String name;

    /**
     * City where the facility is located
     */
    @Column(name = "city")
    private String city;

    /**
     * Country where the facility is located
     */
    @Column(name = "country")
    private String country;

    /**
     * Status of the facility (ACTIVE, INACTIVE)
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
     * Check if the facility is active
     * 
     * @return true if status is ACTIVE
     */
    public boolean isActive() {
        return "ACTIVE".equals(this.status);
    }

    /**
     * Check if the facility is inactive (soft deleted)
     * 
     * @return true if status is INACTIVE
     */
    public boolean isInactive() {
        return "INACTIVE".equals(this.status);
    }

    /**
     * Soft delete the facility by setting status to INACTIVE
     */
    public void softDelete() {
        this.status = "INACTIVE";
    }

    /**
     * Reactivate the facility by setting status to ACTIVE
     */
    public void reactivate() {
        this.status = "ACTIVE";
    }

    /**
     * Get formatted display name for UI rendering
     * Format: "facilityCode - name"
     * 
     * @return formatted display string
     */
    public String getDisplayName() {
        if (name != null && !name.trim().isEmpty()) {
            return facilityCode + " - " + name;
        }
        return facilityCode;
    }
}

