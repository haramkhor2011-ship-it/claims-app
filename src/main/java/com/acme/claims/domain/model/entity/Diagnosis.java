// FILE: src/main/java/com/acme/claims/domain/Diagnosis.java
// Version: v2.0.0
// Maps: claims.diagnosis
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "diagnosis", schema = "claims",
        indexes = @Index(name = "idx_diagnosis_claim", columnList = "claim_id"))
public class Diagnosis {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "claim_id", nullable = false)
    private Claim claim;
    @Column(name = "diag_type", nullable = false)
    private String diagType;
    @Column(name = "code", nullable = false)
    private String code;
    @Column(name = "diagnosis_code_ref_id")
    private Long diagnosisCodeRefId;

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

    public String getDiagType() {
        return diagType;
    }

    public void setDiagType(String v) {
        this.diagType = v;
    }

    public String getCode() {
        return code;
    }

    public void setCode(String v) {
        this.code = v;
    }

    public Long getDiagnosisCodeRefId() {
        return diagnosisCodeRefId;
    }

    public void setDiagnosisCodeRefId(Long diagnosisCodeRefId) {
        this.diagnosisCodeRefId = diagnosisCodeRefId;
    }
}
