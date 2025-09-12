// FILE: src/main/java/com/acme/claims/domain/repo/RemittanceActivityRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.RemittanceActivity;
import com.acme.claims.domain.model.entity.RemittanceClaim;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface RemittanceActivityRepository extends JpaRepository<RemittanceActivity, Long> {
    List<RemittanceActivity> findByRemittanceClaim(RemittanceClaim remittanceClaim);
    Optional<RemittanceActivity> findByRemittanceClaimAndActivityId(RemittanceClaim remittanceClaim, String activityId); // uq_remittance_activity
    boolean existsByRemittanceClaimAndActivityId(RemittanceClaim remittanceClaim, String activityId);
    long countByRemittanceClaim(RemittanceClaim remittanceClaim);
}
