// FILE: src/main/java/com/acme/claims/domain/repo/ClaimStatusTimelineRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.enums.ClaimStatus;
import com.acme.claims.domain.model.entity.ClaimKey;
import com.acme.claims.domain.model.entity.ClaimStatusTimeline;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;

@Repository
public interface ClaimStatusTimelineRepository extends JpaRepository<ClaimStatusTimeline, Long> {
    List<ClaimStatusTimeline> findByClaimKeyAndStatusOrderByStatusTimeAsc(ClaimKey key, ClaimStatus status);
    List<ClaimStatusTimeline> findByStatusTimeBetween(OffsetDateTime from, OffsetDateTime to);
}
