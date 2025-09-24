package com.acme.claims.util;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;
import java.util.StringJoiner;

/**
 * Utility class to generate database views and materialized views
 * based on the JSON mapping configuration file.
 * 
 * This class reads the report_columns_xml_mappings.json file and generates
 * SQL statements for creating views and materialized views dynamically.
 */
@Component
public class ReportViewGenerator {
    
    private final ObjectMapper objectMapper;
    
    public ReportViewGenerator() {
        this.objectMapper = new ObjectMapper();
    }
    
    /**
     * Represents a column mapping from the JSON configuration
     */
    public static class ColumnMapping {
        private String reportColumn;
        private String submissionXmlPath;
        private String remittanceXmlPath;
        private String notesDerivation;
        private String cursorAnalysis;
        private String submissionDbPath;
        private String remittanceDbPath;
        private String dataType;
        private String bestPath;
        private String aiAnalysis;
        
        // Getters and setters
        public String getReportColumn() { return reportColumn; }
        public void setReportColumn(String reportColumn) { this.reportColumn = reportColumn; }
        
        public String getSubmissionXmlPath() { return submissionXmlPath; }
        public void setSubmissionXmlPath(String submissionXmlPath) { this.submissionXmlPath = submissionXmlPath; }
        
        public String getRemittanceXmlPath() { return remittanceXmlPath; }
        public void setRemittanceXmlPath(String remittanceXmlPath) { this.remittanceXmlPath = remittanceXmlPath; }
        
        public String getNotesDerivation() { return notesDerivation; }
        public void setNotesDerivation(String notesDerivation) { this.notesDerivation = notesDerivation; }
        
        public String getCursorAnalysis() { return cursorAnalysis; }
        public void setCursorAnalysis(String cursorAnalysis) { this.cursorAnalysis = cursorAnalysis; }
        
        public String getSubmissionDbPath() { return submissionDbPath; }
        public void setSubmissionDbPath(String submissionDbPath) { this.submissionDbPath = submissionDbPath; }
        
        public String getRemittanceDbPath() { return remittanceDbPath; }
        public void setRemittanceDbPath(String remittanceDbPath) { this.remittanceDbPath = remittanceDbPath; }
        
        public String getDataType() { return dataType; }
        public void setDataType(String dataType) { this.dataType = dataType; }
        
        public String getBestPath() { return bestPath; }
        public void setBestPath(String bestPath) { this.bestPath = bestPath; }
        
        public String getAiAnalysis() { return aiAnalysis; }
        public void setAiAnalysis(String aiAnalysis) { this.aiAnalysis = aiAnalysis; }
    }
    
    /**
     * Loads column mappings from the JSON configuration file
     */
    public List<ColumnMapping> loadColumnMappings() throws IOException {
        ClassPathResource resource = new ClassPathResource("json/report_columns_xml_mappings.json");
        String jsonContent = Files.readString(resource.getFile().toPath());
        
        JsonNode rootNode = objectMapper.readTree(jsonContent);
        JsonNode sheets = rootNode.get("sheets");
        
        List<ColumnMapping> mappings = new ArrayList<>();
        
        if (sheets.isArray()) {
            for (JsonNode sheet : sheets) {
                JsonNode rows = sheet.get("rows");
                if (rows.isArray()) {
                    for (JsonNode row : rows) {
                        ColumnMapping mapping = new ColumnMapping();
                        mapping.setReportColumn(getStringValue(row, "Report Column"));
                        mapping.setSubmissionXmlPath(getStringValue(row, "Submission XML path"));
                        mapping.setRemittanceXmlPath(getStringValue(row, "Remittance XML path"));
                        mapping.setNotesDerivation(getStringValue(row, "Notes / derivation"));
                        mapping.setCursorAnalysis(getStringValue(row, "Cursor Analysis"));
                        mapping.setSubmissionDbPath(getStringValue(row, "Submission DB Path"));
                        mapping.setRemittanceDbPath(getStringValue(row, "Remittance DB Path"));
                        mapping.setDataType(getStringValue(row, "Data Type"));
                        mapping.setBestPath(getStringValue(row, "Best Path"));
                        mapping.setAiAnalysis(getStringValue(row, "AI Analysis"));
                        
                        mappings.add(mapping);
                    }
                }
            }
        }
        
        return mappings;
    }
    
