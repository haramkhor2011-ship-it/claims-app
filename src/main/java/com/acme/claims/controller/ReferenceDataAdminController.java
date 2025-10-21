package com.acme.claims.controller;

import com.acme.claims.controller.dto.*;
import com.acme.claims.service.ReferenceDataAdminService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * REST Controller for administrative operations on reference data.
 * 
 * This controller provides CRUD operations for facility administrators
 * to manage reference data including facilities, payers, clinicians,
 * diagnosis codes, activity codes, and denial codes.
 * 
 * All endpoints require FACILITY_ADMIN role authorization.
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@RestController
@RequestMapping("/api/admin/reference-data")
@RequiredArgsConstructor
@Slf4j
@Tag(name = "Reference Data Admin", description = "Administrative operations for reference data management")
@PreAuthorize("hasRole('FACILITY_ADMIN')")
public class ReferenceDataAdminController {

    private final ReferenceDataAdminService referenceDataAdminService;

    // ==================== FACILITY OPERATIONS ====================

    /**
     * Create a new facility.
     * 
     * @param request The facility creation request
     * @return ResponseEntity with created facility
     */
    @PostMapping("/facilities")
    @Operation(summary = "Create facility", description = "Create a new facility")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "201", description = "Facility created successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = FacilityResponse.FacilityItem.class))),
        @ApiResponse(responseCode = "400", description = "Invalid request data"),
        @ApiResponse(responseCode = "409", description = "Facility code already exists"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<FacilityResponse.FacilityItem> createFacility(@Valid @RequestBody FacilityRequest request) {
        log.info("POST /api/admin/reference-data/facilities - Creating facility: {}", request.getFacilityCode());
        
        try {
            FacilityResponse.FacilityItem createdFacility = referenceDataAdminService.createFacility(request);
            return ResponseEntity.status(HttpStatus.CREATED).body(createdFacility);
        } catch (IllegalArgumentException e) {
            log.warn("Invalid facility data: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            log.error("Error creating facility: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /**
     * Update an existing facility.
     * 
     * @param id The facility ID
     * @param request The facility update request
     * @return ResponseEntity with updated facility
     */
    @PutMapping("/facilities/{id}")
    @Operation(summary = "Update facility", description = "Update an existing facility")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Facility updated successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = FacilityResponse.FacilityItem.class))),
        @ApiResponse(responseCode = "400", description = "Invalid request data"),
        @ApiResponse(responseCode = "404", description = "Facility not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<FacilityResponse.FacilityItem> updateFacility(
            @PathVariable Long id,
            @Valid @RequestBody FacilityRequest request) {
        log.info("PUT /api/admin/reference-data/facilities/{} - Updating facility", id);
        
        try {
            FacilityResponse.FacilityItem updatedFacility = referenceDataAdminService.updateFacility(id, request);
            return ResponseEntity.ok(updatedFacility);
        } catch (IllegalArgumentException e) {
            log.warn("Invalid facility data: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            log.error("Error updating facility: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /**
     * Delete a facility (soft delete).
     * 
     * @param id The facility ID
     * @return ResponseEntity with success message
     */
    @DeleteMapping("/facilities/{id}")
    @Operation(summary = "Delete facility", description = "Soft delete a facility by ID")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Facility deleted successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = String.class),
                        examples = @ExampleObject(value = "Facility deleted successfully"))),
        @ApiResponse(responseCode = "404", description = "Facility not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<String> deleteFacility(@PathVariable Long id) {
        log.info("DELETE /api/admin/reference-data/facilities/{}", id);
        
        try {
            referenceDataAdminService.deleteFacility(id);
            return ResponseEntity.ok("Facility deleted successfully");
        } catch (IllegalArgumentException e) {
            log.warn("Facility not found: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("Error deleting facility: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Error deleting facility: " + e.getMessage());
        }
    }

    /**
     * Get facility by ID.
     * 
     * @param id The facility ID
     * @return ResponseEntity with facility data
     */
    @GetMapping("/facilities/{id}")
    @Operation(summary = "Get facility by ID", description = "Retrieve a facility by its ID")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Facility retrieved successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = FacilityResponse.FacilityItem.class))),
        @ApiResponse(responseCode = "404", description = "Facility not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<FacilityResponse.FacilityItem> getFacility(@PathVariable Long id) {
        log.info("GET /api/admin/reference-data/facilities/{}", id);
        
        try {
            FacilityResponse.FacilityItem facility = referenceDataAdminService.getFacilityById(id);
            return ResponseEntity.ok(facility);
        } catch (IllegalArgumentException e) {
            log.warn("Facility not found: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("Error retrieving facility: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // ==================== PAYER OPERATIONS ====================

    /**
     * Create a new payer.
     * 
     * @param request The payer creation request
     * @return ResponseEntity with created payer
     */
    @PostMapping("/payers")
    @Operation(summary = "Create payer", description = "Create a new payer")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "201", description = "Payer created successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = PayerResponse.PayerItem.class))),
        @ApiResponse(responseCode = "400", description = "Invalid request data"),
        @ApiResponse(responseCode = "409", description = "Payer code already exists"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<PayerResponse.PayerItem> createPayer(@Valid @RequestBody PayerRequest request) {
        log.info("POST /api/admin/reference-data/payers - Creating payer: {}", request.getPayerCode());
        
        try {
            PayerResponse.PayerItem createdPayer = referenceDataAdminService.createPayer(request);
            return ResponseEntity.status(HttpStatus.CREATED).body(createdPayer);
        } catch (IllegalArgumentException e) {
            log.warn("Invalid payer data: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            log.error("Error creating payer: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /**
     * Update an existing payer.
     * 
     * @param id The payer ID
     * @param request The payer update request
     * @return ResponseEntity with updated payer
     */
    @PutMapping("/payers/{id}")
    @Operation(summary = "Update payer", description = "Update an existing payer")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Payer updated successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = PayerResponse.PayerItem.class))),
        @ApiResponse(responseCode = "400", description = "Invalid request data"),
        @ApiResponse(responseCode = "404", description = "Payer not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<PayerResponse.PayerItem> updatePayer(
            @PathVariable Long id,
            @Valid @RequestBody PayerRequest request) {
        log.info("PUT /api/admin/reference-data/payers/{} - Updating payer", id);
        
        try {
            PayerResponse.PayerItem updatedPayer = referenceDataAdminService.updatePayer(id, request);
            return ResponseEntity.ok(updatedPayer);
        } catch (IllegalArgumentException e) {
            log.warn("Invalid payer data: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            log.error("Error updating payer: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /**
     * Delete a payer (soft delete).
     * 
     * @param id The payer ID
     * @return ResponseEntity with success message
     */
    @DeleteMapping("/payers/{id}")
    @Operation(summary = "Delete payer", description = "Soft delete a payer by ID")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Payer deleted successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = String.class),
                        examples = @ExampleObject(value = "Payer deleted successfully"))),
        @ApiResponse(responseCode = "404", description = "Payer not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<String> deletePayer(@PathVariable Long id) {
        log.info("DELETE /api/admin/reference-data/payers/{}", id);
        
        try {
            referenceDataAdminService.deletePayer(id);
            return ResponseEntity.ok("Payer deleted successfully");
        } catch (IllegalArgumentException e) {
            log.warn("Payer not found: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("Error deleting payer: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Error deleting payer: " + e.getMessage());
        }
    }

    /**
     * Get payer by ID.
     * 
     * @param id The payer ID
     * @return ResponseEntity with payer data
     */
    @GetMapping("/payers/{id}")
    @Operation(summary = "Get payer by ID", description = "Retrieve a payer by its ID")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Payer retrieved successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = PayerResponse.PayerItem.class))),
        @ApiResponse(responseCode = "404", description = "Payer not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<PayerResponse.PayerItem> getPayer(@PathVariable Long id) {
        log.info("GET /api/admin/reference-data/payers/{}", id);
        
        try {
            PayerResponse.PayerItem payer = referenceDataAdminService.getPayerById(id);
            return ResponseEntity.ok(payer);
        } catch (IllegalArgumentException e) {
            log.warn("Payer not found: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("Error retrieving payer: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // ==================== CLINICIAN OPERATIONS ====================

    /**
     * Create a new clinician.
     * 
     * @param request The clinician creation request
     * @return ResponseEntity with created clinician
     */
    @PostMapping("/clinicians")
    @Operation(summary = "Create clinician", description = "Create a new clinician")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "201", description = "Clinician created successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = ClinicianResponse.ClinicianItem.class))),
        @ApiResponse(responseCode = "400", description = "Invalid request data"),
        @ApiResponse(responseCode = "409", description = "Clinician code already exists"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<ClinicianResponse.ClinicianItem> createClinician(@Valid @RequestBody ClinicianRequest request) {
        log.info("POST /api/admin/reference-data/clinicians - Creating clinician: {}", request.getClinicianCode());
        
        try {
            ClinicianResponse.ClinicianItem createdClinician = referenceDataAdminService.createClinician(request);
            return ResponseEntity.status(HttpStatus.CREATED).body(createdClinician);
        } catch (IllegalArgumentException e) {
            log.warn("Invalid clinician data: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            log.error("Error creating clinician: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /**
     * Update an existing clinician.
     * 
     * @param id The clinician ID
     * @param request The clinician update request
     * @return ResponseEntity with updated clinician
     */
    @PutMapping("/clinicians/{id}")
    @Operation(summary = "Update clinician", description = "Update an existing clinician")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Clinician updated successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = ClinicianResponse.ClinicianItem.class))),
        @ApiResponse(responseCode = "400", description = "Invalid request data"),
        @ApiResponse(responseCode = "404", description = "Clinician not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<ClinicianResponse.ClinicianItem> updateClinician(
            @PathVariable Long id,
            @Valid @RequestBody ClinicianRequest request) {
        log.info("PUT /api/admin/reference-data/clinicians/{} - Updating clinician", id);
        
        try {
            ClinicianResponse.ClinicianItem updatedClinician = referenceDataAdminService.updateClinician(id, request);
            return ResponseEntity.ok(updatedClinician);
        } catch (IllegalArgumentException e) {
            log.warn("Invalid clinician data: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            log.error("Error updating clinician: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /**
     * Delete a clinician (soft delete).
     * 
     * @param id The clinician ID
     * @return ResponseEntity with success message
     */
    @DeleteMapping("/clinicians/{id}")
    @Operation(summary = "Delete clinician", description = "Soft delete a clinician by ID")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Clinician deleted successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = String.class),
                        examples = @ExampleObject(value = "Clinician deleted successfully"))),
        @ApiResponse(responseCode = "404", description = "Clinician not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<String> deleteClinician(@PathVariable Long id) {
        log.info("DELETE /api/admin/reference-data/clinicians/{}", id);
        
        try {
            referenceDataAdminService.deleteClinician(id);
            return ResponseEntity.ok("Clinician deleted successfully");
        } catch (IllegalArgumentException e) {
            log.warn("Clinician not found: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("Error deleting clinician: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Error deleting clinician: " + e.getMessage());
        }
    }

    /**
     * Get clinician by ID.
     * 
     * @param id The clinician ID
     * @return ResponseEntity with clinician data
     */
    @GetMapping("/clinicians/{id}")
    @Operation(summary = "Get clinician by ID", description = "Retrieve a clinician by its ID")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Clinician retrieved successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = ClinicianResponse.ClinicianItem.class))),
        @ApiResponse(responseCode = "404", description = "Clinician not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<ClinicianResponse.ClinicianItem> getClinician(@PathVariable Long id) {
        log.info("GET /api/admin/reference-data/clinicians/{}", id);
        
        try {
            ClinicianResponse.ClinicianItem clinician = referenceDataAdminService.getClinicianById(id);
            return ResponseEntity.ok(clinician);
        } catch (IllegalArgumentException e) {
            log.warn("Clinician not found: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("Error retrieving clinician: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // ==================== DIAGNOSIS CODE OPERATIONS ====================

    /**
     * Create a new diagnosis code.
     * 
     * @param request The diagnosis code creation request
     * @return ResponseEntity with created diagnosis code
     */
    @PostMapping("/diagnosis-codes")
    @Operation(summary = "Create diagnosis code", description = "Create a new diagnosis code")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "201", description = "Diagnosis code created successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = DiagnosisCodeResponse.DiagnosisCodeItem.class))),
        @ApiResponse(responseCode = "400", description = "Invalid request data"),
        @ApiResponse(responseCode = "409", description = "Diagnosis code already exists"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<DiagnosisCodeResponse.DiagnosisCodeItem> createDiagnosisCode(@Valid @RequestBody DiagnosisCodeRequest request) {
        log.info("POST /api/admin/reference-data/diagnosis-codes - Creating diagnosis code: {}", request.getCode());
        
        try {
            DiagnosisCodeResponse.DiagnosisCodeItem createdDiagnosisCode = referenceDataAdminService.createDiagnosisCode(request);
            return ResponseEntity.status(HttpStatus.CREATED).body(createdDiagnosisCode);
        } catch (IllegalArgumentException e) {
            log.warn("Invalid diagnosis code data: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            log.error("Error creating diagnosis code: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /**
     * Update an existing diagnosis code.
     * 
     * @param id The diagnosis code ID
     * @param request The diagnosis code update request
     * @return ResponseEntity with updated diagnosis code
     */
    @PutMapping("/diagnosis-codes/{id}")
    @Operation(summary = "Update diagnosis code", description = "Update an existing diagnosis code")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Diagnosis code updated successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = DiagnosisCodeResponse.DiagnosisCodeItem.class))),
        @ApiResponse(responseCode = "400", description = "Invalid request data"),
        @ApiResponse(responseCode = "404", description = "Diagnosis code not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<DiagnosisCodeResponse.DiagnosisCodeItem> updateDiagnosisCode(
            @PathVariable Long id,
            @Valid @RequestBody DiagnosisCodeRequest request) {
        log.info("PUT /api/admin/reference-data/diagnosis-codes/{} - Updating diagnosis code", id);
        
        try {
            DiagnosisCodeResponse.DiagnosisCodeItem updatedDiagnosisCode = referenceDataAdminService.updateDiagnosisCode(id, request);
            return ResponseEntity.ok(updatedDiagnosisCode);
        } catch (IllegalArgumentException e) {
            log.warn("Invalid diagnosis code data: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            log.error("Error updating diagnosis code: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /**
     * Delete a diagnosis code (soft delete).
     * 
     * @param id The diagnosis code ID
     * @return ResponseEntity with success message
     */
    @DeleteMapping("/diagnosis-codes/{id}")
    @Operation(summary = "Delete diagnosis code", description = "Soft delete a diagnosis code by ID")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Diagnosis code deleted successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = String.class),
                        examples = @ExampleObject(value = "Diagnosis code deleted successfully"))),
        @ApiResponse(responseCode = "404", description = "Diagnosis code not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<String> deleteDiagnosisCode(@PathVariable Long id) {
        log.info("DELETE /api/admin/reference-data/diagnosis-codes/{}", id);
        
        try {
            referenceDataAdminService.deleteDiagnosisCode(id);
            return ResponseEntity.ok("Diagnosis code deleted successfully");
        } catch (IllegalArgumentException e) {
            log.warn("Diagnosis code not found: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("Error deleting diagnosis code: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Error deleting diagnosis code: " + e.getMessage());
        }
    }

    /**
     * Get diagnosis code by ID.
     * 
     * @param id The diagnosis code ID
     * @return ResponseEntity with diagnosis code data
     */
    @GetMapping("/diagnosis-codes/{id}")
    @Operation(summary = "Get diagnosis code by ID", description = "Retrieve a diagnosis code by its ID")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Diagnosis code retrieved successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = DiagnosisCodeResponse.DiagnosisCodeItem.class))),
        @ApiResponse(responseCode = "404", description = "Diagnosis code not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<DiagnosisCodeResponse.DiagnosisCodeItem> getDiagnosisCode(@PathVariable Long id) {
        log.info("GET /api/admin/reference-data/diagnosis-codes/{}", id);
        
        try {
            DiagnosisCodeResponse.DiagnosisCodeItem diagnosisCode = referenceDataAdminService.getDiagnosisCodeById(id);
            return ResponseEntity.ok(diagnosisCode);
        } catch (IllegalArgumentException e) {
            log.warn("Diagnosis code not found: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("Error retrieving diagnosis code: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // ==================== ACTIVITY CODE OPERATIONS ====================

    /**
     * Create a new activity code.
     * 
     * @param request The activity code creation request
     * @return ResponseEntity with created activity code
     */
    @PostMapping("/activity-codes")
    @Operation(summary = "Create activity code", description = "Create a new activity code")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "201", description = "Activity code created successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = ActivityCodeResponse.ActivityCodeItem.class))),
        @ApiResponse(responseCode = "400", description = "Invalid request data"),
        @ApiResponse(responseCode = "409", description = "Activity code already exists"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<ActivityCodeResponse.ActivityCodeItem> createActivityCode(@Valid @RequestBody ActivityCodeRequest request) {
        log.info("POST /api/admin/reference-data/activity-codes - Creating activity code: {}", request.getCode());
        
        try {
            ActivityCodeResponse.ActivityCodeItem createdActivityCode = referenceDataAdminService.createActivityCode(request);
            return ResponseEntity.status(HttpStatus.CREATED).body(createdActivityCode);
        } catch (IllegalArgumentException e) {
            log.warn("Invalid activity code data: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            log.error("Error creating activity code: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /**
     * Update an existing activity code.
     * 
     * @param id The activity code ID
     * @param request The activity code update request
     * @return ResponseEntity with updated activity code
     */
    @PutMapping("/activity-codes/{id}")
    @Operation(summary = "Update activity code", description = "Update an existing activity code")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Activity code updated successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = ActivityCodeResponse.ActivityCodeItem.class))),
        @ApiResponse(responseCode = "400", description = "Invalid request data"),
        @ApiResponse(responseCode = "404", description = "Activity code not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<ActivityCodeResponse.ActivityCodeItem> updateActivityCode(
            @PathVariable Long id,
            @Valid @RequestBody ActivityCodeRequest request) {
        log.info("PUT /api/admin/reference-data/activity-codes/{} - Updating activity code", id);
        
        try {
            ActivityCodeResponse.ActivityCodeItem updatedActivityCode = referenceDataAdminService.updateActivityCode(id, request);
            return ResponseEntity.ok(updatedActivityCode);
        } catch (IllegalArgumentException e) {
            log.warn("Invalid activity code data: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            log.error("Error updating activity code: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /**
     * Delete an activity code (soft delete).
     * 
     * @param id The activity code ID
     * @return ResponseEntity with success message
     */
    @DeleteMapping("/activity-codes/{id}")
    @Operation(summary = "Delete activity code", description = "Soft delete an activity code by ID")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Activity code deleted successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = String.class),
                        examples = @ExampleObject(value = "Activity code deleted successfully"))),
        @ApiResponse(responseCode = "404", description = "Activity code not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<String> deleteActivityCode(@PathVariable Long id) {
        log.info("DELETE /api/admin/reference-data/activity-codes/{}", id);
        
        try {
            referenceDataAdminService.deleteActivityCode(id);
            return ResponseEntity.ok("Activity code deleted successfully");
        } catch (IllegalArgumentException e) {
            log.warn("Activity code not found: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("Error deleting activity code: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Error deleting activity code: " + e.getMessage());
        }
    }

    /**
     * Get activity code by ID.
     * 
     * @param id The activity code ID
     * @return ResponseEntity with activity code data
     */
    @GetMapping("/activity-codes/{id}")
    @Operation(summary = "Get activity code by ID", description = "Retrieve an activity code by its ID")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Activity code retrieved successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = ActivityCodeResponse.ActivityCodeItem.class))),
        @ApiResponse(responseCode = "404", description = "Activity code not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<ActivityCodeResponse.ActivityCodeItem> getActivityCode(@PathVariable Long id) {
        log.info("GET /api/admin/reference-data/activity-codes/{}", id);
        
        try {
            ActivityCodeResponse.ActivityCodeItem activityCode = referenceDataAdminService.getActivityCodeById(id);
            return ResponseEntity.ok(activityCode);
        } catch (IllegalArgumentException e) {
            log.warn("Activity code not found: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("Error retrieving activity code: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // ==================== DENIAL CODE OPERATIONS ====================

    /**
     * Create a new denial code.
     * 
     * @param request The denial code creation request
     * @return ResponseEntity with created denial code
     */
    @PostMapping("/denial-codes")
    @Operation(summary = "Create denial code", description = "Create a new denial code")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "201", description = "Denial code created successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = DenialCodeResponse.DenialCodeItem.class))),
        @ApiResponse(responseCode = "400", description = "Invalid request data"),
        @ApiResponse(responseCode = "409", description = "Denial code already exists"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<DenialCodeResponse.DenialCodeItem> createDenialCode(@Valid @RequestBody DenialCodeRequest request) {
        log.info("POST /api/admin/reference-data/denial-codes - Creating denial code: {}", request.getCode());
        
        try {
            DenialCodeResponse.DenialCodeItem createdDenialCode = referenceDataAdminService.createDenialCode(request);
            return ResponseEntity.status(HttpStatus.CREATED).body(createdDenialCode);
        } catch (IllegalArgumentException e) {
            log.warn("Invalid denial code data: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            log.error("Error creating denial code: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /**
     * Update an existing denial code.
     * 
     * @param id The denial code ID
     * @param request The denial code update request
     * @return ResponseEntity with updated denial code
     */
    @PutMapping("/denial-codes/{id}")
    @Operation(summary = "Update denial code", description = "Update an existing denial code")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Denial code updated successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = DenialCodeResponse.DenialCodeItem.class))),
        @ApiResponse(responseCode = "400", description = "Invalid request data"),
        @ApiResponse(responseCode = "404", description = "Denial code not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<DenialCodeResponse.DenialCodeItem> updateDenialCode(
            @PathVariable Long id,
            @Valid @RequestBody DenialCodeRequest request) {
        log.info("PUT /api/admin/reference-data/denial-codes/{} - Updating denial code", id);
        
        try {
            DenialCodeResponse.DenialCodeItem updatedDenialCode = referenceDataAdminService.updateDenialCode(id, request);
            return ResponseEntity.ok(updatedDenialCode);
        } catch (IllegalArgumentException e) {
            log.warn("Invalid denial code data: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            log.error("Error updating denial code: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /**
     * Delete a denial code (hard delete).
     * 
     * @param id The denial code ID
     * @return ResponseEntity with success message
     */
    @DeleteMapping("/denial-codes/{id}")
    @Operation(summary = "Delete denial code", description = "Hard delete a denial code by ID")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Denial code deleted successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = String.class),
                        examples = @ExampleObject(value = "Denial code deleted successfully"))),
        @ApiResponse(responseCode = "404", description = "Denial code not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<String> deleteDenialCode(@PathVariable Long id) {
        log.info("DELETE /api/admin/reference-data/denial-codes/{}", id);
        
        try {
            referenceDataAdminService.deleteDenialCode(id);
            return ResponseEntity.ok("Denial code deleted successfully");
        } catch (IllegalArgumentException e) {
            log.warn("Denial code not found: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("Error deleting denial code: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Error deleting denial code: " + e.getMessage());
        }
    }

    /**
     * Get denial code by ID.
     * 
     * @param id The denial code ID
     * @return ResponseEntity with denial code data
     */
    @GetMapping("/denial-codes/{id}")
    @Operation(summary = "Get denial code by ID", description = "Retrieve a denial code by its ID")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Denial code retrieved successfully",
                content = @Content(mediaType = "application/json",
                        schema = @Schema(implementation = DenialCodeResponse.DenialCodeItem.class))),
        @ApiResponse(responseCode = "404", description = "Denial code not found"),
        @ApiResponse(responseCode = "500", description = "Internal server error")
    })
    public ResponseEntity<DenialCodeResponse.DenialCodeItem> getDenialCode(@PathVariable Long id) {
        log.info("GET /api/admin/reference-data/denial-codes/{}", id);
        
        try {
            DenialCodeResponse.DenialCodeItem denialCode = referenceDataAdminService.getDenialCodeById(id);
            return ResponseEntity.ok(denialCode);
        } catch (IllegalArgumentException e) {
            log.warn("Denial code not found: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("Error retrieving denial code: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}
