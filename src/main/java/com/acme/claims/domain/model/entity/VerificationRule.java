// FILE: src/main/java/com/acme/claims/monitoring/domain/VerificationRule.java
// Version: v2.0.0
// Maps: claims.verification_rule
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name="verification_rule", schema="claims",
        uniqueConstraints=@UniqueConstraint(name="verification_rule_code_key", columnNames="code"))
public class VerificationRule {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @Column(name="code", nullable=false) private String code;
    @Column(name="description", nullable=false) private String description;
    @Column(name="severity", nullable=false) private short severity; // 1/2/3
    @Column(name="sql_text", nullable=false, columnDefinition = "text") private String sqlText;
    @Column(name="active", nullable=false) private boolean active = true;
    @Column(name="created_at", nullable=false) private OffsetDateTime createdAt = OffsetDateTime.now();
    // getters/setters…


    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getCode() {
        return code;
    }

    public void setCode(String code) {
        this.code = code;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public short getSeverity() {
        return severity;
    }

    public void setSeverity(short severity) {
        this.severity = severity;
    }

    public String getSqlText() {
        return sqlText;
    }

    public void setSqlText(String sqlText) {
        this.sqlText = sqlText;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(OffsetDateTime createdAt) {
        this.createdAt = createdAt;
    }
}
