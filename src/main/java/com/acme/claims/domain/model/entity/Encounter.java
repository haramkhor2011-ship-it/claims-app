// FILE: src/main/java/com/acme/claims/domain/Encounter.java
// Version: v2.0.0
// Maps: claims.encounter
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;

import java.time.OffsetDateTime;

@Entity
@Table(name = "encounter", schema = "claims",
        indexes = @Index(name = "idx_encounter_claim", columnList = "claim_id"))
public class Encounter {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "claim_id", nullable = false)
    private Claim claim;
    @Column(name = "facility_id", nullable = false)
    private String facilityId;
    @Column(name = "type", nullable = false)
    private String type;
    @Column(name = "patient_id", nullable = false)
    private String patientId;
    @Column(name = "start_at", nullable = false)
    private OffsetDateTime startAt;
    @Column(name = "end_at")
    private OffsetDateTime endAt;
    @Column(name = "start_type")
    private String startType;
    @Column(name = "end_type")
    private String endType;
    @Column(name = "transfer_source")
    private String transferSource;
    @Column(name = "transfer_destination")
    private String transferDestination;

    @Column(name = "facility_ref_id")
    private Long facilityRefId;

    // getters/setters…
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Claim getClaim() {
        return claim;
    }

    public void setClaim(Claim v) {
        this.claim = v;
    }

    public String getFacilityId() {
        return facilityId;
    }

    public void setFacilityId(String v) {
        this.facilityId = v;
    }

    public String getType() {
        return type;
    }

    public void setType(String v) {
        this.type = v;
    }

    public String getPatientId() {
        return patientId;
    }

    public void setPatientId(String v) {
        this.patientId = v;
    }

    public OffsetDateTime getStartAt() {
        return startAt;
    }

    public void setStartAt(OffsetDateTime v) {
        this.startAt = v;
    }

    public OffsetDateTime getEndAt() {
        return endAt;
    }

    public void setEndAt(OffsetDateTime v) {
        this.endAt = v;
    }

    public String getStartType() {
        return startType;
    }

    public void setStartType(String v) {
        this.startType = v;
    }

    public String getEndType() {
        return endType;
    }

    public void setEndType(String v) {
        this.endType = v;
    }

    public String getTransferSource() {
        return transferSource;
    }

    public void setTransferSource(String v) {
        this.transferSource = v;
    }

    public String getTransferDestination() {
        return transferDestination;
    }

    public void setTransferDestination(String v) {
        this.transferDestination = v;
    }

    public Long getFacilityRefId() {
        return facilityRefId;
    }

    public void setFacilityRefId(Long facilityRefId) {
        this.facilityRefId = facilityRefId;
    }
}
