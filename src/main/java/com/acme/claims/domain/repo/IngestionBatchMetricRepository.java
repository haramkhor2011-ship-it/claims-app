// FILE: src/main/java/com/acme/claims/monitoring/repo/IngestionBatchMetricRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.IngestionBatchMetric;
import com.acme.claims.domain.model.entity.IngestionFile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface IngestionBatchMetricRepository extends JpaRepository<IngestionBatchMetric, Long> {
    List<IngestionBatchMetric> findByIngestionFileOrderByStageAscBatchNoAsc(IngestionFile file);
}
