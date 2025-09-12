package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.OffsetDateTime;

@Entity
@Table(name = "claim_attachment", schema = "claims",
        uniqueConstraints = @UniqueConstraint(
                name = "uq_claim_attachment_key_event_file",
                columnNames = {"claim_key_id","claim_event_id","file_name"}))
@Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class ClaimAttachment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "claim_key_id", nullable = false)
    private Long claimKeyId;

    @Column(name = "claim_event_id", nullable = false)
    private Long claimEventId;

    @Column(name = "file_name")
    private String fileName;

    @Column(name = "mime_type")
    private String mimeType;

    @Lob
    @Column(name = "data_base64", nullable = false, columnDefinition = "bytea")
    private byte[] dataBase64;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();
}
