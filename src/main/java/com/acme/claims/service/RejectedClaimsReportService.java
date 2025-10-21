package com.acme.claims.service;

import com.acme.claims.soap.db.ToggleRepo;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.sql.DataSource;
import java.sql.*;
import java.time.LocalDateTime;
import java.util.*;

/**
 * Service for Rejected Claims Report
 *
 * Provides data access for three tabs:
 * - summary: facility/month/payer metrics with detailed row fields
 * - receiverPayer: facility-level summary with averages and collection rate
 * - claimWise: claim/activity-level detail for rejected and partially paid items
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RejectedClaimsReportService {

    private final DataSource dataSource;
    private final ToggleRepo toggleRepo;

    public List<Map<String, Object>> getSummaryTabData(
            String userId,
            List<String> facilityCodes,
            List<String> payerCodes,
            List<String> receiverIds,
            LocalDateTime fromDate,
            LocalDateTime toDate,
            Integer year,
            Integer month,
            String sortBy,
            String sortDirection,
            Integer page,
            Integer size,
            List<Long> facilityRefIds,
            List<Long> payerRefIds,
            List<Long> clinicianRefIds    ) {
        // OPTION 3: Check if MVs are enabled via toggle
        boolean useMv = toggleRepo.isEnabled("is_mv_enabled") || toggleRepo.isEnabled("is_sub_second_mode_enabled");
        
        log.info("Rejected Claims Report - useMv: {}", useMv);

        // Use Option 3 function with dynamic data source selection
        String sql = """
            SELECT * FROM claims.get_rejected_claims_summary(
                p_use_mv := ?,
                p_tab_name := 'summary',
                p_user_id := ?,
                p_facility_codes := ?,
                p_payer_codes := ?,
                p_receiver_ids := ?,
                p_from_date := ?,
                p_to_date := ?,
                p_year := ?,
                p_month := ?,
                p_sort_by := ?,
                p_sort_direction := ?,
                p_limit := ?,
                p_offset := ?,
                p_facility_ref_ids := ?,
                p_payer_ref_ids := ?,
                p_clinician_ref_ids := ?
            )
        """;

        int limit = page != null && size != null && page >= 0 && size != null && size > 0 ? size : 1000;
        int offset = page != null && size != null && page >= 0 && size != null && size > 0 ? page * size : 0;
        String safeOrderBy = validateOrderBy(sortBy, Set.of(
                "facility_name", "claim_year", "rejected_amt", "rejected_percentage_remittance"), "facility_name");
        String safeDirection = validateDirection(sortDirection, "ASC");

        List<Map<String, Object>> results = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            int i = 1;
            // OPTION 3: Set useMv and tabName parameters first
            stmt.setBoolean(i++, useMv);
            stmt.setString(i++, userId);
            setTextArrayParam(conn, stmt, i++, facilityCodes);
            setTextArrayParam(conn, stmt, i++, payerCodes);
            setTextArrayParam(conn, stmt, i++, receiverIds);
            stmt.setObject(i++, fromDate);
            stmt.setObject(i++, toDate);
            stmt.setObject(i++, year);
            stmt.setObject(i++, month);
            stmt.setString(i++, safeOrderBy);
            stmt.setString(i++, safeDirection);
            stmt.setInt(i++, limit);
            stmt.setInt(i++, offset);
            setBigintArrayParam(conn, stmt, i++, facilityRefIds);
            setBigintArrayParam(conn, stmt, i++, payerRefIds);
            setBigintArrayParam(conn, stmt, i++, clinicianRefIds);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("facilityId", rs.getString("facility_id"));
                    row.put("facilityName", rs.getString("facility_name"));
                    row.put("claimYear", rs.getBigDecimal("claim_year"));
                    row.put("claimMonthName", rs.getString("claim_month_name"));
                    row.put("payerId", rs.getString("payer_id"));
                    row.put("payerName", rs.getString("payer_name"));
                    row.put("totalClaim", rs.getLong("total_claim"));
                    row.put("claimAmt", rs.getBigDecimal("claim_amt"));
                    row.put("remittedClaim", rs.getLong("remitted_claim"));
                    row.put("remittedAmt", rs.getBigDecimal("remitted_amt"));
                    row.put("rejectedClaim", rs.getLong("rejected_claim"));
                    row.put("rejectedAmt", rs.getBigDecimal("rejected_amt"));
                    row.put("pendingRemittance", rs.getLong("pending_remittance"));
                    row.put("pendingRemittanceAmt", rs.getBigDecimal("pending_remittance_amt"));
                    row.put("rejectedPercentageRemittance", rs.getBigDecimal("rejected_percentage_remittance"));
                    row.put("rejectedPercentageSubmission", rs.getBigDecimal("rejected_percentage_submission"));
                    row.put("claimId", rs.getString("claim_id"));
                    row.put("memberId", rs.getString("member_id"));
                    row.put("emiratesIdNumber", rs.getString("emirates_id_number"));
                    row.put("claimAmtDetail", rs.getBigDecimal("claim_amt_detail"));
                    row.put("remittedAmtDetail", rs.getBigDecimal("remitted_amt_detail"));
                    row.put("rejectedAmtDetail", rs.getBigDecimal("rejected_amt_detail"));
                    row.put("rejectionType", rs.getString("rejection_type"));
                    row.put("activityStartDate", rs.getTimestamp("activity_start_date"));
                    row.put("activityCode", rs.getString("activity_code"));
                    row.put("activityDenialCode", rs.getString("activity_denial_code"));
                    row.put("denialType", rs.getString("denial_type"));
                    row.put("clinicianName", rs.getString("clinician_name"));
                    row.put("ageingDays", rs.getInt("ageing_days"));
                    row.put("currentStatus", rs.getString("current_status"));
                    row.put("resubmissionType", rs.getString("resubmission_type"));
                    row.put("submissionFileId", rs.getLong("submission_file_id"));
                    row.put("remittanceFileId", rs.getLong("remittance_file_id"));
                    results.add(row);
                }
            }

            log.info("Retrieved {} rejected-claims summary rows", results.size());
        } catch (SQLException e) {
            log.error("Error retrieving rejected-claims summary", e);
            throw new RuntimeException("Failed to retrieve rejected-claims summary", e);
        }

        return results;
    }

    public List<Map<String, Object>> getReceiverPayerTabData(
            String userId,
            List<String> facilityCodes,
            List<String> payerCodes,
            List<String> receiverIds,
            LocalDateTime fromDate,
            LocalDateTime toDate,
            Integer year,
            List<String> denialCodes,
            String sortBy,
            String sortDirection,
            Integer page,
            Integer size,
            List<Long> facilityRefIds,
            List<Long> payerRefIds,
            List<Long> clinicianRefIds) {
        // OPTION 3: Check if MVs are enabled via toggle
        boolean useMv = toggleRepo.isEnabled("is_mv_enabled") || toggleRepo.isEnabled("is_sub_second_mode_enabled");
        
        log.info("Rejected Claims Receiver Payer - useMv: {}", useMv);

        String sql = """
            SELECT * FROM claims.get_rejected_claims_receiver_payer(
              p_use_mv := ?,
              p_tab_name := 'receiver_payer',
              p_user_id := ?::text,
              p_facility_codes := ?::text[],
              p_payer_codes := ?::text[],
              p_receiver_ids := ?::text[],
              p_from_date := ?::timestamptz,
              p_to_date := ?::timestamptz,
              p_year := ?::integer,
              p_denial_codes := ?::text[],
              p_limit := ?::integer,
              p_offset := ?::integer,
              p_sort_by := ?::text,
              p_sort_direction := ?::text,
              p_facility_ref_ids := ?::bigint[],
              p_payer_ref_ids := ?::bigint[],
              p_clinician_ref_ids := ?::bigint[]
            )
        """;

        int limit = page != null && size != null && page >= 0 && size != null && size > 0 ? size : 1000;
        int offset = page != null && size != null && page >= 0 && size != null && size > 0 ? page * size : 0;
        String safeOrderBy = validateOrderBy(sortBy, Set.of(
                "facility_name", "claim_year", "rejected_amt", "rejected_percentage_remittance"), "facility_name");
        String safeDirection = validateDirection(sortDirection, "ASC");

        List<Map<String, Object>> results = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            int i = 1;
            // OPTION 3: Set useMv and tabName parameters first
            stmt.setBoolean(i++, useMv);
            stmt.setString(i++, userId);
            setTextArrayParam(conn, stmt, i++, facilityCodes);
            setTextArrayParam(conn, stmt, i++, payerCodes);
            setTextArrayParam(conn, stmt, i++, receiverIds);
            stmt.setObject(i++, fromDate);
            stmt.setObject(i++, toDate);
            stmt.setObject(i++, year);
            setTextArrayParam(conn, stmt, i++, denialCodes);
            stmt.setInt(i++, limit);
            stmt.setInt(i++, offset);
            stmt.setString(i++, safeOrderBy);
            stmt.setString(i++, safeDirection);
            setBigintArrayParam(conn, stmt, i++, facilityRefIds);
            setBigintArrayParam(conn, stmt, i++, payerRefIds);
            setBigintArrayParam(conn, stmt, i++, clinicianRefIds);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("facilityId", rs.getString("facility_id"));
                    row.put("facilityName", rs.getString("facility_name"));
                    row.put("claimYear", rs.getBigDecimal("claim_year"));
                    row.put("claimMonthName", rs.getString("claim_month_name"));
                    row.put("payerId", rs.getString("payer_id"));
                    row.put("payerName", rs.getString("payer_name"));
                    row.put("totalClaim", rs.getLong("total_claim"));
                    row.put("claimAmt", rs.getBigDecimal("claim_amt"));
                    row.put("remittedClaim", rs.getLong("remitted_claim"));
                    row.put("remittedAmt", rs.getBigDecimal("remitted_amt"));
                    row.put("rejectedClaim", rs.getLong("rejected_claim"));
                    row.put("rejectedAmt", rs.getBigDecimal("rejected_amt"));
                    row.put("pendingRemittance", rs.getLong("pending_remittance"));
                    row.put("pendingRemittanceAmt", rs.getBigDecimal("pending_remittance_amt"));
                    row.put("rejectedPercentageRemittance", rs.getBigDecimal("rejected_percentage_remittance"));
                    row.put("rejectedPercentageSubmission", rs.getBigDecimal("rejected_percentage_submission"));
                    row.put("averageClaimValue", rs.getBigDecimal("average_claim_value"));
                    row.put("collectionRate", rs.getBigDecimal("collection_rate"));
                    results.add(row);
                }
            }

            log.info("Retrieved {} rejected-claims receiver-payer rows", results.size());
        } catch (SQLException e) {
            log.error("Error retrieving rejected-claims receiver-payer", e);
            throw new RuntimeException("Failed to retrieve rejected-claims receiver-payer", e);
        }

        return results;
    }

    public List<Map<String, Object>> getClaimWiseTabData(
            String userId,
            List<String> facilityCodes,
            List<String> payerCodes,
            List<String> receiverIds,
            LocalDateTime fromDate,
            LocalDateTime toDate,
            Integer year,
            List<String> denialCodes,
            String sortBy,
            String sortDirection,
            Integer page,
            Integer size,
            List<Long> facilityRefIds,
            List<Long> payerRefIds,
            List<Long> clinicianRefIds) {
        // OPTION 3: Check if MVs are enabled via toggle
        boolean useMv = toggleRepo.isEnabled("is_mv_enabled") || toggleRepo.isEnabled("is_sub_second_mode_enabled");
        
        log.info("Rejected Claims Claim Wise - useMv: {}", useMv);

        String sql = """
            SELECT * FROM claims.get_rejected_claims_claim_wise(
              p_use_mv := ?,
              p_tab_name := 'claim_wise',
              p_user_id := ?::text,
              p_facility_codes := ?::text[],
              p_payer_codes := ?::text[],
              p_receiver_ids := ?::text[],
              p_from_date := ?::timestamptz,
              p_to_date := ?::timestamptz,
              p_year := ?::integer,
              p_denial_codes := ?::text[],
              p_limit := ?::integer,
              p_offset := ?::integer,
              p_sort_by := ?::text,
              p_sort_direction := ?::text,
              p_facility_ref_ids := ?::bigint[],
              p_payer_ref_ids := ?::bigint[],
              p_clinician_ref_ids := ?::bigint[]
            )
        """;

        int limit = page != null && size != null && page >= 0 && size != null && size > 0 ? size : 1000;
        int offset = page != null && size != null && page >= 0 && size != null && size > 0 ? page * size : 0;
        String safeOrderBy = validateOrderBy(sortBy, Set.of(
                "claim_id", "payer_name", "rejected_amt", "service_date"), "claim_id");
        String safeDirection = validateDirection(sortDirection, "ASC");

        List<Map<String, Object>> results = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            int i = 1;
            // OPTION 3: Set useMv and tabName parameters first
            stmt.setBoolean(i++, useMv);
            stmt.setString(i++, userId);
            setTextArrayParam(conn, stmt, i++, facilityCodes);
            setTextArrayParam(conn, stmt, i++, payerCodes);
            setTextArrayParam(conn, stmt, i++, receiverIds);
            stmt.setObject(i++, fromDate);
            stmt.setObject(i++, toDate);
            stmt.setObject(i++, year);
            setTextArrayParam(conn, stmt, i++, denialCodes);
            stmt.setInt(i++, limit);
            stmt.setInt(i++, offset);
            stmt.setString(i++, safeOrderBy);
            stmt.setString(i++, safeDirection);
            setBigintArrayParam(conn, stmt, i++, facilityRefIds);
            setBigintArrayParam(conn, stmt, i++, payerRefIds);
            setBigintArrayParam(conn, stmt, i++, clinicianRefIds);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("claimKeyId", rs.getLong("claim_key_id"));
                    row.put("claimId", rs.getString("claim_id"));
                    row.put("payerId", rs.getString("payer_id"));
                    row.put("payerName", rs.getString("payer_name"));
                    row.put("memberId", rs.getString("member_id"));
                    row.put("emiratesIdNumber", rs.getString("emirates_id_number"));
                    row.put("claimAmt", rs.getBigDecimal("claim_amt"));
                    row.put("remittedAmt", rs.getBigDecimal("remitted_amt"));
                    row.put("rejectedAmt", rs.getBigDecimal("rejected_amt"));
                    row.put("rejectionType", rs.getString("rejection_type"));
                    row.put("serviceDate", rs.getTimestamp("service_date"));
                    row.put("activityCode", rs.getString("activity_code"));
                    row.put("denialCode", rs.getString("denial_code"));
                    row.put("denialType", rs.getString("denial_type"));
                    row.put("clinicianName", rs.getString("clinician_name"));
                    row.put("facilityName", rs.getString("facility_name"));
                    row.put("ageingDays", rs.getInt("ageing_days"));
                    row.put("currentStatus", rs.getString("current_status"));
                    row.put("resubmissionType", rs.getString("resubmission_type"));
                    row.put("resubmissionComment", rs.getString("resubmission_comment"));
                    row.put("submissionFileId", rs.getLong("submission_file_id"));
                    row.put("remittanceFileId", rs.getLong("remittance_file_id"));
                    row.put("submissionTransactionDate", rs.getTimestamp("submission_transaction_date"));
                    row.put("remittanceTransactionDate", rs.getTimestamp("remittance_transaction_date"));
                    row.put("claimComments", rs.getString("claim_comments"));
                    results.add(row);
                }
            }

            log.info("Retrieved {} rejected-claims claim-wise rows", results.size());
        } catch (SQLException e) {
            log.error("Error retrieving rejected-claims claim-wise", e);
            throw new RuntimeException("Failed to retrieve rejected-claims claim-wise", e);
        }

        return results;
    }

    public Map<String, List<String>> getFilterOptions() {
        Map<String, List<String>> options = new HashMap<>();

        options.put("facilities", getDistinctValues("SELECT DISTINCT facility_code FROM claims_ref.facility WHERE facility_code IS NOT NULL ORDER BY facility_code"));
        options.put("payers", getDistinctValues("SELECT DISTINCT payer_code FROM claims_ref.payer WHERE payer_code IS NOT NULL ORDER BY payer_code"));
        options.put("receivers", getDistinctValues("SELECT DISTINCT provider_code FROM claims_ref.provider WHERE provider_code IS NOT NULL ORDER BY provider_code"));
        options.put("denialCodes", getDistinctValues("SELECT DISTINCT code FROM claims_ref.denial_code WHERE code IS NOT NULL ORDER BY code"));

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

    private void setTextArrayParam(Connection conn, PreparedStatement stmt, int index, List<String> values) throws SQLException {
        if (values == null || values.isEmpty()) {
            stmt.setNull(index, Types.ARRAY);
            return;
        }
        Array array = conn.createArrayOf("text", values.toArray(new String[0]));
        stmt.setArray(index, array);
    }

    private void setBigintArrayParam(Connection conn, PreparedStatement stmt, int index, List<Long> values) throws SQLException {
        if (values == null || values.isEmpty()) {
            stmt.setNull(index, Types.ARRAY);
            return;
        }
        // The underlying driver maps BIGINT to "bigint" array type
        Array array = conn.createArrayOf("bigint", values.toArray(new Long[0]));
        stmt.setArray(index, array);
    }

    private String validateOrderBy(String sortBy, Set<String> allowed, String defaultColumn) {
        if (sortBy == null || sortBy.isBlank()) {
            return defaultColumn;
        }
        return allowed.contains(sortBy) ? sortBy : defaultColumn;
    }

    private String validateDirection(String direction, String defaultDirection) {
        if (direction == null) {
            return defaultDirection;
        }
        String d = direction.toUpperCase(Locale.ROOT);
        return ("ASC".equals(d) || "DESC".equals(d)) ? d : defaultDirection;
    }
}


