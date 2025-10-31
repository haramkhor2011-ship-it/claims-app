package com.acme.claims.repository;

import com.acme.claims.entity.Clinician;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * Spring Data JPA Repository for Clinician entity.
 * 
 * This repository provides data access methods for the claims_ref.clinician table
 * with comprehensive search and filtering capabilities.
 * 
 * Features:
 * - Standard CRUD operations via JpaRepository
 * - Search by clinician code with exact match
 * - Search by name with partial matching
 * - Filter by status (ACTIVE/INACTIVE)
 * - Filter by specialty (CARDIOLOGY, DERMATOLOGY, etc.)
 * - Pagination support for large datasets
 * - Existence checks for validation
 * - Custom queries for complex searches
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@Repository
public interface ClinicianRepository extends JpaRepository<Clinician, Long> {

    /**
     * Find clinician by exact clinician code match.
     * 
     * @param clinicianCode the clinician code to search for
     * @return Optional containing the clinician if found
     */
    Optional<Clinician> findByClinicianCode(String clinicianCode);

    /**
     * Find clinician by exact clinician code match, ignoring case.
     * 
     * @param clinicianCode the clinician code to search for (case-insensitive)
     * @return Optional containing the clinician if found
     */
    Optional<Clinician> findByClinicianCodeIgnoreCase(String clinicianCode);

    /**
     * Find all clinicians by status.
     * 
     * @param status the status to filter by
     * @return List of clinicians with the specified status
     */
    List<Clinician> findByStatus(String status);

    /**
     * Find all clinicians by status with pagination.
     * 
     * @param status the status to filter by
     * @param pageable pagination information
     * @return Page of clinicians matching the status
     */
    Page<Clinician> findByStatus(String status, Pageable pageable);

    /**
     * Find clinicians by name containing the search term (case-insensitive).
     * 
     * @param name the name search term
     * @return List of clinicians with names containing the search term
     */
    List<Clinician> findByNameContainingIgnoreCase(String name);

    /**
     * Find clinicians by name containing the search term with pagination.
     * 
     * @param name the name search term
     * @param pageable pagination information
     * @return Page of clinicians with names containing the search term
     */
    Page<Clinician> findByNameContainingIgnoreCase(String name, Pageable pageable);

    /**
     * Find clinicians by clinician code containing the search term (case-insensitive).
     * 
     * @param clinicianCode the clinician code search term
     * @return List of clinicians with codes containing the search term
     */
    List<Clinician> findByClinicianCodeContainingIgnoreCase(String clinicianCode);

    /**
     * Find clinicians by clinician code containing the search term with pagination.
     * 
     * @param clinicianCode the clinician code search term
     * @param pageable pagination information
     * @return Page of clinicians with codes containing the search term
     */
    Page<Clinician> findByClinicianCodeContainingIgnoreCase(String clinicianCode, Pageable pageable);

    /**
     * Find clinicians by specialty.
     * 
     * @param specialty the specialty to search for
     * @return List of clinicians with the specified specialty
     */
    List<Clinician> findBySpecialty(String specialty);

    /**
     * Find clinicians by specialty with pagination.
     * 
     * @param specialty the specialty to search for
     * @param pageable pagination information
     * @return Page of clinicians with the specified specialty
     */
    Page<Clinician> findBySpecialty(String specialty, Pageable pageable);

    /**
     * Find clinicians by status and specialty.
     * 
     * @param status the status to filter by
     * @param specialty the specialty to filter by
     * @return List of clinicians matching both criteria
     */
    List<Clinician> findByStatusAndSpecialty(String status, String specialty);

    /**
     * Check if a clinician exists with the given clinician code.
     * 
     * @param clinicianCode the clinician code to check
     * @return true if a clinician with this code exists
     */
    boolean existsByClinicianCode(String clinicianCode);

    /**
     * Check if a clinician exists with the given clinician code, ignoring case.
     * 
     * @param clinicianCode the clinician code to check (case-insensitive)
     * @return true if a clinician with this code exists
     */
    boolean existsByClinicianCodeIgnoreCase(String clinicianCode);

    /**
     * Count clinicians by status.
     * 
     * @param status the status to count
     * @return number of clinicians with the specified status
     */
    long countByStatus(String status);

    /**
     * Count clinicians by specialty.
     * 
     * @param specialty the specialty to count
     * @return number of clinicians with the specified specialty
     */
    long countBySpecialty(String specialty);

    /**
     * Custom search method that searches both clinician code and name.
     * Uses PostgreSQL full-text search capabilities.
     * 
     * @param searchTerm the term to search for in both code and name
     * @param status the status to filter by (optional)
     * @param specialty the specialty to filter by (optional)
     * @param pageable pagination information
     * @return Page of clinicians matching the search criteria
     */
    @Query("""
        SELECT c FROM Clinician c 
        WHERE (:searchTerm IS NULL OR 
               LOWER(c.clinicianCode) LIKE LOWER(FUNCTION('CONCAT', '%', CAST(:searchTerm AS string), '%')) OR 
               LOWER(c.name) LIKE LOWER(FUNCTION('CONCAT', '%', CAST(:searchTerm AS string), '%')))
        AND (:status IS NULL OR c.status = :status)
        AND (:specialty IS NULL OR c.specialty = :specialty)
        ORDER BY c.clinicianCode ASC
        """)
    Page<Clinician> searchClinicians(@Param("searchTerm") String searchTerm, 
                                   @Param("status") String status,
                                   @Param("specialty") String specialty,
                                   Pageable pageable);

    /**
     * Find all active clinicians ordered by clinician code.
     * 
     * @return List of active clinicians sorted by code
     */
    @Query("SELECT c FROM Clinician c WHERE c.status = 'ACTIVE' ORDER BY c.clinicianCode ASC")
    List<Clinician> findAllActiveOrderByCode();

    /**
     * Find clinicians by multiple clinician codes.
     * 
     * @param clinicianCodes list of clinician codes to search for
     * @return List of clinicians matching any of the provided codes
     */
    List<Clinician> findByClinicianCodeIn(List<String> clinicianCodes);

    /**
     * Find clinicians by multiple clinician codes with specific status.
     * 
     * @param clinicianCodes list of clinician codes to search for
     * @param status the status to filter by
     * @return List of clinicians matching the codes and status
     */
    List<Clinician> findByClinicianCodeInAndStatus(List<String> clinicianCodes, String status);

    /**
     * Find all unique specialties.
     * 
     * @return List of distinct specialty values
     */
    @Query("SELECT DISTINCT c.specialty FROM Clinician c WHERE c.specialty IS NOT NULL ORDER BY c.specialty")
    List<String> findDistinctSpecialties();
}

