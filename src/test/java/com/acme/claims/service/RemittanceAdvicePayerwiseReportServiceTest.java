package com.acme.claims.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import javax.sql.DataSource;
import java.sql.*;
import java.time.LocalDateTime;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit tests for RemittanceAdvicePayerwiseReportService
 */
@ExtendWith(MockitoExtension.class)
class RemittanceAdvicePayerwiseReportServiceTest {

    @Mock
    private DataSource dataSource;

    @Mock
    private Connection connection;

    @Mock
    private PreparedStatement preparedStatement;

    @Mock
    private ResultSet resultSet;

    @InjectMocks
    private RemittanceAdvicePayerwiseReportService reportService;

    @BeforeEach
    void setUp() throws SQLException {
        when(dataSource.getConnection()).thenReturn(connection);
        when(connection.prepareStatement(anyString())).thenReturn(preparedStatement);
        when(preparedStatement.executeQuery()).thenReturn(resultSet);
    }

    @Test
    void testGetHeaderTabData_Success() throws SQLException {
        // Arrange
        LocalDateTime fromDate = LocalDateTime.of(2025, 1, 1, 0, 0);
        LocalDateTime toDate = LocalDateTime.of(2025, 1, 31, 23, 59);
        String facilityCode = "FAC001";
        String payerCode = "PAYER001";
        String receiverCode = "RECEIVER001";

        // Mock ResultSet
        when(resultSet.next()).thenReturn(true).thenReturn(false);
        when(resultSet.getString("ordering_clinician_name")).thenReturn("Dr. Smith");
        when(resultSet.getString("ordering_clinician")).thenReturn("DOC001");
        when(resultSet.getString("clinician_id")).thenReturn("DOC002");
        when(resultSet.getString("clinician_name")).thenReturn("Dr. Johnson");
        when(resultSet.getString("prior_authorization_id")).thenReturn("PA001");
        when(resultSet.getString("xml_file_name")).thenReturn("file.xml");
        when(resultSet.getString("remittance_comments")).thenReturn("Test comment");
        when(resultSet.getLong("total_claims")).thenReturn(5L);
        when(resultSet.getLong("total_activities")).thenReturn(10L);
        when(resultSet.getBigDecimal("total_billed_amount")).thenReturn(new java.math.BigDecimal("1000.00"));
        when(resultSet.getBigDecimal("total_paid_amount")).thenReturn(new java.math.BigDecimal("900.00"));
        when(resultSet.getBigDecimal("total_denied_amount")).thenReturn(new java.math.BigDecimal("100.00"));
        when(resultSet.getBigDecimal("collection_rate")).thenReturn(new java.math.BigDecimal("90.00"));
        when(resultSet.getLong("denied_activities_count")).thenReturn(2L);
        when(resultSet.getString("facility_id")).thenReturn("FAC001");
        when(resultSet.getString("facility_name")).thenReturn("Test Facility");
        when(resultSet.getString("payer_id")).thenReturn("PAYER001");
        when(resultSet.getString("payer_name")).thenReturn("Test Payer");
        when(resultSet.getString("receiver_id")).thenReturn("RECEIVER001");
        when(resultSet.getString("receiver_name")).thenReturn("Test Receiver");
        when(resultSet.getTimestamp("remittance_date")).thenReturn(Timestamp.valueOf(fromDate));
        when(resultSet.getTimestamp("submission_date")).thenReturn(Timestamp.valueOf(fromDate.minusDays(1)));

        // Act
        List<Map<String, Object>> result = reportService.getHeaderTabData(
                fromDate, toDate, facilityCode, payerCode, receiverCode, null, null, null, null);

        // Assert
        assertNotNull(result);
        assertEquals(1, result.size());

        Map<String, Object> row = result.get(0);
        assertEquals("Dr. Smith", row.get("orderingClinicianName"));
        assertEquals("DOC001", row.get("orderingClinician"));
        assertEquals(5L, row.get("totalClaims"));
        assertEquals(new java.math.BigDecimal("1000.00"), row.get("totalBilledAmount"));

        // Verify PreparedStatement was called with correct SQL
        verify(preparedStatement).setObject(eq(1), eq(fromDate));
        verify(preparedStatement).setObject(eq(2), eq(fromDate));
        verify(preparedStatement).setObject(eq(3), eq(toDate));
        verify(preparedStatement).setObject(eq(4), eq(toDate));
        verify(preparedStatement).setString(eq(5), eq(facilityCode));
        verify(preparedStatement).setString(eq(6), eq(facilityCode));
        verify(preparedStatement).setString(eq(7), eq(payerCode));
        verify(preparedStatement).setString(eq(8), eq(payerCode));
        verify(preparedStatement).setString(eq(9), eq(receiverCode));
        verify(preparedStatement).setString(eq(10), eq(receiverCode));
    }

