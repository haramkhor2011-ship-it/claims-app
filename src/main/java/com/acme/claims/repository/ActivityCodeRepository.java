package com.acme.claims.repository;

import com.acme.claims.entity.ActivityCode;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * Spring Data JPA Repository for ActivityCode entity.
 * 
 * This repository provides data access methods for the claims_ref.activity_code table
 * with comprehensive search and filtering capabilities.
 * 
 * Features:
 * - Standard CRUD operations via JpaRepository
 * - Search by code with exact match
 * - Search by description with partial matching
 * - Filter by status (ACTIVE/INACTIVE)
 * - Filter by type (CPT, HCPCS, LOCAL, etc.)
 * - Filter by code system (CPT, HCPCS, LOCAL)
 * - Pagination support for large datasets
 * - Existence checks for validation
 * - Custom queries for complex searches
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@Repository
public interface ActivityCodeRepository extends JpaRepository<ActivityCode, Long> {

    /**
     * Find activity code by exact code and type match.
     * 
     * @param code the activity code to search for
     * @param type the type to search for
     * @return Optional containing the activity code if found
     */
    Optional<ActivityCode> findByCodeAndType(String code, String type);

    /**
     * Find activity code by exact code match (any type).
     * 
     * @param code the activity code to search for
     * @return List of activity codes with the specified code
     */
    List<ActivityCode> findByCode(String code);

    /**
     * Find activity code by exact code match with specific type.
     * 
     * @param code the activity code to search for
     * @param type the type to filter by
     * @return Optional containing the activity code if found
     */
    Optional<ActivityCode> findByCodeAndTypeIgnoreCase(String code, String type);

    /**
     * Find all activity codes by status.
     * 
     * @param status the status to filter by
     * @return List of activity codes with the specified status
     */
    List<ActivityCode> findByStatus(String status);

    /**
     * Find all activity codes by status with pagination.
     * 
     * @param status the status to filter by
     * @param pageable pagination information
     * @return Page of activity codes matching the status
     */
    Page<ActivityCode> findByStatus(String status, Pageable pageable);

    /**
     * Find activity codes by type.
     * 
     * @param type the type to search for
     * @return List of activity codes with the specified type
     */
    List<ActivityCode> findByType(String type);

    /**
     * Find activity codes by type with pagination.
     * 
     * @param type the type to search for
     * @param pageable pagination information
     * @return Page of activity codes with the specified type
     */
    Page<ActivityCode> findByType(String type, Pageable pageable);

    /**
     * Find activity codes by code system.
     * 
     * @param codeSystem the code system to search for
     * @return List of activity codes with the specified code system
     */
    List<ActivityCode> findByCodeSystem(String codeSystem);

    /**
     * Find activity codes by code system with pagination.
     * 
     * @param codeSystem the code system to search for
     * @param pageable pagination information
     * @return Page of activity codes with the specified code system
     */
    Page<ActivityCode> findByCodeSystem(String codeSystem, Pageable pageable);

    /**
     * Find activity codes by description containing the search term (case-insensitive).
     * 
     * @param description the description search term
     * @return List of activity codes with descriptions containing the search term
     */
    List<ActivityCode> findByDescriptionContainingIgnoreCase(String description);

    /**
     * Find activity codes by description containing the search term with pagination.
     * 
     * @param description the description search term
     * @param pageable pagination information
     * @return Page of activity codes with descriptions containing the search term
     */
    Page<ActivityCode> findByDescriptionContainingIgnoreCase(String description, Pageable pageable);

    /**
     * Find activity codes by code containing the search term (case-insensitive).
     * 
     * @param code the code search term
     * @return List of activity codes with codes containing the search term
     */
    List<ActivityCode> findByCodeContainingIgnoreCase(String code);

    /**
     * Find activity codes by code containing the search term with pagination.
     * 
     * @param code the code search term
     * @param pageable pagination information
     * @return Page of activity codes with codes containing the search term
     */
    Page<ActivityCode> findByCodeContainingIgnoreCase(String code, Pageable pageable);

