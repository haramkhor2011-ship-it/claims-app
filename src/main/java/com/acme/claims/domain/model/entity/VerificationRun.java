// FILE: src/main/java/com/acme/claims/monitoring/domain/VerificationRun.java
// Version: v2.0.0
// Maps: claims.verification_run
package com.acme.claims.domain.model.entity;


import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name="verification_run", schema="claims",
        indexes=@Index(name="idx_ver_run_file", columnList="ingestion_file_id"))
public class VerificationRun {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="ingestion_file_id", nullable=false)
    private IngestionFile ingestionFile;
    @Column(name="started_at", nullable=false) private OffsetDateTime startedAt = OffsetDateTime.now();
    @Column(name="ended_at") private OffsetDateTime endedAt;
    @Column(name="passed") private Boolean passed;
    @Column(name="failed_rules", nullable=false) private Integer failedRules=0;
    // getters/setters…

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public IngestionFile getIngestionFile() {
        return ingestionFile;
    }

    public void setIngestionFile(IngestionFile ingestionFile) {
        this.ingestionFile = ingestionFile;
    }

    public OffsetDateTime getStartedAt() {
        return startedAt;
    }

    public void setStartedAt(OffsetDateTime startedAt) {
        this.startedAt = startedAt;
    }

    public OffsetDateTime getEndedAt() {
        return endedAt;
    }

    public void setEndedAt(OffsetDateTime endedAt) {
        this.endedAt = endedAt;
    }

    public Boolean getPassed() {
        return passed;
    }

    public void setPassed(Boolean passed) {
        this.passed = passed;
    }

    public Integer getFailedRules() {
        return failedRules;
    }

    public void setFailedRules(Integer failedRules) {
        this.failedRules = failedRules;
    }
}
