// FILE: src/main/java/com/acme/claims/domain/repo/SubmissionRepository.java
// Version: v2.0.0
package com.acme.claims.domain.repo;


import com.acme.claims.domain.model.entity.IngestionFile;
import com.acme.claims.domain.model.entity.Submission;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SubmissionRepository extends JpaRepository<Submission, Long> {
    List<Submission> findByIngestionFile(IngestionFile file);
}
