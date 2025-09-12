// FILE: src/main/java/com/acme/claims/domain/repo/ClaimContractRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.Claim;
import com.acme.claims.domain.model.entity.ClaimContract;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ClaimContractRepository extends JpaRepository<ClaimContract, Long> {
    Optional<ClaimContract> findByClaim(Claim claim);
}