    @Test
    void testGetHeaderTabData_WithPagination() throws SQLException {
        // Arrange
        LocalDateTime fromDate = LocalDateTime.of(2025, 1, 1, 0, 0);
        when(resultSet.next()).thenReturn(false); // No results

        // Act
        List<Map<String, Object>> result = reportService.getHeaderTabData(
                fromDate, null, null, null, null, "total_paid_amount", "DESC", 0, 10);

        // Assert
        assertNotNull(result);
        assertTrue(result.isEmpty());

        // Verify pagination parameters were set
        verify(preparedStatement).setInt(eq(11), eq(10)); // LIMIT
        verify(preparedStatement).setInt(eq(12), eq(0));  // OFFSET
    }

    @Test
    void testGetClaimWiseTabData_Success() throws SQLException {
        // Arrange
        LocalDateTime fromDate = LocalDateTime.of(2025, 1, 1, 0, 0);
        LocalDateTime toDate = LocalDateTime.of(2025, 1, 31, 23, 59);

        when(resultSet.next()).thenReturn(true).thenReturn(false);
        when(resultSet.getString("payer_name")).thenReturn("Test Payer");
        when(resultSet.getTimestamp("transaction_date")).thenReturn(Timestamp.valueOf(fromDate));
        when(resultSet.getTimestamp("encounter_start")).thenReturn(Timestamp.valueOf(fromDate));
        when(resultSet.getString("claim_number")).thenReturn("CL001");
        when(resultSet.getString("id_payer")).thenReturn("ID001");
        when(resultSet.getString("member_id")).thenReturn("MEM001");
        when(resultSet.getString("payment_reference")).thenReturn("PAY001");
        when(resultSet.getString("claim_activity_number")).thenReturn("ACT001");
        when(resultSet.getTimestamp("start_date")).thenReturn(Timestamp.valueOf(fromDate));
        when(resultSet.getString("facility_group")).thenReturn("FAC001");
        when(resultSet.getString("health_authority")).thenReturn("HA001");
        when(resultSet.getString("facility_id")).thenReturn("FAC001");
        when(resultSet.getString("facility_name")).thenReturn("Test Facility");
        when(resultSet.getString("receiver_id")).thenReturn("REC001");
        when(resultSet.getString("receiver_name")).thenReturn("Test Receiver");
        when(resultSet.getString("payer_id")).thenReturn("PAY001");
        when(resultSet.getBigDecimal("claim_amount")).thenReturn(new java.math.BigDecimal("500.00"));
        when(resultSet.getBigDecimal("remittance_amount")).thenReturn(new java.math.BigDecimal("450.00"));
        when(resultSet.getString("xml_file_name")).thenReturn("file.xml");
        when(resultSet.getLong("activity_count")).thenReturn(3L);
        when(resultSet.getBigDecimal("total_paid")).thenReturn(new java.math.BigDecimal("450.00"));
        when(resultSet.getBigDecimal("total_denied")).thenReturn(new java.math.BigDecimal("50.00"));
        when(resultSet.getBigDecimal("collection_rate")).thenReturn(new java.math.BigDecimal("90.00"));
        when(resultSet.getLong("denied_count")).thenReturn(1L);

        // Act
        List<Map<String, Object>> result = reportService.getClaimWiseTabData(
                fromDate, toDate, null, null, null, null, null, null, null, null);

        // Assert
        assertNotNull(result);
        assertEquals(1, result.size());

        Map<String, Object> row = result.get(0);
        assertEquals("Test Payer", row.get("payerName"));
        assertEquals("CL001", row.get("claimNumber"));
        assertEquals(new java.math.BigDecimal("500.00"), row.get("claimAmount"));
    }

    @Test
    void testGetActivityWiseTabData_Success() throws SQLException {
        // Arrange
        LocalDateTime fromDate = LocalDateTime.of(2025, 1, 1, 0, 0);

        when(resultSet.next()).thenReturn(true).thenReturn(false);
        when(resultSet.getTimestamp("start_date")).thenReturn(Timestamp.valueOf(fromDate));
        when(resultSet.getString("cpt_type")).thenReturn("PROCEDURE");
        when(resultSet.getString("cpt_code")).thenReturn("99213");
        when(resultSet.getBigDecimal("quantity")).thenReturn(new java.math.BigDecimal("1"));
        when(resultSet.getBigDecimal("net_amount")).thenReturn(new java.math.BigDecimal("100.00"));
        when(resultSet.getBigDecimal("payment_amount")).thenReturn(new java.math.BigDecimal("90.00"));
        when(resultSet.getString("denial_code")).thenReturn("DEN001");
        when(resultSet.getString("ordering_clinician")).thenReturn("DOC001");
        when(resultSet.getString("ordering_clinician_name")).thenReturn("Dr. Smith");
        when(resultSet.getString("clinician")).thenReturn("DOC002");
        when(resultSet.getString("xml_file_name")).thenReturn("file.xml");
        when(resultSet.getBigDecimal("denied_amount")).thenReturn(new java.math.BigDecimal("10.00"));
        when(resultSet.getBigDecimal("payment_percentage")).thenReturn(new java.math.BigDecimal("90.00"));
        when(resultSet.getString("payment_status")).thenReturn("PARTIALLY_PAID");
        when(resultSet.getBigDecimal("unit_price")).thenReturn(new java.math.BigDecimal("90.00"));
        when(resultSet.getString("facility_id")).thenReturn("FAC001");
        when(resultSet.getString("payer_id")).thenReturn("PAY001");
        when(resultSet.getString("claim_number")).thenReturn("CL001");
        when(resultSet.getTimestamp("encounter_start_date")).thenReturn(Timestamp.valueOf(fromDate));

        // Act
        List<Map<String, Object>> result = reportService.getActivityWiseTabData(
                fromDate, null, null, null, null, null, null, null, null, null);

        // Assert
        assertNotNull(result);
        assertEquals(1, result.size());

        Map<String, Object> row = result.get(0);
        assertEquals("PROCEDURE", row.get("cptType"));
        assertEquals("99213", row.get("cptCode"));
        assertEquals("PARTIALLY_PAID", row.get("paymentStatus"));
    }

