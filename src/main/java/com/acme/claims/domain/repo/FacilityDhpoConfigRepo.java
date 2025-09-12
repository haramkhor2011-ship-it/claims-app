package com.acme.claims.domain.repo;

import com.acme.claims.domain.model.entity.FacilityDhpoConfig;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

/**
 * Repository for claims.facility_dhpo_config.
 * Used by the DHPO fetch-orchestrator to enumerate active facilities
 * and by admin flows to manage facility entries.
 */
public interface FacilityDhpoConfigRepo extends JpaRepository<FacilityDhpoConfig, Long> {

    List<FacilityDhpoConfig> findByActiveTrue(); // all active facilities

    Optional<FacilityDhpoConfig> findByFacilityCodeAndActiveTrue(String facilityCode); // one active facility
}
