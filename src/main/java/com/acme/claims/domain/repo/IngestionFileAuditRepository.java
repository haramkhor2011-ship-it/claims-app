// FILE: src/main/java/com/acme/claims/monitoring/repo/IngestionFileAuditRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.IngestionFile;
import com.acme.claims.domain.model.entity.IngestionFileAudit;
import com.acme.claims.domain.model.entity.IngestionRun;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface IngestionFileAuditRepository extends JpaRepository<IngestionFileAudit, Long> {
    List<IngestionFileAudit> findByIngestionRunOrderByCreatedAtDesc(IngestionRun run);
    List<IngestionFileAudit> findByIngestionFile(IngestionFile file);
}
