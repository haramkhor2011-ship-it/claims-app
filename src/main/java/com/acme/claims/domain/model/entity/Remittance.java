// FILE: src/main/java/com/acme/claims/domain/Remittance.java
// Version: v2.0.0
// Maps: claims.remittance
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;

import java.time.OffsetDateTime;

@Entity
@Table(name = "remittance", schema = "claims",
        indexes = @Index(name = "idx_remittance_file", columnList = "ingestion_file_id"))
public class Remittance {
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

    public OffsetDateTime getTxAt() {
        return txAt;
    }

    public void setTxAt(OffsetDateTime txAt) {
        this.txAt = txAt;
    }
}
