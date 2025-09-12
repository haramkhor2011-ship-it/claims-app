// FILE: src/main/java/com/acme/claims/monitoring/domain/IngestionFileAudit.java
// Version: v2.0.0
// Maps: claims.ingestion_file_audit
package com.acme.claims.domain.model.entity;


import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name="ingestion_file_audit", schema="claims",
        indexes={@Index(name="idx_file_audit_run", columnList="ingestion_run_id"),
                @Index(name="idx_file_audit_file", columnList="ingestion_file_id")})
public class IngestionFileAudit {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="ingestion_run_id", nullable=false)
    private IngestionRun ingestionRun;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="ingestion_file_id", nullable=false)
    private IngestionFile ingestionFile;
    @Column(name="status", nullable=false) private short status; // 0=ALREADY,1=OK,2=FAIL
    @Column(name="reason") private String reason;
    @Column(name="error_class") private String errorClass;
    @Column(name="error_message") private String errorMessage;
    @Column(name="validation_ok", nullable=false) private boolean validationOk=false;

    @Column(name="header_sender_id", nullable=false) private String headerSenderId;
    @Column(name="header_receiver_id", nullable=false) private String headerReceiverId;
    @Column(name="header_transaction_date", nullable=false) private OffsetDateTime headerTransactionDate;
    @Column(name="header_record_count", nullable=false) private Integer headerRecordCount;
    @Column(name="header_disposition_flag", nullable=false) private String headerDispositionFlag;

    @Column(name="parsed_claims") private Integer parsedClaims=0;
    @Column(name="parsed_encounters") private Integer parsedEncounters=0;
    @Column(name="parsed_diagnoses") private Integer parsedDiagnoses=0;
    @Column(name="parsed_activities") private Integer parsedActivities=0;
    @Column(name="parsed_observations") private Integer parsedObservations=0;
    @Column(name="persisted_claims") private Integer persistedClaims=0;
    @Column(name="persisted_encounters") private Integer persistedEncounters=0;
    @Column(name="persisted_diagnoses") private Integer persistedDiagnoses=0;
    @Column(name="persisted_activities") private Integer persistedActivities=0;
    @Column(name="persisted_observations") private Integer persistedObservations=0;
    @Column(name="parsed_remit_claims") private Integer parsedRemitClaims=0;
    @Column(name="parsed_remit_activities") private Integer parsedRemitActivities=0;
    @Column(name="persisted_remit_claims") private Integer persistedRemitClaims=0;
    @Column(name="persisted_remit_activities") private Integer persistedRemitActivities=0;
    @Column(name="projected_events") private Integer projectedEvents=0;
    @Column(name="projected_status_rows") private Integer projectedStatusRows=0;

    @Column(name="verification_passed") private Boolean verificationPassed;
    @Column(name="verification_failed_count") private Integer verificationFailedCount=0;
    @Column(name="ack_attempted", nullable=false) private boolean ackAttempted=false;
    @Column(name="ack_sent", nullable=false) private boolean ackSent=false;
    @Column(name="created_at", nullable=false) private OffsetDateTime createdAt = OffsetDateTime.now();
    // getters/setters…
    // (omitted here for brevity—generate standard getters/setters matching fields)
}
