// FILE: src/main/java/com/acme/claims/monitoring/repo/VerificationRuleRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.VerificationRule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface VerificationRuleRepository extends JpaRepository<VerificationRule, Long> {
    Optional<VerificationRule> findByCode(String code);
    List<VerificationRule> findByActiveTrueOrderBySeverityDesc();
}
