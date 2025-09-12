// FILE: src/main/java/com/acme/claims/domain/ClaimStatusTimeline.java
// Version: v2.0.0
// Maps: claims.claim_status_timeline
package com.acme.claims.domain.model.entity;

import com.acme.claims.domain.enums.ClaimStatus;
import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name="claim_status_timeline", schema="claims",
        indexes=@Index(name="idx_cst_claim_key_time", columnList="claim_key_id, status_time"))
public class ClaimStatusTimeline {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="claim_key_id", nullable=false)
    private ClaimKey claimKey;
    @Column(name="status", nullable=false) private ClaimStatus status; // converter -> SMALLINT
    @Column(name="status_time", nullable=false) private OffsetDateTime statusTime;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="claim_event_id")
    private ClaimEvent claimEvent;
    @Column(name="created_at", nullable=false) private OffsetDateTime createdAt = OffsetDateTime.now();
    // getters/setters…
    public Long getId(){return id;} public void setId(Long id){this.id=id;}
    public ClaimKey getClaimKey(){return claimKey;} public void setClaimKey(ClaimKey v){this.claimKey=v;}
    public ClaimStatus getStatus(){return status;} public void setStatus(ClaimStatus v){this.status=v;}
    public OffsetDateTime getStatusTime(){return statusTime;} public void setStatusTime(OffsetDateTime v){this.statusTime=v;}
    public ClaimEvent getClaimEvent(){return claimEvent;} public void setClaimEvent(ClaimEvent v){this.claimEvent=v;}
    public OffsetDateTime getCreatedAt(){return createdAt;} public void setCreatedAt(OffsetDateTime v){this.createdAt=v;}
}
