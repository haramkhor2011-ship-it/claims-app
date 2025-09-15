package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;

/**
 * Entity for claims.facility_dhpo_config (lean version).
 * DDL owner: Flyway/Liquibase or manual migration.
 * Notes:
 * - enc_meta_json is kept as JSONB in DB; mapped here as String to avoid extra deps.
 * - dhpo_username_enc / dhpo_password_enc are ciphertext blobs (BYTEA).
 * - endpoint_url_for_erx is included for future eRx flows.
 */
@Entity
@Table(
        name = "facility_dhpo_config",
        schema = "claims",
        uniqueConstraints = {
                @UniqueConstraint(name = "uq_facility_dhpo_config_facility_code", columnNames = "facility_code")
        }
)
public class FacilityDhpoConfig {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;                                 // BIGSERIAL

    @Column(name = "facility_code", nullable = false, columnDefinition = "citext")
    private String facilityCode;                     // CITEXT NOT NULL

    @Column(name = "facility_name", nullable = false)
    private String facilityName;                     // TEXT NOT NULL

    @Column(name = "endpoint_url", nullable = false)
    private String endpointUrl = "https://dhpo.eclaimlink.ae/ValidateTransactions.asmx"; // TEXT NOT NULL DEFAULT ...

    @Column(name = "endpoint_url_for_erx", nullable = false)
    private String endpointUrlForErx = "https://dhpo.eclaimlink.ae/eRxValidateTransactions.asmx"; // TEXT NOT NULL DEFAULT ...

    @JdbcTypeCode(SqlTypes.BINARY)
    @Column(name = "dhpo_username_enc", nullable = false)
    private byte[] dhpoUsernameEnc;                  // BYTEA NOT NULL

    @JdbcTypeCode(SqlTypes.BINARY)
    @Column(name = "dhpo_password_enc", nullable = false)
    private byte[] dhpoPasswordEnc;                  // BYTEA NOT NULL

    @Column(name = "enc_meta_json", nullable = false, columnDefinition = "jsonb")
    private String encMetaJson;                      // JSONB NOT NULL : {"kek_version":1,"alg":"AES/GCM","iv":"...","tagBits":128}

    @Column(name = "active", nullable = false)
    private boolean active = true;                   // BOOLEAN NOT NULL DEFAULT TRUE

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;                // TIMESTAMPTZ NOT NULL DEFAULT now()

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;                // TIMESTAMPTZ NOT NULL DEFAULT now()

    // --- lifecycle hooks ---
    @PrePersist
    void onCreate() {
        final var now = OffsetDateTime.now();
        if (createdAt == null) createdAt = now;
        if (updatedAt == null) updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = OffsetDateTime.now();
    }

    // --- getters/setters (explicit for clarity & Lombok-free compatibility) ---
    public Long getId() {
        return id;
    }

    public String getFacilityCode() {
        return facilityCode;
    }

    public void setFacilityCode(String facilityCode) {
        this.facilityCode = facilityCode;
    }

    public String getFacilityName() {
        return facilityName;
    }

    public void setFacilityName(String facilityName) {
        this.facilityName = facilityName;
    }

    public String getEndpointUrl() {
        return endpointUrl;
    }

    public void setEndpointUrl(String endpointUrl) {
        this.endpointUrl = endpointUrl;
    }

    public String getEndpointUrlForErx() {
        return endpointUrlForErx;
    }

    public void setEndpointUrlForErx(String endpointUrlForErx) {
        this.endpointUrlForErx = endpointUrlForErx;
    }

    public byte[] getDhpoUsernameEnc() {
        return dhpoUsernameEnc;
    }

    public void setDhpoUsernameEnc(byte[] dhpoUsernameEnc) {
        this.dhpoUsernameEnc = dhpoUsernameEnc;
    }

    public byte[] getDhpoPasswordEnc() {
        return dhpoPasswordEnc;
    }

    public void setDhpoPasswordEnc(byte[] dhpoPasswordEnc) {
        this.dhpoPasswordEnc = dhpoPasswordEnc;
    }

    public String getEncMetaJson() {
        return encMetaJson;
    }

    public void setEncMetaJson(String encMetaJson) {
        this.encMetaJson = encMetaJson;
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

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(OffsetDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
}
