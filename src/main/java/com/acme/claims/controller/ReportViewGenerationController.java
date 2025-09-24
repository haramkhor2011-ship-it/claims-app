package com.acme.claims.controller;

import com.acme.claims.util.ReportViewGenerator;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * REST Controller for generating database views and materialized views
 * based on the JSON mapping configuration.
 */
@RestController
@RequestMapping("/api/reports/views")
@CrossOrigin(origins = "*")
public class ReportViewGenerationController {
    
    @Autowired
    private ReportViewGenerator reportViewGenerator;
    
    /**
     * Get all column mappings from the JSON configuration
     */
    @GetMapping("/mappings")
    public ResponseEntity<List<ReportViewGenerator.ColumnMapping>> getColumnMappings() {
        try {
            List<ReportViewGenerator.ColumnMapping> mappings = reportViewGenerator.loadColumnMappings();
            return ResponseEntity.ok(mappings);
        } catch (IOException e) {
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * Generate comprehensive view SQL
     */
    @GetMapping("/sql/comprehensive")
    public ResponseEntity<Map<String, String>> generateComprehensiveViewSql() {
        try {
            List<ReportViewGenerator.ColumnMapping> mappings = reportViewGenerator.loadColumnMappings();
            String sql = reportViewGenerator.generateComprehensiveViewSql(mappings);
            
            Map<String, String> response = new HashMap<>();
            response.put("sql", sql);
            response.put("viewName", "v_comprehensive_claims_report_generated");
            response.put("description", "Comprehensive claims report view generated from JSON mapping");
            
            return ResponseEntity.ok(response);
        } catch (IOException e) {
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * Generate balance amount view SQL
     */
    @GetMapping("/sql/balance-amount")
    public ResponseEntity<Map<String, String>> generateBalanceAmountViewSql() {
        try {
            List<ReportViewGenerator.ColumnMapping> mappings = reportViewGenerator.loadColumnMappings();
            String sql = reportViewGenerator.generateBalanceAmountViewSql(mappings);
            
            Map<String, String> response = new HashMap<>();
            response.put("sql", sql);
            response.put("viewName", "v_balance_amount_report_generated");
            response.put("description", "Balance amount report view generated from JSON mapping");
            
            return ResponseEntity.ok(response);
        } catch (IOException e) {
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * Generate materialized views SQL
     */
    @GetMapping("/sql/materialized-views")
    public ResponseEntity<Map<String, String>> generateMaterializedViewsSql() {
        try {
            String sql = reportViewGenerator.generateMaterializedViewsSql();
            
            Map<String, String> response = new HashMap<>();
            response.put("sql", sql);
            response.put("description", "Materialized views generated from JSON mapping");
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * Generate complete SQL script for all views and materialized views
     */
    @GetMapping("/sql/complete")
    public ResponseEntity<Map<String, String>> generateCompleteSqlScript() {
        try {
            String sql = reportViewGenerator.generateCompleteSqlScript();
            
            Map<String, String> response = new HashMap<>();
            response.put("sql", sql);
            response.put("description", "Complete SQL script for all views and materialized views generated from JSON mapping");
            
            return ResponseEntity.ok(response);
        } catch (IOException e) {
            return ResponseEntity.internalServerError().build();
        }
    }
    
    /**
     * Get information about available view types
     */
    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> getViewInfo() {
        Map<String, Object> info = new HashMap<>();
        
        Map<String, String> viewTypes = new HashMap<>();
        viewTypes.put("comprehensive", "Comprehensive claims report view with all fields from JSON mapping");
        viewTypes.put("balance-amount", "Balance amount specific view for outstanding balances");
        viewTypes.put("materialized-views", "Materialized views for performance optimization");
        
        info.put("availableViewTypes", viewTypes);
        info.put("endpoints", Map.of(
            "mappings", "/api/reports/views/mappings",
            "comprehensive", "/api/reports/views/sql/comprehensive",
            "balance-amount", "/api/reports/views/sql/balance-amount",
            "materialized-views", "/api/reports/views/sql/materialized-views",
            "complete", "/api/reports/views/sql/complete"
        ));
        info.put("description", "View generation API based on JSON mapping configuration");
        
        return ResponseEntity.ok(info);
    }
}
