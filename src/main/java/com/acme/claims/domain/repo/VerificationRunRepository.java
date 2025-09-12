// FILE: src/main/java/com/acme/claims/monitoring/repo/VerificationRunRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.IngestionFile;
import com.acme.claims.domain.model.entity.VerificationRun;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface VerificationRunRepository extends JpaRepository<VerificationRun, Long> {
    List<VerificationRun> findByIngestionFileOrderByStartedAtDesc(IngestionFile file);
}
