package com.acme.claims.controller;

import com.acme.claims.controller.dto.*;
import com.acme.claims.service.ReferenceDataService;
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
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

/**
 * REST Controller for reference data lookup endpoints.
 * 
 * This controller provides read-only access to reference data
 * for UI rendering and dropdown population.
 * 
 * Features:
 * - Search and pagination for all reference data types
 * - Individual item lookup by code
 * - Cached responses for performance
 * - Proper error handling and validation
 * - Swagger/OpenAPI documentation
 * - Role-based access control
 * 
 * @author Claims System
 * @version 1.0
 * @since 2025-01-20
 */
@RestController
@RequestMapping("/api/v1/reference-data")
@RequiredArgsConstructor
@Slf4j
@Tag(name = "Reference Data", description = "Reference data lookup endpoints for UI rendering")
public class ReferenceDataController {

    private final ReferenceDataService referenceDataService;

    // ==========================================================================================================
    // FACILITY ENDPOINTS
    // ==========================================================================================================

    /**
     * Search facilities with pagination and filtering.
     * 
     * @param request The search request with pagination and filters
     * @return Paginated list of facilities
     */
    @GetMapping("/facilities")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'FACILITY_ADMIN', 'STAFF')")
    @Operation(
        summary = "Search facilities",
        description = "Search and retrieve facilities with pagination, filtering, and sorting"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Successfully retrieved facilities",
            content = @Content(schema = @Schema(implementation = ReferenceDataResponse.class),
                examples = @ExampleObject(value = """
                    {
                      "data": [
                        {
                          "id": 1,
                          "facilityCode": "FAC001",
                          "name": "Dubai Hospital",
                          "displayName": "FAC001 - Dubai Hospital",
                          "city": "Dubai",
                          "country": "UAE",
                          "status": "ACTIVE"
                        }
                      ],
                      "pagination": {
                        "page": 0,
                        "size": 10,
                        "totalElements": 1,
                        "totalPages": 1
                      }
                    }
                    """))),
        @ApiResponse(responseCode = "400", description = "Invalid request parameters"),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "403", description = "Forbidden")
    })
    public ResponseEntity<ReferenceDataResponse> searchFacilities(
            @Valid @Parameter(description = "Search and pagination parameters") ReferenceDataRequest request) {
        
        log.info("Searching facilities with request: {}", request);
        
        try {
            ReferenceDataResponse response = referenceDataService.searchFacilities(request);
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error searching facilities", e);
            throw e;
        }
    }

    /**
     * Get facility by code.
     * 
     * @param facilityCode The facility code
     * @return Facility details
     */
    @GetMapping("/facilities/code/{facilityCode}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'FACILITY_ADMIN', 'STAFF')")
    @Operation(
        summary = "Get facility by code",
        description = "Retrieve a specific facility by its unique facility code"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Successfully retrieved facility",
            content = @Content(schema = @Schema(implementation = FacilityResponse.class))),
        @ApiResponse(responseCode = "404", description = "Facility not found"),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "403", description = "Forbidden")
    })
    public ResponseEntity<FacilityResponse> getFacilityByCode(
            @Parameter(description = "Facility code", example = "FAC001")
            @PathVariable String facilityCode) {
        
        log.info("Retrieving facility by code: {}", facilityCode);
        
        try {
            FacilityResponse response = referenceDataService.getFacilityByCode(facilityCode);
            if (response == null) {
                log.warn("Facility not found: {}", facilityCode);
                return ResponseEntity.notFound().build();
            }
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error retrieving facility by code: {}", facilityCode, e);
            throw e;
        }
    }

    // ==========================================================================================================
    // PAYER ENDPOINTS
    // ==========================================================================================================

    /**
     * Search payers with pagination and filtering.
     * 
     * @param request The search request with pagination and filters
     * @return Paginated list of payers
     */
    @GetMapping("/payers")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'FACILITY_ADMIN', 'STAFF')")
    @Operation(
        summary = "Search payers",
        description = "Search and retrieve payers with pagination, filtering, and sorting"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Successfully retrieved payers",
            content = @Content(schema = @Schema(implementation = ReferenceDataResponse.class),
                examples = @ExampleObject(value = """
                    {
                      "data": [
                        {
                          "id": 1,
                          "payerCode": "DHA",
                          "name": "Dubai Health Authority",
                          "displayName": "DHA - Dubai Health Authority",
                          "classification": "GOVERNMENT",
                          "status": "ACTIVE"
                        }
                      ],
                      "pagination": {
                        "page": 0,
                        "size": 10,
                        "totalElements": 1,
                        "totalPages": 1
                      }
                    }
                    """))),
        @ApiResponse(responseCode = "400", description = "Invalid request parameters"),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "403", description = "Forbidden")
    })
    public ResponseEntity<ReferenceDataResponse> searchPayers(
            @Valid @Parameter(description = "Search and pagination parameters") ReferenceDataRequest request) {
        
        log.info("Searching payers with request: {}", request);
        
        try {
            ReferenceDataResponse response = referenceDataService.searchPayers(request);
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error searching payers", e);
            throw e;
        }
    }

    /**
     * Get payer by code.
     * 
     * @param payerCode The payer code
     * @return Payer details
     */
    @GetMapping("/payers/code/{payerCode}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'FACILITY_ADMIN', 'STAFF')")
    @Operation(
        summary = "Get payer by code",
        description = "Retrieve a specific payer by its unique payer code"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Successfully retrieved payer",
            content = @Content(schema = @Schema(implementation = PayerResponse.class))),
        @ApiResponse(responseCode = "404", description = "Payer not found"),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "403", description = "Forbidden")
    })
    public ResponseEntity<PayerResponse> getPayerByCode(
            @Parameter(description = "Payer code", example = "DHA")
            @PathVariable String payerCode) {
        
        log.info("Retrieving payer by code: {}", payerCode);
        
        try {
            PayerResponse response = referenceDataService.getPayerByCode(payerCode);
            if (response == null) {
                log.warn("Payer not found: {}", payerCode);
                return ResponseEntity.notFound().build();
            }
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error retrieving payer by code: {}", payerCode, e);
            throw e;
        }
    }

    // ==========================================================================================================
    // CLINICIAN ENDPOINTS
    // ==========================================================================================================

    /**
     * Search clinicians with pagination and filtering.
     * 
     * @param request The search request with pagination and filters
     * @return Paginated list of clinicians
     */
    @GetMapping("/clinicians")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'FACILITY_ADMIN', 'STAFF')")
    @Operation(
        summary = "Search clinicians",
        description = "Search and retrieve clinicians with pagination, filtering, and sorting"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Successfully retrieved clinicians",
            content = @Content(schema = @Schema(implementation = ReferenceDataResponse.class),
                examples = @ExampleObject(value = """
                    {
                      "data": [
                        {
                          "id": 1,
                          "clinicianCode": "DOC001",
                          "name": "Dr. John Smith",
                          "displayName": "DOC001 - Dr. John Smith",
                          "specialty": "CARDIOLOGY",
                          "status": "ACTIVE"
                        }
                      ],
                      "pagination": {
                        "page": 0,
                        "size": 10,
                        "totalElements": 1,
                        "totalPages": 1
                      }
                    }
                    """))),
        @ApiResponse(responseCode = "400", description = "Invalid request parameters"),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "403", description = "Forbidden")
    })
    public ResponseEntity<ReferenceDataResponse> searchClinicians(
            @Valid @Parameter(description = "Search and pagination parameters") ReferenceDataRequest request) {
        
        log.info("Searching clinicians with request: {}", request);
        
        try {
            ReferenceDataResponse response = referenceDataService.searchClinicians(request);
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error searching clinicians", e);
            throw e;
        }
    }

    /**
     * Get clinician by code.
     * 
     * @param clinicianCode The clinician code
     * @return Clinician details
     */
    @GetMapping("/clinicians/code/{clinicianCode}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'FACILITY_ADMIN', 'STAFF')")
    @Operation(
        summary = "Get clinician by code",
        description = "Retrieve a specific clinician by its unique clinician code"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Successfully retrieved clinician",
            content = @Content(schema = @Schema(implementation = ClinicianResponse.class))),
        @ApiResponse(responseCode = "404", description = "Clinician not found"),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "403", description = "Forbidden")
    })
    public ResponseEntity<ClinicianResponse> getClinicianByCode(
            @Parameter(description = "Clinician code", example = "DOC001")
            @PathVariable String clinicianCode) {
        
        log.info("Retrieving clinician by code: {}", clinicianCode);
        
        try {
            ClinicianResponse response = referenceDataService.getClinicianByCode(clinicianCode);
            if (response == null) {
                log.warn("Clinician not found: {}", clinicianCode);
                return ResponseEntity.notFound().build();
            }
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error retrieving clinician by code: {}", clinicianCode, e);
            throw e;
        }
    }

    // ==========================================================================================================
    // DIAGNOSIS CODE ENDPOINTS
    // ==========================================================================================================

    /**
     * Search diagnosis codes with pagination and filtering.
     * 
     * @param request The search request with pagination and filters
     * @return Paginated list of diagnosis codes
     */
    @GetMapping("/diagnosis-codes")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'FACILITY_ADMIN', 'STAFF')")
    @Operation(
        summary = "Search diagnosis codes",
        description = "Search and retrieve diagnosis codes with pagination, filtering, and sorting"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Successfully retrieved diagnosis codes",
            content = @Content(schema = @Schema(implementation = ReferenceDataResponse.class),
                examples = @ExampleObject(value = """
                    {
                      "data": [
                        {
                          "id": 1,
                          "code": "Z00.00",
                          "codeSystem": "ICD-10",
                          "description": "Encounter for general adult medical examination",
                          "displayName": "Z00.00 - Encounter for general adult medical examination",
                          "status": "ACTIVE"
                        }
                      ],
                      "pagination": {
                        "page": 0,
                        "size": 10,
                        "totalElements": 1,
                        "totalPages": 1
                      }
                    }
                    """))),
        @ApiResponse(responseCode = "400", description = "Invalid request parameters"),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "403", description = "Forbidden")
    })
    public ResponseEntity<ReferenceDataResponse> searchDiagnosisCodes(
            @Valid @Parameter(description = "Search and pagination parameters") ReferenceDataRequest request) {
        
        log.info("Searching diagnosis codes with request: {}", request);
        
        try {
            ReferenceDataResponse response = referenceDataService.searchDiagnosisCodes(request);
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error searching diagnosis codes", e);
            throw e;
        }
    }

    /**
     * Get diagnosis code by code.
     * Uses ICD-10 as the default code system.
     * 
     * @param code The diagnosis code
     * @return Diagnosis code details
     */
    @GetMapping("/diagnosis-codes/code/{code}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'FACILITY_ADMIN', 'STAFF')")
    @Operation(
        summary = "Get diagnosis code by code",
        description = "Retrieve a specific diagnosis code by its code (defaults to ICD-10 code system)"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Successfully retrieved diagnosis code",
            content = @Content(schema = @Schema(implementation = DiagnosisCodeResponse.class))),
        @ApiResponse(responseCode = "404", description = "Diagnosis code not found"),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "403", description = "Forbidden")
    })
    public ResponseEntity<DiagnosisCodeResponse> getDiagnosisCodeByCode(
            @Parameter(description = "Diagnosis code", example = "Z00.00")
            @PathVariable String code) {
        
        log.info("Retrieving diagnosis code by code: {} (default code system: ICD-10)", code);
        
        try {
            DiagnosisCodeResponse response = referenceDataService.getDiagnosisCodeByCode(code);
            if (response == null) {
                log.warn("Diagnosis code not found: {}", code);
                return ResponseEntity.notFound().build();
            }
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error retrieving diagnosis code by code: {}", code, e);
            throw e;
        }
    }

    // ==========================================================================================================
    // ACTIVITY CODE ENDPOINTS
    // ==========================================================================================================

    /**
     * Search activity codes with pagination and filtering.
     * 
     * @param request The search request with pagination and filters
     * @return Paginated list of activity codes
     */
    @GetMapping("/activity-codes")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'FACILITY_ADMIN', 'STAFF')")
    @Operation(
        summary = "Search activity codes",
        description = "Search and retrieve activity codes with pagination, filtering, and sorting"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Successfully retrieved activity codes",
            content = @Content(schema = @Schema(implementation = ReferenceDataResponse.class),
                examples = @ExampleObject(value = """
                    {
                      "data": [
                        {
                          "id": 1,
                          "type": "CPT",
                          "code": "99213",
                          "codeSystem": "LOCAL",
                          "description": "Office or other outpatient visit",
                          "displayName": "99213 - Office or other outpatient visit",
                          "status": "ACTIVE"
                        }
                      ],
                      "pagination": {
                        "page": 0,
                        "size": 10,
                        "totalElements": 1,
                        "totalPages": 1
                      }
                    }
                    """))),
        @ApiResponse(responseCode = "400", description = "Invalid request parameters"),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "403", description = "Forbidden")
    })
    public ResponseEntity<ReferenceDataResponse> searchActivityCodes(
            @Valid @Parameter(description = "Search and pagination parameters") ReferenceDataRequest request) {
        
        log.info("Searching activity codes with request: {}", request);
        
        try {
            ReferenceDataResponse response = referenceDataService.searchActivityCodes(request);
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error searching activity codes", e);
            throw e;
        }
    }

    /**
     * Get activity code by code.
     * Searches by code only, returns the first active match found.
     * 
     * @param code The activity code
     * @return Activity code details
     */
    @GetMapping("/activity-codes/code/{code}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'FACILITY_ADMIN', 'STAFF')")
    @Operation(
        summary = "Get activity code by code",
        description = "Retrieve an activity code by its code. Searches by code only and returns the first active match."
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Successfully retrieved activity code",
            content = @Content(schema = @Schema(implementation = ActivityCodeResponse.class))),
        @ApiResponse(responseCode = "404", description = "Activity code not found"),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "403", description = "Forbidden")
    })
    public ResponseEntity<ActivityCodeResponse> getActivityCodeByCode(
            @Parameter(description = "Activity code", example = "99213")
            @PathVariable String code) {
        
        log.info("Retrieving activity code by code: {}", code);
        
        try {
            ActivityCodeResponse response = referenceDataService.getActivityCodeByCode(code);
            if (response == null) {
                log.warn("Activity code not found: {}", code);
                return ResponseEntity.notFound().build();
            }
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error retrieving activity code by code: {}", code, e);
            throw e;
        }
    }

    // ==========================================================================================================
    // DENIAL CODE ENDPOINTS
    // ==========================================================================================================

    /**
     * Search denial codes with pagination and filtering.
     * 
     * @param request The search request with pagination and filters
     * @return Paginated list of denial codes
     */
    @GetMapping("/denial-codes")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'FACILITY_ADMIN', 'STAFF')")
    @Operation(
        summary = "Search denial codes",
        description = "Search and retrieve denial codes with pagination, filtering, and sorting"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Successfully retrieved denial codes",
            content = @Content(schema = @Schema(implementation = ReferenceDataResponse.class),
                examples = @ExampleObject(value = """
                    {
                      "data": [
                        {
                          "id": 1,
                          "code": "CO-45",
                          "description": "Claim/service denied",
                          "displayName": "CO-45 - Claim/service denied",
                          "payerCode": "DHA",
                          "status": "ACTIVE"
                        }
                      ],
                      "pagination": {
                        "page": 0,
                        "size": 10,
                        "totalElements": 1,
                        "totalPages": 1
                      }
                    }
                    """))),
        @ApiResponse(responseCode = "400", description = "Invalid request parameters"),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "403", description = "Forbidden")
    })
    public ResponseEntity<ReferenceDataResponse> searchDenialCodes(
            @Valid @Parameter(description = "Search and pagination parameters") ReferenceDataRequest request) {
        
        log.info("Searching denial codes with request: {}", request);
        
        try {
            ReferenceDataResponse response = referenceDataService.searchDenialCodes(request);
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error searching denial codes", e);
            throw e;
        }
    }

    /**
     * Get denial code by code.
     * 
     * @param code The denial code
     * @return Denial code details
     */
    @GetMapping("/denial-codes/code/{code}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'FACILITY_ADMIN', 'STAFF')")
    @Operation(
        summary = "Get denial code by code",
        description = "Retrieve a specific denial code by its unique code"
    )
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Successfully retrieved denial code",
            content = @Content(schema = @Schema(implementation = DenialCodeResponse.class))),
        @ApiResponse(responseCode = "404", description = "Denial code not found"),
        @ApiResponse(responseCode = "401", description = "Unauthorized"),
        @ApiResponse(responseCode = "403", description = "Forbidden")
    })
    public ResponseEntity<DenialCodeResponse> getDenialCodeByCode(
            @Parameter(description = "Denial code", example = "CO-45")
            @PathVariable String code) {
        
        log.info("Retrieving denial code by code: {}", code);
        
        try {
            DenialCodeResponse response = referenceDataService.getDenialCodeByCode(code);
            if (response == null) {
                log.warn("Denial code not found: {}", code);
                return ResponseEntity.notFound().build();
            }
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Error retrieving denial code by code: {}", code, e);
            throw e;
        }
    }
}