    /**
     * Find activity codes by status and type.
     * 
     * @param status the status to filter by
     * @param type the type to filter by
     * @return List of activity codes matching both criteria
     */
    List<ActivityCode> findByStatusAndType(String status, String type);

    /**
     * Find activity codes by status and code system.
     * 
     * @param status the status to filter by
     * @param codeSystem the code system to filter by
     * @return List of activity codes matching both criteria
     */
    List<ActivityCode> findByStatusAndCodeSystem(String status, String codeSystem);

    /**
     * Check if an activity code exists with the given code and type.
     * 
     * @param code the activity code to check
     * @param type the type to check
     * @return true if an activity code with this combination exists
     */
    boolean existsByCodeAndType(String code, String type);

    /**
     * Check if an activity code exists with the given code (any type).
     * 
     * @param code the activity code to check
     * @return true if an activity code with this code exists
     */
    boolean existsByCode(String code);

    /**
     * Count activity codes by status.
     * 
     * @param status the status to count
     * @return number of activity codes with the specified status
     */
    long countByStatus(String status);

    /**
     * Count activity codes by type.
     * 
     * @param type the type to count
     * @return number of activity codes with the specified type
     */
    long countByType(String type);

    /**
     * Count activity codes by code system.
     * 
     * @param codeSystem the code system to count
     * @return number of activity codes with the specified code system
     */
    long countByCodeSystem(String codeSystem);

    /**
     * Custom search method that searches both code and description.
     * Uses PostgreSQL full-text search capabilities.
     * 
     * @param searchTerm the term to search for in both code and description
     * @param status the status to filter by (optional)
     * @param type the type to filter by (optional)
     * @param codeSystem the code system to filter by (optional)
     * @param pageable pagination information
     * @return Page of activity codes matching the search criteria
     */
    @Query("""
        SELECT a FROM ActivityCode a 
        WHERE (:searchTerm IS NULL OR 
               LOWER(a.code) LIKE LOWER(FUNCTION('CONCAT', '%', CAST(:searchTerm AS string), '%')) OR 
               LOWER(a.description) LIKE LOWER(FUNCTION('CONCAT', '%', CAST(:searchTerm AS string), '%')))
        AND (:status IS NULL OR a.status = :status)
        AND (:type IS NULL OR a.type = :type)
        AND (:codeSystem IS NULL OR a.codeSystem = :codeSystem)
        ORDER BY a.code ASC
        """)
    Page<ActivityCode> searchActivityCodes(@Param("searchTerm") String searchTerm, 
                                         @Param("status") String status,
                                         @Param("type") String type,
                                         @Param("codeSystem") String codeSystem,
                                         Pageable pageable);

    /**
     * Find all active activity codes ordered by code.
     * 
     * @return List of active activity codes sorted by code
     */
    @Query("SELECT a FROM ActivityCode a WHERE a.status = 'ACTIVE' ORDER BY a.code ASC")
    List<ActivityCode> findAllActiveOrderByCode();

    /**
     * Find activity codes by multiple codes.
     * 
     * @param codes list of activity codes to search for
     * @return List of activity codes matching any of the provided codes
     */
    List<ActivityCode> findByCodeIn(List<String> codes);

    /**
     * Find activity codes by multiple codes with specific status.
     * 
     * @param codes list of activity codes to search for
     * @param status the status to filter by
     * @return List of activity codes matching the codes and status
     */
    List<ActivityCode> findByCodeInAndStatus(List<String> codes, String status);

    /**
     * Find all unique types.
     * 
     * @return List of distinct type values
     */
    @Query("SELECT DISTINCT a.type FROM ActivityCode a WHERE a.type IS NOT NULL ORDER BY a.type")
    List<String> findDistinctTypes();

    /**
     * Find all unique code systems.
     * 
     * @return List of distinct code system values
     */
    @Query("SELECT DISTINCT a.codeSystem FROM ActivityCode a WHERE a.codeSystem IS NOT NULL ORDER BY a.codeSystem")
    List<String> findDistinctCodeSystems();
}

