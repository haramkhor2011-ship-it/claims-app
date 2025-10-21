package com.acme.claims.repository;

import com.acme.claims.entity.Payer;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * Spring Data JPA Repository for Payer entity.
 * 
 * This repository provides data access methods for the claims_ref.payer table
 * with comprehensive search and filtering capabilities.
 * 
 * Features:
 * - Standard CRUD operations via JpaRepository
 * - Search by payer code with exact match
 * - Search by name with partial matching
 * - Filter by status (ACTIVE/INACTIVE)
 * - Filter by classification (GOVERNMENT, PRIVATE, etc.)
 * - Pagination support for large datasets
 * - Existence checks for validation
 * - Custom queries for complex searches
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@Repository
public interface PayerRepository extends JpaRepository<Payer, Long> {

    /**
     * Find payer by exact payer code match.
     * 
     * @param payerCode the payer code to search for
     * @return Optional containing the payer if found
     */
    Optional<Payer> findByPayerCode(String payerCode);

    /**
     * Find payer by exact payer code match, ignoring case.
     * 
     * @param payerCode the payer code to search for (case-insensitive)
     * @return Optional containing the payer if found
     */
    Optional<Payer> findByPayerCodeIgnoreCase(String payerCode);

    /**
     * Find all payers by status.
     * 
     * @param status the status to filter by
     * @return List of payers with the specified status
     */
    List<Payer> findByStatus(String status);

    /**
     * Find all payers by status with pagination.
     * 
     * @param status the status to filter by
     * @param pageable pagination information
     * @return Page of payers matching the status
     */
    Page<Payer> findByStatus(String status, Pageable pageable);

    /**
     * Find payers by name containing the search term (case-insensitive).
     * 
     * @param name the name search term
     * @return List of payers with names containing the search term
     */
    List<Payer> findByNameContainingIgnoreCase(String name);

    /**
     * Find payers by name containing the search term with pagination.
     * 
     * @param name the name search term
     * @param pageable pagination information
     * @return Page of payers with names containing the search term
     */
    Page<Payer> findByNameContainingIgnoreCase(String name, Pageable pageable);

    /**
     * Find payers by payer code containing the search term (case-insensitive).
     * 
     * @param payerCode the payer code search term
     * @return List of payers with codes containing the search term
     */
    List<Payer> findByPayerCodeContainingIgnoreCase(String payerCode);

    /**
     * Find payers by payer code containing the search term with pagination.
     * 
     * @param payerCode the payer code search term
     * @param pageable pagination information
     * @return Page of payers with codes containing the search term
     */
    Page<Payer> findByPayerCodeContainingIgnoreCase(String payerCode, Pageable pageable);

    /**
     * Find payers by classification.
     * 
     * @param classification the classification to search for
     * @return List of payers with the specified classification
     */
    List<Payer> findByClassification(String classification);

    /**
     * Find payers by classification with pagination.
     * 
     * @param classification the classification to search for
     * @param pageable pagination information
     * @return Page of payers with the specified classification
     */
    Page<Payer> findByClassification(String classification, Pageable pageable);

    /**
     * Find payers by status and classification.
     * 
     * @param status the status to filter by
     * @param classification the classification to filter by
     * @return List of payers matching both criteria
     */
    List<Payer> findByStatusAndClassification(String status, String classification);

    /**
     * Check if a payer exists with the given payer code.
     * 
     * @param payerCode the payer code to check
     * @return true if a payer with this code exists
     */
    boolean existsByPayerCode(String payerCode);

    /**
     * Check if a payer exists with the given payer code, ignoring case.
     * 
     * @param payerCode the payer code to check (case-insensitive)
     * @return true if a payer with this code exists
     */
    boolean existsByPayerCodeIgnoreCase(String payerCode);

    /**
     * Count payers by status.
     * 
     * @param status the status to count
     * @return number of payers with the specified status
     */
    long countByStatus(String status);

    /**
     * Count payers by classification.
     * 
     * @param classification the classification to count
     * @return number of payers with the specified classification
     */
    long countByClassification(String classification);

    /**
     * Custom search method that searches both payer code and name.
     * Uses PostgreSQL full-text search capabilities.
     * 
     * @param searchTerm the term to search for in both code and name
     * @param status the status to filter by (optional)
     * @param classification the classification to filter by (optional)
     * @param pageable pagination information
     * @return Page of payers matching the search criteria
     */
    @Query("""
        SELECT p FROM Payer p 
        WHERE (:searchTerm IS NULL OR 
               LOWER(p.payerCode) LIKE LOWER(CONCAT('%', :searchTerm, '%')) OR 
               LOWER(p.name) LIKE LOWER(CONCAT('%', :searchTerm, '%')))
        AND (:status IS NULL OR p.status = :status)
        AND (:classification IS NULL OR p.classification = :classification)
        ORDER BY p.payerCode ASC
        """)
    Page<Payer> searchPayers(@Param("searchTerm") String searchTerm, 
                            @Param("status") String status,
                            @Param("classification") String classification,
                            Pageable pageable);

    /**
     * Find all active payers ordered by payer code.
     * 
     * @return List of active payers sorted by code
     */
    @Query("SELECT p FROM Payer p WHERE p.status = 'ACTIVE' ORDER BY p.payerCode ASC")
    List<Payer> findAllActiveOrderByCode();

    /**
     * Find payers by multiple payer codes.
     * 
     * @param payerCodes list of payer codes to search for
     * @return List of payers matching any of the provided codes
     */
    List<Payer> findByPayerCodeIn(List<String> payerCodes);

    /**
     * Find payers by multiple payer codes with specific status.
     * 
     * @param payerCodes list of payer codes to search for
     * @param status the status to filter by
     * @return List of payers matching the codes and status
     */
    List<Payer> findByPayerCodeInAndStatus(List<String> payerCodes, String status);

    /**
     * Find all unique classifications.
     * 
     * @return List of distinct classification values
     */
    @Query("SELECT DISTINCT p.classification FROM Payer p WHERE p.classification IS NOT NULL ORDER BY p.classification")
    List<String> findDistinctClassifications();
}

