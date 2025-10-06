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
 * Service for Remittance Advice Payerwise Report
 *
 * This service provides data access methods for the three tabs of the
 * Remittance Advice Payerwise report:
 * - Header Tab (Provider/Authorization level)
 * - Claim Wise Tab (Claim level details)
 * - Activity Wise Tab (Line-item level details)
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RemittanceAdvicePayerwiseReportService {

    private final DataSource dataSource;

    /**
     * Get Header Tab data for Remittance Advice Payerwise report
     */
    public List<Map<String, Object>> getHeaderTabData(
            LocalDateTime fromDate,
            LocalDateTime toDate,
            String facilityCode,
            String payerCode,
            String receiverCode,
            String sortBy,
            String sortDirection,
            Integer page,
            Integer size) {

        // Build ORDER BY clause
        String orderByClause = buildOrderByClause(sortBy, sortDirection, "total_paid_amount", "DESC");

        String sql = """
            SELECT
                ordering_clinician_name,
                ordering_clinician,
                clinician_id,
                clinician_name,
                prior_authorization_id,
                xml_file_name,
                remittance_comments,
                total_claims,
                total_activities,
                total_billed_amount,
                total_paid_amount,
                total_denied_amount,
                collection_rate,
                denied_activities_count,
                facility_id,
                facility_name,
                payer_id,
                payer_name,
                receiver_id,
                receiver_name,
                remittance_date,
                submission_date
            FROM claims.v_remittance_advice_header
            WHERE (?::timestamptz IS NULL OR remittance_date >= ?::timestamptz)
              AND (?::timestamptz IS NULL OR remittance_date <= ?::timestamptz)
              AND (?::text IS NULL OR facility_id = ?::text)
              AND (?::text IS NULL OR payer_id = ?::text)
              AND (?::text IS NULL OR receiver_id = ?::text)
            """ + orderByClause;

        // Add pagination if specified
        if (page != null && size != null && page >= 0 && size > 0) {
            sql += " LIMIT ? OFFSET ?";
        }

        List<Map<String, Object>> results = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            // Set parameters
            int paramIndex = 1;
            stmt.setObject(paramIndex++, fromDate);
            stmt.setObject(paramIndex++, fromDate);
            stmt.setObject(paramIndex++, toDate);
            stmt.setObject(paramIndex++, toDate);
            stmt.setString(paramIndex++, facilityCode);
            stmt.setString(paramIndex++, facilityCode);
            stmt.setString(paramIndex++, payerCode);
            stmt.setString(paramIndex++, payerCode);
            stmt.setString(paramIndex++, receiverCode);
            stmt.setString(paramIndex++, receiverCode);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("orderingClinicianName", rs.getString("ordering_clinician_name"));
                    row.put("orderingClinician", rs.getString("ordering_clinician"));
                    row.put("clinicianId", rs.getString("clinician_id"));
                    row.put("clinicianName", rs.getString("clinician_name"));
                    row.put("priorAuthorizationId", rs.getString("prior_authorization_id"));
                    row.put("xmlFileName", rs.getString("xml_file_name"));
                    row.put("remittanceComments", rs.getString("remittance_comments"));
                    row.put("totalClaims", rs.getLong("total_claims"));
                    row.put("totalActivities", rs.getLong("total_activities"));
                    row.put("totalBilledAmount", rs.getBigDecimal("total_billed_amount"));
                    row.put("totalPaidAmount", rs.getBigDecimal("total_paid_amount"));
                    row.put("totalDeniedAmount", rs.getBigDecimal("total_denied_amount"));
                    row.put("collectionRate", rs.getBigDecimal("collection_rate"));
                    row.put("deniedActivitiesCount", rs.getLong("denied_activities_count"));
                    row.put("facilityId", rs.getString("facility_id"));
                    row.put("facilityName", rs.getString("facility_name"));
                    row.put("payerId", rs.getString("payer_id"));
                    row.put("payerName", rs.getString("payer_name"));
                    row.put("receiverId", rs.getString("receiver_id"));
                    row.put("receiverName", rs.getString("receiver_name"));
                    row.put("remittanceDate", rs.getTimestamp("remittance_date"));
                    row.put("submissionDate", rs.getTimestamp("submission_date"));
                    results.add(row);
                }
            }

            log.info("Retrieved {} header tab records for Remittance Advice Payerwise report", results.size());

        } catch (SQLException e) {
            log.error("Error retrieving header tab data for Remittance Advice Payerwise report", e);
            throw new RuntimeException("Failed to retrieve header tab data", e);
        }

        return results;
    }

    /**
     * Get Claim Wise Tab data for Remittance Advice Payerwise report
     */
    public List<Map<String, Object>> getClaimWiseTabData(
            LocalDateTime fromDate,
            LocalDateTime toDate,
            String facilityCode,
            String payerCode,
            String receiverCode,
            String paymentReference,
            String sortBy,
            String sortDirection,
            Integer page,
            Integer size) {

        // Build ORDER BY clause
        String orderByClause = buildClaimWiseOrderByClause(sortBy, sortDirection);

        String sql = """
            SELECT
                payer_name,
                transaction_date,
                encounter_start,
                claim_number,
                id_payer,
                member_id,
                payment_reference,
                claim_activity_number,
                start_date,
                facility_group,
                health_authority,
                facility_id,
                facility_name,
                receiver_id,
                receiver_name,
                payer_id,
                claim_amount,
                remittance_amount,
                xml_file_name,
                activity_count,
                total_paid,
                total_denied,
                collection_rate,
                denied_count
            FROM claims.v_remittance_advice_claim_wise
            WHERE (?::timestamptz IS NULL OR transaction_date >= ?::timestamptz)
              AND (?::timestamptz IS NULL OR transaction_date <= ?::timestamptz)
              AND (?::text IS NULL OR facility_id = ?::text)
              AND (?::text IS NULL OR payer_id = ?::text)
              AND (?::text IS NULL OR receiver_id = ?::text)
              AND (?::text IS NULL OR payment_reference = ?::text)
            """ + orderByClause;

        // Add pagination if specified
        if (page != null && size != null && page >= 0 && size > 0) {
            sql += " LIMIT ? OFFSET ?";
        }

        List<Map<String, Object>> results = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            // Set parameters
            int paramIndex = 1;
            stmt.setObject(paramIndex++, fromDate);
            stmt.setObject(paramIndex++, fromDate);
            stmt.setObject(paramIndex++, toDate);
            stmt.setObject(paramIndex++, toDate);
            stmt.setString(paramIndex++, facilityCode);
            stmt.setString(paramIndex++, facilityCode);
            stmt.setString(paramIndex++, payerCode);
            stmt.setString(paramIndex++, payerCode);
            stmt.setString(paramIndex++, receiverCode);
            stmt.setString(paramIndex++, receiverCode);
            stmt.setString(paramIndex++, paymentReference);
            stmt.setString(paramIndex++, paymentReference);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("payerName", rs.getString("payer_name"));
                    row.put("transactionDate", rs.getTimestamp("transaction_date"));
                    row.put("encounterStart", rs.getTimestamp("encounter_start"));
                    row.put("claimNumber", rs.getString("claim_number"));
                    row.put("idPayer", rs.getString("id_payer"));
                    row.put("memberId", rs.getString("member_id"));
                    row.put("paymentReference", rs.getString("payment_reference"));
                    row.put("claimActivityNumber", rs.getString("claim_activity_number"));
                    row.put("startDate", rs.getTimestamp("start_date"));
                    row.put("facilityGroup", rs.getString("facility_group"));
                    row.put("healthAuthority", rs.getString("health_authority"));
                    row.put("facilityId", rs.getString("facility_id"));
                    row.put("facilityName", rs.getString("facility_name"));
                    row.put("receiverId", rs.getString("receiver_id"));
                    row.put("receiverName", rs.getString("receiver_name"));
                    row.put("payerId", rs.getString("payer_id"));
                    row.put("claimAmount", rs.getBigDecimal("claim_amount"));
                    row.put("remittanceAmount", rs.getBigDecimal("remittance_amount"));
                    row.put("xmlFileName", rs.getString("xml_file_name"));
                    row.put("activityCount", rs.getLong("activity_count"));
                    row.put("totalPaid", rs.getBigDecimal("total_paid"));
                    row.put("totalDenied", rs.getBigDecimal("total_denied"));
                    row.put("collectionRate", rs.getBigDecimal("collection_rate"));
                    row.put("deniedCount", rs.getLong("denied_count"));
                    results.add(row);
                }
            }

            log.info("Retrieved {} claim wise tab records for Remittance Advice Payerwise report", results.size());

        } catch (SQLException e) {
            log.error("Error retrieving claim wise tab data for Remittance Advice Payerwise report", e);
            throw new RuntimeException("Failed to retrieve claim wise tab data", e);
        }

        return results;
    }

    /**
     * Get Activity Wise Tab data for Remittance Advice Payerwise report
     */
    public List<Map<String, Object>> getActivityWiseTabData(
            LocalDateTime fromDate,
            LocalDateTime toDate,
            String facilityCode,
            String payerCode,
            String receiverCode,
            String paymentReference,
            String sortBy,
            String sortDirection,
            Integer page,
            Integer size) {

        // Build ORDER BY clause
        String orderByClause = buildActivityWiseOrderByClause(sortBy, sortDirection);

        String sql = """
            SELECT
                start_date,
                cpt_type,
                cpt_code,
                quantity,
                net_amount,
                payment_amount,
                denial_code,
                ordering_clinician,
                ordering_clinician_name,
                clinician,
                xml_file_name,
                denied_amount,
                payment_percentage,
                payment_status,
                unit_price,
                facility_id,
                payer_id,
                claim_number,
                encounter_start_date
            FROM claims.v_remittance_advice_activity_wise
            WHERE (?::timestamptz IS NULL OR start_date >= ?::timestamptz)
              AND (?::timestamptz IS NULL OR start_date <= ?::timestamptz)
              AND (?::text IS NULL OR facility_id = ?::text)
              AND (?::text IS NULL OR payer_id = ?::text)
              AND (?::text IS NULL OR payer_id = ?::text)
              AND (?::text IS NULL OR payer_id = ?::text)
            """ + orderByClause;

        // Add pagination if specified
        if (page != null && size != null && page >= 0 && size > 0) {
            sql += " LIMIT ? OFFSET ?";
        }

        List<Map<String, Object>> results = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            // Set parameters
            int paramIndex = 1;
            stmt.setObject(paramIndex++, fromDate);
            stmt.setObject(paramIndex++, fromDate);
            stmt.setObject(paramIndex++, toDate);
            stmt.setObject(paramIndex++, toDate);
            stmt.setString(paramIndex++, facilityCode);
            stmt.setString(paramIndex++, facilityCode);
            stmt.setString(paramIndex++, payerCode);
            stmt.setString(paramIndex++, payerCode);
            stmt.setString(paramIndex++, receiverCode);
            stmt.setString(paramIndex++, receiverCode);
            stmt.setString(paramIndex++, paymentReference);
            stmt.setString(paramIndex++, paymentReference);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("startDate", rs.getTimestamp("start_date"));
                    row.put("cptType", rs.getString("cpt_type"));
                    row.put("cptCode", rs.getString("cpt_code"));
                    row.put("quantity", rs.getBigDecimal("quantity"));
                    row.put("netAmount", rs.getBigDecimal("net_amount"));
                    row.put("paymentAmount", rs.getBigDecimal("payment_amount"));
                    row.put("denialCode", rs.getString("denial_code"));
                    row.put("orderingClinician", rs.getString("ordering_clinician"));
                    row.put("orderingClinicianName", rs.getString("ordering_clinician_name"));
                    row.put("clinician", rs.getString("clinician"));
                    row.put("xmlFileName", rs.getString("xml_file_name"));
                    row.put("deniedAmount", rs.getBigDecimal("denied_amount"));
                    row.put("paymentPercentage", rs.getBigDecimal("payment_percentage"));
                    row.put("paymentStatus", rs.getString("payment_status"));
                    row.put("unitPrice", rs.getBigDecimal("unit_price"));
                    row.put("facilityId", rs.getString("facility_id"));
                    row.put("payerId", rs.getString("payer_id"));
                    row.put("claimNumber", rs.getString("claim_number"));
                    row.put("encounterStartDate", rs.getTimestamp("encounter_start_date"));
                    results.add(row);
                }
            }

            log.info("Retrieved {} activity wise tab records for Remittance Advice Payerwise report", results.size());

        } catch (SQLException e) {
            log.error("Error retrieving activity wise tab data for Remittance Advice Payerwise report", e);
            throw new RuntimeException("Failed to retrieve activity wise tab data", e);
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
            String paymentReference) {

        String sql = """
            SELECT * FROM claims.get_remittance_advice_report_params(
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
            stmt.setString(6, paymentReference);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    Map<String, Object> params = new LinkedHashMap<>();
                    params.put("totalClaims", rs.getLong("total_claims"));
                    params.put("totalActivities", rs.getLong("total_activities"));
                    params.put("totalBilledAmount", rs.getBigDecimal("total_billed_amount"));
                    params.put("totalPaidAmount", rs.getBigDecimal("total_paid_amount"));
                    params.put("totalDeniedAmount", rs.getBigDecimal("total_denied_amount"));
                    params.put("avgCollectionRate", rs.getBigDecimal("avg_collection_rate"));

                    log.info("Retrieved report parameters for Remittance Advice Payerwise report");
                    return params;
                }
            }

        } catch (SQLException e) {
            log.error("Error retrieving report parameters for Remittance Advice Payerwise report", e);
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
        options.put("facilities", getDistinctValues("SELECT DISTINCT facility_code FROM claims.facility WHERE facility_code IS NOT NULL ORDER BY facility_code"));

        // Get available payers
        options.put("payers", getDistinctValues("SELECT DISTINCT payer_code FROM claims.payer WHERE payer_code IS NOT NULL ORDER BY payer_code"));

        // Get available receivers
        options.put("receivers", getDistinctValues("SELECT DISTINCT payer_code FROM claims.payer WHERE payer_code IS NOT NULL ORDER BY payer_code"));

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
            "ordering_clinician_name", "ordering_clinician", "clinician_id", "clinician_name",
            "prior_authorization_id", "xml_file_name", "remittance_comments", "total_claims",
            "total_activities", "total_billed_amount", "total_paid_amount", "total_denied_amount",
            "collection_rate", "denied_activities_count", "facility_id", "facility_name",
            "payer_id", "payer_name", "receiver_id", "receiver_name", "remittance_date", "submission_date"
        );

        if (!validColumns.contains(sortBy)) {
            sortBy = defaultColumn;
        }

        return " ORDER BY " + sortBy + " " + sortDirection.toUpperCase();
    }

    /**
     * Build ORDER BY clause for Claim Wise tab queries
     */
    private String buildClaimWiseOrderByClause(String sortBy, String sortDirection) {
        if (sortBy == null || sortBy.trim().isEmpty()) {
            return " ORDER BY transaction_date DESC, claim_number";
        }

        if (sortDirection == null || (!"ASC".equalsIgnoreCase(sortDirection) && !"DESC".equalsIgnoreCase(sortDirection))) {
            sortDirection = "DESC";
        }

        // Validate sortBy column to prevent SQL injection
        Set<String> validColumns = Set.of(
            "payer_name", "transaction_date", "encounter_start", "claim_number",
            "id_payer", "member_id", "payment_reference", "claim_activity_number",
            "start_date", "facility_group", "health_authority", "facility_id",
            "facility_name", "receiver_id", "receiver_name", "payer_id",
            "claim_amount", "remittance_amount", "xml_file_name", "activity_count",
            "total_paid", "total_denied", "collection_rate", "denied_count"
        );

        if (!validColumns.contains(sortBy)) {
            return " ORDER BY transaction_date DESC, claim_number";
        }

        return " ORDER BY " + sortBy + " " + sortDirection.toUpperCase();
    }

    /**
     * Build ORDER BY clause for Activity Wise tab queries
     */
    private String buildActivityWiseOrderByClause(String sortBy, String sortDirection) {
        if (sortBy == null || sortBy.trim().isEmpty()) {
            return " ORDER BY start_date DESC, cpt_code";
        }

        if (sortDirection == null || (!"ASC".equalsIgnoreCase(sortDirection) && !"DESC".equalsIgnoreCase(sortDirection))) {
            sortDirection = "DESC";
        }

        // Validate sortBy column to prevent SQL injection
        Set<String> validColumns = Set.of(
            "start_date", "cpt_type", "cpt_code", "quantity", "net_amount",
            "payment_amount", "denial_code", "ordering_clinician", "ordering_clinician_name",
            "clinician", "xml_file_name", "denied_amount", "payment_percentage",
            "payment_status", "unit_price", "facility_id", "payer_id",
            "claim_number", "encounter_start_date"
        );

        if (!validColumns.contains(sortBy)) {
            return " ORDER BY start_date DESC, cpt_code";
        }

        return " ORDER BY " + sortBy + " " + sortDirection.toUpperCase();
    }
}
