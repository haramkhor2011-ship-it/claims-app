// FILE: src/main/java/com/acme/claims/monitoring/repo/IngestionErrorRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.IngestionError;
import com.acme.claims.domain.model.entity.IngestionFile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface IngestionErrorRepository extends JpaRepository<IngestionError, Long> {
    List<IngestionError> findByIngestionFileOrderByOccurredAtDesc(IngestionFile file);
    long countByIngestionFile(IngestionFile file);
}
