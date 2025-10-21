package com.acme.claims.controller.dto;

import com.acme.claims.security.ReportType;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import lombok.EqualsAndHashCode;

import jakarta.validation.constraints.*;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Request DTO for Remittances Resubmission Report
 * 
 * This DTO extends ReportQueryRequest with specific fields required for
 * the Remittances Resubmission report that aren't available in the base class.
 */
@Data
@EqualsAndHashCode(callSuper = true)
@Schema(description = "Request for Remittances Resubmission Report")
public class RemittancesResubmissionRequest extends ReportQueryRequest {
    
    @Schema(description = "Single facility ID filter", example = "FAC001")
    private String facilityId;
    
    @Size(max = 100, message = "Cannot filter by more than 100 facilities")
    @Schema(description = "List of facility IDs to filter by", 
            example = "[\"FAC001\", \"FAC002\"]")
    private List<String> facilityIds;
    
    @Size(max = 100, message = "Cannot filter by more than 100 payers")
    @Schema(description = "List of payer IDs to filter by", 
            example = "[\"PAY001\", \"PAY002\"]")
    private List<String> payerIds;
    
    @Size(max = 100, message = "Cannot filter by more than 100 receivers")
    @Schema(description = "List of receiver IDs to filter by", 
            example = "[\"RECV001\", \"RECV002\"]")
    private List<String> receiverIds;
    
    @Size(max = 100, message = "Cannot filter by more than 100 clinicians")
    @Schema(description = "List of clinician IDs to filter by", 
            example = "[\"CLIN001\", \"CLIN002\"]")
    private List<String> clinicianIds;
    
    @Schema(description = "Claim number filter", example = "CLM123456")
    private String claimNumber;
    
    @Schema(description = "CPT code filter", example = "99213")
    private String cptCode;
    
    @Schema(description = "Denial filter type", example = "rejected")
    private String denialFilter;
    
    @Schema(description = "Encounter type filter", example = "OUTPATIENT")
    private String encounterType;
    
    @Schema(description = "Level for level-based reports (activity or claim)", 
            example = "activity",
            allowableValues = {"activity", "claim"})
    private String level;
    
    @PastOrPresent(message = "From date cannot be in the future")
    @Schema(description = "Start date for filtering (ISO 8601 format)", 
            example = "2025-01-01T00:00:00")
    private LocalDateTime fromDate;
    
    @FutureOrPresent(message = "To date cannot be in the past")
    @Schema(description = "End date for filtering (ISO 8601 format)", 
            example = "2025-12-31T23:59:59")
    private LocalDateTime toDate;
    
    @Schema(description = "Column name to sort by", example = "encounter_start")
    private String orderBy;
    
    @Min(value = 0, message = "Page must be >= 0")
    @Schema(description = "Page number (0-based)", example = "0")
    private Integer page;
    
    @Min(value = 1, message = "Size must be >= 1")
    @Max(value = 1000, message = "Size cannot exceed 1000")
    @Schema(description = "Number of records per page", example = "50")
    private Integer size;
    
    @Size(max = 100, message = "Cannot filter by more than 100 facility reference IDs")
    @Schema(description = "List of facility reference IDs to filter by")
    private List<Long> facilityRefIds;
    
    @Size(max = 100, message = "Cannot filter by more than 100 payer reference IDs")
    @Schema(description = "List of payer reference IDs to filter by")
    private List<Long> payerRefIds;
    
    @Size(max = 100, message = "Cannot filter by more than 100 clinician reference IDs")
    @Schema(description = "List of clinician reference IDs to filter by")
    private List<Long> clinicianRefIds;
    
    /**
     * Constructor that sets the report type
     */
    public RemittancesResubmissionRequest() {
        super();
        this.setReportType(ReportType.REMITTANCES_RESUBMISSION);
    }
}
