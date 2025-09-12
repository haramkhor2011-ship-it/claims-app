// FILE: src/main/java/com/acme/claims/domain/ClaimResubmission.java
// Version: v2.0.0
// Maps: claims.claim_resubmission (1:1 with RESUBMISSION event)
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;

@Entity
@Table(name="claim_resubmission", schema="claims")
public class ClaimResubmission {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @OneToOne(fetch=FetchType.LAZY) @JoinColumn(name="claim_event_id", nullable=false, unique=true)
    private ClaimEvent claimEvent;
    @Column(name="resubmission_type", nullable=false) private String resubmissionType;
    @Column(name="comment", nullable=false) private String comment;
    @Column(name="attachment") private byte[] attachment;
    // getters/setters…
    public Long getId(){return id;} public void setId(Long id){this.id=id;}
    public ClaimEvent getClaimEvent(){return claimEvent;} public void setClaimEvent(ClaimEvent v){this.claimEvent=v;}
    public String getResubmissionType(){return resubmissionType;} public void setResubmissionType(String v){this.resubmissionType=v;}
    public String getComment(){return comment;} public void setComment(String v){this.comment=v;}
    public byte[] getAttachment(){return attachment;} public void setAttachment(byte[] v){this.attachment=v;}
}
