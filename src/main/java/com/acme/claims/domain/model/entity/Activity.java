// FILE: src/main/java/com/acme/claims/domain/Activity.java
// Version: v2.0.0
// Maps: claims.activity
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Table(name = "activity", schema = "claims",
        uniqueConstraints = @UniqueConstraint(name = "uq_activity_bk", columnNames = {"claim_id", "activity_id"}),
        indexes = @Index(name = "idx_activity_claim", columnList = "claim_id"))
public class Activity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "claim_id", nullable = false)
    private Claim claim;
    @Column(name = "activity_id", nullable = false)
    private String activityId;
    @Column(name = "start_at", nullable = false)
    private OffsetDateTime startAt;
    @Column(name = "type", nullable = false)
    private String type;
    @Column(name = "code", nullable = false)
    private String code;
    @Column(name = "quantity", nullable = false, precision = 14, scale = 2)
    private BigDecimal quantity;
    @Column(name = "net", nullable = false, precision = 14, scale = 2)
    private BigDecimal net;
    @Column(name = "clinician", nullable = false)
    private String clinician;
    @Column(name = "prior_authorization_id")
    private String priorAuthorizationId;
    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();
    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();
    @Column(name = "activity_code_ref_id")
    private Long activityCodeRefId;
    @Column(name = "clinician_ref_id")
    private Long clinicianRefId;

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

    public String getActivityId() {
        return activityId;
    }

    public void setActivityId(String v) {
        this.activityId = v;
    }

    public OffsetDateTime getStartAt() {
        return startAt;
    }

    public void setStartAt(OffsetDateTime v) {
        this.startAt = v;
    }

    public String getType() {
        return type;
    }

    public void setType(String v) {
        this.type = v;
    }

    public String getCode() {
        return code;
    }

    public void setCode(String v) {
        this.code = v;
    }

    public BigDecimal getQuantity() {
        return quantity;
    }

    public void setQuantity(BigDecimal v) {
        this.quantity = v;
    }

    public BigDecimal getNet() {
        return net;
    }

    public void setNet(BigDecimal v) {
        this.net = v;
    }

    public String getClinician() {
        return clinician;
    }

    public void setClinician(String v) {
        this.clinician = v;
    }

    public String getPriorAuthorizationId() {
        return priorAuthorizationId;
    }

    public void setPriorAuthorizationId(String v) {
        this.priorAuthorizationId = v;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(OffsetDateTime v) {
        this.createdAt = v;
    }

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(OffsetDateTime v) {
        this.updatedAt = v;
    }

    public Long getActivityCodeRefId() {
        return activityCodeRefId;
    }

    public void setActivityCodeRefId(Long activityCodeRefId) {
        this.activityCodeRefId = activityCodeRefId;
    }

    public Long getClinicianRefId() {
        return clinicianRefId;
    }

    public void setClinicianRefId(Long clinicianRefId) {
        this.clinicianRefId = clinicianRefId;
    }
}
