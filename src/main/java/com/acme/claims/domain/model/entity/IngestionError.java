// FILE: src/main/java/com/acme/claims/monitoring/domain/IngestionError.java
// Version: v2.0.0
// Maps: claims.ingestion_error
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name="ingestion_error", schema="claims",
        indexes=@Index(name="idx_ing_error_file_stage", columnList="ingestion_file_id, stage, occurred_at desc"))
public class IngestionError {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="ingestion_file_id", nullable=false)
    private IngestionFile ingestionFile;
    @Column(name="stage", nullable=false) private String stage;
    @Column(name="object_type") private String objectType;
    @Column(name="object_key") private String objectKey;
    @Column(name="error_code") private String errorCode;
    @Column(name="error_message", nullable=false) private String errorMessage;
    @Column(name="stack_excerpt") private String stackExcerpt;
    @Column(name="retryable", nullable=false) private boolean retryable=false;
    @Column(name="occurred_at", nullable=false) private OffsetDateTime occurredAt = OffsetDateTime.now();
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

    public String getStage() {
        return stage;
    }

    public void setStage(String stage) {
        this.stage = stage;
    }

    public String getObjectType() {
        return objectType;
    }

    public void setObjectType(String objectType) {
        this.objectType = objectType;
    }

    public String getObjectKey() {
        return objectKey;
    }

    public void setObjectKey(String objectKey) {
        this.objectKey = objectKey;
    }

    public String getErrorCode() {
        return errorCode;
    }

    public void setErrorCode(String errorCode) {
        this.errorCode = errorCode;
    }

    public String getErrorMessage() {
        return errorMessage;
    }

    public void setErrorMessage(String errorMessage) {
        this.errorMessage = errorMessage;
    }

    public String getStackExcerpt() {
        return stackExcerpt;
    }

    public void setStackExcerpt(String stackExcerpt) {
        this.stackExcerpt = stackExcerpt;
    }

    public boolean isRetryable() {
        return retryable;
    }

    public void setRetryable(boolean retryable) {
        this.retryable = retryable;
    }

    public OffsetDateTime getOccurredAt() {
        return occurredAt;
    }

    public void setOccurredAt(OffsetDateTime occurredAt) {
        this.occurredAt = occurredAt;
    }
}
