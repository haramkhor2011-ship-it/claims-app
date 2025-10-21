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
 * Service for Remittances & Resubmission report
 *
 * Exposes two entry points:
 * - getActivityLevelData → claims.get_remittances_resubmission_activity_level
 * - getClaimLevelData → claims.get_remittances_resubmission_claim_level
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RemittancesResubmissionReportService {

    private final DataSource dataSource;
    private final ToggleRepo toggleRepo;

    public List<Map<String, Object>> getActivityLevelData(
            String facilityId,
            List<String> facilityIds,
            List<String> payerIds,
            List<String> receiverIds,
            LocalDateTime fromDate,
            LocalDateTime toDate,
            String encounterType,
            List<String> clinicianIds,
            String claimNumber,
            String cptCode,
            String denialFilter,
            String orderBy,
            Integer page,
            Integer size,
            List<Long> facilityRefIds,
            List<Long> payerRefIds,
            List<Long> clinicianRefIds
    ) {
        // OPTION 3: Check if MVs are enabled via toggle
        boolean useMv = toggleRepo.isEnabled("is_mv_enabled") || toggleRepo.isEnabled("is_sub_second_mode_enabled");
        
        log.info("Resubmission Report - useMv: {}", useMv);

        String sql = """
            SELECT * FROM claims.get_remittances_resubmission_activity_level(
                p_use_mv := ?,
                p_tab_name := 'activity_level',
                p_facility_id := ?::text,
                p_facility_ids := ?::text[],
                ?::text[],
                ?::text[],
                ?::timestamptz,
                ?::timestamptz,
                ?::text,
                ?::text[],
                ?::text,
                ?::text,
                ?::text,
                ?::text,
                ?::integer,
                ?::integer,
                ?::bigint[],
                ?::bigint[],
                ?::bigint[]
            )
        """;

        int limit = page != null && size != null && page >= 0 && size != null && size > 0 ? size : 1000;
        int offset = page != null && size != null && page >= 0 && size != null && size > 0 ? page * size : 0;
        String safeOrderBy = validateOrderBy(orderBy, Set.of(
                "encounter_start ASC", "encounter_start DESC",
                "submitted_amount ASC", "submitted_amount DESC",
                "ageing_days ASC", "ageing_days DESC"
        ), "encounter_start DESC");

        List<Map<String, Object>> results = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            int i = 1;
            stmt.setString(i++, facilityId);
            setTextArray(conn, stmt, i++, facilityIds);
            setTextArray(conn, stmt, i++, payerIds);
            setTextArray(conn, stmt, i++, receiverIds);
            stmt.setObject(i++, fromDate);
            stmt.setObject(i++, toDate);
            stmt.setString(i++, encounterType);
            setTextArray(conn, stmt, i++, clinicianIds);
            stmt.setString(i++, claimNumber);
            stmt.setString(i++, cptCode);
            stmt.setString(i++, denialFilter);
            stmt.setString(i++, safeOrderBy);
            stmt.setInt(i++, limit);
            stmt.setInt(i++, offset);
            setBigintArray(conn, stmt, i++, facilityRefIds);
            setBigintArray(conn, stmt, i++, payerRefIds);
            setBigintArray(conn, stmt, i++, clinicianRefIds);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    // Core identifiers
                    row.put("claimKeyId", rs.getLong("claim_key_id"));
                    row.put("claimId", rs.getString("claim_id"));
                    row.put("activityId", rs.getString("activity_id"));
                    // Entities
                    row.put("memberId", rs.getString("member_id"));
                    row.put("patientId", rs.getString("patient_id"));
                    row.put("payerId", rs.getString("payer_id"));
                    row.put("payerName", rs.getString("payer_name"));
                    row.put("receiverId", rs.getString("receiver_id"));
                    row.put("receiverName", rs.getString("receiver_name"));
                    row.put("facilityId", rs.getString("facility_id"));
                    row.put("facilityName", rs.getString("facility_name"));
                    row.put("facilityGroup", rs.getString("facility_group"));
                    row.put("healthAuthority", rs.getString("health_authority"));
                    // Clinical
                    row.put("clinician", rs.getString("clinician"));
                    row.put("clinicianName", rs.getString("clinician_name"));
                    row.put("encounterType", rs.getString("encounter_type"));
                    // Dates
                    row.put("encounterStart", rs.getTimestamp("encounter_start"));
                    row.put("encounterEnd", rs.getTimestamp("encounter_end"));
                    row.put("encounterDate", rs.getTimestamp("encounter_date"));
                    row.put("activityDate", rs.getTimestamp("activity_date"));
                    // CPT
                    row.put("cptType", rs.getString("cpt_type"));
                    row.put("cptCode", rs.getString("cpt_code"));
                    row.put("quantity", rs.getBigDecimal("quantity"));
                    // Financials
                    row.put("submittedAmount", rs.getBigDecimal("submitted_amount"));
                    row.put("totalPaid", rs.getBigDecimal("total_paid"));
                    row.put("totalRemitted", rs.getBigDecimal("total_remitted"));
                    row.put("rejectedAmount", rs.getBigDecimal("rejected_amount"));
                    row.put("initialDenialCode", rs.getString("initial_denial_code"));
                    row.put("latestDenialCode", rs.getString("latest_denial_code"));
                    // Cycles & metrics
                    row.put("resubmissionCount", rs.getLong("resubmission_count"));
                    row.put("remittanceCount", rs.getLong("remittance_count"));
                    row.put("hasRejectedAmount", rs.getBoolean("has_rejected_amount"));
                    row.put("rejectedNotResubmitted", rs.getBoolean("rejected_not_resubmitted"));
                    row.put("denialCode", rs.getString("denial_code"));
                    row.put("denialComment", rs.getString("denial_comment"));
                    row.put("cptStatus", rs.getString("cpt_status"));
                    row.put("ageingDays", rs.getBigDecimal("ageing_days"));
                    // Timeline & diagnosis
                    row.put("submittedDate", rs.getTimestamp("submitted_date"));
                    row.put("claimTransactionDate", rs.getTimestamp("claim_transaction_date"));
                    row.put("primaryDiagnosis", rs.getString("primary_diagnosis"));
                    row.put("secondaryDiagnosis", rs.getString("secondary_diagnosis"));
                    // Derived
                    row.put("billedAmount", rs.getBigDecimal("billed_amount"));
                    row.put("paidAmount", rs.getBigDecimal("paid_amount"));
                    row.put("remittedAmount", rs.getBigDecimal("remitted_amount"));
                    row.put("paymentAmount", rs.getBigDecimal("payment_amount"));
                    row.put("outstandingBalance", rs.getBigDecimal("outstanding_balance"));
                    row.put("pendingAmount", rs.getBigDecimal("pending_amount"));
                    row.put("pendingRemittanceAmount", rs.getBigDecimal("pending_remittance_amount"));
                    row.put("idPayer", rs.getString("id_payer"));
                    row.put("priorAuthorizationId", rs.getString("prior_authorization_id"));
                    row.put("paymentReference", rs.getString("payment_reference"));
                    row.put("dateSettlement", rs.getTimestamp("date_settlement"));
                    row.put("claimMonth", rs.getBigDecimal("claim_month"));
                    row.put("claimYear", rs.getBigDecimal("claim_year"));
                    row.put("collectionRate", rs.getBigDecimal("collection_rate"));
                    row.put("fullyPaidCount", rs.getLong("fully_paid_count"));
                    row.put("fullyPaidAmount", rs.getBigDecimal("fully_paid_amount"));
                    row.put("fullyRejectedCount", rs.getLong("fully_rejected_count"));
                    row.put("fullyRejectedAmount", rs.getBigDecimal("fully_rejected_amount"));
                    row.put("partiallyPaidCount", rs.getLong("partially_paid_count"));
                    row.put("partiallyPaidAmount", rs.getBigDecimal("partially_paid_amount"));
                    row.put("selfPayCount", rs.getLong("self_pay_count"));
                    row.put("selfPayAmount", rs.getBigDecimal("self_pay_amount"));
                    row.put("takenBackAmount", rs.getBigDecimal("taken_back_amount"));
                    row.put("takenBackCount", rs.getLong("taken_back_count"));
                    results.add(row);
                }
            }

            log.info("Retrieved {} remittances-resubmission activity rows", results.size());
        } catch (SQLException e) {
            log.error("Error retrieving remittances-resubmission activity data", e);
            throw new RuntimeException("Failed to retrieve remittances-resubmission activity data", e);
        }

        return results;
    }

    public List<Map<String, Object>> getClaimLevelData(
            String facilityId,
            List<String> facilityIds,
            List<String> payerIds,
            List<String> receiverIds,
            LocalDateTime fromDate,
            LocalDateTime toDate,
            String encounterType,
            List<String> clinicianIds,
            String claimNumber,
            String denialFilter,
            String orderBy,
            Integer page,
            Integer size,
            List<Long> facilityRefIds,
            List<Long> payerRefIds,
            List<Long> clinicianRefIds
    ) {
        // OPTION 3: Check if MVs are enabled via toggle
        boolean useMv = toggleRepo.isEnabled("is_mv_enabled") || toggleRepo.isEnabled("is_sub_second_mode_enabled");
        
        log.info("Resubmission Claim Level - useMv: {}", useMv);

        String sql = """
            SELECT * FROM claims.get_remittances_resubmission_claim_level(
                p_use_mv := ?,
                p_tab_name := 'claim_level',
                p_facility_id := ?::text,
                p_facility_ids := ?::text[],
                p_payer_ids := ?::text[],
                p_receiver_ids := ?::text[],
                p_from_date := ?::timestamptz,
                p_to_date := ?::timestamptz,
                p_encounter_type := ?::text,
                p_clinician_ids := ?::text[],
                p_claim_number := ?::text,
                p_denial_filter := ?::text,
                p_order_by := ?::text,
                p_limit := ?::integer,
                p_offset := ?::integer,
                p_facility_ref_ids := ?::bigint[],
                p_payer_ref_ids := ?::bigint[],
                p_clinician_ref_ids := ?::bigint[]
            )
        """;

        int limit = page != null && size != null && page >= 0 && size != null && size > 0 ? size : 1000;
        int offset = page != null && size != null && page >= 0 && size != null && size > 0 ? page * size : 0;
        String safeOrderBy = validateOrderBy(orderBy, Set.of(
                "encounter_start ASC", "encounter_start DESC",
                "submitted_amount ASC", "submitted_amount DESC",
                "ageing_days ASC", "ageing_days DESC"
        ), "encounter_start DESC");

        List<Map<String, Object>> results = new ArrayList<>();

        try (Connection conn = dataSource.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            int i = 1;
            // OPTION 3: Set useMv and tabName parameters first
            stmt.setBoolean(i++, useMv);
            stmt.setString(i++, facilityId);
            setTextArray(conn, stmt, i++, facilityIds);
            setTextArray(conn, stmt, i++, payerIds);
            setTextArray(conn, stmt, i++, receiverIds);
            stmt.setObject(i++, fromDate);
            stmt.setObject(i++, toDate);
            stmt.setString(i++, encounterType);
            setTextArray(conn, stmt, i++, clinicianIds);
            stmt.setString(i++, claimNumber);
            stmt.setString(i++, denialFilter);
            stmt.setString(i++, safeOrderBy);
            stmt.setInt(i++, limit);
            stmt.setInt(i++, offset);
            setBigintArray(conn, stmt, i++, facilityRefIds);
            setBigintArray(conn, stmt, i++, payerRefIds);
            setBigintArray(conn, stmt, i++, clinicianRefIds);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("claimKeyId", rs.getLong("claim_key_id"));
                    row.put("claimId", rs.getString("claim_id"));
                    row.put("claimInternalId", rs.getLong("claim_internal_id"));
                    row.put("memberId", rs.getString("member_id"));
                    row.put("patientId", rs.getString("patient_id"));
                    row.put("payerId", rs.getString("payer_id"));
                    row.put("payerName", rs.getString("payer_name"));
                    row.put("receiverId", rs.getString("receiver_id"));
                    row.put("receiverName", rs.getString("receiver_name"));
                    row.put("facilityId", rs.getString("facility_id"));
                    row.put("facilityName", rs.getString("facility_name"));
                    row.put("facilityGroup", rs.getString("facility_group"));
                    row.put("healthAuthority", rs.getString("health_authority"));
                    row.put("clinician", rs.getString("clinician"));
                    row.put("clinicianName", rs.getString("clinician_name"));
                    row.put("encounterType", rs.getString("encounter_type"));
                    row.put("encounterStart", rs.getTimestamp("encounter_start"));
                    row.put("encounterEnd", rs.getTimestamp("encounter_end"));
                    row.put("encounterDate", rs.getTimestamp("encounter_date"));
                    row.put("submittedAmount", rs.getBigDecimal("submitted_amount"));
                    row.put("totalPaid", rs.getBigDecimal("total_paid"));
                    row.put("rejectedAmount", rs.getBigDecimal("rejected_amount"));
                    row.put("remittanceCount", rs.getLong("remittance_count"));
                    row.put("resubmissionCount", rs.getLong("resubmission_count"));
                    row.put("hasRejectedAmount", rs.getBoolean("has_rejected_amount"));
                    row.put("rejectedNotResubmitted", rs.getBoolean("rejected_not_resubmitted"));
                    row.put("ageingDays", rs.getBigDecimal("ageing_days"));
                    row.put("submittedDate", rs.getTimestamp("submitted_date"));
                    row.put("claimTransactionDate", rs.getTimestamp("claim_transaction_date"));
                    row.put("primaryDiagnosis", rs.getString("primary_diagnosis"));
                    row.put("secondaryDiagnosis", rs.getString("secondary_diagnosis"));
                    results.add(row);
                }
            }

            log.info("Retrieved {} remittances-resubmission claim rows", results.size());
        } catch (SQLException e) {
            log.error("Error retrieving remittances-resubmission claim-level data", e);
            throw new RuntimeException("Failed to retrieve remittances-resubmission claim-level data", e);
        }

        return results;
    }

    public Map<String, List<String>> getFilterOptions() {
        Map<String, List<String>> options = new HashMap<>();
        options.put("facilities", getDistinctValues("SELECT DISTINCT facility_code FROM claims_ref.facility WHERE facility_code IS NOT NULL ORDER BY facility_code"));
        options.put("payers", getDistinctValues("SELECT DISTINCT payer_code FROM claims_ref.payer WHERE payer_code IS NOT NULL ORDER BY payer_code"));
        options.put("receivers", getDistinctValues("SELECT DISTINCT provider_code FROM claims_ref.provider WHERE provider_code IS NOT NULL ORDER BY provider_code"));
        options.put("clinicians", getDistinctValues("SELECT DISTINCT clinician_code FROM claims_ref.clinician WHERE clinician_code IS NOT NULL ORDER BY clinician_code"));
        options.put("encounterTypes", getDistinctValues("SELECT DISTINCT type FROM claims.encounter WHERE type IS NOT NULL ORDER BY type"));
        options.put("denialCodes", getDistinctValues("SELECT DISTINCT code FROM claims_ref.denial_code WHERE code IS NOT NULL ORDER BY code"));
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

    private String validateOrderBy(String orderBy, Set<String> allowed, String defaultValue) {
        if (orderBy == null || orderBy.isBlank()) return defaultValue;
        return allowed.contains(orderBy) ? orderBy : defaultValue;
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


