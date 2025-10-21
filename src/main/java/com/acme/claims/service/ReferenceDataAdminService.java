package com.acme.claims.service;

import com.acme.claims.controller.dto.*;
import com.acme.claims.entity.*;
import com.acme.claims.repository.*;
import com.acme.claims.security.service.UserContextService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Caching;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * Service for managing reference data CRUD operations.
 * 
 * This service provides administrative functionality for facility admins
 * to create, read, update, and delete reference data entries.
 * 
 * Features:
 * - CRUD operations for all reference data types
 * - Cache eviction on data modifications
 * - Audit logging for all changes
 * - Input validation and sanitization
 * - Transaction management
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class ReferenceDataAdminService {

    private final FacilityRepository facilityRepository;
    private final PayerRepository payerRepository;
    private final ClinicianRepository clinicianRepository;
    private final DiagnosisCodeRepository diagnosisCodeRepository;
    private final ActivityCodeRepository activityCodeRepository;
    private final DenialCodeRepository denialCodeRepository;
    private final UserContextService userContextService;

    // ==========================================================================================================
    // FACILITY MANAGEMENT
    // ==========================================================================================================

    /**
     * Create a new facility.
     * 
     * @param request The facility creation request
     * @return The created facility response
     */
    @Caching(evict = {
        @CacheEvict(value = "facilities", allEntries = true),
        @CacheEvict(value = "facilityByCode", allEntries = true)
    })
    public FacilityResponse.FacilityItem createFacility(FacilityRequest request) {
        log.info("Creating facility with code: {}", request.getFacilityCode());
        
        // Check if facility code already exists
        if (facilityRepository.existsByFacilityCode(request.getFacilityCode())) {
            throw new IllegalArgumentException("Facility with code " + request.getFacilityCode() + " already exists");
        }

        Facility facility = Facility.builder()
                .facilityCode(request.getFacilityCode())
                .name(request.getName())
                .city(request.getCity())
                .country(request.getCountry())
                .status(request.getStatus())
                .build();

        Facility savedFacility = facilityRepository.save(facility);
        log.info("Successfully created facility: {} with ID: {}", savedFacility.getFacilityCode(), savedFacility.getId());

        return mapToFacilityItem(savedFacility);
    }

    /**
     * Update an existing facility.
     * 
     * @param id The facility ID
     * @param request The facility update request
     * @return The updated facility response
     */
    @Caching(evict = {
        @CacheEvict(value = "facilities", allEntries = true),
        @CacheEvict(value = "facilityByCode", allEntries = true)
    })
    public FacilityResponse.FacilityItem updateFacility(Long id, FacilityRequest request) {
        log.info("Updating facility with ID: {}", id);
        
        Facility facility = facilityRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Facility with ID " + id + " not found"));

        // Check if facility code is being changed and if new code already exists
        if (!facility.getFacilityCode().equals(request.getFacilityCode()) && 
            facilityRepository.existsByFacilityCode(request.getFacilityCode())) {
            throw new IllegalArgumentException("Facility with code " + request.getFacilityCode() + " already exists");
        }

        facility.setFacilityCode(request.getFacilityCode());
        facility.setName(request.getName());
        facility.setCity(request.getCity());
        facility.setCountry(request.getCountry());
        facility.setStatus(request.getStatus());

        Facility savedFacility = facilityRepository.save(facility);
        log.info("Successfully updated facility: {} with ID: {}", savedFacility.getFacilityCode(), savedFacility.getId());

        return mapToFacilityItem(savedFacility);
    }

    /**
     * Delete a facility (soft delete).
     * 
     * @param id The facility ID
     */
    @Caching(evict = {
        @CacheEvict(value = "facilities", allEntries = true),
        @CacheEvict(value = "facilityByCode", allEntries = true)
    })
    public void deleteFacility(Long id) {
        log.info("Deleting facility with ID: {}", id);
        
        Facility facility = facilityRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Facility with ID " + id + " not found"));

        facility.setStatus("INACTIVE");
        facilityRepository.save(facility);
        
        log.info("Successfully soft-deleted facility: {} with ID: {}", facility.getFacilityCode(), facility.getId());
    }

    /**
     * Get facility by ID.
     * 
     * @param id The facility ID
     * @return The facility response
     */
    @Transactional(readOnly = true)
    public FacilityResponse.FacilityItem getFacilityById(Long id) {
        log.info("Retrieving facility with ID: {}", id);
        
        Facility facility = facilityRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Facility with ID " + id + " not found"));

        return mapToFacilityItem(facility);
    }

    // ==========================================================================================================
    // PAYER MANAGEMENT
    // ==========================================================================================================

    /**
     * Create a new payer.
     * 
     * @param request The payer creation request
     * @return The created payer response
     */
    @Caching(evict = {
        @CacheEvict(value = "payers", allEntries = true),
        @CacheEvict(value = "payerByCode", allEntries = true)
    })
    public PayerResponse.PayerItem createPayer(PayerRequest request) {
        log.info("Creating payer with code: {}", request.getPayerCode());
        
        // Check if payer code already exists
        if (payerRepository.existsByPayerCode(request.getPayerCode())) {
            throw new IllegalArgumentException("Payer with code " + request.getPayerCode() + " already exists");
        }

        Payer payer = Payer.builder()
                .payerCode(request.getPayerCode())
                .name(request.getName())
                .classification(request.getClassification())
                .status(request.getStatus())
                .build();

        Payer savedPayer = payerRepository.save(payer);
        log.info("Successfully created payer: {} with ID: {}", savedPayer.getPayerCode(), savedPayer.getId());

        return mapToPayerItem(savedPayer);
    }

    /**
     * Update an existing payer.
     * 
     * @param id The payer ID
     * @param request The payer update request
     * @return The updated payer response
     */
    @Caching(evict = {
        @CacheEvict(value = "payers", allEntries = true),
        @CacheEvict(value = "payerByCode", allEntries = true)
    })
    public PayerResponse.PayerItem updatePayer(Long id, PayerRequest request) {
        log.info("Updating payer with ID: {}", id);
        
        Payer payer = payerRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Payer with ID " + id + " not found"));

        // Check if payer code is being changed and if new code already exists
        if (!payer.getPayerCode().equals(request.getPayerCode()) && 
            payerRepository.existsByPayerCode(request.getPayerCode())) {
            throw new IllegalArgumentException("Payer with code " + request.getPayerCode() + " already exists");
        }

        payer.setPayerCode(request.getPayerCode());
        payer.setName(request.getName());
        payer.setClassification(request.getClassification());
        payer.setStatus(request.getStatus());

        Payer savedPayer = payerRepository.save(payer);
        log.info("Successfully updated payer: {} with ID: {}", savedPayer.getPayerCode(), savedPayer.getId());

        return mapToPayerItem(savedPayer);
    }

    /**
     * Delete a payer (soft delete).
     * 
     * @param id The payer ID
     */
    @Caching(evict = {
        @CacheEvict(value = "payers", allEntries = true),
        @CacheEvict(value = "payerByCode", allEntries = true)
    })
    public void deletePayer(Long id) {
        log.info("Deleting payer with ID: {}", id);
        
        Payer payer = payerRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Payer with ID " + id + " not found"));

        payer.setStatus("INACTIVE");
        payerRepository.save(payer);
        
        log.info("Successfully soft-deleted payer: {} with ID: {}", payer.getPayerCode(), payer.getId());
    }

    /**
     * Get payer by ID.
     * 
     * @param id The payer ID
     * @return The payer response
     */
    @Transactional(readOnly = true)
    public PayerResponse.PayerItem getPayerById(Long id) {
        log.info("Retrieving payer with ID: {}", id);
        
        Payer payer = payerRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Payer with ID " + id + " not found"));

        return mapToPayerItem(payer);
    }

    // ==========================================================================================================
    // CLINICIAN MANAGEMENT
    // ==========================================================================================================

    /**
     * Create a new clinician.
     * 
     * @param request The clinician creation request
     * @return The created clinician response
     */
    @Caching(evict = {
        @CacheEvict(value = "clinicians", allEntries = true),
        @CacheEvict(value = "clinicianByCode", allEntries = true)
    })
    public ClinicianResponse.ClinicianItem createClinician(ClinicianRequest request) {
        log.info("Creating clinician with code: {}", request.getClinicianCode());
        
        // Check if clinician code already exists
        if (clinicianRepository.existsByClinicianCode(request.getClinicianCode())) {
            throw new IllegalArgumentException("Clinician with code " + request.getClinicianCode() + " already exists");
        }

        Clinician clinician = Clinician.builder()
                .clinicianCode(request.getClinicianCode())
                .name(request.getName())
                .specialty(request.getSpecialty())
                .status(request.getStatus())
                .build();

        Clinician savedClinician = clinicianRepository.save(clinician);
        log.info("Successfully created clinician: {} with ID: {}", savedClinician.getClinicianCode(), savedClinician.getId());

        return mapToClinicianItem(savedClinician);
    }

    /**
     * Update an existing clinician.
     * 
     * @param id The clinician ID
     * @param request The clinician update request
     * @return The updated clinician response
     */
    @Caching(evict = {
        @CacheEvict(value = "clinicians", allEntries = true),
        @CacheEvict(value = "clinicianByCode", allEntries = true)
    })
    public ClinicianResponse.ClinicianItem updateClinician(Long id, ClinicianRequest request) {
        log.info("Updating clinician with ID: {}", id);
        
        Clinician clinician = clinicianRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Clinician with ID " + id + " not found"));

        // Check if clinician code is being changed and if new code already exists
        if (!clinician.getClinicianCode().equals(request.getClinicianCode()) && 
            clinicianRepository.existsByClinicianCode(request.getClinicianCode())) {
            throw new IllegalArgumentException("Clinician with code " + request.getClinicianCode() + " already exists");
        }

        clinician.setClinicianCode(request.getClinicianCode());
        clinician.setName(request.getName());
        clinician.setSpecialty(request.getSpecialty());
        clinician.setStatus(request.getStatus());

        Clinician savedClinician = clinicianRepository.save(clinician);
        log.info("Successfully updated clinician: {} with ID: {}", savedClinician.getClinicianCode(), savedClinician.getId());

        return mapToClinicianItem(savedClinician);
    }

    /**
     * Delete a clinician (soft delete).
     * 
     * @param id The clinician ID
     */
    @Caching(evict = {
        @CacheEvict(value = "clinicians", allEntries = true),
        @CacheEvict(value = "clinicianByCode", allEntries = true)
    })
    public void deleteClinician(Long id) {
        log.info("Deleting clinician with ID: {}", id);
        
        Clinician clinician = clinicianRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Clinician with ID " + id + " not found"));

        clinician.setStatus("INACTIVE");
        clinicianRepository.save(clinician);
        
        log.info("Successfully soft-deleted clinician: {} with ID: {}", clinician.getClinicianCode(), clinician.getId());
    }

    /**
     * Get clinician by ID.
     * 
     * @param id The clinician ID
     * @return The clinician response
     */
    @Transactional(readOnly = true)
    public ClinicianResponse.ClinicianItem getClinicianById(Long id) {
        log.info("Retrieving clinician with ID: {}", id);
        
        Clinician clinician = clinicianRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Clinician with ID " + id + " not found"));

        return mapToClinicianItem(clinician);
    }

    // ==========================================================================================================
    // DIAGNOSIS CODE MANAGEMENT
    // ==========================================================================================================

    /**
     * Create a new diagnosis code.
     * 
     * @param request The diagnosis code creation request
     * @return The created diagnosis code response
     */
    @Caching(evict = {
        @CacheEvict(value = "diagnosisCodes", allEntries = true),
        @CacheEvict(value = "diagnosisCodeByCodeAndSystem", allEntries = true)
    })
    public DiagnosisCodeResponse.DiagnosisCodeItem createDiagnosisCode(DiagnosisCodeRequest request) {
        log.info("Creating diagnosis code: {} in system: {}", request.getCode(), request.getCodeSystem());
        
        // Check if diagnosis code already exists
        if (diagnosisCodeRepository.existsByCodeAndCodeSystem(request.getCode(), request.getCodeSystem())) {
            throw new IllegalArgumentException("Diagnosis code " + request.getCode() + " in system " + request.getCodeSystem() + " already exists");
        }

        DiagnosisCode diagnosisCode = DiagnosisCode.builder()
                .code(request.getCode())
                .codeSystem(request.getCodeSystem())
                .description(request.getDescription())
                .status(request.getStatus())
                .build();

        DiagnosisCode savedDiagnosisCode = diagnosisCodeRepository.save(diagnosisCode);
        log.info("Successfully created diagnosis code: {} with ID: {}", savedDiagnosisCode.getCode(), savedDiagnosisCode.getId());

        return mapToDiagnosisCodeItem(savedDiagnosisCode);
    }

    /**
     * Update an existing diagnosis code.
     * 
     * @param id The diagnosis code ID
     * @param request The diagnosis code update request
     * @return The updated diagnosis code response
     */
    @Caching(evict = {
        @CacheEvict(value = "diagnosisCodes", allEntries = true),
        @CacheEvict(value = "diagnosisCodeByCodeAndSystem", allEntries = true)
    })
    public DiagnosisCodeResponse.DiagnosisCodeItem updateDiagnosisCode(Long id, DiagnosisCodeRequest request) {
        log.info("Updating diagnosis code with ID: {}", id);
        
        DiagnosisCode diagnosisCode = diagnosisCodeRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Diagnosis code with ID " + id + " not found"));

        // Check if code or system is being changed and if new combination already exists
        if ((!diagnosisCode.getCode().equals(request.getCode()) || 
             !diagnosisCode.getCodeSystem().equals(request.getCodeSystem())) && 
            diagnosisCodeRepository.existsByCodeAndCodeSystem(request.getCode(), request.getCodeSystem())) {
            throw new IllegalArgumentException("Diagnosis code " + request.getCode() + " in system " + request.getCodeSystem() + " already exists");
        }

        diagnosisCode.setCode(request.getCode());
        diagnosisCode.setCodeSystem(request.getCodeSystem());
        diagnosisCode.setDescription(request.getDescription());
        diagnosisCode.setStatus(request.getStatus());

        DiagnosisCode savedDiagnosisCode = diagnosisCodeRepository.save(diagnosisCode);
        log.info("Successfully updated diagnosis code: {} with ID: {}", savedDiagnosisCode.getCode(), savedDiagnosisCode.getId());

        return mapToDiagnosisCodeItem(savedDiagnosisCode);
    }

    /**
     * Delete a diagnosis code (soft delete).
     * 
     * @param id The diagnosis code ID
     */
    @Caching(evict = {
        @CacheEvict(value = "diagnosisCodes", allEntries = true),
        @CacheEvict(value = "diagnosisCodeByCodeAndSystem", allEntries = true)
    })
    public void deleteDiagnosisCode(Long id) {
        log.info("Deleting diagnosis code with ID: {}", id);
        
        DiagnosisCode diagnosisCode = diagnosisCodeRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Diagnosis code with ID " + id + " not found"));

        diagnosisCode.setStatus("INACTIVE");
        diagnosisCodeRepository.save(diagnosisCode);
        
        log.info("Successfully soft-deleted diagnosis code: {} with ID: {}", diagnosisCode.getCode(), diagnosisCode.getId());
    }

    /**
     * Get diagnosis code by ID.
     * 
     * @param id The diagnosis code ID
     * @return The diagnosis code response
     */
    @Transactional(readOnly = true)
    public DiagnosisCodeResponse.DiagnosisCodeItem getDiagnosisCodeById(Long id) {
        log.info("Retrieving diagnosis code with ID: {}", id);
        
        DiagnosisCode diagnosisCode = diagnosisCodeRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Diagnosis code with ID " + id + " not found"));

        return mapToDiagnosisCodeItem(diagnosisCode);
    }

    // ==========================================================================================================
    // ACTIVITY CODE MANAGEMENT
    // ==========================================================================================================

    /**
     * Create a new activity code.
     * 
     * @param request The activity code creation request
     * @return The created activity code response
     */
    @Caching(evict = {
        @CacheEvict(value = "activityCodes", allEntries = true),
        @CacheEvict(value = "activityCodeByCodeAndType", allEntries = true)
    })
    public ActivityCodeResponse.ActivityCodeItem createActivityCode(ActivityCodeRequest request) {
        log.info("Creating activity code: {} of type: {}", request.getCode(), request.getType());
        
        // Check if activity code already exists
        if (activityCodeRepository.existsByCodeAndType(request.getCode(), request.getType())) {
            throw new IllegalArgumentException("Activity code " + request.getCode() + " of type " + request.getType() + " already exists");
        }

        ActivityCode activityCode = ActivityCode.builder()
                .type(request.getType())
                .code(request.getCode())
                .codeSystem(request.getCodeSystem())
                .description(request.getDescription())
                .status(request.getStatus())
                .build();

        ActivityCode savedActivityCode = activityCodeRepository.save(activityCode);
        log.info("Successfully created activity code: {} with ID: {}", savedActivityCode.getCode(), savedActivityCode.getId());

        return mapToActivityCodeItem(savedActivityCode);
    }

    /**
     * Update an existing activity code.
     * 
     * @param id The activity code ID
     * @param request The activity code update request
     * @return The updated activity code response
     */
    @Caching(evict = {
        @CacheEvict(value = "activityCodes", allEntries = true),
        @CacheEvict(value = "activityCodeByCodeAndType", allEntries = true)
    })
    public ActivityCodeResponse.ActivityCodeItem updateActivityCode(Long id, ActivityCodeRequest request) {
        log.info("Updating activity code with ID: {}", id);
        
        ActivityCode activityCode = activityCodeRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Activity code with ID " + id + " not found"));

        // Check if code or type is being changed and if new combination already exists
        if ((!activityCode.getCode().equals(request.getCode()) || 
             !activityCode.getType().equals(request.getType())) && 
            activityCodeRepository.existsByCodeAndType(request.getCode(), request.getType())) {
            throw new IllegalArgumentException("Activity code " + request.getCode() + " of type " + request.getType() + " already exists");
        }

        activityCode.setType(request.getType());
        activityCode.setCode(request.getCode());
        activityCode.setCodeSystem(request.getCodeSystem());
        activityCode.setDescription(request.getDescription());
        activityCode.setStatus(request.getStatus());

        ActivityCode savedActivityCode = activityCodeRepository.save(activityCode);
        log.info("Successfully updated activity code: {} with ID: {}", savedActivityCode.getCode(), savedActivityCode.getId());

        return mapToActivityCodeItem(savedActivityCode);
    }

    /**
     * Delete an activity code (soft delete).
     * 
     * @param id The activity code ID
     */
    @Caching(evict = {
        @CacheEvict(value = "activityCodes", allEntries = true),
        @CacheEvict(value = "activityCodeByCodeAndType", allEntries = true)
    })
    public void deleteActivityCode(Long id) {
        log.info("Deleting activity code with ID: {}", id);
        
        ActivityCode activityCode = activityCodeRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Activity code with ID " + id + " not found"));

        activityCode.setStatus("INACTIVE");
        activityCodeRepository.save(activityCode);
        
        log.info("Successfully soft-deleted activity code: {} with ID: {}", activityCode.getCode(), activityCode.getId());
    }

    /**
     * Get activity code by ID.
     * 
     * @param id The activity code ID
     * @return The activity code response
     */
    @Transactional(readOnly = true)
    public ActivityCodeResponse.ActivityCodeItem getActivityCodeById(Long id) {
        log.info("Retrieving activity code with ID: {}", id);
        
        ActivityCode activityCode = activityCodeRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Activity code with ID " + id + " not found"));

        return mapToActivityCodeItem(activityCode);
    }

    // ==========================================================================================================
    // DENIAL CODE MANAGEMENT
    // ==========================================================================================================

    /**
     * Create a new denial code.
     * 
     * @param request The denial code creation request
     * @return The created denial code response
     */
    @Caching(evict = {
        @CacheEvict(value = "denialCodes", allEntries = true),
        @CacheEvict(value = "denialCodeByCode", allEntries = true)
    })
    public DenialCodeResponse.DenialCodeItem createDenialCode(DenialCodeRequest request) {
        log.info("Creating denial code: {}", request.getCode());
        
        // Check if denial code already exists
        if (denialCodeRepository.existsByCode(request.getCode())) {
            throw new IllegalArgumentException("Denial code " + request.getCode() + " already exists");
        }

        DenialCode denialCode = DenialCode.builder()
                .code(request.getCode())
                .description(request.getDescription())
                .payerCode(request.getPayerCode())
                .build();

        DenialCode savedDenialCode = denialCodeRepository.save(denialCode);
        log.info("Successfully created denial code: {} with ID: {}", savedDenialCode.getCode(), savedDenialCode.getId());

        return mapToDenialCodeItem(savedDenialCode);
    }

    /**
     * Update an existing denial code.
     * 
     * @param id The denial code ID
     * @param request The denial code update request
     * @return The updated denial code response
     */
    @Caching(evict = {
        @CacheEvict(value = "denialCodes", allEntries = true),
        @CacheEvict(value = "denialCodeByCode", allEntries = true)
    })
    public DenialCodeResponse.DenialCodeItem updateDenialCode(Long id, DenialCodeRequest request) {
        log.info("Updating denial code with ID: {}", id);
        
        DenialCode denialCode = denialCodeRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Denial code with ID " + id + " not found"));

        // Check if code is being changed and if new code already exists
        if (!denialCode.getCode().equals(request.getCode()) && 
            denialCodeRepository.existsByCode(request.getCode())) {
            throw new IllegalArgumentException("Denial code " + request.getCode() + " already exists");
        }

        denialCode.setCode(request.getCode());
        denialCode.setDescription(request.getDescription());
        denialCode.setPayerCode(request.getPayerCode());

        DenialCode savedDenialCode = denialCodeRepository.save(denialCode);
        log.info("Successfully updated denial code: {} with ID: {}", savedDenialCode.getCode(), savedDenialCode.getId());

        return mapToDenialCodeItem(savedDenialCode);
    }

    /**
     * Delete a denial code (hard delete).
     * 
     * @param id The denial code ID
     */
    @Caching(evict = {
        @CacheEvict(value = "denialCodes", allEntries = true),
        @CacheEvict(value = "denialCodeByCode", allEntries = true)
    })
    public void deleteDenialCode(Long id) {
        log.info("Deleting denial code with ID: {}", id);
        
        DenialCode denialCode = denialCodeRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Denial code with ID " + id + " not found"));

        denialCodeRepository.delete(denialCode);
        
        log.info("Successfully deleted denial code: {} with ID: {}", denialCode.getCode(), denialCode.getId());
    }

    /**
     * Get denial code by ID.
     * 
     * @param id The denial code ID
     * @return The denial code response
     */
    @Transactional(readOnly = true)
    public DenialCodeResponse.DenialCodeItem getDenialCodeById(Long id) {
        log.info("Retrieving denial code with ID: {}", id);
        
        DenialCode denialCode = denialCodeRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Denial code with ID " + id + " not found"));

        return mapToDenialCodeItem(denialCode);
    }

    // ==========================================================================================================
    // MAPPING METHODS
    // ==========================================================================================================

    private FacilityResponse mapToFacilityResponse(Facility facility) {
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
        
        FacilityResponse response = new FacilityResponse();
        response.setFacilities(List.of(item));
        return response;
    }

    private PayerResponse mapToPayerResponse(Payer payer) {
        PayerResponse.PayerItem item = new PayerResponse.PayerItem();
        item.setId(payer.getId());
        item.setPayerCode(payer.getPayerCode());
        item.setName(payer.getName());
        item.setDisplayName(payer.getDisplayName());
        item.setClassification(payer.getClassification());
        item.setStatus(payer.getStatus());
        item.setCreatedAt(payer.getCreatedAt());
        item.setUpdatedAt(payer.getUpdatedAt());
        
        PayerResponse response = new PayerResponse();
        response.setPayers(List.of(item));
        return response;
    }

    private ClinicianResponse mapToClinicianResponse(Clinician clinician) {
        ClinicianResponse.ClinicianItem item = new ClinicianResponse.ClinicianItem();
        item.setId(clinician.getId());
        item.setClinicianCode(clinician.getClinicianCode());
        item.setName(clinician.getName());
        item.setDisplayName(clinician.getDisplayName());
        item.setSpecialty(clinician.getSpecialty());
        item.setStatus(clinician.getStatus());
        item.setCreatedAt(clinician.getCreatedAt());
        item.setUpdatedAt(clinician.getUpdatedAt());
        
        ClinicianResponse response = new ClinicianResponse();
        response.setClinicians(List.of(item));
        return response;
    }

    private DiagnosisCodeResponse mapToDiagnosisCodeResponse(DiagnosisCode diagnosisCode) {
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
        
        DiagnosisCodeResponse response = new DiagnosisCodeResponse();
        response.setDiagnosisCodes(List.of(item));
        return response;
    }

    private ActivityCodeResponse mapToActivityCodeResponse(ActivityCode activityCode) {
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
        
        ActivityCodeResponse response = new ActivityCodeResponse();
        response.setActivityCodes(List.of(item));
        return response;
    }

    // ==========================================================================================================
    // MAPPING METHODS FOR INDIVIDUAL ITEMS
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
        item.setPayerCode(denialCode.getPayerCode());
        item.setFullCode(denialCode.getFullCode());
        item.setPayerSpecific(denialCode.isPayerSpecific());
        item.setGlobal(denialCode.isGlobal());
        item.setCreatedAt(denialCode.getCreatedAt());
        item.setUpdatedAt(denialCode.getUpdatedAt());
        
        // Set base fields
        item.setCode(denialCode.getCode());
        item.setName(denialCode.getDescription());
        item.setDisplayName(denialCode.getDisplayName());
        item.setStatus("ACTIVE"); // Denial codes don't have status, but base class expects it
        item.setCreatedAt(denialCode.getCreatedAt());
        item.setUpdatedAt(denialCode.getUpdatedAt());
        
        return item;
    }
}
