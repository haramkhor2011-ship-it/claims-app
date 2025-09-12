// FILE: src/main/java/com/acme/claims/monitoring/repo/IngestionRunRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.IngestionRun;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;

@Repository
public interface IngestionRunRepository extends JpaRepository<IngestionRun, Long> {
    List<IngestionRun> findByStartedAtBetweenOrderByStartedAtDesc(OffsetDateTime from, OffsetDateTime to);
}
