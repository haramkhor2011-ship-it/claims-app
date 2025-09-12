// FILE: src/main/java/com/acme/claims/domain/repo/EventObservationRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.ClaimEventActivity;
import com.acme.claims.domain.model.entity.EventObservation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface EventObservationRepository extends JpaRepository<EventObservation, Long> {
    List<EventObservation> findByClaimEventActivity(ClaimEventActivity cea);
}
