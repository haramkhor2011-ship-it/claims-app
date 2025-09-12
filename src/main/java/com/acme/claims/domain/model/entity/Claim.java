// FILE: src/main/java/com/acme/claims/domain/Claim.java
// Version: v2.0.0
// Maps: claims.claim
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Table(name = "claim", schema = "claims",
        uniqueConstraints = @UniqueConstraint(name = "uq_claim_per_key", columnNames = "claim_key_id"),
        indexes = @Index(name = "idx_claim_claim_key", columnList = "claim_key_id"))
public class Claim {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "claim_key_id", nullable = false)
    private ClaimKey claimKey;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "submission_id", nullable = false)
    private Submission submission;
    @Column(name = "id_payer")
    private String idPayer;
    @Column(name = "member_id")
    private String memberId;
    @Column(name = "payer_id", nullable = false)
    private String payerId;
    @Column(name = "provider_id", nullable = false)
    private String providerId;
    @Column(name = "emirates_id_number", nullable = false)
    private String emiratesIdNumber;
    @Column(name = "gross", nullable = false, precision = 14, scale = 2)
    private BigDecimal gross;
    @Column(name = "patient_share", nullable = false, precision = 14, scale = 2)
    private BigDecimal patientShare;
    @Column(name = "net", nullable = false, precision = 14, scale = 2)
    private BigDecimal net;
    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();
    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();
    @Column(name = "payer_ref_id")
    private Long payerRefId;
    @Column(name = "provider_ref_id")
    private Long providerRefId;
    @Column(name = "tx_at", nullable = false, insertable = false, updatable = false)
    private OffsetDateTime txAt;
    @Column(name = "comments")
    private String comments;

    // getters/setters...
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public ClaimKey getClaimKey() {
        return claimKey;
    }

    public void setClaimKey(ClaimKey v) {
        this.claimKey = v;
    }

    public Submission getSubmission() {
        return submission;
    }

    public void setSubmission(Submission v) {
        this.submission = v;
    }

    public String getIdPayer() {
        return idPayer;
    }

    public void setIdPayer(String v) {
        this.idPayer = v;
    }

    public String getMemberId() {
        return memberId;
    }

    public void setMemberId(String v) {
        this.memberId = v;
    }

    public String getPayerId() {
        return payerId;
    }

    public void setPayerId(String v) {
        this.payerId = v;
    }

    public String getProviderId() {
        return providerId;
    }

    public void setProviderId(String v) {
        this.providerId = v;
    }

    public String getEmiratesIdNumber() {
        return emiratesIdNumber;
    }

    public void setEmiratesIdNumber(String v) {
        this.emiratesIdNumber = v;
    }

    public BigDecimal getGross() {
        return gross;
    }

    public void setGross(BigDecimal v) {
        this.gross = v;
    }

    public BigDecimal getPatientShare() {
        return patientShare;
    }

    public void setPatientShare(BigDecimal v) {
        this.patientShare = v;
    }

    public BigDecimal getNet() {
        return net;
    }

    public void setNet(BigDecimal v) {
        this.net = v;
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

    public OffsetDateTime getTxAt() {
        return txAt;
    }

    public void setTxAt(OffsetDateTime txAt) {
        this.txAt = txAt;
    }

    public String getComments() {
        return comments;
    }

    public void setComments(String comments) {
        this.comments = comments;
    }
}
