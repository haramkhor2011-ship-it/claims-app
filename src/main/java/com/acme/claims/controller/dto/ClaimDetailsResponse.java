package com.acme.claims.controller.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * Comprehensive response DTO for claim details endpoint.
 * 
 * This DTO provides a structured response for the claim details API,
 * containing all information related to a specific claim in a format
 * optimized for UI rendering.
 * 
 * Features:
 * - Basic claim information
 * - Encounter details
 * - Diagnosis information
 * - Activities/procedures
 * - Remittance information
 * - Claim timeline/events
 * - Attachments
 * - Transaction types
 * - Metadata for UI rendering
 * 
 * Example JSON:
 * {
 *   "claimId": "CLM001",
 *   "submission": {
 *     "fileName": "submission_batch_001.xml",
 *     "ingestionFileId": 123,
 *     "submissionDate": "2024-01-10T09:00:00Z",
 *     "claimInfo": {
 *       "claimId": "CLM001",
 *       "payerId": "DHA",
 *       "providerId": "PROV001",
 *       "netAmount": 1500.00,
 *       "submissionDate": "2024-01-10T09:00:00Z"
 *     },
 *     "encounterInfo": {
 *       "facilityId": "FAC001",
 *       "encounterType": "OUTPATIENT",
 *       "startDate": "2024-01-10T08:00:00Z"
 *     },
 *     "diagnosisInfo": [
 *       {
 *         "diagnosisCode": "Z00.00",
 *         "diagnosisType": "Principal",
 *         "diagnosisDescription": "Encounter for general adult medical examination"
 *       }
 *     ],
 *     "activitiesInfo": [
 *       {
 *         "activityCode": "99213",
 *         "netAmount": 150.00,
 *         "quantity": 1.0,
 *         "clinicianName": "Dr. Smith"
 *       }
 *     ],
 *     "attachments": [
 *       {
 *         "fileName": "claim.pdf",
 *         "createdAt": "2024-01-10T09:00:00Z",
 *         "mimeType": "application/pdf"
 *       }
 *     ]
 *   },
 *   "resubmissions": [
 *     {
 *       "fileName": "resubmission_batch_002.xml",
 *       "ingestionFileId": 145,
 *       "claimEventId": 567,
 *       "resubmissionDate": "2024-01-20T10:00:00Z",
 *       "resubmissionType": "CORRECTED",
 *       "resubmissionComment": "Corrected diagnosis code",
 *       "activitiesInfo": [
 *         {
 *           "activityCode": "99213",
 *           "netAmount": 150.00,
 *           "quantity": 1.0,
 *           "clinicianName": "Dr. Smith"
 *         }
 *       ],
 *       "attachments": []
 *     }
 *   ],
 *   "remittances": [
 *     {
 *       "fileName": "remittance_batch_003.xml",
 *       "ingestionFileId": 178,
 *       "remittanceId": 89,
 *       "remittanceClaimId": 234,
 *       "remittanceDate": "2024-01-25T14:30:00Z",
 *       "paymentReference": "PAY-2024-001",
 *       "settlementDate": "2024-01-25T00:00:00Z",
 *       "denialCode": null,
 *       "activities": [
 *         {
 *           "activityId": "ACT001",
 *           "paymentAmount": 150.00,
 *           "denialCode": null
 *         }
 *       ],
 *       "attachments": []
 *     }
 *   ],
 *   "claimTimeline": [
 *     {
 *       "eventTime": "2024-01-10T09:00:00Z",
 *       "eventType": "Submission",
 *       "currentStatus": 1
 *     }
 *   ],
 *   "metadata": {
 *     "user": "john.doe",
 *     "userId": 123,
 *     "timestamp": "2025-10-20T10:30:45",
 *     "correlationId": "abc123-def456"
 *   }
 * }
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
@Schema(description = "Comprehensive claim details response")
public class ClaimDetailsResponse {
    
    @Schema(description = "The claim ID being requested", example = "CLM001")
    private String claimId;
    
    @Schema(description = "Original submission data")
    private SubmissionData submission;
    
    @Schema(description = "List of resubmissions ordered by event_time")
    private List<ResubmissionData> resubmissions;
    
    @Schema(description = "List of remittances ordered by event_time")
    private List<RemittanceData> remittances;
    
    @Schema(description = "Claim timeline/events (kept for backward compatibility)")
    private List<ClaimTimelineEvent> claimTimeline;
    
    @Schema(description = "Response metadata")
    private ClaimDetailsMetadata metadata;
    
