// FILE: src/main/java/com/acme/claims/domain/ClaimEvent.java
// Version: v2.0.0
// Maps: claims.claim_event (event_time set from Header.TransactionDate; provenance -> ingestion_file)
package com.acme.claims.domain.model.entity;

import com.acme.claims.domain.enums.ClaimEventType;
import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name="claim_event", schema="claims",
        indexes={@Index(name="idx_event_claim_key", columnList="claim_key_id")})
public class ClaimEvent {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="claim_key_id", nullable=false)
    private ClaimKey claimKey;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="ingestion_file_id")
    private IngestionFile ingestionFile; // provenance
    @Column(name="event_time", nullable=false) private OffsetDateTime eventTime;
    @Column(name="type", nullable=false) private ClaimEventType type; // converter -> SMALLINT
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="submission_id") private Submission submission;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="remittance_id") private Remittance remittance;
    @Column(name="created_at", nullable=false) private OffsetDateTime createdAt = OffsetDateTime.now();
    // getters/setters…
    public Long getId(){return id;} public void setId(Long id){this.id=id;}
    public ClaimKey getClaimKey(){return claimKey;} public void setClaimKey(ClaimKey v){this.claimKey=v;}
    public IngestionFile getIngestionFile(){return ingestionFile;} public void setIngestionFile(IngestionFile v){this.ingestionFile=v;}
    public OffsetDateTime getEventTime(){return eventTime;} public void setEventTime(OffsetDateTime v){this.eventTime=v;}
    public ClaimEventType getType(){return type;} public void setType(ClaimEventType v){this.type=v;}
    public Submission getSubmission(){return submission;} public void setSubmission(Submission v){this.submission=v;}
    public Remittance getRemittance(){return remittance;} public void setRemittance(Remittance v){this.remittance=v;}
    public OffsetDateTime getCreatedAt(){return createdAt;} public void setCreatedAt(OffsetDateTime v){this.createdAt=v;}
}
