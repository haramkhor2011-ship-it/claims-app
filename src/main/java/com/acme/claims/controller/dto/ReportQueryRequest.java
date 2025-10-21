package com.acme.claims.controller.dto;

import com.acme.claims.security.ReportType;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

import jakarta.validation.constraints.*;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * Unified report query request with comprehensive filtering and pagination options.
 * 
 * This DTO serves as the single request model for all report endpoints,
 * providing a consistent interface for filtering, sorting, and pagination.
 * 
 * Features:
 * - Comprehensive validation annotations
 * - Support for all report types
 * - Flexible filtering options
 * - Pagination and sorting
 * - Swagger documentation
 * 
 * Example usage:
 * {
 *   "reportType": "BALANCE_AMOUNT_REPORT",
 *   "tab": "overall",
 *   "facilityCodes": ["FAC001", "FAC002"],
 *   "fromDate": "2025-01-01T00:00:00",
 *   "toDate": "2025-12-31T23:59:59",
 *   "page": 0,
 *   "size": 50,
 *   "sortBy": "aging_days",
 *   "sortDirection": "DESC"
 * }
 */
@Data
@Schema(description = "Unified report query request with filters and pagination")
public class ReportQueryRequest {
    @NotNull(message = "Report type is required")
    @Schema(description = "Type of report to retrieve", 
            required = true, 
            example = "BALANCE_AMOUNT_REPORT",
            allowableValues = {"BALANCE_AMOUNT_REPORT", "REJECTED_CLAIMS_REPORT", "CLAIM_DETAILS_WITH_ACTIVITY", 
                             "DOCTOR_DENIAL_REPORT", "REMITTANCES_RESUBMISSION", "CLAIM_SUMMARY_MONTHWISE", 
                             "REMITTANCE_ADVICE_PAYERWISE"})
    private ReportType reportType;
    
    @Schema(description = "Tab name for tabbed reports (e.g., 'summary', 'receiverPayer', 'claimWise')", 
            example = "summary")
    private String tab; // for tabbed reports
    
    @Schema(description = "Level for level-based reports (activity or claim)", 
            example = "activity",
            allowableValues = {"activity", "claim"})
    private String level; // for level-based reports (activity|claim)

    // Common filters
    @Schema(description = "Single facility code filter", example = "FAC001")
    private String facilityCode;
    
    @Size(max = 100, message = "Cannot filter by more than 100 facilities")
    @Schema(description = "List of facility codes to filter by", 
            example = "[\"FAC001\", \"FAC002\"]")
    private List<String> facilityCodes;
    
    @Size(max = 100, message = "Cannot filter by more than 100 facility reference IDs")
    @Schema(description = "List of facility reference IDs to filter by")
    private List<Long> facilityRefIds;

    @Schema(description = "Single payer code filter", example = "DHA")
    private String payerCode;
    
    @Size(max = 100, message = "Cannot filter by more than 100 payers")
    @Schema(description = "List of payer codes to filter by", 
            example = "[\"DHA\", \"ADNOC\"]")
    private List<String> payerCodes;
    
    @Size(max = 100, message = "Cannot filter by more than 100 payer reference IDs")
    @Schema(description = "List of payer reference IDs to filter by")
    private List<Long> payerRefIds;

    @Schema(description = "Single receiver code filter", example = "PROV001")
    private String receiverCode;
    
    @Size(max = 100, message = "Cannot filter by more than 100 receivers")
    @Schema(description = "List of receiver IDs to filter by", 
            example = "[\"PROV001\", \"PROV002\"]")
    private List<String> receiverIds;

    @Schema(description = "Single clinician code filter", example = "DR001")
    private String clinicianCode;
    
    @Size(max = 100, message = "Cannot filter by more than 100 clinicians")
    @Schema(description = "List of clinician IDs to filter by", 
            example = "[\"DR001\", \"DR002\"]")
    private List<String> clinicianIds;
    
    @Size(max = 100, message = "Cannot filter by more than 100 clinician reference IDs")
    @Schema(description = "List of clinician reference IDs to filter by")
    private List<Long> clinicianRefIds;

    @Schema(description = "Specific claim ID to filter by", example = "CLM123456")
    private String claimId;
    
    @Schema(description = "Patient ID to filter by", example = "PAT789")
    private String patientId;
    
    @Schema(description = "CPT code to filter by", example = "99213")
    private String cptCode;
    
    @Schema(description = "Payment reference to filter by", example = "PAYREF123")
    private String paymentReference;
    
    @Size(max = 50, message = "Cannot filter by more than 50 denial codes")
    @Schema(description = "List of denial codes to filter by", 
            example = "[\"CO-4\", \"CO-16\"]")
    private List<String> denialCodes;
    
    @Schema(description = "Denial filter type", example = "rejected")
    private String denialFilter;
    
    @Schema(description = "Encounter type to filter by", example = "OUTPATIENT")
    private String encounterType;
    
    @Schema(description = "Resubmission type to filter by", example = "CORRECTED")
    private String resubType;
    
    @Schema(description = "Claim status to filter by", example = "SUBMITTED")
    private String claimStatus;
    
    @Schema(description = "Payment status to filter by", example = "PAID")
    private String paymentStatus;

    @PastOrPresent(message = "From date cannot be in the future")
    @Schema(description = "Start date for filtering (ISO 8601 format)", 
            example = "2025-01-01T00:00:00",
            implementation = String.class)
    private LocalDateTime fromDate;
    
    @FutureOrPresent(message = "To date cannot be in the past")
    @Schema(description = "End date for filtering (ISO 8601 format)", 
            example = "2025-12-31T23:59:59",
            implementation = String.class)
    private LocalDateTime toDate;
    
    @Min(value = 1, message = "Year must be >= 1")
    @Max(value = 9999, message = "Year must be <= 9999")
    @Schema(description = "Year filter (1-9999)", example = "2025")
    private Integer year;
    
    @Min(value = 1, message = "Month must be between 1 and 12")
    @Max(value = 12, message = "Month must be between 1 and 12")
    @Schema(description = "Month filter (1-12)", example = "6")
    private Integer month;

    // Balance report specific
    @Size(max = 1000, message = "Cannot filter by more than 1000 claim key IDs")
    @Schema(description = "List of specific claim key IDs to filter by")
    private List<Long> claimKeyIds;
    
    @Schema(description = "Whether to base calculations on initial net amount", example = "true")
    private Boolean basedOnInitialNet;

    // Sorting & paging
    @Schema(description = "Column name to sort by", example = "aging_days")
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

    // Fallback for any extras
    @Schema(description = "Additional parameters for specific report types")
    private Map<String, Object> extra;
}


