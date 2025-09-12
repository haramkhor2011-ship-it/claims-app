// FILE: src/main/java/com/acme/claims/domain/repo/IngestionFileRepository.java
// Version: v2.0.0 (SSOT-aligned)
// Purpose: SSOT raw XML + XSD header lookups; idempotency by fileId
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.IngestionFile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface IngestionFileRepository extends JpaRepository<IngestionFile, Long> {
    Optional<IngestionFile> findByFileId(String fileId);
    boolean existsByFileId(String fileId);
    List<IngestionFile> findAllByRootTypeOrderByTransactionDateDesc(short rootType);
    List<IngestionFile> findAllByTransactionDateBetween(OffsetDateTime from, OffsetDateTime to);
}