    /**
     * Basic claim information DTO
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @Schema(description = "Basic claim information")
    public static class ClaimBasicInfo {
        
        @Schema(description = "Claim ID", example = "CLM001")
        private String claimId;
        
        @Schema(description = "Internal claim database ID", example = "12345")
        private Long claimDbId;
        
        @Schema(description = "Payer ID", example = "DHA")
        private String payerId;
        
        @Schema(description = "Provider ID", example = "PROV001")
        private String providerId;
        
        @Schema(description = "Member ID", example = "MEM123456")
        private String memberId;
        
        @Schema(description = "Emirates ID number", example = "784-1234-5678901-2")
        private String emiratesIdNumber;
        
        @Schema(description = "Gross amount", example = "2000.00")
        private BigDecimal grossAmount;
        
        @Schema(description = "Patient share amount", example = "200.00")
        private BigDecimal patientShare;
        
        @Schema(description = "Net amount", example = "1500.00")
        private BigDecimal netAmount;
        
        @Schema(description = "Comments", example = "Routine checkup")
        private String comments;
        
        @Schema(description = "Submission date", example = "2024-01-10T09:00:00Z")
        private LocalDateTime submissionDate;
        
        @Schema(description = "Submission ID", example = "12345")
        private Long submissionId;
        
        @Schema(description = "Provider name", example = "City Hospital")
        private String providerName;
        
        @Schema(description = "Provider code", example = "PROV001")
        private String providerCode;
        
        @Schema(description = "Payer name", example = "Dubai Health Authority")
        private String payerName;
        
        @Schema(description = "Payer code", example = "DHA")
        private String payerCode;
    }
    
    /**
     * Encounter information DTO
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @Schema(description = "Encounter information")
    public static class EncounterInfo {
        
        @Schema(description = "Encounter ID", example = "12345")
        private Long encounterId;
        
        @Schema(description = "Facility ID", example = "FAC001")
        private String facilityId;
        
        @Schema(description = "Encounter type", example = "OUTPATIENT")
        private String encounterType;
        
        @Schema(description = "Patient ID", example = "PAT123456")
        private String patientId;
        
        @Schema(description = "Start date", example = "2024-01-10T08:00:00Z")
        private LocalDateTime startDate;
        
        @Schema(description = "End date", example = "2024-01-10T10:00:00Z")
        private LocalDateTime endDate;
        
        @Schema(description = "Start type", example = "SCHEDULED")
        private String startType;
        
        @Schema(description = "End type", example = "DISCHARGE")
        private String endType;
        
        @Schema(description = "Transfer source", example = "EMERGENCY")
        private String transferSource;
        
        @Schema(description = "Transfer destination", example = "WARD_A")
        private String transferDestination;
        
        @Schema(description = "Facility name", example = "City Hospital")
        private String facilityName;
        
        @Schema(description = "Facility code", example = "FAC001")
        private String facilityCode;
    }
    
    /**
     * Diagnosis information DTO
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @Schema(description = "Diagnosis information")
    public static class DiagnosisInfo {
        
        @Schema(description = "Diagnosis ID", example = "12345")
        private Long diagnosisId;
        
        @Schema(description = "Diagnosis type", example = "Principal")
        private String diagnosisType;
        
        @Schema(description = "Diagnosis code", example = "Z00.00")
        private String diagnosisCode;
        
        @Schema(description = "Diagnosis description", example = "Encounter for general adult medical examination")
        private String diagnosisDescription;
    }
    
    /**
     * Activity information DTO
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @Schema(description = "Activity/procedure information")
    public static class ActivityInfo {
        
        @Schema(description = "Activity ID", example = "12345")
        private Long activityId;
        
        @Schema(description = "Activity number", example = "ACT001")
        private String activityNumber;
        
        @Schema(description = "Start date", example = "2024-01-10T08:30:00Z")
        private LocalDateTime startDate;
        
        @Schema(description = "Activity type", example = "PROCEDURE")
        private String activityType;
        
        @Schema(description = "Activity code", example = "99213")
        private String activityCode;
        
        @Schema(description = "Quantity", example = "1.0")
        private BigDecimal quantity;
        
        @Schema(description = "Net amount", example = "150.00")
        private BigDecimal netAmount;
        
        @Schema(description = "Clinician code", example = "CLIN001")
        private String clinician;
        
        @Schema(description = "Prior authorization ID", example = "PA123456")
        private String priorAuthorizationId;
        
        @Schema(description = "Clinician name", example = "Dr. Smith")
        private String clinicianName;
        
        @Schema(description = "Clinician specialty", example = "Internal Medicine")
        private String clinicianSpecialty;
        
        @Schema(description = "Activity description", example = "Office or other outpatient visit")
        private String activityDescription;
    }
    
    /**
     * Remittance information DTO
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @Schema(description = "Remittance information")
    public static class RemittanceInfo {
        
        @Schema(description = "Remittance claim ID", example = "12345")
        private Long remittanceClaimId;
        
        @Schema(description = "Remittance payer ID", example = "DHA")
        private String remittancePayerId;
        
        @Schema(description = "Remittance provider ID", example = "PROV001")
        private String remittanceProviderId;
        
        @Schema(description = "Denial code", example = "CO-4")
        private String denialCode;
        
        @Schema(description = "Payment reference", example = "REM001")
        private String paymentReference;
        
        @Schema(description = "Settlement date", example = "2024-01-15T10:30:00Z")
        private LocalDateTime settlementDate;
        
        @Schema(description = "Remittance date", example = "2024-01-15T10:30:00Z")
        private LocalDateTime remittanceDate;
        
        @Schema(description = "Remittance ID", example = "12345")
        private Long remittanceId;
        
        @Schema(description = "List of remittance activities")
        private List<RemittanceActivityInfo> remittanceActivities;
    }
    
    /**
     * Remittance activity information DTO
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @Schema(description = "Remittance activity information")
    public static class RemittanceActivityInfo {
        
        @Schema(description = "Remittance activity ID", example = "12345")
        private Long remittanceActivityId;
        
        @Schema(description = "Activity ID", example = "ACT001")
        private String activityId;
        
        @Schema(description = "Start date", example = "2024-01-10T08:30:00Z")
        private LocalDateTime startDate;
        
        @Schema(description = "Activity type", example = "PROCEDURE")
        private String activityType;
        
        @Schema(description = "Activity code", example = "99213")
        private String activityCode;
        
        @Schema(description = "Quantity", example = "1.0")
        private BigDecimal quantity;
        
        @Schema(description = "Net amount", example = "150.00")
        private BigDecimal netAmount;
        
        @Schema(description = "List price", example = "200.00")
        private BigDecimal listPrice;
        
        @Schema(description = "Gross amount", example = "200.00")
        private BigDecimal grossAmount;
        
        @Schema(description = "Patient share", example = "20.00")
        private BigDecimal patientShare;
        
        @Schema(description = "Payment amount", example = "150.00")
        private BigDecimal paymentAmount;
        
        @Schema(description = "Denial code", example = "CO-4")
        private String denialCode;
        
        @Schema(description = "Clinician", example = "CLIN001")
        private String clinician;
    }
    
    /**
     * Claim timeline event DTO
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @Schema(description = "Claim timeline event")
    public static class ClaimTimelineEvent {
        
        @Schema(description = "Event ID", example = "12345")
        private Long eventId;
        
        @Schema(description = "Event time", example = "2024-01-10T09:00:00Z")
        private LocalDateTime eventTime;
        
        @Schema(description = "Event type description", example = "Submission")
        private String eventType;
        
        @Schema(description = "Submission ID", example = "12345")
        private Long submissionId;
        
        @Schema(description = "Remittance ID", example = "12345")
        private Long remittanceId;
        
        @Schema(description = "Current status", example = "1")
        private Integer currentStatus;
        
        @Schema(description = "Status time", example = "2024-01-10T09:00:00Z")
        private LocalDateTime statusTime;
        
        @Schema(description = "Resubmission type", example = "CORRECTED")
        private String resubmissionType;
        
        @Schema(description = "Resubmission comment", example = "Corrected diagnosis code")
        private String resubmissionComment;
    }
    
    /**
     * Attachment information DTO
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @Schema(description = "Attachment information")
    public static class AttachmentInfo {
        
        @Schema(description = "Attachment ID", example = "12345")
        private Long attachmentId;
        
        @Schema(description = "File name", example = "claim.pdf")
        private String fileName;
        
        @Schema(description = "MIME type", example = "application/pdf")
        private String mimeType;
        
        @Schema(description = "Data length in bytes", example = "1024000")
        private Integer dataLength;
        
        @Schema(description = "Created date", example = "2024-01-10T09:00:00Z")
        private LocalDateTime createdAt;
        
        @Schema(description = "Attachment event time", example = "2024-01-10T09:00:00Z")
        private LocalDateTime attachmentEventTime;
        
        @Schema(description = "Attachment event type", example = "Submission")
        private String attachmentEventType;
    }
    
    /**
     * Transaction type DTO
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @Schema(description = "Transaction type information")
    public static class TransactionType {
        
        @Schema(description = "Transaction ID", example = "12345")
        private Long transactionId;
        
        @Schema(description = "Event time", example = "2024-01-10T09:00:00Z")
        private LocalDateTime eventTime;
        
        @Schema(description = "Event type", example = "1")
        private Integer eventType;
        
        @Schema(description = "Transaction type", example = "Initial Submission")
        private String transactionType;
        
        @Schema(description = "Transaction description", example = "First time claim submission")
        private String transactionDescription;
        
        @Schema(description = "Submission ID", example = "12345")
        private Long submissionId;
        
        @Schema(description = "Remittance ID", example = "12345")
        private Long remittanceId;
        
        @Schema(description = "Resubmission type", example = "CORRECTED")
        private String resubmissionType;
        
        @Schema(description = "Resubmission comment", example = "Corrected diagnosis code")
        private String resubmissionComment;
    }
    
    /**
     * Claim details metadata DTO
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @Schema(description = "Claim details response metadata")
    public static class ClaimDetailsMetadata {
        
        @Schema(description = "Username of the user who requested the claim details", example = "john.doe")
        private String user;
        
        @Schema(description = "User ID of the user who requested the claim details", example = "123")
        private Long userId;
        
        @Schema(description = "Timestamp when the response was generated", example = "2025-10-20T10:30:45")
        private LocalDateTime timestamp;
        
        @Schema(description = "Correlation ID for request tracing", example = "abc123-def456-789ghi")
        private String correlationId;
        
        @Schema(description = "Execution time in milliseconds", example = "234")
        private Long executionTimeMs;
        
    @Schema(description = "Additional metadata for UI rendering")
    private Map<String, Object> additionalMetadata;
}

/**
 * Submission data DTO - contains original submission information
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
@Schema(description = "Original submission data")
public static class SubmissionData {
    
    @Schema(description = "File name from ingestion_file", example = "submission_batch_001.xml")
    private String fileName;
    
    @Schema(description = "Ingestion file ID", example = "123")
    private Long ingestionFileId;
    
    @Schema(description = "Submission date", example = "2024-01-10T09:00:00Z")
    private LocalDateTime submissionDate;
    
    @Schema(description = "Basic claim information")
    private ClaimBasicInfo claimInfo;
    
    @Schema(description = "Encounter information")
    private EncounterInfo encounterInfo;
    
    @Schema(description = "List of diagnosis information")
    private List<DiagnosisInfo> diagnosisInfo;
    
    @Schema(description = "List of activities/procedures")
    private List<ActivityInfo> activitiesInfo;
    
    @Schema(description = "List of attachments for this submission")
    private List<AttachmentInfo> attachments;
}

/**
 * Resubmission data DTO - contains resubmission information with activity snapshots
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
@Schema(description = "Resubmission data")
public static class ResubmissionData {
    
    @Schema(description = "File name from ingestion_file", example = "resubmission_batch_002.xml")
    private String fileName;
    
    @Schema(description = "Ingestion file ID", example = "145")
    private Long ingestionFileId;
    
    @Schema(description = "Claim event ID", example = "567")
    private Long claimEventId;
    
    @Schema(description = "Resubmission date", example = "2024-01-20T10:00:00Z")
    private LocalDateTime resubmissionDate;
    
    @Schema(description = "Resubmission type", example = "CORRECTED")
    private String resubmissionType;
    
    @Schema(description = "Resubmission comment", example = "Corrected diagnosis code")
    private String resubmissionComment;
    
    @Schema(description = "List of activities at resubmission time (from snapshots)")
    private List<ActivityInfo> activitiesInfo;
    
    @Schema(description = "List of attachments for this resubmission")
    private List<AttachmentInfo> attachments;
}

/**
 * Remittance data DTO - contains remittance information with payment details
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
@Schema(description = "Remittance data")
public static class RemittanceData {
    
    @Schema(description = "File name from ingestion_file", example = "remittance_batch_003.xml")
    private String fileName;
    
    @Schema(description = "Ingestion file ID", example = "178")
    private Long ingestionFileId;
    
    @Schema(description = "Remittance ID", example = "89")
    private Long remittanceId;
    
    @Schema(description = "Remittance claim ID", example = "234")
    private Long remittanceClaimId;
    
    @Schema(description = "Remittance date", example = "2024-01-25T14:30:00Z")
    private LocalDateTime remittanceDate;
    
    @Schema(description = "Payment reference", example = "PAY-2024-001")
    private String paymentReference;
    
    @Schema(description = "Settlement date", example = "2024-01-25T00:00:00Z")
    private LocalDateTime settlementDate;
    
    @Schema(description = "Claim-level denial code", example = "CO-4")
    private String denialCode;
    
    @Schema(description = "Remittance payer ID", example = "DHA")
    private String remittancePayerId;
    
    @Schema(description = "Remittance provider ID", example = "PROV001")
    private String remittanceProviderId;
    
    @Schema(description = "List of remittance activities with payment amounts and denial codes")
    private List<RemittanceActivityInfo> activities;
    
    @Schema(description = "List of attachments for this remittance")
    private List<AttachmentInfo> attachments;
}
}

