package com.acme.claims.service;

import com.acme.claims.soap.db.ToggleRepo;
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
 * Service for Doctor Denial Report
 *
 * This service provides comprehensive data access methods for the Doctor Denial Report,
 * which shows denial analysis across three tabs:
 * - Tab A: Doctors with high denial rates
 * - Tab B: Doctor-wise summary with aggregated metrics
 * - Tab C: Detailed patient and claim information
 *
 * The report includes metrics like denial rates, collection rates, turnaround times,
 * and provides insights for improving claim processing efficiency.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class DoctorDenialReportService {

    private final DataSource dataSource;
    private final ToggleRepo toggleRepo;

    /**
     * Get doctor denial report data for all three tabs with complex filtering
     */
    public List<Map<String, Object>> getDoctorDenialReport(
            String facilityCode,
            String clinicianCode,
            LocalDateTime fromDate,
            LocalDateTime toDate,
            Integer year,
            Integer month,
            String tab,
            String sortBy,
            String sortDirection,
            Integer page,
            Integer size    ) {
        // OPTION 3: Check if MVs are enabled via toggle
        boolean useMv = toggleRepo.isEnabled("is_mv_enabled") || toggleRepo.isEnabled("is_sub_second_mode_enabled");
        
        log.info("Doctor Denial Report - useMv: {}, tab: {}", useMv, tab);

        // Build ORDER BY clause
        String orderByClause = buildOrderByClause(sortBy, sortDirection, tab);

        String sql = """
            SELECT * FROM claims.get_doctor_denial_report(
                p_use_mv := ?,
                p_tab_name := ?,
                p_facility_code := ?::text,
                p_clinician_code := ?::text,
                p_from_date := ?::timestamptz,
                p_to_date := ?::timestamptz,
                p_year := ?::integer,
                p_month := ?::integer,
                p_limit := ?::integer,
                p_offset := ?::integer
            )
            """ + orderByClause;

        List<Map<String, Object>> results = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            // Set parameters
            int paramIndex = 1;
            // OPTION 3: Set useMv and tabName parameters first
            stmt.setBoolean(paramIndex++, useMv);
            stmt.setString(paramIndex++, tab != null ? tab : "high_denial");
            stmt.setString(paramIndex++, facilityCode);
            stmt.setString(paramIndex++, clinicianCode);
            stmt.setObject(paramIndex++, fromDate);
            stmt.setObject(paramIndex++, toDate);
            stmt.setObject(paramIndex++, year);
            stmt.setObject(paramIndex++, month);
            stmt.setInt(paramIndex++, page != null && size != null ? size : 1000);
            stmt.setInt(paramIndex++, page != null && size != null ? page * size : 0);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();

                    // Common fields for all tabs
                    row.put("clinicianId", rs.getString("clinician_id"));
                    row.put("clinicianName", rs.getString("clinician_name"));
                    row.put("clinicianSpecialty", rs.getString("clinician_specialty"));
                    row.put("facilityId", rs.getString("facility_id"));
                    row.put("facilityName", rs.getString("facility_name"));
                    row.put("facilityGroup", rs.getString("facility_group"));
                    row.put("healthAuthority", rs.getString("health_authority"));
                    row.put("reportMonth", rs.getTimestamp("report_month"));
                    row.put("reportYear", rs.getInt("report_year"));
                    row.put("reportMonthNum", rs.getInt("report_month_num"));

                    // Tab A and B specific fields
                    if ("high_denial".equals(tab) || "summary".equals(tab)) {
                        row.put("totalClaims", rs.getLong("total_claims"));
                        row.put("remittedClaims", rs.getLong("remitted_claims"));
                        row.put("rejectedClaims", rs.getLong("rejected_claims"));
                        row.put("pendingRemittanceClaims", rs.getLong("pending_remittance_claims"));
                        row.put("totalClaimAmount", rs.getBigDecimal("total_claim_amount"));
                        row.put("remittedAmount", rs.getBigDecimal("remitted_amount"));
                        row.put("rejectedAmount", rs.getBigDecimal("rejected_amount"));
                        row.put("pendingRemittanceAmount", rs.getBigDecimal("pending_remittance_amount"));
                        row.put("rejectionPercentage", rs.getBigDecimal("rejection_percentage"));
                        row.put("collectionRate", rs.getBigDecimal("collection_rate"));
                        row.put("avgClaimValue", rs.getBigDecimal("avg_claim_value"));
                        row.put("netBalance", rs.getBigDecimal("net_balance"));
                        row.put("topPayerCode", rs.getString("top_payer_code"));
                    }

                    // Tab A specific fields
                    if ("high_denial".equals(tab)) {
                        row.put("uniqueProviders", rs.getLong("unique_providers"));
                        row.put("uniquePatients", rs.getLong("unique_patients"));
                        row.put("earliestSubmission", rs.getTimestamp("earliest_submission"));
                        row.put("latestSubmission", rs.getTimestamp("latest_submission"));
                        row.put("avgProcessingDays", rs.getBigDecimal("avg_processing_days"));
                    }

                    // Tab C specific fields
                    if ("detail".equals(tab)) {
                        row.put("claimId", rs.getString("claim_id"));
                        row.put("claimDbId", rs.getLong("claim_db_id"));
                        row.put("payerId", rs.getString("payer_id"));
                        row.put("providerId", rs.getString("provider_id"));
                        row.put("memberId", rs.getString("member_id"));
                        row.put("emiratesIdNumber", rs.getString("emirates_id_number"));
                        row.put("patientId", rs.getString("patient_id"));
                        row.put("claimAmount", rs.getBigDecimal("claim_amount"));
                        row.put("providerName", rs.getString("provider_name"));
                        row.put("receiverId", rs.getString("receiver_id"));
                        row.put("payerName", rs.getString("payer_name"));
                        row.put("payerCode", rs.getString("payer_code"));
                        row.put("idPayer", rs.getString("id_payer"));
                        row.put("claimActivityNumber", rs.getString("claim_activity_number"));
                        row.put("activityStartDate", rs.getTimestamp("activity_start_date"));
                        row.put("activityType", rs.getString("activity_type"));
                        row.put("cptCode", rs.getString("cpt_code"));
                        row.put("quantity", rs.getBigDecimal("quantity"));
                        row.put("remittanceClaimId", rs.getLong("remittance_claim_id"));
                        row.put("paymentReference", rs.getString("payment_reference"));
                        row.put("dateSettlement", rs.getTimestamp("date_settlement"));
                        row.put("submissionDate", rs.getTimestamp("submission_date"));
                        row.put("remittanceDate", rs.getTimestamp("remittance_date"));
                    }

                    results.add(row);
                }
            }

            log.info("Retrieved {} doctor denial records for tab: {} with filters: facility={}, clinician={}, year={}, month={}",
                    results.size(), tab, facilityCode, clinicianCode, year, month);

        } catch (SQLException e) {
            log.error("Error retrieving doctor denial report data", e);
            throw new RuntimeException("Failed to retrieve doctor denial report data", e);
        }

        return results;
    }

    /**
     * Get summary metrics for the Doctor Denial Report dashboard
     */
    public Map<String, Object> getDoctorDenialSummary(
            String facilityCode,
            String clinicianCode,
            LocalDateTime fromDate,
            LocalDateTime toDate,
            Integer year,
            Integer month) {
        // OPTION 3: Check if MVs are enabled via toggle
        boolean useMv = toggleRepo.isEnabled("is_mv_enabled") || toggleRepo.isEnabled("is_sub_second_mode_enabled");
        
        log.info("Doctor Denial Summary - useMv: {}", useMv);

        String sql = """
            SELECT * FROM claims.get_doctor_denial_summary(
                p_use_mv := ?,
                p_facility_code := ?::text,
                p_clinician_code := ?::text,
                p_from_date := ?::timestamptz,
                p_to_date := ?::timestamptz,
                p_year := ?::integer,
                p_month := ?::integer
            )
            """;

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            // OPTION 3: Set useMv parameter first
            stmt.setBoolean(1, useMv);
            stmt.setString(2, facilityCode);
            stmt.setString(3, clinicianCode);
            stmt.setObject(4, fromDate);
            stmt.setObject(5, toDate);
            stmt.setObject(6, year);
            stmt.setObject(7, month);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    Map<String, Object> summary = new LinkedHashMap<>();
                    summary.put("totalDoctors", rs.getLong("total_doctors"));
                    summary.put("totalClaims", rs.getLong("total_claims"));
                    summary.put("totalClaimAmount", rs.getBigDecimal("total_claim_amount"));
                    summary.put("totalRemittedAmount", rs.getBigDecimal("total_remitted_amount"));
                    summary.put("totalRejectedAmount", rs.getBigDecimal("total_rejected_amount"));
                    summary.put("totalPendingAmount", rs.getBigDecimal("total_pending_amount"));
                    summary.put("avgRejectionRate", rs.getBigDecimal("avg_rejection_rate"));
                    summary.put("avgCollectionRate", rs.getBigDecimal("avg_collection_rate"));
                    summary.put("doctorsWithHighDenial", rs.getLong("doctors_with_high_denial"));
                    summary.put("highRiskDoctors", rs.getLong("high_risk_doctors"));
                    summary.put("improvementPotential", rs.getBigDecimal("improvement_potential"));

                    log.info("Retrieved doctor denial summary for dashboard");
                    return summary;
                }
            }

        } catch (SQLException e) {
            log.error("Error retrieving doctor denial summary", e);
            throw new RuntimeException("Failed to retrieve doctor denial summary", e);
        }

        return new HashMap<>();
    }

    /**
     * Get filter options for the Doctor Denial Report
     */
    public Map<String, List<String>> getFilterOptions() {
        Map<String, List<String>> options = new HashMap<>();

        // Get available facilities
        options.put("facilities", getDistinctValues("SELECT DISTINCT facility_code FROM claims_ref.facility WHERE facility_code IS NOT NULL ORDER BY facility_code"));

        // Get available clinicians
        options.put("clinicians", getDistinctValues("SELECT DISTINCT clinician_code FROM claims_ref.clinician WHERE clinician_code IS NOT NULL ORDER BY clinician_code"));

        // Get available years
        options.put("years", getDistinctValues("SELECT DISTINCT EXTRACT(YEAR FROM tx_at)::text FROM claims.claim WHERE tx_at IS NOT NULL ORDER BY 1 DESC"));

        // Get available months
        options.put("months", Arrays.asList("1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"));

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
     * Get claims for a specific clinician (drill-down functionality)
     * This allows expanding clinician rows to see their actual claims
     */
    public List<Map<String, Object>> getClinicianClaims(
            String clinicianCode,
            String facilityCode,
            LocalDateTime fromDate,
            LocalDateTime toDate,
            Integer year,
            Integer month,
            String sortBy,
            String sortDirection,
            Integer page,
            Integer size) {
        // OPTION 3: Check if MVs are enabled via toggle
        boolean useMv = toggleRepo.isEnabled("is_mv_enabled") || toggleRepo.isEnabled("is_sub_second_mode_enabled");
        
        log.info("Clinician Claims - useMv: {}", useMv);

        // Build ORDER BY clause
        String orderByClause = buildOrderByClause(sortBy, sortDirection, "detail");

        String sql = """
            SELECT * FROM claims.get_doctor_denial_report(
                p_use_mv := ?,
                p_tab_name := 'detail',
                p_facility_code := ?::text,
                p_clinician_code := ?::text,
                p_from_date := ?::timestamptz,
                p_to_date := ?::timestamptz,
                p_year := ?::integer,
                p_month := ?::integer,
                p_limit := ?::integer,
                p_offset := ?::integer
            )
            """ + orderByClause;

        List<Map<String, Object>> results = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            // Set parameters
            int paramIndex = 1;
            // OPTION 3: Set useMv and tabName parameters first
            stmt.setBoolean(paramIndex++, useMv);
            stmt.setString(paramIndex++, facilityCode);
            stmt.setString(paramIndex++, clinicianCode); // This is the key - filtering by clinician
            stmt.setObject(paramIndex++, fromDate);
            stmt.setObject(paramIndex++, toDate);
            stmt.setObject(paramIndex++, year);
            stmt.setObject(paramIndex++, month);
            stmt.setInt(paramIndex++, page != null && size != null ? size : 1000);
            stmt.setInt(paramIndex++, page != null && size != null ? page * size : 0);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();

                    // Include all detail fields for drill-down
                    row.put("claimId", rs.getString("claim_id"));
                    row.put("claimDbId", rs.getLong("claim_db_id"));
                    row.put("payerId", rs.getString("payer_id"));
                    row.put("providerId", rs.getString("provider_id"));
                    row.put("memberId", rs.getString("member_id"));
                    row.put("emiratesIdNumber", rs.getString("emirates_id_number"));
                    row.put("patientId", rs.getString("patient_id"));
                    row.put("claimAmount", rs.getBigDecimal("claim_amount"));
                    row.put("providerName", rs.getString("provider_name"));
                    row.put("receiverId", rs.getString("receiver_id"));
                    row.put("payerName", rs.getString("payer_name"));
                    row.put("payerCode", rs.getString("payer_code"));
                    row.put("idPayer", rs.getString("id_payer"));
                    row.put("claimActivityNumber", rs.getString("claim_activity_number"));
                    row.put("activityStartDate", rs.getTimestamp("activity_start_date"));
                    row.put("activityType", rs.getString("activity_type"));
                    row.put("cptCode", rs.getString("cpt_code"));
                    row.put("quantity", rs.getBigDecimal("quantity"));
                    row.put("remittanceClaimId", rs.getLong("remittance_claim_id"));
                    row.put("paymentReference", rs.getString("payment_reference"));
                    row.put("dateSettlement", rs.getTimestamp("date_settlement"));
                    row.put("submissionDate", rs.getTimestamp("submission_date"));
                    row.put("remittanceDate", rs.getTimestamp("remittance_date"));

                    // Add clinician info for context
                    row.put("clinicianId", rs.getString("clinician_id"));
                    row.put("clinicianName", rs.getString("clinician_name"));

                    results.add(row);
                }
            }

            log.info("Retrieved {} claims for clinician: {} with filters: facility={}, year={}, month={}",
                    results.size(), clinicianCode, facilityCode, year, month);

        } catch (SQLException e) {
            log.error("Error retrieving clinician claims for drill-down", e);
            throw new RuntimeException("Failed to retrieve clinician claims", e);
        }

        return results;
    }

    /**
     * Build ORDER BY clause for SQL queries based on tab
     */
    private String buildOrderByClause(String sortBy, String sortDirection, String tab) {
        String defaultColumn = "rejection_percentage";
        String defaultDirection = "DESC";

        // Tab-specific default sorting
        switch (tab) {
            case "high_denial":
                defaultColumn = "rejection_percentage";
                break;
            case "summary":
                defaultColumn = "rejection_percentage";
                break;
            case "detail":
                defaultColumn = "submission_date";
                defaultDirection = "DESC";
                break;
        }

        if (sortBy == null || sortBy.trim().isEmpty()) {
            sortBy = defaultColumn;
        }

        if (sortDirection == null || (!"ASC".equalsIgnoreCase(sortDirection) && !"DESC".equalsIgnoreCase(sortDirection))) {
            sortDirection = defaultDirection;
        }

        // Validate sortBy column to prevent SQL injection
        Set<String> validColumns = Set.of(
            // Common columns
            "clinician_id", "clinician_name", "facility_id", "facility_name", "report_month",
            // Tab A/B specific
            "total_claims", "remitted_claims", "rejected_claims", "total_claim_amount",
            "remitted_amount", "rejected_amount", "rejection_percentage", "collection_rate",
            "avg_claim_value", "net_balance",
            // Tab C specific
            "claim_id", "submission_date", "claim_amount", "remitted_amount", "rejected_amount"
        );

        if (!validColumns.contains(sortBy)) {
            sortBy = defaultColumn;
        }

        return " ORDER BY " + sortBy + " " + sortDirection.toUpperCase();
    }
}
