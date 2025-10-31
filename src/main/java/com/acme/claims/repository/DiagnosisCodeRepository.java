package com.acme.claims.repository;

import com.acme.claims.entity.DiagnosisCode;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * Spring Data JPA Repository for DiagnosisCode entity.
 * 
 * This repository provides data access methods for the claims_ref.diagnosis_code table
 * with comprehensive search and filtering capabilities.
 * 
 * Features:
 * - Standard CRUD operations via JpaRepository
 * - Search by code with exact match
 * - Search by description with partial matching
 * - Filter by status (ACTIVE/INACTIVE)
 * - Filter by code system (ICD-10, ICD-9, LOCAL)
 * - Pagination support for large datasets
 * - Existence checks for validation
 * - Custom queries for complex searches
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@Repository
public interface DiagnosisCodeRepository extends JpaRepository<DiagnosisCode, Long> {

    /**
     * Find diagnosis code by exact code and code system match.
     * 
     * @param code the diagnosis code to search for
     * @param codeSystem the code system to search for
     * @return Optional containing the diagnosis code if found
     */
    Optional<DiagnosisCode> findByCodeAndCodeSystem(String code, String codeSystem);

    /**
     * Find diagnosis code by exact code match (any code system).
     * 
     * @param code the diagnosis code to search for
     * @return List of diagnosis codes with the specified code
     */
    List<DiagnosisCode> findByCode(String code);

    /**
     * Find diagnosis code by exact code match with specific code system.
     * 
     * @param code the diagnosis code to search for
     * @param codeSystem the code system to filter by
     * @return Optional containing the diagnosis code if found
     */
    Optional<DiagnosisCode> findByCodeAndCodeSystemIgnoreCase(String code, String codeSystem);

    /**
     * Find all diagnosis codes by status.
     * 
     * @param status the status to filter by
     * @return List of diagnosis codes with the specified status
     */
    List<DiagnosisCode> findByStatus(String status);

    /**
     * Find all diagnosis codes by status with pagination.
     * 
     * @param status the status to filter by
     * @param pageable pagination information
     * @return Page of diagnosis codes matching the status
     */
    Page<DiagnosisCode> findByStatus(String status, Pageable pageable);

    /**
     * Find diagnosis codes by code system.
     * 
     * @param codeSystem the code system to search for
     * @return List of diagnosis codes with the specified code system
     */
    List<DiagnosisCode> findByCodeSystem(String codeSystem);

    /**
     * Find diagnosis codes by code system with pagination.
     * 
     * @param codeSystem the code system to search for
     * @param pageable pagination information
     * @return Page of diagnosis codes with the specified code system
     */
    Page<DiagnosisCode> findByCodeSystem(String codeSystem, Pageable pageable);

    /**
     * Find diagnosis codes by description containing the search term (case-insensitive).
     * 
     * @param description the description search term
     * @return List of diagnosis codes with descriptions containing the search term
     */
    List<DiagnosisCode> findByDescriptionContainingIgnoreCase(String description);

    /**
     * Find diagnosis codes by description containing the search term with pagination.
     * 
     * @param description the description search term
     * @param pageable pagination information
     * @return Page of diagnosis codes with descriptions containing the search term
     */
    Page<DiagnosisCode> findByDescriptionContainingIgnoreCase(String description, Pageable pageable);

    /**
     * Find diagnosis codes by code containing the search term (case-insensitive).
     * 
     * @param code the code search term
     * @return List of diagnosis codes with codes containing the search term
     */
    List<DiagnosisCode> findByCodeContainingIgnoreCase(String code);

    /**
     * Find diagnosis codes by code containing the search term with pagination.
     * 
     * @param code the code search term
     * @param pageable pagination information
     * @return Page of diagnosis codes with codes containing the search term
     */
    Page<DiagnosisCode> findByCodeContainingIgnoreCase(String code, Pageable pageable);

    /**
     * Find diagnosis codes by status and code system.
     * 
     * @param status the status to filter by
     * @param codeSystem the code system to filter by
     * @return List of diagnosis codes matching both criteria
     */
    List<DiagnosisCode> findByStatusAndCodeSystem(String status, String codeSystem);

    /**
     * Check if a diagnosis code exists with the given code and code system.
     * 
     * @param code the diagnosis code to check
     * @param codeSystem the code system to check
     * @return true if a diagnosis code with this combination exists
     */
    boolean existsByCodeAndCodeSystem(String code, String codeSystem);

    /**
     * Check if a diagnosis code exists with the given code (any code system).
     * 
     * @param code the diagnosis code to check
     * @return true if a diagnosis code with this code exists
     */
    boolean existsByCode(String code);

    /**
     * Count diagnosis codes by status.
     * 
     * @param status the status to count
     * @return number of diagnosis codes with the specified status
     */
    long countByStatus(String status);

    /**
     * Count diagnosis codes by code system.
     * 
     * @param codeSystem the code system to count
     * @return number of diagnosis codes with the specified code system
     */
    long countByCodeSystem(String codeSystem);

    /**
     * Custom search method that searches both code and description.
     * Uses PostgreSQL full-text search capabilities.
     * 
     * @param searchTerm the term to search for in both code and description
     * @param status the status to filter by (optional)
     * @param codeSystem the code system to filter by (optional)
     * @param pageable pagination information
     * @return Page of diagnosis codes matching the search criteria
     */
    @Query("""
        SELECT d FROM DiagnosisCode d 
        WHERE (:searchTerm IS NULL OR 
               LOWER(d.code) LIKE LOWER(FUNCTION('CONCAT', '%', CAST(:searchTerm AS string), '%')) OR 
               LOWER(d.description) LIKE LOWER(FUNCTION('CONCAT', '%', CAST(:searchTerm AS string), '%')))
        AND (:status IS NULL OR d.status = :status)
        AND (:codeSystem IS NULL OR d.codeSystem = :codeSystem)
        ORDER BY d.code ASC
        """)
    Page<DiagnosisCode> searchDiagnosisCodes(@Param("searchTerm") String searchTerm, 
                                           @Param("status") String status,
                                           @Param("codeSystem") String codeSystem,
                                           Pageable pageable);

    /**
     * Find all active diagnosis codes ordered by code.
     * 
     * @return List of active diagnosis codes sorted by code
     */
    @Query("SELECT d FROM DiagnosisCode d WHERE d.status = 'ACTIVE' ORDER BY d.code ASC")
    List<DiagnosisCode> findAllActiveOrderByCode();

    /**
     * Find diagnosis codes by multiple codes.
     * 
     * @param codes list of diagnosis codes to search for
     * @return List of diagnosis codes matching any of the provided codes
     */
    List<DiagnosisCode> findByCodeIn(List<String> codes);

    /**
     * Find diagnosis codes by multiple codes with specific status.
     * 
     * @param codes list of diagnosis codes to search for
     * @param status the status to filter by
     * @return List of diagnosis codes matching the codes and status
     */
    List<DiagnosisCode> findByCodeInAndStatus(List<String> codes, String status);

    /**
     * Find all unique code systems.
     * 
     * @return List of distinct code system values
     */
    @Query("SELECT DISTINCT d.codeSystem FROM DiagnosisCode d WHERE d.codeSystem IS NOT NULL ORDER BY d.codeSystem")
    List<String> findDistinctCodeSystems();
}

