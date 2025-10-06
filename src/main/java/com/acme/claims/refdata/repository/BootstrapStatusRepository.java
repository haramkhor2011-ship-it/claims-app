package com.acme.claims.refdata.repository;

import com.acme.claims.refdata.entity.BootstrapStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface BootstrapStatusRepository extends JpaRepository<BootstrapStatus, Long> {

    /**
     * Find bootstrap status by name
     */
    Optional<BootstrapStatus> findByBootstrapName(String bootstrapName);

    /**
     * Check if bootstrap with given name has been completed
     */
    @Query("SELECT COUNT(b) > 0 FROM BootstrapStatus b WHERE b.bootstrapName = :bootstrapName")
    boolean isBootstrapCompleted(@Param("bootstrapName") String bootstrapName);

    /**
     * Delete bootstrap status by name (for reset functionality)
     */
    void deleteByBootstrapName(String bootstrapName);
}
