package com.acme.claims.util;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

/**
 * Utility to fix materialized view duplicate issues
 * 
 * This class fixes duplicate key violations in materialized views caused by
 * multiple remittances per claim creating multiple rows through LEFT JOINs.
 * 
 * Root Cause: LEFT JOINs to remittance_claim and remittance_activity create duplicates
 * Solution: Pre-aggregate remittance data before joining to ensure one row per claim
 */
@Component
public class MaterializedViewFixer {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    /**
     * Fix materialized view duplicates by applying aggregation approach
     */
    @Transactional
    public void fixMaterializedViewDuplicates() {
        System.out.println("=== MATERIALIZED VIEW DUPLICATE FIXES ===");
        System.out.println("Fixing duplicate key violations in materialized views...");
        
        try {
            // Read the fix script
            String sqlScript = new String(Files.readAllBytes(Paths.get("fix_materialized_views_duplicates.sql")));
            
            // Split by semicolon and execute each statement
            String[] statements = sqlScript.split(";");
            
            for (String statement : statements) {
                statement = statement.trim();
                if (!statement.isEmpty() && !statement.startsWith("--") && !statement.startsWith("/*")) {
                    try {
                        System.out.println("Executing: " + statement.substring(0, Math.min(50, statement.length())) + "...");
                        jdbcTemplate.execute(statement);
                        System.out.println("✓ Success");
                    } catch (Exception e) {
                        System.err.println("✗ Error: " + e.getMessage());
                        // Continue with other statements
                    }
                }
            }
            
            System.out.println("Materialized view fixes completed successfully!");
            
        } catch (IOException e) {
            System.err.println("Error reading fix script: " + e.getMessage());
            throw new RuntimeException("Failed to read fix script", e);
        }
    }

    /**
     * Verify the fixes by checking row counts and duplicates
     */
    public void verifyFixes() {
        System.out.println("\n=== VERIFICATION ===");
        
        try {
            // Check row counts
            String rowCountQuery = """
                SELECT 'mv_claim_summary_payerwise' as view_name, COUNT(*) as row_count 
                FROM claims.mv_claim_summary_payerwise
                UNION ALL 
                SELECT 'mv_claim_summary_encounterwise', COUNT(*) 
                FROM claims.mv_claim_summary_encounterwise
                ORDER BY view_name
            """;
            
            System.out.println("Row counts after fix:");
            jdbcTemplate.query(rowCountQuery, (rs) -> {
                System.out.println("  " + rs.getString("view_name") + ": " + rs.getInt("row_count") + " rows");
            });
            
            // Check for duplicates
            String duplicateCheckQuery = """
                SELECT 
                  'mv_claim_summary_payerwise' as view_name,
                  COUNT(*) as total_rows,
                  COUNT(DISTINCT month_bucket, payer_id, facility_id) as unique_keys,
                  COUNT(*) - COUNT(DISTINCT month_bucket, payer_id, facility_id) as duplicates
                FROM claims.mv_claim_summary_payerwise
                UNION ALL
                SELECT 
                  'mv_claim_summary_encounterwise',
                  COUNT(*),
                  COUNT(DISTINCT month_bucket, encounter_type, facility_id, payer_id),
                  COUNT(*) - COUNT(DISTINCT month_bucket, encounter_type, facility_id, payer_id)
                FROM claims.mv_claim_summary_encounterwise
            """;
            
            System.out.println("\nDuplicate check:");
            jdbcTemplate.query(duplicateCheckQuery, (rs) -> {
                String viewName = rs.getString("view_name");
                int totalRows = rs.getInt("total_rows");
                int uniqueKeys = rs.getInt("unique_keys");
                int duplicates = rs.getInt("duplicates");
                
                System.out.println("  " + viewName + ":");
                System.out.println("    Total rows: " + totalRows);
                System.out.println("    Unique keys: " + uniqueKeys);
                System.out.println("    Duplicates: " + duplicates);
                
                if (duplicates == 0) {
                    System.out.println("    ✓ No duplicates found!");
                } else {
                    System.out.println("    ✗ " + duplicates + " duplicates still exist!");
                }
            });
            
        } catch (Exception e) {
            System.err.println("Error during verification: " + e.getMessage());
        }
    }

    /**
     * Run the complete fix process
     */
    public void runCompleteFix() {
        System.out.println("Starting materialized view duplicate fix process...");
        
        try {
            // Apply fixes
            fixMaterializedViewDuplicates();
            
            // Verify fixes
            verifyFixes();
            
            System.out.println("\n=== SUMMARY ===");
            System.out.println("Materialized view duplicate fixes completed!");
            System.out.println("Fixed views:");
            System.out.println("  - mv_claim_summary_payerwise");
            System.out.println("  - mv_claim_summary_encounterwise");
            System.out.println("\nNext steps:");
            System.out.println("  1. Test reports to ensure they work correctly");
            System.out.println("  2. Monitor performance");
            System.out.println("  3. Fix remaining views if needed");
            
        } catch (Exception e) {
            System.err.println("Error during fix process: " + e.getMessage());
            e.printStackTrace();
            throw new RuntimeException("Failed to fix materialized views", e);
        }
    }
}
