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
 * Service for Balance Amount to be Received report (three tabs)
 * Uses claims.get_balance_amount_to_be_received with filters and pagination.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BalanceAmountReportService {

    private final DataSource dataSource;
    private final ToggleRepo toggleRepo;

    public List<Map<String, Object>> getTabA_BalanceToBeReceived(
            String userId,
            List<Long> claimKeyIds,
            List<String> facilityCodes,
            List<String> payerCodes,
            List<String> receiverIds,
            LocalDateTime dateFrom,
            LocalDateTime dateTo,
            Integer year,
            Integer month,
            Boolean basedOnInitialNet,
            String orderBy,
            String orderDirection,
            Integer page,
            Integer size,
            List<Long> facilityRefIds,
            List<Long> payerRefIds
    ) {
        // OPTION 3: Check if MVs are enabled via toggle
        boolean useMv = toggleRepo.isEnabled("is_mv_enabled") || toggleRepo.isEnabled("is_sub_second_mode_enabled");
        
        log.info("Balance Amount Report - useMv: {}", useMv);
        
        // Use Option 3 function with dynamic data source selection
        String sql = """
            SELECT * FROM claims.get_balance_amount_to_be_received(
                p_use_mv := ?,
                p_tab_name := 'overall',
                p_user_id := ?,
                p_claim_key_ids := ?,
                p_facility_codes := ?,
                p_payer_codes := ?,
                p_receiver_ids := ?,
                p_from_date := ?,
                p_to_date := ?,
                p_year := ?,
                p_month := ?,
                p_based_on_initial_net := ?,
                p_order_by := ?,
                p_order_direction := ?,
                p_limit := ?,
                p_offset := ?,
                p_facility_ref_ids := ?,
                p_payer_ref_ids := ?
            )
        """;

        int limit = page != null && size != null && page >= 0 && size != null && size > 0 ? size : 1000;
        int offset = page != null && size != null && page >= 0 && size != null && size > 0 ? page * size : 0;
        String safeOrderBy = validateOrderBy(orderBy, Set.of(
                "encounter_start_date", "encounter_end_date", "claim_submission_date", "claim_amt", "pending_amt", "aging_days"),
                "encounter_start_date");
        String safeDirection = validateDirection(orderDirection, "DESC");

        List<Map<String, Object>> results = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            int i = 1;
            // OPTION 3: Set useMv parameter first
            stmt.setBoolean(i++, useMv);
            stmt.setString(i++, userId);
            setBigintArray(conn, stmt, i++, claimKeyIds);
            setTextArray(conn, stmt, i++, facilityCodes);
            setTextArray(conn, stmt, i++, payerCodes);
            setTextArray(conn, stmt, i++, receiverIds);
            stmt.setObject(i++, dateFrom);
            stmt.setObject(i++, dateTo);
            stmt.setObject(i++, year);
            stmt.setObject(i++, month);
            stmt.setObject(i++, basedOnInitialNet);
            stmt.setString(i++, safeOrderBy);
            stmt.setString(i++, safeDirection);
            stmt.setInt(i++, limit);
            stmt.setInt(i++, offset);
            setBigintArray(conn, stmt, i++, facilityRefIds);
            setBigintArray(conn, stmt, i++, payerRefIds);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("claimKeyId", rs.getLong("claim_key_id"));
                    row.put("claimId", rs.getString("claim_id"));
                    row.put("facilityGroupId", rs.getString("facility_group_id"));
                    row.put("healthAuthority", rs.getString("health_authority"));
                    row.put("facilityId", rs.getString("facility_id"));
                    row.put("facilityName", rs.getString("facility_name"));
                    row.put("claimNumber", rs.getString("claim_number"));
                    row.put("encounterStartDate", rs.getTimestamp("encounter_start_date"));
                    row.put("encounterEndDate", rs.getTimestamp("encounter_end_date"));
                    row.put("encounterStartYear", rs.getInt("encounter_start_year"));
                    row.put("encounterStartMonth", rs.getInt("encounter_start_month"));
                    row.put("idPayer", rs.getString("id_payer"));
                    row.put("patientId", rs.getString("patient_id"));
                    row.put("memberId", rs.getString("member_id"));
                    row.put("emiratesIdNumber", rs.getString("emirates_id_number"));
                    row.put("billedAmount", rs.getBigDecimal("billed_amount"));
                    row.put("amountReceived", rs.getBigDecimal("amount_received"));
                    row.put("deniedAmount", rs.getBigDecimal("denied_amount"));
                    row.put("outstandingBalance", rs.getBigDecimal("outstanding_balance"));
                    row.put("submissionDate", rs.getTimestamp("submission_date"));
                    row.put("submissionReferenceFile", rs.getString("submission_reference_file"));
                    row.put("claimStatus", rs.getString("claim_status"));
                    row.put("remittanceCount", rs.getInt("remittance_count"));
                    row.put("resubmissionCount", rs.getInt("resubmission_count"));
                    row.put("agingDays", rs.getInt("aging_days"));
                    row.put("agingBucket", rs.getString("aging_bucket"));
                    row.put("currentClaimStatus", rs.getString("current_claim_status"));
                    row.put("lastStatusDate", rs.getTimestamp("last_status_date"));
                    row.put("totalRecords", rs.getLong("total_records"));
                    results.add(row);
                }
            }

            log.info("Retrieved {} balance-to-be-received rows using Option 3 (useMv: {})", results.size(), useMv);
        } catch (SQLException e) {
            log.error("Error retrieving balance amount (Tab A)", e);
            throw new RuntimeException("Failed to retrieve balance amount (Tab A)", e);
        }

        return results;
    }

    public Map<String, List<String>> getFilterOptions() {
        Map<String, List<String>> options = new HashMap<>();
        options.put("facilities", getDistinctValues("SELECT DISTINCT facility_code FROM claims_ref.facility WHERE facility_code IS NOT NULL ORDER BY facility_code"));
        options.put("payers", getDistinctValues("SELECT DISTINCT payer_code FROM claims_ref.payer WHERE payer_code IS NOT NULL ORDER BY payer_code"));
        options.put("receivers", getDistinctValues("SELECT DISTINCT provider_code FROM claims_ref.provider WHERE provider_code IS NOT NULL ORDER BY provider_code"));
        return options;
    }

    private void setTextArray(Connection conn, PreparedStatement stmt, int index, List<String> list) throws SQLException {
        if (list == null || list.isEmpty()) {
            stmt.setNull(index, Types.ARRAY);
            return;
        }
        Array array = conn.createArrayOf("text", list.toArray(new String[0]));
        stmt.setArray(index, array);
    }

    private void setBigintArray(Connection conn, PreparedStatement stmt, int index, List<Long> list) throws SQLException {
        if (list == null || list.isEmpty()) {
            stmt.setNull(index, Types.ARRAY);
            return;
        }
        Array array = conn.createArrayOf("bigint", list.toArray(new Long[0]));
        stmt.setArray(index, array);
    }

    private String validateOrderBy(String sortBy, Set<String> allowed, String def) {
        if (sortBy == null || sortBy.isBlank()) return def;
        return allowed.contains(sortBy) ? sortBy : def;
    }

    private String validateDirection(String direction, String def) {
        if (direction == null) return def;
        String d = direction.toUpperCase(Locale.ROOT);
        return ("ASC".equals(d) || "DESC".equals(d)) ? d : def;
    }

    private List<String> getDistinctValues(String sql) {
        List<String> values = new ArrayList<>();
        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {
            while (rs.next()) values.add(rs.getString(1));
        } catch (SQLException e) {
            log.error("Error loading filter options", e);
        }
        return values;
    }
}


