// FILE: src/main/java/com/acme/claims/monitoring/domain/IngestionRun.java
// Version: v2.0.0
// Maps: claims.ingestion_run
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity @Table(name="ingestion_run", schema="claims")
public class IngestionRun {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @Column(name="started_at", nullable=false) private OffsetDateTime startedAt = OffsetDateTime.now();
    @Column(name="ended_at") private OffsetDateTime endedAt;
    @Column(name="profile", nullable=false) private String profile;
    @Column(name="fetcher_name", nullable=false) private String fetcherName;
    @Column(name="acker_name") private String ackerName;
    @Column(name="poll_reason") private String pollReason;
    @Column(name="files_discovered", nullable=false) private Integer filesDiscovered = 0;
    @Column(name="files_pulled", nullable=false) private Integer filesPulled = 0;
    @Column(name="files_processed_ok", nullable=false) private Integer filesProcessedOk = 0;
    @Column(name="files_failed", nullable=false) private Integer filesFailed = 0;
    @Column(name="files_already", nullable=false) private Integer filesAlready = 0;
    @Column(name="acks_sent", nullable=false) private Integer acksSent = 0;
    // getters/setters…
    public Long getId(){return id;} public void setId(Long id){this.id=id;}
    public OffsetDateTime getStartedAt(){return startedAt;} public void setStartedAt(OffsetDateTime v){this.startedAt=v;}
    public OffsetDateTime getEndedAt(){return endedAt;} public void setEndedAt(OffsetDateTime v){this.endedAt=v;}
    public String getProfile(){return profile;} public void setProfile(String v){this.profile=v;}
    public String getFetcherName(){return fetcherName;} public void setFetcherName(String v){this.fetcherName=v;}
    public String getAckerName(){return ackerName;} public void setAckerName(String v){this.ackerName=v;}
    public String getPollReason(){return pollReason;} public void setPollReason(String v){this.pollReason=v;}
    public Integer getFilesDiscovered(){return filesDiscovered;} public void setFilesDiscovered(Integer v){this.filesDiscovered=v;}
    public Integer getFilesPulled(){return filesPulled;} public void setFilesPulled(Integer v){this.filesPulled=v;}
    public Integer getFilesProcessedOk(){return filesProcessedOk;} public void setFilesProcessedOk(Integer v){this.filesProcessedOk=v;}
    public Integer getFilesFailed(){return filesFailed;} public void setFilesFailed(Integer v){this.filesFailed=v;}
    public Integer getFilesAlready(){return filesAlready;} public void setFilesAlready(Integer v){this.filesAlready=v;}
    public Integer getAcksSent(){return acksSent;} public void setAcksSent(Integer v){this.acksSent=v;}
}
