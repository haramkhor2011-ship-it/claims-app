package com.acme.claims.repository;

import com.acme.claims.entity.DenialCode;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * Spring Data JPA Repository for DenialCode entity.
 * 
 * This repository provides data access methods for the claims_ref.denial_code table
 * with comprehensive search and filtering capabilities.
 * 
 * Features:
 * - Standard CRUD operations via JpaRepository
 * - Search by code with exact match
 * - Search by description with partial matching
 * - Pagination support for large datasets
 * - Existence checks for validation
 * - Custom queries for complex searches
 * 
 * Note: Denial codes typically don't have soft delete functionality
 * as they are reference data that should remain available for historical claims.
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@Repository
public interface DenialCodeRepository extends JpaRepository<DenialCode, Long> {

    /**
     * Find denial code by exact code match.
     * 
     * @param code the denial code to search for
     * @return Optional containing the denial code if found
     */
    Optional<DenialCode> findByCode(String code);

    /**
     * Find denial code by exact code match, ignoring case.
     * 
     * @param code the denial code to search for (case-insensitive)
     * @return Optional containing the denial code if found
     */
    Optional<DenialCode> findByCodeIgnoreCase(String code);

    /**
     * Find denial codes by description containing the search term (case-insensitive).
     * 
     * @param description the description search term
     * @return List of denial codes with descriptions containing the search term
     */
    List<DenialCode> findByDescriptionContainingIgnoreCase(String description);

    /**
     * Find denial codes by description containing the search term with pagination.
     * 
     * @param description the description search term
     * @param pageable pagination information
     * @return Page of denial codes with descriptions containing the search term
     */
    Page<DenialCode> findByDescriptionContainingIgnoreCase(String description, Pageable pageable);

    /**
     * Find denial codes by code containing the search term (case-insensitive).
     * 
     * @param code the code search term
     * @return List of denial codes with codes containing the search term
     */
    List<DenialCode> findByCodeContainingIgnoreCase(String code);

    /**
     * Find denial codes by code containing the search term with pagination.
     * 
     * @param code the code search term
     * @param pageable pagination information
     * @return Page of denial codes with codes containing the search term
     */
    Page<DenialCode> findByCodeContainingIgnoreCase(String code, Pageable pageable);

    /**
     * Check if a denial code exists with the given code.
     * 
     * @param code the denial code to check
     * @return true if a denial code with this code exists
     */
    boolean existsByCode(String code);

    /**
     * Check if a denial code exists with the given code, ignoring case.
     * 
     * @param code the denial code to check (case-insensitive)
     * @return true if a denial code with this code exists
     */
    boolean existsByCodeIgnoreCase(String code);

    /**
     * Custom search method that searches both code and description.
     * Uses PostgreSQL full-text search capabilities.
     * 
     * @param searchTerm the term to search for in both code and description
     * @param pageable pagination information
     * @return Page of denial codes matching the search criteria
     */
    @Query("""
        SELECT d FROM DenialCode d 
        WHERE (:searchTerm IS NULL OR 
               LOWER(d.code) LIKE LOWER(FUNCTION('CONCAT', '%', CAST(:searchTerm AS string), '%')) OR 
               LOWER(d.description) LIKE LOWER(FUNCTION('CONCAT', '%', CAST(:searchTerm AS string), '%')))
        ORDER BY d.code ASC
        """)
    Page<DenialCode> searchDenialCodes(@Param("searchTerm") String searchTerm, 
                                     Pageable pageable);

    /**
     * Find all denial codes ordered by code.
     * 
     * @return List of all denial codes sorted by code
     */
    @Query("SELECT d FROM DenialCode d ORDER BY d.code ASC")
    List<DenialCode> findAllOrderByCode();

    /**
     * Find denial codes by multiple codes.
     * 
     * @param codes list of denial codes to search for
     * @return List of denial codes matching any of the provided codes
     */
    List<DenialCode> findByCodeIn(List<String> codes);

}

