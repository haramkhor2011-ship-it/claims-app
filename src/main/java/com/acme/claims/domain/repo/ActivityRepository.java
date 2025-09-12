// FILE: src/main/java/com/acme/claims/domain/repo/ActivityRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.Activity;
import com.acme.claims.domain.model.entity.Claim;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ActivityRepository extends JpaRepository<Activity, Long> {
    List<Activity> findByClaim(Claim claim);
    Optional<Activity> findByClaimAndActivityId(Claim claim, String activityId); // uq_activity_bk
    boolean existsByClaimAndActivityId(Claim claim, String activityId);
    long countByClaim(Claim claim);
}
