package com.acme.claims.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.sql.DataSource;
import java.sql.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * Service for Claim Details with Activity Report
 *
 * This service provides comprehensive data access methods for the Claim Details with Activity report,
 * which shows detailed claim information including:
 * - Submission & Remittance Tracking
 * - Claim Financials
 * - Denial & Resubmission Information
 * - Remittance and Rejection Tracking
 * - Patient and Payer Information
 * - Encounter & Activity Details
 * - Calculated Metrics (Collection Rate, Denial Rate, Turnaround Time, etc.)
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ClaimDetailsWithActivityReportService {

    private final DataSource dataSource;

    /**
     * Get comprehensive claim details with activity data using complex filtering
     */
    public List<Map<String, Object>> getClaimDetailsWithActivity(
            String facilityCode,
            String receiverId,
            String payerCode,
            String clinician,
            String claimId,
            String patientId,
            String cptCode,
            String claimStatus,
            String paymentStatus,
            String encounterType,
            String resubType,
            String denialCode,
            String memberId,
            LocalDateTime fromDate,
            LocalDateTime toDate,
            String sortBy,
            String sortDirection,
            Integer page,
            Integer size) {

        // Build ORDER BY clause
        String orderByClause = buildOrderByClause(sortBy, sortDirection, "submission_date", "DESC");

        String sql = """
            SELECT * FROM claims.get_claim_details_with_activity(
                ?::text,
                ?::text,
                ?::text,
                ?::text,
                ?::text,
                ?::text,
                ?::text,
                ?::text,
                ?::text,
                ?::text,
                ?::text,
                ?::text,
                ?::text,
                ?::timestamptz,
                ?::timestamptz,
                ?::integer,
                ?::integer
            )
            """ + orderByClause;

        List<Map<String, Object>> results = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            // Set parameters
            int paramIndex = 1;
            stmt.setString(paramIndex++, facilityCode);
            stmt.setString(paramIndex++, receiverId);
            stmt.setString(paramIndex++, payerCode);
            stmt.setString(paramIndex++, clinician);
            stmt.setString(paramIndex++, claimId);
            stmt.setString(paramIndex++, patientId);
            stmt.setString(paramIndex++, cptCode);
            stmt.setString(paramIndex++, claimStatus);
            stmt.setString(paramIndex++, paymentStatus);
            stmt.setString(paramIndex++, encounterType);
            stmt.setString(paramIndex++, resubType);
            stmt.setString(paramIndex++, denialCode);
            stmt.setString(paramIndex++, memberId);
            stmt.setObject(paramIndex++, fromDate);
            stmt.setObject(paramIndex++, toDate);
            stmt.setInt(paramIndex++, page != null && size != null ? size : 1000);
            stmt.setInt(paramIndex++, page != null && size != null ? page * size : 0);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("claimId", rs.getString("claim_id"));
                    row.put("claimDbId", rs.getLong("claim_db_id"));
                    row.put("payerId", rs.getString("payer_id"));
                    row.put("providerId", rs.getString("provider_id"));
                    row.put("memberId", rs.getString("member_id"));
                    row.put("emiratesIdNumber", rs.getString("emirates_id_number"));
                    row.put("grossAmount", rs.getBigDecimal("gross_amount"));
                    row.put("patientShare", rs.getBigDecimal("patient_share"));
                    row.put("initialNetAmount", rs.getBigDecimal("initial_net_amount"));
                    row.put("comments", rs.getString("comments"));
                    row.put("submissionDate", rs.getTimestamp("submission_date"));
                    row.put("providerName", rs.getString("provider_name"));
                    row.put("receiverId", rs.getString("receiver_id"));
                    row.put("payerName", rs.getString("payer_name"));
                    row.put("payerCode", rs.getString("payer_code"));
                    row.put("facilityId", rs.getString("facility_id"));
                    row.put("encounterType", rs.getString("encounter_type"));
                    row.put("patientId", rs.getString("patient_id"));
                    row.put("encounterStart", rs.getTimestamp("encounter_start"));
                    row.put("encounterEndDate", rs.getTimestamp("encounter_end_date"));
                    row.put("facilityName", rs.getString("facility_name"));
                    row.put("facilityGroup", rs.getString("facility_group"));
                    row.put("submissionId", rs.getLong("submission_id"));
                    row.put("submissionTransactionDate", rs.getTimestamp("submission_transaction_date"));
                    row.put("remittanceClaimId", rs.getLong("remittance_claim_id"));
                    row.put("remittancePayerId", rs.getString("remittance_payer_id"));
                    row.put("paymentReference", rs.getString("payment_reference"));
                    row.put("initialDateSettlement", rs.getTimestamp("initial_date_settlement"));
                    row.put("initialDenialCode", rs.getString("initial_denial_code"));
                    row.put("remittanceDate", rs.getTimestamp("remittance_date"));
                    row.put("remittanceId", rs.getLong("remittance_id"));
                    row.put("claimActivityNumber", rs.getString("claim_activity_number"));
                    row.put("activityStartDate", rs.getTimestamp("activity_start_date"));
                    row.put("activityType", rs.getString("activity_type"));
                    row.put("cptCode", rs.getString("cpt_code"));
                    row.put("quantity", rs.getBigDecimal("quantity"));
                    row.put("activityNetAmount", rs.getBigDecimal("activity_net_amount"));
                    row.put("clinician", rs.getString("clinician"));
                    row.put("priorAuthorizationId", rs.getString("prior_authorization_id"));
                    row.put("clinicianName", rs.getString("clinician_name"));
                    row.put("activityDescription", rs.getString("activity_description"));
                    row.put("primaryDiagnosis", rs.getString("primary_diagnosis"));
                    row.put("secondaryDiagnosis", rs.getString("secondary_diagnosis"));
                    row.put("lastSubmissionFile", rs.getString("last_submission_file"));
                    row.put("lastSubmissionTransactionDate", rs.getTimestamp("last_submission_transaction_date"));
                    row.put("lastRemittanceFile", rs.getString("last_remittance_file"));
                    row.put("lastRemittanceTransactionDate", rs.getTimestamp("last_remittance_transaction_date"));
                    row.put("claimStatus", rs.getString("claim_status"));
                    row.put("claimStatusTime", rs.getTimestamp("claim_status_time"));
                    row.put("paymentStatus", rs.getString("payment_status"));
                    row.put("remittedAmount", rs.getBigDecimal("remitted_amount"));
                    row.put("settledAmount", rs.getBigDecimal("settled_amount"));
                    row.put("rejectedAmount", rs.getBigDecimal("rejected_amount"));
                    row.put("unprocessedAmount", rs.getBigDecimal("unprocessed_amount"));
                    row.put("initialRejectedAmount", rs.getBigDecimal("initial_rejected_amount"));
                    row.put("lastDenialCode", rs.getString("last_denial_code"));
                    row.put("remittanceComments", rs.getString("remittance_comments"));
                    row.put("denialComment", rs.getString("denial_comment"));
                    row.put("resubmissionType", rs.getString("resubmission_type"));
                    row.put("resubmissionComment", rs.getString("resubmission_comment"));
                    row.put("netCollectionRate", rs.getBigDecimal("net_collection_rate"));
                    row.put("denialRate", rs.getBigDecimal("denial_rate"));
                    row.put("turnaroundTimeDays", rs.getInt("turnaround_time_days"));
                    row.put("resubmissionEffectiveness", rs.getBigDecimal("resubmission_effectiveness"));
                    row.put("createdAt", rs.getTimestamp("created_at"));
                    row.put("updatedAt", rs.getTimestamp("updated_at"));
                    results.add(row);
                }
            }

            log.info("Retrieved {} claim details records for Claim Details with Activity report", results.size());

        } catch (SQLException e) {
            log.error("Error retrieving claim details with activity data", e);
            throw new RuntimeException("Failed to retrieve claim details with activity data", e);
        }

        return results;
    }

    /**
     * Get summary metrics for the Claim Details with Activity report dashboard
     */
    public Map<String, Object> getClaimDetailsSummary(
            String facilityCode,
            String receiverId,
            String payerCode,
            LocalDateTime fromDate,
            LocalDateTime toDate) {

        String sql = """
            SELECT * FROM claims.get_claim_details_summary(
                ?::text,
                ?::text,
                ?::text,
                ?::timestamptz,
                ?::timestamptz
            )
            """;

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, facilityCode);
            stmt.setString(2, receiverId);
            stmt.setString(3, payerCode);
            stmt.setObject(4, fromDate);
            stmt.setObject(5, toDate);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    Map<String, Object> summary = new LinkedHashMap<>();
                    summary.put("totalClaims", rs.getLong("total_claims"));
                    summary.put("totalClaimAmount", rs.getBigDecimal("total_claim_amount"));
                    summary.put("totalPaidAmount", rs.getBigDecimal("total_paid_amount"));
                    summary.put("totalRejectedAmount", rs.getBigDecimal("total_rejected_amount"));
                    summary.put("totalPendingAmount", rs.getBigDecimal("total_pending_amount"));
                    summary.put("avgCollectionRate", rs.getBigDecimal("avg_collection_rate"));
                    summary.put("avgDenialRate", rs.getBigDecimal("avg_denial_rate"));
                    summary.put("avgTurnaroundTime", rs.getBigDecimal("avg_turnaround_time"));
                    summary.put("fullyPaidCount", rs.getLong("fully_paid_count"));
                    summary.put("partiallyPaidCount", rs.getLong("partially_paid_count"));
                    summary.put("fullyRejectedCount", rs.getLong("fully_rejected_count"));
                    summary.put("pendingCount", rs.getLong("pending_count"));
                    summary.put("resubmittedCount", rs.getLong("resubmitted_count"));
                    summary.put("uniquePatients", rs.getLong("unique_patients"));
                    summary.put("uniqueProviders", rs.getLong("unique_providers"));
                    summary.put("uniqueFacilities", rs.getLong("unique_facilities"));

                    log.info("Retrieved claim details summary for dashboard");
                    return summary;
                }
            }

        } catch (SQLException e) {
            log.error("Error retrieving claim details summary", e);
            throw new RuntimeException("Failed to retrieve claim details summary", e);
        }

        return new HashMap<>();
    }

    /**
     * Get filter options for the Claim Details with Activity report
     */
    public Map<String, List<String>> getFilterOptions() {
        Map<String, List<String>> options = new HashMap<>();

        // Get available facilities
        options.put("facilities", getDistinctValues("SELECT DISTINCT facility_code FROM claims_ref.facility WHERE facility_code IS NOT NULL ORDER BY facility_code"));

        // Get available receivers (providers)
        options.put("receivers", getDistinctValues("SELECT DISTINCT provider_code FROM claims_ref.provider WHERE provider_code IS NOT NULL ORDER BY provider_code"));

        // Get available payers
        options.put("payers", getDistinctValues("SELECT DISTINCT payer_code FROM claims_ref.payer WHERE payer_code IS NOT NULL ORDER BY payer_code"));

        // Get available clinicians
        options.put("clinicians", getDistinctValues("SELECT DISTINCT clinician_code FROM claims_ref.clinician WHERE clinician_code IS NOT NULL ORDER BY clinician_code"));

        // Get available CPT codes
        options.put("cptCodes", getDistinctValues("SELECT DISTINCT code FROM claims_ref.activity_code WHERE code IS NOT NULL ORDER BY code"));

        // Get available claim statuses
        options.put("claimStatuses", getDistinctValues("SELECT DISTINCT status FROM claims.claim_status_timeline WHERE status IS NOT NULL ORDER BY status"));

        // Get available payment statuses
        options.put("paymentStatuses", Arrays.asList("Fully Paid", "Partially Paid", "Rejected", "Pending", "Unknown"));

        // Get available encounter types
        options.put("encounterTypes", getDistinctValues("SELECT DISTINCT type FROM claims.encounter WHERE type IS NOT NULL ORDER BY type"));

        // Get available resubmission types
        options.put("resubmissionTypes", getDistinctValues("SELECT DISTINCT resubmission_type FROM claims.claim_resubmission WHERE resubmission_type IS NOT NULL ORDER BY resubmission_type"));

        // Get available denial codes
        options.put("denialCodes", getDistinctValues("SELECT DISTINCT denial_code FROM claims.remittance_activity WHERE denial_code IS NOT NULL ORDER BY denial_code"));

        return options;
    }

    private List<String> getDistinctValues(String sql) {
        List<String> values = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {

            while (rs.next()) {
                values.add(rs.getString(1));
            }

        } catch (SQLException e) {
            log.error("Error retrieving distinct values", e);
        }

        return values;
    }

    /**
     * Build ORDER BY clause for SQL queries
     */
    private String buildOrderByClause(String sortBy, String sortDirection, String defaultColumn, String defaultDirection) {
        if (sortBy == null || sortBy.trim().isEmpty()) {
            sortBy = defaultColumn;
        }

        if (sortDirection == null || (!"ASC".equalsIgnoreCase(sortDirection) && !"DESC".equalsIgnoreCase(sortDirection))) {
            sortDirection = defaultDirection;
        }

        // Validate sortBy column to prevent SQL injection
        Set<String> validColumns = Set.of(
            "claim_id", "submission_date", "facility_id", "payer_id", "provider_id",
            "patient_id", "cpt_code", "clinician", "claim_status", "payment_status",
            "initial_net_amount", "remitted_amount", "rejected_amount", "net_collection_rate",
            "denial_rate", "turnaround_time_days", "created_at"
        );

        if (!validColumns.contains(sortBy)) {
            sortBy = defaultColumn;
        }

        return " ORDER BY " + sortBy + " " + sortDirection.toUpperCase();
    }
}
