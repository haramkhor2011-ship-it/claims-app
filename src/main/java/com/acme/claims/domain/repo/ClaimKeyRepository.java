// FILE: src/main/java/com/acme/claims/domain/repo/ClaimKeyRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;

import com.acme.claims.domain.model.entity.ClaimKey;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ClaimKeyRepository extends JpaRepository<ClaimKey, Long> {
    Optional<ClaimKey> findByClaimId(String claimId);
    boolean existsByClaimId(String claimId);
}
