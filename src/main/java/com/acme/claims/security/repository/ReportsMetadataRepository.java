package com.acme.claims.security.repository;

import com.acme.claims.security.entity.ReportsMetadata;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * Repository for ReportsMetadata entity
 */
@Repository
public interface ReportsMetadataRepository extends JpaRepository<ReportsMetadata, Long> {
    
    /**
     * Find report metadata by report code
     */
    Optional<ReportsMetadata> findByReportCode(String reportCode);
    
    /**
     * Find all active reports
     */
    List<ReportsMetadata> findByStatus(String status);
    
    /**
     * Find all active reports
     */
    @Query("SELECT rm FROM ReportsMetadata rm WHERE rm.status = 'A' ORDER BY rm.reportName")
    List<ReportsMetadata> findAllActiveReports();
    
    /**
     * Find reports by category
     */
    List<ReportsMetadata> findByCategory(String category);
    
    /**
     * Find active reports by category
     */
    @Query("SELECT rm FROM ReportsMetadata rm WHERE rm.category = :category AND rm.status = 'A' ORDER BY rm.reportName")
    List<ReportsMetadata> findActiveReportsByCategory(@Param("category") String category);
    
    /**
     * Check if report code exists
     */
    boolean existsByReportCode(String reportCode);
    
    /**
     * Check if report code exists and is active
     */
    @Query("SELECT COUNT(rm) > 0 FROM ReportsMetadata rm WHERE rm.reportCode = :reportCode AND rm.status = 'A'")
    boolean existsByReportCodeAndActive(@Param("reportCode") String reportCode);
}
