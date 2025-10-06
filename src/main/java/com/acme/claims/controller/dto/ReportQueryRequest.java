package com.acme.claims.controller.dto;

import com.acme.claims.security.ReportType;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Data
public class ReportQueryRequest {
    private ReportType reportType;
    private String tab; // for tabbed reports
    private String level; // for level-based reports (activity|claim)

    // Common filters
    private String facilityCode;
    private List<String> facilityCodes;
    private List<Long> facilityRefIds;

    private String payerCode;
    private List<String> payerCodes;
    private List<Long> payerRefIds;

    private String receiverCode;
    private List<String> receiverIds;

    private String clinicianCode;
    private List<String> clinicianIds;
    private List<Long> clinicianRefIds;

    private String claimId;
    private String patientId;
    private String cptCode;
    private String paymentReference;
    private List<String> denialCodes;
    private String denialFilter;
    private String encounterType;
    private String resubType;
    private String claimStatus;
    private String paymentStatus;

    private LocalDateTime fromDate;
    private LocalDateTime toDate;
    private Integer year;
    private Integer month;

    // Balance report specific
    private List<Long> claimKeyIds;
    private Boolean basedOnInitialNet;

    // Sorting & paging
    private String sortBy;
    private String sortDirection;
    private Integer page;
    private Integer size;

    // Fallback for any extras
    private Map<String, Object> extra;
}