    @Test
    void testGetReportParameters_Success() throws SQLException {
        // Arrange
        LocalDateTime fromDate = LocalDateTime.of(2025, 1, 1, 0, 0);
        LocalDateTime toDate = LocalDateTime.of(2025, 1, 31, 23, 59);

        when(resultSet.next()).thenReturn(true);
        when(resultSet.getLong("total_claims")).thenReturn(10L);
        when(resultSet.getLong("total_activities")).thenReturn(25L);
        when(resultSet.getBigDecimal("total_billed_amount")).thenReturn(new java.math.BigDecimal("5000.00"));
        when(resultSet.getBigDecimal("total_paid_amount")).thenReturn(new java.math.BigDecimal("4500.00"));
        when(resultSet.getBigDecimal("total_denied_amount")).thenReturn(new java.math.BigDecimal("500.00"));
        when(resultSet.getBigDecimal("avg_collection_rate")).thenReturn(new java.math.BigDecimal("90.00"));

        // Act
        Map<String, Object> result = reportService.getReportParameters(
                fromDate, toDate, null, null, null, null);

        // Assert
        assertNotNull(result);
        assertEquals(10L, result.get("totalClaims"));
        assertEquals(25L, result.get("totalActivities"));
        assertEquals(new java.math.BigDecimal("5000.00"), result.get("totalBilledAmount"));
        assertEquals(new java.math.BigDecimal("4500.00"), result.get("totalPaidAmount"));
        assertEquals(new java.math.BigDecimal("500.00"), result.get("totalDeniedAmount"));
        assertEquals(new java.math.BigDecimal("90.00"), result.get("avgCollectionRate"));
    }

    @Test
    void testGetFilterOptions_Success() throws SQLException {
        // Arrange
        when(resultSet.next()).thenReturn(true).thenReturn(true).thenReturn(false);
        when(resultSet.getString(1)).thenReturn("FAC001").thenReturn("FAC002");

        // Act
        Map<String, List<String>> result = reportService.getFilterOptions();

        // Assert
        assertNotNull(result);
        assertTrue(result.containsKey("facilities"));
        assertTrue(result.containsKey("payers"));
        assertTrue(result.containsKey("receivers"));

        // Verify that queries were made for each filter option
        verify(connection, times(3)).prepareStatement(anyString());
    }

    @Test
    void testGetHeaderTabData_SqlException() throws SQLException {
        // Arrange
        when(dataSource.getConnection()).thenThrow(new SQLException("Database connection failed"));

        // Act & Assert
        RuntimeException exception = assertThrows(RuntimeException.class, () ->
            reportService.getHeaderTabData(null, null, null, null, null, null, null, null, null));

        assertEquals("Failed to retrieve header tab data", exception.getMessage());
        assertTrue(exception.getCause() instanceof SQLException);
    }

    @Test
    void testBuildOrderByClause_ValidColumn() {
        // This is a private method, but we can test it indirectly through the public methods
        // The implementation is tested through the integration with getHeaderTabData
        assertDoesNotThrow(() -> {
            reportService.getHeaderTabData(null, null, null, null, null, "total_paid_amount", "ASC", null, null);
        });
    }

    @Test
    void testBuildOrderByClause_InvalidColumn() throws SQLException {
        // Arrange
        when(resultSet.next()).thenReturn(false);

        // Act
        List<Map<String, Object>> result = reportService.getHeaderTabData(
                null, null, null, null, null, "invalid_column", "ASC", null, null);

        // Assert - Should not throw exception, should use default sorting
        assertNotNull(result);
        assertTrue(result.isEmpty());

        // Verify that the statement was prepared (method executed without error)
        verify(preparedStatement).executeQuery();
    }
}
