// FILE: src/main/java/com/acme/claims/domain/repo/DiagnosisRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.Claim;
import com.acme.claims.domain.model.entity.Diagnosis;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DiagnosisRepository extends JpaRepository<Diagnosis, Long> {
    List<Diagnosis> findByClaim(Claim claim);
}
