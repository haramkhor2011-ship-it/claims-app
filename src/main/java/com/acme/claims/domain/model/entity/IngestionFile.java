// FILE: src/main/java/com/acme/claims/domain/IngestionFile.java
// Version: v2.0.0 (SSOT: Combined DDL - 2025-09-02)
// Maps: claims.ingestion_file
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

import java.time.OffsetDateTime;

@Entity
@Table(name = "ingestion_file", schema = "claims",
        uniqueConstraints = @UniqueConstraint(name = "uq_ingestion_file", columnNames = "file_id"))
@NoArgsConstructor
@AllArgsConstructor
public class IngestionFile {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "file_id", nullable = false)
    private String fileId;
    @Column(name = "root_type", nullable = false)
    private short rootType; // 1=Submission,2=Remittance
    @Column(name = "sender_id", nullable = false)
    private String senderId;
    @Column(name = "receiver_id", nullable = false)
    private String receiverId;
    @Column(name = "transaction_date", nullable = false)
    private OffsetDateTime transactionDate;
    @Column(name = "record_count_declared", nullable = false)
    private Integer recordCountDeclared;
    @Column(name = "disposition_flag", nullable = false)
    private String dispositionFlag;
    @Lob
    @Basic(fetch = FetchType.LAZY)
    @Column(name = "xml_bytes", nullable = false, columnDefinition = "bytea")
    private byte[] xmlBytes;
    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();
    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();

    // getters/setters…
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getFileId() {
        return fileId;
    }

    public void setFileId(String v) {
        this.fileId = v;
    }

    public short getRootType() {
        return rootType;
    }

    public void setRootType(short v) {
        this.rootType = v;
    }

    public String getSenderId() {
        return senderId;
    }

    public void setSenderId(String v) {
        this.senderId = v;
    }

    public String getReceiverId() {
        return receiverId;
    }

    public void setReceiverId(String v) {
        this.receiverId = v;
    }

    public OffsetDateTime getTransactionDate() {
        return transactionDate;
    }

    public void setTransactionDate(OffsetDateTime v) {
        this.transactionDate = v;
    }

    public Integer getRecordCountDeclared() {
        return recordCountDeclared;
    }

    public void setRecordCountDeclared(Integer v) {
        this.recordCountDeclared = v;
    }

    public String getDispositionFlag() {
        return dispositionFlag;
    }

    public void setDispositionFlag(String v) {
        this.dispositionFlag = v;
    }

    public byte[] getXmlBytes() {
        return xmlBytes;
    }

    public void setXmlBytes(byte[] v) {
        this.xmlBytes = v;
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
}