    /**
     * Generates SQL for creating a comprehensive claims report view
     */
    public String generateComprehensiveViewSql(List<ColumnMapping> mappings) {
        StringBuilder sql = new StringBuilder();
        sql.append("-- ==========================================================================================================\n");
        sql.append("-- COMPREHENSIVE CLAIMS REPORT VIEW - GENERATED FROM JSON MAPPING\n");
        sql.append("-- ==========================================================================================================\n\n");
        
        sql.append("CREATE OR REPLACE VIEW claims.v_comprehensive_claims_report_generated AS\n");
        sql.append("SELECT\n");
        
        // Generate column definitions
        StringJoiner columns = new StringJoiner(",\n  ");
        for (ColumnMapping mapping : mappings) {
            if (mapping.getReportColumn() != null && !mapping.getReportColumn().trim().isEmpty()) {
                String columnName = sanitizeColumnName(mapping.getReportColumn());
                String dataType = mapDataType(mapping.getDataType());
                String columnDefinition = generateColumnDefinition(mapping);
                
                columns.add(String.format("  %s %s, -- %s", columnName, dataType, columnDefinition));
            }
        }
        
        sql.append(columns.toString()).append("\n");
        
        // Add FROM clause
        sql.append("FROM claims.claim_key ck\n");
        sql.append("JOIN claims.claim c ON c.claim_key_id = ck.id\n");
        sql.append("JOIN claims.encounter e ON e.claim_id = c.id\n");
        sql.append("LEFT JOIN claims.activity a ON a.claim_id = c.id\n");
        sql.append("LEFT JOIN claims_ref.provider p ON p.provider_code = c.provider_id\n");
        sql.append("LEFT JOIN claims_ref.facility f ON f.facility_code = e.facility_id\n");
        sql.append("LEFT JOIN claims_ref.payer pay ON pay.payer_code = c.payer_id\n");
        sql.append("LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id\n");
        sql.append("LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id AND ra.activity_id = a.activity_id\n");
        sql.append("LEFT JOIN claims.submission s ON s.id = c.submission_id\n");
        sql.append("LEFT JOIN claims.ingestion_file if_sub ON if_sub.id = s.ingestion_file_id\n");
        sql.append("LEFT JOIN claims.remittance rem ON rem.claim_key_id = ck.id\n");
        sql.append("LEFT JOIN claims.ingestion_file if_rem ON if_rem.id = rem.ingestion_file_id;\n\n");
        
        sql.append("COMMENT ON VIEW claims.v_comprehensive_claims_report_generated IS 'Comprehensive claims report view generated from JSON mapping configuration';\n");
        
        return sql.toString();
    }
    
    /**
     * Generates SQL for creating a balance amount report view
     */
    public String generateBalanceAmountViewSql(List<ColumnMapping> mappings) {
        StringBuilder sql = new StringBuilder();
        sql.append("-- ==========================================================================================================\n");
        sql.append("-- BALANCE AMOUNT REPORT VIEW - GENERATED FROM JSON MAPPING\n");
        sql.append("-- ==========================================================================================================\n\n");
        
        sql.append("CREATE OR REPLACE VIEW claims.v_balance_amount_report_generated AS\n");
        sql.append("SELECT\n");
        
        // Generate column definitions for balance amount specific fields
        StringJoiner columns = new StringJoiner(",\n  ");
        for (ColumnMapping mapping : mappings) {
            if (isBalanceAmountField(mapping.getReportColumn())) {
                String columnName = sanitizeColumnName(mapping.getReportColumn());
                String dataType = mapDataType(mapping.getDataType());
                String columnDefinition = generateColumnDefinition(mapping);
                
                columns.add(String.format("  %s %s, -- %s", columnName, dataType, columnDefinition));
            }
        }
        
        sql.append(columns.toString()).append("\n");
        
        // Add FROM clause
        sql.append("FROM claims.claim_key ck\n");
        sql.append("JOIN claims.claim c ON c.claim_key_id = ck.id\n");
        sql.append("JOIN claims.encounter e ON e.claim_id = c.id\n");
        sql.append("LEFT JOIN claims.activity a ON a.claim_id = c.id\n");
        sql.append("LEFT JOIN claims_ref.provider p ON p.provider_code = c.provider_id\n");
        sql.append("LEFT JOIN claims_ref.facility f ON f.facility_code = e.facility_id\n");
        sql.append("LEFT JOIN claims_ref.payer pay ON pay.payer_code = c.payer_id\n");
        sql.append("LEFT JOIN claims.remittance_claim rc ON rc.claim_key_id = ck.id\n");
        sql.append("LEFT JOIN claims.remittance_activity ra ON ra.remittance_claim_id = rc.id AND ra.activity_id = a.activity_id\n");
        sql.append("WHERE (c.net - COALESCE(ra.payment_amount, 0)) > 0;\n\n");
        
        sql.append("COMMENT ON VIEW claims.v_balance_amount_report_generated IS 'Balance amount report view generated from JSON mapping configuration';\n");
        
        return sql.toString();
    }
    
