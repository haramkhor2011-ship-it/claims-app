// FILE: src/main/java/com/acme/claims/domain/repo/ClaimEventActivityRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.ClaimEvent;
import com.acme.claims.domain.model.entity.ClaimEventActivity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ClaimEventActivityRepository extends JpaRepository<ClaimEventActivity, Long> {
    List<ClaimEventActivity> findByClaimEvent(ClaimEvent event);
    Optional<ClaimEventActivity> findByClaimEventAndActivityIdAtEvent(ClaimEvent event, String activityIdAtEvent); // uq_cea_event_activity
    boolean existsByClaimEventAndActivityIdAtEvent(ClaimEvent event, String activityIdAtEvent);
}
