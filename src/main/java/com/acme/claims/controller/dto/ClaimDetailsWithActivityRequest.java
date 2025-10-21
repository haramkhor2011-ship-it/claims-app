package com.acme.claims.controller.dto;

import com.acme.claims.security.ReportType;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import lombok.EqualsAndHashCode;

import jakarta.validation.constraints.*;
import java.time.LocalDateTime;
import java.util.Map;

/**
 * Request DTO for Claim Details with Activity Report
 * 
 * This DTO extends ReportQueryRequest with specific fields required for
 * the Claim Details with Activity report that aren't available in the base class.
 */
@Data
@EqualsAndHashCode(callSuper = true)
@Schema(description = "Request for Claim Details with Activity Report")
public class ClaimDetailsWithActivityRequest extends ReportQueryRequest {
    
    @Schema(description = "Receiver ID filter (specific to this report)", example = "RECV001")
    private String receiverId;
    
    @Schema(description = "Clinician filter (specific to this report)", example = "DR001")
    private String clinician;
    
    @Schema(description = "Member ID filter (specific to this report)", example = "MEM123")
    private String memberId;
    
    @Schema(description = "Resubmission type filter", example = "CORRECTED")
    private String resubType;
    
    @Schema(description = "Claim status filter", example = "SUBMITTED")
    private String claimStatus;
    
    @Schema(description = "Payment status filter", example = "PAID")
    private String paymentStatus;
    
    @Schema(description = "CPT code filter", example = "99213")
    private String cptCode;
    
    @Schema(description = "Patient ID filter", example = "PAT789")
    private String patientId;
    
    @Schema(description = "Encounter type filter", example = "OUTPATIENT")
    private String encounterType;
    
    @Schema(description = "Denial code filter", example = "CO-4")
    private String denialCode;
    
    @Schema(description = "Facility code filter", example = "FAC001")
    private String facilityCode;
    
    @Schema(description = "Payer code filter", example = "DHA")
    private String payerCode;
    
    @Schema(description = "Claim ID filter", example = "CLM123456")
    private String claimId;
    
    @PastOrPresent(message = "From date cannot be in the future")
    @Schema(description = "Start date for filtering (ISO 8601 format)", 
            example = "2025-01-01T00:00:00")
    private LocalDateTime fromDate;
    
    @FutureOrPresent(message = "To date cannot be in the past")
    @Schema(description = "End date for filtering (ISO 8601 format)", 
            example = "2025-12-31T23:59:59")
    private LocalDateTime toDate;
    
    @Schema(description = "Column name to sort by", example = "submission_date")
    private String sortBy;
    
    @Pattern(regexp = "^(ASC|DESC)$", message = "Sort direction must be ASC or DESC")
    @Schema(description = "Sort direction", 
            example = "DESC",
            allowableValues = {"ASC", "DESC"})
    private String sortDirection;
    
    @Min(value = 0, message = "Page must be >= 0")
    @Schema(description = "Page number (0-based)", example = "0")
    private Integer page;
    
    @Min(value = 1, message = "Size must be >= 1")
    @Max(value = 1000, message = "Size cannot exceed 1000")
    @Schema(description = "Number of records per page", example = "50")
    private Integer size;
    
    @Schema(description = "Additional parameters for specific report types")
    private Map<String, Object> extra;
    
    /**
     * Constructor that sets the report type
     */
    public ClaimDetailsWithActivityRequest() {
        super();
        this.setReportType(ReportType.CLAIM_DETAILS_WITH_ACTIVITY);
    }
}
