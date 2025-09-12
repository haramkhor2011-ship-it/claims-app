// FILE: src/main/java/com/acme/claims/domain/ClaimKey.java
// Version: v2.0.0
// Maps: claims.claim_key
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity @Table(name="claim_key", schema="claims")
public class ClaimKey {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @Column(name="claim_id", nullable=false, unique=true) private String claimId;
    @Column(name="created_at", nullable=false) private OffsetDateTime createdAt = OffsetDateTime.now();
    // getters/setters
    public Long getId(){return id;} public void setId(Long id){this.id=id;}
    public String getClaimId(){return claimId;} public void setClaimId(String v){this.claimId=v;}
    public OffsetDateTime getCreatedAt(){return createdAt;} public void setCreatedAt(OffsetDateTime v){this.createdAt=v;}
}
