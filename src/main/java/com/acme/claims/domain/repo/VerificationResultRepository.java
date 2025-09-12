// FILE: src/main/java/com/acme/claims/monitoring/repo/VerificationResultRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.VerificationResult;
import com.acme.claims.domain.model.entity.VerificationRule;
import com.acme.claims.domain.model.entity.VerificationRun;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface VerificationResultRepository extends JpaRepository<VerificationResult, Long> {
    List<VerificationResult> findByVerificationRun(VerificationRun run);
    Optional<VerificationResult> findByVerificationRunAndRule(VerificationRun run, VerificationRule rule);
}
