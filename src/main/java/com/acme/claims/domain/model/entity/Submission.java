// FILE: src/main/java/com/acme/claims/domain/Submission.java
// Version: v2.0.0
// Maps: claims.submission
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.DynamicUpdate;

import java.time.OffsetDateTime;

@Entity
@Table(name = "submission", schema = "claims",
        indexes = @Index(name = "idx_submission_file", columnList = "ingestion_file_id"))
@DynamicUpdate
public class Submission {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ingestion_file_id", nullable = false)
    private IngestionFile ingestionFile;
    @Column(name = "tx_at", nullable = false, insertable = false, updatable = false)
    private OffsetDateTime txAt;

    // getters/setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public IngestionFile getIngestionFile() {
        return ingestionFile;
    }

    public void setIngestionFile(IngestionFile v) {
        this.ingestionFile = v;
    }
}
