// FILE: src/main/java/com/acme/claims/domain/repo/RemittanceRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.IngestionFile;
import com.acme.claims.domain.model.entity.Remittance;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface RemittanceRepository extends JpaRepository<Remittance, Long> {
    List<Remittance> findByIngestionFile(IngestionFile file);
}
