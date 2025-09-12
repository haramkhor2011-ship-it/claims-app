// FILE: src/main/java/com/acme/claims/domain/repo/ClaimRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;

import com.acme.claims.domain.model.entity.Claim;
import com.acme.claims.domain.model.entity.ClaimKey;
import com.acme.claims.domain.model.entity.Submission;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ClaimRepository extends JpaRepository<Claim, Long> {
    Optional<Claim> findByClaimKey(ClaimKey claimKey);
    boolean existsByClaimKey(ClaimKey claimKey); // one submission per claim_key
    long countBySubmission(Submission submission);
}
