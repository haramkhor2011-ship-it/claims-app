// FILE: src/main/java/com/acme/claims/domain/RemittanceClaim.java
// Version: v2.0.0
// Maps: claims.remittance_claim
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;

import java.time.OffsetDateTime;

@Entity
@Table(name = "remittance_claim", schema = "claims",
        uniqueConstraints = @UniqueConstraint(name = "uq_remittance_claim", columnNames = {"remittance_id", "claim_key_id"}),
        indexes = {@Index(name = "idx_remittance_claim_key", columnList = "claim_key_id"),
                @Index(name = "idx_remittance_claim_remit", columnList = "remittance_id")})
public class RemittanceClaim {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "remittance_id", nullable = false)
    private Remittance remittance;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "claim_key_id", nullable = false)
    private ClaimKey claimKey;
    @Column(name = "id_payer", nullable = false)
    private String idPayer;
    @Column(name = "provider_id")
    private String providerId;
    @Column(name = "denial_code")
    private String denialCode;
    @Column(name = "payment_reference", nullable = false)
    private String paymentReference;
    @Column(name = "date_settlement")
    private OffsetDateTime dateSettlement;
    @Column(name = "facility_id")
    private String facilityId; // Remittance Encounter/FacilityID (stored directly)
    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();
    @Column(name = "denial_code_ref_id")
    private Long denialCodeRefId;
    @Column(name ="payer_ref_id")
    private Long payerRefId;
    @Column(name ="provider_ref_id")
    private Long providerRefId;
    @Column(name = "comments")
    private String comments;
    // getters/setters…
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Remittance getRemittance() {
        return remittance;
    }

    public void setRemittance(Remittance v) {
        this.remittance = v;
    }

    public ClaimKey getClaimKey() {
        return claimKey;
    }

    public void setClaimKey(ClaimKey v) {
        this.claimKey = v;
    }

    public String getIdPayer() {
        return idPayer;
    }

    public void setIdPayer(String v) {
        this.idPayer = v;
    }

    public String getProviderId() {
        return providerId;
    }

    public void setProviderId(String v) {
        this.providerId = v;
    }

    public String getDenialCode() {
        return denialCode;
    }

    public void setDenialCode(String v) {
        this.denialCode = v;
    }

    public String getPaymentReference() {
        return paymentReference;
    }

    public void setPaymentReference(String v) {
        this.paymentReference = v;
    }

    public OffsetDateTime getDateSettlement() {
        return dateSettlement;
    }

    public void setDateSettlement(OffsetDateTime v) {
        this.dateSettlement = v;
    }

    public String getFacilityId() {
        return facilityId;
    }

    public void setFacilityId(String v) {
        this.facilityId = v;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(OffsetDateTime v) {
        this.createdAt = v;
    }

    public Long getDenialCodeRefId() {
        return denialCodeRefId;
    }

    public void setDenialCodeRefId(Long denialCodeRefId) {
        this.denialCodeRefId = denialCodeRefId;
    }

    public Long getPayerRefId() {
        return payerRefId;
    }

    public void setPayerRefId(Long payerRefId) {
        this.payerRefId = payerRefId;
    }

    public Long getProviderRefId() {
        return providerRefId;
    }

    public void setProviderRefId(Long providerRefId) {
        this.providerRefId = providerRefId;
    }

    public String getComments() {
        return comments;
    }

    public void setComments(String v) {
        this.comments = v;
    }
}
