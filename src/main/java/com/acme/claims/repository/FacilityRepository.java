package com.acme.claims.repository;

import com.acme.claims.entity.Facility;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * Spring Data JPA Repository for Facility entity.
 * 
 * This repository provides data access methods for the claims_ref.facility table
 * with comprehensive search and filtering capabilities.
 * 
 * Features:
 * - Standard CRUD operations via JpaRepository
 * - Search by facility code with exact match
 * - Search by name with partial matching
 * - Filter by status (ACTIVE/INACTIVE)
 * - Pagination support for large datasets
 * - Existence checks for validation
 * - Custom queries for complex searches
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@Repository
public interface FacilityRepository extends JpaRepository<Facility, Long> {

    /**
     * Find facility by exact facility code match.
     * 
     * @param facilityCode the facility code to search for
     * @return Optional containing the facility if found
     */
    Optional<Facility> findByFacilityCode(String facilityCode);

    /**
     * Find facility by exact facility code match, ignoring case.
     * 
     * @param facilityCode the facility code to search for (case-insensitive)
     * @return Optional containing the facility if found
     */
    Optional<Facility> findByFacilityCodeIgnoreCase(String facilityCode);

    /**
     * Find all active facilities.
     * 
     * @return List of active facilities
     */
    List<Facility> findByStatus(String status);

    /**
     * Find all active facilities with pagination.
     * 
     * @param status the status to filter by
     * @param pageable pagination information
     * @return Page of facilities matching the status
     */
    Page<Facility> findByStatus(String status, Pageable pageable);

    /**
     * Find facilities by name containing the search term (case-insensitive).
     * 
     * @param name the name search term
     * @return List of facilities with names containing the search term
     */
    List<Facility> findByNameContainingIgnoreCase(String name);

    /**
     * Find facilities by name containing the search term with pagination.
     * 
     * @param name the name search term
     * @param pageable pagination information
     * @return Page of facilities with names containing the search term
     */
    Page<Facility> findByNameContainingIgnoreCase(String name, Pageable pageable);

    /**
     * Find facilities by facility code containing the search term (case-insensitive).
     * 
     * @param facilityCode the facility code search term
     * @return List of facilities with codes containing the search term
     */
    List<Facility> findByFacilityCodeContainingIgnoreCase(String facilityCode);

    /**
     * Find facilities by facility code containing the search term with pagination.
     * 
     * @param facilityCode the facility code search term
     * @param pageable pagination information
     * @return Page of facilities with codes containing the search term
     */
    Page<Facility> findByFacilityCodeContainingIgnoreCase(String facilityCode, Pageable pageable);

    /**
     * Find facilities by city.
     * 
     * @param city the city to search for
     * @return List of facilities in the specified city
     */
    List<Facility> findByCity(String city);

    /**
     * Find facilities by country.
     * 
     * @param country the country to search for
     * @return List of facilities in the specified country
     */
    List<Facility> findByCountry(String country);

    /**
     * Check if a facility exists with the given facility code.
     * 
     * @param facilityCode the facility code to check
     * @return true if a facility with this code exists
     */
    boolean existsByFacilityCode(String facilityCode);

    /**
     * Check if a facility exists with the given facility code, ignoring case.
     * 
     * @param facilityCode the facility code to check (case-insensitive)
     * @return true if a facility with this code exists
     */
    boolean existsByFacilityCodeIgnoreCase(String facilityCode);

    /**
     * Count facilities by status.
     * 
     * @param status the status to count
     * @return number of facilities with the specified status
     */
    long countByStatus(String status);

    /**
     * Custom search method that searches both facility code and name.
     * Uses PostgreSQL full-text search capabilities.
     * 
     * @param searchTerm the term to search for in both code and name
     * @param status the status to filter by (optional)
     * @param pageable pagination information
     * @return Page of facilities matching the search criteria
     */
    @Query("""
        SELECT f FROM Facility f 
        WHERE (:searchTerm IS NULL OR 
               LOWER(f.facilityCode) LIKE LOWER(FUNCTION('CONCAT', '%', CAST(:searchTerm AS string), '%')) OR 
               LOWER(f.name) LIKE LOWER(FUNCTION('CONCAT', '%', CAST(:searchTerm AS string), '%')))
        AND (:status IS NULL OR f.status = :status)
        ORDER BY f.facilityCode ASC
        """)
    Page<Facility> searchFacilities(@Param("searchTerm") String searchTerm, 
                                   @Param("status") String status, 
                                   Pageable pageable);

    /**
     * Find all active facilities ordered by facility code.
     * 
     * @return List of active facilities sorted by code
     */
    @Query("SELECT f FROM Facility f WHERE f.status = 'ACTIVE' ORDER BY f.facilityCode ASC")
    List<Facility> findAllActiveOrderByCode();

    /**
     * Find facilities by multiple facility codes.
     * 
     * @param facilityCodes list of facility codes to search for
     * @return List of facilities matching any of the provided codes
     */
    List<Facility> findByFacilityCodeIn(List<String> facilityCodes);

    /**
     * Find facilities by multiple facility codes with specific status.
     * 
     * @param facilityCodes list of facility codes to search for
     * @param status the status to filter by
     * @return List of facilities matching the codes and status
     */
    List<Facility> findByFacilityCodeInAndStatus(List<String> facilityCodes, String status);
}

