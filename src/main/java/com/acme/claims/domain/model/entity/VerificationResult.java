// FILE: src/main/java/com/acme/claims/monitoring/domain/VerificationResult.java
// Version: v2.0.0
// Maps: claims.verification_result
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name="verification_result", schema="claims",
        indexes=@Index(name="idx_ver_result_run", columnList="verification_run_id, rule_id"))
public class VerificationResult {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="verification_run_id", nullable=false)
    private VerificationRun verificationRun;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="rule_id", nullable=false)
    private VerificationRule rule;
    @Column(name="ok", nullable=false) private boolean ok;
    @Column(name="rows_affected") private Long rowsAffected;
    @Column(name="sample_json", columnDefinition="jsonb") private String sampleJson;
    @Column(name="message") private String message;
    @Column(name="executed_at", nullable=false) private OffsetDateTime executedAt = OffsetDateTime.now();
    // getters/setters…

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public VerificationRun getVerificationRun() {
        return verificationRun;
    }

    public void setVerificationRun(VerificationRun verificationRun) {
        this.verificationRun = verificationRun;
    }

    public VerificationRule getRule() {
        return rule;
    }

    public void setRule(VerificationRule rule) {
        this.rule = rule;
    }

    public boolean isOk() {
        return ok;
    }

    public void setOk(boolean ok) {
        this.ok = ok;
    }

    public Long getRowsAffected() {
        return rowsAffected;
    }

    public void setRowsAffected(Long rowsAffected) {
        this.rowsAffected = rowsAffected;
    }

    public String getSampleJson() {
        return sampleJson;
    }

    public void setSampleJson(String sampleJson) {
        this.sampleJson = sampleJson;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public OffsetDateTime getExecutedAt() {
        return executedAt;
    }

    public void setExecutedAt(OffsetDateTime executedAt) {
        this.executedAt = executedAt;
    }
}
