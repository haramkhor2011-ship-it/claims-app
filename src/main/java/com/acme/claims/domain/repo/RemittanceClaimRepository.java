// FILE: src/main/java/com/acme/claims/domain/repo/RemittanceClaimRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.ClaimKey;
import com.acme.claims.domain.model.entity.Remittance;
import com.acme.claims.domain.model.entity.RemittanceClaim;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface RemittanceClaimRepository extends JpaRepository<RemittanceClaim, Long> {
    Optional<RemittanceClaim> findByRemittanceAndClaimKey(Remittance remittance, ClaimKey claimKey); // uq_remittance_claim
    boolean existsByRemittanceAndClaimKey(Remittance remittance, ClaimKey claimKey);
    long countByRemittance(Remittance remittance);
}
