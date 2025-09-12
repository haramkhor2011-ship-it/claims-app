// FILE: src/main/java/com/acme/claims/domain/repo/ClaimEventRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.enums.ClaimEventType;
import com.acme.claims.domain.model.entity.*;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface ClaimEventRepository extends JpaRepository<ClaimEvent, Long> {
    List<ClaimEvent> findByClaimKeyOrderByEventTimeAsc(ClaimKey claimKey);
    Optional<ClaimEvent> findByClaimKeyAndType(ClaimKey claimKey, ClaimEventType type); // unique for SUBMISSION
    List<ClaimEvent> findByTypeAndEventTimeBetween(ClaimEventType type, OffsetDateTime from, OffsetDateTime to);
    List<ClaimEvent> findByIngestionFile(IngestionFile ingestionFile);
    long countBySubmission(Submission submission);
    long countByRemittance(Remittance remittance);
}
