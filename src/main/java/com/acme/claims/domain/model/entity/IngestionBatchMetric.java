// FILE: src/main/java/com/acme/claims/monitoring/domain/IngestionBatchMetric.java
// Version: v2.0.0
// Maps: claims.ingestion_batch_metric
package com.acme.claims.domain.model.entity;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name="ingestion_batch_metric", schema="claims",
        indexes=@Index(name="idx_batch_metric_file", columnList="ingestion_file_id, stage, batch_no"))
public class IngestionBatchMetric {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="ingestion_file_id", nullable=false)
    private IngestionFile ingestionFile;
    @Column(name="stage", nullable=false) private String stage;
    @Column(name="target_table") private String targetTable;
    @Column(name="batch_no", nullable=false) private Integer batchNo;
    @Column(name="started_at", nullable=false) private OffsetDateTime startedAt = OffsetDateTime.now();
    @Column(name="ended_at") private OffsetDateTime endedAt;
    @Column(name="rows_attempted", nullable=false) private Integer rowsAttempted=0;
    @Column(name="rows_inserted", nullable=false) private Integer rowsInserted=0;
    @Column(name="conflicts_ignored", nullable=false) private Integer conflictsIgnored=0;
    @Column(name="retries", nullable=false) private Integer retries=0;
    @Column(name="status", nullable=false) private String status;
    @Column(name="error_class") private String errorClass;
    @Column(name="error_message") private String errorMessage;
    // getters/setters…
}