    /**
     * Generates SQL for creating materialized views
     */
    public String generateMaterializedViewsSql() {
        StringBuilder sql = new StringBuilder();
        sql.append("-- ==========================================================================================================\n");
        sql.append("-- MATERIALIZED VIEWS - GENERATED FROM JSON MAPPING\n");
        sql.append("-- ==========================================================================================================\n\n");
        
        // Comprehensive report materialized view
        sql.append("CREATE MATERIALIZED VIEW claims.mv_comprehensive_claims_report_generated AS\n");
        sql.append("SELECT * FROM claims.v_comprehensive_claims_report_generated;\n\n");
        
        sql.append("CREATE UNIQUE INDEX ON claims.mv_comprehensive_claims_report_generated (claim_key_id, activity_id);\n\n");
        
        // Balance amount report materialized view
        sql.append("CREATE MATERIALIZED VIEW claims.mv_balance_amount_report_generated AS\n");
        sql.append("SELECT * FROM claims.v_balance_amount_report_generated;\n\n");
        
        sql.append("CREATE UNIQUE INDEX ON claims.mv_balance_amount_report_generated (claim_key_id);\n\n");
        
        // Refresh function
        sql.append("CREATE OR REPLACE FUNCTION claims.refresh_generated_materialized_views()\n");
        sql.append("RETURNS VOID\n");
        sql.append("LANGUAGE plpgsql\n");
        sql.append("AS $$\n");
        sql.append("BEGIN\n");
        sql.append("  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_comprehensive_claims_report_generated;\n");
        sql.append("  REFRESH MATERIALIZED VIEW CONCURRENTLY claims.mv_balance_amount_report_generated;\n");
        sql.append("  RAISE NOTICE 'Generated materialized views refreshed successfully!';\n");
        sql.append("END;\n");
        sql.append("$$;\n\n");
        
        sql.append("COMMENT ON FUNCTION claims.refresh_generated_materialized_views IS 'Refreshes all generated materialized views';\n");
        
        return sql.toString();
    }
    
    /**
     * Generates complete SQL script for all views and materialized views
     */
    public String generateCompleteSqlScript() throws IOException {
        List<ColumnMapping> mappings = loadColumnMappings();
        
        StringBuilder sql = new StringBuilder();
        sql.append("-- ==========================================================================================================\n");
        sql.append("-- COMPLETE VIEW GENERATION SCRIPT FROM JSON MAPPING\n");
        sql.append("-- Generated on: ").append(java.time.LocalDateTime.now()).append("\n");
        sql.append("-- ==========================================================================================================\n\n");
        
        sql.append(generateComprehensiveViewSql(mappings));
        sql.append("\n");
        sql.append(generateBalanceAmountViewSql(mappings));
        sql.append("\n");
        sql.append(generateMaterializedViewsSql());
        
        return sql.toString();
    }
    
    // Helper methods
    
    private String getStringValue(JsonNode node, String fieldName) {
        JsonNode fieldNode = node.get(fieldName);
        return fieldNode != null && !fieldNode.isNull() ? fieldNode.asText() : "";
    }
    
    private String sanitizeColumnName(String columnName) {
        if (columnName == null) return "";
        return columnName.toLowerCase()
                .replaceAll("[^a-zA-Z0-9_]", "_")
                .replaceAll("_+", "_")
                .replaceAll("^_|_$", "");
    }
    
    private String mapDataType(String dataType) {
        if (dataType == null) return "TEXT";
        
        switch (dataType.toLowerCase()) {
            case "text": return "TEXT";
            case "integer": return "INTEGER";
            case "numeric(14,2)": return "NUMERIC(14,2)";
            case "timestamptz": return "TIMESTAMPTZ";
            case "boolean": return "BOOLEAN";
            case "array of text": return "TEXT[]";
            default: return "TEXT";
        }
    }
    
    private String generateColumnDefinition(ColumnMapping mapping) {
        if (mapping.getBestPath() != null && mapping.getBestPath().toLowerCase().contains("derived")) {
            return "Derived: " + mapping.getNotesDerivation();
        } else if (mapping.getBestPath() != null && !mapping.getBestPath().trim().isEmpty()) {
            return mapping.getBestPath();
        } else if (mapping.getSubmissionDbPath() != null && !mapping.getSubmissionDbPath().trim().isEmpty()) {
            return mapping.getSubmissionDbPath();
        } else {
            return mapping.getReportColumn();
        }
    }
    
    private boolean isBalanceAmountField(String reportColumn) {
        if (reportColumn == null) return false;
        
        String lowerColumn = reportColumn.toLowerCase();
        return lowerColumn.contains("balance") || 
               lowerColumn.contains("amount") || 
               lowerColumn.contains("claim") || 
               lowerColumn.contains("facility") || 
               lowerColumn.contains("payer") || 
               lowerColumn.contains("aging") || 
               lowerColumn.contains("payment") || 
               lowerColumn.contains("outstanding") ||
               lowerColumn.contains("pending");
    }
}
