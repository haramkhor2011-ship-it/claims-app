package com.acme.claims.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Caching;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.util.Objects;
import java.util.concurrent.CompletableFuture;

/**
 * Service for managing cache refresh operations.
 * 
 * This service provides functionality to manually refresh caches
 * and schedule automatic cache refresh operations.
 * 
 * Features:
 * - Manual cache refresh for all reference data types
 * - Scheduled cache refresh (configurable intervals)
 * - Selective cache refresh by type
 * - Async cache refresh operations
 * - Cache statistics and monitoring
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CacheRefreshService {

    private final CacheManager cacheManager;
    private final ReferenceDataService referenceDataService;

    // ==========================================================================================================
    // MANUAL CACHE REFRESH OPERATIONS
    // ==========================================================================================================

    /**
     * Refresh all reference data caches.
     * This operation clears all caches and forces fresh data to be loaded.
     * 
     * @return CompletableFuture indicating completion
     */
    @Async
    @Caching(evict = {
        @CacheEvict(value = "facilities", allEntries = true),
        @CacheEvict(value = "facilityByCode", allEntries = true),
        @CacheEvict(value = "payers", allEntries = true),
        @CacheEvict(value = "payerByCode", allEntries = true),
        @CacheEvict(value = "clinicians", allEntries = true),
        @CacheEvict(value = "clinicianByCode", allEntries = true),
        @CacheEvict(value = "diagnosisCodes", allEntries = true),
        @CacheEvict(value = "diagnosisCodeByCodeAndSystem", allEntries = true),
        @CacheEvict(value = "activityCodes", allEntries = true),
        @CacheEvict(value = "activityCodeByCodeAndType", allEntries = true),
        @CacheEvict(value = "denialCodes", allEntries = true),
        @CacheEvict(value = "denialCodeByCode", allEntries = true)
    })
    public CompletableFuture<Void> refreshAllCaches() {
        log.info("Starting manual refresh of all reference data caches");
        
        try {
            // Clear all caches
            clearAllCaches();
            
            // Preload frequently accessed data
            preloadFrequentlyAccessedData();
            
            log.info("Successfully completed manual refresh of all reference data caches");
            return CompletableFuture.completedFuture(null);
            
        } catch (Exception e) {
            log.error("Error during manual cache refresh", e);
            return CompletableFuture.failedFuture(e);
        }
    }

    /**
     * Refresh facility caches only.
     * 
     * @return CompletableFuture indicating completion
     */
    @Async
    @Caching(evict = {
        @CacheEvict(value = "facilities", allEntries = true),
        @CacheEvict(value = "facilityByCode", allEntries = true)
    })
    public CompletableFuture<Void> refreshFacilityCaches() {
        log.info("Starting manual refresh of facility caches");
        
        try {
            clearFacilityCaches();
            preloadFacilityData();
            
            log.info("Successfully completed manual refresh of facility caches");
            return CompletableFuture.completedFuture(null);
            
        } catch (Exception e) {
            log.error("Error during facility cache refresh", e);
            return CompletableFuture.failedFuture(e);
        }
    }

    /**
     * Refresh payer caches only.
     * 
     * @return CompletableFuture indicating completion
     */
    @Async
    @Caching(evict = {
        @CacheEvict(value = "payers", allEntries = true),
        @CacheEvict(value = "payerByCode", allEntries = true)
    })
    public CompletableFuture<Void> refreshPayerCaches() {
        log.info("Starting manual refresh of payer caches");
        
        try {
            clearPayerCaches();
            preloadPayerData();
            
            log.info("Successfully completed manual refresh of payer caches");
            return CompletableFuture.completedFuture(null);
            
        } catch (Exception e) {
            log.error("Error during payer cache refresh", e);
            return CompletableFuture.failedFuture(e);
        }
    }

    /**
     * Refresh clinician caches only.
     * 
     * @return CompletableFuture indicating completion
     */
    @Async
    @Caching(evict = {
        @CacheEvict(value = "clinicians", allEntries = true),
        @CacheEvict(value = "clinicianByCode", allEntries = true)
    })
    public CompletableFuture<Void> refreshClinicianCaches() {
        log.info("Starting manual refresh of clinician caches");
        
        try {
            clearClinicianCaches();
            preloadClinicianData();
            
            log.info("Successfully completed manual refresh of clinician caches");
            return CompletableFuture.completedFuture(null);
            
        } catch (Exception e) {
            log.error("Error during clinician cache refresh", e);
            return CompletableFuture.failedFuture(e);
        }
    }

    /**
     * Refresh diagnosis code caches only.
     * 
     * @return CompletableFuture indicating completion
     */
    @Async
    @Caching(evict = {
        @CacheEvict(value = "diagnosisCodes", allEntries = true),
        @CacheEvict(value = "diagnosisCodeByCodeAndSystem", allEntries = true)
    })
    public CompletableFuture<Void> refreshDiagnosisCodeCaches() {
        log.info("Starting manual refresh of diagnosis code caches");
        
        try {
            clearDiagnosisCodeCaches();
            preloadDiagnosisCodeData();
            
            log.info("Successfully completed manual refresh of diagnosis code caches");
            return CompletableFuture.completedFuture(null);
            
        } catch (Exception e) {
            log.error("Error during diagnosis code cache refresh", e);
            return CompletableFuture.failedFuture(e);
        }
    }

    /**
     * Refresh activity code caches only.
     * 
     * @return CompletableFuture indicating completion
     */
    @Async
    @Caching(evict = {
        @CacheEvict(value = "activityCodes", allEntries = true),
        @CacheEvict(value = "activityCodeByCodeAndType", allEntries = true)
    })
    public CompletableFuture<Void> refreshActivityCodeCaches() {
        log.info("Starting manual refresh of activity code caches");
        
        try {
            clearActivityCodeCaches();
            preloadActivityCodeData();
            
            log.info("Successfully completed manual refresh of activity code caches");
            return CompletableFuture.completedFuture(null);
            
        } catch (Exception e) {
            log.error("Error during activity code cache refresh", e);
            return CompletableFuture.failedFuture(e);
        }
    }

    /**
     * Refresh denial code caches only.
     * 
     * @return CompletableFuture indicating completion
     */
    @Async
    @Caching(evict = {
        @CacheEvict(value = "denialCodes", allEntries = true),
        @CacheEvict(value = "denialCodeByCode", allEntries = true)
    })
    public CompletableFuture<Void> refreshDenialCodeCaches() {
        log.info("Starting manual refresh of denial code caches");
        
        try {
            clearDenialCodeCaches();
            preloadDenialCodeData();
            
            log.info("Successfully completed manual refresh of denial code caches");
            return CompletableFuture.completedFuture(null);
            
        } catch (Exception e) {
            log.error("Error during denial code cache refresh", e);
            return CompletableFuture.failedFuture(e);
        }
    }

    // ==========================================================================================================
    // SCHEDULED CACHE REFRESH OPERATIONS
    // ==========================================================================================================

    /**
     * Scheduled cache refresh - runs every 6 hours by default.
     * This can be configured via application properties.
     */
    @Scheduled(fixedRateString = "${claims.cache.refresh-interval:21600000}") // 6 hours default
    public void scheduledCacheRefresh() {
        log.info("Starting scheduled cache refresh");
        
        try {
            refreshAllCaches().join();
            log.info("Successfully completed scheduled cache refresh");
            
        } catch (Exception e) {
            log.error("Error during scheduled cache refresh", e);
        }
    }

    /**
     * Scheduled cache refresh for frequently changing data - runs every 2 hours.
     * This includes facilities, payers, and clinicians.
     */
    @Scheduled(fixedRateString = "${claims.cache.frequent-refresh-interval:7200000}") // 2 hours default
    public void scheduledFrequentCacheRefresh() {
        log.info("Starting scheduled frequent cache refresh");
        
        try {
            CompletableFuture.allOf(
                refreshFacilityCaches(),
                refreshPayerCaches(),
                refreshClinicianCaches()
            ).join();
            
            log.info("Successfully completed scheduled frequent cache refresh");
            
        } catch (Exception e) {
            log.error("Error during scheduled frequent cache refresh", e);
        }
    }

    // ==========================================================================================================
    // CACHE CLEARING OPERATIONS
    // ==========================================================================================================

    /**
     * Clear all reference data caches.
     */
    public void clearAllCaches() {
        log.info("Clearing all reference data caches");
        
        String[] cacheNames = {
            "facilities", "facilityByCode",
            "payers", "payerByCode",
            "clinicians", "clinicianByCode",
            "diagnosisCodes", "diagnosisCodeByCodeAndSystem",
            "activityCodes", "activityCodeByCodeAndType",
            "denialCodes", "denialCodeByCode"
        };
        
        for (String cacheName : cacheNames) {
            var cache = cacheManager.getCache(cacheName);
            if (cache != null) {
                cache.clear();
                log.debug("Cleared cache: {}", cacheName);
            }
        }
        
        log.info("Successfully cleared all reference data caches");
    }

    /**
     * Clear facility caches.
     */
    public void clearFacilityCaches() {
        clearCache("facilities");
        clearCache("facilityByCode");
    }

    /**
     * Clear payer caches.
     */
    public void clearPayerCaches() {
        clearCache("payers");
        clearCache("payerByCode");
    }

    /**
     * Clear clinician caches.
     */
    public void clearClinicianCaches() {
        clearCache("clinicians");
        clearCache("clinicianByCode");
    }

    /**
     * Clear diagnosis code caches.
     */
    public void clearDiagnosisCodeCaches() {
        clearCache("diagnosisCodes");
        clearCache("diagnosisCodeByCodeAndSystem");
    }

    /**
     * Clear activity code caches.
     */
    public void clearActivityCodeCaches() {
        clearCache("activityCodes");
        clearCache("activityCodeByCodeAndType");
    }

    /**
     * Clear denial code caches.
     */
    public void clearDenialCodeCaches() {
        clearCache("denialCodes");
        clearCache("denialCodeByCode");
    }

    /**
     * Clear a specific cache by name.
     * 
     * @param cacheName The name of the cache to clear
     */
    private void clearCache(String cacheName) {
        var cache = cacheManager.getCache(cacheName);
        if (cache != null) {
            cache.clear();
            log.debug("Cleared cache: {}", cacheName);
        } else {
            log.warn("Cache not found: {}", cacheName);
        }
    }

    // ==========================================================================================================
    // CACHE PRELOADING OPERATIONS
    // ==========================================================================================================

    /**
     * Preload frequently accessed reference data.
     */
    private void preloadFrequentlyAccessedData() {
        log.info("Preloading frequently accessed reference data");
        
        try {
            // Preload first page of each reference data type
            preloadFacilityData();
            preloadPayerData();
            preloadClinicianData();
            preloadDiagnosisCodeData();
            preloadActivityCodeData();
            preloadDenialCodeData();
            
            log.info("Successfully preloaded frequently accessed reference data");
            
        } catch (Exception e) {
            log.error("Error preloading frequently accessed data", e);
        }
    }

    /**
     * Preload facility data.
     */
    private void preloadFacilityData() {
        try {
            // Preload first page of facilities
            referenceDataService.searchFacilities(createDefaultRequest());
            log.debug("Preloaded facility data");
        } catch (Exception e) {
            log.warn("Failed to preload facility data", e);
        }
    }

    /**
     * Preload payer data.
     */
    private void preloadPayerData() {
        try {
            // Preload first page of payers
            referenceDataService.searchPayers(createDefaultRequest());
            log.debug("Preloaded payer data");
        } catch (Exception e) {
            log.warn("Failed to preload payer data", e);
        }
    }

    /**
     * Preload clinician data.
     */
    private void preloadClinicianData() {
        try {
            // Preload first page of clinicians
            referenceDataService.searchClinicians(createDefaultRequest());
            log.debug("Preloaded clinician data");
        } catch (Exception e) {
            log.warn("Failed to preload clinician data", e);
        }
    }

    /**
     * Preload diagnosis code data.
     */
    private void preloadDiagnosisCodeData() {
        try {
            // Preload first page of diagnosis codes
            referenceDataService.searchDiagnosisCodes(createDefaultRequest());
            log.debug("Preloaded diagnosis code data");
        } catch (Exception e) {
            log.warn("Failed to preload diagnosis code data", e);
        }
    }

    /**
     * Preload activity code data.
     */
    private void preloadActivityCodeData() {
        try {
            // Preload first page of activity codes
            referenceDataService.searchActivityCodes(createDefaultRequest());
            log.debug("Preloaded activity code data");
        } catch (Exception e) {
            log.warn("Failed to preload activity code data", e);
        }
    }

    /**
     * Preload denial code data.
     */
    private void preloadDenialCodeData() {
        try {
            // Preload first page of denial codes
            referenceDataService.searchDenialCodes(createDefaultRequest());
            log.debug("Preloaded denial code data");
        } catch (Exception e) {
            log.warn("Failed to preload denial code data", e);
        }
    }

    /**
     * Create a default request for preloading data.
     * 
     * @return Default reference data request
     */
    private com.acme.claims.controller.dto.ReferenceDataRequest createDefaultRequest() {
        return com.acme.claims.controller.dto.ReferenceDataRequest.builder()
                .page(0)
                .size(10)
                .status("ACTIVE")
                .sortBy("name")
                .sortDirection("ASC")
                .build();
    }

    // ==========================================================================================================
    // CACHE STATISTICS AND MONITORING
    // ==========================================================================================================

    /**
     * Get cache statistics for monitoring.
     * 
     * @return Cache statistics information
     */
    public String getCacheStatistics() {
        StringBuilder stats = new StringBuilder();
        stats.append("Cache Statistics:\n");
        
        String[] cacheNames = {
            "facilities", "facilityByCode",
            "payers", "payerByCode",
            "clinicians", "clinicianByCode",
            "diagnosisCodes", "diagnosisCodeByCodeAndSystem",
            "activityCodes", "activityCodeByCodeAndType",
            "denialCodes", "denialCodeByCode"
        };
        
        for (String cacheName : cacheNames) {
            var cache = cacheManager.getCache(cacheName);
            if (cache != null) {
                stats.append(String.format("  %s: %s\n", cacheName, cache.getClass().getSimpleName()));
            } else {
                stats.append(String.format("  %s: Not Found\n", cacheName));
            }
        }
        
        return stats.toString();
    }

    /**
     * Check if cache is available and working.
     * 
     * @return true if cache is working, false otherwise
     */
    public boolean isCacheAvailable() {
        try {
            var cache = cacheManager.getCache("facilities");
            return cache != null;
        } catch (Exception e) {
            log.warn("Cache availability check failed", e);
            return false;
        }
    }
}
