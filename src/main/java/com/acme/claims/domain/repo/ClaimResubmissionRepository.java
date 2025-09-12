// FILE: src/main/java/com/acme/claims/domain/repo/ClaimResubmissionRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.ClaimEvent;
import com.acme.claims.domain.model.entity.ClaimResubmission;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ClaimResubmissionRepository extends JpaRepository<ClaimResubmission, Long> {
    Optional<ClaimResubmission> findByClaimEvent(ClaimEvent event); // 1:1
    boolean existsByClaimEvent(ClaimEvent event);
}
