package com.acme.claims.domain.repo;

import com.acme.claims.domain.model.entity.ClaimAttachment;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ClaimAttachmentRepository extends JpaRepository<ClaimAttachment, Long> {
}

