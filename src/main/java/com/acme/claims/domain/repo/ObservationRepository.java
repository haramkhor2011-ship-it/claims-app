// FILE: src/main/java/com/acme/claims/domain/repo/ObservationRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.Activity;
import com.acme.claims.domain.model.entity.Observation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ObservationRepository extends JpaRepository<Observation, Long> {
    List<Observation> findByActivity(Activity activity);
    long countByActivity(Activity activity);
}
