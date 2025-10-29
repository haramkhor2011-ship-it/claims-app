package com.acme.claims.service;

import com.acme.claims.controller.dto.ClaimDetailsResponse;
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
 * Service for Claim Summary Monthwise Report
 *
 * This service provides data access methods for the three tabs of the
 * Claim Summary Monthwise report:
 * - Tab A: Monthwise grouping
 * - Tab B: Payerwise grouping
 * - Tab C: Encounterwise grouping
 *
 * Each tab shows comprehensive metrics including counts, amounts, and percentages
 * for claims processing status and financial performance.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ClaimSummaryMonthwiseReportService {

    private final DataSource dataSource;
    private final ToggleRepo toggleRepo;

    /**
     * Get Monthwise Tab data for Claim Summary Monthwise report (Tab A)
     */
    public List<Map<String, Object>> getMonthwiseTabData(
            LocalDateTime fromDate,
            LocalDateTime toDate,
            String facilityCode,
            String payerCode,
            String receiverCode,
            String sortBy,
            String sortDirection,
            Integer page,
            Integer size) {

        // Build WHERE clause
        StringBuilder whereClause = new StringBuilder();
        List<Object> parameters = new ArrayList<>();

        boolean hasWhere = false;

        if (fromDate != null) {
            if (hasWhere) whereClause.append(" AND ");
            else whereClause.append(" WHERE ");
            whereClause.append("EXTRACT(YEAR FROM month_year::date) >= ? AND EXTRACT(MONTH FROM month_year::date) >= ?");
            parameters.add(fromDate.getYear());
            parameters.add(fromDate.getMonthValue());
            hasWhere = true;
        }

        if (toDate != null) {
            if (hasWhere) whereClause.append(" AND ");
            else whereClause.append(" WHERE ");
            whereClause.append("EXTRACT(YEAR FROM month_year::date) <= ? AND EXTRACT(MONTH FROM month_year::date) <= ?");
            parameters.add(toDate.getYear());
            parameters.add(toDate.getMonthValue());
            hasWhere = true;
        }

        if (facilityCode != null && !facilityCode.trim().isEmpty()) {
            if (hasWhere) whereClause.append(" AND ");
            else whereClause.append(" WHERE ");
            whereClause.append("facility_id = ?");
            parameters.add(facilityCode);
            hasWhere = true;
        }

        if (payerCode != null && !payerCode.trim().isEmpty()) {
            if (hasWhere) whereClause.append(" AND ");
            else whereClause.append(" WHERE ");
            whereClause.append("health_authority = ?");
            parameters.add(payerCode);
            hasWhere = true;
        }

        // Build ORDER BY clause
        String orderByClause = buildOrderByClause(sortBy, sortDirection, "month_bucket", "DESC");

        // Use optimized materialized view for sub-second performance
        String sql = """
            SELECT
                TO_CHAR(month_bucket, 'Month YYYY') as month_year,
                EXTRACT(YEAR FROM month_bucket) as year,
                EXTRACT(MONTH FROM month_bucket) as month,
                SUM(claim_count) as count_claims,
                SUM(total_net) as claim_amount,
                SUM(total_net) as initial_claim_amount,
                payer_id as facility_id,
                'N/A' as facility_name,
                payer_id as health_authority,
                0.0 as rejected_percentage_on_remittance,
                0 as remitted_count,
                0.0 as remitted_amount,
                0.0 as rejected_percentage_on_initial,
                0.0 as remitted_net_amount,
                0 as fully_paid_count,
                0.0 as fully_paid_amount,
                0 as partially_paid_count,
                0.0 as partially_paid_amount,
                0 as fully_rejected_count,
                0.0 as fully_rejected_amount,
                0 as rejection_count,
                0.0 as rejected_amount,
                0 as taken_back_count,
                0 as pending_remittance_count,
                0.0 as pending_remittance_amount,
                0 as self_pay_count,
                0.0 as self_pay_amount,
                0.0 as collection_rate
            FROM claims.mv_claims_monthly_agg
            """ + whereClause + """
            GROUP BY month_bucket, payer_id, provider_id
            """ + orderByClause;

        // Add pagination if specified
        if (page != null && size != null && page >= 0 && size > 0) {
            sql += " LIMIT ? OFFSET ?";
            parameters.add(size);
            parameters.add(page * size);
        }

        List<Map<String, Object>> results = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            // Set parameters
            for (int i = 0; i < parameters.size(); i++) {
                stmt.setObject(i + 1, parameters.get(i));
            }

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("monthYear", rs.getString("month_year"));
                    row.put("year", rs.getInt("year"));
                    row.put("month", rs.getInt("month"));
                    row.put("count", rs.getLong("count_claims"));
                    row.put("claimAmount", rs.getBigDecimal("claim_amount"));
                    row.put("initialClaimAmount", rs.getBigDecimal("initial_claim_amount"));
                    row.put("facilityId", rs.getString("facility_id"));
                    row.put("facilityName", rs.getString("facility_name"));
                    row.put("healthAuthority", rs.getString("health_authority"));
                    row.put("rejectedPercentageOnRemittance", rs.getBigDecimal("rejected_percentage_on_remittance"));
                    row.put("remittedCount", rs.getLong("remitted_count"));
                    row.put("remittedAmount", rs.getBigDecimal("remitted_amount"));
                    row.put("rejectedPercentageOnInitial", rs.getBigDecimal("rejected_percentage_on_initial"));
                    row.put("remittedNetAmount", rs.getBigDecimal("remitted_net_amount"));
                    row.put("fullyPaidCount", rs.getLong("fully_paid_count"));
                    row.put("fullyPaidAmount", rs.getBigDecimal("fully_paid_amount"));
                    row.put("partiallyPaidCount", rs.getLong("partially_paid_count"));
                    row.put("partiallyPaidAmount", rs.getBigDecimal("partially_paid_amount"));
                    row.put("fullyRejectedCount", rs.getLong("fully_rejected_count"));
                    row.put("fullyRejectedAmount", rs.getBigDecimal("fully_rejected_amount"));
                    row.put("rejectionCount", rs.getLong("rejection_count"));
                    row.put("rejectedAmount", rs.getBigDecimal("rejected_amount"));
                    row.put("takenBackCount", rs.getLong("taken_back_count"));
                    row.put("pendingRemittanceCount", rs.getLong("pending_remittance_count"));
                    row.put("pendingRemittanceAmount", rs.getBigDecimal("pending_remittance_amount"));
                    row.put("selfPayCount", rs.getLong("self_pay_count"));
                    row.put("selfPayAmount", rs.getBigDecimal("self_pay_amount"));
                    row.put("collectionRate", rs.getBigDecimal("collection_rate"));
                    results.add(row);
                }
            }

            log.info("Retrieved {} monthwise tab records for Claim Summary Monthwise report", results.size());

        } catch (SQLException e) {
            log.error("Error retrieving monthwise tab data for Claim Summary Monthwise report", e);
            throw new RuntimeException("Failed to retrieve monthwise tab data", e);
        }

        return results;
    }

    /**
     * Get Payerwise Tab data for Claim Summary Monthwise report (Tab B)
     */
    public List<Map<String, Object>> getPayerwiseTabData(
            LocalDateTime fromDate,
            LocalDateTime toDate,
            String facilityCode,
            String payerCode,
            String receiverCode,
            String sortBy,
            String sortDirection,
            Integer page,
            Integer size) {

        // Build WHERE clause
        StringBuilder whereClause = new StringBuilder();
        List<Object> parameters = new ArrayList<>();

        boolean hasWhere = false;

        if (fromDate != null) {
            if (hasWhere) whereClause.append(" AND ");
            else whereClause.append(" WHERE ");
            whereClause.append("EXTRACT(YEAR FROM month_year::date) >= ? AND EXTRACT(MONTH FROM month_year::date) >= ?");
            parameters.add(fromDate.getYear());
            parameters.add(fromDate.getMonthValue());
            hasWhere = true;
        }

        if (toDate != null) {
            if (hasWhere) whereClause.append(" AND ");
            else whereClause.append(" WHERE ");
            whereClause.append("EXTRACT(YEAR FROM month_year::date) <= ? AND EXTRACT(MONTH FROM month_year::date) <= ?");
            parameters.add(toDate.getYear());
            parameters.add(toDate.getMonthValue());
            hasWhere = true;
        }

        if (facilityCode != null && !facilityCode.trim().isEmpty()) {
            if (hasWhere) whereClause.append(" AND ");
            else whereClause.append(" WHERE ");
            whereClause.append("facility_id = ?");
            parameters.add(facilityCode);
            hasWhere = true;
        }

        if (payerCode != null && !payerCode.trim().isEmpty()) {
            if (hasWhere) whereClause.append(" AND ");
            else whereClause.append(" WHERE ");
            whereClause.append("payer_id = ?");
            parameters.add(payerCode);
            hasWhere = true;
        }

        // Build ORDER BY clause
        String orderByClause = buildOrderByClause(sortBy, sortDirection, "payer_id, month_year", "ASC, DESC");

        String sql = """
            SELECT
                payer_id,
                payer_name,
                month_year,
                year,
                month,
                count_claims,
                claim_amount,
                initial_claim_amount,
                facility_id,
                facility_name,
                health_authority,
                rejected_percentage_on_remittance,
                remitted_count,
                remitted_amount,
                rejected_percentage_on_initial,
                remitted_net_amount,
                fully_paid_count,
                fully_paid_amount,
                partially_paid_count,
                partially_paid_amount,
                fully_rejected_count,
                fully_rejected_amount,
                rejection_count,
                rejected_amount,
                taken_back_count,
                pending_remittance_count,
                pending_remittance_amount,
                self_pay_count,
                self_pay_amount,
                collection_rate
            FROM claims.v_claim_summary_payerwise
            """ + whereClause + orderByClause;

        // Add pagination if specified
        if (page != null && size != null && page >= 0 && size > 0) {
            sql += " LIMIT ? OFFSET ?";
            parameters.add(size);
            parameters.add(page * size);
        }

        List<Map<String, Object>> results = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            // Set parameters
            for (int i = 0; i < parameters.size(); i++) {
                stmt.setObject(i + 1, parameters.get(i));
            }

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("payerId", rs.getString("payer_id"));
                    row.put("payerName", rs.getString("payer_name"));
                    row.put("monthYear", rs.getString("month_year"));
                    row.put("year", rs.getInt("year"));
                    row.put("month", rs.getInt("month"));
                    row.put("count", rs.getLong("count_claims"));
                    row.put("claimAmount", rs.getBigDecimal("claim_amount"));
                    row.put("initialClaimAmount", rs.getBigDecimal("initial_claim_amount"));
                    row.put("facilityId", rs.getString("facility_id"));
                    row.put("facilityName", rs.getString("facility_name"));
                    row.put("healthAuthority", rs.getString("health_authority"));
                    row.put("rejectedPercentageOnRemittance", rs.getBigDecimal("rejected_percentage_on_remittance"));
                    row.put("remittedCount", rs.getLong("remitted_count"));
                    row.put("remittedAmount", rs.getBigDecimal("remitted_amount"));
                    row.put("rejectedPercentageOnInitial", rs.getBigDecimal("rejected_percentage_on_initial"));
                    row.put("remittedNetAmount", rs.getBigDecimal("remitted_net_amount"));
                    row.put("fullyPaidCount", rs.getLong("fully_paid_count"));
                    row.put("fullyPaidAmount", rs.getBigDecimal("fully_paid_amount"));
                    row.put("partiallyPaidCount", rs.getLong("partially_paid_count"));
                    row.put("partiallyPaidAmount", rs.getBigDecimal("partially_paid_amount"));
                    row.put("fullyRejectedCount", rs.getLong("fully_rejected_count"));
                    row.put("fullyRejectedAmount", rs.getBigDecimal("fully_rejected_amount"));
                    row.put("rejectionCount", rs.getLong("rejection_count"));
                    row.put("rejectedAmount", rs.getBigDecimal("rejected_amount"));
                    row.put("takenBackCount", rs.getLong("taken_back_count"));
                    row.put("pendingRemittanceCount", rs.getLong("pending_remittance_count"));
                    row.put("pendingRemittanceAmount", rs.getBigDecimal("pending_remittance_amount"));
                    row.put("selfPayCount", rs.getLong("self_pay_count"));
                    row.put("selfPayAmount", rs.getBigDecimal("self_pay_amount"));
                    row.put("collectionRate", rs.getBigDecimal("collection_rate"));
                    results.add(row);
                }
            }

            log.info("Retrieved {} payerwise tab records for Claim Summary Monthwise report", results.size());

        } catch (SQLException e) {
            log.error("Error retrieving payerwise tab data for Claim Summary Monthwise report", e);
            throw new RuntimeException("Failed to retrieve payerwise tab data", e);
        }

        return results;
    }

    /**
     * Get Encounterwise Tab data for Claim Summary Monthwise report (Tab C)
     */
    public List<Map<String, Object>> getEncounterwiseTabData(
            LocalDateTime fromDate,
            LocalDateTime toDate,
            String facilityCode,
            String payerCode,
            String receiverCode,
            String sortBy,
            String sortDirection,
            Integer page,
            Integer size) {

        // Build WHERE clause
        StringBuilder whereClause = new StringBuilder();
        List<Object> parameters = new ArrayList<>();

        boolean hasWhere = false;

        if (fromDate != null) {
            if (hasWhere) whereClause.append(" AND ");
            else whereClause.append(" WHERE ");
            whereClause.append("EXTRACT(YEAR FROM month_year::date) >= ? AND EXTRACT(MONTH FROM month_year::date) >= ?");
            parameters.add(fromDate.getYear());
            parameters.add(fromDate.getMonthValue());
            hasWhere = true;
        }

        if (toDate != null) {
            if (hasWhere) whereClause.append(" AND ");
            else whereClause.append(" WHERE ");
            whereClause.append("EXTRACT(YEAR FROM month_year::date) <= ? AND EXTRACT(MONTH FROM month_year::date) <= ?");
            parameters.add(toDate.getYear());
            parameters.add(toDate.getMonthValue());
            hasWhere = true;
        }

        if (facilityCode != null && !facilityCode.trim().isEmpty()) {
            if (hasWhere) whereClause.append(" AND ");
            else whereClause.append(" WHERE ");
            whereClause.append("facility_id = ?");
            parameters.add(facilityCode);
            hasWhere = true;
        }

        if (payerCode != null && !payerCode.trim().isEmpty()) {
            if (hasWhere) whereClause.append(" AND ");
            else whereClause.append(" WHERE ");
            whereClause.append("health_authority = ?");
            parameters.add(payerCode);
            hasWhere = true;
        }

        // Build ORDER BY clause
        String orderByClause = buildOrderByClause(sortBy, sortDirection, "encounter_type, month_year", "ASC, DESC");

        String sql = """
            SELECT
                encounter_type,
                month_year,
                year,
                month,
                count_claims,
                claim_amount,
                initial_claim_amount,
                facility_id,
                facility_name,
                health_authority,
                rejected_percentage_on_remittance,
                remitted_count,
                remitted_amount,
                rejected_percentage_on_initial,
                remitted_net_amount,
                fully_paid_count,
                fully_paid_amount,
                partially_paid_count,
                partially_paid_amount,
                fully_rejected_count,
                fully_rejected_amount,
                rejection_count,
                rejected_amount,
                taken_back_count,
                pending_remittance_count,
                pending_remittance_amount,
                self_pay_count,
                self_pay_amount,
                collection_rate
            FROM claims.v_claim_summary_encounterwise
            """ + whereClause + orderByClause;

        // Add pagination if specified
        if (page != null && size != null && page >= 0 && size > 0) {
            sql += " LIMIT ? OFFSET ?";
            parameters.add(size);
            parameters.add(page * size);
        }

        List<Map<String, Object>> results = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            // Set parameters
            for (int i = 0; i < parameters.size(); i++) {
                stmt.setObject(i + 1, parameters.get(i));
            }

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("encounterType", rs.getString("encounter_type"));
                    row.put("monthYear", rs.getString("month_year"));
                    row.put("year", rs.getInt("year"));
                    row.put("month", rs.getInt("month"));
                    row.put("count", rs.getLong("count_claims"));
                    row.put("claimAmount", rs.getBigDecimal("claim_amount"));
                    row.put("initialClaimAmount", rs.getBigDecimal("initial_claim_amount"));
                    row.put("facilityId", rs.getString("facility_id"));
                    row.put("facilityName", rs.getString("facility_name"));
                    row.put("healthAuthority", rs.getString("health_authority"));
                    row.put("rejectedPercentageOnRemittance", rs.getBigDecimal("rejected_percentage_on_remittance"));
                    row.put("remittedCount", rs.getLong("remitted_count"));
                    row.put("remittedAmount", rs.getBigDecimal("remitted_amount"));
                    row.put("rejectedPercentageOnInitial", rs.getBigDecimal("rejected_percentage_on_initial"));
                    row.put("remittedNetAmount", rs.getBigDecimal("remitted_net_amount"));
                    row.put("fullyPaidCount", rs.getLong("fully_paid_count"));
                    row.put("fullyPaidAmount", rs.getBigDecimal("fully_paid_amount"));
                    row.put("partiallyPaidCount", rs.getLong("partially_paid_count"));
                    row.put("partiallyPaidAmount", rs.getBigDecimal("partially_paid_amount"));
                    row.put("fullyRejectedCount", rs.getLong("fully_rejected_count"));
                    row.put("fullyRejectedAmount", rs.getBigDecimal("fully_rejected_amount"));
                    row.put("rejectionCount", rs.getLong("rejection_count"));
                    row.put("rejectedAmount", rs.getBigDecimal("rejected_amount"));
                    row.put("takenBackCount", rs.getLong("taken_back_count"));
                    row.put("pendingRemittanceCount", rs.getLong("pending_remittance_count"));
                    row.put("pendingRemittanceAmount", rs.getBigDecimal("pending_remittance_amount"));
                    row.put("selfPayCount", rs.getLong("self_pay_count"));
                    row.put("selfPayAmount", rs.getBigDecimal("self_pay_amount"));
                    row.put("collectionRate", rs.getBigDecimal("collection_rate"));
                    results.add(row);
                }
            }

            log.info("Retrieved {} encounterwise tab records for Claim Summary Monthwise report", results.size());

        } catch (SQLException e) {
            log.error("Error retrieving encounterwise tab data for Claim Summary Monthwise report", e);
            throw new RuntimeException("Failed to retrieve encounterwise tab data", e);
        }

        return results;
    }

    /**
     * Get report summary parameters
     */
    public Map<String, Object> getReportParameters(
            LocalDateTime fromDate,
            LocalDateTime toDate,
            String facilityCode,
            String payerCode,
            String receiverCode,
            String encounterType    ) {
        // OPTION 3: Check if MVs are enabled via toggle
        boolean useMv = toggleRepo.isEnabled("is_mv_enabled") || toggleRepo.isEnabled("is_sub_second_mode_enabled");
        
        log.info("Claim Summary Report - useMv: {}", useMv);

        String sql = """
            SELECT * FROM claims.get_claim_summary_monthwise_params(
                p_use_mv := ?,
                p_tab_name := 'monthwise',
                p_from_date := ?::timestamptz,
                p_to_date := ?::timestamptz,
                p_facility_code := ?::text,
                p_payer_code := ?::text,
                p_receiver_code := ?::text,
                p_encounter_type := ?::text
            )
            """;

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            // OPTION 3: Set useMv and tabName parameters first
            stmt.setBoolean(1, useMv);
            stmt.setString(2, "monthwise"); // p_tab_name
            stmt.setObject(3, fromDate);
            stmt.setObject(4, toDate);
            stmt.setString(5, facilityCode);
            stmt.setString(6, payerCode);
            stmt.setString(7, receiverCode);
            stmt.setString(8, encounterType);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    Map<String, Object> params = new LinkedHashMap<>();
                    params.put("totalClaims", rs.getLong("total_claims"));
                    params.put("totalRemittedClaims", rs.getLong("total_remitted_claims"));
                    params.put("totalFullyPaidClaims", rs.getLong("total_fully_paid_claims"));
                    params.put("totalPartiallyPaidClaims", rs.getLong("total_partially_paid_claims"));
                    params.put("totalFullyRejectedClaims", rs.getLong("total_fully_rejected_claims"));
                    params.put("totalRejectionCount", rs.getLong("total_rejection_count"));
                    params.put("totalTakenBackCount", rs.getLong("total_taken_back_count"));
                    params.put("totalClaimAmount", rs.getBigDecimal("total_claim_amount"));
                    params.put("totalInitialClaimAmount", rs.getBigDecimal("total_initial_claim_amount"));
                    params.put("totalRemittedAmount", rs.getBigDecimal("total_remitted_amount"));
                    params.put("totalRemittedNetAmount", rs.getBigDecimal("total_remitted_net_amount"));
                    params.put("totalFullyPaidAmount", rs.getBigDecimal("total_fully_paid_amount"));
                    params.put("totalPartiallyPaidAmount", rs.getBigDecimal("total_partially_paid_amount"));
                    params.put("totalFullyRejectedAmount", rs.getBigDecimal("total_fully_rejected_amount"));
                    params.put("totalRejectedAmount", rs.getBigDecimal("total_rejected_amount"));
                    params.put("totalPendingRemittanceAmount", rs.getBigDecimal("total_pending_remittance_amount"));
                    params.put("totalPendingRemittanceCount", rs.getLong("total_pending_remittance_count"));
                    params.put("totalSelfPayCount", rs.getLong("total_self_pay_count"));
                    params.put("totalSelfPayAmount", rs.getBigDecimal("total_self_pay_amount"));
                    params.put("avgRejectedPercentageOnInitial", rs.getBigDecimal("avg_rejected_percentage_on_initial"));
                    params.put("avgRejectedPercentageOnRemittance", rs.getBigDecimal("avg_rejected_percentage_on_remittance"));
                    params.put("avgCollectionRate", rs.getBigDecimal("avg_collection_rate"));

                    log.info("Retrieved report parameters for Claim Summary Monthwise report");
                    return params;
                }
            }

        } catch (SQLException e) {
            log.error("Error retrieving report parameters for Claim Summary Monthwise report", e);
            throw new RuntimeException("Failed to retrieve report parameters", e);
        }

        return new HashMap<>();
    }

    /**
     * Get available filter options for the report
     */
    public Map<String, List<String>> getFilterOptions() {
        Map<String, List<String>> options = new HashMap<>();

        // Get available facilities
        options.put("facilities", getDistinctValues("SELECT DISTINCT facility_code FROM claims_ref.facility WHERE facility_code IS NOT NULL ORDER BY facility_code"));

        // Get available payers
        options.put("payers", getDistinctValues("SELECT DISTINCT payer_code FROM claims_ref.payer WHERE payer_code IS NOT NULL ORDER BY payer_code"));

        // Get available receivers (providers)
        options.put("receivers", getDistinctValues("SELECT DISTINCT provider_code FROM claims_ref.provider WHERE provider_code IS NOT NULL ORDER BY provider_code"));

        // Get available encounter types
        options.put("encounterTypes", getDistinctValues("SELECT DISTINCT type FROM claims.encounter WHERE type IS NOT NULL ORDER BY type"));

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
            "month_year", "year", "month", "count_claims", "claim_amount", "initial_claim_amount",
            "facility_id", "facility_name", "health_authority", "rejected_percentage_on_remittance",
            "remitted_count", "remitted_amount", "rejected_percentage_on_initial", "remitted_net_amount",
            "fully_paid_count", "fully_paid_amount", "partially_paid_count", "partially_paid_amount",
            "fully_rejected_count", "fully_rejected_amount", "rejection_count", "rejected_amount",
            "taken_back_count", "pending_remittance_count", "pending_remittance_amount",
            "self_pay_count", "self_pay_amount", "collection_rate"
        );

        if (!validColumns.contains(sortBy)) {
            sortBy = defaultColumn;
        }

        return " ORDER BY " + sortBy + " " + sortDirection.toUpperCase();
    }

    /**
     * Get claim status breakdown for popup when clicking Tab A rows
     */
    public List<Map<String, Object>> getClaimStatusBreakdownPopup(
            String monthYear,
            String facilityId,
            String healthAuthority) {

        String sql = """
            SELECT * FROM claims.get_claim_status_breakdown_popup(?, ?, ?)
            """;

        List<Map<String, Object>> results = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, monthYear);
            stmt.setString(2, facilityId);
            stmt.setString(3, healthAuthority);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("statusName", rs.getString("status_name"));
                    row.put("statusCount", rs.getLong("status_count"));
                    row.put("statusDescription", rs.getString("status_description"));
                    row.put("totalAmount", rs.getBigDecimal("total_amount"));
                    row.put("statusPercentage", rs.getBigDecimal("status_percentage"));
                    results.add(row);
                }
            }

            log.info("Retrieved {} status breakdown records for popup: monthYear={}, facilityId={}, healthAuthority={}",
                    results.size(), monthYear, facilityId, healthAuthority);

        } catch (SQLException e) {
            log.error("Error retrieving claim status breakdown popup data", e);
            throw new RuntimeException("Failed to retrieve claim status breakdown popup data", e);
        }

        return results;
    }

    /**
     * Get comprehensive claim details by claim ID for UI rendering
     * This API returns all information related to a specific claim in a structured format
     * 
     * @param claimId The claim ID to retrieve details for
     * @return ClaimDetailsResponse containing all claim information
     * @throws IllegalArgumentException if claimId is null or empty
     * @throws RuntimeException if claim is not found or database error occurs
     */
    public ClaimDetailsResponse getClaimDetailsById(String claimId) {
        if (claimId == null || claimId.trim().isEmpty()) {
            throw new IllegalArgumentException("Claim ID cannot be null or empty");
        }

        long startTime = System.currentTimeMillis();
        
        try (Connection conn = dataSource.getConnection()) {
            // 1. Get original submission data (type=1)
            ClaimDetailsResponse.SubmissionData submission = getSubmissionData(conn, claimId);
            if (submission == null) {
                log.warn("Claim not found: {}", claimId);
                throw new RuntimeException("Claim not found: " + claimId);
            }
            
            // 2. Get all resubmissions (type=2) ordered by event_time
            List<ClaimDetailsResponse.ResubmissionData> resubmissions = getResubmissionsData(conn, claimId);
            
            // 3. Get all remittances (type=3) ordered by event_time
            List<ClaimDetailsResponse.RemittanceData> remittances = getRemittancesData(conn, claimId);
            
            // 4. Get timeline (keep for compatibility)
            List<ClaimDetailsResponse.ClaimTimelineEvent> claimTimeline = getClaimTimeline(conn, claimId);

            long executionTime = System.currentTimeMillis() - startTime;

            // Build response with metadata
            ClaimDetailsResponse.ClaimDetailsMetadata metadata = ClaimDetailsResponse.ClaimDetailsMetadata.builder()
                    .timestamp(LocalDateTime.now())
                    .executionTimeMs(executionTime)
                    .additionalMetadata(Map.of(
                            "dataRetrievalTime", executionTime + "ms",
                            "sectionsRetrieved", 4,
                            "hasSubmission", submission != null,
                            "resubmissionsCount", resubmissions.size(),
                            "remittancesCount", remittances.size(),
                            "timelineEventsCount", claimTimeline.size(),
                            "submissionAttachmentsCount", submission.getAttachments() != null ? submission.getAttachments().size() : 0,
                            "totalResubmissionAttachmentsCount", resubmissions.stream().mapToInt(r -> r.getAttachments() != null ? r.getAttachments().size() : 0).sum(),
                            "totalRemittanceAttachmentsCount", remittances.stream().mapToInt(r -> r.getAttachments() != null ? r.getAttachments().size() : 0).sum()
                    ))
                    .build();

            ClaimDetailsResponse response = ClaimDetailsResponse.builder()
                    .claimId(claimId)
                    .submission(submission)
                    .resubmissions(resubmissions)
                    .remittances(remittances)
                    .claimTimeline(claimTimeline)
                    .metadata(metadata)
                    .build();

            log.info("Retrieved comprehensive claim details for claim ID: {} in {}ms", claimId, executionTime);
            return response;

        } catch (SQLException e) {
            log.error("Database error retrieving claim details for claim ID: {}", claimId, e);
            throw new RuntimeException("Failed to retrieve claim details due to database error", e);
        } catch (Exception e) {
            log.error("Unexpected error retrieving claim details for claim ID: {}", claimId, e);
            throw new RuntimeException("Failed to retrieve claim details", e);
        }
    }

    private ClaimDetailsResponse.ClaimBasicInfo getClaimBasicInfo(Connection conn, String claimId) throws SQLException {
        String sql = """
            SELECT
                ck.claim_id,
                c.id as claim_db_id,
                c.payer_id,
                c.provider_id,
                c.member_id,
                c.emirates_id_number,
                c.gross,
                c.patient_share,
                c.net,
                c.comments,
                c.tx_at as submission_date,
                s.id as submission_id,
                pr.name as provider_name,
                pr.provider_code,
                py.name as payer_name,
                py.payer_code
            FROM claims.claim_key ck
            JOIN claims.claim c ON c.claim_key_id = ck.id
            JOIN claims.submission s ON s.id = c.submission_id
            LEFT JOIN claims_ref.provider pr ON pr.provider_code = c.provider_id
            LEFT JOIN claims_ref.payer py ON py.payer_code = c.payer_id
            WHERE ck.claim_id = ?
            """;

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return ClaimDetailsResponse.ClaimBasicInfo.builder()
                            .claimId(rs.getString("claim_id"))
                            .claimDbId(rs.getLong("claim_db_id"))
                            .payerId(rs.getString("payer_id"))
                            .providerId(rs.getString("provider_id"))
                            .memberId(rs.getString("member_id"))
                            .emiratesIdNumber(rs.getString("emirates_id_number"))
                            .grossAmount(rs.getBigDecimal("gross"))
                            .patientShare(rs.getBigDecimal("patient_share"))
                            .netAmount(rs.getBigDecimal("net"))
                            .comments(rs.getString("comments"))
                            .submissionDate(rs.getTimestamp("submission_date") != null ? 
                                    rs.getTimestamp("submission_date").toLocalDateTime() : null)
                            .submissionId(rs.getLong("submission_id"))
                            .providerName(rs.getString("provider_name"))
                            .providerCode(rs.getString("provider_code"))
                            .payerName(rs.getString("payer_name"))
                            .payerCode(rs.getString("payer_code"))
                            .build();
                }
            }
        }

        return null;
    }

    private ClaimDetailsResponse.EncounterInfo getClaimEncounterInfo(Connection conn, String claimId) throws SQLException {
        String sql = """
            SELECT
                e.id,
                e.facility_id,
                e.type as encounter_type,
                e.patient_id,
                e.start_at,
                e.end_at,
                e.start_type,
                e.end_type,
                e.transfer_source,
                e.transfer_destination,
                f.name as facility_name,
                f.facility_code
            FROM claims.claim_key ck
            JOIN claims.claim c ON c.claim_key_id = ck.id
            LEFT JOIN claims.encounter e ON e.claim_id = c.id
            LEFT JOIN claims_ref.facility f ON f.facility_code = e.facility_id
            WHERE ck.claim_id = ?
            """;

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return ClaimDetailsResponse.EncounterInfo.builder()
                            .encounterId(rs.getLong("id"))
                            .facilityId(rs.getString("facility_id"))
                            .encounterType(rs.getString("encounter_type"))
                            .patientId(rs.getString("patient_id"))
                            .startDate(rs.getTimestamp("start_at") != null ? 
                                    rs.getTimestamp("start_at").toLocalDateTime() : null)
                            .endDate(rs.getTimestamp("end_at") != null ? 
                                    rs.getTimestamp("end_at").toLocalDateTime() : null)
                            .startType(rs.getString("start_type"))
                            .endType(rs.getString("end_type"))
                            .transferSource(rs.getString("transfer_source"))
                            .transferDestination(rs.getString("transfer_destination"))
                            .facilityName(rs.getString("facility_name"))
                            .facilityCode(rs.getString("facility_code"))
                            .build();
                }
            }
        }

        return null;
    }

    private List<ClaimDetailsResponse.DiagnosisInfo> getClaimDiagnosisInfo(Connection conn, String claimId) throws SQLException {
        String sql = """
            SELECT
                d.id,
                d.diag_type,
                d.code,
                dc.description as diagnosis_description
            FROM claims.claim_key ck
            JOIN claims.claim c ON c.claim_key_id = ck.id
            LEFT JOIN claims.diagnosis d ON d.claim_id = c.id
            LEFT JOIN claims_ref.diagnosis_code dc ON dc.code = d.code
            WHERE ck.claim_id = ?
            ORDER BY d.diag_type, d.code
            """;

        List<ClaimDetailsResponse.DiagnosisInfo> diagnoses = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    diagnoses.add(ClaimDetailsResponse.DiagnosisInfo.builder()
                            .diagnosisId(rs.getLong("id"))
                            .diagnosisType(rs.getString("diag_type"))
                            .diagnosisCode(rs.getString("code"))
                            .diagnosisDescription(rs.getString("diagnosis_description"))
                            .build());
                }
            }
        }

        return diagnoses;
    }

    private List<ClaimDetailsResponse.ActivityInfo> getClaimActivitiesInfo(Connection conn, String claimId) throws SQLException {
        String sql = """
            SELECT
                a.id,
                a.activity_id,
                a.start_at,
                a.type as activity_type,
                a.code as activity_code,
                a.quantity,
                a.net as activity_net,
                a.clinician,
                a.prior_authorization_id,
                cl.name as clinician_name,
                cl.specialty as clinician_specialty,
                ac.description as activity_description
            FROM claims.claim_key ck
            JOIN claims.claim c ON c.claim_key_id = ck.id
            LEFT JOIN claims.activity a ON a.claim_id = c.id
            LEFT JOIN claims_ref.clinician cl ON cl.clinician_code = a.clinician
            LEFT JOIN claims_ref.activity_code ac ON ac.code = a.code
            WHERE ck.claim_id = ?
            ORDER BY a.start_at, a.activity_id
            """;

        List<ClaimDetailsResponse.ActivityInfo> activities = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    activities.add(ClaimDetailsResponse.ActivityInfo.builder()
                            .activityId(rs.getLong("id"))
                            .activityNumber(rs.getString("activity_id"))
                            .startDate(rs.getTimestamp("start_at") != null ? 
                                    rs.getTimestamp("start_at").toLocalDateTime() : null)
                            .activityType(rs.getString("activity_type"))
                            .activityCode(rs.getString("activity_code"))
                            .quantity(rs.getBigDecimal("quantity"))
                            .netAmount(rs.getBigDecimal("activity_net"))
                            .clinician(rs.getString("clinician"))
                            .priorAuthorizationId(rs.getString("prior_authorization_id"))
                            .clinicianName(rs.getString("clinician_name"))
                            .clinicianSpecialty(rs.getString("clinician_specialty"))
                            .activityDescription(rs.getString("activity_description"))
                            .build());
                }
            }
        }

        return activities;
    }

    private ClaimDetailsResponse.RemittanceInfo getClaimRemittanceInfo(Connection conn, String claimId) throws SQLException {
        String sql = """
            SELECT
                rc.id,
                rc.id_payer,
                rc.provider_id as remittance_provider_id,
                rc.denial_code,
                rc.payment_reference,
                rc.date_settlement,
                r.tx_at as remittance_date,
                r.id as remittance_id
            FROM claims.claim_key ck
            JOIN claims.claim c ON c.claim_key_id = ck.id
            LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
            LEFT JOIN claims.remittance r ON r.id = rc.remittance_id
            WHERE ck.claim_id = ?
            """;

        ClaimDetailsResponse.RemittanceInfo.RemittanceInfoBuilder builder = ClaimDetailsResponse.RemittanceInfo.builder();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    builder.remittanceClaimId(rs.getLong("id"))
                            .remittancePayerId(rs.getString("id_payer"))
                            .remittanceProviderId(rs.getString("remittance_provider_id"))
                            .denialCode(rs.getString("denial_code"))
                            .paymentReference(rs.getString("payment_reference"))
                            .settlementDate(rs.getTimestamp("date_settlement") != null ? 
                                    rs.getTimestamp("date_settlement").toLocalDateTime() : null)
                            .remittanceDate(rs.getTimestamp("remittance_date") != null ? 
                                    rs.getTimestamp("remittance_date").toLocalDateTime() : null)
                            .remittanceId(rs.getLong("remittance_id"));
                }
            }
        }

        ClaimDetailsResponse.RemittanceInfo remittanceInfo = builder.build();

        // Get remittance activities if remittance info exists
        if (remittanceInfo.getRemittanceClaimId() != null) {
            remittanceInfo.setRemittanceActivities(getClaimRemittanceActivities(conn, claimId));
        }

        return remittanceInfo.getRemittanceClaimId() != null ? remittanceInfo : null;
    }

    private List<ClaimDetailsResponse.RemittanceActivityInfo> getClaimRemittanceActivities(Connection conn, String claimId) throws SQLException {
        String sql = """
            SELECT
                ra.id,
                ra.activity_id,
                ra.start_at,
                ra.type as activity_type,
                ra.code as activity_code,
                ra.quantity,
                ra.net as activity_net,
                ra.list_price,
                ra.gross,
                ra.patient_share,
                ra.payment_amount,
                ra.denial_code as activity_denial_code,
                ra.clinician
            FROM claims.claim_key ck
            JOIN claims.claim c ON c.claim_key_id = ck.id
            LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id
            LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id
            WHERE ck.claim_id = ?
            ORDER BY ra.start_at, ra.activity_id
            """;

        List<ClaimDetailsResponse.RemittanceActivityInfo> remittanceActivities = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    remittanceActivities.add(ClaimDetailsResponse.RemittanceActivityInfo.builder()
                            .remittanceActivityId(rs.getLong("id"))
                            .activityId(rs.getString("activity_id"))
                            .startDate(rs.getTimestamp("start_at") != null ? 
                                    rs.getTimestamp("start_at").toLocalDateTime() : null)
                            .activityType(rs.getString("activity_type"))
                            .activityCode(rs.getString("activity_code"))
                            .quantity(rs.getBigDecimal("quantity"))
                            .netAmount(rs.getBigDecimal("activity_net"))
                            .listPrice(rs.getBigDecimal("list_price"))
                            .grossAmount(rs.getBigDecimal("gross"))
                            .patientShare(rs.getBigDecimal("patient_share"))
                            .paymentAmount(rs.getBigDecimal("payment_amount"))
                            .denialCode(rs.getString("activity_denial_code"))
                            .clinician(rs.getString("clinician"))
                            .build());
                }
            }
        }

        return remittanceActivities;
    }

    private List<ClaimDetailsResponse.ClaimTimelineEvent> getClaimTimeline(Connection conn, String claimId) throws SQLException {
        String sql = """
            SELECT
                ce.id,
                ce.event_time,
                ce.type as event_type,
                ce.submission_id,
                ce.remittance_id,
                cst.status as current_status,
                cst.status_time as status_time,
                cr.resubmission_type,
                cr.comment as resubmission_comment
            FROM claims.claim_key ck
            JOIN claims.claim_event ce ON ce.claim_key_id = ck.id
            LEFT JOIN claims.claim_status_timeline cst ON cst.claim_event_id = ce.id
            LEFT JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce.id
            WHERE ck.claim_id = ?
            ORDER BY ce.event_time DESC
            """;

        List<ClaimDetailsResponse.ClaimTimelineEvent> timeline = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    timeline.add(ClaimDetailsResponse.ClaimTimelineEvent.builder()
                            .eventId(rs.getLong("id"))
                            .eventTime(rs.getTimestamp("event_time") != null ? 
                                    rs.getTimestamp("event_time").toLocalDateTime() : null)
                            .eventType(getEventTypeDescription(rs.getInt("event_type")))
                            .submissionId(rs.getLong("submission_id"))
                            .remittanceId(rs.getLong("remittance_id"))
                            .currentStatus(rs.getInt("current_status"))
                            .statusTime(rs.getTimestamp("status_time") != null ? 
                                    rs.getTimestamp("status_time").toLocalDateTime() : null)
                            .resubmissionType(rs.getString("resubmission_type"))
                            .resubmissionComment(rs.getString("resubmission_comment"))
                            .build());
                }
            }
        }

        return timeline;
    }

    private List<ClaimDetailsResponse.AttachmentInfo> getClaimAttachments(Connection conn, String claimId) throws SQLException {
        String sql = """
            SELECT
                ca.id,
                ca.file_name,
                ca.mime_type,
                ca.data_length,
                ca.created_at,
                ce.event_time as attachment_event_time,
                ce.type as attachment_event_type
            FROM claims.claim_key ck
            JOIN claims.claim_attachment ca ON ca.claim_key_id = ck.id
            LEFT JOIN claims.claim_event ce ON ce.id = ca.claim_event_id
            WHERE ck.claim_id = ?
            ORDER BY ca.created_at DESC
            """;

        List<ClaimDetailsResponse.AttachmentInfo> attachments = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    attachments.add(ClaimDetailsResponse.AttachmentInfo.builder()
                            .attachmentId(rs.getLong("id"))
                            .fileName(rs.getString("file_name"))
                            .mimeType(rs.getString("mime_type"))
                            .dataLength(rs.getInt("data_length"))
                            .createdAt(rs.getTimestamp("created_at") != null ? 
                                    rs.getTimestamp("created_at").toLocalDateTime() : null)
                            .attachmentEventTime(rs.getTimestamp("attachment_event_time") != null ? 
                                    rs.getTimestamp("attachment_event_time").toLocalDateTime() : null)
                            .attachmentEventType(getEventTypeDescription(rs.getInt("attachment_event_type")))
                            .build());
                }
            }
        }

        return attachments;
    }

    private List<ClaimDetailsResponse.TransactionType> getClaimTransactionTypes(Connection conn, String claimId) throws SQLException {
        String sql = """
            SELECT
                ce.id,
                ce.event_time,
                ce.type as event_type,
                CASE
                    WHEN ce.type = 1 THEN 'Initial Submission'
                    WHEN ce.type = 2 THEN CONCAT('Resubmission - ', COALESCE(cr.resubmission_type, 'Unknown'))
                    WHEN ce.type = 3 THEN 'Remittance'
                    ELSE CONCAT('Event Type ', ce.type)
                END as transaction_type,
                CASE
                    WHEN ce.type = 1 THEN 'First time claim submission'
                    WHEN ce.type = 2 THEN CONCAT('Claim resubmitted for: ', COALESCE(cr.comment, 'No comment'))
                    WHEN ce.type = 3 THEN 'Payer processed and returned remittance'
                    ELSE 'Other claim event'
                END as transaction_description,
                s.id as submission_id,
                r.id as remittance_id,
                cr.resubmission_type,
                cr.comment as resubmission_comment
            FROM claims.claim_key ck
            JOIN claims.claim_event ce ON ce.claim_key_id = ck.id
            LEFT JOIN claims.submission s ON s.id = ce.submission_id
            LEFT JOIN claims.remittance r ON r.id = ce.remittance_id
            LEFT JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce.id
            WHERE ck.claim_id = ?
            ORDER BY ce.event_time ASC
            """;

        List<ClaimDetailsResponse.TransactionType> transactionTypes = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    transactionTypes.add(ClaimDetailsResponse.TransactionType.builder()
                            .transactionId(rs.getLong("id"))
                            .eventTime(rs.getTimestamp("event_time") != null ? 
                                    rs.getTimestamp("event_time").toLocalDateTime() : null)
                            .eventType(rs.getInt("event_type"))
                            .transactionType(rs.getString("transaction_type"))
                            .transactionDescription(rs.getString("transaction_description"))
                            .submissionId(rs.getLong("submission_id"))
                            .remittanceId(rs.getLong("remittance_id"))
                            .resubmissionType(rs.getString("resubmission_type"))
                            .resubmissionComment(rs.getString("resubmission_comment"))
                            .build());
                }
            }
        }

        return transactionTypes;
    }

    private String getEventTypeDescription(int eventType) {
        return switch (eventType) {
            case 1 -> "Submission";
            case 2 -> "Resubmission";
            case 3 -> "Remittance";
            default -> "Unknown Event";
        };
    }

    /**
     * Get original submission data (type=1) with file name and all associated data
     */
    private ClaimDetailsResponse.SubmissionData getSubmissionData(Connection conn, String claimId) throws SQLException {
        String sql = """
            SELECT 
                ce.id as claim_event_id,
                if.id as ingestion_file_id,
                if.file_name,
                ce.event_time as submission_date
            FROM claims.claim_event ce
            JOIN claims.ingestion_file if ON if.id = ce.ingestion_file_id
            WHERE ce.claim_key_id = (SELECT id FROM claims.claim_key WHERE claim_id = ?)
              AND ce.type = 1
            """;

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    // Get all the existing data using existing methods
                    ClaimDetailsResponse.ClaimBasicInfo claimInfo = getClaimBasicInfo(conn, claimId);
                    ClaimDetailsResponse.EncounterInfo encounterInfo = getClaimEncounterInfo(conn, claimId);
                    List<ClaimDetailsResponse.DiagnosisInfo> diagnosisInfo = getClaimDiagnosisInfo(conn, claimId);
                    List<ClaimDetailsResponse.ActivityInfo> activitiesInfo = getClaimActivitiesInfo(conn, claimId);
                    
                    // Get attachments for this specific submission event
                    List<ClaimDetailsResponse.AttachmentInfo> attachments = getAttachmentsForEvent(conn, claimId, rs.getLong("claim_event_id"));

                    return ClaimDetailsResponse.SubmissionData.builder()
                            .fileName(rs.getString("file_name"))
                            .ingestionFileId(rs.getLong("ingestion_file_id"))
                            .submissionDate(rs.getTimestamp("submission_date") != null ? 
                                    rs.getTimestamp("submission_date").toLocalDateTime() : null)
                            .claimInfo(claimInfo)
                            .encounterInfo(encounterInfo)
                            .diagnosisInfo(diagnosisInfo)
                            .activitiesInfo(activitiesInfo)
                            .attachments(attachments)
                            .build();
                }
            }
        }

        return null;
    }

    /**
     * Get all resubmissions (type=2) with activity snapshots and file names
     */
    private List<ClaimDetailsResponse.ResubmissionData> getResubmissionsData(Connection conn, String claimId) throws SQLException {
        String sql = """
            SELECT 
                ce.id as claim_event_id,
                if.id as ingestion_file_id,
                if.file_name,
                ce.event_time as resubmission_date,
                cr.resubmission_type,
                cr.comment as resubmission_comment
            FROM claims.claim_event ce
            JOIN claims.ingestion_file if ON if.id = ce.ingestion_file_id
            JOIN claims.claim_resubmission cr ON cr.claim_event_id = ce.id
            WHERE ce.claim_key_id = (SELECT id FROM claims.claim_key WHERE claim_id = ?)
              AND ce.type = 2
            ORDER BY ce.event_time ASC
            """;

        List<ClaimDetailsResponse.ResubmissionData> resubmissions = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Long claimEventId = rs.getLong("claim_event_id");
                    
                    // Get activity snapshots for this resubmission event
                    List<ClaimDetailsResponse.ActivityInfo> activitiesInfo = getActivitySnapshotsForEvent(conn, claimEventId);
                    
                    // Get attachments for this specific resubmission event
                    List<ClaimDetailsResponse.AttachmentInfo> attachments = getAttachmentsForEvent(conn, claimId, claimEventId);

                    resubmissions.add(ClaimDetailsResponse.ResubmissionData.builder()
                            .fileName(rs.getString("file_name"))
                            .ingestionFileId(rs.getLong("ingestion_file_id"))
                            .claimEventId(claimEventId)
                            .resubmissionDate(rs.getTimestamp("resubmission_date") != null ? 
                                    rs.getTimestamp("resubmission_date").toLocalDateTime() : null)
                            .resubmissionType(rs.getString("resubmission_type"))
                            .resubmissionComment(rs.getString("resubmission_comment"))
                            .activitiesInfo(activitiesInfo)
                            .attachments(attachments)
                            .build());
                }
            }
        }

        return resubmissions;
    }

    /**
     * Get all remittances (type=3) with activities and file names
     */
    private List<ClaimDetailsResponse.RemittanceData> getRemittancesData(Connection conn, String claimId) throws SQLException {
        String sql = """
            SELECT 
                ce.id as claim_event_id,
                if.id as ingestion_file_id,
                if.file_name,
                ce.event_time as remittance_date,
                r.id as remittance_id,
                rc.id as remittance_claim_id,
                rc.payment_reference,
                rc.date_settlement,
                rc.denial_code,
                rc.id_payer,
                rc.provider_id
            FROM claims.claim_event ce
            JOIN claims.ingestion_file if ON if.id = ce.ingestion_file_id
            JOIN claims.remittance r ON r.id = ce.remittance_id
            JOIN claims.remittance_claim rc ON rc.remittance_id = r.id 
                AND rc.claim_key_id = ce.claim_key_id
            WHERE ce.claim_key_id = (SELECT id FROM claims.claim_key WHERE claim_id = ?)
              AND ce.type = 3
            ORDER BY ce.event_time ASC
            """;

        List<ClaimDetailsResponse.RemittanceData> remittances = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Long remittanceClaimId = rs.getLong("remittance_claim_id");
                    
                    // Get remittance activities for this remittance
                    List<ClaimDetailsResponse.RemittanceActivityInfo> activities = getRemittanceActivitiesForClaim(conn, remittanceClaimId);
                    
                    // Get attachments for this specific remittance event
                    List<ClaimDetailsResponse.AttachmentInfo> attachments = getAttachmentsForEvent(conn, claimId, rs.getLong("claim_event_id"));

                    remittances.add(ClaimDetailsResponse.RemittanceData.builder()
                            .fileName(rs.getString("file_name"))
                            .ingestionFileId(rs.getLong("ingestion_file_id"))
                            .remittanceId(rs.getLong("remittance_id"))
                            .remittanceClaimId(remittanceClaimId)
                            .remittanceDate(rs.getTimestamp("remittance_date") != null ? 
                                    rs.getTimestamp("remittance_date").toLocalDateTime() : null)
                            .paymentReference(rs.getString("payment_reference"))
                            .settlementDate(rs.getTimestamp("date_settlement") != null ? 
                                    rs.getTimestamp("date_settlement").toLocalDateTime() : null)
                            .denialCode(rs.getString("denial_code"))
                            .remittancePayerId(rs.getString("id_payer"))
                            .remittanceProviderId(rs.getString("provider_id"))
                            .activities(activities)
                            .attachments(attachments)
                            .build());
                }
            }
        }

        return remittances;
    }

    /**
     * Get attachments for a specific claim event
     */
    private List<ClaimDetailsResponse.AttachmentInfo> getAttachmentsForEvent(Connection conn, String claimId, Long claimEventId) throws SQLException {
        String sql = """
            SELECT 
                ca.id,
                ca.file_name,
                ca.mime_type,
                ca.data_length,
                ca.created_at,
                ce.event_time as attachment_event_time,
                ce.type as attachment_event_type
            FROM claims.claim_attachment ca
            LEFT JOIN claims.claim_event ce ON ce.id = ca.claim_event_id
            WHERE ca.claim_key_id = (SELECT id FROM claims.claim_key WHERE claim_id = ?)
              AND ca.claim_event_id = ?
            ORDER BY ca.created_at ASC
            """;

        List<ClaimDetailsResponse.AttachmentInfo> attachments = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);
            stmt.setLong(2, claimEventId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    attachments.add(ClaimDetailsResponse.AttachmentInfo.builder()
                            .attachmentId(rs.getLong("id"))
                            .fileName(rs.getString("file_name"))
                            .mimeType(rs.getString("mime_type"))
                            .dataLength(rs.getInt("data_length"))
                            .createdAt(rs.getTimestamp("created_at") != null ? 
                                    rs.getTimestamp("created_at").toLocalDateTime() : null)
                            .attachmentEventTime(rs.getTimestamp("attachment_event_time") != null ? 
                                    rs.getTimestamp("attachment_event_time").toLocalDateTime() : null)
                            .attachmentEventType(getEventTypeDescription(rs.getInt("attachment_event_type")))
                            .build());
                }
            }
        }

        return attachments;
    }

    /**
     * Get activity snapshots for a specific claim event (for resubmissions)
     */
    private List<ClaimDetailsResponse.ActivityInfo> getActivitySnapshotsForEvent(Connection conn, Long claimEventId) throws SQLException {
        String sql = """
            SELECT 
                cea.activity_id_at_event,
                cea.start_at_event,
                cea.type_at_event,
                cea.code_at_event,
                cea.quantity_at_event,
                cea.net_at_event,
                cea.clinician_at_event,
                cea.prior_authorization_id_at_event,
                cea.list_price_at_event,
                cea.gross_at_event,
                cea.patient_share_at_event,
                cea.payment_amount_at_event,
                cea.denial_code_at_event
            FROM claims.claim_event_activity cea
            WHERE cea.claim_event_id = ?
            ORDER BY cea.activity_id_at_event
            """;

        List<ClaimDetailsResponse.ActivityInfo> activities = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setLong(1, claimEventId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    activities.add(ClaimDetailsResponse.ActivityInfo.builder()
                            .activityNumber(rs.getString("activity_id_at_event"))
                            .startDate(rs.getTimestamp("start_at_event") != null ? 
                                    rs.getTimestamp("start_at_event").toLocalDateTime() : null)
                            .activityType(rs.getString("type_at_event"))
                            .activityCode(rs.getString("code_at_event"))
                            .quantity(rs.getBigDecimal("quantity_at_event"))
                            .netAmount(rs.getBigDecimal("net_at_event"))
                            .clinician(rs.getString("clinician_at_event"))
                            .priorAuthorizationId(rs.getString("prior_authorization_id_at_event"))
                            .build());
                }
            }
        }

        return activities;
    }

    /**
     * Get remittance activities for a specific remittance claim
     */
    private List<ClaimDetailsResponse.RemittanceActivityInfo> getRemittanceActivitiesForClaim(Connection conn, Long remittanceClaimId) throws SQLException {
        String sql = """
            SELECT 
                ra.id,
                ra.activity_id,
                ra.start_at,
                ra.type as activity_type,
                ra.code as activity_code,
                ra.quantity,
                ra.net as activity_net,
                ra.list_price,
                ra.gross,
                ra.patient_share,
                ra.payment_amount,
                ra.denial_code as activity_denial_code,
                ra.clinician
            FROM claims.remittance_activity ra
            WHERE ra.remittance_claim_id = ?
            ORDER BY ra.activity_id
            """;

        List<ClaimDetailsResponse.RemittanceActivityInfo> activities = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setLong(1, remittanceClaimId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    activities.add(ClaimDetailsResponse.RemittanceActivityInfo.builder()
                            .remittanceActivityId(rs.getLong("id"))
                            .activityId(rs.getString("activity_id"))
                            .startDate(rs.getTimestamp("start_at") != null ? 
                                    rs.getTimestamp("start_at").toLocalDateTime() : null)
                            .activityType(rs.getString("activity_type"))
                            .activityCode(rs.getString("activity_code"))
                            .quantity(rs.getBigDecimal("quantity"))
                            .netAmount(rs.getBigDecimal("activity_net"))
                            .listPrice(rs.getBigDecimal("list_price"))
                            .grossAmount(rs.getBigDecimal("gross"))
                            .patientShare(rs.getBigDecimal("patient_share"))
                            .paymentAmount(rs.getBigDecimal("payment_amount"))
                            .denialCode(rs.getString("activity_denial_code"))
                            .clinician(rs.getString("clinician"))
                            .build());
                }
            }
        }

        return activities;
    }
}
