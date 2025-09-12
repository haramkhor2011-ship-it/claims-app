// FILE: src/main/java/com/acme/claims/domain/Observation.java
// Version: v2.0.0
// Maps: claims.observation
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;

import java.time.OffsetDateTime;

@Entity
@Table(name = "observation", schema = "claims",
        indexes = @Index(name = "idx_obs_activity", columnList = "activity_id"))
public class Observation {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "activity_id", nullable = false)
    private Activity activity;
    @Column(name = "obs_type", nullable = false)
    private String obsType;
    @Column(name = "obs_code", nullable = false)
    private String obsCode;
    @Column(name = "value_text")
    private String valueText;
    @Column(name = "value_type")
    private String valueType;
    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();
    @Lob
    @Basic(fetch = FetchType.LAZY)
    @Column(name = "file_bytes")
    private byte[] fileBytes;

    // getters/setters…
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Activity getActivity() {
        return activity;
    }

    public void setActivity(Activity v) {
        this.activity = v;
    }

    public String getObsType() {
        return obsType;
    }

    public void setObsType(String v) {
        this.obsType = v;
    }

    public String getObsCode() {
        return obsCode;
    }

    public void setObsCode(String v) {
        this.obsCode = v;
    }

    public String getValueText() {
        return valueText;
    }

    public void setValueText(String v) {
        this.valueText = v;
    }

    public String getValueType() {
        return valueType;
    }

    public void setValueType(String v) {
        this.valueType = v;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(OffsetDateTime v) {
        this.createdAt = v;
    }

    public byte[] getFileBytes() {
        return fileBytes;
    }

    public void setFileBytes(byte[] fileBytes) {
        this.fileBytes = fileBytes;
    }
}
