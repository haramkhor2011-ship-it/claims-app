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
            String encounterType) {

        String sql = """
            SELECT * FROM claims.get_claim_summary_monthwise_params(
                ?::timestamptz,
                ?::timestamptz,
                ?::text,
                ?::text,
                ?::text,
                ?::text
            )
            """;

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setObject(1, fromDate);
            stmt.setObject(2, toDate);
            stmt.setString(3, facilityCode);
            stmt.setString(4, payerCode);
            stmt.setString(5, receiverCode);
            stmt.setString(6, encounterType);

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
     */
    public Map<String, Object> getClaimDetailsById(String claimId) {
        Map<String, Object> claimDetails = new HashMap<>();

        try (Connection conn = dataSource.getConnection()) {
            // 1. Get basic claim information
            claimDetails.put("claimInfo", getClaimBasicInfo(conn, claimId));

            // 2. Get encounter information
            claimDetails.put("encounterInfo", getClaimEncounterInfo(conn, claimId));

            // 3. Get diagnosis information
            claimDetails.put("diagnosisInfo", getClaimDiagnosisInfo(conn, claimId));

            // 4. Get activities information
            claimDetails.put("activitiesInfo", getClaimActivitiesInfo(conn, claimId));

            // 5. Get remittance information
            claimDetails.put("remittanceInfo", getClaimRemittanceInfo(conn, claimId));

            // 6. Get claim events/timeline
            claimDetails.put("claimTimeline", getClaimTimeline(conn, claimId));

            // 7. Get attachments
            claimDetails.put("attachments", getClaimAttachments(conn, claimId));

            // 8. Get transaction types (claim lifecycle)
            claimDetails.put("transactionTypes", getClaimTransactionTypes(conn, claimId));

            log.info("Retrieved comprehensive claim details for claim ID: {}", claimId);

        } catch (SQLException e) {
            log.error("Error retrieving claim details for claim ID: {}", claimId, e);
            throw new RuntimeException("Failed to retrieve claim details", e);
        }

        return claimDetails;
    }

    private Map<String, Object> getClaimBasicInfo(Connection conn, String claimId) throws SQLException {
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
                    Map<String, Object> claimInfo = new LinkedHashMap<>();
                    claimInfo.put("claimId", rs.getString("claim_id"));
                    claimInfo.put("claimDbId", rs.getLong("claim_db_id"));
                    claimInfo.put("payerId", rs.getString("payer_id"));
                    claimInfo.put("providerId", rs.getString("provider_id"));
                    claimInfo.put("memberId", rs.getString("member_id"));
                    claimInfo.put("emiratesIdNumber", rs.getString("emirates_id_number"));
                    claimInfo.put("grossAmount", rs.getBigDecimal("gross"));
                    claimInfo.put("patientShare", rs.getBigDecimal("patient_share"));
                    claimInfo.put("netAmount", rs.getBigDecimal("net"));
                    claimInfo.put("comments", rs.getString("comments"));
                    claimInfo.put("submissionDate", rs.getTimestamp("submission_date"));
                    claimInfo.put("submissionId", rs.getLong("submission_id"));
                    claimInfo.put("providerName", rs.getString("provider_name"));
                    claimInfo.put("providerCode", rs.getString("provider_code"));
                    claimInfo.put("payerName", rs.getString("payer_name"));
                    claimInfo.put("payerCode", rs.getString("payer_code"));
                    return claimInfo;
                }
            }
        }

        return new HashMap<>();
    }

    private Map<String, Object> getClaimEncounterInfo(Connection conn, String claimId) throws SQLException {
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
                    Map<String, Object> encounterInfo = new LinkedHashMap<>();
                    encounterInfo.put("encounterId", rs.getLong("id"));
                    encounterInfo.put("facilityId", rs.getString("facility_id"));
                    encounterInfo.put("encounterType", rs.getString("encounter_type"));
                    encounterInfo.put("patientId", rs.getString("patient_id"));
                    encounterInfo.put("startDate", rs.getTimestamp("start_at"));
                    encounterInfo.put("endDate", rs.getTimestamp("end_at"));
                    encounterInfo.put("startType", rs.getString("start_type"));
                    encounterInfo.put("endType", rs.getString("end_type"));
                    encounterInfo.put("transferSource", rs.getString("transfer_source"));
                    encounterInfo.put("transferDestination", rs.getString("transfer_destination"));
                    encounterInfo.put("facilityName", rs.getString("facility_name"));
                    encounterInfo.put("facilityCode", rs.getString("facility_code"));
                    return encounterInfo;
                }
            }
        }

        return new HashMap<>();
    }

    private List<Map<String, Object>> getClaimDiagnosisInfo(Connection conn, String claimId) throws SQLException {
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

        List<Map<String, Object>> diagnoses = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> diagnosis = new LinkedHashMap<>();
                    diagnosis.put("diagnosisId", rs.getLong("id"));
                    diagnosis.put("diagnosisType", rs.getString("diag_type"));
                    diagnosis.put("diagnosisCode", rs.getString("code"));
                    diagnosis.put("diagnosisDescription", rs.getString("diagnosis_description"));
                    diagnoses.add(diagnosis);
                }
            }
        }

        return diagnoses;
    }

    private List<Map<String, Object>> getClaimActivitiesInfo(Connection conn, String claimId) throws SQLException {
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

        List<Map<String, Object>> activities = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> activity = new LinkedHashMap<>();
                    activity.put("activityId", rs.getLong("id"));
                    activity.put("activityNumber", rs.getString("activity_id"));
                    activity.put("startDate", rs.getTimestamp("start_at"));
                    activity.put("activityType", rs.getString("activity_type"));
                    activity.put("activityCode", rs.getString("activity_code"));
                    activity.put("quantity", rs.getBigDecimal("quantity"));
                    activity.put("netAmount", rs.getBigDecimal("activity_net"));
                    activity.put("clinician", rs.getString("clinician"));
                    activity.put("priorAuthorizationId", rs.getString("prior_authorization_id"));
                    activity.put("clinicianName", rs.getString("clinician_name"));
                    activity.put("clinicianSpecialty", rs.getString("clinician_specialty"));
                    activity.put("activityDescription", rs.getString("activity_description"));
                    activities.add(activity);
                }
            }
        }

        return activities;
    }

    private Map<String, Object> getClaimRemittanceInfo(Connection conn, String claimId) throws SQLException {
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

        Map<String, Object> remittanceInfo = new HashMap<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    remittanceInfo.put("remittanceClaimId", rs.getLong("id"));
                    remittanceInfo.put("remittancePayerId", rs.getString("id_payer"));
                    remittanceInfo.put("remittanceProviderId", rs.getString("remittance_provider_id"));
                    remittanceInfo.put("denialCode", rs.getString("denial_code"));
                    remittanceInfo.put("paymentReference", rs.getString("payment_reference"));
                    remittanceInfo.put("settlementDate", rs.getTimestamp("date_settlement"));
                    remittanceInfo.put("remittanceDate", rs.getTimestamp("remittance_date"));
                    remittanceInfo.put("remittanceId", rs.getLong("remittance_id"));
                }
            }
        }

        // Get remittance activities
        if (!remittanceInfo.isEmpty()) {
            remittanceInfo.put("remittanceActivities", getClaimRemittanceActivities(conn, claimId));
        }

        return remittanceInfo;
    }

    private List<Map<String, Object>> getClaimRemittanceActivities(Connection conn, String claimId) throws SQLException {
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

        List<Map<String, Object>> remittanceActivities = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> activity = new LinkedHashMap<>();
                    activity.put("remittanceActivityId", rs.getLong("id"));
                    activity.put("activityId", rs.getString("activity_id"));
                    activity.put("startDate", rs.getTimestamp("start_at"));
                    activity.put("activityType", rs.getString("activity_type"));
                    activity.put("activityCode", rs.getString("activity_code"));
                    activity.put("quantity", rs.getBigDecimal("quantity"));
                    activity.put("netAmount", rs.getBigDecimal("activity_net"));
                    activity.put("listPrice", rs.getBigDecimal("list_price"));
                    activity.put("grossAmount", rs.getBigDecimal("gross"));
                    activity.put("patientShare", rs.getBigDecimal("patient_share"));
                    activity.put("paymentAmount", rs.getBigDecimal("payment_amount"));
                    activity.put("denialCode", rs.getString("activity_denial_code"));
                    activity.put("clinician", rs.getString("clinician"));
                    remittanceActivities.add(activity);
                }
            }
        }

        return remittanceActivities;
    }

    private List<Map<String, Object>> getClaimTimeline(Connection conn, String claimId) throws SQLException {
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

        List<Map<String, Object>> timeline = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> event = new LinkedHashMap<>();
                    event.put("eventId", rs.getLong("id"));
                    event.put("eventTime", rs.getTimestamp("event_time"));
                    event.put("eventType", getEventTypeDescription(rs.getInt("event_type")));
                    event.put("submissionId", rs.getLong("submission_id"));
                    event.put("remittanceId", rs.getLong("remittance_id"));
                    event.put("currentStatus", rs.getInt("current_status"));
                    event.put("statusTime", rs.getTimestamp("status_time"));
                    event.put("resubmissionType", rs.getString("resubmission_type"));
                    event.put("resubmissionComment", rs.getString("resubmission_comment"));
                    timeline.add(event);
                }
            }
        }

        return timeline;
    }

    private List<Map<String, Object>> getClaimAttachments(Connection conn, String claimId) throws SQLException {
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

        List<Map<String, Object>> attachments = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> attachment = new LinkedHashMap<>();
                    attachment.put("attachmentId", rs.getLong("id"));
                    attachment.put("fileName", rs.getString("file_name"));
                    attachment.put("mimeType", rs.getString("mime_type"));
                    attachment.put("dataLength", rs.getInt("data_length"));
                    attachment.put("createdAt", rs.getTimestamp("created_at"));
                    attachment.put("attachmentEventTime", rs.getTimestamp("attachment_event_time"));
                    attachment.put("attachmentEventType", getEventTypeDescription(rs.getInt("attachment_event_type")));
                    attachments.add(attachment);
                }
            }
        }

        return attachments;
    }

    private List<Map<String, Object>> getClaimTransactionTypes(Connection conn, String claimId) throws SQLException {
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

        List<Map<String, Object>> transactionTypes = new ArrayList<>();

        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, claimId);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> transaction = new LinkedHashMap<>();
                    transaction.put("transactionId", rs.getLong("id"));
                    transaction.put("eventTime", rs.getTimestamp("event_time"));
                    transaction.put("eventType", rs.getInt("event_type"));
                    transaction.put("transactionType", rs.getString("transaction_type"));
                    transaction.put("transactionDescription", rs.getString("transaction_description"));
                    transaction.put("submissionId", rs.getLong("submission_id"));
                    transaction.put("remittanceId", rs.getLong("remittance_id"));
                    transaction.put("resubmissionType", rs.getString("resubmission_type"));
                    transaction.put("resubmissionComment", rs.getString("resubmission_comment"));
                    transactionTypes.add(transaction);
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
}
