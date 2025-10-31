package com.acme.claims.service;

import com.acme.claims.controller.dto.*;
import com.acme.claims.entity.*;
import com.acme.claims.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Service for reference data lookup operations with caching.
 * 
 * This service provides cached access to all reference data types
 * with comprehensive search, filtering, and pagination capabilities.
 * 
 * Features:
 * - @Cacheable methods for all lookup operations
 * - Automatic cache key generation based on parameters
 * - Pagination support for large datasets
 * - Search and filtering capabilities
 * - Performance tracking and logging
 * - Transactional read operations
 * 
 * Cache Strategy:
 * - Cache keys include all relevant parameters
 * - TTL configured in CacheConfig (6 hours by default)
 * - Automatic cache eviction on data updates
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ReferenceDataService {

    private final FacilityRepository facilityRepository;
    private final PayerRepository payerRepository;
    private final ClinicianRepository clinicianRepository;
    private final DiagnosisCodeRepository diagnosisCodeRepository;
    private final ActivityCodeRepository activityCodeRepository;
    private final DenialCodeRepository denialCodeRepository;

    // ==========================================================================================================
    // FACILITY OPERATIONS
    // ==========================================================================================================

    /**
     * Get all active facilities with caching.
     * 
     * @return List of active facilities
     */
    @Cacheable(value = "facilities", key = "'active'")
    public List<FacilityResponse.FacilityItem> getAllActiveFacilities() {
        log.debug("Fetching all active facilities from database");
        long startTime = System.currentTimeMillis();
        
        List<Facility> facilities = facilityRepository.findAllActiveOrderByCode();
        
        long executionTime = System.currentTimeMillis() - startTime;
        log.info("Retrieved {} active facilities in {}ms", facilities.size(), executionTime);
        
        return facilities.stream()
                .map(this::mapToFacilityItem)
                .collect(Collectors.toList());
    }

    /**
     * Search facilities with caching.
     * 
     * @param request the search request
     * @return Paginated facility response
     */
    @Cacheable(value = "facilities", key = "#request.toString()")
    public ReferenceDataResponse searchFacilities(ReferenceDataRequest request) {
        log.debug("Searching facilities with request: {}", request);
        long startTime = System.currentTimeMillis();
        
        Pageable pageable = createPageableForFacility(request);
        Page<Facility> facilityPage = facilityRepository.searchFacilities(
                request.getSearchTerm(), 
                request.getStatus(), 
                pageable
        );
        
        long executionTime = System.currentTimeMillis() - startTime;
        log.info("Searched facilities: {} results in {}ms", facilityPage.getTotalElements(), executionTime);
        
        return buildReferenceDataResponse(
                facilityPage.getContent().stream()
                        .map(this::mapToFacilityItem)
                        .collect(Collectors.toList()),
                facilityPage,
                request,
                executionTime,
                true
        );
    }

    /**
     * Get facility by code with caching.
     * 
     * @param facilityCode the facility code
     * @return Optional facility item
     */
    @Cacheable(value = "facilities", key = "'code:' + #facilityCode")
    public FacilityResponse getFacilityByCode(String facilityCode) {
        log.debug("Fetching facility by code: {}", facilityCode);
        
        return facilityRepository.findByFacilityCode(facilityCode)
                .map(this::mapToFacilityResponse)
                .orElse(null);
    }

    // ==========================================================================================================
    // PAYER OPERATIONS
    // ==========================================================================================================

    /**
     * Get all active payers with caching.
     * 
     * @return List of active payers
     */
    @Cacheable(value = "payers", key = "'active'")
    public List<PayerResponse.PayerItem> getAllActivePayers() {
        log.debug("Fetching all active payers from database");
        long startTime = System.currentTimeMillis();
        
        List<Payer> payers = payerRepository.findAllActiveOrderByCode();
        
        long executionTime = System.currentTimeMillis() - startTime;
        log.info("Retrieved {} active payers in {}ms", payers.size(), executionTime);
        
        return payers.stream()
                .map(this::mapToPayerItem)
                .collect(Collectors.toList());
    }

    /**
     * Search payers with caching.
     * 
     * @param request the search request
     * @return Paginated payer response
     */
    @Cacheable(value = "payers", key = "#request.toString()")
    public ReferenceDataResponse searchPayers(ReferenceDataRequest request) {
        log.debug("Searching payers with request: {}", request);
        long startTime = System.currentTimeMillis();
        
        Pageable pageable = createPageableForPayer(request);
        Page<Payer> payerPage = payerRepository.searchPayers(
                request.getSearchTerm(), 
                request.getStatus(),
                null, // classification filter can be added later
                pageable
        );
        
        long executionTime = System.currentTimeMillis() - startTime;
        log.info("Searched payers: {} results in {}ms", payerPage.getTotalElements(), executionTime);
        
        return buildReferenceDataResponse(
                payerPage.getContent().stream()
                        .map(this::mapToPayerItem)
                        .collect(Collectors.toList()),
                payerPage,
                request,
                executionTime,
                true
        );
    }

    /**
     * Get payer by code with caching.
     * 
     * @param payerCode the payer code
     * @return Optional payer item
     */
    @Cacheable(value = "payers", key = "'code:' + #payerCode")
    public PayerResponse getPayerByCode(String payerCode) {
        log.debug("Fetching payer by code: {}", payerCode);
        
        return payerRepository.findByPayerCode(payerCode)
                .map(this::mapToPayerResponse)
                .orElse(null);
    }

    // ==========================================================================================================
    // CLINICIAN OPERATIONS
    // ==========================================================================================================

    /**
     * Get all active clinicians with caching.
     * 
     * @return List of active clinicians
     */
    @Cacheable(value = "clinicians", key = "'active'")
    public List<ClinicianResponse.ClinicianItem> getAllActiveClinicians() {
        log.debug("Fetching all active clinicians from database");
        long startTime = System.currentTimeMillis();
        
        List<Clinician> clinicians = clinicianRepository.findAllActiveOrderByCode();
        
        long executionTime = System.currentTimeMillis() - startTime;
        log.info("Retrieved {} active clinicians in {}ms", clinicians.size(), executionTime);
        
        return clinicians.stream()
                .map(this::mapToClinicianItem)
                .collect(Collectors.toList());
    }

    /**
     * Search clinicians with caching.
     * 
     * @param request the search request
     * @return Paginated clinician response
     */
    @Cacheable(value = "clinicians", key = "#request.toString()")
    public ReferenceDataResponse searchClinicians(ReferenceDataRequest request) {
        log.debug("Searching clinicians with request: {}", request);
        long startTime = System.currentTimeMillis();
        
        Pageable pageable = createPageableForClinician(request);
        Page<Clinician> clinicianPage = clinicianRepository.searchClinicians(
                request.getSearchTerm(), 
                request.getStatus(),
                null, // specialty filter can be added later
                pageable
        );
        
        long executionTime = System.currentTimeMillis() - startTime;
        log.info("Searched clinicians: {} results in {}ms", clinicianPage.getTotalElements(), executionTime);
        
        return buildReferenceDataResponse(
                clinicianPage.getContent().stream()
                        .map(this::mapToClinicianItem)
                        .collect(Collectors.toList()),
                clinicianPage,
                request,
                executionTime,
                true
        );
    }

    /**
     * Get clinician by code with caching.
     * 
     * @param clinicianCode the clinician code
     * @return Optional clinician item
     */
    @Cacheable(value = "clinicians", key = "'code:' + #clinicianCode")
    public ClinicianResponse getClinicianByCode(String clinicianCode) {
        log.debug("Fetching clinician by code: {}", clinicianCode);
        
        return clinicianRepository.findByClinicianCode(clinicianCode)
                .map(this::mapToClinicianResponse)
                .orElse(null);
    }

    // ==========================================================================================================
    // DIAGNOSIS CODE OPERATIONS
    // ==========================================================================================================

    /**
     * Get all active diagnosis codes with caching.
     * 
     * @return List of active diagnosis codes
     */
    @Cacheable(value = "diagnosisCodes", key = "'active'")
    public List<DiagnosisCodeResponse.DiagnosisCodeItem> getAllActiveDiagnosisCodes() {
        log.debug("Fetching all active diagnosis codes from database");
        long startTime = System.currentTimeMillis();
        
        List<DiagnosisCode> diagnosisCodes = diagnosisCodeRepository.findAllActiveOrderByCode();
        
        long executionTime = System.currentTimeMillis() - startTime;
        log.info("Retrieved {} active diagnosis codes in {}ms", diagnosisCodes.size(), executionTime);
        
        return diagnosisCodes.stream()
                .map(this::mapToDiagnosisCodeItem)
                .collect(Collectors.toList());
    }

    /**
     * Search diagnosis codes with caching.
     * 
     * @param request the search request
     * @return Paginated diagnosis code response
     */
    @Cacheable(value = "diagnosisCodes", key = "#request.toString()")
    public ReferenceDataResponse searchDiagnosisCodes(ReferenceDataRequest request) {
        log.debug("Searching diagnosis codes with request: {}", request);
        long startTime = System.currentTimeMillis();
        
        Pageable pageable = createPageableForCodeEntity(request);
        Page<DiagnosisCode> diagnosisCodePage = diagnosisCodeRepository.searchDiagnosisCodes(
                request.getSearchTerm(), 
                request.getStatus(),
                null, // code system filter can be added later
                pageable
        );
        
        long executionTime = System.currentTimeMillis() - startTime;
        log.info("Searched diagnosis codes: {} results in {}ms", diagnosisCodePage.getTotalElements(), executionTime);
        
        return buildReferenceDataResponse(
                diagnosisCodePage.getContent().stream()
                        .map(this::mapToDiagnosisCodeItem)
                        .collect(Collectors.toList()),
                diagnosisCodePage,
                request,
                executionTime,
                true
        );
    }

    /**
     * Get diagnosis code by code with caching.
     * Uses ICD-10 as the default code system.
     * 
     * @param code the diagnosis code
     * @return Optional diagnosis code item
     */
    @Cacheable(value = "diagnosisCodes", key = "'code:' + #code")
    public DiagnosisCodeResponse getDiagnosisCodeByCode(String code) {
        log.debug("Fetching diagnosis code by code: {} (default code system: ICD-10)", code);
        
        // Use ICD-10 as default code system
        String defaultCodeSystem = "ICD-10";
        
        return diagnosisCodeRepository.findByCodeAndCodeSystem(code, defaultCodeSystem)
                .map(this::mapToDiagnosisCodeResponse)
                .orElse(null);
    }

    /**
     * Get diagnosis code by code and system with caching.
     * This method is kept for internal use or when code system needs to be explicitly specified.
     * 
     * @param code the diagnosis code
     * @param codeSystem the code system
     * @return Optional diagnosis code item
     */
    @Cacheable(value = "diagnosisCodes", key = "'code:' + #code + ':' + #codeSystem")
    public DiagnosisCodeResponse getDiagnosisCodeByCodeAndSystem(String code, String codeSystem) {
        log.debug("Fetching diagnosis code by code: {} and system: {}", code, codeSystem);
        
        return diagnosisCodeRepository.findByCodeAndCodeSystem(code, codeSystem)
                .map(this::mapToDiagnosisCodeResponse)
                .orElse(null);
    }

    // ==========================================================================================================
    // ACTIVITY CODE OPERATIONS
    // ==========================================================================================================

    /**
     * Get all active activity codes with caching.
     * 
     * @return List of active activity codes
     */
    @Cacheable(value = "activityCodes", key = "'active'")
    public List<ActivityCodeResponse.ActivityCodeItem> getAllActiveActivityCodes() {
        log.debug("Fetching all active activity codes from database");
        long startTime = System.currentTimeMillis();
        
        List<ActivityCode> activityCodes = activityCodeRepository.findAllActiveOrderByCode();
        
        long executionTime = System.currentTimeMillis() - startTime;
        log.info("Retrieved {} active activity codes in {}ms", activityCodes.size(), executionTime);
        
        return activityCodes.stream()
                .map(this::mapToActivityCodeItem)
                .collect(Collectors.toList());
    }

    /**
     * Search activity codes with caching.
     * 
     * @param request the search request
     * @return Paginated activity code response
     */
    @Cacheable(value = "activityCodes", key = "#request.toString()")
    public ReferenceDataResponse searchActivityCodes(ReferenceDataRequest request) {
        log.debug("Searching activity codes with request: {}", request);
        long startTime = System.currentTimeMillis();
        
        Pageable pageable = createPageableForCodeEntity(request);
        Page<ActivityCode> activityCodePage = activityCodeRepository.searchActivityCodes(
                request.getSearchTerm(), 
                request.getStatus(),
                null, // type filter can be added later
                null, // code system filter can be added later
                pageable
        );
        
        long executionTime = System.currentTimeMillis() - startTime;
        log.info("Searched activity codes: {} results in {}ms", activityCodePage.getTotalElements(), executionTime);
        
        return buildReferenceDataResponse(
                activityCodePage.getContent().stream()
                        .map(this::mapToActivityCodeItem)
                        .collect(Collectors.toList()),
                activityCodePage,
                request,
                executionTime,
                true
        );
    }

    /**
     * Get activity code by code with caching.
     * Searches by code only and returns the first active match found.
     * Uses index idx_ref_activity_code for fast lookup.
     * 
     * @param code the activity code
     * @return Optional activity code item
     */
    @Cacheable(value = "activityCodes", key = "'code:' + #code")
    public ActivityCodeResponse getActivityCodeByCode(String code) {
        log.debug("Fetching activity code by code: {} (using index idx_ref_activity_code)", code);
        
        // Find all activity codes with this code (may have multiple types)
        List<ActivityCode> codes = activityCodeRepository.findByCode(code);
        
        if (codes.isEmpty()) {
            return null;
        }
        
        // Prefer active codes first, then return the first one
        Optional<ActivityCode> activeCode = codes.stream()
                .filter(ActivityCode::isActive)
                .findFirst();
        
        ActivityCode selectedCode = activeCode.orElse(codes.get(0));
        
        return mapToActivityCodeResponse(selectedCode);
    }

    /**
     * Get activity code by code and type with caching.
     * This method is kept for internal use or when type needs to be explicitly specified.
     * 
     * @param code the activity code
     * @param type the activity type
     * @return Optional activity code item
     */
    @Cacheable(value = "activityCodes", key = "'code:' + #code + ':' + #type")
    public ActivityCodeResponse getActivityCodeByCodeAndType(String code, String type) {
        log.debug("Fetching activity code by code: {} and type: {}", code, type);
        
        return activityCodeRepository.findByCodeAndType(code, type)
                .map(this::mapToActivityCodeResponse)
                .orElse(null);
    }

    // ==========================================================================================================
    // DENIAL CODE OPERATIONS
    // ==========================================================================================================

    /**
     * Get all denial codes with caching.
     * 
     * @return List of all denial codes
     */
    @Cacheable(value = "denialCodes", key = "'all'")
    public List<DenialCodeResponse.DenialCodeItem> getAllDenialCodes() {
        log.debug("Fetching all denial codes from database");
        long startTime = System.currentTimeMillis();
        
        List<DenialCode> denialCodes = denialCodeRepository.findAllOrderByCode();
        
        long executionTime = System.currentTimeMillis() - startTime;
        log.info("Retrieved {} denial codes in {}ms", denialCodes.size(), executionTime);
        
        return denialCodes.stream()
                .map(this::mapToDenialCodeItem)
                .collect(Collectors.toList());
    }

    /**
     * Search denial codes with caching.
     * 
     * @param request the search request
     * @return Paginated denial code response
     */
    @Cacheable(value = "denialCodes", key = "#request.toString()")
    public ReferenceDataResponse searchDenialCodes(ReferenceDataRequest request) {
        log.debug("Searching denial codes with request: {}", request);
        long startTime = System.currentTimeMillis();
        
        Pageable pageable = createPageableForCodeEntity(request);
        Page<DenialCode> denialCodePage = denialCodeRepository.searchDenialCodes(
                request.getSearchTerm(), 
                pageable
        );
        
        long executionTime = System.currentTimeMillis() - startTime;
        log.info("Searched denial codes: {} results in {}ms", denialCodePage.getTotalElements(), executionTime);
        
        return buildReferenceDataResponse(
                denialCodePage.getContent().stream()
                        .map(this::mapToDenialCodeItem)
                        .collect(Collectors.toList()),
                denialCodePage,
                request,
                executionTime,
                true
        );
    }

    /**
     * Get denial code by code with caching.
     * 
     * @param code the denial code
     * @return Optional denial code item
     */
    @Cacheable(value = "denialCodes", key = "'code:' + #code")
    public DenialCodeResponse getDenialCodeByCode(String code) {
        log.debug("Fetching denial code by code: {}", code);
        
        return denialCodeRepository.findByCode(code)
                .map(this::mapToDenialCodeResponse)
                .orElse(null);
    }

    // ==========================================================================================================
    // HELPER METHODS
    // ==========================================================================================================

    /**
     * Create Pageable object from request.
     * Maps "code" to the correct field name for each entity type.
     */
    private Pageable createPageable(ReferenceDataRequest request) {
        String sortBy = request.getSortBy();
        // "code" field doesn't exist - entities use specific code fields (facilityCode, payerCode, clinicianCode)
        // For now, default to name which exists on Facility, Payer, and Clinician
        if ("code".equals(sortBy)) {
            sortBy = "name";
        }
        Sort sort = Sort.by(
                Sort.Direction.fromString(request.getSortDirection()),
                sortBy
        );
        return PageRequest.of(request.getPage(), request.getSize(), sort);
    }

    /**
     * Create Pageable object for Facility entity.
     * Maps "code" to "facilityCode" since Facility doesn't have a "code" field.
     */
    private Pageable createPageableForFacility(ReferenceDataRequest request) {
        String sortBy = request.getSortBy();
        if ("code".equals(sortBy)) {
            sortBy = "facilityCode";
        } else if ("name".equals(sortBy)) {
            sortBy = "name"; // name exists on Facility
        }
        Sort sort = Sort.by(
                Sort.Direction.fromString(request.getSortDirection()),
                sortBy
        );
        return PageRequest.of(request.getPage(), request.getSize(), sort);
    }

    /**
     * Create Pageable object for Payer entity.
     * Maps "code" to "payerCode" since Payer doesn't have a "code" field.
     */
    private Pageable createPageableForPayer(ReferenceDataRequest request) {
        String sortBy = request.getSortBy();
        if ("code".equals(sortBy)) {
            sortBy = "payerCode";
        } else if ("name".equals(sortBy)) {
            sortBy = "name"; // name exists on Payer
        }
        Sort sort = Sort.by(
                Sort.Direction.fromString(request.getSortDirection()),
                sortBy
        );
        return PageRequest.of(request.getPage(), request.getSize(), sort);
    }

    /**
     * Create Pageable object for Clinician entity.
     * Maps "code" to "clinicianCode" since Clinician doesn't have a "code" field.
     */
    private Pageable createPageableForClinician(ReferenceDataRequest request) {
        String sortBy = request.getSortBy();
        if ("code".equals(sortBy)) {
            sortBy = "clinicianCode";
        } else if ("name".equals(sortBy)) {
            sortBy = "name"; // name exists on Clinician
        }
        Sort sort = Sort.by(
                Sort.Direction.fromString(request.getSortDirection()),
                sortBy
        );
        return PageRequest.of(request.getPage(), request.getSize(), sort);
    }

    /**
     * Create Pageable object for code-based entities (DiagnosisCode, ActivityCode, DenialCode).
     * Maps "name" to "description" since these entities don't have a "name" field.
     * Note: These entities DO have a "code" field, so "code" works as-is.
     */
    private Pageable createPageableForCodeEntity(ReferenceDataRequest request) {
        String sortBy = request.getSortBy();
        // Map "name" to "description" for code-based entities that use "description" instead of "name"
        if ("name".equals(sortBy)) {
            sortBy = "description";
        }
        // "code" field exists on these entities, so no mapping needed
        Sort sort = Sort.by(
                Sort.Direction.fromString(request.getSortDirection()),
                sortBy
        );
        return PageRequest.of(request.getPage(), request.getSize(), sort);
    }

    /**
     * Build standardized reference data response.
     */
    private ReferenceDataResponse buildReferenceDataResponse(
            List<ReferenceDataResponse.ReferenceDataItem> items,
            Page<?> page,
            ReferenceDataRequest request,
            long executionTime,
            boolean fromCache) {
        
        ReferenceDataResponse.PaginationMetadata pagination = ReferenceDataResponse.PaginationMetadata.builder()
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .first(page.isFirst())
                .last(page.isLast())
                .numberOfElements(page.getNumberOfElements())
                .build();

        ReferenceDataResponse.FilterMetadata filters = ReferenceDataResponse.FilterMetadata.builder()
                .searchTerm(request.getSearchTerm())
                .status(request.getStatus())
                .sortBy(request.getSortBy())
                .build();

        ReferenceDataResponse.ResponseMetadata metadata = ReferenceDataResponse.ResponseMetadata.builder()
                .timestamp(LocalDateTime.now())
                .executionTimeMs(executionTime)
                .fromCache(fromCache)
                .cacheKey(UUID.randomUUID().toString()) // This would be the actual cache key
                .correlationId(UUID.randomUUID().toString())
                .build();

        return ReferenceDataResponse.builder()
                .items(items)
                .pagination(pagination)
                .filters(filters)
                .metadata(metadata)
                .build();
    }

    // ==========================================================================================================
    // MAPPING METHODS
    // ==========================================================================================================

    private FacilityResponse.FacilityItem mapToFacilityItem(Facility facility) {
        FacilityResponse.FacilityItem item = new FacilityResponse.FacilityItem();
        item.setId(facility.getId());
        item.setFacilityCode(facility.getFacilityCode());
        item.setName(facility.getName());
        item.setDisplayName(facility.getDisplayName());
        item.setCity(facility.getCity());
        item.setCountry(facility.getCountry());
        item.setStatus(facility.getStatus());
        item.setCreatedAt(facility.getCreatedAt());
        item.setUpdatedAt(facility.getUpdatedAt());
        
        // Set base fields
        item.setCode(facility.getFacilityCode());
        item.setName(facility.getName());
        item.setDisplayName(facility.getDisplayName());
        item.setStatus(facility.getStatus());
        item.setCreatedAt(facility.getCreatedAt());
        item.setUpdatedAt(facility.getUpdatedAt());
        
        return item;
    }

    private PayerResponse.PayerItem mapToPayerItem(Payer payer) {
        PayerResponse.PayerItem item = new PayerResponse.PayerItem();
        item.setId(payer.getId());
        item.setPayerCode(payer.getPayerCode());
        item.setName(payer.getName());
        item.setDisplayName(payer.getDisplayName());
        item.setClassification(payer.getClassification());
        item.setStatus(payer.getStatus());
        item.setCreatedAt(payer.getCreatedAt());
        item.setUpdatedAt(payer.getUpdatedAt());
        
        // Set base fields
        item.setCode(payer.getPayerCode());
        item.setName(payer.getName());
        item.setDisplayName(payer.getDisplayName());
        item.setStatus(payer.getStatus());
        item.setCreatedAt(payer.getCreatedAt());
        item.setUpdatedAt(payer.getUpdatedAt());
        
        return item;
    }

    private ClinicianResponse.ClinicianItem mapToClinicianItem(Clinician clinician) {
        ClinicianResponse.ClinicianItem item = new ClinicianResponse.ClinicianItem();
        item.setId(clinician.getId());
        item.setClinicianCode(clinician.getClinicianCode());
        item.setName(clinician.getName());
        item.setDisplayName(clinician.getDisplayName());
        item.setSpecialty(clinician.getSpecialty());
        item.setStatus(clinician.getStatus());
        item.setCreatedAt(clinician.getCreatedAt());
        item.setUpdatedAt(clinician.getUpdatedAt());
        
        // Set base fields
        item.setCode(clinician.getClinicianCode());
        item.setName(clinician.getName());
        item.setDisplayName(clinician.getDisplayName());
        item.setStatus(clinician.getStatus());
        item.setCreatedAt(clinician.getCreatedAt());
        item.setUpdatedAt(clinician.getUpdatedAt());
        
        return item;
    }

    private DiagnosisCodeResponse.DiagnosisCodeItem mapToDiagnosisCodeItem(DiagnosisCode diagnosisCode) {
        DiagnosisCodeResponse.DiagnosisCodeItem item = new DiagnosisCodeResponse.DiagnosisCodeItem();
        item.setId(diagnosisCode.getId());
        item.setCode(diagnosisCode.getCode());
        item.setCodeSystem(diagnosisCode.getCodeSystem());
        item.setDescription(diagnosisCode.getDescription());
        item.setDisplayName(diagnosisCode.getDisplayName());
        item.setFullCode(diagnosisCode.getFullCode());
        item.setStatus(diagnosisCode.getStatus());
        item.setCreatedAt(diagnosisCode.getCreatedAt());
        item.setUpdatedAt(diagnosisCode.getUpdatedAt());
        
        // Set base fields
        item.setCode(diagnosisCode.getCode());
        item.setName(diagnosisCode.getDescription());
        item.setDisplayName(diagnosisCode.getDisplayName());
        item.setStatus(diagnosisCode.getStatus());
        item.setCreatedAt(diagnosisCode.getCreatedAt());
        item.setUpdatedAt(diagnosisCode.getUpdatedAt());
        
        return item;
    }

    private ActivityCodeResponse.ActivityCodeItem mapToActivityCodeItem(ActivityCode activityCode) {
        ActivityCodeResponse.ActivityCodeItem item = new ActivityCodeResponse.ActivityCodeItem();
        item.setId(activityCode.getId());
        item.setType(activityCode.getType());
        item.setCode(activityCode.getCode());
        item.setCodeSystem(activityCode.getCodeSystem());
        item.setDescription(activityCode.getDescription());
        item.setDisplayName(activityCode.getDisplayName());
        item.setFullCode(activityCode.getFullCode());
        item.setStatus(activityCode.getStatus());
        item.setCreatedAt(activityCode.getCreatedAt());
        item.setUpdatedAt(activityCode.getUpdatedAt());
        
        // Set base fields
        item.setCode(activityCode.getCode());
        item.setName(activityCode.getDescription());
        item.setDisplayName(activityCode.getDisplayName());
        item.setStatus(activityCode.getStatus());
        item.setCreatedAt(activityCode.getCreatedAt());
        item.setUpdatedAt(activityCode.getUpdatedAt());
        
        return item;
    }

    private DenialCodeResponse.DenialCodeItem mapToDenialCodeItem(DenialCode denialCode) {
        DenialCodeResponse.DenialCodeItem item = new DenialCodeResponse.DenialCodeItem();
        item.setId(denialCode.getId());
        item.setCode(denialCode.getCode());
        item.setDescription(denialCode.getDescription());
        item.setDisplayName(denialCode.getDisplayName());
        item.setCreatedAt(denialCode.getCreatedAt());
        item.setUpdatedAt(denialCode.getUpdatedAt());
        
        // Set payer-related fields to null/false since DenialCode doesn't have payerCode field
        item.setPayerCode(null);
        item.setPayerSpecific(false);
        item.setGlobal(true);
        item.setFullCode(denialCode.getCode()); // Use code as full code since no payer scope
        
        // Set base fields
        item.setCode(denialCode.getCode());
        item.setName(denialCode.getDescription());
        item.setDisplayName(denialCode.getDisplayName());
        item.setStatus("ACTIVE"); // Denial codes don't have status, but base class expects it
        item.setCreatedAt(denialCode.getCreatedAt());
        item.setUpdatedAt(denialCode.getUpdatedAt());
        
        return item;
    }

    // ==========================================================================================================
    // RESPONSE DTO MAPPING METHODS
    // ==========================================================================================================

    private FacilityResponse mapToFacilityResponse(Facility facility) {
        FacilityResponse.FacilityItem item = mapToFacilityItem(facility);
        return FacilityResponse.builder()
                .facilities(List.of(item))
                .build();
    }

    private PayerResponse mapToPayerResponse(Payer payer) {
        PayerResponse.PayerItem item = mapToPayerItem(payer);
        return PayerResponse.builder()
                .payers(List.of(item))
                .build();
    }

    private ClinicianResponse mapToClinicianResponse(Clinician clinician) {
        ClinicianResponse.ClinicianItem item = mapToClinicianItem(clinician);
        return ClinicianResponse.builder()
                .clinicians(List.of(item))
                .build();
    }

    private DiagnosisCodeResponse mapToDiagnosisCodeResponse(DiagnosisCode diagnosisCode) {
        DiagnosisCodeResponse.DiagnosisCodeItem item = mapToDiagnosisCodeItem(diagnosisCode);
        return DiagnosisCodeResponse.builder()
                .diagnosisCodes(List.of(item))
                .build();
    }

    private ActivityCodeResponse mapToActivityCodeResponse(ActivityCode activityCode) {
        ActivityCodeResponse.ActivityCodeItem item = mapToActivityCodeItem(activityCode);
        return ActivityCodeResponse.builder()
                .activityCodes(List.of(item))
                .build();
    }

    private DenialCodeResponse mapToDenialCodeResponse(DenialCode denialCode) {
        DenialCodeResponse.DenialCodeItem item = mapToDenialCodeItem(denialCode);
        return DenialCodeResponse.builder()
                .denialCodes(List.of(item))
                .build();
    }
}
