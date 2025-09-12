// FILE: src/main/java/com/acme/claims/domain/repo/EncounterRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.Claim;
import com.acme.claims.domain.model.entity.Encounter;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface EncounterRepository extends JpaRepository<Encounter, Long> {
    Optional<Encounter> findByClaim(Claim claim); // 0..1 per claim (submission XSD)
    long countByClaim(Claim claim);
}
